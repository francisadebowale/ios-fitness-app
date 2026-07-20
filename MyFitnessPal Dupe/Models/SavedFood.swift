import Foundation
import SwiftData

enum FoodServingUnit: String, CaseIterable, Identifiable, Codable {
    case grams
    case milliliters

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .grams:
            "g"
        case .milliliters:
            "ml"
        }
    }

    var per100Label: String {
        "Per 100\(abbreviation)"
    }

    var amountLabel: String {
        switch self {
        case .grams:
            "Grams"
        case .milliliters:
            "Milliliters"
        }
    }

    static func defaultUnit(for foodName: String) -> FoodServingUnit {
        let lowercasedName = foodName.lowercased()
        return lowercasedName.contains("milk") ? .milliliters : .grams
    }
}

@Model
final class SavedFood {
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var servingSizeGrams: Double?
    var servingUnitRawValue: String?
    var isFavorite: Bool?

    var servingUnit: FoodServingUnit {
        get {
            if let servingUnitRawValue, let unit = FoodServingUnit(rawValue: servingUnitRawValue) {
                return unit
            }
            return FoodServingUnit.defaultUnit(for: name)
        }
        set { servingUnitRawValue = newValue.rawValue }
    }

    init(
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        servingSizeGrams: Double? = nil,
        servingUnit: FoodServingUnit? = nil,
        isFavorite: Bool? = false
    ) {
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.servingSizeGrams = servingSizeGrams
        self.servingUnitRawValue = servingUnit?.rawValue
        self.isFavorite = isFavorite
    }
}
