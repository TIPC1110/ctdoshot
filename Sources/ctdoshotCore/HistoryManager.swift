import Foundation
import AppKit

public struct ShotItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let filePath: String
    public let ocrText: String?

    public init(id: UUID = UUID(), date: Date = Date(), filePath: String, ocrText: String?) {
        self.id = id
        self.date = date
        self.filePath = filePath
        self.ocrText = ocrText
    }

    public var image: NSImage? {
        return NSImage(contentsOfFile: filePath)
    }
}

public enum HistorySearch {
    public static func filter(items: [ShotItem], query: String) -> [ShotItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return items }
        return items.filter { item in
            let ocrMatch = (item.ocrText ?? "").localizedCaseInsensitiveContains(q)
            let nameMatch = URL(fileURLWithPath: item.filePath)
                .lastPathComponent
                .localizedCaseInsensitiveContains(q)
            return ocrMatch || nameMatch
        }
    }
}

public class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    @Published public var historyItems: [ShotItem] = []

    private var historyFile: URL {
        OutputManager.currentOptions().saveDirectory.appendingPathComponent("history.json")
    }

    public init() {
        loadHistory()
    }

    public func addShot(filePath: String, ocrText: String?) {
        let newItem = ShotItem(id: UUID(), date: Date(), filePath: filePath, ocrText: ocrText)
        historyItems.insert(newItem, at: 0)
        if historyItems.count > 100 {
            historyItems = Array(historyItems.prefix(100))
        }
        saveHistory()
    }

    public func updateOCR(forFilePath path: String, ocrText: String) {
        guard let idx = historyItems.firstIndex(where: { $0.filePath == path }) else { return }
        let old = historyItems[idx]
        historyItems[idx] = ShotItem(id: old.id, date: old.date, filePath: old.filePath, ocrText: ocrText)
        saveHistory()
    }

    public func filtered(query: String) -> [ShotItem] {
        HistorySearch.filter(items: historyItems, query: query)
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(historyItems)
            try data.write(to: historyFile)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }
        do {
            let data = try Data(contentsOf: historyFile)
            historyItems = try JSONDecoder().decode([ShotItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}
