import Foundation
import SwiftData

@Model
final class FoodEntry {
    var name: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double?
    var mealTypeRawValue: String
    var date: Date

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRawValue) ?? .snack }
        set { mealTypeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fibre: Double = 0,
        mealType: MealType,
        date: Date = .now
    ) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fibre = fibre
        self.mealTypeRawValue = mealType.rawValue
        self.date = date
    }
}
