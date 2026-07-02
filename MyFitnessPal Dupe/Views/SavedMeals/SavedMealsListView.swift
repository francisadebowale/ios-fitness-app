import SwiftData
import SwiftUI

struct SavedMealsListView: View {
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    var body: some View {
        List {
            Section("Saved Meals") {
                ForEach(savedMeals) { meal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.name)
                            .font(.headline)
                        Text("\(meal.calories) kcal · P \(meal.protein.formatted())g · C \(meal.carbs.formatted())g · F \(meal.fat.formatted())g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
