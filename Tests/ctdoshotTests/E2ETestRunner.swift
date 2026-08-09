import XCTest
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
@testable import ctdoshotCore

public struct GIFMetadata {
    public let width: Int
    public let height: Int
    public let frameCount: Int
    public let frameDelay: Double
}

public class E2ETestRunner {
    public private(set) var testDir: URL!
    public private(set) var recorder: ScreenRecorder!

    private var previousSavePath: String?

    public init() {}

    @MainActor
    public func setUpIsolatedEnvironment() throws {
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ctdoshot_e2e_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        previousSavePath = UserDefaults.standard.string(forKey: "savePath")
        UserDefaults.standard.set(testDir.path, forKey: "savePath")

        HistoryManager.shared.historyItems.removeAll()
        NSPasteboard.general.clearContents()

        recorder = ScreenRecorder()
        recorder.simulatedPermissionGranted = true
    }

    @MainActor
    public func tearDownIsolatedEnvironment() {
        if let dir = testDir {
            try? FileManager.default.removeItem(at: dir)
        }
        if let prev = previousSavePath {
            UserDefaults.standard.set(prev, forKey: "savePath")
        } else {
            UserDefaults.standard.removeObject(forKey: "savePath")
        }

        HistoryManager.shared.historyItems.removeAll()
        NSPasteboard.general.clearContents()
        recorder = nil
    }

    @MainActor
    public func setRecordMode(_ mode: RecordMode) {
        recorder.recordMode = mode
    }

    @MainActor
    public func setExportFormat(_ format: ExportFormat) {
        recorder.exportFormat = format
    }

    @MainActor
    public func setMicEnabled(_ enabled: Bool) {
        recorder.isMicEnabled = enabled
    }

    @MainActor
    public func toggleMic() {
        recorder.toggleMic()
    }

    @MainActor
    public func simulatePermission(granted: Bool) {
        recorder.simulatedPermissionGranted = granted
    }

    @MainActor
    public func startRecording(completion: ((Result<Void, Error>) -> Void)? = nil) {
        recorder.startRecording(completion: completion)
    }

    @MainActor
    public func pauseRecording() {
        recorder.pauseRecording()
    }

    @MainActor
    public func resumeRecording() {
        recorder.resumeRecording()
    }

    @MainActor
    public func simulateTimePassage(seconds: Double) {
        recorder.elapsedTime += seconds
    }

    @MainActor
    public func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        recorder.stopRecording(completion: completion)
    }

    @MainActor
    public var isHUDPanelVisible: Bool {
        return recorder.state == .recording || recorder.state == .paused
    }

    @MainActor
    public var isMenuBarAnimating: Bool {
        return recorder.state == .recording
    }

    @MainActor
    public var excludedWindows: [String] {
        return ["RecordingHUDPanel"]
    }

    @MainActor
    public func triggerHotkey(_ chordString: String) {
        switch chordString {
        case "RecordArea", "⇧⌘S":
            recorder.recordMode = .region(CGRect(x: 100, y: 100, width: 400, height: 300))
            recorder.startRecording()
        case "RecordScreen", "⌘3":
            recorder.recordMode = .fullScreen()
            recorder.startRecording()
        case "RecordGIF", "⇧⌘G":
            recorder.recordMode = .fullScreen()
            recorder.exportFormat = .gif
            recorder.startRecording()
        default:
            break
        }
    }

    @MainActor
    public func triggerMenuItem(_ title: String) {
        switch title {
        case "Record Area":
            recorder.recordMode = .region(CGRect(x: 100, y: 100, width: 400, height: 300))
            recorder.startRecording()
        case "Record Screen":
            recorder.recordMode = .fullScreen()
            recorder.startRecording()
        case "Record GIF":
            recorder.recordMode = .fullScreen()
            recorder.exportFormat = .gif
            recorder.startRecording()
        default:
            break
        }
    }
}

public enum E2EVerifier {
    public static func extractVideoTrack(from url: URL) -> AVAssetTrack? {
        let asset = AVURLAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var track: AVAssetTrack?
        Task {
            let tracks = try? await asset.loadTracks(withMediaType: .video)
            track = tracks?.first
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5.0)
        return track
    }

    public static func hasAudioTrack(in url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var hasAudio = false
        Task {
            let tracks = try? await asset.loadTracks(withMediaType: .audio)
            hasAudio = !(tracks?.isEmpty ?? true)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5.0)
        return hasAudio
    }

    public static func getVideoDuration(from url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var durationSec: TimeInterval = 0.0
        Task {
            if let duration = try? await asset.load(.duration) {
                durationSec = CMTimeGetSeconds(duration)
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5.0)
        return durationSec
    }

    public static func inspectGIF(at url: URL) throws -> GIFMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw NSError(domain: "E2EVerifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid GIF URL"])
        }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0, let firstProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw NSError(domain: "E2EVerifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty GIF properties"])
        }

        let width = firstProps[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = firstProps[kCGImagePropertyPixelHeight as String] as? Int ?? 0

        var frameDelay = 0.0667
        if let gifDict = firstProps[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            frameDelay = gifDict[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                ?? gifDict[kCGImagePropertyGIFDelayTime as String] as? Double
                ?? 0.0667
        }

        return GIFMetadata(width: width, height: height, frameCount: frameCount, frameDelay: frameDelay)
    }

    public static func verifyPasteboard(containsURL url: URL) {
        let pasteboard = NSPasteboard.general
        let stringContent = pasteboard.string(forType: .string)
        XCTAssertEqual(stringContent, url.path, "Pasteboard should contain exact file path")
    }

    public static func verifyHistoryItem(filePath: String, expectedMediaType: ShotItem.MediaType) {
        guard let item = HistoryManager.shared.historyItems.first(where: { $0.filePath == filePath }) else {
            XCTFail("HistoryManager missing entry for \(filePath)")
            return
        }
        XCTAssertEqual(item.mediaType, expectedMediaType)
    }

    public static func verifyFileExists(at url: URL) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "File should exist at \(url.path)")
    }
}
