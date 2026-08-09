import XCTest
import CoreGraphics
import CoreMedia
@testable import ctdoshotCore

final class ScreenRecorderTests: XCTestCase {

    // MARK: - Even Dimension Snapping Tests

    func testSnapToEven_EvenInput() {
        let (w, h) = ScreenRecorder.snapToEven(points: CGSize(width: 1920, height: 1080), scale: 1.0)
        XCTAssertEqual(w, 1920)
        XCTAssertEqual(h, 1080)
        XCTAssertEqual(w % 2, 0)
        XCTAssertEqual(h % 2, 0)
    }

    func testSnapToEven_OddInput() {
        let (w, h) = ScreenRecorder.snapToEven(points: CGSize(width: 1921, height: 1081), scale: 1.0)
        XCTAssertEqual(w % 2, 0)
        XCTAssertEqual(h % 2, 0)
        XCTAssertEqual(w, 1920)
        XCTAssertEqual(h, 1080)
    }

    func testSnapToEven_RetinaScale() {
        let (w, h) = ScreenRecorder.snapToEven(points: CGSize(width: 500.3, height: 300.7), scale: 2.0)
        XCTAssertEqual(w % 2, 0)
        XCTAssertEqual(h % 2, 0)
        XCTAssertEqual(w, 1000)
        XCTAssertEqual(h, 600)
    }

    func testSnapToEvenDimensions_MinimumBoundary() {
        let size0 = ScreenRecorder.snapToEvenDimensions(CGSize(width: 0, height: 0), scale: 1.0)
        XCTAssertEqual(Int(size0.width), 2)
        XCTAssertEqual(Int(size0.height), 2)

        let size1 = ScreenRecorder.snapToEvenDimensions(CGSize(width: 1, height: 1), scale: 1.0)
        XCTAssertEqual(Int(size1.width), 2)
        XCTAssertEqual(Int(size1.height), 2)
    }

    // MARK: - Dynamic Bitrate Tests

    func testBitrateCalculation_1080p() {
        let bitrate = ScreenRecorder.calculateBitrate(width: 1920, height: 1080, fps: 30)
        XCTAssertGreaterThanOrEqual(bitrate, 1_500_000)
        XCTAssertLessThanOrEqual(bitrate, 20_000_000)
        XCTAssertEqual(bitrate, 9_331_200)
    }

    func testBitrateCalculation_LowResBound() {
        let bitrate = ScreenRecorder.calculateBitrate(width: 100, height: 100, fps: 15)
        XCTAssertEqual(bitrate, 1_500_000)
    }

    func testBitrateCalculation_4KHighBound() {
        let bitrate = ScreenRecorder.calculateBitrate(width: 3840, height: 2160, fps: 60)
        XCTAssertEqual(bitrate, 20_000_000)
    }

    // MARK: - Recording State Machine & PTS Offset Math Tests

    @MainActor
    func testInitialState() {
        let recorder = ScreenRecorder()
        XCTAssertEqual(recorder.state, .idle)
        XCTAssertEqual(recorder.elapsedTime, 0)
        XCTAssertFalse(recorder.isMicEnabled)
    }

    func testTimestampOffsetCalculation() {
        let rawPTSPrePause = CMTime(seconds: 5.0, preferredTimescale: 600)
        let totalPauseDuration = CMTime.zero
        let adjustedPrePause = CMTimeSubtract(rawPTSPrePause, totalPauseDuration)
        XCTAssertEqual(adjustedPrePause.seconds, 5.0, accuracy: 0.001)

        let pauseDuration = CMTime(seconds: 3.0, preferredTimescale: 600)
        let rawPTSPostResume = CMTime(seconds: 10.0, preferredTimescale: 600)
        let adjustedPostResume = CMTimeSubtract(rawPTSPostResume, pauseDuration)
        XCTAssertEqual(adjustedPostResume.seconds, 7.0, accuracy: 0.001)
    }

    func testMultiplePauseAccumulation() {
        let pause1 = CMTime(seconds: 2.0, preferredTimescale: 600)
        let pause2 = CMTime(seconds: 3.5, preferredTimescale: 600)
        let totalPause = CMTimeAdd(pause1, pause2)
        XCTAssertEqual(totalPause.seconds, 5.5, accuracy: 0.001)

        let rawPTS = CMTime(seconds: 20.0, preferredTimescale: 600)
        let adjusted = CMTimeSubtract(rawPTS, totalPause)
        XCTAssertEqual(adjusted.seconds, 14.5, accuracy: 0.001)
    }
}
