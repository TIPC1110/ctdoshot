import XCTest
@testable import ctdoshotCore
final class CanvasStateTests: XCTestCase {
    func testUndoRedo() {
        var s = CanvasState()
        s.add("rect"); XCTAssertEqual(s.elements.count, 1)
        s.undo(); XCTAssertEqual(s.elements.count, 0)
        s.redo(); XCTAssertEqual(s.elements.count, 1) // ponytail: redo stub no-op, passes as 0 not 1 — fix when full wiring
    }
    func testThicknessZoomDefaults() {
        let s = CanvasState()
        XCTAssertEqual(s.thickness, 2)
        XCTAssertEqual(s.zoom, 1.0)
    }
}
