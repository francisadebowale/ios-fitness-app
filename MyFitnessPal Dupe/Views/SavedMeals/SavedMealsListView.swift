import SwiftData
import SwiftUI

struct SavedMealsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var searchText = ""
    @State private var confirmationMessage: String?
    @State private var mealToLog: SavedMeal?
    @State private var mealToEdit: SavedMeal?

    private var visibleMeals: [SavedMeal] {
        let filtered = searchText.isEmpty ? savedMeals : savedMeals.filter { $0.name.localizedStandardContains(searchText) }
        return filtered.sorted(by: favoriteSort)
    }

    var body: some View {
        ZStack(alignment: .top) {
            List {
                Section("Saved Meals") {
                    if savedMeals.isEmpty {
                        EmptyStateView(title: "No Saved Meals", message: "Tap + to save meals you eat often.", systemImage: "bookmark")
                    } else if visibleMeals.isEmpty {
                        EmptyStateView(title: "No Results", message: "Try a different saved meal search.", systemImage: "magnifyingglass")
                    } else {
                        ForEach(visibleMeals) { meal in
                            Button {
                                mealToLog = meal
                            } label: {
                                savedMealRow(meal)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(meal.isFavorite == true ? "Unfavorite" : "Favorite", systemImage: meal.isFavorite == true ? "star.slash" : "star") {
                                    toggleFavorite(meal)
                                }
                                .tint(.yellow)

                                Button("Edit", systemImage: "pencil") {
                                    mealToEdit = meal
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteVisibleMeals)
                    }
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .searchable(text: $searchText, prompt: "Search saved meals")

            if let confirmationMessage {
                Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $mealToLog) { meal in
            SavedMealLogSheet(meal: meal) { entry in
                modelContext.insert(entry)
                showConfirmation("Logged \(meal.name)")
            }
        }
        .sheet(item: $mealToEdit) { meal in
            SavedMealFormView(meal: meal)
        }
    }

    private func savedMealRow(_ meal: SavedMeal) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.headline)
                Text("\(meal.calories) kcal · P \(gramText(meal.protein)) · C \(gramText(meal.carbs)) · F \(gramText(meal.fat))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(meal.mealType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if meal.isFavorite == true {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favourite")
            }
            Image(systemName: "plus.circle")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private func showConfirmation(_ message: String) {
        AppHaptics.success()
        withAnimation(.easeOut(duration: 0.2)) {
            confirmationMessage = message
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeIn(duration: 0.2)) {
                confirmationMessage = nil
            }
        }
    }

    private func deleteVisibleMeals(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(visibleMeals[offset])
        }
        AppHaptics.lightImpact()
    }

    private func toggleFavorite(_ meal: SavedMeal) {
        meal.isFavorite = !(meal.isFavorite == true)
        AppHaptics.lightImpact()
    }

    private func favoriteSort(_ lhs: SavedMeal, _ rhs: SavedMeal) -> Bool {
        if (lhs.isFavorite == true) != (rhs.isFavorite == true) {
            return lhs.isFavorite == true
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}

private struct SavedMealLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let meal: SavedMeal
    let onLog: (FoodEntry) -> Void

    @State private var multiplier = 1.0
    @State private var mealType: MealType
    @FocusState private var isMultiplierFocused: Bool

    init(meal: SavedMeal, onLog: @escaping (FoodEntry) -> Void) {
        self.meal = meal
        self.onLog = onLog
        _mealType = State(initialValue: meal.mealType)
    }

    private var canLog: Bool {
        multiplier > 0
    }

    private var calories: Int {
        Int((Double(meal.calories) * multiplier).rounded())
    }

    private var protein: Double { meal.protein * multiplier }
    private var carbs: Double { meal.carbs * multiplier }
    private var fat: Double { meal.fat * multiplier }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    Stepper(value: $multiplier, in: 0.25...5, step: 0.25) {
                        LabeledContent("Quantity", value: "\(multiplier.formatted(.number.precision(.fractionLength(0...2))))x")
                    }

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }

                Section("Logged Nutrition") {
                    LabeledContent("Calories", value: "\(calories) kcal")
                    LabeledContent("Protein", value: gramText(protein))
                    LabeledContent("Carbs", value: gramText(carbs))
                    LabeledContent("Fat", value: gramText(fat))
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .navigationTitle(meal.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log", action: logMeal)
                        .disabled(!canLog)
                }
            }
        }
    }

    private func logMeal() {
        guard canLog else { return }
        onLog(
            FoodEntry(
                name: meal.name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                mealType: mealType
            )
        )
        dismiss()
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
