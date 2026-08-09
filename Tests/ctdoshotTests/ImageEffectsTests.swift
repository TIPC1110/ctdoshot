import XCTest
import AppKit
@testable import ctdoshotCore

final class ImageEffectsTests: XCTestCase {

    func testCropReducesSize() {
        let img = solidImage(width: 100, height: 80, gray: 0.5)
        let cropped = ImageEffects.crop(
            img,
            toNormalized: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        )
        XCTAssertNotNil(cropped)
        XCTAssertEqual(cropped!.size.width, 50, accuracy: 1)
        XCTAssertEqual(cropped!.size.height, 40, accuracy: 1)
    }

    func testPixelateReturnsImage() {
        let img = solidImage(width: 64, height: 64, gray: 0.3)
        let out = ImageEffects.pixelate(
            img,
            normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            scale: 8
        )
        XCTAssertNotNil(out)
        XCTAssertEqual(out!.size.width, img.size.width, accuracy: 1)
        XCTAssertEqual(out!.size.height, img.size.height, accuracy: 1)
    }

    // MARK: - Helpers

    private func solidImage(width: Int, height: Int, gray: CGFloat) -> NSImage {
        let g = UInt8(max(0, min(255, Int(round(gray * 255)))))
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                pixels[i] = g
                pixels[i + 1] = g
                pixels[i + 2] = g
                pixels[i + 3] = 255
            }
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: bytesPerRow,
            bitsPerPixel: 32
        ), let dest = rep.bitmapData else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        for i in 0..<pixels.count {
            dest[i] = pixels[i]
        }
        rep.size = NSSize(width: width, height: height)

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}
