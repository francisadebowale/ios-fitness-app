import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name)
                .font(.headline)
            Text("\(entry.calories) kcal · P \(entry.protein.formatted())g · C \(entry.carbs.formatted())g · F \(entry.fat.formatted())g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
