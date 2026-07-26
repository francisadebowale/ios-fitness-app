import Foundation
import CoreGraphics

struct NutritionLabelLayoutParseOutput: Equatable {
    var result: NutritionLabelParseResult
    var debugInfo: NutritionLabelParseDebugInfo
}

enum NutritionLabelLayoutParser {
    static func parse(rawText: String, observations: [NutritionLabelOCRObservation]) -> NutritionLabelLayoutParseOutput {
        let rows = reconstructedRows(from: observations)
        let layoutText = rows.joined(separator: "\n")
        let layoutResult = NutritionLabelParser.parse(layoutText)
        let fallbackResult = NutritionLabelParser.parse(rawText)

        if layoutResult.foundValueCount >= fallbackResult.foundValueCount {
            return NutritionLabelLayoutParseOutput(
                result: layoutResult,
                debugInfo: NutritionLabelParseDebugInfo(rawText: rawText, reconstructedRows: rows, parserName: "Vision layout")
            )
        }

        return NutritionLabelLayoutParseOutput(
            result: fallbackResult,
            debugInfo: NutritionLabelParseDebugInfo(rawText: rawText, reconstructedRows: rows, parserName: "Plain text fallback")
        )
    }

    static func reconstructedRows(from observations: [NutritionLabelOCRObservation]) -> [String] {
        let sorted = observations
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { first, second in
                if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.018 {
                    return first.boundingBox.midY > second.boundingBox.midY
                }
                return first.boundingBox.minX < second.boundingBox.minX
            }

        var rowGroups: [[NutritionLabelOCRObservation]] = []

        for observation in sorted {
            if let rowIndex = rowGroups.firstIndex(where: { row in
                guard let anchor = row.first else { return false }
                return abs(anchor.boundingBox.midY - observation.boundingBox.midY) <= max(0.022, anchor.boundingBox.height * 0.65)
            }) {
                rowGroups[rowIndex].append(observation)
            } else {
                rowGroups.append([observation])
            }
        }

        let rows = rowGroups.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        }

        return rows.compactMap { row in
            reconstructedRow(row, preferredColumnX: nil)
        }
    }

    private static func per100ColumnX(in rows: [[NutritionLabelOCRObservation]]) -> CGFloat? {
        for row in rows {
            for observation in row {
                let normalized = normalize(observation.text)
                if normalized.contains("per 100g") || normalized.contains("per100g") || normalized.contains("100 g") || normalized.contains("100g") {
                    return observation.boundingBox.midX
                }
            }
        }
        return nil
    }

    private static func reconstructedRow(_ row: [NutritionLabelOCRObservation], preferredColumnX: CGFloat?) -> String? {
        let sorted = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        guard !sorted.isEmpty else { return nil }

        let rowText = sorted.map(\.text).joined(separator: " ")
        let normalizedRow = normalize(rowText)
        guard !normalizedRow.contains("of which") else { return rowText }

        guard let preferredColumnX, let rowName = rowName(from: sorted) else {
            return rowText
        }

        let valuePieces = sorted
            .filter { abs($0.boundingBox.midX - preferredColumnX) < 0.20 || normalize($0.text).contains("kcal") }
            .filter { !isLikelyRowName($0.text) }
            .map(\.text)

        guard !valuePieces.isEmpty else { return rowText }
        return ([rowName] + valuePieces).joined(separator: " ")
    }

    private static func rowName(from row: [NutritionLabelOCRObservation]) -> String? {
        let texts = row.map(\.text)
        let joined = texts.joined(separator: " ")
        let normalized = normalize(joined)

        if normalized.contains("energy") || normalized.contains("kcal") {
            return "Energy"
        }
        if normalized.contains("fat") && !normalized.contains("satur") {
            return "Fat"
        }
        if normalized.contains("carbohydrate") || normalized.contains("carbs") {
            return "Carbohydrate"
        }
        if normalized.contains("protein") {
            return "Protein"
        }
        return nil
    }

    private static func isLikelyRowName(_ text: String) -> Bool {
        let normalized = normalize(text)
        return normalized.contains("energy")
            || normalized.contains("fat")
            || normalized.contains("carbohydrate")
            || normalized.contains("carbs")
            || normalized.contains("protein")
            || normalized.contains("per 100g")
            || normalized.contains("serving")
            || normalized.contains("typical values")
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
