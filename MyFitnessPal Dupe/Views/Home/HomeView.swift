import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query(sort: \DailyHistoryEntry.date, order: .reverse) private var historyEntries: [DailyHistoryEntry]
    @Query private var goals: [DailyGoals]

    @State private var selectedDate = Date()
    @State private var editingEntry: FoodEntry?
    @State private var loggingMealType: MealType?
    @State private var showsRoughDaySheet = false

    private var selectedEntries: [FoodEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedHistoryEntry: DailyHistoryEntry? {
        historyEntries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var usesImportedHistory: Bool {
        selectedEntries.isEmpty && selectedHistoryEntry != nil
    }

    private var activeGoals: DailyGoals? {
        goals.first
    }

    private var totals: NutritionTotals {
        if selectedEntries.isEmpty, let selectedHistoryEntry {
            return NutritionTotals(
                calories: selectedHistoryEntry.calories,
                protein: selectedHistoryEntry.protein,
                carbs: selectedHistoryEntry.carbs,
                fat: selectedHistoryEntry.fat,
                fibre: selectedHistoryEntry.fibre
            )
        }
        return NutritionCalculator.totals(for: selectedEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DateSwitcher(
                        selectedDate: $selectedDate,
                        isToday: calendar.isDateInToday(selectedDate),
                        title: dateTitle,
                        previousDay: previousDay,
                        nextDay: nextDay,
                        goToToday: goToToday
                    )
                }

                if let activeGoals {
                    DailyTotalsView(goals: activeGoals, totals: totals)
                        .onTapGesture {
                            showsRoughDaySheet = true
                        }
                        .accessibilityHint("Double-tap to log rough totals for this day")
                }

                if usesImportedHistory, let selectedHistoryEntry {
                    importedHistorySection(selectedHistoryEntry)
                } else if selectedEntries.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No food logged", systemImage: "fork.knife")
                        } description: {
                            Text("Start today by logging a meal.")
                        } actions: {
                            Button("Log Breakfast") {
                                loggingMealType = .breakfast
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if !usesImportedHistory {
                    ForEach(MealType.allCases) { mealType in
                        mealSection(for: mealType)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsRoughDaySheet = true
                    } label: {
                        Label("Rough Day", systemImage: "calendar.badge.clock")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
#endif
            .onAppear(perform: ensureGoalsExist)
            .sheet(item: $editingEntry) { entry in
                FoodEntryEditorView(entry: entry)
            }
            .sheet(item: $loggingMealType) { mealType in
                LogFoodView(initialMealType: mealType, initialDate: selectedDate)
            }
            .sheet(isPresented: $showsRoughDaySheet) {
                RoughDayEntryView(date: selectedDate)
            }
        }
    }

    private var dateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            "Tomorrow"
        } else {
            selectedDate.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func importedHistorySection(_ entry: DailyHistoryEntry) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Imported history is being used for this day.", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    importedMacroText("P", entry.protein, MacroColor.protein)
                    importedMacroText("C", entry.carbs, MacroColor.carbs)
                    importedMacroText("F", entry.fat, MacroColor.fat)
                    importedMacroText("Fi", entry.fibre, .teal)
                }

                if let weight = entry.weight {
                    Label("\(weight.formatted(.number.precision(.fractionLength(1)))) kg", systemImage: "scalemass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Imported History")
        } footer: {
            Text("Log food on this date if you want detailed meal entries to replace the imported total.")
        }
    }

    private func importedMacroText(_ label: String, _ value: Double, _ color: Color) -> some View {
        Label {
            Text("\(label) \(value.formatted(.number.precision(.fractionLength(0...1))))g")
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

    private func mealSection(for mealType: MealType) -> some View {
        let mealEntries = selectedEntries.filter { $0.mealType == mealType }
        let mealTotals = NutritionCalculator.totals(for: mealEntries)

        return Section {
            if mealEntries.isEmpty {
                Text("No \(mealType.displayName.lowercased()) logged")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mealEntries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        FoodEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    deleteEntries(at: offsets, from: mealEntries)
                }
            }
        } header: {
            HStack(alignment: .center) {
                Text(mealType.displayName)
                Spacer()
                Text("\(mealTotals.calories) kcal")
                    .monospacedDigit()
                Button {
                    loggingMealType = mealType
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(mealType.displayName)")
            }
        }
    }

    private func previousDay() {
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextDay() {
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func goToToday() {
        selectedDate = .now
    }

    private func ensureGoalsExist() {
        guard goals.isEmpty else { return }
        modelContext.insert(DailyGoals())
    }

    private func deleteEntries(at offsets: IndexSet, from mealEntries: [FoodEntry]) {
        for offset in offsets {
            modelContext.delete(mealEntries[offset])
        }
        AppHaptics.lightImpact()
    }
}

private struct DateSwitcher: View {
    @Binding var selectedDate: Date

    let isToday: Bool
    let title: String
    let previousDay: () -> Void
    let nextDay: () -> Void
    let goToToday: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .imageScale(.medium)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous day")

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .frame(maxWidth: .infinity)

            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .imageScale(.medium)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Next day")
        }

        if !isToday {
            Button("Today", action: goToToday)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Light") {
    HomeView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark") {
    HomeView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    HomeView()
        .modelContainer(PreviewData.container())
        .environment(\.dynamicTypeSize, .accessibility3)
}
