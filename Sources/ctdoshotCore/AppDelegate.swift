import SwiftUI
import AppKit
import UserNotifications

public class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    public var statusItem: NSStatusItem?
    public var overlayWindow: NSWindow?
    public var preferencesWindow: NSWindow?
    public var historyWindow: NSWindow?
    public var lastCapturedImage: NSImage?
    /// Strong refs so pin panels stay alive (and can be closed on quit).
    private var pinControllers: [PinWindowController] = []
    private var isOCRBusy = false

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility: no dock bounce; still show in Cmd-Tab when windows open.
        NSApp.setActivationPolicy(.accessory)

        setupNotifications()
        setupStatusBar()
        setupHotkey()

        // Bind Screen Recording TCC to this signed bundle early (one system dialog).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !CaptureEngine.hasScreenRecordingPermission() {
                _ = CaptureEngine.requestScreenRecordingPermission()
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        teardownForQuit()
        return .terminateNow
    }

    private func teardownForQuit() {
        OCRManager.cancel()
        CaptureEngine.cancelInteractiveCapture()
        HotkeyManager.shared.unregister()

        overlayWindow?.close()
        overlayWindow = nil
        preferencesWindow?.close()
        preferencesWindow = nil
        historyWindow?.close()
        historyWindow = nil

        for pin in pinControllers {
            pin.close()
        }
        pinControllers.removeAll()

        // Abort any nested modal sessions (old OCR alerts).
        if NSApp.modalWindow != nil {
            NSApp.abortModal()
            NSApp.stopModal()
        }
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ctdoshot")
        }
        rebuildMenu()
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        let reopenItem = NSMenuItem(
            title: "menu.reopen".localized,
            action: #selector(reopenLastCapture),
            keyEquivalent: "r"
        )
        reopenItem.isEnabled = (lastCapturedImage != nil)
        menu.addItem(reopenItem)

        menu.addItem(NSMenuItem(
            title: "menu.history".localized,
            action: #selector(openHistoryGallery),
            keyEquivalent: "h"
        ))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "menu.capture_screen".localized,
            action: #selector(triggerFullscreenCapture),
            keyEquivalent: "3"
        ))

        let areaItem = NSMenuItem(
            title: "menu.capture_area".localized,
            action: #selector(triggerInteractiveCapture),
            keyEquivalent: "s"
        )
        areaItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(areaItem)

        let windowItem = NSMenuItem(
            title: "menu.capture_window".localized,
            action: #selector(triggerWindowCapture),
            keyEquivalent: "w"
        )
        windowItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(windowItem)

        let lastRegionItem = NSMenuItem(
            title: "menu.capture_last_region".localized,
            action: #selector(triggerLastRegionCapture),
            keyEquivalent: "l"
        )
        lastRegionItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(lastRegionItem)

        let scrollItem = NSMenuItem(
            title: "menu.scrolling_capture".localized,
            action: #selector(triggerScrollingCapture),
            keyEquivalent: "s"
        )
        scrollItem.keyEquivalentModifierMask = [.command, .shift, .option]
        menu.addItem(scrollItem)

        let ocrItem = NSMenuItem(
            title: "menu.recognize_ocr".localized,
            action: #selector(triggerOCRQuick),
            keyEquivalent: "o"
        )
        ocrItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(ocrItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "menu.settings".localized,
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())

        // Explicit Cmd+Q quit — always works for menu-bar apps.
        let quitItem = NSMenuItem(
            title: "menu.quit".localized,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func setupHotkey() {
        let mgr = HotkeyManager.shared
        mgr.handlers[HotkeyManager.carbonID(for: .captureArea)] = { [weak self] in
            self?.triggerInteractiveCapture()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .captureFullscreen)] = { [weak self] in
            self?.triggerFullscreenCapture()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .ocrQuick)] = { [weak self] in
            self?.triggerOCRQuick()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .captureWindow)] = { [weak self] in
            self?.triggerWindowCapture()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .captureLastRegion)] = { [weak self] in
            self?.triggerLastRegionCapture()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .captureScrolling)] = { [weak self] in
            self?.triggerScrollingCapture()
        }
        mgr.handlers[HotkeyManager.carbonID(for: .openHistory)] = { [weak self] in
            self?.openHistoryGallery()
        }
        mgr.registerAll()
    }

    @objc public func reopenLastCapture() {
        guard let img = lastCapturedImage else { return }
        showEditorWindow(with: img)
    }

    @objc public func openHistoryGallery() {
        if historyWindow == nil {
            let galleryView = HistoryGalleryView { [weak self] selectedImage in
                self?.historyWindow?.close()
                self?.showEditorWindow(with: selectedImage)
            }
            let hostingController = NSHostingController(rootView: galleryView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "menu.history".localized
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 720, height: 480))
            window.center()
            historyWindow = window
        }
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func triggerInteractiveCapture() {
        CaptureEngine.captureRegionInteractive { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else { return }
            self.lastCapturedImage = image
            self.rebuildMenu()
            self.showEditorWindow(with: image)
        }
    }

    @objc public func triggerFullscreenCapture() {
        CaptureEngine.captureFullScreen { [weak self] image in
            guard let self = self, let image = image else { return }
            self.lastCapturedImage = image
            self.rebuildMenu()

            let defaults = UserDefaults.standard
            let afterShow = defaults.object(forKey: "afterShow") != nil
                ? defaults.bool(forKey: "afterShow")
                : true

            if afterShow {
                self.showEditorWindow(with: image)
            } else {
                self.processFinalOutput(image: image)
            }
        }
    }

    @objc public func triggerWindowCapture() {
        CaptureEngine.captureActiveWindow { [weak self] image in
            guard let self = self, let image = image else { return }
            self.lastCapturedImage = image
            self.rebuildMenu()
            self.showEditorWindow(with: image)
        }
    }

    @objc public func triggerLastRegionCapture() {
        CaptureEngine.captureLastRegion { [weak self] image in
            guard let self = self, let image = image else { return }
            self.lastCapturedImage = image
            self.rebuildMenu()
            self.showEditorWindow(with: image)
        }
    }

    @objc public func triggerScrollingCapture() {
        CaptureEngine.captureScrolling { [weak self] image, isPartial in
            guard let self = self, let image = image else { return }
            if isPartial {
                self.notify(title: "ctdoshot", body: "capture.scroll_partial".localized)
            }
            self.lastCapturedImage = image
            self.rebuildMenu()
            self.showEditorWindow(with: image)
        }
    }

    /// Region → OCR → copy clipboard + banner. **No modal alert** (that blocked quit).
    @objc public func triggerOCRQuick() {
        guard !isOCRBusy else { return }
        CaptureEngine.captureRegionInteractive { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else { return }
            self.runOCR(on: image, sourceLabel: "OCR")
        }
    }

    @objc public func openSettings() {
        if preferencesWindow == nil {
            let prefView = PreferencesView()
            let hostingController = NSHostingController(rootView: prefView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "pref.title".localized
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 600, height: 560))
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showEditorWindow(with image: NSImage) {
        var mutableImage = image
        let editorView = DrawingCanvasView(
            bgImage: Binding(get: { mutableImage }, set: { mutableImage = $0 }),
            onCopy: { [weak self] finalImg in
                // ⌃C / ⌘C: copy annotated image only; keep editor open.
                let opts = OutputManager.currentOptions()
                let result = OutputManager.process(
                    image: finalImg,
                    options: OutputOptions(
                        copy: true,
                        save: false,
                        downscaleRetina: opts.downscaleRetina,
                        saveFormat: opts.saveFormat,
                        saveDirectory: opts.saveDirectory
                    )
                )
                if result.didCopy {
                    self?.notify(title: "ctdoshot", body: "notif.copied".localized)
                }
            },
            onSave: { [weak self] finalImg in
                // Save (+ copy per prefs) and close. Path also goes to clipboard when copy is on.
                self?.processFinalOutput(image: finalImg)
                self?.overlayWindow?.close()
            },
            onPin: { [weak self] finalImg in
                self?.pinImageOnScreen(image: finalImg)
                self?.overlayWindow?.close()
            },
            onOCR: { [weak self] finalImg in
                self?.runOCR(on: finalImg, sourceLabel: "OCR")
            },
            onCancel: { [weak self] in
                self?.overlayWindow?.close()
            }
        )

        let hostingController = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: hostingController)
        let contentW = min(max(image.size.width + 40, 960), 1400)
        let contentH = min(max(image.size.height + 80, 640), 1000)
        window.setContentSize(NSSize(width: contentW, height: contentH))
        window.minSize = NSSize(width: 900, height: 480)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.title = "ctdoshot Editor"
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.overlayWindow = window
    }

    /// Shared OCR path: copy text + non-blocking notification. Never `runModal`.
    private func runOCR(on image: NSImage, sourceLabel: String) {
        if isOCRBusy {
            OCRManager.cancel()
        }
        isOCRBusy = true
        notify(title: sourceLabel, body: "ocr.working".localized)

        OCRManager.recognizeText(in: image) { [weak self] text in
            self?.isOCRBusy = false
            guard let text = text, !text.isEmpty else {
                self?.notify(title: sourceLabel, body: "ocr.failed".localized)
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            let preview = text.count > 180 ? String(text.prefix(180)) + "…" : text
            self?.notify(
                title: sourceLabel,
                body: "ocr.copied_alert".localized + "\n" + preview
            )
        }
    }

    func processFinalOutput(image: NSImage, forceOptions: OutputOptions? = nil) {
        let options = forceOptions ?? OutputManager.currentOptions()
        let shouldPersist = options.save || options.copy
        guard shouldPersist else { return }

        // Save/copy first (snappy). OCR for history is best-effort and never blocks quit.
        let result = OutputManager.process(image: image, options: options)

        if result.fileURL != nil || result.didCopy {
            let body: String
            switch (result.fileURL != nil, result.didCopy) {
            case (true, true): body = "notif.saved_copied".localized
            case (true, false): body = "notif.saved".localized
            case (false, true): body = "notif.copied".localized
            default: body = "notif.saved_copied".localized
            }
            notify(title: "ctdoshot", body: body, subtitle: result.fileURL?.lastPathComponent)
        }

        guard let url = result.fileURL else { return }

        // History immediately; OCR enrichment is optional and never blocks quit.
        HistoryManager.shared.addShot(filePath: url.path, ocrText: nil)
        OCRManager.recognizeText(in: image) { ocrText in
            guard let ocrText = ocrText, !ocrText.isEmpty else { return }
            HistoryManager.shared.updateOCR(forFilePath: url.path, ocrText: ocrText)
        }
    }

    private func pinImageOnScreen(image: NSImage) {
        let w = max(120, min(image.size.width / 2, 640))
        let h = max(80, min(image.size.height / 2, 480))
        let frame = NSRect(x: 200, y: 200, width: w, height: h)
        let pinController = PinWindowController(image: image, frame: frame)
        pinController.showWindow(nil)
        pinControllers.append(pinController)

        // Drop controller as soon as the pin window closes (avoid session-long leaks).
        if let window = pinController.window {
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self, weak pinController] _ in
                guard let self = self, let pinController = pinController else { return }
                self.pinControllers.removeAll { $0 === pinController }
            }
        }

        // Safety prune for any already-closed controllers.
        pinControllers.removeAll { $0.window?.isVisible != true && $0.window != pinController.window }
    }

    private func notify(title: String, body: String, subtitle: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    @objc public func quit() {
        teardownForQuit()
        NSApp.terminate(nil)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
