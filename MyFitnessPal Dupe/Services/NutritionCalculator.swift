import Foundation

struct NutritionTotals: Equatable {
    var calories: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fibre: Double = 0

    static let zero = NutritionTotals()
}

enum NutritionCalculator {
    static func totals(for entries: [FoodEntry]) -> NutritionTotals {
        entries.reduce(into: .zero) { totals, entry in
            totals.calories += entry.calories
            totals.protein += entry.protein
            totals.carbs += entry.carbs
            totals.fat += entry.fat
            totals.fibre += entry.fibre ?? 0
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

    static func calorieProgress(goals: DailyGoals, totals: NutritionTotals) -> Double {
        progress(consumed: Double(totals.calories), goal: Double(goals.calories))
    }

    static func progress(consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return max(0, consumed / goal)
    }
}
