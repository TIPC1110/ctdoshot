import AppKit
import SwiftUI

// ponytail: Floating recording HUD panel using native NSPanel + SwiftUI, minimal & zero third-party deps
@MainActor
public final class HUDController {
    public static let shared = HUDController()

    private var hudWindow: NSPanel?
    public var isVisible: Bool {
        hudWindow?.isVisible ?? false
    }

    public init() {}

    public func show(onStop: @escaping () -> Void) {
        show(recorder: .shared, onStop: onStop)
    }

    public func show(recorder: ScreenRecorder, onStop: @escaping () -> Void) {
        if hudWindow == nil {
            let hudView = FloatingHUDView(recorder: recorder, onStop: { [weak self] in
                self?.hide()
                onStop()
            })
            let hosting = NSHostingView(rootView: hudView)
            hosting.setFrameSize(NSSize(width: 240, height: 48))

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 240, height: 48),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.contentView = hosting
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            self.hudWindow = panel
        }

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 120
            let y = screenFrame.minY + 40
            hudWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow?.orderFront(nil)
    }

    public func hide() {
        hudWindow?.orderOut(nil)
        hudWindow = nil
    }
}

private struct FloatingHUDView: View {
    @ObservedObject var recorder: ScreenRecorder
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Blinking status indicator
            Circle()
                .fill(recorder.state == .paused ? Color.orange : Color.red)
                .frame(width: 10, height: 10)

            // Timer
            Text(formattedTime(recorder.elapsedTime))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 48)

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.3))

            // Pause / Resume button
            Button(action: {
                if recorder.state == .paused {
                    recorder.resumeRecording()
                } else if recorder.state == .recording {
                    recorder.pauseRecording()
                }
            }) {
                Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(recorder.state == .paused ? "hud.resume".localized : "hud.pause".localized)

            // Mic toggle button
            Button(action: {
                recorder.toggleMic()
            }) {
                Image(systemName: recorder.isMicEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(recorder.isMicEnabled ? .green : .white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Microphone")

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .help("hud.stop".localized)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
