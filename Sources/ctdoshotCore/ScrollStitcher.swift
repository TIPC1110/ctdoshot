import AppKit
import CoreGraphics

public enum ScrollStitcher {
    public static func stitch(frames: [NSImage], minOverlap: Int, maxOverlap: Int) -> NSImage? {
        guard let first = frames.first else { return nil }
        var canvas = first
        for next in frames.dropFirst() {
            guard let merged = append(
                canvas: canvas,
                next: next,
                minOverlap: minOverlap,
                maxOverlap: maxOverlap
            ) else {
                return canvas
            }
            canvas = merged
        }
        return canvas
    }

    private static func append(
        canvas: NSImage,
        next: NSImage,
        minOverlap: Int,
        maxOverlap: Int
    ) -> NSImage? {
        guard let cg1 = makeCGImage(from: canvas),
              let cg2 = makeCGImage(from: next) else {
            return nil
        }

        let w1 = cg1.width
        let h1 = cg1.height
        let w2 = cg2.width
        let h2 = cg2.height
        guard w1 > 0, h1 > 0, w2 > 0, h2 > 0 else { return nil }

        let width = min(w1, w2)
        let maxO = min(maxOverlap, h1, h2)
        let bestOverlap: Int
        if minOverlap > 0, minOverlap <= maxO,
           let gray1 = grayscalePixels(from: cg1),
           let gray2 = grayscalePixels(from: cg2) {
            var bestO = minOverlap
            var bestScore = Double.greatestFiniteMagnitude
            for o in minOverlap...maxO {
                let score = rowMSE(
                    a: gray1,
                    aWidth: w1,
                    aHeight: h1,
                    b: gray2,
                    bWidth: w2,
                    overlap: o,
                    compareWidth: width
                )
                if score < bestScore {
                    bestScore = score
                    bestO = o
                }
            }
            bestOverlap = bestO
        } else {
            bestOverlap = 0
        }

        let newHeight = h1 + h2 - bestOverlap
        guard newHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Work in top-left coordinates for mental model of scroll stitch.
        ctx.translateBy(x: 0, y: CGFloat(newHeight))
        ctx.scaleBy(x: 1, y: -1)

        // Canvas occupies the top of the result.
        ctx.draw(cg1, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(h1)))
        // Next is placed so its top `bestOverlap` rows land on the canvas bottom band.
        ctx.draw(
            cg2,
            in: CGRect(
                x: 0,
                y: CGFloat(h1 - bestOverlap),
                width: CGFloat(width),
                height: CGFloat(h2)
            )
        )

        guard let resultCG = ctx.makeImage() else { return nil }
        return NSImage(
            cgImage: resultCG,
            size: NSSize(width: width, height: newHeight)
        )
    }

    private static func grayscalePixels(from cgImage: CGImage) -> [UInt8]? {
        let w = cgImage.width
        let h = cgImage.height
        var pixels = [UInt8](repeating: 0, count: w * h)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                    data: base,
                    width: w,
                    height: h,
                    bitsPerComponent: 8,
                    bytesPerRow: w,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else {
                return false
            }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? pixels : nil
    }

    private static func rowMSE(
        a: [UInt8],
        aWidth: Int,
        aHeight: Int,
        b: [UInt8],
        bWidth: Int,
        overlap: Int,
        compareWidth: Int
    ) -> Double {
        var sum = 0.0
        let count = Double(overlap * compareWidth)
        guard count > 0 else { return Double.greatestFiniteMagnitude }

        for row in 0..<overlap {
            let aY = aHeight - overlap + row
            let bY = row
            let aRow = aY * aWidth
            let bRow = bY * bWidth
            for x in 0..<compareWidth {
                let d = Double(a[aRow + x]) - Double(b[bRow + x])
                sum += d * d
            }
        }
        return sum / count
    }

    private static func makeCGImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           cg.width >= 1, cg.height >= 1 {
            return cg
        }

        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let cg = rep.cgImage {
            return cg
        }

        let size = image.size
        let pxW = max(1, Int(size.width.rounded(.up)))
        let pxH = max(1, Int(size.height.rounded(.up)))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW,
            pixelsHigh: pxH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = nsCtx
        image.draw(
            in: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        return rep.cgImage
    }
}
