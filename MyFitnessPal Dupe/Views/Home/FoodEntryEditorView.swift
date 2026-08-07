import SwiftData
import SwiftUI

struct FoodEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var entry: FoodEntry
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case fibre
    }

    private var canSave: Bool {
        !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.calories >= 0
            && entry.protein >= 0
            && entry.carbs >= 0
            && entry.fat >= 0
            && (entry.fibre ?? 0) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $entry.name)
                    Picker("Meal", selection: $entry.mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                }

                Section("Macros") {
                    NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $entry.calories, field: Field.calories, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $entry.protein, field: Field.protein, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $entry.carbs, field: Field.carbs, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $entry.fat, field: Field.fat, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fibre", unit: "g", value: Binding(
                        get: { entry.fibre ?? 0 },
                        set: { entry.fibre = $0 }
                    ), field: Field.fibre, focusedField: $focusedField)
                }

                if !canSave {
                    Section {
                        Text("Use a name and non-negative nutrition values.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: saveAsMeal) {
                        HStack {
                            Text("Save as Meal")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }

                    Button(role: .destructive, action: deleteEntry) {
                        HStack {
                            Text("Delete Entry")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(!canSave)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
#endif
            .navigationTitle("Edit Food")
        }
    }

    private func saveAsMeal() {
        let meal = SavedMeal(
            name: entry.name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            mealType: entry.mealType
        )
        modelContext.insert(meal)
    }

    private func deleteEntry() {
        modelContext.delete(entry)
        dismiss()
    }
}
