import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import VideoToolbox

public enum CaptureEngine {
    private static let overlay = RegionSelectionOverlay()
    private static let maxScrollFrames = 15

    public static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public static func requestScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    public static func ensurePermission(completion: @escaping (Bool) -> Void) {
        if hasScreenRecordingPermission() {
            DispatchQueue.main.async { completion(true) }
            return
        }
        DispatchQueue.main.async {
            _ = requestScreenRecordingPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                completion(CGPreflightScreenCaptureAccess())
            }
        }
    }

    private static func deliverOnMain(_ image: NSImage?, _ completion: @escaping (NSImage?) -> Void) {
        nonisolated(unsafe) let transfer = image
        DispatchQueue.main.async { completion(transfer) }
    }

    private static func deliverOnMain(
        _ image: NSImage?,
        isPartial: Bool,
        _ completion: @escaping (NSImage?, Bool) -> Void
    ) {
        nonisolated(unsafe) let transfer = image
        DispatchQueue.main.async { completion(transfer, isPartial) }
    }

    public static func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        ensurePermission { granted in
            guard granted else {
                presentPermissionHelp()
                completion(nil)
                return
            }
            Task {
                let image = await captureWithScreenCaptureKit(targetRectGlobal: nil)
                deliverOnMain(image, completion)
            }
        }
    }

    public static func captureRegionInteractive(completion: @escaping (NSImage?) -> Void) {
        ensurePermission { granted in
            guard granted else {
                presentPermissionHelp()
                completion(nil)
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            overlay.begin { rect in
                guard let rect = rect, rect.width >= 4, rect.height >= 4 else {
                    completion(nil)
                    return
                }
                Task {
                    let img = await captureWithScreenCaptureKit(targetRectGlobal: rect)
                    if img != nil {
                        LastRegionStore.save(rect, displayID: displayID(containing: rect))
                    }
                    deliverOnMain(img, completion)
                }
            }
        }
    }

    public static func cancelInteractiveCapture() {
        overlay.cancel(notify: true)
    }

    public static func captureLastRegion(completion: @escaping (NSImage?) -> Void) {
        guard let (rect, _) = LastRegionStore.load(), rect.width >= 4, rect.height >= 4 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        ensurePermission { granted in
            guard granted else {
                presentPermissionHelp()
                completion(nil)
                return
            }
            Task {
                let img = await captureWithScreenCaptureKit(targetRectGlobal: rect)
                deliverOnMain(img, completion)
            }
        }
    }

    public static func captureActiveWindow(completion: @escaping (NSImage?) -> Void) {
        ensurePermission { granted in
            guard granted else {
                presentPermissionHelp()
                completion(nil)
                return
            }
            Task {
                await MainActor.run { NSApp.deactivate() }
                try? await Task.sleep(nanoseconds: 200_000_000)
                let img = await captureFrontmostWindow()
                deliverOnMain(img, completion)
            }
        }
    }

    public static func captureScrolling(completion: @escaping (NSImage?, Bool) -> Void) {
        ensurePermission { granted in
            guard granted else {
                presentPermissionHelp()
                completion(nil, false)
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            overlay.begin { rect in
                guard let rect = rect, rect.width >= 4, rect.height >= 4 else {
                    completion(nil, false)
                    return
                }
                LastRegionStore.save(rect, displayID: displayID(containing: rect))
                Task {
                    let (img, isPartial) = await performScrollingCapture(region: rect)
                    deliverOnMain(img, isPartial: isPartial, completion)
                }
            }
        }
    }

    private static func captureWithScreenCaptureKit(targetRectGlobal: CGRect?) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard !content.displays.isEmpty else { return nil }

            let display: SCDisplay
            let cropInDisplay: CGRect?

            if let target = targetRectGlobal {
                let center = CGPoint(x: target.midX, y: target.midY)
                let matched = content.displays.first { displayCocoaFrame($0).contains(center) }
                    ?? content.displays[0]
                display = matched
                let frame = displayCocoaFrame(display)
                // Cocoa bottom-left global → SCK top-left display-local (clamped)
                cropInDisplay = CaptureGeometry.topLeftSourceRect(
                    selectionGlobalCocoa: target,
                    displayCocoaFrame: frame
                )
            } else {
                let mainID = CGMainDisplayID()
                display = content.displays.first(where: { $0.displayID == mainID }) ?? content.displays[0]
                cropInDisplay = nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scale = displayScale(for: display)
            let fullW = CGFloat(display.width)
            let fullH = CGFloat(display.height)

            if let crop = cropInDisplay {
                config.sourceRect = crop
                config.width = max(1, Int((crop.width * scale).rounded()))
                config.height = max(1, Int((crop.height * scale).rounded()))
            } else {
                config.width = max(1, Int((fullW * scale).rounded()))
                config.height = max(1, Int((fullH * scale).rounded()))
            }
            config.scalesToFit = false
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let rawCgImage: CGImage
            if #available(macOS 14.0, *) {
                rawCgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
            } else {
                rawCgImage = try await captureViaStream(filter: filter, config: config)
            }

            let pointSize: CGSize
            if let crop = cropInDisplay {
                pointSize = crop.size
            } else {
                pointSize = CGSize(width: fullW, height: fullH)
            }

            // ScreenCaptureKit image buffer coordinate space top-left vs AppKit coordinate space bottom-left.
            // Flip vertically so the captured NSImage displays upright.
            guard let flippedCg = flipVertically(cgImage: rawCgImage) else {
                return NSImage(cgImage: rawCgImage, size: pointSize)
            }
            return NSImage(cgImage: flippedCg, size: pointSize)
        } catch {
            NSLog("ctdoshot SCK capture error: \(error.localizedDescription)")
            return nil
        }
    }

    private static func flipVertically(cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return nil
        }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static func captureViaStream(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            let box = ContinuationBox(cont)
            let output = StreamFrameOutput { result in
                box.resume(result)
            }
            do {
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
                output.onComplete = {
                    stream.stopCapture { _ in }
                }
                stream.startCapture { error in
                    if let error = error {
                        box.resume(.failure(error))
                    }
                }
            } catch {
                box.resume(.failure(error))
            }
        }
    }

    private static func captureFrontmostWindow() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ourPID = ProcessInfo.processInfo.processIdentifier
            let ourBundle = Bundle.main.bundleIdentifier

            let excludedOwners: Set<String> = [
                "Window Server",
                "Dock",
                "Control Center",
                "Notification Center",
                "SystemUIServer",
                "Spotlight",
            ]

            // Prefer the real frontmost app (not us); fall back to largest non-system window.
            let frontApp = NSWorkspace.shared.frontmostApplication
            let frontIsUs = frontApp?.processIdentifier == ourPID
                || (frontApp?.bundleIdentifier != nil && frontApp?.bundleIdentifier == ourBundle)
            let targetPID = frontIsUs ? nil : frontApp?.processIdentifier
            let targetBundle = frontIsUs ? nil : frontApp?.bundleIdentifier

            func isExcluded(_ window: SCWindow) -> Bool {
                guard window.isOnScreen else { return true }
                guard window.frame.width >= 50, window.frame.height >= 50 else { return true }
                let owner = window.owningApplication
                if owner?.processID == ourPID { return true }
                if let ourBundle, owner?.bundleIdentifier == ourBundle { return true }
                if let ownerName = owner?.applicationName, excludedOwners.contains(ownerName) {
                    return true
                }
                return false
            }

            let matching: [SCWindow]
            if let targetBundle, !targetBundle.isEmpty {
                matching = content.windows.filter { window in
                    !isExcluded(window) && window.owningApplication?.bundleIdentifier == targetBundle
                }
            } else if let targetPID {
                matching = content.windows.filter { window in
                    !isExcluded(window) && window.owningApplication?.processID == targetPID
                }
            } else {
                matching = content.windows.filter { !isExcluded($0) }
            }

            // Largest on-screen window for the chosen app (skip tiny chrome).
            guard let window = matching
                .sorted(by: { ($0.frame.width * $0.frame.height) > ($1.frame.width * $1.frame.height) })
                .first
            else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            let scale = windowScale(for: window)
            let w = max(1, Int((window.frame.width * scale).rounded()))
            let h = max(1, Int((window.frame.height * scale).rounded()))
            config.width = w
            config.height = h
            config.scalesToFit = false
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let rawCgImage: CGImage
            if #available(macOS 14.0, *) {
                rawCgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
            } else {
                rawCgImage = try await captureViaStream(filter: filter, config: config)
            }

            let pointSize = CGSize(width: window.frame.width, height: window.frame.height)
            guard let flippedCg = flipVertically(cgImage: rawCgImage) else {
                return NSImage(cgImage: rawCgImage, size: pointSize)
            }
            return NSImage(cgImage: flippedCg, size: pointSize)
        } catch {
            NSLog("ctdoshot SCK window capture error: \(error.localizedDescription)")
            return nil
        }
    }

    private static func performScrollingCapture(region: CGRect) async -> (NSImage?, Bool) {
        let maxHeight = scrollMaxHeightPoints()
        var frames: [NSImage] = []

        // Capture first frame before scrolling.
        if let first = await captureWithScreenCaptureKit(targetRectGlobal: region) {
            frames.append(first)
        } else {
            return (nil, false)
        }

        var stitchedHeight = frames[0].size.height
        // Remaining frames: scroll → wait → capture (up to maxScrollFrames total).
        while frames.count < maxScrollFrames, stitchedHeight < maxHeight {
            postScrollWheel(atCocoaPoint: CGPoint(x: region.midX, y: region.midY), lineDelta: -3)
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms

            guard let frame = await captureWithScreenCaptureKit(targetRectGlobal: region) else {
                break
            }
            // Stop if content didn't change (end of scrollable area).
            if let last = frames.last, imagesLikelyEqual(last, frame) {
                break
            }
            frames.append(frame)
            stitchedHeight += max(1, frame.size.height * 0.5) // rough progress until stitch
        }

        let h = Int(region.height.rounded())
        let maxOverlap = max(10, min(120, h / 2))
        if let stitched = ScrollStitcher.stitch(frames: frames, minOverlap: 10, maxOverlap: maxOverlap) {
            return (stitched, false)
        }
        // Partial / stitch failure: still return something useful + signal toast.
        return (frames.last ?? frames.first, true)
    }

    private static func postScrollWheel(atCocoaPoint point: CGPoint, lineDelta: Int32) {
        let quartz = quartzPoint(fromCocoa: point)
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: lineDelta,
            wheel2: 0,
            wheel3: 0
        ) else {
            return
        }
        event.location = quartz
        event.post(tap: .cghidEventTap)
    }

    private static func quartzPoint(fromCocoa point: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first(where: {
            $0.frame.origin == .zero
        })?.frame.height ?? NSScreen.main?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    private static func imagesLikelyEqual(_ a: NSImage, _ b: NSImage) -> Bool {
        guard abs(a.size.width - b.size.width) < 0.5,
              abs(a.size.height - b.size.height) < 0.5 else {
            return false
        }
        guard let tiffA = a.tiffRepresentation, let tiffB = b.tiffRepresentation else {
            return false
        }
        return tiffA == tiffB
    }

    private static func scrollMaxHeightPoints() -> CGFloat {
        let raw = UserDefaults.standard.string(forKey: "scrollMaxHeight") ?? "20000"
        // Prefer plain numeric; fall back to stripping grouping separators ("20.000" → 20000).
        if let v = Double(raw), v >= 100 {
            return CGFloat(v)
        }
        let digitsOnly = raw.filter { $0.isNumber }
        if let v = Double(digitsOnly), v > 0 {
            return CGFloat(v)
        }
        return 20000
    }

    private static func displayID(containing rect: CGRect) -> UInt32 {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for screen in NSScreen.screens {
            if screen.frame.contains(center),
               let idNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return idNum.uint32Value
            }
        }
        return CGMainDisplayID()
    }

    private static func displayCocoaFrame(_ display: SCDisplay) -> CGRect {
        for screen in NSScreen.screens {
            if let idNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               idNum.uint32Value == display.displayID {
                return screen.frame
            }
        }
        return CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
    }

    private static func displayScale(for display: SCDisplay) -> CGFloat {
        if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID
        }) {
            return screen.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 2
    }

    private static func windowScale(for window: SCWindow) -> CGFloat {
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
        let cocoaCenter = CGPoint(
            x: window.frame.midX,
            y: primaryHeight - window.frame.midY
        )
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(cocoaCenter) }) {
            return screen.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 2
    }

    public static func presentPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording required"
        alert.informativeText = "Enable ctdoshot under System Settings → Privacy & Security → Screen Recording, then quit and reopen the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private var cont: CheckedContinuation<CGImage, Error>?
    private let lock = NSLock()

    init(_ cont: CheckedContinuation<CGImage, Error>) {
        self.cont = cont
    }

    func resume(_ result: Result<CGImage, Error>) {
        lock.lock()
        let c = cont
        cont = nil
        lock.unlock()
        c?.resume(with: result)
    }
}

private final class StreamFrameOutput: NSObject, SCStreamOutput {
    private let handler: (Result<CGImage, Error>) -> Void
    private var finished = false
    var onComplete: (() -> Void)?

    init(handler: @escaping (Result<CGImage, Error>) -> Void) {
        self.handler = handler
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, !finished else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        finished = true
        onComplete?()

        var cgOut: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgOut)
        if status == noErr, let cgOut = cgOut {
            handler(.success(cgOut))
            return
        }

        let ci = CIImage(cvImageBuffer: imageBuffer)
        let ctx = CIContext(options: nil)
        if let out = ctx.createCGImage(ci, from: ci.extent) {
            handler(.success(out))
        } else {
            handler(.failure(NSError(
                domain: "ctdoshot",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert capture frame"]
            )))
        }
    }
}
