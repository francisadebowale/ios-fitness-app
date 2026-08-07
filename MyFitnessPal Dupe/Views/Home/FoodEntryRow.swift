import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Text("\(entry.calories) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MacroColor.calories)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                macroText("P", entry.protein, MacroColor.protein)
                macroText("C", entry.carbs, MacroColor.carbs)
                macroText("F", entry.fat, MacroColor.fat)
                if (entry.fibre ?? 0) > 0 {
                    macroText("Fi", entry.fibre ?? 0, .teal)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func macroText(_ label: String, _ value: Double, _ color: Color) -> some View {
        Label {
            Text("\(label) \(gramText(value))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } icon: {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .labelStyle(.titleAndIcon)
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))g"
    }
}
