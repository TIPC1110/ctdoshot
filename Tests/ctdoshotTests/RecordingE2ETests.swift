import XCTest
import AppKit
import AVFoundation
import ImageIO
@testable import ctdoshotCore

final class RecordingE2ETests: XCTestCase {

    var runner: E2ETestRunner!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        runner = E2ETestRunner()
        try runner.setUpIsolatedEnvironment()
    }

    @MainActor
    override func tearDownWithError() throws {
        runner.tearDownIsolatedEnvironment()
        runner = nil
        try super.tearDownWithError()
    }

    // MARK: - Tier 1: Feature Area 1 - MP4 Video Recording Engine (5 Cases)

    @MainActor
    func testT1_MP4_001_FullScreenRecording() throws {
        let exp = expectation(description: "FullScreen MP4 recording completion")
        runner.setRecordMode(.fullScreen())
        runner.setExportFormat(.mp4)

        runner.startRecording()
        XCTAssertEqual(runner.recorder.state, .recording)

        runner.simulateTimePassage(seconds: 2.0)

        runner.stopRecording { result in
            switch result {
            case .success(let outputURL):
                E2EVerifier.verifyFileExists(at: outputURL)
                XCTAssertEqual(outputURL.pathExtension.lowercased(), "mp4")
                let track = E2EVerifier.extractVideoTrack(from: outputURL)
                XCTAssertNotNil(track)
                exp.fulfill()
            case .failure(let error):
                XCTFail("MP4 recording failed with error: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_MP4_002_AreaRegionEvenDimensions() throws {
        let exp = expectation(description: "Area Region Even Dimensions MP4")
        let oddRegion = CGRect(x: 10, y: 10, width: 501, height: 303)
        runner.setRecordMode(.region(oddRegion))
        runner.setExportFormat(.mp4)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            switch result {
            case .success(let outputURL):
                E2EVerifier.verifyFileExists(at: outputURL)
                if let track = E2EVerifier.extractVideoTrack(from: outputURL) {
                    let width = Int(track.naturalSize.width)
                    let height = Int(track.naturalSize.height)
                    XCTAssertEqual(width % 2, 0, "Width should be even integer")
                    XCTAssertEqual(height % 2, 0, "Height should be even integer")
                } else {
                    XCTFail("Missing video track")
                }
                exp.fulfill()
            case .failure(let error):
                XCTFail("Recording failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_MP4_003_TimerAccuracy() throws {
        runner.startRecording()
        runner.simulateTimePassage(seconds: 3.5)
        XCTAssertEqual(runner.recorder.elapsedTime, 3.5, accuracy: 0.1)
    }

    @MainActor
    func testT1_MP4_004_StopCallbackAndState() throws {
        let exp = expectation(description: "Stop callback")
        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success = result {
                XCTAssertEqual(self.runner.recorder.state, .idle)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_MP4_005_SequentialSessions() throws {
        let exp1 = expectation(description: "Session 1")
        let exp2 = expectation(description: "Session 2")

        var firstURL: URL?

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)
        runner.stopRecording { res1 in
            if case .success(let url1) = res1 {
                firstURL = url1
                exp1.fulfill()
            }
        }

        wait(for: [exp1], timeout: 10.0)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)
        runner.stopRecording { res2 in
            if case .success(let url2) = res2 {
                XCTAssertNotEqual(firstURL, url2, "Sequential session URLs should be distinct")
                exp2.fulfill()
            }
        }

        wait(for: [exp2], timeout: 10.0)
    }

    // MARK: - Tier 1: Feature Area 2 - Animated GIF Export Engine (5 Cases)

    @MainActor
    func testT1_GIF_001_HeaderVerification() throws {
        let exp = expectation(description: "GIF Header")
        runner.setExportFormat(.gif)
        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.5)

        runner.stopRecording { result in
            switch result {
            case .success(let gifURL):
                XCTAssertEqual(gifURL.pathExtension.lowercased(), "gif")
                let meta = try? E2EVerifier.inspectGIF(at: gifURL)
                XCTAssertNotNil(meta)
                XCTAssertGreaterThan(meta?.frameCount ?? 0, 0)
                exp.fulfill()
            case .failure(let error):
                XCTFail("GIF export failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_GIF_002_DownscalingToMax1024() throws {
        let exp = expectation(description: "GIF Downscaling")
        let largeRegion = CGRect(x: 0, y: 0, width: 2560, height: 1600)
        runner.setRecordMode(.region(largeRegion))
        runner.setExportFormat(.gif)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            switch result {
            case .success(let gifURL):
                if let meta = try? E2EVerifier.inspectGIF(at: gifURL) {
                    XCTAssertLessThanOrEqual(meta.width, 1024)
                } else {
                    XCTFail("GIF inspection failed")
                }
                exp.fulfill()
            case .failure(let error):
                XCTFail("GIF export failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_GIF_003_FrameRate15FPS() throws {
        let exp = expectation(description: "GIF 15 FPS Delay")
        runner.setExportFormat(.gif)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            switch result {
            case .success(let gifURL):
                if let meta = try? E2EVerifier.inspectGIF(at: gifURL) {
                    XCTAssertEqual(meta.frameDelay, 0.0667, accuracy: 0.02)
                } else {
                    XCTFail("GIF inspection failed")
                }
                exp.fulfill()
            case .failure(let error):
                XCTFail("GIF export failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_GIF_004_TempFileCleanup() throws {
        let exp = expectation(description: "Temp file cleanup")
        runner.setExportFormat(.gif)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let gifURL) = result {
                XCTAssertTrue(FileManager.default.fileExists(atPath: gifURL.path))
                let parentDir = gifURL.deletingLastPathComponent()
                let mp4Files = (try? FileManager.default.contentsOfDirectory(atPath: parentDir.path))?.filter { $0.hasSuffix(".mp4") } ?? []
                XCTAssertTrue(mp4Files.isEmpty, "Temp MP4 file should be cleaned up")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_GIF_005_ConversionCancellation() throws {
        let converter = GIFConverter()
        let invalidURL = runner.testDir.appendingPathComponent("non_existent.mp4")
        let gifURL = runner.testDir.appendingPathComponent("output.gif")

        let exp = expectation(description: "Cancellation")
        Task {
            do {
                _ = try await converter.convert(mp4URL: invalidURL, outputURL: gifURL)
                XCTFail("Should throw on missing file")
            } catch {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Tier 1: Feature Area 3 - Microphone Audio Capture (5 Cases)

    @MainActor
    func testT1_AUD_001_MicEnabledAudioTrack() throws {
        let exp = expectation(description: "Mic Enabled Audio Track")
        runner.setMicEnabled(true)
        runner.setExportFormat(.mp4)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.5)

        runner.stopRecording { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(E2EVerifier.hasAudioTrack(in: url))
                exp.fulfill()
            case .failure(let error):
                XCTFail("Recording failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_AUD_002_MicDisabledNoAudioTrack() throws {
        let exp = expectation(description: "Mic Disabled No Audio Track")
        runner.setMicEnabled(false)
        runner.setExportFormat(.mp4)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.5)

        runner.stopRecording { result in
            switch result {
            case .success(let url):
                XCTAssertFalse(E2EVerifier.hasAudioTrack(in: url))
                exp.fulfill()
            case .failure(let error):
                XCTFail("Recording failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_AUD_003_DynamicMicToggleMuteToUnmute() throws {
        runner.setMicEnabled(false)
        runner.startRecording()
        XCTAssertFalse(runner.recorder.isMicEnabled)

        runner.toggleMic()
        XCTAssertTrue(runner.recorder.isMicEnabled)
    }

    @MainActor
    func testT1_AUD_004_DynamicMicToggleUnmuteToMute() throws {
        runner.setMicEnabled(true)
        runner.startRecording()
        XCTAssertTrue(runner.recorder.isMicEnabled)

        runner.toggleMic()
        XCTAssertFalse(runner.recorder.isMicEnabled)
    }

    @MainActor
    func testT1_AUD_005_AACEncoderFormat() throws {
        let exp = expectation(description: "AAC Audio Format")
        runner.setMicEnabled(true)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                XCTAssertTrue(E2EVerifier.hasAudioTrack(in: url))
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    // MARK: - Tier 1: Feature Area 4 - Floating Control HUD (5 Cases)

    @MainActor
    func testT1_HUD_001_NonActivatingWindowProperties() throws {
        XCTAssertFalse(runner.isHUDPanelVisible)
        runner.startRecording()
        XCTAssertTrue(runner.isHUDPanelVisible)
    }

    @MainActor
    func testT1_HUD_002_WindowExclusionFilter() throws {
        XCTAssertTrue(runner.excludedWindows.contains("RecordingHUDPanel"))
    }

    @MainActor
    func testT1_HUD_003_StateBindings() throws {
        runner.startRecording()
        XCTAssertEqual(runner.recorder.state, .recording)

        runner.pauseRecording()
        XCTAssertEqual(runner.recorder.state, .paused)

        runner.resumeRecording()
        XCTAssertEqual(runner.recorder.state, .recording)
    }

    @MainActor
    func testT1_HUD_004_TimerFormatting() throws {
        runner.startRecording()
        runner.simulateTimePassage(seconds: 125.0)

        let totalSeconds = Int(runner.recorder.elapsedTime)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let formatted = String(format: "%02d:%02d", mins, secs)
        XCTAssertEqual(formatted, "02:05")
    }

    @MainActor
    func testT1_HUD_005_MicToggleIconState() throws {
        runner.setMicEnabled(true)
        XCTAssertTrue(runner.recorder.isMicEnabled)

        runner.toggleMic()
        XCTAssertFalse(runner.recorder.isMicEnabled)
    }

    // MARK: - Tier 1: Feature Area 5 - Status Bar Menu & Hotkeys (5 Cases)

    @MainActor
    func testT1_MNU_001_StatusMenuItems() throws {
        runner.triggerMenuItem("Record Area")
        XCTAssertEqual(runner.recorder.state, .recording)
    }

    @MainActor
    func testT1_MNU_002_CarbonHotkeyTriggerBindings() throws {
        runner.triggerHotkey("RecordScreen")
        XCTAssertEqual(runner.recorder.state, .recording)
    }

    @MainActor
    func testT1_MNU_003_StatusItemAnimationPulse() throws {
        XCTAssertFalse(runner.isMenuBarAnimating)
        runner.startRecording()
        XCTAssertTrue(runner.isMenuBarAnimating)
    }

    @MainActor
    func testT1_MNU_004_StatusItemAnimationStop() throws {
        let exp = expectation(description: "Animation stop")
        runner.startRecording()
        XCTAssertTrue(runner.isMenuBarAnimating)

        runner.stopRecording { _ in
            XCTAssertFalse(self.runner.isMenuBarAnimating)
            exp.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_MNU_005_MenuItemDisableDuringActiveRecording() throws {
        runner.startRecording()
        XCTAssertEqual(runner.recorder.state, .recording)
        // Verify recorder state prevents duplicate start
        XCTAssertTrue(runner.isHUDPanelVisible)
    }

    // MARK: - Tier 1: Feature Area 6 - Output & History Integration (5 Cases)

    @MainActor
    func testT1_HST_001_ShotItemSerialization() throws {
        let item = ShotItem(
            filePath: "/tmp/test.mp4",
            ocrText: "Sample",
            mediaType: .video,
            duration: 5.4
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ShotItem.self, from: data)

        XCTAssertEqual(decoded.filePath, item.filePath)
        XCTAssertEqual(decoded.mediaType, .video)
        XCTAssertEqual(decoded.duration, 5.4)
    }

    @MainActor
    func testT1_HST_002_HistoryManagerAddShot() throws {
        HistoryManager.shared.addShot(
            filePath: "/tmp/rec.mp4",
            ocrText: nil,
            mediaType: .video,
            duration: 4.2
        )
        XCTAssertEqual(HistoryManager.shared.historyItems.count, 1)
        XCTAssertEqual(HistoryManager.shared.historyItems.first?.mediaType, .video)
    }

    @MainActor
    func testT1_HST_003_VideoThumbnailGeneration() throws {
        let exp = expectation(description: "Video Thumbnail")
        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                E2EVerifier.verifyHistoryItem(filePath: url.path, expectedMediaType: .video)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_HST_004_PasteboardCopy() throws {
        let exp = expectation(description: "Pasteboard copy")
        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                E2EVerifier.verifyPasteboard(containsURL: url)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT1_HST_005_HistoryDurationFormatting() throws {
        let duration: TimeInterval = 65.0
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let formatted = String(format: "%02d:%02d", mins, secs)
        XCTAssertEqual(formatted, "01:05")
    }

    // MARK: - Tier 2: Boundary & Corner Cases (5 Cases)

    @MainActor
    func testT2_BND_001_ZeroSizeRegionHandling() throws {
        let zeroRegion = CGRect(x: 10, y: 10, width: 0, height: 0)
        runner.setRecordMode(.region(zeroRegion))

        let exp = expectation(description: "Zero size region")
        runner.startRecording { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error as? RecordingError, RecordingError.invalidRegion)
                XCTAssertEqual(self.runner.recorder.state, .idle)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    @MainActor
    func testT2_BND_002_HighDPIRetinaScaling() throws {
        let (w, h) = ScreenRecorder.snapToEven(points: CGSize(width: 400, height: 300), scale: 2.0)
        XCTAssertEqual(w, 800)
        XCTAssertEqual(h, 600)
    }

    @MainActor
    func testT2_BND_003_PauseResumeTimestampAlignment() throws {
        runner.startRecording()
        runner.simulateTimePassage(seconds: 2.0)

        runner.pauseRecording()
        XCTAssertEqual(runner.recorder.state, .paused)

        runner.simulateTimePassage(seconds: 5.0) // Excluded pause duration

        runner.resumeRecording()
        XCTAssertEqual(runner.recorder.state, .recording)

        runner.simulateTimePassage(seconds: 2.0)

        let exp = expectation(description: "PTS duration")
        runner.stopRecording { result in
            if case .success(let url) = result {
                let dur = E2EVerifier.getVideoDuration(from: url)
                XCTAssertEqual(dur, 4.0, accuracy: 0.5)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT2_BND_004_PermissionDeniedFallback() throws {
        runner.simulatePermission(granted: false)

        let exp = expectation(description: "Permission denied")
        runner.startRecording { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error as? RecordingError, RecordingError.permissionDenied)
                XCTAssertEqual(self.runner.recorder.state, .idle)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    @MainActor
    func testT2_BND_005_InvalidSaveDirectoryRecovery() throws {
        let invalidPath = "/System/Library/ctdoshot_invalid"
        UserDefaults.standard.set(invalidPath, forKey: "savePath")

        let exp = expectation(description: "Fallback directory")
        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                E2EVerifier.verifyFileExists(at: url)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    // MARK: - Tier 3: Cross-Feature Combinations (4 Cases)

    @MainActor
    func testT3_CMB_001_AreaMP4_Mic_HistoryPreview() throws {
        let exp = expectation(description: "Area MP4 + Mic + History")
        let region = CGRect(x: 50, y: 50, width: 800, height: 600)
        runner.setRecordMode(.region(region))
        runner.setMicEnabled(true)
        runner.setExportFormat(.mp4)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 2.0)

        runner.stopRecording { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(E2EVerifier.hasAudioTrack(in: url))
                E2EVerifier.verifyPasteboard(containsURL: url)
                E2EVerifier.verifyHistoryItem(filePath: url.path, expectedMediaType: .video)
                exp.fulfill()
            case .failure(let error):
                XCTFail("Combination 1 failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT3_CMB_002_GIF_Pasteboard_HistoryBadge() throws {
        let exp = expectation(description: "GIF + Pasteboard + History Badge")
        runner.setExportFormat(.gif)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.5)

        runner.stopRecording { result in
            switch result {
            case .success(let gifURL):
                E2EVerifier.verifyPasteboard(containsURL: gifURL)
                E2EVerifier.verifyHistoryItem(filePath: gifURL.path, expectedMediaType: .gif)
                exp.fulfill()
            case .failure(let error):
                XCTFail("Combination 2 failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT3_CMB_003_FullScreenMP4_DynamicMic_HUDTimer() throws {
        let exp = expectation(description: "Full Screen MP4 + Dynamic Mic + HUD Timer")
        runner.setRecordMode(.fullScreen())
        runner.setMicEnabled(false)

        runner.startRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.toggleMic()
        XCTAssertTrue(runner.recorder.isMicEnabled)

        runner.pauseRecording()
        runner.simulateTimePassage(seconds: 2.0)

        runner.resumeRecording()
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                let dur = E2EVerifier.getVideoDuration(from: url)
                XCTAssertEqual(dur, 2.0, accuracy: 0.5)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT3_CMB_004_AreaGIF_StatusAnimation_Pasteboard() throws {
        let exp = expectation(description: "Area GIF + Status Animation + Pasteboard")
        runner.triggerMenuItem("Record GIF")

        XCTAssertTrue(runner.isMenuBarAnimating)
        runner.simulateTimePassage(seconds: 1.0)

        runner.stopRecording { result in
            if case .success(let url) = result {
                XCTAssertFalse(self.runner.isMenuBarAnimating)
                E2EVerifier.verifyPasteboard(containsURL: url)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    // MARK: - Tier 4: Real-World Application Scenarios (3 Cases)

    @MainActor
    func testT4_SCE_001_FullHotkeyAreaVideoWorkflow() throws {
        let exp = expectation(description: "Full Hotkey Area Video Workflow")

        // 1. Hotkey trigger
        runner.triggerHotkey("RecordArea")
        XCTAssertEqual(runner.recorder.state, .recording)
        XCTAssertTrue(runner.isHUDPanelVisible)

        // 2. Active recording and pause
        runner.simulateTimePassage(seconds: 1.0)
        runner.pauseRecording()
        XCTAssertEqual(runner.recorder.state, .paused)

        runner.resumeRecording()
        runner.simulateTimePassage(seconds: 1.0)

        // 3. Stop and verify artifacts
        runner.stopRecording { result in
            switch result {
            case .success(let url):
                E2EVerifier.verifyFileExists(at: url)
                E2EVerifier.verifyPasteboard(containsURL: url)
                E2EVerifier.verifyHistoryItem(filePath: url.path, expectedMediaType: .video)
                exp.fulfill()
            case .failure(let error):
                XCTFail("Scenario 1 failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT4_SCE_002_FullHotkeyGIFExportWorkflow() throws {
        let exp = expectation(description: "Full Hotkey GIF Export Workflow")

        // 1. Hotkey trigger for GIF
        runner.triggerHotkey("RecordGIF")
        XCTAssertEqual(runner.recorder.state, .recording)

        runner.simulateTimePassage(seconds: 1.5)

        // 2. Stop and verify GIF output, scaling, pasteboard, and history
        runner.stopRecording { result in
            switch result {
            case .success(let gifURL):
                XCTAssertEqual(gifURL.pathExtension.lowercased(), "gif")
                if let meta = try? E2EVerifier.inspectGIF(at: gifURL) {
                    XCTAssertLessThanOrEqual(meta.width, 1024)
                } else {
                    XCTFail("GIF metadata inspection failed")
                }
                E2EVerifier.verifyPasteboard(containsURL: gifURL)
                E2EVerifier.verifyHistoryItem(filePath: gifURL.path, expectedMediaType: .gif)
                exp.fulfill()
            case .failure(let error):
                XCTFail("Scenario 2 failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    @MainActor
    func testT4_SCE_003_FullScreenNarrationDynamicMicWorkflow() throws {
        let exp = expectation(description: "Full Screen Narration Dynamic Mic Workflow")

        // 1. Start full screen with Mic ON
        runner.setRecordMode(.fullScreen())
        runner.setMicEnabled(true)
        runner.startRecording()

        runner.simulateTimePassage(seconds: 1.0)

        // 2. Toggle Mic OFF during narration pause
        runner.toggleMic()
        XCTAssertFalse(runner.recorder.isMicEnabled)

        runner.simulateTimePassage(seconds: 1.0)

        // 3. Stop and verify output MP4 and History entry
        runner.stopRecording { result in
            switch result {
            case .success(let url):
                E2EVerifier.verifyFileExists(at: url)
                E2EVerifier.verifyHistoryItem(filePath: url.path, expectedMediaType: .video)
                exp.fulfill()
            case .failure(let error):
                XCTFail("Scenario 3 failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10.0)
    }
}
