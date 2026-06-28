import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var goals: [DailyGoals]
    @Query private var entries: [FoodEntry]

    private var activeGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    private var totals: NutritionTotals {
        NutritionCalculator.totals(for: entries)
    }

    var body: some View {
        NavigationStack {
            List {
                DailyTotalsView(goals: activeGoals, totals: totals)

                Section("Entries") {
                    ForEach(entries) { entry in
                        FoodEntryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Today")
        }
    }
}
