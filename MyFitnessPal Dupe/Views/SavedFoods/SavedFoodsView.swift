import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#endif

struct SavedFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFood.name) private var savedFoods: [SavedFood]

    @State private var searchText = ""
    @State private var confirmationMessage: String?
    @State private var addActionHandler = SavedFoodAddActionHandler.shared
    @State private var reviewResult: NutritionLabelParseResult?
    @State private var reviewIsManual = false
    @State private var isRecognizingText = false
    @State private var scanProgressMessage = "Reading label"
    @State private var foodToLog: SavedFood?
    @State private var foodToEdit: SavedFood?

#if os(iOS)
    @State private var pickerSourceType: UIImagePickerController.SourceType?
#endif

    private var visibleFoods: [SavedFood] {
        let filtered = searchText.isEmpty ? savedFoods : savedFoods.filter { $0.name.localizedStandardContains(searchText) }
        return filtered.sorted(by: favoriteSort)
    }

    var body: some View {
        ZStack(alignment: .top) {
            List {
                if isRecognizingText {
                    Section {
                        ProgressView(scanProgressMessage)
                    }
                }

                Section("Saved Foods") {
                    if savedFoods.isEmpty {
                        EmptyStateView(title: "No Saved Foods", message: "Tap + to scan a label, choose a photo, or enter food manually.", systemImage: "barcode.viewfinder")
                    } else if visibleFoods.isEmpty {
                        EmptyStateView(title: "No Results", message: "Try a different saved food search.", systemImage: "magnifyingglass")
                    } else {
                        ForEach(visibleFoods) { food in
                            Button {
                                foodToLog = food
                            } label: {
                                savedFoodRow(food)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(food.isFavorite == true ? "Unfavorite" : "Favorite", systemImage: food.isFavorite == true ? "star.slash" : "star") {
                                    toggleFavorite(food)
                                }
                                .tint(.yellow)

                                Button("Edit", systemImage: "pencil") {
                                    foodToEdit = food
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteVisibleFoods)
                    }
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .searchable(text: $searchText, prompt: "Search saved foods")

            if let confirmationMessage {
                Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $foodToLog) { food in
            SavedFoodLogSheet(food: food) { entry in
                modelContext.insert(entry)
                showConfirmation("Logged \(food.name)")
            }
        }
        .sheet(item: $foodToEdit) { food in
            SavedFoodEditView(food: food)
        }
        .sheet(item: reviewBinding) { item in
            SavedFoodReviewView(parseResult: item.result, startsInManualMode: item.isManual) {
                reviewResult = nil
                reviewIsManual = false
                presentCamera()
            }
        }
        .onAppear {
            handleAddAction(addActionHandler.action)
        }
        .onChange(of: addActionHandler.action) { _, action in
            handleAddAction(action)
        }
#if os(iOS)
        .sheet(item: $pickerSourceType) { sourceType in
            ImagePickerView(sourceType: sourceType) { image in
                processImage(image)
            }
        }
#endif
    }

    var addMenu: some View {
        Menu {
            Button("Scan Label", systemImage: "camera", action: presentCamera)
            Button("Choose Photo", systemImage: "photo", action: presentPhotoLibrary)
            Button("Enter Manually", systemImage: "square.and.pencil", action: enterManually)
        } label: {
            Image(systemName: "plus")
        }
    }

    private var reviewBinding: Binding<ReviewItem?> {
        Binding {
            guard let reviewResult else { return nil }
            return ReviewItem(result: reviewResult, isManual: reviewIsManual)
        } set: { newValue in
            if newValue == nil {
                reviewResult = nil
                reviewIsManual = false
            }
        }
    }

    private func savedFoodRow(_ food: SavedFood) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                Text("\(food.servingUnit.per100Label): \(food.caloriesPer100g.formatted(.number.precision(.fractionLength(0)))) kcal · P \(gramText(food.proteinPer100g)) · C \(gramText(food.carbsPer100g)) · F \(gramText(food.fatPer100g))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let servingSizeGrams = food.servingSizeGrams {
                    Text("Default serving: \(amountText(servingSizeGrams, unit: food.servingUnit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if food.isFavorite == true {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favourite")
            }
            Image(systemName: "plus.circle")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private func deleteVisibleFoods(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(visibleFoods[offset])
        }
        AppHaptics.lightImpact()
    }

    private func toggleFavorite(_ food: SavedFood) {
        food.isFavorite = !(food.isFavorite == true)
        AppHaptics.lightImpact()
    }

    private func favoriteSort(_ lhs: SavedFood, _ rhs: SavedFood) -> Bool {
        if (lhs.isFavorite == true) != (rhs.isFavorite == true) {
            return lhs.isFavorite == true
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func handleAddAction(_ action: SavedFoodAddAction?) {
        guard let action else { return }
        addActionHandler.action = nil

        switch action {
        case .scan:
            presentCamera()
        case .photo:
            presentPhotoLibrary()
        case .manual:
            enterManually()
        }
    }

    private func enterManually() {
        reviewIsManual = true
        reviewResult = NutritionLabelParseResult(calories: nil, protein: nil, carbs: nil, fat: nil, missingFields: NutritionLabelField.allCases, sanityWarning: false)
    }

    private func presentCamera() {
#if os(iOS)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            pickerSourceType = .camera
        } else {
            enterManually()
        }
#else
        enterManually()
#endif
    }

    private func presentPhotoLibrary() {
#if os(iOS)
        pickerSourceType = .photoLibrary
#else
        enterManually()
#endif
    }

#if os(iOS)
    private func processImage(_ image: UIImage) {
        isRecognizingText = true
        scanProgressMessage = "Reading label"
        Task { @MainActor in
            defer { isRecognizingText = false }
            do {
                let scanImage = image.scaledForNutritionOCR(maxDimension: 1_600)
                let recognition = try await NutritionLabelTextRecognizer.recognize(in: scanImage)
                let output = NutritionLabelLayoutParser.parse(rawText: recognition.rawText, observations: recognition.observations)

                scanProgressMessage = "Reading nutrition with AI"
                let aiInput = NutritionLabelAIExtractionInput(
                    rawText: recognition.rawText,
                    reconstructedRows: output.debugInfo.reconstructedRows,
                    observations: []
                )
                let aiResult = try? await withTimeout(seconds: 18) {
                    try await NutritionLabelAIExtractionServiceFactory.make().extractNutrition(from: aiInput)
                }

                var result = aiResult?.parseResult ?? output.result
                result.debugInfo = NutritionLabelParseDebugInfo(
                    rawText: recognition.rawText,
                    reconstructedRows: output.debugInfo.reconstructedRows,
                    parserName: aiResult == nil ? "Parser fallback" : "AI extraction"
                )
                reviewIsManual = !result.couldReadLabel
                reviewResult = result
            } catch {
                reviewIsManual = true
                reviewResult = NutritionLabelParseResult(calories: nil, protein: nil, carbs: nil, fat: nil, missingFields: NutritionLabelField.allCases, sanityWarning: false)
            }
        }
    }
#endif

    private func showConfirmation(_ message: String) {
        AppHaptics.success()
        withAnimation(.easeOut(duration: 0.2)) {
            confirmationMessage = message
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeIn(duration: 0.2)) {
                confirmationMessage = nil
            }
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }

    private func amountText(_ value: Double, unit: FoodServingUnit) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit.abbreviation)"
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
}

private struct SavedFoodLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let food: SavedFood
    let onLog: (FoodEntry) -> Void

    @State private var amount: Double
    @State private var mealType = MealType.snack
    @FocusState private var isAmountFocused: Bool

    init(food: SavedFood, onLog: @escaping (FoodEntry) -> Void) {
        self.food = food
        self.onLog = onLog
        _amount = State(initialValue: food.servingSizeGrams ?? 100)
    }

    private var scaled: ScaledFoodNutrition {
        SavedFoodCalculator.scaledNutrition(
            caloriesPer100g: food.caloriesPer100g,
            proteinPer100g: food.proteinPer100g,
            carbsPer100g: food.carbsPer100g,
            fatPer100g: food.fatPer100g,
            amount: amount
        )
    }

    private var canLog: Bool {
        amount > 0
    }

    private var quickAmounts: [Double] {
        var values: [Double] = []
        if let servingSizeGrams = food.servingSizeGrams, servingSizeGrams > 0 {
            values.append(servingSizeGrams)
        }
        values.append(contentsOf: [50, 100])
        return values.reduce(into: []) { result, value in
            if !result.contains(where: { abs($0 - value) < 0.1 }) {
                result.append(value)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text(food.servingUnit.amountLabel)
                        Spacer()
                        TextField(food.servingUnit.amountLabel, value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .nutritionKeyboard(.decimal)
                            .focused($isAmountFocused)
                            .frame(minWidth: 72)
                        Text(food.servingUnit.abbreviation)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAmounts, id: \.self) { quickAmount in
                                Button("\(quickAmount.formatted(.number.precision(.fractionLength(0...1))))\(food.servingUnit.abbreviation)") {
                                    amount = quickAmount
                                    AppHaptics.lightImpact()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }

                Section("Logged Nutrition") {
                    LabeledContent("Calories", value: "\(Int(scaled.calories.rounded())) kcal")
                    LabeledContent("Protein", value: "\(gramText(scaled.protein))")
                    LabeledContent("Carbs", value: "\(gramText(scaled.carbs))")
                    LabeledContent("Fat", value: "\(gramText(scaled.fat))")
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .navigationTitle(food.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log", action: logFood)
                        .disabled(!canLog)
                }
#if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isAmountFocused = false }
                }
#endif
            }
        }
    }

    private func logFood() {
        guard canLog else { return }
        onLog(SavedFoodCalculator.foodEntry(from: food, amount: amount, mealType: mealType))
        dismiss()
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}

private struct SavedFoodEditView: View {
    @Environment(\.dismiss) private var dismiss

    let food: SavedFood

    @State private var name: String
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var servingSizeText: String
    @State private var servingUnit: FoodServingUnit
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case serving
    }

    init(food: SavedFood) {
        self.food = food
        _name = State(initialValue: food.name)
        _calories = State(initialValue: food.caloriesPer100g)
        _protein = State(initialValue: food.proteinPer100g)
        _carbs = State(initialValue: food.carbsPer100g)
        _fat = State(initialValue: food.fatPer100g)
        _servingSizeText = State(initialValue: food.servingSizeGrams.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "")
        _servingUnit = State(initialValue: food.servingUnit)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var servingSize: Double? {
        let trimmed = servingSizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && calories >= 0
            && protein >= 0
            && carbs >= 0
            && fat >= 0
            && (servingSizeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (servingSize ?? -1) >= 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Unit", selection: $servingUnit) {
                        ForEach(FoodServingUnit.allCases) { unit in
                            Text(unit.abbreviation).tag(unit)
                        }
                    }
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

                Section(servingUnit.per100Label) {
                    editableField("Calories", unit: "kcal", value: $calories, field: .calories)
                    editableField("Protein", unit: "g", value: $protein, field: .protein)
                    editableField("Carbs", unit: "g", value: $carbs, field: .carbs)
                    editableField("Fat", unit: "g", value: $fat, field: .fat)
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .navigationTitle("Edit Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
#if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
#endif
            }
        }
    }

    private func editableField(_ title: String, unit: String, value: Binding<Double>, field: Field) -> some View {
        HStack {
            Text(title)
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

    private func save() {
        guard canSave else { return }
        food.name = trimmedName
        food.caloriesPer100g = calories
        food.proteinPer100g = protein
        food.carbsPer100g = carbs
        food.fatPer100g = fat
        food.servingSizeGrams = servingSize
        food.servingUnit = servingUnit
        AppHaptics.success()
        dismiss()
    }
}

private struct ReviewItem: Identifiable {
    let id = UUID()
    let result: NutritionLabelParseResult
    let isManual: Bool
}

#if os(iOS)
extension UIImagePickerController.SourceType: @retroactive Identifiable {
    public var id: Int { rawValue }
}

private extension UIImage {
    func scaledForNutritionOCR(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
#endif
