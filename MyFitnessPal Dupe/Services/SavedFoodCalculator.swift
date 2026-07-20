import Foundation

struct ScaledFoodNutrition: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

enum SavedFoodCalculator {
    static func scaledNutrition(
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        amount: Double
    ) -> ScaledFoodNutrition {
        let multiplier = max(amount, 0) / 100
        return ScaledFoodNutrition(
            calories: caloriesPer100g * multiplier,
            protein: proteinPer100g * multiplier,
            carbs: carbsPer100g * multiplier,
            fat: fatPer100g * multiplier
        )
    }

    static func foodEntry(from food: SavedFood, amount: Double, mealType: MealType) -> FoodEntry {
        let scaled = scaledNutrition(
            caloriesPer100g: food.caloriesPer100g,
            proteinPer100g: food.proteinPer100g,
            carbsPer100g: food.carbsPer100g,
            fatPer100g: food.fatPer100g,
            amount: amount
        )

        return FoodEntry(
            name: food.name,
            calories: Int(scaled.calories.rounded()),
            protein: scaled.protein,
            carbs: scaled.carbs,
            fat: scaled.fat,
            mealType: mealType
        )
    }
}
