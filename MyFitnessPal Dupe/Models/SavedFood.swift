import Foundation
import SwiftData

@Model
final class SavedFood {
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var servingSizeGrams: Double?

    init(name: String, caloriesPer100g: Double, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double, servingSizeGrams: Double? = nil) {
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.servingSizeGrams = servingSizeGrams
    }
}
