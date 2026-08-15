import Foundation
import SwiftData

@Model
final class DailyHistoryEntry {
    var date: Date
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
    var weight: Double?

    init(
        date: Date,
        calories: Int = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fibre: Double = 0,
        weight: Double? = nil
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fibre = fibre
        self.weight = weight
    }
}
