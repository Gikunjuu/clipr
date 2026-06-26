import Vision
import AppKit

class OCRService {
    static let shared = OCRService()
    private let queue = DispatchQueue(label: "gikunju.design.Clipr.ocr", qos: .background)

    private init() {}

    func extractText(from image: NSImage, clipId: String) {
        queue.async {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { return }

            let request = VNRecognizeTextRequest { req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
                let text = obs
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                ClipStore.shared.updateOCRText(clipId: clipId, ocrText: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
