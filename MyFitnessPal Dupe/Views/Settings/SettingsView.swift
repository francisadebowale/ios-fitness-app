import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]

    var body: some View {
        NavigationStack {
            Form {
                if let goals = goals.first {
                    GoalsEditor(goals: goals)
                } else {
                    Text("Creating default goals")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: ensureGoalsExist)
        }
    }

    private func ensureGoalsExist() {
        guard goals.isEmpty else { return }
        modelContext.insert(DailyGoals())
    }
}

private struct GoalsEditor: View {
    @Bindable var goals: DailyGoals

    var body: some View {
        Section("Daily Goals") {
            TextField("Calories", value: $goals.calories, format: .number)
            TextField("Protein", value: $goals.protein, format: .number)
            TextField("Carbs", value: $goals.carbs, format: .number)
            TextField("Fat", value: $goals.fat, format: .number)
        }
    }
}
