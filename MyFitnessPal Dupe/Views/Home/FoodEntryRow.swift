import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.headline)

                Spacer()

                Text(entry.mealType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.calories) cal · P \(gramText(entry.protein)) · C \(gramText(entry.carbs)) · F \(gramText(entry.fat))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))g"
    }
}
