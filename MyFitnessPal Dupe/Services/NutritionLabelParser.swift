import Foundation

enum NutritionLabelField: String, CaseIterable, Identifiable {
    case calories
    case protein
    case carbs
    case fat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calories:
            "Calories"
        case .protein:
            "Protein"
        case .carbs:
            "Carbs"
        case .fat:
            "Fat"
        }
    }
}

struct NutritionLabelParseResult: Equatable {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var servingSizeGrams: Double?
    var missingFields: [NutritionLabelField]
    var sanityWarning: Bool
    var debugInfo: NutritionLabelParseDebugInfo = .empty

    var foundValueCount: Int {
        [calories, protein, carbs, fat].compactMap { $0 }.count
    }

    var couldReadLabel: Bool {
        foundValueCount >= 2
    }
}

enum NutritionLabelParser {
    static func parse(_ text: String, debugInfo: NutritionLabelParseDebugInfo? = nil) -> NutritionLabelParseResult {
        let lines = normalizedLines(from: text)
        let hasPer100g = lines.contains { containsPer100g($0) }
        let servingSizeGrams = servingSize(from: lines)

        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?

        for index in lines.indices {
            let line = lines[index]
            guard !isIgnoredLine(line) else { continue }

            if calories == nil, isEnergyLine(line) {
                calories = valueForRow(line, unit: .kcal, servingSizeGrams: servingSizeGrams, preferFirst: hasPer100g) ?? nearbyKcalValue(in: lines, from: index)
            }

            if fat == nil, isFatLine(line) {
                fat = valueForRow(line, unit: .fat, servingSizeGrams: servingSizeGrams, preferFirst: hasPer100g) ?? nearbyGramValue(in: lines, from: index, unit: .fat)
            }

            if carbs == nil, isCarbLine(line) {
                carbs = valueForRow(line, unit: .carbs, servingSizeGrams: servingSizeGrams, preferFirst: hasPer100g) ?? nearbyGramValue(in: lines, from: index, unit: .carbs)
            }

            if protein == nil, isProteinLine(line) {
                protein = valueForRow(line, unit: .protein, servingSizeGrams: servingSizeGrams, preferFirst: hasPer100g) ?? nearbyGramValue(in: lines, from: index, unit: .protein)
            }
        }

        let missingFields = missingFields(calories: calories, protein: protein, carbs: carbs, fat: fat)
        let sanityWarning = shouldWarnAboutCalories(calories: calories, protein: protein, carbs: carbs, fat: fat)

        return NutritionLabelParseResult(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSizeGrams: servingSizeGrams,
            missingFields: missingFields,
            sanityWarning: sanityWarning,
            debugInfo: debugInfo ?? NutritionLabelParseDebugInfo(rawText: text, reconstructedRows: lines, parserName: "Plain text")
        )
    }

    private enum NutritionUnit {
        case kcal
        case fat
        case carbs
        case protein
    }

    private static func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func isIgnoredLine(_ line: String) -> Bool {
        let normalized = line.replacingOccurrences(of: " ", with: "")
        return line.contains("of which")
            || normalized.contains("ofwhich")
            || line.contains("sugar")
            || line.contains("satur")
            || line.contains("fibre")
            || line.contains("fiber")
            || line.contains("salt")
    }

    private static func containsPer100g(_ line: String) -> Bool {
        line.contains("100g") || line.contains("100 g")
    }

    private static func isEnergyLine(_ line: String) -> Bool {
        line.contains("energy") || line.contains("kcal")
    }

    private static func isFatLine(_ line: String) -> Bool {
        line.contains("fat") && !line.contains("satur")
    }

    private static func isCarbLine(_ line: String) -> Bool {
        line.contains("carbohydrate") || line.contains("carbs")
    }

    private static func isProteinLine(_ line: String) -> Bool {
        line.contains("protein")
    }

    private static func servingSize(from lines: [String]) -> Double? {
        let patterns = [
            #"per\s+[a-z ]+\((\d+(?:[\.,]\d+)?)\s*g\)"#,
            #"per\s+(?:serving|portion|pack|wrap|bar|slice|piece|pot|bowl)?\s*\(?\s*(\d+(?:[\.,]\d+)?)\s*g\)?"#,
            #"(\d+(?:[\.,]\d+)?)\s*g\s+(?:serving|portion|pack|wrap|bar|slice|piece|pot|bowl)"#,
            #"serving\s*size\D*(\d+(?:[\.,]\d+)?)\s*g"#,
            #"serving\D*(\d+(?:[\.,]\d+)?)\s*g"#
        ]

        for line in lines {
            for pattern in patterns {
                if let value = values(matching: pattern, in: line).first, value > 0, value != 100 {
                    return value
                }
            }
        }
        return nil
    }

