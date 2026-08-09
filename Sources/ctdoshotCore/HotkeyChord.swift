import Foundation
import Carbon

public struct HotkeyChord: Codable, Equatable, Hashable {
    public struct Modifiers: Codable, Equatable, Hashable {
        public var cmd: Bool
        public var shift: Bool
        public var option: Bool
        public var control: Bool
        public init(cmd: Bool, shift: Bool, option: Bool, control: Bool) {
            self.cmd = cmd; self.shift = shift; self.option = option; self.control = control
        }
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.cmd { m |= UInt32(cmdKey) }
        if modifiers.shift { m |= UInt32(shiftKey) }
        if modifiers.option { m |= UInt32(optionKey) }
        if modifiers.control { m |= UInt32(controlKey) }
        return m
    }

    public func conflicts(with other: HotkeyChord) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// Minimal US keymap for plan defaults; extend in implementation as needed.
    public var displayString: String {
        var parts: [String] = []
        if modifiers.control { parts.append("⌃") }
        if modifiers.option { parts.append("⌥") }
        if modifiers.shift { parts.append("⇧") }
        if modifiers.cmd { parts.append("⌘") }
        parts.append(Self.keyLabel(keyCode))
        return parts.joined()
    }

    public static func keyLabel(_ code: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 5: "G", 4: "H",
            12: "Q", 13: "W", 14: "E", 15: "R",
            17: "T", 16: "Y", 32: "U", 34: "I", 31: "O", 35: "P",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            37: "L", 45: "N", 46: "M", 11: "B", 9: "V", 8: "C", 7: "X", 6: "Z",
        ]
        return map[code] ?? "⌥\(code)"
    }
}

public enum HotkeyAction: String, CaseIterable, Codable {
    case captureArea
    case captureFullscreen
    case captureWindow
    case captureLastRegion
    case captureScrolling
    case ocrQuick
    case openHistory

    public var defaultsKey: String { "hotkey.\(rawValue)" }

    public var defaultChord: HotkeyChord {
        switch self {
        case .captureArea:
            return HotkeyChord(keyCode: 1, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        case .captureFullscreen:
            return HotkeyChord(keyCode: 20, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        case .captureWindow:
            return HotkeyChord(keyCode: 13, modifiers: .init(cmd: true, shift: true, option: false, control: false)) // W
        case .captureLastRegion:
            return HotkeyChord(keyCode: 37, modifiers: .init(cmd: true, shift: true, option: false, control: false)) // L
        case .captureScrolling:
            // Avoid ⌥⇧⌘S (easy mis-hit of area ⇧⌘S). Use ⌥⇧⌘X instead.
            return HotkeyChord(keyCode: 7, modifiers: .init(cmd: true, shift: true, option: true, control: false)) // ⌥⇧⌘X
        case .ocrQuick:
            return HotkeyChord(keyCode: 31, modifiers: .init(cmd: true, shift: false, option: true, control: true))
        case .openHistory:
            return HotkeyChord(keyCode: 4, modifiers: .init(cmd: true, shift: true, option: false, control: false)) // H
        }
    }
}

public enum HotkeyStore {
    public static func load(_ action: HotkeyAction) -> HotkeyChord {
        guard let data = UserDefaults.standard.data(forKey: action.defaultsKey),
              let c = try? JSONDecoder().decode(HotkeyChord.self, from: data) else {
            return action.defaultChord
        }
        return c
    }

    public static func save(_ action: HotkeyAction, chord: HotkeyChord) {
        if let data = try? JSONEncoder().encode(chord) {
            UserDefaults.standard.set(data, forKey: action.defaultsKey)
        }
    }

    public static func findConflict(for action: HotkeyAction, chord: HotkeyChord) -> HotkeyAction? {
        for other in HotkeyAction.allCases where other != action {
            if load(other).conflicts(with: chord) { return other }
        }
        return nil
    }
}
