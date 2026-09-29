import SwiftData
import SwiftUI

struct SavedMealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var name = ""
    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var mealType = MealType.lunch

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Add Saved Meal") {
                    TextField("Name", text: $name)
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    TextField("Calories", value: $calories, format: .number)
                    TextField("Protein", value: $protein, format: .number)
                    TextField("Carbs", value: $carbs, format: .number)
                    TextField("Fat", value: $fat, format: .number)
                    Button("Save Meal", action: saveMeal)
                        .disabled(!canSave)
                }

                Section("Saved Meals") {
                    if savedMeals.isEmpty {
                        Text("No saved meals yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedMeals) { meal in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meal.name)
                                        .font(.headline)
                                    Text("\(meal.calories) cal · \(meal.mealType.displayName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Log", action: { logMeal(meal) })
                            }
                        }
                        .onDelete(perform: deleteMeals)
                    }
                }
            }
            .navigationTitle("Saved Meals")
        }
    }

    private func saveMeal() {
        let meal = SavedMeal(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            mealType: mealType
        )
        modelContext.insert(meal)
        resetForm()
    }

    private func logMeal(_ meal: SavedMeal) {
        let entry = FoodEntry(
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            mealType: meal.mealType
        )
        modelContext.insert(entry)
    }

    private func deleteMeals(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(savedMeals[offset])
        }
    }

    private func resetForm() {
        name = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        mealType = .lunch
    }
}
