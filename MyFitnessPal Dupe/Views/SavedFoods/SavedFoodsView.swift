import SwiftData
import SwiftUI

struct SavedFoodsView: View {
    @Query(sort: \SavedFood.name) private var savedFoods: [SavedFood]

    var body: some View {
        List {
            Section("Saved Foods") {
                ForEach(savedFoods) { food in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.headline)
                        Text("Per 100g: \(Int(food.caloriesPer100g)) kcal · P \(food.proteinPer100g.formatted())g · C \(food.carbsPer100g.formatted())g · F \(food.fatPer100g.formatted())g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
