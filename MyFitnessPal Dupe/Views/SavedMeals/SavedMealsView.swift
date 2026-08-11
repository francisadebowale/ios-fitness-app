import SwiftData
import SwiftUI

enum MealsTabSelection: String, CaseIterable, Identifiable {
    case meals = "Meals"
    case foods = "Foods"

    var id: String { rawValue }
}

struct SavedMealsView: View {
    @State private var selection: MealsTabSelection
    @State private var showingMealForm = false

    init(initialSelection: MealsTabSelection = .meals) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Saved Type", selection: $selection) {
                    ForEach(MealsTabSelection.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                switch selection {
                case .meals:
                    SavedMealsListView()
                case .foods:
                    SavedFoodsView()
                }
            }
            .navigationTitle(selection == .meals ? "Saved Meals" : "Saved Foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
            }
            .sheet(isPresented: $showingMealForm) {
                SavedMealFormView()
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        switch selection {
        case .meals:
            Button {
                showingMealForm = true
            } label: {
                Image(systemName: "plus")
            }
        case .foods:
            SavedFoodsViewAddButton()
        }
    }
}

private struct SavedFoodsViewAddButton: View {
    @State private var actionHandler = SavedFoodAddActionHandler.shared

    var body: some View {
        Menu {
            Button("Scan Label", systemImage: "camera") {
                actionHandler.action = .scan
            }
            Button("Choose Photo", systemImage: "photo") {
                actionHandler.action = .photo
            }
            Button("Enter Manually", systemImage: "square.and.pencil") {
                actionHandler.action = .manual
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}

@Observable
final class SavedFoodAddActionHandler {
    static let shared = SavedFoodAddActionHandler()
    var action: SavedFoodAddAction?

    private init() {}
}

enum SavedFoodAddAction: Equatable {
    case scan
    case photo
    case manual
}

#Preview("Light") {
    SavedMealsView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark Large Text") {
    SavedMealsView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
