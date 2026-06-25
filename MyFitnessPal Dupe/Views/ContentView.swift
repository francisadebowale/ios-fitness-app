import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            LogFoodView()
                .tabItem { Label("Log", systemImage: "plus.circle") }

            SavedMealsView()
                .tabItem { Label("Meals", systemImage: "fork.knife") }

            AssistantView()
                .tabItem { Label("Assistant", systemImage: "bubble.left.and.bubble.right") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
