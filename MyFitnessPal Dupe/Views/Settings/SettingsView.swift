import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]
    @Query private var entries: [FoodEntry]
    @Query private var savedMeals: [SavedMeal]
    @Query private var savedFoods: [SavedFood]
    @Query private var historyEntries: [DailyHistoryEntry]

    @AppStorage("developer.showScanDebug") private var showsScanDebug = false

    @State private var isEditingGoals = false
    @State private var draftCalories = 0
    @State private var draftProtein = 0.0
    @State private var draftCarbs = 0.0
    @State private var draftFat = 0.0
    @State private var draftFibre = 0.0
    @State private var exportURL: URL?
    @State private var showsResetConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case fibre
    }

    private struct ExportSnapshot: Codable {
        var exportedAt: Date
        var goals: [GoalExport]
        var entries: [EntryExport]
        var savedMeals: [MealExport]
        var savedFoods: [FoodExport]
        var history: [HistoryExport]
    }

    private struct GoalExport: Codable {
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        var fibre: Double?
    }

    private struct EntryExport: Codable {
        var name: String
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        var fibre: Double
        var mealType: String
        var date: Date
    }

    private struct MealExport: Codable {
        var name: String
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        var mealType: String
    }

    private struct FoodExport: Codable {
        var name: String
        var caloriesPer100: Double
        var proteinPer100: Double
        var carbsPer100: Double
        var fatPer100: Double
        var servingSize: Double?
        var servingUnit: String
    }

    private struct HistoryExport: Codable {
        var date: Date
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        var fibre: Double
        var weight: Double?
    }

    private var activeGoals: DailyGoals? {
        goals.first
    }

    private var canSave: Bool {
        draftCalories >= 0 && draftProtein >= 0 && draftCarbs >= 0 && draftFat >= 0 && draftFibre >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                dailyGoalsSection
                dataSection
                developerSection
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .navigationTitle("Settings")
            .toolbar {
                if isEditingGoals {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancelEditing)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveGoals)
                            .disabled(!canSave)
                    }

#if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
#endif
                }
            }
            .confirmationDialog("Reset all data?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
                Button("Reset All Data", role: .destructive, action: resetAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes logged entries, saved meals, saved foods, imported history, weigh-ins, and goals on this device.")
            }
            .onAppear(perform: ensureGoalsExist)
        }
    }

    @ViewBuilder
    private var dailyGoalsSection: some View {
        if let activeGoals {
            Section {
                if isEditingGoals {
                    NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $draftCalories, field: Field.calories, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $draftProtein, field: Field.protein, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $draftCarbs, field: Field.carbs, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $draftFat, field: Field.fat, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fibre", unit: "g", value: $draftFibre, field: Field.fibre, focusedField: $focusedField)

                    if !canSave {
                        Label("Goals must use non-negative values.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(action: saveGoals) {
                        Label("Save Goals", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(!canSave)
                } else {
                    goalRow("Calories", value: "\(activeGoals.calories) kcal", systemImage: "flame", color: MacroColor.calories)
                    goalRow("Protein", value: gramText(activeGoals.protein), systemImage: "bolt.fill", color: MacroColor.protein)
                    goalRow("Carbs", value: gramText(activeGoals.carbs), systemImage: "leaf.fill", color: MacroColor.carbs)
                    goalRow("Fat", value: gramText(activeGoals.fat), systemImage: "drop.fill", color: MacroColor.fat)
                    goalRow("Fibre", value: gramText(activeGoals.fibre ?? 25), systemImage: "circle.hexagongrid.fill", color: .teal)

                    Button {
                        startEditing(activeGoals)
                    } label: {
                        Label("Edit Daily Goals", systemImage: "slider.horizontal.3")
                    }
                }
            } header: {
                Text("Daily Goals")
            } footer: {
                Text(isEditingGoals ? "Tap Save when your targets are correct." : "Targets are used for Home progress and Assistant remaining macros.")
            }
        } else {
            Section("Daily Goals") {
                EmptyStateView(
                    title: "Goals Loading",
                    message: "Default daily goals are being created.",
                    systemImage: "target"
                )
            }
        }
    }

    private var dataSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share Export", systemImage: "square.and.arrow.up")
                }
            } else {
                Button(action: prepareExport) {
                    Label("Prepare Export", systemImage: "doc.badge.arrow.up")
                }
            }

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label("Reset All Data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Export creates a JSON backup. Reset removes data stored on this device.")
        }
    }

    private var developerSection: some View {
        Section {
            Toggle(isOn: $showsScanDebug) {
                Label("Show scan debug details", systemImage: "ladybug")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Shows raw OCR text and reconstructed rows on the food label review screen.")
        }
    }

    private func goalRow(_ title: String, value: String, systemImage: String, color: Color) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }
        }
    }

    private func prepareExport() {
        let snapshot = ExportSnapshot(
            exportedAt: .now,
            goals: goals.map { GoalExport(calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, fibre: $0.fibre) },
            entries: entries.map {
                EntryExport(name: $0.name, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, fibre: $0.fibre ?? 0, mealType: $0.mealType.rawValue, date: $0.date)
            },
            savedMeals: savedMeals.map {
                MealExport(name: $0.name, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, mealType: $0.mealType.rawValue)
            },
            savedFoods: savedFoods.map {
                FoodExport(
                    name: $0.name,
                    caloriesPer100: $0.caloriesPer100g,
                    proteinPer100: $0.proteinPer100g,
                    carbsPer100: $0.carbsPer100g,
                    fatPer100: $0.fatPer100g,
                    servingSize: $0.servingSizeGrams,
                    servingUnit: $0.servingUnit.rawValue
                )
            },
            history: historyEntries.map {
                HistoryExport(
                    date: $0.date,
                    calories: $0.calories,
                    protein: $0.protein,
                    carbs: $0.carbs,
                    fat: $0.fat,
                    fibre: $0.fibre,
                    weight: $0.weight
                )
            }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("MyFitnessPal-Dupe-Export.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
            AppHaptics.success()
        } catch {
            exportURL = nil
        }
    }

    private func resetAllData() {
        for entry in entries { modelContext.delete(entry) }
        for meal in savedMeals { modelContext.delete(meal) }
        for food in savedFoods { modelContext.delete(food) }
        for historyEntry in historyEntries { modelContext.delete(historyEntry) }
        for goal in goals { modelContext.delete(goal) }
        modelContext.insert(DailyGoals())
        exportURL = nil
        AppHaptics.success()
    }

    private func startEditing(_ goals: DailyGoals) {
        draftCalories = goals.calories
        draftProtein = goals.protein
        draftCarbs = goals.carbs
        draftFat = goals.fat
        draftFibre = goals.fibre ?? 25
        isEditingGoals = true
    }

    private func saveGoals() {
        guard canSave, let activeGoals else { return }

        activeGoals.calories = draftCalories
        activeGoals.protein = draftProtein
        activeGoals.carbs = draftCarbs
        activeGoals.fat = draftFat
        activeGoals.fibre = draftFibre
        focusedField = nil
        isEditingGoals = false
        AppHaptics.success()
    }

    private func cancelEditing() {
        focusedField = nil
        isEditingGoals = false
    }

    private func ensureGoalsExist() {
        guard goals.isEmpty else { return }
        modelContext.insert(DailyGoals())
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}

#Preview("Light") {
    SettingsView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark Large Text") {
    SettingsView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
