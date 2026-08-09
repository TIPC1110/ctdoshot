import XCTest
@testable import ctdoshotCore

final class CaptureGeometryTests: XCTestCase {
    func testCocoaToTopLeftInDisplay() {
        // Display frame cocoa: origin (100,200) size 800x600
        // Selection cocoa global: (200, 300, 100, 50) → bottom-left based
        let display = CGRect(x: 100, y: 200, width: 800, height: 600)
        let sel = CGRect(x: 200, y: 300, width: 100, height: 50)
        let tl = CaptureGeometry.topLeftSourceRect(selectionGlobalCocoa: sel, displayCocoaFrame: display)
        // local cocoa y = 300-200 = 100; topLeftY = 600 - (100+50) = 450
        XCTAssertEqual(tl.origin.x, 100, accuracy: 0.1)
        XCTAssertEqual(tl.origin.y, 450, accuracy: 0.1)
        XCTAssertEqual(tl.width, 100, accuracy: 0.1)
        XCTAssertEqual(tl.height, 50, accuracy: 0.1)
    }

    func testClampToDisplay() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        let overflow = CGRect(x: 90, y: 90, width: 50, height: 50)
        let c = CaptureGeometry.clamp(overflow, to: display)
        XCTAssertLessThanOrEqual(c.maxX, 100.1)
        XCTAssertLessThanOrEqual(c.maxY, 100.1)
    }
}
