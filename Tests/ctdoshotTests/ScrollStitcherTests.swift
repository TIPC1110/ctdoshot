import XCTest
import AppKit
@testable import ctdoshotCore

final class ScrollStitcherTests: XCTestCase {
    func testStitchEmptyFramesReturnsNil() {
        let result = ScrollStitcher.stitch(frames: [], minOverlap: 5, maxOverlap: 40)
        XCTAssertNil(result)
    }

    func testStitchSingleFrameReturnsSameSize() {
        let frame = patternedImage(width: 40, height: 60) { x, y in
            UInt8((y * 3 + x) % 200)
        }
        let result = ScrollStitcher.stitch(frames: [frame], minOverlap: 5, maxOverlap: 40)
        XCTAssertNotNil(result)
        XCTAssertEqual(pixelSize(of: result!).height, 60)
        XCTAssertEqual(pixelSize(of: result!).width, 40)
    }

    func testStitchTwoOverlappingStripsIncreasesHeight() {
        let w = 40
        let h = 60
        let overlap = 20

        // Image A: unique vertical pattern so MSE can pick a clear best overlap.
        let top = patternedImage(width: w, height: h) { x, y in
            UInt8((y * 3 + x) % 200)
        }

        // Image B: top `overlap` rows copy A's bottom `overlap` rows; remainder is new content.
        let bottom = patternedImage(width: w, height: h) { x, y in
            Self.bottomStripGray(x: x, y: y, height: h, overlap: overlap)
        }

        let stitched = ScrollStitcher.stitch(
            frames: [top, bottom],
            minOverlap: 5,
            maxOverlap: 40
        )
        XCTAssertNotNil(stitched)

        let stitchedH = pixelSize(of: stitched!).height
        XCTAssertGreaterThan(stitchedH, h, "stitched height should exceed a single frame")
        // Ideal match is exactly `overlap` → 60 + 60 - 20 = 100
        XCTAssertEqual(stitchedH, h + h - overlap)
        XCTAssertEqual(pixelSize(of: stitched!).width, w)
    }

    // MARK: - Helpers

    private static func bottomStripGray(x: Int, y: Int, height: Int, overlap: Int) -> UInt8 {
        if y < overlap {
            let srcY = height - overlap + y
            return UInt8((srcY * 3 + x) % 200)
        }
        let value = ((y + 80) * 5 + x * 2) % 200 + 20
        return UInt8(value)
    }

    private func patternedImage(
        width: Int,
        height: Int,
        gray: (_ x: Int, _ y: Int) -> UInt8
    ) -> NSImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let g = gray(x, y)
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

    private func pixelSize(of image: NSImage) -> (width: Int, height: Int) {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return (cg.width, cg.height)
        }
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            return (rep.pixelsWide, rep.pixelsHigh)
        }
        return (Int(image.size.width), Int(image.size.height))
    }
}
