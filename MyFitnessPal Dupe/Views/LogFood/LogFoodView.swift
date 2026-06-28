import SwiftData
import SwiftUI

struct LogFoodView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var mealType: MealType = .snack

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

                Section("Nutrition") {
                    LabeledContent("Calories") { TextField("0", value: $calories, format: .number) }
                    LabeledContent("Protein") { TextField("0", value: $protein, format: .number) }
                    LabeledContent("Carbs") { TextField("0", value: $carbs, format: .number) }
                    LabeledContent("Fat") { TextField("0", value: $fat, format: .number) }
                }

                Button("Log Food", action: logFood)
            }
            .navigationTitle("Log Food")
        }
    }

    private func logFood() {
        modelContext.insert(FoodEntry(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, mealType: mealType))
        name = ""
    }
}
