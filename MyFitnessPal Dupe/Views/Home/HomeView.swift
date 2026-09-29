import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query private var goals: [DailyGoals]

    private var todaysEntries: [FoodEntry] {
        entries.filter { calendar.isDateInToday($0.date) }
    }

    private var activeGoals: DailyGoals? {
        goals.first
    }

    private var totals: NutritionTotals {
        NutritionCalculator.totals(for: todaysEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                if let activeGoals {
                    DailyTotalsView(goals: activeGoals, totals: totals)
                }

                Section("Food Log") {
                    if todaysEntries.isEmpty {
                        Text("No food logged today")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todaysEntries) { entry in
                            FoodEntryRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Today")
            .onAppear(perform: ensureGoalsExist)
        }
    }

    private func ensureGoalsExist() {
        guard goals.isEmpty else { return }
        modelContext.insert(DailyGoals())
    }

    private func deleteEntries(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(todaysEntries[offset])
        }
    }
}
