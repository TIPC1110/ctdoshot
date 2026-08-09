import Foundation
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

public enum GIFConverterError: Error, Equatable {
    case invalidSourceFile
    case cancelled
    case conversionFailed
}

public struct GIFConverterConfiguration {
    public var frameRate: Int
    public var maxWidth: Int
    public var loopCount: Int

    public init(frameRate: Int = 15, maxWidth: Int = 1024, loopCount: Int = 0) {
        self.frameRate = frameRate
        self.maxWidth = maxWidth
        self.loopCount = loopCount
    }
}

public final class GIFConverter {
    public init() {}

    @discardableResult
    public func convert(
        mp4URL: URL,
        outputURL: URL,
        config: GIFConverterConfiguration = GIFConverterConfiguration(),
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: mp4URL.path) else {
            throw GIFConverterError.invalidSourceFile
        }

        if Task.isCancelled {
            try? FileManager.default.removeItem(at: outputURL)
            throw GIFConverterError.cancelled
        }

        let asset = AVURLAsset(url: mp4URL)
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            throw GIFConverterError.invalidSourceFile
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw GIFConverterError.invalidSourceFile
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)

        guard reader.startReading() else {
            throw GIFConverterError.invalidSourceFile
        }

        var sampleBuffers: [CMSampleBuffer] = []
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            if Task.isCancelled {
                reader.cancelReading()
                try? FileManager.default.removeItem(at: outputURL)
                throw GIFConverterError.cancelled
            }
            sampleBuffers.append(sampleBuffer)
        }

        guard !sampleBuffers.isEmpty else {
            throw GIFConverterError.conversionFailed
        }

        // Downsample frames according to config.frameRate (assumes source 30/60 fps)
        let totalInputFrames = sampleBuffers.count
        let step = max(1, totalInputFrames / max(1, Int(Double(totalInputFrames) * Double(config.frameRate) / 30.0)))
        var selectedBuffers: [CMSampleBuffer] = []
        for idx in stride(from: 0, to: totalInputFrames, by: step) {
            selectedBuffers.append(sampleBuffers[idx])
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            selectedBuffers.count,
            nil
        ) else {
            throw GIFConverterError.conversionFailed
        }

        let frameDelay = 1.0 / Double(config.frameRate)
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay,
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFLoopCount as String: config.loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let ciContext = CIContext()
        let count = selectedBuffers.count

        for (i, buffer) in selectedBuffers.enumerated() {
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: outputURL)
                throw GIFConverterError.cancelled
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { continue }
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }

            let origW = cgImage.width
            let origH = cgImage.height
            let scaledImage: CGImage
            if origW > config.maxWidth {
                let targetW = config.maxWidth
                let targetH = max(1, (origH * config.maxWidth) / origW)
                if let resized = resizeCGImage(cgImage, width: targetW, height: targetH) {
                    scaledImage = resized
                } else {
                    scaledImage = cgImage
                }
            } else {
                scaledImage = cgImage
            }

            let frameDict: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay,
                    kCGImagePropertyGIFDelayTime as String: frameDelay
                ]
            ]
            CGImageDestinationAddImage(destination, scaledImage, frameDict as CFDictionary)

            let p = Double(i + 1) / Double(count)
            progress?(p)
        }

        if !CGImageDestinationFinalize(destination) {
            try? FileManager.default.removeItem(at: outputURL)
            throw GIFConverterError.conversionFailed
        }

        return outputURL
    }

    private func resizeCGImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
