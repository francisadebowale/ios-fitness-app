import SwiftUI

struct DailyTotalsView: View {
    let goals: DailyGoals
    let totals: NutritionTotals

    @ScaledMetric(relativeTo: .largeTitle) private var ringSize = 148

    private var remaining: NutritionTotals {
        NutritionCalculator.remaining(goals: goals, totals: totals)
    }

    private var calorieProgress: Double {
        min(NutritionCalculator.calorieProgress(goals: goals, totals: totals), 1)
    }

    private var fibreGoal: Double {
        goals.fibre ?? 25
    }

    var body: some View {
        Section {
            VStack(spacing: 20) {
                calorieRing

                VStack(spacing: 14) {
                    macroProgress(
                        title: "Protein",
                        consumed: totals.protein,
                        goal: goals.protein,
                        color: MacroColor.protein
                    )
                    macroProgress(
                        title: "Carbs",
                        consumed: totals.carbs,
                        goal: goals.carbs,
                        color: MacroColor.carbs
                    )
                    macroProgress(
                        title: "Fat",
                        consumed: totals.fat,
                        goal: goals.fat,
                        color: MacroColor.fat
                    )
                    if fibreGoal > 0 {
                        macroProgress(
                            title: "Fibre",
                            consumed: totals.fibre,
                            goal: fibreGoal,
                            color: .teal
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var calorieRing: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(MacroColor.calories.opacity(0.18), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(MacroColor.calories, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.25), value: calorieProgress)

                VStack(spacing: 2) {
                    Text("\(remaining.calories)")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("kcal left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.7)
                .padding()
            }
            .frame(width: min(ringSize, 190), height: min(ringSize, 190))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories")
            .accessibilityValue("\(totals.calories) eaten, \(remaining.calories) remaining, goal \(goals.calories)")

            Text("\(totals.calories) eaten of \(goals.calories) kcal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func macroProgress(title: String, consumed: Double, goal: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(gramText(consumed)) / \(gramText(goal))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: min(NutritionCalculator.progress(consumed: consumed, goal: goal), 1))
                .tint(color)
                .animation(.snappy(duration: 0.2), value: consumed)
        }
        .accessibilityElement(children: .combine)
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))g"
    }
}

#Preview("Light") {
    List {
        DailyTotalsView(
            goals: DailyGoals(calories: 2_200, protein: 160, carbs: 240, fat: 70, fibre: 25),
            totals: NutritionTotals(calories: 1_280, protein: 114, carbs: 126, fat: 31, fibre: 12)
        )
    }
}

#Preview("Dark Large Text") {
    List {
        DailyTotalsView(
            goals: DailyGoals(calories: 2_200, protein: 160, carbs: 240, fat: 70, fibre: 25),
            totals: NutritionTotals(calories: 1_280, protein: 114, carbs: 126, fat: 31, fibre: 12)
        )
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
