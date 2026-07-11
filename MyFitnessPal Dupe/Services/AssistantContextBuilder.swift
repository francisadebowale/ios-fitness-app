import Foundation

struct AssistantContextBuilder {
    func context(goals: DailyGoals?, entries: [FoodEntry], savedMeals: [SavedMeal], savedFoods: [SavedFood]) -> String {
        "Nutrition context available."
    }
}
