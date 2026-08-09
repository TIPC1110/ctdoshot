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

        let request = VNRecognizeTextRequest { request, error in
            defer {
                lock.lock()
                if currentRequest === (request as? VNRecognizeTextRequest) {
                    currentRequest = nil
                }
                lock.unlock()
            }

            if let error = error as NSError?,
               error.domain == VNErrorDomain,
               error.code == 11 /* VNErrorRequestCancelled */ {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            guard !observations.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let sorted = observations.sorted { a, b in
                let ay = a.boundingBox.midY
                let by = b.boundingBox.midY
                if abs(ay - by) > 0.02 { return ay > by }
                return a.boundingBox.minX < b.boundingBox.minX
            }

            let lines = sorted.compactMap { obs -> String? in
                guard let candidate = obs.topCandidates(1).first, candidate.confidence >= 0.25 else {
                    return nil
                }
                let s = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }

            var text = lines.joined(separator: "\n")
            if UserDefaults.standard.bool(forKey: "removeLineBreaks") {
                text = text
                    .replacingOccurrences(
                        of: "\\s+",
                        with: " ",
                        options: .regularExpression
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            DispatchQueue.main.async {
                completion(text.isEmpty ? nil : text)
            }
        }

        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = preferredLanguages()
        if #available(macOS 13.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }

        lock.lock()
        currentRequest = request
        lock.unlock()

        queue.async {
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
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
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        return rep.cgImage
    }
}
