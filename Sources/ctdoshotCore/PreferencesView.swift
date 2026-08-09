import SwiftUI
import AppKit
import ServiceManagement

public struct PreferencesView: View {
    @State private var selectedTab = 0
    @ObservedObject private var langManager = LanguageManager.shared

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("pref.tab_general".localized, systemImage: "gearshape")
                }
                .tag(0)

            HotkeysSettingsView()
                .tabItem {
                    Label("pref.tab_hotkeys".localized, systemImage: "keyboard")
                }
                .tag(1)

            AdvancedSettingsView()
                .tabItem {
                    Label("pref.tab_advanced".localized, systemImage: "slider.horizontal.3")
                }
                .tag(2)
        }
        .padding(20)
        .frame(width: 580, height: 550)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var langManager = LanguageManager.shared

    @AppStorage("backgroundStyle") private var backgroundStyle = "Transparent"
    @AppStorage("savePath") private var savePath = OutputManager.defaultSaveDir.path
    @AppStorage("saveFormat") private var saveFormat = "Auto"
    @AppStorage("downscaleRetina") private var downscaleRetina = false
    @AppStorage("scrollMaxHeight") private var scrollMaxHeight = "20.000"
    @AppStorage("launchAtStartup") private var launchAtStartup = false

    @AppStorage("afterShow") private var afterShow = true
    @AppStorage("afterCopy") private var afterCopy = true
    @AppStorage("afterSave") private var afterSave = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("pref.language".localized).font(.headline)
                Picker("", selection: $langManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            Divider()

            Text("pref.bg_title".localized).font(.headline)
            HStack(spacing: 16) {
                BgOptionBox(title: "pref.bg_wallpaper".localized, icon: "desktopcomputer", isSelected: backgroundStyle == "Wallpaper") { backgroundStyle = "Wallpaper" }
                BgOptionBox(title: "pref.bg_transparent".localized, icon: "square.dashed", isSelected: backgroundStyle == "Transparent") { backgroundStyle = "Transparent" }
                BgOptionBox(title: "pref.bg_solid".localized, icon: "square.fill", isSelected: backgroundStyle == "Solid Color") { backgroundStyle = "Solid Color" }
                BgOptionBox(title: "pref.bg_trim".localized, icon: "crop", isSelected: backgroundStyle == "Trim shadow") { backgroundStyle = "Trim shadow" }
            }

            Divider()

            HStack {
                Text("pref.folder".localized)
                TextField("", text: $savePath).disabled(true)
                Button("pref.choose".localized) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        savePath = url.path
                    }
                }
            }

            HStack {
                Text("pref.save_format".localized)
                Picker("", selection: $saveFormat) {
                    Text("PNG").tag("PNG")
                    Text("Auto (PNG/JPEG)").tag("Auto")
                }
                .pickerStyle(.radioGroup)
            }

            Toggle("pref.downscale_retina".localized, isOn: $downscaleRetina)

            Divider()

            HStack {
                Text("pref.scroll_max".localized)
                TextField("", text: $scrollMaxHeight).frame(width: 80)
                Text("px")
            }

            Divider()

            Toggle("pref.autostart".localized, isOn: $launchAtStartup)
                .onChange(of: launchAtStartup) { newValue in
                    if #available(macOS 13.0, *) {
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                }

            HStack(spacing: 20) {
                Text("pref.after_shot".localized)
                Toggle("pref.after_show".localized, isOn: $afterShow)
                Toggle("pref.after_copy".localized, isOn: $afterCopy)
                Toggle("pref.after_save".localized, isOn: $afterSave)
            }
        }
        .padding()
    }
}

struct BgOptionBox: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon).font(.largeTitle)
                Text(title).font(.caption)
            }
            .frame(width: 100, height: 70)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// Owns the NSEvent local monitor so SwiftUI `@State` does not need to capture a struct `self`.
