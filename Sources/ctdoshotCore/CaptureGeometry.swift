import CoreGraphics

public enum CaptureGeometry {
    /// Convert a Cocoa global selection rect (bottom-left origin) into a
    /// display-local top-left source rect suitable for ScreenCaptureKit.
    public static func topLeftSourceRect(selectionGlobalCocoa: CGRect, displayCocoaFrame: CGRect) -> CGRect {
        let local = CGRect(
            x: selectionGlobalCocoa.minX - displayCocoaFrame.minX,
            y: selectionGlobalCocoa.minY - displayCocoaFrame.minY,
            width: selectionGlobalCocoa.width,
            height: selectionGlobalCocoa.height
        )
        let topLeftY = displayCocoaFrame.height - local.maxY
        return clamp(
            CGRect(x: local.minX, y: topLeftY, width: local.width, height: local.height),
            to: CGRect(x: 0, y: 0, width: displayCocoaFrame.width, height: displayCocoaFrame.height)
        )
    }

    public static func clamp(_ r: CGRect, to bounds: CGRect) -> CGRect {
        let x = max(bounds.minX, r.minX)
        let y = max(bounds.minY, r.minY)
        let maxX = min(bounds.maxX, r.maxX)
        let maxY = min(bounds.maxY, r.maxY)
        return CGRect(x: x, y: y, width: max(1, maxX - x), height: max(1, maxY - y))
    }
}
