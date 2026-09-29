import Foundation
import SwiftData

@Model
final class DailyGoals {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    init(calories: Int = 2_000, protein: Double = 150, carbs: Double = 250, fat: Double = 65) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}
