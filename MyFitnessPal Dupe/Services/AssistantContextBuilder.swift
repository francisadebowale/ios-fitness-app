import Foundation

struct AssistantContextBuilder {
    static func build(
        date: Date = .now,
        goals: DailyGoals?,
        entries: [FoodEntry],
        savedMeals: [SavedMeal],
        savedFoods: [SavedFood],
        calendar: Calendar = .current
    ) -> String {
        let goals = goals ?? DailyGoals()
        let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let totals = NutritionCalculator.totals(for: dayEntries)
        let remaining = NutritionCalculator.remaining(goals: goals, totals: totals)

        let entryLines = dayEntries.isEmpty
            ? ["- No food entries logged for this day."]
            : dayEntries.map { entry in
                "- \(entry.mealType.displayName): \(entry.name), \(entry.calories) kcal, protein \(format(entry.protein))g, carbs \(format(entry.carbs))g, fat \(format(entry.fat))g"
            }

        let savedMealLines = savedMeals.isEmpty
            ? ["- No saved meals."]
            : savedMeals.prefix(20).map { meal in
                "- \(meal.name): \(meal.calories) kcal, protein \(format(meal.protein))g, carbs \(format(meal.carbs))g, fat \(format(meal.fat))g"
            }

        let savedFoodLines = savedFoods.isEmpty
            ? ["- No saved foods."]
            : savedFoods.prefix(20).map { food in
                let unit = food.servingUnit
                let serving = food.servingSizeGrams.map { ", serving \(format($0))\(unit.abbreviation)" } ?? ""
                return "- \(food.name): \(unit.per100Label.lowercased()) \(format(food.caloriesPer100g)) kcal, protein \(format(food.proteinPer100g))g, carbs \(format(food.carbsPer100g))g, fat \(format(food.fatPer100g))g\(serving)"
            }

        return """
        Date: \(date.formatted(date: .abbreviated, time: .omitted))

        Daily goals:
        - Calories: \(goals.calories) kcal
        - Protein: \(format(goals.protein))g
        - Carbs: \(format(goals.carbs))g
        - Fat: \(format(goals.fat))g

        Totals logged in Swift:
        - Calories: \(totals.calories) kcal
        - Protein: \(format(totals.protein))g
        - Carbs: \(format(totals.carbs))g
        - Fat: \(format(totals.fat))g

        Remaining calculated in Swift:
        - Calories: \(remaining.calories) kcal
        - Protein: \(format(remaining.protein))g
        - Carbs: \(format(remaining.carbs))g
        - Fat: \(format(remaining.fat))g

        Logged entries:
        \(entryLines.joined(separator: "\n"))

        Saved meals:
        \(savedMealLines.joined(separator: "\n"))

        Saved foods:
        \(savedFoodLines.joined(separator: "\n"))
        """
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
