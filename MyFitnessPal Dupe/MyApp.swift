import SwiftData
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailyGoals.self, FoodEntry.self, SavedMeal.self, SavedFood.self, DailyHistoryEntry.self])
    }
}
