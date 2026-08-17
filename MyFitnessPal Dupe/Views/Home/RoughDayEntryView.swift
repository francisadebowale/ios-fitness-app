import SwiftData
import SwiftUI

struct RoughDayEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let date: Date

    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var fibre = 0.0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case fibre
    }

    private var canSave: Bool {
        calories >= 0 && protein >= 0 && carbs >= 0 && fat >= 0 && fibre >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Use this when you roughly know the day's totals but cannot track each food exactly.", systemImage: "calendar.badge.clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Rough Totals") {
                    NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $calories, field: Field.calories, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $protein, field: Field.protein, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $carbs, field: Field.carbs, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $fat, field: Field.fat, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fibre", unit: "g", value: $fibre, field: Field.fibre, focusedField: $focusedField)
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                bottomButton
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
#endif
            .navigationTitle("Rough Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: save) {
                Label("Log Rough Day", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func save() {
        guard canSave else { return }
        let entry = FoodEntry(
            name: "Rough day estimate",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fibre: fibre,
            mealType: .snack,
            date: date
        )
        modelContext.insert(entry)
        AppHaptics.success()
        dismiss()
    }
}

#Preview("Rough Day") {
    RoughDayEntryView(date: .now)
        .modelContainer(PreviewData.container())
}
