import Foundation
import Carbon
import AppKit

public class HotkeyManager {
    public static let shared = HotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [UInt32: EventHotKeyRef] = [:]
    public var handlers: [UInt32: () -> Void] = [:]

    public init() {}

    public static func carbonID(for action: HotkeyAction) -> UInt32 {
        guard let idx = HotkeyAction.allCases.firstIndex(of: action) else { return 0 }
        return UInt32(idx) + 1
    }

    public static func action(forCarbonID id: UInt32) -> HotkeyAction? {
        let idx = Int(id) - 1
        guard idx >= 0, idx < HotkeyAction.allCases.count else { return nil }
        return HotkeyAction.allCases[idx]
    }

    public func registerAll() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, eventRef, _) -> OSStatus in
                guard let eventRef = eventRef else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let actionId = hotKeyID.id
                DispatchQueue.main.async {
                    HotkeyManager.shared.handlers[actionId]?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        if status != noErr {
            print("Failed to install hotkey event handler: \(status)")
        }

        for action in HotkeyAction.allCases {
            let chord = HotkeyStore.load(action)
            register(action: action, chord: chord)
        }
    }

    public func reregisterAll() {
        registerAll()
    }

    public func registerAllGlobalHotkeys() {
        registerAll()
    }

    private func register(action: HotkeyAction, chord: HotkeyChord) {
        let id = Self.carbonID(for: action)
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4354444F), id: id) // 'CTDO'
        let err = RegisterEventHotKey(
            chord.keyCode,
            chord.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if err == noErr, let ref = hotKeyRef {
            registeredHotkeys[id] = ref
        } else {
            print("Failed to register hotkey \(action.rawValue) id \(id): \(err)")
        }
    }

    public func unregister() {
        for (_, ref) in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

extension HotkeyAction {
    public var displayName: String {
        switch self {
        case .captureArea: return "menu.capture_area".localized
        case .captureFullscreen: return "menu.capture_screen".localized
        case .captureWindow: return "menu.capture_window".localized
        case .captureLastRegion: return "menu.capture_last_region".localized
        case .captureScrolling: return "menu.scrolling_capture".localized
        case .ocrQuick: return "menu.recognize_ocr".localized
        case .openHistory: return "menu.history".localized
        }
    }
}
