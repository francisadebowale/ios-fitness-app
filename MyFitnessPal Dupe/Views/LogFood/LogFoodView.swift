import SwiftData
import SwiftUI

struct LogFoodView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var mealType = MealType.breakfast

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }

                Section("Macros") {
                    TextField("Calories", value: $calories, format: .number)
                    TextField("Protein", value: $protein, format: .number)
                    TextField("Carbs", value: $carbs, format: .number)
                    TextField("Fat", value: $fat, format: .number)
                }

                Section {
                    Button("Log Food", action: saveEntry)
                        .disabled(!canSave)
                }
            }
            .navigationTitle("Log Food")
        }
    }

    private func saveEntry() {
        let entry = FoodEntry(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            mealType: mealType
        )
        modelContext.insert(entry)
        resetForm()
    }

    private func resetForm() {
        name = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        mealType = .breakfast
    }
}
