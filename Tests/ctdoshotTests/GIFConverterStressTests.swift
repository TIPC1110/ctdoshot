import XCTest
import AVFoundation
import AppKit
import ImageIO
@testable import ctdoshotCore

final class GIFConverterStressTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - 1. 0-Byte Source File Handling
    func testGIFConversion_ZeroByteSourceFile() async {
        let zeroByteURL = tempDir.appendingPathComponent("zero_byte.mp4")
        let gifURL = tempDir.appendingPathComponent("output_zero_byte.gif")

        FileManager.default.createFile(atPath: zeroByteURL.path, contents: Data())

        let converter = GIFConverter()
        do {
            _ = try await converter.convert(mp4URL: zeroByteURL, outputURL: gifURL)
            XCTFail("Expected GIFConverter to throw for 0-byte source file")
        } catch let error as GIFConverterError {
            XCTAssertEqual(error, GIFConverterError.invalidSourceFile, "0-byte source file should throw invalidSourceFile")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: gifURL.path), "Output GIF should not exist after error")
    }

    // MARK: - 2. Non-Existent Source URL
    func testGIFConversion_NonExistentURL() async {
        let nonExistentURL = tempDir.appendingPathComponent("file_does_not_exist_\(UUID().uuidString).mp4")
        let gifURL = tempDir.appendingPathComponent("output_non_existent.gif")

        let converter = GIFConverter()
        do {
            _ = try await converter.convert(mp4URL: nonExistentURL, outputURL: gifURL)
            XCTFail("Expected GIFConverter to throw for non-existent URL")
        } catch let error as GIFConverterError {
            XCTAssertEqual(error, GIFConverterError.invalidSourceFile, "Non-existent source URL should throw invalidSourceFile")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: gifURL.path))
    }

    // MARK: - 3. Downscaling Edge Cases (width < 1024 vs > 1024)
    func testGIFConversion_Downscaling_WidthLessThan1024() async throws {
        // Source width 640 (< 1024), default maxWidth 1024. Should NOT scale up.
        let mp4URL = tempDir.appendingPathComponent("input_640x480.mp4")
        let gifURL = tempDir.appendingPathComponent("output_640x480.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 0.5, fps: 30, size: CGSize(width: 640, height: 480))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 1024, loopCount: 0)

        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil),
              let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to read created GIF")
            return
        }

        XCTAssertEqual(firstFrame.width, 640, "Width < 1024 should retain original width 640, not scaled to 1024")
        XCTAssertEqual(firstFrame.height, 480, "Height should retain original height 480")
    }

    func testGIFConversion_Downscaling_WidthGreaterThan1024() async throws {
        // Source width 1920 (> 1024), default maxWidth 1024. Should downscale to 1024x576.
        let mp4URL = tempDir.appendingPathComponent("input_1920x1080.mp4")
        let gifURL = tempDir.appendingPathComponent("output_1024x576.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 0.5, fps: 30, size: CGSize(width: 1920, height: 1080))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 1024, loopCount: 0)

        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil),
              let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to read created GIF")
            return
        }

        XCTAssertEqual(firstFrame.width, 1024, "Width 1920 > 1024 should downscale width to 1024")
        XCTAssertEqual(firstFrame.height, 576, "Height 1080 should downscale proportionally to 576")
    }

    func testGIFConversion_Downscaling_Exact1024Boundary() async throws {
        // Source width exact 1024. Should remain 1024.
        let mp4URL = tempDir.appendingPathComponent("input_1024x768.mp4")
        let gifURL = tempDir.appendingPathComponent("output_1024x768.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 0.5, fps: 30, size: CGSize(width: 1024, height: 768))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 1024, loopCount: 0)

        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil),
              let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to read created GIF")
            return
        }

        XCTAssertEqual(firstFrame.width, 1024, "Width 1024 should remain 1024")
        XCTAssertEqual(firstFrame.height, 768, "Height should remain 768")
    }

    // MARK: - 4. Non-Standard Frame Rates
    func testGIFConversion_NonStandardFPS_60FPS_Source() async throws {
        // 2 seconds of 60 FPS MP4 (120 frames total). Target 15 FPS GIF.
        // Expected GIF frame count: ~30 frames (15 FPS * 2 sec).
        let mp4URL = tempDir.appendingPathComponent("input_60fps.mp4")
        let gifURL = tempDir.appendingPathComponent("output_60fps.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 2.0, fps: 60, size: CGSize(width: 640, height: 480))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 640, loopCount: 0)

        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            XCTFail("Failed to create image source")
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        // 2 seconds video at target 15 FPS should be 30 frames (allow 25..35 tolerance)
        XCTAssertGreaterThanOrEqual(frameCount, 25, "60 FPS source converted to 15 FPS GIF should have at least 25 frames")
        XCTAssertLessThanOrEqual(frameCount, 35, "60 FPS source converted to 15 FPS GIF should have at most 35 frames, but got \(frameCount)")
    }

    func testGIFConversion_NonStandardFPS_10FPS_Source() async throws {
        // 3 seconds of 10 FPS MP4 (30 frames total). Target 10 FPS GIF.
        // Expected GIF frame count: ~30 frames (10 FPS * 3 sec).
        let mp4URL = tempDir.appendingPathComponent("input_10fps.mp4")
        let gifURL = tempDir.appendingPathComponent("output_10fps.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 3.0, fps: 10, size: CGSize(width: 640, height: 480))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 10, maxWidth: 640, loopCount: 0)

        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            XCTFail("Failed to create image source")
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        // 3 seconds of 10 FPS source requested at 10 FPS GIF should keep ~30 frames.
        XCTAssertGreaterThanOrEqual(frameCount, 25, "10 FPS source converted to 10 FPS GIF for 3s should have ~30 frames, but got \(frameCount)")
        XCTAssertLessThanOrEqual(frameCount, 35, "10 FPS source converted to 10 FPS GIF for 3s should have ~30 frames, but got \(frameCount)")
    }

    // MARK: - 5. Cancellation Mid-Conversion
    func testGIFConversion_CancellationMidConversion() async throws {
        let mp4URL = tempDir.appendingPathComponent("input_cancel.mp4")
        let gifURL = tempDir.appendingPathComponent("output_cancel.gif")

        // 3 seconds of 60 FPS MP4 (180 frames)
        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 3.0, fps: 60, size: CGSize(width: 640, height: 480))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 640, loopCount: 0)

        let exp = expectation(description: "Progress callback reached")
        var task: Task<URL, Error>?

        task = Task {
            try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config) { progress in
                if progress > 0.1 {
                    exp.fulfill()
                    task?.cancel()
                }
            }
        }

        await fulfillment(of: [exp], timeout: 5.0)

        do {
            _ = try await task?.value
            XCTFail("Expected conversion task to throw when cancelled mid-conversion")
        } catch let error as GIFConverterError {
            XCTAssertEqual(error, GIFConverterError.cancelled)
        } catch is CancellationError {
            // Swift Concurrency CancellationError is also expected
        } catch {
            XCTFail("Unexpected error type on cancellation: \(error)")
        }

        // Delay slightly to ensure cleanup completes
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: gifURL.path), "Output file must be cleaned up after cancellation mid-conversion")
    }

    // MARK: - 6. Large MP4 File Stress Test
    func testGIFConversion_LargeMP4File() async throws {
        // 5 seconds of 1080p at 30 FPS (150 frames, 1920x1080)
        let mp4URL = tempDir.appendingPathComponent("large_1080p.mp4")
        let gifURL = tempDir.appendingPathComponent("output_large_1080p.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 5.0, fps: 30, size: CGSize(width: 1920, height: 1080))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 1024, loopCount: 0)

        let startTime = Date()
        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config)
        let elapsedTime = Date().timeIntervalSince(startTime)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        print("Large MP4 conversion completed in \(elapsedTime) seconds")

        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil),
              let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to decode large MP4 output GIF")
            return
        }

        XCTAssertEqual(firstFrame.width, 1024, "1080p should be downscaled to 1024 width")
        XCTAssertEqual(firstFrame.height, 576, "1080p should be downscaled to 576 height")
    }
}
