import AppKit
import CoreImage
import CoreGraphics

/// Raster image operations for the editor (crop, pixelate/blur).
///
/// Normalized rects use **image point space** with origin at the **top-left**
/// (x right, y down), matching `DrawingCanvasView` image-point coordinates.
/// Components are fractions of `image.size` in `0...1` (clamped).
public enum ImageEffects {

    /// Pixel-accurate crop via `CGImage.cropping`. Returns a new image whose
    /// point size is `image.size` scaled by the normalized rect size.
    public static func crop(_ image: NSImage, toNormalized r: CGRect) -> NSImage? {
        guard let cg = makeCGImage(from: image) else { return nil }
        let pw = CGFloat(cg.width)
        let ph = CGFloat(cg.height)
        guard pw > 0, ph > 0 else { return nil }

        let nr = clampNormalized(r)
        guard nr.width > 0, nr.height > 0 else { return nil }

        var pixelRect = CGRect(
            x: nr.origin.x * pw,
            y: nr.origin.y * ph,
            width: nr.width * pw,
            height: nr.height * ph
        ).integral

        // Keep within bounds and at least 1×1 pixel.
        pixelRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: pw, height: ph))
        if pixelRect.width < 1 { pixelRect.size.width = 1 }
        if pixelRect.height < 1 { pixelRect.size.height = 1 }
        pixelRect.origin.x = min(max(0, pixelRect.origin.x), pw - pixelRect.width)
        pixelRect.origin.y = min(max(0, pixelRect.origin.y), ph - pixelRect.height)

        guard let cropped = cg.cropping(to: pixelRect) else { return nil }

        let pointSize = NSSize(
            width: image.size.width * (pixelRect.width / pw),
            height: image.size.height * (pixelRect.height / ph)
        )
        return NSImage(cgImage: cropped, size: pointSize)
    }

    /// Apply `CIPixellate` to a normalized region and composite back onto the full image.
    /// Output has the same dimensions as the input. Does not black-out the region.
    public static func pixelate(
        _ image: NSImage,
        normalizedRect: CGRect,
        scale: Float
    ) -> NSImage? {
        guard let cg = makeCGImage(from: image) else { return nil }
        let pw = CGFloat(cg.width)
        let ph = CGFloat(cg.height)
        guard pw > 0, ph > 0 else { return nil }

        let nr = clampNormalized(normalizedRect)
        guard nr.width > 0, nr.height > 0 else { return nil }

        // Top-left image space → integer pixel rect.
        var pixelRect = CGRect(
            x: floor(nr.origin.x * pw),
            y: floor(nr.origin.y * ph),
            width: max(1, floor(nr.width * pw)),
            height: max(1, floor(nr.height * ph))
        )
        pixelRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: pw, height: ph))
        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return nil }

        // CIImage uses bottom-left origin; convert Y.
        let ciY = ph - pixelRect.maxY
        let ciRect = CGRect(
            x: pixelRect.minX,
            y: ciY,
            width: pixelRect.width,
            height: pixelRect.height
        )

        let full = CIImage(cgImage: cg)
        let region = full.cropped(to: ciRect)

        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(region, forKey: kCIInputImageKey)
        filter.setValue(max(scale, 1), forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: ciRect.midX, y: ciRect.midY), forKey: kCIInputCenterKey)

        guard let pixelated = filter.outputImage?.cropped(to: ciRect) else { return nil }

        // Composite pixelated region over the original (not a black fill).
        let composed = pixelated.composited(over: full)
        let extent = CGRect(x: 0, y: 0, width: pw, height: ph)

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        guard let outCG = ciContext.createCGImage(composed, from: extent) else { return nil }

        return NSImage(cgImage: outCG, size: image.size)
    }

    // MARK: - Helpers

    /// Clamp normalized rect into the unit square; width/height stay non-negative.
    private static func clampNormalized(_ r: CGRect) -> CGRect {
        var x = r.origin.x
        var y = r.origin.y
        var w = r.width
        var h = r.height
        if w < 0 {
            x += w
            w = -w
        }
        if h < 0 {
            y += h
            h = -h
        }
        let maxX = x + w
        let maxY = y + h
        let cx = min(max(x, 0), 1)
        let cy = min(max(y, 0), 1)
        let cMaxX = min(max(maxX, 0), 1)
        let cMaxY = min(max(maxY, 0), 1)
        return CGRect(x: cx, y: cy, width: max(0, cMaxX - cx), height: max(0, cMaxY - cy))
    }

    private static func makeCGImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.cgImage
    }
}
