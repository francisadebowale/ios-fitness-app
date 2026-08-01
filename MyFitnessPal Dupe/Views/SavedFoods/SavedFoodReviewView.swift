import SwiftData
import SwiftUI

struct SavedFoodReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let parseResult: NutritionLabelParseResult
    let startsInManualMode: Bool
    let onRetake: () -> Void

    @State private var isManualMode: Bool
    @State private var name = ""
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var servingSizeText = ""
    @State private var servingUnit = FoodServingUnit.grams
    @State private var servingUnitWasEdited = false
    @AppStorage("developer.showScanDebug") private var showsDebugInfo = false
    @State private var mealType = MealType.snack
    @State private var aiCheckState = AICheckState.idle
    @FocusState private var focusedField: Field?

    private enum AICheckState: Equatable {
        case idle
        case checking
        case noSuggestion
        case suggestion(NutritionLabelAIExtractionResult)
        case unavailable
    }

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case serving
    }

    init(parseResult: NutritionLabelParseResult, startsInManualMode: Bool = false, onRetake: @escaping () -> Void) {
        self.parseResult = parseResult
        self.startsInManualMode = startsInManualMode
        self.onRetake = onRetake
        _isManualMode = State(initialValue: startsInManualMode)
        _calories = State(initialValue: parseResult.calories ?? 0)
        _protein = State(initialValue: parseResult.protein ?? 0)
        _carbs = State(initialValue: parseResult.carbs ?? 0)
        _fat = State(initialValue: parseResult.fat ?? 0)
        _servingSizeText = State(initialValue: parseResult.servingSizeGrams.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "")
    }

    private var shouldShowFailure: Bool {
        !startsInManualMode && !isManualMode && !parseResult.couldReadLabel
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && calories >= 0
            && protein >= 0
            && carbs >= 0
            && fat >= 0
            && servingSizeGramsIsValid
    }

    private var servingSizeGrams: Double? {
        let trimmed = servingSizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private var servingSizeGramsIsValid: Bool {
        let trimmed = servingSizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || (servingSizeGrams ?? -1) >= 0
    }

    private var amountToLog: Double {
        servingSizeGrams ?? 100
    }

    private var servingUnitSelection: Binding<FoodServingUnit> {
        Binding {
            servingUnit
        } set: { newValue in
            servingUnit = newValue
            servingUnitWasEdited = true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if shouldShowFailure {
                    failedScanSection
                } else {
                    reviewForm
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                if !shouldShowFailure {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveFood)
                            .disabled(!canSave)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                if !shouldShowFailure {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveFood)
                            .disabled(!canSave)
                    }
                }
            }
#endif
            .navigationTitle("Review Food")
            .task {
                await runAICheckIfNeeded()
            }
            .onChange(of: name) { _, newName in
                guard !servingUnitWasEdited else { return }
                servingUnit = FoodServingUnit.defaultUnit(for: newName)
            }
        }
    }

    private var failedScanSection: some View {
        Section {
            EmptyStateView(
                title: "Couldn't read this label",
                message: "Try another photo or enter the nutrition manually.",
                systemImage: "text.viewfinder"
            )
            Button("Retake", action: onRetake)
            Button("Enter Manually") {
                isManualMode = true
            }
        }
    }

    private var reviewForm: some View {
        Group {
            if startsInManualMode && !parseResult.couldReadLabel {
                Section {
                    Label("Some fields could not be read. Check the values and fill in anything missing.", systemImage: "text.viewfinder")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Food") {
                TextField("Name", text: $name)
                Picker("Unit", selection: servingUnitSelection) {
                    ForEach(FoodServingUnit.allCases) { unit in
                        Text(unit.abbreviation).tag(unit)
                    }
                }
                servingField
            }

            Section(servingUnit.per100Label) {
                parsedField(title: "Calories", unit: "kcal", value: $calories, field: .calories, missingField: .calories)
                parsedField(title: "Protein", unit: "g", value: $protein, field: .protein, missingField: .protein)
                parsedField(title: "Carbs", unit: "g", value: $carbs, field: .carbs, missingField: .carbs)
                parsedField(title: "Fat", unit: "g", value: $fat, field: .fat, missingField: .fat)
            }

            if !parseResult.missingFields.isEmpty && !startsInManualMode {
                Section {
                    Text("Missing fields are highlighted. Fill them in before saving.")
                        .foregroundStyle(.red)
                }
            }

            if parseResult.sanityWarning {
                Section {
                    Text("These numbers may be wrong. Macro calories differ from listed calories by more than 15%.")
                        .foregroundStyle(.orange)
                }
            }

            aiCheckSection

            saveAndLogSection

            debugSection
        }
    }

    private var aiCheckSection: some View {
        Section("AI Check") {
            switch aiCheckState {
            case .idle:
                EmptyView()
            case .checking:
                HStack {
                    ProgressView()
                    Text("Checking per 100g values")
                        .foregroundStyle(.secondary)
                }
            case .noSuggestion:
                Label("No AI corrections suggested", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            case .suggestion(let suggestion):
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI found values to review", systemImage: "sparkles")
                    Text(suggestionSummary(suggestion))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Apply Suggestions") {
                            applySuggestion(suggestion)
                        }
                        Button("Ignore") {
                            aiCheckState = .noSuggestion
                        }
                    }
                }
            case .unavailable:
                Label("AI check skipped", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var saveAndLogSection: some View {
        Section("Save and Log") {
            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.displayName).tag(meal)
                }
            }

            Button("Save & Log \(amountToLog.formatted(.number.precision(.fractionLength(0...1))))\(servingUnit.abbreviation)") {
                saveFood(logEntry: true)
            }
            .disabled(!canSave || amountToLog <= 0)
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        if showsDebugInfo {
            Section("Developer") {
                LabeledContent("Parser", value: parseResult.debugInfo.parserName)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Raw OCR Text")
                        .font(.headline)
                    Text(parseResult.debugInfo.rawText.isEmpty ? "No text recognized" : parseResult.debugInfo.rawText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reconstructed Rows")
                        .font(.headline)
                    Text(parseResult.debugInfo.reconstructedRows.isEmpty ? "No rows reconstructed" : parseResult.debugInfo.reconstructedRows.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var servingField: some View {
        HStack {
            Text("Serving Size")
            Spacer()
            TextField("Optional", text: $servingSizeText)
                .multilineTextAlignment(.trailing)
                .nutritionKeyboard(.decimal)
                .focused($focusedField, equals: .serving)
                .frame(minWidth: 72)
            Text(servingUnit.abbreviation)
                .foregroundStyle(.secondary)
        }
    }

    private func parsedField(title: String, unit: String, value: Binding<Double>, field: Field, missingField: NutritionLabelField) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(parseResult.missingFields.contains(missingField) ? .red : .primary)
            Spacer()
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .nutritionKeyboard(field == .calories ? .number : .decimal)
                .focused($focusedField, equals: field)
                .frame(minWidth: 72)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func runAICheckIfNeeded() async {
        guard parseResult.debugInfo.parserName != "AI extraction" else { return }
        guard aiCheckState == .idle, !parseResult.debugInfo.rawText.isEmpty || !parseResult.debugInfo.reconstructedRows.isEmpty else { return }

        aiCheckState = .checking
        do {
            try await Task.sleep(for: .milliseconds(900))
            let input = NutritionLabelAIValidationInput(
                rawText: parseResult.debugInfo.rawText,
                reconstructedRows: parseResult.debugInfo.reconstructedRows,
                currentCalories: calories,
                currentProtein: protein,
                currentCarbs: carbs,
                currentFat: fat,
                currentServingSizeGrams: servingSizeGrams
            )
            let suggestion = try await withTimeout(seconds: 12) {
                try await NutritionLabelAIExtractionServiceFactory.make().validateNutrition(from: input)
            }

            if let suggestion, hasUsefulDifference(suggestion) {
                aiCheckState = .suggestion(suggestion)
            } else {
                aiCheckState = .noSuggestion
            }
        } catch {
            aiCheckState = .unavailable
        }
    }

    private func hasUsefulDifference(_ suggestion: NutritionLabelAIExtractionResult) -> Bool {
        differs(suggestion.caloriesPer100g, from: calories)
            || differs(suggestion.proteinPer100g, from: protein)
            || differs(suggestion.carbsPer100g, from: carbs)
            || differs(suggestion.fatPer100g, from: fat)
            || differs(suggestion.servingSizeGrams, from: servingSizeGrams)
    }

    private func differs(_ suggested: Double?, from current: Double?) -> Bool {
        guard let suggested else { return false }
        guard let current else { return true }
        return abs(suggested - current) > max(0.2, abs(current) * 0.03)
    }

    private func suggestionSummary(_ suggestion: NutritionLabelAIExtractionResult) -> String {
        var parts: [String] = []
        if differs(suggestion.caloriesPer100g, from: calories), let value = suggestion.caloriesPer100g {
            parts.append("Calories: \(value.formatted(.number.precision(.fractionLength(0...1)))) kcal")
        }
        if differs(suggestion.proteinPer100g, from: protein), let value = suggestion.proteinPer100g {
            parts.append("Protein: \(value.formatted(.number.precision(.fractionLength(0...1))))g")
        }
        if differs(suggestion.carbsPer100g, from: carbs), let value = suggestion.carbsPer100g {
            parts.append("Carbs: \(value.formatted(.number.precision(.fractionLength(0...1))))g")
        }
        if differs(suggestion.fatPer100g, from: fat), let value = suggestion.fatPer100g {
            parts.append("Fat: \(value.formatted(.number.precision(.fractionLength(0...1))))g")
        }
        if differs(suggestion.servingSizeGrams, from: servingSizeGrams), let value = suggestion.servingSizeGrams {
            parts.append("Serving: \(value.formatted(.number.precision(.fractionLength(0...1))))g")
        }
        return parts.joined(separator: "\n")
    }

    private func applySuggestion(_ suggestion: NutritionLabelAIExtractionResult) {
        if let value = suggestion.caloriesPer100g { calories = value }
        if let value = suggestion.proteinPer100g { protein = value }
        if let value = suggestion.carbsPer100g { carbs = value }
        if let value = suggestion.fatPer100g { fat = value }
        if let value = suggestion.servingSizeGrams {
            servingSizeText = value.formatted(.number.precision(.fractionLength(0...1)))
        }
        aiCheckState = .noSuggestion
        AppHaptics.lightImpact()
    }

    private func withTimeout<T: Sendable>(seconds: UInt64, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func saveFood() {
        saveFood(logEntry: false)
    }

    private func saveFood(logEntry: Bool) {
        guard canSave else { return }

        let savedFood = SavedFood(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            caloriesPer100g: calories,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingSizeGrams: servingSizeGrams,
            servingUnit: servingUnit
        )
        modelContext.insert(savedFood)

        if logEntry {
            let entry = SavedFoodCalculator.foodEntry(from: savedFood, amount: amountToLog, mealType: mealType)
            modelContext.insert(entry)
        }

        dismiss()
    }
}
