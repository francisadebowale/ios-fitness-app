import SwiftData
import SwiftUI

struct LogFoodView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var fibre = 0.0
    @State private var mealType = MealType.breakfast
    @State private var date = Date()
    @State private var quickSheet: QuickDestination?
    @State private var addActionHandler = SavedFoodAddActionHandler.shared
    @FocusState private var focusedField: Field?

    init(initialMealType: MealType = .breakfast, initialDate: Date = .now) {
        _mealType = State(initialValue: initialMealType)
        _date = State(initialValue: initialDate)
    }

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case fibre
    }

    private enum QuickDestination: String, Identifiable {
        case scanLabel
        case savedFoods
        case savedMeals

        var id: String { rawValue }

        var initialSelection: MealsTabSelection {
            switch self {
            case .scanLabel, .savedFoods:
                .foods
            case .savedMeals:
                .meals
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && calories >= 0 && protein >= 0 && carbs >= 0 && fat >= 0 && fibre >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                quickEntrySection
                foodSection
                macroSection

                if !canSave {
                    Section {
                        Label("Use a name and non-negative nutrition values.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                bottomLogButton
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
#endif
            .navigationTitle("Log Food")
            .sheet(item: $quickSheet) { destination in
                SavedMealsView(initialSelection: destination.initialSelection)
            }
        }
    }

    private var quickEntrySection: some View {
        Section("Quick Entry") {
            Button {
                addActionHandler.action = .scan
                quickSheet = .scanLabel
            } label: {
                quickActionLabel("Scan Label", systemImage: "camera.viewfinder")
            }

            Button {
                quickSheet = .savedFoods
            } label: {
                quickActionLabel("Saved Foods", systemImage: "list.bullet.rectangle")
            }

            Button {
                quickSheet = .savedMeals
            } label: {
                quickActionLabel("Saved Meals", systemImage: "fork.knife")
            }
        }
        .buttonStyle(.plain)
    }

    private var foodSection: some View {
        Section("Food") {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)

            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.displayName).tag(meal)
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }

    private var macroSection: some View {
        Section("Nutrition") {
            NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $calories, field: Field.calories, focusedField: $focusedField)
            NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $protein, field: Field.protein, focusedField: $focusedField)
            NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $carbs, field: Field.carbs, focusedField: $focusedField)
            NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $fat, field: Field.fat, focusedField: $focusedField)
            NutritionDoubleFieldRow(title: "Fibre", unit: "g", value: $fibre, field: Field.fibre, focusedField: $focusedField)
        }
    }

    private var bottomLogButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: saveEntry) {
                Label("Log Food", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func quickActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func saveEntry() {
        guard canSave else { return }

        let entry = FoodEntry(
            name: trimmedName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fibre: fibre,
            mealType: mealType,
            date: date
        )
        modelContext.insert(entry)
        AppHaptics.success()
        resetForm()
    }

    private func resetForm() {
        name = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        fibre = 0
        mealType = .breakfast
        date = .now
        focusedField = nil
    }
}

#Preview("Light") {
    LogFoodView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark Large Text") {
    LogFoodView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
