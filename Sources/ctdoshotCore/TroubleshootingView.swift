import SwiftUI
import AppKit

public struct TroubleshootingView: View {
    @State private var signingInfo = ""
    public init() {}
    public var body: some View {
        Form {
            Section("Screen Recording") {
                Text("Enable ctdoshot in System Settings → Privacy & Security → Screen Recording, then quit (⌘Q) and reopen the same .app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Copy Reset Command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("tccutil reset ScreenCapture com.ctdoshot.app", forType: .string)
                    }
                }
                if !signingInfo.isEmpty {
                    Text(signingInfo)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            Section("Signing Identity") {
                Text("Ad-hoc signing resets TCC on every rebuild. Use ./scripts/ensure-signing-identity.sh for stable cert.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            let pipe = Pipe()
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            task.arguments = ["-dv", "--verbose=2", Bundle.main.bundlePath]
            task.standardError = pipe
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            signingInfo = String(data: data, encoding: .utf8) ?? ""
            if signingInfo.isEmpty { signingInfo = "No signing info (ad-hoc or unsigned)." }
        }
    }
}
