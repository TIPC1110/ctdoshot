import XCTest
@testable import ctdoshotCore

final class HistorySearchTests: XCTestCase {
    private func sampleItems() -> [ShotItem] {
        [
            ShotItem(
                id: UUID(),
                date: Date(timeIntervalSince1970: 1),
                filePath: "/tmp/shots/login_screen.png",
                ocrText: "Welcome back to Dashboard"
            ),
            ShotItem(
                id: UUID(),
                date: Date(timeIntervalSince1970: 2),
                filePath: "/tmp/shots/receipt_2024.jpg",
                ocrText: "Total: $42.00"
            ),
            ShotItem(
                id: UUID(),
                date: Date(timeIntervalSince1970: 3),
                filePath: "/tmp/shots/empty.png",
                ocrText: nil
            ),
        ]
    }

    func testEmptyQueryReturnsAll() {
        let items = sampleItems()
        XCTAssertEqual(HistorySearch.filter(items: items, query: "").count, 3)
        XCTAssertEqual(HistorySearch.filter(items: items, query: "   ").count, 3)
    }

    func testFilterByOCR() {
        let items = sampleItems()
        let result = HistorySearch.filter(items: items, query: "dashboard")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.filePath, "/tmp/shots/login_screen.png")
    }

    func testFilterByFilename() {
        let items = sampleItems()
        let result = HistorySearch.filter(items: items, query: "receipt")
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first?.filePath.contains("receipt") == true)
    }

    func testFilterIsCaseInsensitive() {
        let items = sampleItems()
        let byOCR = HistorySearch.filter(items: items, query: "TOTAL")
        XCTAssertEqual(byOCR.count, 1)
        let byName = HistorySearch.filter(items: items, query: "LOGIN_SCREEN")
        XCTAssertEqual(byName.count, 1)
    }

    func testNoMatchReturnsEmpty() {
        let items = sampleItems()
        XCTAssertTrue(HistorySearch.filter(items: items, query: "zzz-no-such").isEmpty)
    }

    func testManagerFilteredDelegatesToHistorySearch() {
        let manager = HistoryManager()
        // Avoid touching shared disk history: assign in-memory only.
        let items = sampleItems()
        manager.historyItems = items
        XCTAssertEqual(manager.filtered(query: "42.00").count, 1)
        XCTAssertEqual(manager.filtered(query: "").count, items.count)
    }
}
