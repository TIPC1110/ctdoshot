import Foundation
import Vision
import AppKit

enum OCRManager {
    private static let queue = DispatchQueue(label: "ctdoshot.ocr", qos: .userInitiated)
    private static var currentRequest: VNRecognizeTextRequest?
    private static let lock = NSLock()

    static func cancel() {
        lock.lock()
        currentRequest?.cancel()
        currentRequest = nil
        lock.unlock()
    }

    static func recognizeText(in image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = makeCGImage(from: image) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        cancel()
        let baseRequest = VNRecognizeTextRequest()
        baseRequest.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        baseRequest.usesLanguageCorrection = true
        baseRequest.recognitionLanguages = preferredLanguages()
        if #available(macOS 13.0, *) { baseRequest.revision = VNRecognizeTextRequestRevision3 }
        lock.lock()
        currentRequest = baseRequest
        lock.unlock()
        queue.async {
            func performAndExtract(_ cg: CGImage, req: VNRecognizeTextRequest) -> (String?, Double) {
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:]).perform([req])
                    let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                    if obs.isEmpty { return (nil, 0) }
                    var sum: Double = 0; var cnt = 0
                    for o in obs { if let c = o.topCandidates(1).first { sum += Double(c.confidence); cnt += 1 } }
                    let avg = cnt > 0 ? sum/Double(cnt) : 0
                    let sorted = obs.sorted { a,b in
                        let ay = a.boundingBox.midY; let by = b.boundingBox.midY
                        if abs(ay - by) > 0.02 { return ay > by }
                        return a.boundingBox.minX < b.boundingBox.minX
                    }
                    let lines = sorted.compactMap { ob -> String? in
                        guard let cand = ob.topCandidates(1).first, cand.confidence >= 0.25 else { return nil }
                        let s = cand.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        return s.isEmpty ? nil : s
                    }
                    var t = lines.joined(separator: "\n")
                    if UserDefaults.standard.bool(forKey: "removeLineBreaks") {
                        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return (t.isEmpty ? nil : t, avg)
                } catch {
                    if let e = error as NSError?, e.domain == VNErrorDomain, e.code == 11 { return (nil, 0) }
                    return (nil, 0)
                }
            }
            let req1 = baseRequest
            let (firstText, firstConf) = performAndExtract(cgImage, req: req1)
            lock.lock()
            if currentRequest === req1 { currentRequest = nil }
            lock.unlock()

            var chosenText = firstText
            if let rotated = rotated180(cgImage) {
                let req2 = VNRecognizeTextRequest()
                req2.recognitionLevel = req1.recognitionLevel
                req2.usesLanguageCorrection = req1.usesLanguageCorrection
                req2.recognitionLanguages = req1.recognitionLanguages
                if #available(macOS 13.0, *) { req2.revision = VNRecognizeTextRequestRevision3 }
                let (secondText, secondConf) = performAndExtract(rotated, req: req2)
                if let s = secondText, secondConf > firstConf + 0.05, firstConf < 0.75 {
                    chosenText = s
                }
            }

            // ponytail: native Vision barcode/QR scan, zero third-party deps
            let barcodes = detectBarcodes(in: cgImage)
            let finalResult: String?
            if !barcodes.isEmpty {
                let barcodeHeader = barcodes.map { "[QR/Barcode] \($0)" }.joined(separator: "\n")
                if let text = chosenText, !text.isEmpty {
                    finalResult = "\(barcodeHeader)\n\n\(text)"
                } else {
                    finalResult = barcodeHeader
                }
            } else {
                finalResult = chosenText
            }

            DispatchQueue.main.async { completion(finalResult) }
        }
    }

    // ponytail: native Vision VNDetectBarcodesRequest for QR and 1D/2D barcodes
    private static func detectBarcodes(in cgImage: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:]).perform([request])
            let results = request.results ?? []
            return results.compactMap { $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private static func preferredLanguages() -> [String] {
        switch UserDefaults.standard.string(forKey: "ocrLanguage") ?? "English+" {
        case "Vietnamese":
            return ["vi-VN", "en-US"]
        case "Japanese":
            return ["ja-JP", "en-US"]
        default:
            return ["en-US", "vi-VN"]
        }
    }

    private static func makeCGImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           cg.width >= 2, cg.height >= 2 {
            return cg
        }
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let cg = rep.cgImage,
           cg.width >= 2 {
            return cg
        }
        let size = image.size
        let pxW = max(1, Int(size.width.rounded(.up)))
        let pxH = max(1, Int(size.height.rounded(.up)))
        guard pxW > 1, pxH > 1,
              let rep = NSBitmapImageRep(
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
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = ctx
        ctx.cgContext.translateBy(x: 0, y: CGFloat(pxH))
        ctx.cgContext.scaleBy(x: 1, y: -1)
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        return rep.cgImage
    }

    private static func rotated180(_ cg: CGImage) -> CGImage? {
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: CGFloat(w), y: CGFloat(h))
        ctx.rotate(by: .pi)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
