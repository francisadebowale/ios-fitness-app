import SwiftData
import SwiftUI

struct SavedMealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavedFood.name) private var savedFoods: [SavedFood]

    private let meal: SavedMeal?

    @State private var name: String
    @State private var calories: Int
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var mealType: MealType
    @State private var components: [SavedMealFoodComponent] = []
    @State private var showingFoodPicker = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case componentAmount(UUID)
    }

    init(meal: SavedMeal? = nil) {
        self.meal = meal
        _name = State(initialValue: meal?.name ?? "")
        _calories = State(initialValue: meal?.calories ?? 0)
        _protein = State(initialValue: meal?.protein ?? 0)
        _carbs = State(initialValue: meal?.carbs ?? 0)
        _fat = State(initialValue: meal?.fat ?? 0)
        _mealType = State(initialValue: meal?.mealType ?? .lunch)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && calories >= 0 && protein >= 0 && carbs >= 0 && fat >= 0
    }

    private var builderTotals: ScaledFoodNutrition {
        components.reduce(ScaledFoodNutrition(calories: 0, protein: 0, carbs: 0, fat: 0)) { partial, component in
            let scaled = SavedFoodCalculator.scaledNutrition(
                caloriesPer100g: component.food.caloriesPer100g,
                proteinPer100g: component.food.proteinPer100g,
                carbsPer100g: component.food.carbsPer100g,
                fatPer100g: component.food.fatPer100g,
                amount: component.amount
            )
            return ScaledFoodNutrition(
                calories: partial.calories + scaled.calories,
                protein: partial.protein + scaled.protein,
                carbs: partial.carbs + scaled.carbs,
                fat: partial.fat + scaled.fat
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }

                buildFromFoodsSection

                Section("Nutrition") {
                    NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $calories, field: Field.calories, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $protein, field: Field.protein, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $carbs, field: Field.carbs, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $fat, field: Field.fat, focusedField: $focusedField)
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveMeal)
                        .disabled(!canSave)
                }
#if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
#endif
            }
            .navigationTitle(meal == nil ? "Saved Meal" : "Edit Meal")
            .sheet(isPresented: $showingFoodPicker) {
                SavedFoodPickerSheet(savedFoods: savedFoods) { food in
                    add(food)
                }
            }
        }
    }

    private var buildFromFoodsSection: some View {
        Section {
            if savedFoods.isEmpty {
                ContentUnavailableView {
                    Label("No saved foods", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Save foods first, then combine them into meals.")
                }
            } else {
                Button {
                    showingFoodPicker = true
                } label: {
                    Label("Add Saved Food", systemImage: "plus.circle")
                }
            }

            if !components.isEmpty {
                ForEach($components) { $component in
                    mealComponentRow($component)
                }
                .onDelete(perform: deleteComponents)

                LabeledContent("Builder Total", value: "\(Int(builderTotals.calories.rounded())) kcal")
                    .font(.headline)
                LabeledContent("Protein", value: gramText(builderTotals.protein))
                LabeledContent("Carbs", value: gramText(builderTotals.carbs))
                LabeledContent("Fat", value: gramText(builderTotals.fat))

                Button {
                    applyBuilderTotals()
                } label: {
                    Label("Use Builder Totals", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Build From Saved Foods")
        } footer: {
            Text("Add foods and set amounts, then use the calculated total for this saved meal. Saved meals still store one combined total.")
        }
    }

    private func mealComponentRow(_ component: Binding<SavedMealFoodComponent>) -> some View {
        let food = component.wrappedValue.food
        let unit = food.servingUnit
        let scaled = SavedFoodCalculator.scaledNutrition(
            caloriesPer100g: food.caloriesPer100g,
            proteinPer100g: food.proteinPer100g,
            carbsPer100g: food.carbsPer100g,
            fatPer100g: food.fatPer100g,
            amount: component.wrappedValue.amount
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(food.name)
                    .font(.body.weight(.medium))
                Spacer(minLength: 12)
                Text("\(Int(scaled.calories.rounded())) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MacroColor.calories)
                    .monospacedDigit()
            }

            HStack {
                TextField(unit.amountLabel, value: component.amount, format: .number)
                    .multilineTextAlignment(.trailing)
                    .nutritionKeyboard(.decimal)
                    .focused($focusedField, equals: .componentAmount(component.wrappedValue.id))
                    .frame(maxWidth: 110)
                Text(unit.abbreviation)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("P \(gramText(scaled.protein)) · C \(gramText(scaled.carbs)) · F \(gramText(scaled.fat))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private func add(_ food: SavedFood) {
        let amount = food.servingSizeGrams ?? 100
        components.append(SavedMealFoodComponent(food: food, amount: amount))
        AppHaptics.lightImpact()
    }

    private func deleteComponents(at offsets: IndexSet) {
        components.remove(atOffsets: offsets)
        AppHaptics.lightImpact()
    }

    private func applyBuilderTotals() {
        calories = Int(builderTotals.calories.rounded())
        protein = builderTotals.protein
        carbs = builderTotals.carbs
        fat = builderTotals.fat
        AppHaptics.success()
    }

    private func saveMeal() {
        guard canSave else { return }
        if let meal {
            meal.name = trimmedName
            meal.calories = calories
            meal.protein = protein
            meal.carbs = carbs
            meal.fat = fat
            meal.mealType = mealType
        } else {
            modelContext.insert(SavedMeal(name: trimmedName, calories: calories, protein: protein, carbs: carbs, fat: fat, mealType: mealType))
        }
        AppHaptics.success()
        dismiss()
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}

private struct SavedMealFoodComponent: Identifiable {
    let id = UUID()
    let food: SavedFood
    var amount: Double
}

private struct SavedFoodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let savedFoods: [SavedFood]
    let onSelect: (SavedFood) -> Void

    @State private var searchText = ""

    private var visibleFoods: [SavedFood] {
        let filtered = searchText.isEmpty ? savedFoods : savedFoods.filter { $0.name.localizedStandardContains(searchText) }
        return filtered.sorted(by: favoriteSort)
    }

    var body: some View {
        NavigationStack {
            List {
                if visibleFoods.isEmpty {
                    ContentUnavailableView {
                        Label("No foods found", systemImage: "magnifyingglass")
                    }
                } else {
                    ForEach(visibleFoods) { food in
                        Button {
                            onSelect(food)
                            dismiss()
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name)
                                        .font(.body.weight(.medium))
                                    Text("\(food.servingUnit.per100Label): \(Int(food.caloriesPer100g.rounded())) kcal · P \(gramText(food.proteinPer100g)) · C \(gramText(food.carbsPer100g)) · F \(gramText(food.fatPer100g))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if food.isFavorite == true {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                }
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search saved foods")
            .navigationTitle("Add Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }

    private func favoriteSort(_ lhs: SavedFood, _ rhs: SavedFood) -> Bool {
        if (lhs.isFavorite == true) != (rhs.isFavorite == true) {
            return lhs.isFavorite == true
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
