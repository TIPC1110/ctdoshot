import XCTest
import AVFoundation
import AppKit
import ImageIO
@testable import ctdoshotCore

final class SyntheticMP4Generator {
    static func createSampleMP4(
        url: URL,
        duration: TimeInterval = 1.0,
        fps: Int32 = 30,
        size: CGSize = CGSize(width: 640, height: 480),
        color: NSColor = .red
    ) async throws -> URL {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(duration * Double(fps))
        let frameDuration = CMTime(value: 1, timescale: fps)

        for i in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(i))
            if let pixelBuffer = makePixelBuffer(size: size, color: color) {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
        }

        writerInput.markAsFinished()
        await writer.finishWriting()
        return url
    }

    private static func makePixelBuffer(size: CGSize, color: NSColor) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
        return buffer
    }
}

final class GIFConverterTests: XCTestCase {

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

    func testGIFConversion_Successful() async throws {
        let mp4URL = tempDir.appendingPathComponent("test_input.mp4")
        let gifURL = tempDir.appendingPathComponent("test_output.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 1.0, fps: 30, size: CGSize(width: 640, height: 480))

        let converter = GIFConverter()
        let config = GIFConverterConfiguration(frameRate: 15, maxWidth: 320, loopCount: 0)

        var progressValues: [Double] = []
        let resultURL = try await converter.convert(mp4URL: mp4URL, outputURL: gifURL, config: config) { progress in
            progressValues.append(progress)
        }

        XCTAssertEqual(resultURL, gifURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: gifURL.path))

        // Check GIF properties via ImageIO
        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            XCTFail("Failed to create CGImageSource from output GIF")
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        XCTAssertGreaterThan(frameCount, 5)
        XCTAssertLessThanOrEqual(frameCount, 25)

        if let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            XCTAssertEqual(firstFrame.width, 320)
            XCTAssertEqual(firstFrame.height, 240) // 4:3 aspect ratio preserved
        } else {
            XCTFail("Failed to decode first frame from GIF")
        }

        // Verify progress reporting
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last ?? 0.0, 1.0, accuracy: 0.01)
    }

    func testGIFConversion_InvalidSourceFile() async {
        let invalidURL = tempDir.appendingPathComponent("non_existent.mp4")
        let gifURL = tempDir.appendingPathComponent("output.gif")

        let converter = GIFConverter()
        do {
            _ = try await converter.convert(mp4URL: invalidURL, outputURL: gifURL)
            XCTFail("Expected convert to throw for non-existent source file")
        } catch let error as GIFConverterError {
            XCTAssertEqual(error, GIFConverterError.invalidSourceFile)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGIFConversion_TaskCancellation() async throws {
        let mp4URL = tempDir.appendingPathComponent("test_cancel_input.mp4")
        let gifURL = tempDir.appendingPathComponent("test_cancel_output.gif")

        _ = try await SyntheticMP4Generator.createSampleMP4(url: mp4URL, duration: 3.0, fps: 30)

        let converter = GIFConverter()

        let task = Task {
            try await converter.convert(mp4URL: mp4URL, outputURL: gifURL)
        }

        // Cancel task almost immediately
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected task to throw on cancellation")
        } catch let error as GIFConverterError {
            XCTAssertEqual(error, .cancelled)
        } catch is CancellationError {
            // CancellationError is also valid
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: gifURL.path), "Output file should be cleaned up on cancellation")
    }
}
