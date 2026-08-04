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

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview("Light") {
    ContentView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark Large Text") {
    ContentView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
