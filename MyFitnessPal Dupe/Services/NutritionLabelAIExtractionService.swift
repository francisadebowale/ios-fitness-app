import Foundation
import CoreGraphics
#if canImport(FoundationModels)
import FoundationModels
#endif

struct NutritionLabelAIExtractionInput: Equatable {
    var rawText: String
    var reconstructedRows: [String]
    var observations: [NutritionLabelOCRObservation]
}

struct NutritionLabelAIValidationInput: Equatable {
    var rawText: String
    var reconstructedRows: [String]
    var currentCalories: Double?
    var currentProtein: Double?
    var currentCarbs: Double?
    var currentFat: Double?
    var currentServingSizeGrams: Double?
}

struct NutritionLabelAIExtractionResult: Decodable, Equatable {
    var name: String?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var servingSizeGrams: Double?
    var missingFields: [String]
    var confidence: String?

    var parseResult: NutritionLabelParseResult {
        NutritionLabelParseResult(
            calories: caloriesPer100g,
            protein: proteinPer100g,
            carbs: carbsPer100g,
            fat: fatPer100g,
            servingSizeGrams: servingSizeGrams,
            missingFields: NutritionLabelParser.missingFields(
                calories: caloriesPer100g,
                protein: proteinPer100g,
                carbs: carbsPer100g,
                fat: fatPer100g
            ),
            sanityWarning: NutritionLabelParser.shouldWarnAboutCalories(
                calories: caloriesPer100g,
                protein: proteinPer100g,
                carbs: carbsPer100g,
                fat: fatPer100g
            )
        )
    }
}

protocol NutritionLabelAIExtractionService {
    func extractNutrition(from input: NutritionLabelAIExtractionInput) async throws -> NutritionLabelAIExtractionResult?
    func validateNutrition(from input: NutritionLabelAIValidationInput) async throws -> NutritionLabelAIExtractionResult?
}

enum NutritionLabelAIExtractionPromptBuilder {
    static func prompt(for input: NutritionLabelAIExtractionInput) -> String {
        return """
        /no_think
        You extract nutrition label values from OCR. Return only valid JSON. Do not explain.

        Rules:
        - Use PER 100G values only.
        - Never use Per serving, Per wrap, Per portion, Each, or serving-size columns.
        - If both kJ and kcal are present, use kcal.
        - Ignore rows beginning with or referring to "of which", including sugars and saturates.
        - Calories are kcal per 100g.
        - Protein, carbs, and fat are grams per 100g.
        - Protein must come only from a row explicitly labelled "protein". Never use fibre/fiber, salt, sodium, sugars, saturates, or carbohydrate values for protein.
        - Carbs must come only from carbohydrate/carbs total. Never use fibre/fiber or "of which sugars" for carbs.
        - Fat must come only from fat total. Never use saturates for fat.
        - If unsure or missing, use null.
        - Do not calculate missing values from other values.
        - Return exactly this JSON shape:
        {"name":null,"caloriesPer100g":null,"proteinPer100g":null,"carbsPer100g":null,"fatPer100g":null,"servingSizeGrams":null,"missingFields":[],"confidence":"low"}

        Raw OCR text:
        \(input.rawText)

        Possible reconstructed rows, which may be corrupted by layout OCR. Use only when they agree with the raw OCR text:
        \(input.reconstructedRows.joined(separator: "\n"))

        """
    }

