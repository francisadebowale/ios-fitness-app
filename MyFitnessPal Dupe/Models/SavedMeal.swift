import Foundation
import SwiftData

@Model
final class SavedMeal {
    var name: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var mealTypeRawValue: String

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRawValue) ?? .snack }
        set { mealTypeRawValue = newValue.rawValue }
    }

    init(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, mealType: MealType) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.mealTypeRawValue = mealType.rawValue
    }
}
