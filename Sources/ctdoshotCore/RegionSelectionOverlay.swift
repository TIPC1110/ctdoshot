import AppKit
import CoreGraphics

/// Full-screen dimmed overlay: drag to select a region, Esc to cancel.
final class RegionSelectionOverlay {
    private var panels: [NSPanel] = []
    private var completion: ((CGRect?) -> Void)?

    /// Present overlays on all screens. Completion receives **global** CGRect in
    /// Cocoa bottom-left coordinates, or nil if cancelled.
    func begin(completion: @escaping (CGRect?) -> Void) {
        cancel(notify: false)
        self.completion = completion

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.setFrame(screen.frame, display: true)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.hidesOnDeactivate = false
            panel.hasShadow = false
            panel.acceptsMouseMovedEvents = true

            let view = SelectionView(frame: panel.contentView?.bounds ?? .zero)
            view.autoresizingMask = [.width, .height]
            view.onFinished = { [weak self] localRect in
                guard let self = self else { return }
                if let localRect = localRect {
                    // Convert panel-local → global Cocoa coords
                    let global = CGRect(
                        x: panel.frame.origin.x + localRect.origin.x,
                        y: panel.frame.origin.y + localRect.origin.y,
                        width: localRect.width,
                        height: localRect.height
                    )
                    self.finish(with: global)
                } else {
                    self.finish(with: nil)
                }
            }
            panel.contentView = view
            panel.makeKeyAndOrderFront(nil)
            panels.append(panel)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func cancel(notify: Bool = true) {
        for p in panels { p.orderOut(nil); p.close() }
        panels.removeAll()
        if notify {
            let cb = completion
            completion = nil
            DispatchQueue.main.async { cb?(nil) }
        } else {
            completion = nil
        }
    }

    private func finish(with rect: CGRect?) {
        let cb = completion
        completion = nil
        for p in panels { p.orderOut(nil); p.close() }
        panels.removeAll()
        DispatchQueue.main.async { cb?(rect) }
    }
}

// MARK: - Selection view

private final class SelectionView: NSView {
    var onFinished: ((CGRect?) -> Void)?
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var tracking: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTracking()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTracking()
    }

    private func updateTracking() {
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dim entire screen
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard let start = startPoint, let current = currentPoint else {
            drawHint()
            return
        }

        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        // Clear hole for selection (redraw dim then cut)
        NSGraphicsContext.saveGraphicsState()
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: rect).reversed)
        path.setClip()
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Selection border
        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 2
        border.stroke()

        // Size badge
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attrs)
        let badge = CGRect(
            x: rect.midX - size.width / 2 - 6,
            y: max(rect.minY - size.height - 12, 8),
            width: size.width + 12,
            height: size.height + 6
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        label.draw(at: CGPoint(x: badge.minX + 6, y: badge.minY + 3), withAttributes: attrs)
    }

    private func drawHint() {
        let text = "Drag to select · Esc to cancel"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height * 0.08)
        let badge = CGRect(x: origin.x - 12, y: origin.y - 6, width: size.width + 24, height: size.height + 12)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()
        text.draw(at: origin, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let start = startPoint, let end = currentPoint else {
            onFinished?(nil)
            return
        }
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        startPoint = nil
        currentPoint = nil
        // Tiny click = cancel
        if rect.width < 4 || rect.height < 4 {
            onFinished?(nil)
        } else {
            onFinished?(rect)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinished?(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onFinished?(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
