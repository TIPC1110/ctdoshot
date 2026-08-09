import Foundation
import AppKit
import AVFoundation
import CoreMedia

public struct ShotItem: Identifiable, Codable, Equatable {
    public enum MediaType: String, Codable {
        case image
        case video
        case gif
    }

    public let id: UUID
    public let date: Date
    public let filePath: String
    public let ocrText: String?
    public let mediaType: MediaType
    public let duration: TimeInterval?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        filePath: String,
        ocrText: String?,
        mediaType: MediaType = .image,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.date = date
        self.filePath = filePath
        self.ocrText = ocrText
        self.mediaType = mediaType
        self.duration = duration
    }

    public var image: NSImage? {
        return NSImage(contentsOfFile: filePath)
    }

    public var videoThumbnail: NSImage? {
        guard mediaType == .video || mediaType == .gif else { return image }
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        }
        return nil
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

    public func addShot(
        filePath: String,
        ocrText: String?,
        mediaType: ShotItem.MediaType = .image,
        duration: TimeInterval? = nil
    ) {
        let newItem = ShotItem(
            id: UUID(),
            date: Date(),
            filePath: filePath,
            ocrText: ocrText,
            mediaType: mediaType,
            duration: duration
        )
        historyItems.insert(newItem, at: 0)
        if historyItems.count > 100 {
            historyItems = Array(historyItems.prefix(100))
        }
        saveHistory()
    }

    public func updateOCR(forFilePath path: String, ocrText: String) {
        guard let idx = historyItems.firstIndex(where: { $0.filePath == path }) else { return }
        let old = historyItems[idx]
        historyItems[idx] = ShotItem(
            id: old.id,
            date: old.date,
            filePath: old.filePath,
            ocrText: ocrText,
            mediaType: old.mediaType,
            duration: old.duration
        )
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
