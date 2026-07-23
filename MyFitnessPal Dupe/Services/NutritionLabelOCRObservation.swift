import Foundation
import CoreGraphics

struct NutritionLabelOCRObservation: Equatable {
    var text: String
    var boundingBox: CGRect
    var confidence: Float
}

struct NutritionLabelParseDebugInfo: Equatable {
    var rawText: String
    var reconstructedRows: [String]
    var parserName: String

    static let empty = NutritionLabelParseDebugInfo(rawText: "", reconstructedRows: [], parserName: "Manual")
}

struct NutritionLabelRecognitionResult: Equatable {
    var rawText: String
    var observations: [NutritionLabelOCRObservation]
    var debugInfo: NutritionLabelParseDebugInfo
}
