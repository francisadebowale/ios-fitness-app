import SwiftData
import SwiftUI

@main
struct MyFitnessPal_DupeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    DailyGoals.self,
                    FoodEntry.self,
                    SavedFood.self,
                    SavedMeal.self
                ])
        }
    }
}
