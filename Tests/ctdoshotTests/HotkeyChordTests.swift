import XCTest
import Carbon
@testable import ctdoshotCore

final class HotkeyChordTests: XCTestCase {
    func testRoundTripJSON() throws {
        let c = HotkeyChord(keyCode: 1, modifiers: HotkeyChord.Modifiers(cmd: true, shift: true, option: false, control: false))
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(HotkeyChord.self, from: data)
        XCTAssertEqual(decoded.keyCode, 1)
        XCTAssertTrue(decoded.modifiers.cmd)
        XCTAssertTrue(decoded.modifiers.shift)
    }

    func testCarbonFlags() {
        let c = HotkeyChord(keyCode: 1, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        // cmdKey | shiftKey from Carbon
        XCTAssertEqual(c.carbonModifiers & UInt32(cmdKey), UInt32(cmdKey))
        XCTAssertEqual(c.carbonModifiers & UInt32(shiftKey), UInt32(shiftKey))
    }

    func testConflictDetection() {
        let a = HotkeyChord(keyCode: 1, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        let b = HotkeyChord(keyCode: 1, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        let c = HotkeyChord(keyCode: 2, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        XCTAssertTrue(a.conflicts(with: b))
        XCTAssertFalse(a.conflicts(with: c))
    }

    func testDisplayString() {
        let c = HotkeyChord(keyCode: 1, modifiers: .init(cmd: true, shift: true, option: false, control: false))
        // keyCode 1 == "S" on US layout for our mapping table
        XCTAssertTrue(c.displayString.contains("⌘") || c.displayString.contains("Cmd"))
    }
}
