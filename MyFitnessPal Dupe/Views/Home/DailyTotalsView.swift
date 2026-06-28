import SwiftUI

struct DailyTotalsView: View {
    let goals: DailyGoals
    let totals: NutritionTotals

    var body: some View {
        Section("Daily Totals") {
            LabeledContent("Calories", value: "\(totals.calories) / \(goals.calories) kcal")
            LabeledContent("Protein", value: "\(Int(totals.protein)) / \(Int(goals.protein))g")
            LabeledContent("Carbs", value: "\(Int(totals.carbs)) / \(Int(goals.carbs))g")
            LabeledContent("Fat", value: "\(Int(totals.fat)) / \(Int(goals.fat))g")
        }
    }
}