final class HotkeyRecorderController: ObservableObject {
    @Published var recordingAction: HotkeyAction?
    @Published var conflictMessage: String?
    @Published var displayByAction: [HotkeyAction: String] = [:]

    private var eventMonitor: Any?

    init() {
        refreshDisplays()
    }

    deinit {
        stopRecording()
    }

    func refreshDisplays() {
        var map: [HotkeyAction: String] = [:]
        for action in HotkeyAction.allCases {
            map[action] = HotkeyStore.load(action).displayString
        }
        displayByAction = map
    }

    func displayString(for action: HotkeyAction) -> String {
        if recordingAction == action {
            return "hotkey.recording".localized
        }
        return displayByAction[action] ?? HotkeyStore.load(action).displayString
    }

    func beginRecording(_ action: HotkeyAction) {
        stopRecording()
        conflictMessage = nil
        recordingAction = action

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Esc cancels recording without changing the chord.
            if event.keyCode == 53 {
                DispatchQueue.main.async { self.stopRecording() }
                return nil
            }

            // Ignore pure modifier presses.
            let pureModifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if pureModifiers.contains(event.keyCode) {
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let chord = HotkeyChord(
                keyCode: UInt32(event.keyCode),
                modifiers: .init(
                    cmd: flags.contains(.command),
                    shift: flags.contains(.shift),
                    option: flags.contains(.option),
                    control: flags.contains(.control)
                )
            )

            if let other = HotkeyStore.findConflict(for: action, chord: chord) {
                NSSound.beep()
                DispatchQueue.main.async {
                    let template = "hotkey.conflict".localized
                    if template.contains("%@") {
                        self.conflictMessage = String(format: template, other.displayName)
                    } else {
                        self.conflictMessage = "\(template) \(other.displayName)"
                    }
                }
                return nil
            }

            HotkeyStore.save(action, chord: chord)
            HotkeyManager.shared.reregisterAll()
            DispatchQueue.main.async {
                self.conflictMessage = nil
                self.refreshDisplays()
                self.stopRecording()
            }
            return nil
        }
    }

    func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        recordingAction = nil
    }
}

struct HotkeysSettingsView: View {
    @StateObject private var recorder = HotkeyRecorderController()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pref.tab_hotkeys".localized).font(.headline)
            Text("pref.hotkeys_hint".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let conflict = recorder.conflictMessage {
                Text(conflict)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(HotkeyAction.allCases, id: \.rawValue) { action in
                        HotkeyRecordRow(
                            label: action.displayName,
                            shortcut: recorder.displayString(for: action),
                            isRecording: recorder.recordingAction == action,
                            onRecord: { recorder.beginRecording(action) }
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .onAppear { recorder.refreshDisplays() }
        .onDisappear { recorder.stopRecording() }
    }
}

struct HotkeyRecordRow: View {
    let label: String
    let shortcut: String
    let isRecording: Bool
    let onRecord: () -> Void

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: onRecord) {
                Text(shortcut)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(
                isRecording
                    ? "hotkey.recording".localized
                    : "hotkey.row_help".localized + " " + shortcut
            )
        }
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("ocrLanguage") private var ocrLanguage = "English+"
    @AppStorage("removeLineBreaks") private var removeLineBreaks = false
    @AppStorage("actionOnEscCopy") private var actionOnEscCopy = true
    @AppStorage("actionOnEscSave") private var actionOnEscSave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("pref.ocr_lang".localized)
                Picker("", selection: $ocrLanguage) {
                    Text("English+").tag("English+")
                    Text("Vietnamese").tag("Vietnamese")
                    Text("Japanese").tag("Japanese")
                }
            }

            Toggle("pref.remove_line_breaks".localized, isOn: $removeLineBreaks)
            Divider()

            HStack(spacing: 20) {
                Text("pref.action_on_esc".localized)
                Toggle("pref.after_copy".localized, isOn: $actionOnEscCopy)
                Toggle("pref.after_save".localized, isOn: $actionOnEscSave)
            }

            Spacer()
        }
        .padding()
    }
}
