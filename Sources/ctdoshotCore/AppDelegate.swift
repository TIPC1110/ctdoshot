import SwiftUI
import AppKit
import UserNotifications

public class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    public var statusItem: NSStatusItem?
    public var overlayWindow: NSWindow?
    public var preferencesWindow: NSWindow?
    public var historyWindow: NSWindow?
    public var lastCapturedImage: NSImage?
    private var pinControllers: [PinWindowController] = []
    private var isOCRBusy = false

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupNotifications()
        setupStatusBar()
        setupMainMenu()
        setupHotkey()

        NotificationCenter.default.addObserver(
            forName: Notification.Name("AppLanguageDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupMainMenu()
            self?.rebuildMenu()
        }

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

        let aboutItem = NSMenuItem(
            title: "menu.about".localized,
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())

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

        menu.addItem(NSMenuItem(
            title: "menu.help".localized,
            action: #selector(openHelpDocs),
            keyEquivalent: ""
        ))

        let servicesItem = NSMenuItem(title: "menu.services".localized, action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        menu.addItem(servicesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "menu.quit".localized,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        statusItem?.menu = menu
        setupMainMenu()
    }

    public func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "menu.app".localized)

        let aboutItem = NSMenuItem(
            title: "menu.about".localized,
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "menu.settings".localized,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())

        let servicesItem = NSMenuItem(title: "menu.services".localized, action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(
            title: "menu.hide".localized,
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "menu.hide_others".localized,
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "menu.show_all".localized,
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "menu.quit".localized,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "menu.file".localized)

        let closeItem = NSMenuItem(
            title: "menu.close_window".localized,
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenu.addItem(closeItem)

        let reopenItem = NSMenuItem(
            title: "menu.reopen".localized,
            action: #selector(reopenLastCapture),
            keyEquivalent: "r"
        )
        reopenItem.isEnabled = (lastCapturedImage != nil)
        fileMenu.addItem(reopenItem)

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "menu.edit".localized)

        editMenu.addItem(withTitle: "menu.undo".localized, action: Selector(("undo:")), keyEquivalent: "z")

        let redoItem = NSMenuItem(
            title: "menu.redo".localized,
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "menu.cut".localized, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "menu.copy".localized, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "menu.paste".localized, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "menu.select_all".localized, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "menu.view".localized)

        let zoomInItem = NSMenuItem(title: "menu.zoom_in".localized, action: Selector(("zoomIn:")), keyEquivalent: "+")
        zoomInItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "menu.zoom_out".localized, action: Selector(("zoomOut:")), keyEquivalent: "-")
        zoomOutItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomOutItem)

        let actualSizeItem = NSMenuItem(title: "menu.actual_size".localized, action: Selector(("actualSize:")), keyEquivalent: "0")
        actualSizeItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(actualSizeItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "menu.window".localized)

        let minimizeItem = NSMenuItem(
            title: "menu.minimize".localized,
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)

        let zoomWindowItem = NSMenuItem(
            title: "menu.zoom_window".localized,
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoomWindowItem)

        windowMenu.addItem(NSMenuItem.separator())

        let bringAllItem = NSMenuItem(
            title: "menu.bring_all_front".localized,
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(bringAllItem)

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // 6. Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "menu.help".localized)

        let helpDocItem = NSMenuItem(
            title: "menu.help".localized,
            action: #selector(openHelpDocs),
            keyEquivalent: "?"
        )
        helpDocItem.keyEquivalentModifierMask = [.command]
        helpMenu.addItem(helpDocItem)

        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc public func showAboutPanel() {
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "ctdoshot",
            .applicationVersion: "1.0.0",
            .version: "1",
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 ctdoshot. All rights reserved."
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func openHelpDocs() {
        if let url = URL(string: "https://github.com/ctdoshot/ctdoshot#readme") {
            NSWorkspace.shared.open(url)
        }
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
                
                let alert = NSAlert()
                alert.messageText = "OCR"
                alert.informativeText = "ocr.failed".localized
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
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

            let alert = NSAlert()
            alert.messageText = "ocr.copied_alert".localized
            alert.informativeText = text
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func processFinalOutput(image: NSImage, forceOptions: OutputOptions? = nil) {
        let options = forceOptions ?? OutputManager.currentOptions()
        let shouldPersist = options.save || options.copy
        guard shouldPersist else { return }

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
