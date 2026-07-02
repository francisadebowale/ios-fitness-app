import SwiftUI

struct SavedMealsView: View {
    var body: some View {
        NavigationStack {
            SavedMealsListView()
                .navigationTitle("Meals")
        }
    }
}
