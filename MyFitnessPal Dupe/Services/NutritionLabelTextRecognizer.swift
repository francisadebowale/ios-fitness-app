import Foundation
import Vision

#if os(iOS)
import UIKit
#endif

enum NutritionLabelTextRecognizer {
#if os(iOS)
    static func recognize(in image: UIImage) async throws -> NutritionLabelRecognitionResult {
        guard let cgImage = image.cgImage else {
            return NutritionLabelRecognitionResult(rawText: "", observations: [], debugInfo: .empty)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let recognizedObservations = request.results as? [VNRecognizedTextObservation] ?? []
                let observations = recognizedObservations.compactMap { observation -> NutritionLabelOCRObservation? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return NutritionLabelOCRObservation(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                let rawText = observations.map(\.text).joined(separator: "\n")
                let debugInfo = NutritionLabelParseDebugInfo(rawText: rawText, reconstructedRows: [], parserName: "Vision OCR")
                continuation.resume(returning: NutritionLabelRecognitionResult(rawText: rawText, observations: observations, debugInfo: debugInfo))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImagePropertyOrientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
#endif
}

#if os(iOS)
private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
#endif
