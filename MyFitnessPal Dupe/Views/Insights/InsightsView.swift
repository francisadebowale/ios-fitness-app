import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyHistoryEntry.date, order: .reverse) private var historyEntries: [DailyHistoryEntry]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query private var goals: [DailyGoals]

    private let assistantService = LocalAssistantService()

    @State private var showsImportSheet = false
    @State private var showsAddSheet = false
    @State private var showsDeleteAllConfirmation = false
    @State private var editingEntry: DailyHistoryEntry?
    @State private var selectedWeightEntry: DailyHistoryEntry?
    @State private var weightScrollDate = Date()
    @State private var coachSummary: String?
    @State private var isGeneratingCoachSummary = false

    private var analyticsSnapshot: AnalyticsSnapshot {
        AnalyticsService.snapshot(entries: foodEntries, historyEntries: historyEntries, goals: goals.first, calendar: calendar)
    }

    private var sortedAscending: [DailyHistoryEntry] {
        historyEntries.sorted { $0.date < $1.date }
    }

    private var weightEntries: [DailyHistoryEntry] {
        sortedAscending.filter { $0.weight != nil }
    }

    private var weightScale: ClosedRange<Double> {
        let weights = weightEntries.compactMap(\.weight)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else { return 0...100 }
        let padding = max((maxWeight - minWeight) * 0.25, 1.5)
        return max(0, minWeight - padding)...(maxWeight + padding)
    }

    private var visibleWeightWindow: TimeInterval {
        28 * 24 * 60 * 60
    }

    var body: some View {
        NavigationStack {
            List {
                weightSection
                analyticsSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showsImportSheet = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showsAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog("Delete imported history?", isPresented: $showsDeleteAllConfirmation, titleVisibility: .visible) {
                Button("Delete Imported History", role: .destructive, action: deleteAllHistory)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes imported daily history and weigh-ins. Your normal food log, saved foods, and meals stay unchanged.")
            }
            .onAppear(perform: goToLatestWeight)
            .onChange(of: weightEntries.count) { _, _ in
                goToLatestWeight()
            }
            .sheet(isPresented: $showsImportSheet) {
                DailyHistoryImportView { drafts in
                    importDrafts(drafts)
                }
            }
            .sheet(isPresented: $showsAddSheet) {
                DailyHistoryEntryFormView(entry: nil, defaultDate: .now) { values in
                    save(values, editing: nil)
                }
            }
            .sheet(item: $editingEntry) { entry in
                DailyHistoryEntryFormView(entry: entry, defaultDate: entry.date) { values in
                    save(values, editing: entry)
                }
            }
        }
    }

    private var weightSection: some View {
        Section("Weight") {
            if weightEntries.isEmpty {
                ContentUnavailableView {
                    Label("No weigh-ins yet", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Import your notes or add a weigh-in manually.")
                } actions: {
                    Button("Add Weigh-In") {
                        showsAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                weightChartControls

                Chart(weightEntries) { entry in
                    if let weight = entry.weight {
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(selectedWeightEntry === entry ? .orange : .blue)
                        .symbolSize(selectedWeightEntry === entry ? 90 : 55)
                    }
                }
                .frame(height: 300)
                .padding(.vertical, 12)
                .chartYScale(domain: weightScale)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleWeightWindow)
                .chartScrollPosition(x: $weightScrollDate)
                .chartScrollTargetBehavior(.valueAligned(matching: DateComponents(day: 1)))
                .chartYAxis {
                    AxisMarks(position: .trailing)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .accessibilityLabel("Weight chart")

                if let selectedWeightEntry, let weight = selectedWeightEntry.weight {
                    Button {
                        editingEntry = selectedWeightEntry
                    } label: {
                        Label(
                            "\(selectedWeightEntry.date.formatted(date: .abbreviated, time: .omitted)): \(weightText(weight)) kg",
                            systemImage: "scalemass"
                        )
                    }
                }
            }
        }
    }

    private var weightChartControls: some View {
        HStack(spacing: 12) {
            Button {
                moveWeightWindow(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Previous weight period")

            VStack(spacing: 2) {
                Text(weightWindowTitle)
                    .font(.caption.weight(.semibold))
                Text("Swipe chart or use arrows")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                moveWeightWindow(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Next weight period")

            Button("Latest") {
                goToLatestWeight()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var weightWindowTitle: String {
        let start = weightScrollDate
        let end = calendar.date(byAdding: .day, value: 28, to: start) ?? start
        return "\(start.formatted(.dateTime.day().month(.abbreviated))) - \(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var analyticsSection: some View {
        Section {
            if analyticsSnapshot.summaries.allSatisfy({ $0.trackedDays == 0 }) {
                ContentUnavailableView {
                    Label("No analytics yet", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("Import history or log food to see trends.")
                }
            } else {
                ForEach(analyticsSnapshot.summaries) { summary in
                    AnalyticsSummaryCard(summary: summary)
                }

                Button {
                    generateCoachSummary()
                } label: {
                    if isGeneratingCoachSummary {
                        Label("Generating Summary", systemImage: "hourglass")
                    } else {
                        Label("Generate Coach Summary", systemImage: "sparkles")
                    }
                }
                .disabled(isGeneratingCoachSummary)

                if let coachSummary {
                    Text(coachSummary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Analytics")
        } footer: {
            Text("Swift calculates the stats. The local assistant only explains these numbers.")
        }
    }

    private var historySection: some View {
        Section {
            if historyEntries.isEmpty {
                ContentUnavailableView {
                    Label("No history imported", systemImage: "calendar.badge.plus")
                } description: {
                    Text("Paste your old Notes macros to start the timeline.")
                } actions: {
                    Button("Import Notes") {
                        showsImportSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(historyEntries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        DailyHistoryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteHistory)

                Button(role: .destructive) {
                    showsDeleteAllConfirmation = true
                } label: {
                    Label("Delete Imported History", systemImage: "trash")
                }
            }
        } header: {
            Text("Daily History")
        } footer: {
            if !historyEntries.isEmpty {
                Text("Deletes only this Insights history and weigh-ins, not your normal food log.")
            }
        }
    }

    private func generateCoachSummary() {
        guard !isGeneratingCoachSummary else { return }
        isGeneratingCoachSummary = true
        coachSummary = nil
        let context = analyticsSnapshot.contextText

        Task {
            let response = await assistantService.sendAnalyticsSummary(context: context)
            await MainActor.run {
                coachSummary = response
                isGeneratingCoachSummary = false
            }
        }
    }

    private func moveWeightWindow(by direction: Int) {
        let dayCount = Int(visibleWeightWindow / (24 * 60 * 60))
        let nextDate = calendar.date(byAdding: .day, value: direction * dayCount, to: weightScrollDate) ?? weightScrollDate
        weightScrollDate = clampedWeightScrollDate(nextDate)
        selectedWeightEntry = nearestWeightEntry(to: weightScrollDate)
        AppHaptics.lightImpact()
    }

    private func goToLatestWeight() {
        guard let latest = weightEntries.last?.date else { return }
        let latestWindowStart = calendar.date(byAdding: .day, value: -28, to: latest) ?? latest
        weightScrollDate = clampedWeightScrollDate(latestWindowStart)
        selectedWeightEntry = nearestWeightEntry(to: latest)
        AppHaptics.lightImpact()
    }

    private func clampedWeightScrollDate(_ date: Date) -> Date {
        guard let earliest = weightEntries.first?.date, let latest = weightEntries.last?.date else { return date }
        let latestStart = calendar.date(byAdding: .day, value: -28, to: latest) ?? latest
        return min(max(date, earliest), latestStart)
    }

    private func weightText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func nearestWeightEntry(to date: Date) -> DailyHistoryEntry? {
        weightEntries.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func importDrafts(_ drafts: [DailyHistoryDraft]) {
        for draft in drafts {
            save(
                DailyHistoryEntryFormValues(
                    date: draft.date,
                    calories: draft.calories,
                    protein: draft.protein,
                    carbs: draft.carbs,
                    fat: draft.fat,
                    fibre: draft.fibre,
                    weight: draft.weight
                ),
                editing: nil
            )
        }
        AppHaptics.success()
    }

    private func save(_ values: DailyHistoryEntryFormValues, editing entry: DailyHistoryEntry?) {
        let targetDate = calendar.startOfDay(for: values.date)
        let existingForDate = historyEntries.first { candidate in
            calendar.isDate(candidate.date, inSameDayAs: targetDate) && candidate !== entry
        }
        let target = entry ?? existingForDate ?? DailyHistoryEntry(date: targetDate)

        target.date = targetDate
        target.calories = values.calories
        target.protein = values.protein
        target.carbs = values.carbs
        target.fat = values.fat
        target.fibre = values.fibre
        target.weight = values.weight

        if entry == nil && existingForDate == nil {
            modelContext.insert(target)
        }

        if let entry, let existingForDate {
            modelContext.delete(entry)
            existingForDate.date = targetDate
            existingForDate.calories = values.calories
            existingForDate.protein = values.protein
            existingForDate.carbs = values.carbs
            existingForDate.fat = values.fat
            existingForDate.fibre = values.fibre
            existingForDate.weight = values.weight
        }

        AppHaptics.success()
    }

    private func deleteHistory(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(historyEntries[offset])
        }
        AppHaptics.lightImpact()
    }

    private func deleteAllHistory() {
        for entry in historyEntries {
            modelContext.delete(entry)
        }
        AppHaptics.success()
    }
}

private struct AnalyticsSummaryCard: View {
    let summary: AnalyticsPeriodSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last \(summary.dayCount) days")
                        .font(.headline)
                    Text(summary.dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(summary.trackedDays)/\(summary.dayCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                stat("Avg kcal", "\(summary.averageCalories)", MacroColor.calories)
                stat("Protein", gramText(summary.averageProtein), MacroColor.protein)
                stat("Fibre", gramText(summary.averageFibre), .teal)
                stat("On goal", "\(summary.daysAtOrUnderGoal)d", .green)
            }

            if let weightChange = summary.weightChange, let latestWeight = summary.latestWeight {
                Label("Weight \(signed(weightChange)) kg to \(weightText(latestWeight)) kg", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let highest = summary.highestCalorieDay, let lowest = summary.lowestCalorieDay {
                Text("Highest: \(highest.calories) kcal on \(highest.date.formatted(.dateTime.day().month(.abbreviated))). Lowest: \(lowest.calories) kcal on \(lowest.date.formatted(.dateTime.day().month(.abbreviated))).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }

    private func weightText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func signed(_ value: Double) -> String {
        let formatted = weightText(value)
        return value > 0 ? "+\(formatted)" : formatted
    }
}

private struct DailyHistoryRow: View {
    let entry: DailyHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.body.weight(.medium))
                Spacer(minLength: 12)
                Text("\(entry.calories) kcal")
                    .foregroundStyle(MacroColor.calories)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                macroText("P", entry.protein, MacroColor.protein)
                macroText("C", entry.carbs, MacroColor.carbs)
                macroText("F", entry.fat, MacroColor.fat)
                macroText("Fi", entry.fibre, .teal)
            }

            if let weight = entry.weight {
                Label("\(weightText(weight)) kg", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func weightText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func macroText(_ label: String, _ value: Double, _ color: Color) -> some View {
        Label {
            Text("\(label) \(value.formatted(.number.precision(.fractionLength(0))))g")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } icon: {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .labelStyle(.titleAndIcon)
    }
}

private struct DailyHistoryImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notesText = ""
    @State private var parsedDrafts: [DailyHistoryDraft] = []

    let onImport: ([DailyHistoryDraft]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes Text") {
                    TextEditor(text: $notesText)
                        .frame(minHeight: 220)
                        .onChange(of: notesText) { _, newValue in
                            parsedDrafts = DailyHistoryImportParser.parse(newValue)
                        }
                }

                Section {
                    Label("\(parsedDrafts.count) day\(parsedDrafts.count == 1 ? "" : "s") ready to import", systemImage: "checkmark.circle")
                        .foregroundStyle(parsedDrafts.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                }

                if !parsedDrafts.isEmpty {
                    Section("Preview") {
                        ForEach(parsedDrafts.prefix(5)) { draft in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                Text("\(draft.calories) kcal, P \(gramText(draft.protein)), C \(gramText(draft.carbs)), F \(gramText(draft.fat)), fibre \(gramText(draft.fibre))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let weight = draft.weight {
                                    Text("Weight: \(weight.formatted(.number.precision(.fractionLength(1))))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(parsedDrafts)
                        dismiss()
                    }
                    .disabled(parsedDrafts.isEmpty)
                }
            }
        }
    }

    private func gramText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))g"
    }
}

private struct DailyHistoryEntryFormValues {
    var date: Date
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
    var weight: Double?
}

private struct DailyHistoryEntryFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var calories: Int
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var fibre: Double
    @State private var hasWeight: Bool
    @State private var weight: Double
    @FocusState private var focusedField: Field?

    let entry: DailyHistoryEntry?
    let onSave: (DailyHistoryEntryFormValues) -> Void

    private enum Field: Hashable {
        case calories
        case protein
        case carbs
        case fat
        case fibre
        case weight
    }

    init(entry: DailyHistoryEntry?, defaultDate: Date, onSave: @escaping (DailyHistoryEntryFormValues) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _date = State(initialValue: entry?.date ?? defaultDate)
        _calories = State(initialValue: entry?.calories ?? 0)
        _protein = State(initialValue: entry?.protein ?? 0)
        _carbs = State(initialValue: entry?.carbs ?? 0)
        _fat = State(initialValue: entry?.fat ?? 0)
        _fibre = State(initialValue: entry?.fibre ?? 0)
        _hasWeight = State(initialValue: entry?.weight != nil)
        _weight = State(initialValue: entry?.weight ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Nutrition") {
                    NutritionIntFieldRow(title: "Calories", unit: "kcal", value: $calories, field: Field.calories, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Protein", unit: "g", value: $protein, field: Field.protein, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Carbs", unit: "g", value: $carbs, field: Field.carbs, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fat", unit: "g", value: $fat, field: Field.fat, focusedField: $focusedField)
                    NutritionDoubleFieldRow(title: "Fibre", unit: "g", value: $fibre, field: Field.fibre, focusedField: $focusedField)
                }

                Section("Weigh-In") {
                    Toggle("Add weight", isOn: $hasWeight)
                    if hasWeight {
                        NutritionDoubleFieldRow(title: "Weight", unit: "", value: $weight, field: Field.weight, focusedField: $focusedField)
                    }
                }
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
#endif
            .navigationTitle(entry == nil ? "Add History" : "Edit History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            DailyHistoryEntryFormValues(
                                date: date,
                                calories: calories,
                                protein: protein,
                                carbs: carbs,
                                fat: fat,
                                fibre: fibre,
                                weight: hasWeight ? weight : nil
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Insights") {
    InsightsView()
        .modelContainer(PreviewData.container())
}
