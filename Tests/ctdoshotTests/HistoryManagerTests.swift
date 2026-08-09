import XCTest
@testable import ctdoshotCore

final class HistoryManagerTests: XCTestCase {
    func testUpdateOCRForExistingItemPreservesIdentity() {
        let manager = HistoryManager.shared
        let dummyPath = "/tmp/test_shot_\(UUID().uuidString).png"
        
        manager.addShot(filePath: dummyPath, ocrText: nil)
        
        guard let originalItem = manager.historyItems.first(where: { $0.filePath == dummyPath }) else {
            XCTFail("Item should exist after addShot")
            return
        }
        XCTAssertNil(originalItem.ocrText)
        
        let recognized = "Recognized OCR Content"
        manager.updateOCR(forFilePath: dummyPath, ocrText: recognized)
        
        guard let updatedItem = manager.historyItems.first(where: { $0.filePath == dummyPath }) else {
            XCTFail("Item should still exist after updateOCR")
            return
        }
        XCTAssertEqual(updatedItem.ocrText, recognized)
        XCTAssertEqual(updatedItem.id, originalItem.id)
        XCTAssertEqual(updatedItem.date, originalItem.date)
        
        // Clean up memory array for test run
        manager.historyItems.removeAll(where: { $0.filePath == dummyPath })
    }

    func testUpdateOCRNonexistentPathIsNoOp() {
        let manager = HistoryManager.shared
        let initialCount = manager.historyItems.count
        manager.updateOCR(forFilePath: "/tmp/nonexistent_\(UUID().uuidString).png", ocrText: "Sample")
        XCTAssertEqual(manager.historyItems.count, initialCount)
    }
}
