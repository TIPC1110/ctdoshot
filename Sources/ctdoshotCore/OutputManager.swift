import Foundation
import AppKit

struct OutputOptions {
    var copy: Bool
    var save: Bool
    var downscaleRetina: Bool
    var saveFormat: String
    var saveDirectory: URL
}

enum OutputManager {
    static var defaultSaveDir: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let dir = pictures.appendingPathComponent("ctdoshot")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func currentOptions() -> OutputOptions {
        let defaults = UserDefaults.standard
        let pathString = defaults.string(forKey: "savePath") ?? ""
        let saveDir: URL
        if !pathString.isEmpty {
            saveDir = URL(fileURLWithPath: pathString)
        } else {
            saveDir = defaultSaveDir
        }

        let copy = defaults.object(forKey: "afterCopy") != nil ? defaults.bool(forKey: "afterCopy") : true
        let save = defaults.object(forKey: "afterSave") != nil ? defaults.bool(forKey: "afterSave") : true
        let downscale = defaults.bool(forKey: "downscaleRetina")
        let format = defaults.string(forKey: "saveFormat") ?? "Auto"

        return OutputOptions(
            copy: copy,
            save: save,
            downscaleRetina: downscale,
            saveFormat: format,
            saveDirectory: saveDir
        )
    }

    @discardableResult
    static func process(image: NSImage, options customOptions: OutputOptions? = nil) -> (fileURL: URL?, didCopy: Bool) {
        let options = customOptions ?? currentOptions()
        var targetImage = image

        if options.downscaleRetina, let downscaled = downscaleRetinaIfNeeded(image) {
            targetImage = downscaled
        }

        var savedURL: URL? = nil
        if options.save {
            savedURL = saveFile(image: targetImage, options: options)
        }

        var didCopy = false
        if options.copy {
            copyToPasteboard(image: targetImage, fileURL: savedURL)
            didCopy = true
        }

        return (savedURL, didCopy)
    }

    /// Puts image on pasteboard; when `fileURL` is set also exposes path + file URL.
    static func copyToPasteboard(image: NSImage, fileURL: URL? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var items: [NSPasteboardWriting] = [image]
        if let fileURL = fileURL {
            items.append(fileURL as NSURL)
        }
        pasteboard.writeObjects(items)

        // Plain path for terminals / paste-as-text (⌃C path request).
        if let path = fileURL?.path {
            pasteboard.setString(path, forType: .string)
        }
    }

    private static func saveFile(image: NSImage, options: OutputOptions) -> URL? {
        let dir = options.saveDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let isJPEG = shouldSaveAsJPEG(image: image, formatSetting: options.saveFormat)
        let ext = isJPEG ? "jpg" : "png"

        guard let imageData = imageData(from: image, isJPEG: isJPEG) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "ctdoshot_\(formatter.string(from: Date())).\(ext)"
        let fileURL = dir.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    private static func downscaleRetinaIfNeeded(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let pxWidth = cgImage.width
        let pxHeight = cgImage.height
        let ptWidth = max(1, Int(round(image.size.width)))
        let ptHeight = max(1, Int(round(image.size.height)))

        // Only downscale when pixel buffer is clearly retina-scale vs point size.
        guard pxWidth >= ptWidth * 2 || pxHeight >= ptHeight * 2 else {
            return nil
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: ptWidth,
            pixelsHigh: ptHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = NSSize(width: ptWidth, height: ptHeight)

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: ptWidth, height: ptHeight),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let resized = NSImage(size: NSSize(width: ptWidth, height: ptHeight))
        resized.addRepresentation(rep)
        return resized
    }

    private static func shouldSaveAsJPEG(image: NSImage, formatSetting: String) -> Bool {
        if formatSetting.lowercased() == "png" {
            return false
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let alphaInfo = cgImage.alphaInfo
        let hasAlpha = alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast
        return !hasAlpha
    }

    private static func imageData(from image: NSImage, isJPEG: Bool) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        if isJPEG {
            return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else {
            return bitmapImage.representation(using: .png, properties: [:])
        }
    }
}
