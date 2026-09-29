import Foundation

struct NutritionTotals {
    var calories: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
}

enum NutritionCalculator {
    static func totals(for entries: [FoodEntry]) -> NutritionTotals {
        entries.reduce(into: NutritionTotals()) { totals, entry in
            totals.calories += entry.calories
            totals.protein += entry.protein
            totals.carbs += entry.carbs
            totals.fat += entry.fat
        }
    }

    static func remaining(goals: DailyGoals, totals: NutritionTotals) -> NutritionTotals {
        NutritionTotals(
            calories: goals.calories - totals.calories,
            protein: goals.protein - totals.protein,
            carbs: goals.carbs - totals.carbs,
            fat: goals.fat - totals.fat
        )
    }
}