    static func validationPrompt(for input: NutritionLabelAIValidationInput) -> String {
        """
        /no_think
        Validate nutrition label OCR. Return only valid JSON. Do not explain.

        Rules:
        - Use PER 100G values only.
        - Do not use per serving, per wrap, per portion, each, or pack values as per 100g values.
        - If a serving column exists, use it only to cross-check the per 100g column.
        - If a header says Per Wrap (62g), Per 40g, Serving 40g, or similar, set servingSizeGrams.
        - Ignore "of which" rows like sugars and saturates.
        - Protein must come only from a row explicitly labelled "protein". Never use fibre/fiber, salt, sodium, sugars, saturates, or carbohydrate values for protein.
        - Carbs must come only from carbohydrate/carbs total. Never use fibre/fiber or "of which sugars" for carbs.
        - Fat must come only from fat total. Never use saturates for fat.
        - If unsure, use null.
        - Return exactly this JSON shape:
        {"name":null,"caloriesPer100g":null,"proteinPer100g":null,"carbsPer100g":null,"fatPer100g":null,"servingSizeGrams":null,"missingFields":[],"confidence":"low"}

        Current parser values:
        caloriesPer100g=\(number(input.currentCalories))
        proteinPer100g=\(number(input.currentProtein))
        carbsPer100g=\(number(input.currentCarbs))
        fatPer100g=\(number(input.currentFat))
        servingSizeGrams=\(number(input.currentServingSizeGrams))

        Possible reconstructed rows, which may be corrupted by layout OCR. Use only when they agree with the raw OCR text:
        \(input.reconstructedRows.joined(separator: "\n"))

        Raw OCR text:
        \(input.rawText)
        """
    }

    private static func number(_ value: Double?) -> String {
        value.map { String($0) } ?? "null"
    }
}

enum NutritionLabelAIJSONParser {
    static func parse(_ text: String) -> NutritionLabelAIExtractionResult? {
        guard let jsonData = jsonObjectString(from: text)?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NutritionLabelAIExtractionResult.self, from: jsonData)
    }

    private static func jsonObjectString(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(text[start...end])
    }
}

enum NutritionLabelAIPostProcessor {
    static func corrected(_ result: NutritionLabelAIExtractionResult, using input: NutritionLabelAIExtractionInput) -> NutritionLabelAIExtractionResult {
        var corrected = result
        let table = NutritionLabelRawPer100Table.extract(from: input.rawText)

        if table.confirmedValueCount >= 3 {
            corrected.caloriesPer100g = table.calories ?? corrected.caloriesPer100g
            corrected.proteinPer100g = table.protein ?? corrected.proteinPer100g
            corrected.carbsPer100g = table.carbs ?? corrected.carbsPer100g
            corrected.fatPer100g = table.fat ?? corrected.fatPer100g
            corrected.servingSizeGrams = table.servingSizeGrams ?? corrected.servingSizeGrams
            corrected.missingFields = missingFieldNames(for: corrected)
            return corrected
        }

        corrected = rejectWrongRowMatches(in: corrected, rawText: input.rawText)
        corrected.missingFields = missingFieldNames(for: corrected)
        return corrected
    }

    private static func rejectWrongRowMatches(in result: NutritionLabelAIExtractionResult, rawText: String) -> NutritionLabelAIExtractionResult {
        var corrected = result
        let rows = NutritionLabelRawRows.extract(from: rawText)

        if let protein = corrected.proteinPer100g, rows.value(protein, matchesAny: [.fibre, .salt, .sugars, .saturates, .carbs, .fat]) {
            corrected.proteinPer100g = rows.protein
        }

        if let carbs = corrected.carbsPer100g, rows.value(carbs, matchesAny: [.fibre, .sugars, .protein, .salt]) {
            corrected.carbsPer100g = rows.carbs
        }

        if let fat = corrected.fatPer100g, rows.value(fat, matchesAny: [.saturates, .protein, .salt]) {
            corrected.fatPer100g = rows.fat
        }

        return corrected
    }

    private static func missingFieldNames(for result: NutritionLabelAIExtractionResult) -> [String] {
        NutritionLabelParser.missingFields(
            calories: result.caloriesPer100g,
            protein: result.proteinPer100g,
            carbs: result.carbsPer100g,
            fat: result.fatPer100g
        ).map(\.rawValue)
    }
}

private struct NutritionLabelRawPer100Table {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var servingSizeGrams: Double?

    var confirmedValueCount: Int {
        [calories, protein, carbs, fat].compactMap { $0 }.count
    }

