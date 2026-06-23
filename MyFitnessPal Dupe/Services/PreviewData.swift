import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static func container() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: DailyGoals.self,
                FoodEntry.self,
                SavedMeal.self,
                SavedFood.self,
                DailyHistoryEntry.self,
                configurations: configuration
            )
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }

    private static func seed(_ context: ModelContext) {
        context.insert(DailyGoals(calories: 2_200, protein: 160, carbs: 240, fat: 70))
        context.insert(FoodEntry(name: "Greek yogurt bowl", calories: 420, protein: 32, carbs: 48, fat: 10, mealType: .breakfast))
        context.insert(FoodEntry(name: "Chicken rice bowl", calories: 680, protein: 52, carbs: 72, fat: 18, mealType: .lunch))
        context.insert(FoodEntry(name: "Protein shake", calories: 180, protein: 30, carbs: 6, fat: 3, mealType: .snack))
        context.insert(SavedMeal(name: "Turkey sandwich", calories: 520, protein: 38, carbs: 54, fat: 16, mealType: .lunch))
        context.insert(SavedMeal(name: "Oats and banana", calories: 390, protein: 18, carbs: 68, fat: 8, mealType: .breakfast))
        context.insert(SavedFood(name: "Greek yogurt", caloriesPer100g: 59, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 0.4, servingSizeGrams: 170))
        context.insert(SavedFood(name: "Oats", caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9, servingSizeGrams: 40))
        context.insert(DailyHistoryEntry(date: .now.addingTimeInterval(-86400 * 21), calories: 2100, protein: 150, carbs: 230, fat: 62, fibre: 28, weight: 84.2))
        context.insert(DailyHistoryEntry(date: .now.addingTimeInterval(-86400 * 14), calories: 2050, protein: 155, carbs: 220, fat: 58, fibre: 30, weight: 83.7))
        context.insert(DailyHistoryEntry(date: .now.addingTimeInterval(-86400 * 7), calories: 2200, protein: 148, carbs: 245, fat: 65, fibre: 25, weight: 83.1))
    }
}
