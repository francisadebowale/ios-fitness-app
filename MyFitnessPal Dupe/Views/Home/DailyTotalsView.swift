import SwiftUI

struct DailyTotalsView: View {
    let goals: DailyGoals
    let totals: NutritionTotals

    private var remaining: NutritionTotals {
        NutritionCalculator.remaining(goals: goals, totals: totals)
    }

    var body: some View {
        Section("Today") {
            nutrientRow(title: "Calories", consumed: "\(totals.calories)", goal: "\(goals.calories)", remaining: "\(remaining.calories)")
            nutrientRow(title: "Protein", consumed: gramText(totals.protein), goal: gramText(goals.protein), remaining: gramText(remaining.protein))
            nutrientRow(title: "Carbs", consumed: gramText(totals.carbs), goal: gramText(goals.carbs), remaining: gramText(remaining.carbs))
            nutrientRow(title: "Fat", consumed: gramText(totals.fat), goal: gramText(goals.fat), remaining: gramText(remaining.fat))
        }
    }

    private func nutrientRow(title: String, consumed: String, goal: String, remaining: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            HStack {
                Text("Consumed: \(consumed)")
                Spacer()
                Text("Goal: \(goal)")
                Spacer()
                Text("Left: \(remaining)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))g"
    }
}