    static func extract(from text: String) -> NutritionLabelRawPer100Table {
        let lines = normalizedLines(from: text)
        let servingSize = servingSizeGrams(from: lines)
        guard let per100Index = lines.firstIndex(where: { $0.contains("per 100g") || $0.contains("per 100 g") }) else {
            return NutritionLabelRawPer100Table(servingSizeGrams: servingSize)
        }

        let labels = nutrientLabels(before: per100Index, in: lines)
        let values = per100Values(after: per100Index, in: lines)
        guard labels.count >= 4, values.count >= 4 else {
            return NutritionLabelRawPer100Table(servingSizeGrams: servingSize)
        }

        var table = NutritionLabelRawPer100Table(servingSizeGrams: servingSize)
        for (label, valueText) in zip(labels, values) {
            switch label {
            case .energy:
                table.calories = kcalValue(from: valueText)
            case .fat:
                table.fat = gramValue(from: valueText)
            case .carbs:
                table.carbs = gramValue(from: valueText)
            case .protein:
                table.protein = gramValue(from: valueText)
            case .saturates, .sugars, .fibre, .salt:
                break
            }
        }
        return table
    }

    private static func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func nutrientLabels(before index: Int, in lines: [String]) -> [NutritionLabelRawRows.Kind] {
        var labels: [NutritionLabelRawRows.Kind] = []
        let start = max(0, index - 24)
        for line in lines[start..<index] {
            guard let label = NutritionLabelRawRows.Kind(exactLabel: line), !labels.contains(label) else { continue }
            labels.append(label)
        }
        return labels
    }

    private static func per100Values(after index: Int, in lines: [String]) -> [String] {
        var values: [String] = []
        for line in lines.dropFirst(index + 1) {
            if line.contains("per wrap") || line.contains("per serving") || line.contains("per portion") || line.contains("each") {
                break
            }
            guard kcalValue(from: line) != nil || gramValue(from: line) != nil else { continue }
            values.append(line)
            if values.count == 8 { break }
        }
        return values
    }

    private static func kcalValue(from line: String) -> Double? {
        value(matching: #"(\d+(?:[\.,]\d+)?)\s*kcal"#, in: line)
    }

    private static func gramValue(from line: String) -> Double? {
        value(matching: #"(\d+(?:[\.,]\d+)?)\s*g\b"#, in: line)
    }

    private static func servingSizeGrams(from lines: [String]) -> Double? {
        for line in lines {
            if let value = value(matching: #"per\s+[a-z ]+\((\d+(?:[\.,]\d+)?)\s*g\)"#, in: line), value != 100 {
                return value
            }
        }
        return nil
    }

    private static func value(matching pattern: String, in line: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), let matchRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[matchRange].replacingOccurrences(of: ",", with: "."))
    }
}

private struct NutritionLabelRawRows {
    enum Kind: CaseIterable, Equatable {
        case energy
        case fat
        case saturates
        case carbs
        case sugars
        case fibre
        case protein
        case salt

        init?(exactLabel line: String) {
            let compact = line.replacingOccurrences(of: " ", with: "")
            switch compact {
            case "energy": self = .energy
            case "fat": self = .fat
            case "ofwhichsaturates": self = .saturates
            case "carbohydrate", "carbs": self = .carbs
            case "ofwhichsugars": self = .sugars
            case "fibre", "fiber": self = .fibre
            case "protein": self = .protein
            case "salt": self = .salt
            default: return nil
            }
        }
    }

    var fat: Double?
    var saturates: Double?
    var carbs: Double?
    var sugars: Double?
    var fibre: Double?
    var protein: Double?
    var salt: Double?

