import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            LogFoodView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle")
                }

            SavedMealsView()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }

            AssistantView()
                .tabItem {
                    Label("Assistant", systemImage: "message")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DailyGoals.self, FoodEntry.self, SavedMeal.self], inMemory: true)
}