    private static func valueForRow(_ line: String, unit: NutritionUnit, servingSizeGrams: Double?, preferFirst: Bool) -> Double? {
        let rowValues: [Double]
        switch unit {
        case .kcal:
            rowValues = kcalValues(from: line)
        case .fat, .carbs, .protein:
            rowValues = gramValuesForNutrientRow(line, unit: unit)
        }

        guard !rowValues.isEmpty else { return nil }
        guard rowValues.count >= 2 else {
            return rowValues.first
        }

        if let servingSizeGrams, servingSizeGrams > 0 {
            if let crossChecked = per100ValueByServingCrossCheck(rowValues, servingSizeGrams: servingSizeGrams) {
                return crossChecked
            }

            if servingSizeGrams < 100 {
                return rowValues.max()
            }
        }

        return preferFirst ? rowValues.first : rowValues.max()
    }

    private static func per100ValueByServingCrossCheck(_ values: [Double], servingSizeGrams: Double) -> Double? {
        for per100Candidate in values {
            for servingCandidate in values where servingCandidate != per100Candidate {
                let expectedServing = per100Candidate * servingSizeGrams / 100
                if valuesMatch(expectedServing, servingCandidate) {
                    return per100Candidate
                }
            }
        }
        return nil
    }

    private static func valuesMatch(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) <= max(0.25, abs(second) * 0.08)
    }

    private static func kcalValues(from line: String) -> [Double] {
        guard isEnergyLine(line) else { return [] }

        let explicitKcal = values(matching: #"(\d+(?:[\.,]\d+)?)\s*kcal"#, in: line)
        if !explicitKcal.isEmpty {
            return explicitKcal
        }

        let numbers = nutritionColumnNumbers(in: line).filter { $0 > 20 }
        guard line.contains("kj"), line.contains("kcal"), numbers.count >= 2 else {
            return numbers
        }

        let kjKcalPairs = stride(from: 0, to: numbers.count - 1, by: 2).compactMap { index -> Double? in
            let possibleKJ = numbers[index]
            let possibleKcal = numbers[index + 1]
            guard possibleKJ > possibleKcal, abs((possibleKcal * 4.184) - possibleKJ) / max(possibleKJ, 1) < 0.18 else {
                return nil
            }
            return possibleKcal
        }

        return kjKcalPairs.isEmpty ? numbers : kjKcalPairs
    }

    private static func gramValuesForNutrientRow(_ line: String, unit: NutritionUnit) -> [Double] {
        nutritionColumnNumbers(in: trimmedNutrientLine(line, unit: unit))
    }

    private static func trimmedNutrientLine(_ line: String, unit: NutritionUnit) -> String {
        let stopWords: [String]
        switch unit {
        case .kcal:
            stopWords = []
        case .fat:
            stopWords = ["satur", "salt"]
        case .carbs:
            stopWords = ["of which", "ofwhich", "sugar", "fibre", "fiber", "salt"]
        case .protein:
            stopWords = ["salt"]
        }

        var trimmed = line
        for stopWord in stopWords {
            if let range = trimmed.range(of: stopWord) {
                trimmed = String(trimmed[..<range.lowerBound])
            }
        }
        return trimmed
    }

    private static func nutritionColumnNumbers(in line: String) -> [Double] {
        allNumbers(in: line).filter { value in
            value != 100 && value != servingSize(from: [line])
        }
    }

    private static func nearbyKcalValue(in lines: [String], from index: Int) -> Double? {
        let searchRange = (index + 1)..<min(lines.count, index + 4)
        for nextIndex in searchRange {
            if let value = valueForRow(lines[nextIndex], unit: .kcal, servingSizeGrams: servingSize(from: lines), preferFirst: true) {
                return value
            }
        }
        return nil
    }

    private static func nearbyGramValue(in lines: [String], from index: Int, unit: NutritionUnit) -> Double? {
        let searchRange = (index + 1)..<min(lines.count, index + 3)
        for nextIndex in searchRange {
            let line = lines[nextIndex]
            guard !isIgnoredLine(line), !containsKnownRowName(line) else { continue }
            if let value = valueForRow(line, unit: unit, servingSizeGrams: servingSize(from: lines), preferFirst: true) {
                return value
            }
        }
        return nil
    }

    private static func containsKnownRowName(_ line: String) -> Bool {
        isEnergyLine(line) || isFatLine(line) || isCarbLine(line) || isProteinLine(line)
    }

    private static func values(matching pattern: String, in line: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: line) else { return nil }
            return Double(line[matchRange].replacingOccurrences(of: ",", with: "."))
        }
    }

    private static func allNumbers(in line: String) -> [Double] {
        values(matching: #"(\d+(?:[\.,]\d+)?)"#, in: line)
    }

    static func missingFields(calories: Double?, protein: Double?, carbs: Double?, fat: Double?) -> [NutritionLabelField] {
        var fields: [NutritionLabelField] = []
        if calories == nil { fields.append(.calories) }
        if protein == nil { fields.append(.protein) }
        if carbs == nil { fields.append(.carbs) }
        if fat == nil { fields.append(.fat) }
        return fields
    }

    static func shouldWarnAboutCalories(calories: Double?, protein: Double?, carbs: Double?, fat: Double?) -> Bool {
        guard let calories, let protein, let carbs, let fat, calories > 0 else { return false }
        let macroCalories = protein * 4 + carbs * 4 + fat * 9
        return abs(macroCalories - calories) / calories > 0.15
    }
}