    static func extract(from text: String) -> NutritionLabelRawRows {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        var rows = NutritionLabelRawRows()
        for line in lines {
            guard let kind = Kind.allCases.first(where: { lineContains($0, line: line) }), let value = gramValue(from: line) else { continue }
            switch kind {
            case .energy:
                continue
            case .fat:
                rows.fat = rows.fat ?? value
            case .saturates:
                rows.saturates = rows.saturates ?? value
            case .carbs:
                rows.carbs = rows.carbs ?? value
            case .sugars:
                rows.sugars = rows.sugars ?? value
            case .fibre:
                rows.fibre = rows.fibre ?? value
            case .protein:
                rows.protein = rows.protein ?? value
            case .salt:
                rows.salt = rows.salt ?? value
            }
        }
        return rows
    }

    func value(_ candidate: Double, matchesAny kinds: [Kind]) -> Bool {
        kinds.contains { kind in
            guard let rowValue = value(for: kind) else { return false }
            return abs(rowValue - candidate) <= max(0.15, abs(rowValue) * 0.04)
        }
    }

    private func value(for kind: Kind) -> Double? {
        switch kind {
        case .energy:
            nil
        case .fat:
            fat
        case .saturates:
            saturates
        case .carbs:
            carbs
        case .sugars:
            sugars
        case .fibre:
            fibre
        case .protein:
            protein
        case .salt:
            salt
        }
    }

    private static func lineContains(_ kind: Kind, line: String) -> Bool {
        switch kind {
        case .energy:
            line.contains("energy")
        case .fat:
            line.contains("fat") && !line.contains("satur")
        case .saturates:
            line.contains("satur")
        case .carbs:
            line.contains("carbohydrate") || line.contains("carbs")
        case .sugars:
            line.contains("sugar")
        case .fibre:
            line.contains("fibre") || line.contains("fiber")
        case .protein:
            line.contains("protein")
        case .salt:
            line.contains("salt")
        }
    }

    private static func gramValue(from line: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:[\.,]\d+)?)\s*g\b"#, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), let matchRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[matchRange].replacingOccurrences(of: ",", with: "."))
    }
}

struct LocalQwenNutritionLabelAIExtractionService: NutritionLabelAIExtractionService {
    private let qwen: LocalQwenService

    init(qwen: LocalQwenService = .shared) {
        self.qwen = qwen
    }

    func extractNutrition(from input: NutritionLabelAIExtractionInput) async throws -> NutritionLabelAIExtractionResult? {
        let instructions = """
        You extract structured nutrition data from OCR text.
        Return only valid JSON with no Markdown and no explanation.
        You must select PER 100G values only.
        Protein must come only from a row explicitly labelled protein. Never use fibre, fiber, salt, sodium, sugars, saturates, carbs, or fat as protein.
        """
        let response = try await qwen.generate(
            prompt: NutritionLabelAIExtractionPromptBuilder.prompt(for: input),
            instructions: instructions,
            maxTokens: 220,
            temperature: 0
        )
        guard let result = NutritionLabelAIJSONParser.parse(response) else { return nil }
        return NutritionLabelAIPostProcessor.corrected(result, using: input)
    }

    func validateNutrition(from input: NutritionLabelAIValidationInput) async throws -> NutritionLabelAIExtractionResult? {
        let instructions = """
        You validate structured nutrition data from OCR text.
        Return only valid JSON with no Markdown and no explanation.
        You must select PER 100G values only.
        Protein must come only from a row explicitly labelled protein. Never use fibre, fiber, salt, sodium, sugars, saturates, carbs, or fat as protein.
        """
        let response = try await qwen.generate(
            prompt: NutritionLabelAIExtractionPromptBuilder.validationPrompt(for: input),
            instructions: instructions,
            maxTokens: 160,
            temperature: 0
        )
        return NutritionLabelAIJSONParser.parse(response)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct FoundationNutritionLabelExtraction {
    @Guide(description: "Product or food name from the label. Use nil if unclear.")
    var name: String?

    @Guide(description: "Calories in kcal per 100g. Use nil if unclear.")
    var caloriesPer100g: Double?

    @Guide(description: "Protein in grams per 100g. Must come only from a row explicitly labelled protein. Never use fibre/fiber, salt, sodium, sugars, saturates, carbs, or fat. Use nil if unclear.")
    var proteinPer100g: Double?

    @Guide(description: "Carbohydrate total in grams per 100g. Do not use sugars/of which sugars. Use nil if unclear.")
    var carbsPer100g: Double?

    @Guide(description: "Fat total in grams per 100g. Do not use saturates/of which saturates. Use nil if unclear.")
    var fatPer100g: Double?

    @Guide(description: "Serving size in grams from headers like Per Wrap (62g), Per 40g, or serving size. Use nil if unclear.")
    var servingSizeGrams: Double?

    @Guide(description: "Nutrition fields that are missing or not confirmed. Use names: calories, protein, carbs, fat, servingSize.")
    var missingFields: [String]

    @Guide(description: "Confidence for this extraction: high, medium, or low.")
    var confidence: String?

    var extractionResult: NutritionLabelAIExtractionResult {
        NutritionLabelAIExtractionResult(
            name: name,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            servingSizeGrams: servingSizeGrams,
            missingFields: missingFields,
            confidence: confidence
        )
    }
}

@available(iOS 26.0, *)
struct FoundationModelsNutritionLabelAIExtractionService: NutritionLabelAIExtractionService {
    private let model = SystemLanguageModel.default

    var isAvailable: Bool {
        if case .available = model.availability {
            return model.capabilities.contains(.guidedGeneration)
        }
        return false
    }

    func extractNutrition(from input: NutritionLabelAIExtractionInput) async throws -> NutritionLabelAIExtractionResult? {
        guard isAvailable else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You extract nutrition label values from OCR text. Return only the structured fields requested.
            Use PER 100G values only. Never use per serving, per wrap, per portion, each, pack, or serving-size columns as per 100g values.
            If both kJ and kcal are present, use kcal only. Ignore rows beginning with or referring to of which, including sugars and saturates.
            If a serving column exists, use it only to cross-check per 100g values. If a value cannot be confirmed, leave it nil and list it in missingFields.
            Protein must come only from a row explicitly labelled protein. Never use fibre, fiber, salt, sodium, sugars, saturates, carbs, or fat as protein.
            Carbs must come only from carbohydrate/carbs total. Never use fibre/fiber or sugars as carbs.
            Fat must come only from fat total. Never use saturates as fat.
            Do not calculate missing values from other values.
            """
        )

        let response = try await session.respond(
            to: NutritionLabelAIExtractionPromptBuilder.prompt(for: input),
            generating: FoundationNutritionLabelExtraction.self
        )
        return NutritionLabelAIPostProcessor.corrected(response.content.extractionResult, using: input)
    }

    func validateNutrition(from input: NutritionLabelAIValidationInput) async throws -> NutritionLabelAIExtractionResult? {
        guard isAvailable else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You validate nutrition label values from OCR text. Return only the structured fields requested.
            Use PER 100G values only. Never use per serving, per wrap, per portion, each, pack, or serving-size columns as per 100g values.
            If a serving column exists, use it only to cross-check per 100g values. If a value cannot be confirmed, leave it nil and list it in missingFields.
            Ignore of which rows like sugars and saturates.
            Protein must come only from a row explicitly labelled protein. Never use fibre, fiber, salt, sodium, sugars, saturates, carbs, or fat as protein.
            Carbs must come only from carbohydrate/carbs total. Never use fibre/fiber or sugars as carbs.
            Fat must come only from fat total. Never use saturates as fat.
            """
        )

        let response = try await session.respond(
            to: NutritionLabelAIExtractionPromptBuilder.validationPrompt(for: input),
            generating: FoundationNutritionLabelExtraction.self
        )
        return response.content.extractionResult
    }
}
#endif

enum NutritionLabelAIExtractionServiceFactory {
    static func make() -> any NutritionLabelAIExtractionService {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let foundationModelsService = FoundationModelsNutritionLabelAIExtractionService()
            if foundationModelsService.isAvailable {
                return foundationModelsService
            }
        }
        #endif

        return LocalQwenNutritionLabelAIExtractionService()
    }
}
