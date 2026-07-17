import SwiftData
import SwiftUI

private struct AssistantMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

private struct AssistantMealOption {
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: MealType
    let detail: String

    var contextLine: String {
        "- \(name): \(calories) kcal, protein \(AssistantView.format(protein))g, carbs \(AssistantView.format(carbs))g, fat \(AssistantView.format(fat))g\(detail)"
    }

    var displayLine: String {
        "- \(name)\(detail): \(calories) kcal, protein \(AssistantView.format(protein))g, carbs \(AssistantView.format(carbs))g, fat \(AssistantView.format(fat))g"
    }
}

struct AssistantView: View {
    @Environment(\.modelContext) private var modelContext

    private let service = LocalAssistantService()
    private let quickPrompts = ["What's left today?", "Suggest dinner", "What did I eat?"]
    private let bottomID = "assistant-bottom"

    @Query private var goals: [DailyGoals]
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query(sort: \DailyHistoryEntry.date, order: .reverse) private var historyEntries: [DailyHistoryEntry]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
    @Query(sort: \SavedFood.name) private var savedFoods: [SavedFood]

    @State private var draft = ""
    @State private var isSending = false
    @State private var pendingLogOptions: [AssistantMealOption] = []
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(text: "Local assistant ready. Ask about your goals, today's log, saved meals, or saved foods.", isUser: false)
    ]
    @FocusState private var isMessageFieldFocused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcriptView
                Divider()
                quickPromptBar
                pendingLogBar
                composer
            }
            .navigationTitle("Assistant")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isMessageFieldFocused = false
                    }
                }
            }
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if isSending {
                        typingIndicator
                            .id("typing")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .simultaneousGesture(
                TapGesture().onEnded {
                    isMessageFieldFocused = false
                }
            )
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isSending) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        sendQuickPrompt(prompt)
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var pendingLogBar: some View {
        if !pendingLogOptions.isEmpty && !isSending {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pendingLogOptions, id: \.name) { option in
                        Button {
                            logOption(option)
                        } label: {
                            Label("Log \(option.name)", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.bar)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .focused($isMessageFieldFocused)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit(sendMessage)
                .disabled(isSending)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.bar)
    }

    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack(alignment: .bottom) {
            if message.isUser {
                Spacer(minLength: 48)
            }

            Text(renderedText(for: message))
                .font(.body)
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(message.isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground).opacity(0.95), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .textSelection(.enabled)

            if !message.isUser {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(0.45 + Double(index) * 0.2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.95), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer(minLength: 48)
        }
        .accessibilityLabel("Assistant is typing")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private func sendMessage() {
        send(text: draft)
    }

    private func sendQuickPrompt(_ prompt: String) {
        send(text: prompt)
    }

    private func send(text rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        messages.append(AssistantMessage(text: text, isUser: true))
        draft = ""
        isSending = true
        isMessageFieldFocused = false

        if let localLogResponse = logPendingSuggestionIfRequested(text) {
            messages.append(AssistantMessage(text: localLogResponse, isUser: false))
            isSending = false
            AppHaptics.success()
            return
        }

        let responseOverride = localResponse(for: text)
        let context = AssistantContextBuilder.build(
            goals: goals.first,
            entries: entries,
            savedMeals: savedMeals,
            savedFoods: savedFoods
        )

        if let responseOverride {
            messages.append(AssistantMessage(text: responseOverride, isUser: false))
            isSending = false
            return
        }

        let mealOptions = eligibleMealOptions(for: text)
        let eligibleOptionsContext = mealOptions.map(\.contextLine).joined(separator: "\n")

        Task {
            let response: String
            if isAnalyticsRequest(text) {
                let snapshot = AnalyticsService.snapshot(entries: entries, historyEntries: historyEntries, goals: goals.first)
                response = await service.sendAnalyticsSummary(context: snapshot.contextText)
                await MainActor.run {
                    pendingLogOptions = []
                }
            } else if isMealSuggestionRequest(text), !mealOptions.isEmpty {
                let modelResponse = await service.sendMealSuggestion(
                    text,
                    context: context,
                    eligibleOptionsContext: eligibleOptionsContext
                )
                let selectedOptions = selectedMealOptions(from: modelResponse, eligibleOptions: mealOptions)
                response = mealSuggestionResponse(for: selectedOptions)
                await MainActor.run {
                    pendingLogOptions = selectedOptions
                }
            } else {
                response = await service.sendMessage(text, context: context)
                await MainActor.run {
                    pendingLogOptions = []
                }
            }

            await MainActor.run {
                messages.append(AssistantMessage(text: response, isUser: false))
                isSending = false
            }
        }
    }

    private func renderedText(for message: AssistantMessage) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard !message.isUser, let attributed = try? AttributedString(markdown: message.text, options: options) else {
            return AttributedString(message.text)
        }
        return attributed
    }

    private func selectedMealOptions(from modelResponse: String, eligibleOptions: [AssistantMealOption]) -> [AssistantMealOption] {
        let selected = eligibleOptions.filter { option in
            modelResponse.localizedCaseInsensitiveContains(option.name)
        }

        if selected.isEmpty {
            return Array(eligibleOptions.prefix(3))
        }

        return Array(selected.prefix(3))
    }

    private func mealSuggestionResponse(for options: [AssistantMealOption]) -> String {
        let optionLines = options.map { option in
            let remainingAfter = remainingTotals(afterEating: option)
            return "\(option.displayLine)\n  If you eat this, you will have \(remainingAfter.calories) kcal, protein \(Self.format(remainingAfter.protein))g, carbs \(Self.format(remainingAfter.carbs))g, and fat \(Self.format(remainingAfter.fat))g left today."
        }

        let logHint = options.count == 1
            ? "Reply 'log that' to add it to today."
            : "Reply 'log' and the option name to add one to today."

        return "Here are saved meals that fit your remaining calories and macros:\n\n\(optionLines.joined(separator: "\n\n"))\n\n\(logHint)"
    }

    private func localResponse(for message: String) -> String? {
        guard isMealSuggestionRequest(message) else { return nil }

        if savedMeals.isEmpty {
            pendingLogOptions = []
            return "You do not have any saved meals yet, so I cannot suggest a full meal from your library. Save a few meals first, then I can choose from those.\n\n\(remainingSummary())"
        }

        if eligibleMealOptions(for: message).isEmpty {
            pendingLogOptions = []
            return "None of your saved meals fit within your remaining calories and macros right now.\n\n\(remainingSummary())"
        }

        return nil
    }

    private func logOption(_ option: AssistantMealOption) {
        let response = logOptionAndReturnMessage(option)
        messages.append(AssistantMessage(text: response, isUser: false))
        AppHaptics.success()
    }

    private func logOptionAndReturnMessage(_ selected: AssistantMealOption) -> String {
        modelContext.insert(
            FoodEntry(
                name: selected.name,
                calories: selected.calories,
                protein: selected.protein,
                carbs: selected.carbs,
                fat: selected.fat,
                mealType: selected.mealType
            )
        )
        pendingLogOptions = []

        let remainingAfter = remainingTotals(afterEating: selected)
        return "Logged \(selected.name). After that, you have \(remainingAfter.calories) kcal, protein \(Self.format(remainingAfter.protein))g, carbs \(Self.format(remainingAfter.carbs))g, and fat \(Self.format(remainingAfter.fat))g left today."
    }

    private func logPendingSuggestionIfRequested(_ message: String) -> String? {
        guard isLogRequest(message) else { return nil }
        guard !pendingLogOptions.isEmpty else {
            return "There is no suggested saved meal or food to log yet. Ask me what you should have first."
        }

        let selected = pendingLogOptions.first { option in
            message.localizedCaseInsensitiveContains(option.name)
        } ?? (pendingLogOptions.count == 1 || isAmbiguousLogConfirmation(message) ? pendingLogOptions[0] : nil)

        guard let selected else {
            let names = pendingLogOptions.map(\.name).joined(separator: ", ")
            return "Which one should I log? Choose one of: \(names)."
        }

        modelContext.insert(
            FoodEntry(
                name: selected.name,
                calories: selected.calories,
                protein: selected.protein,
                carbs: selected.carbs,
                fat: selected.fat,
                mealType: selected.mealType
            )
        )
        pendingLogOptions = []

        let remainingAfter = remainingTotals(afterEating: selected)
        return "Logged \(selected.name). After that, you have \(remainingAfter.calories) kcal, protein \(Self.format(remainingAfter.protein))g, carbs \(Self.format(remainingAfter.carbs))g, and fat \(Self.format(remainingAfter.fat))g left today."
    }

    private func eligibleMealOptions(for message: String) -> [AssistantMealOption] {
        let remaining = remainingTotals()
        let requestedMealType = requestedMealType(from: message) ?? .dinner

        let mealOptions = savedMeals.map { meal in
            AssistantMealOption(
                name: meal.name,
                calories: meal.calories,
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat,
                mealType: meal.mealType,
                detail: ", saved meal"
            )
        }

        return mealOptions
            .filter { fits($0, within: remaining) }
            .sorted { lhs, rhs in
                let lhsScore = suggestionScore(lhs, requestedMealType: requestedMealType, remaining: remaining)
                let rhsScore = suggestionScore(rhs, requestedMealType: requestedMealType, remaining: remaining)
                if lhsScore == rhsScore {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
            .prefix(10)
            .map { $0 }
    }


    private func suggestionScore(_ option: AssistantMealOption, requestedMealType: MealType, remaining: NutritionTotals) -> Double {
        let mealTypeScore = option.mealType == requestedMealType ? 2.0 : 0
        let calorieScore = remaining.calories > 0 ? min(Double(option.calories) / Double(remaining.calories), 1) : 0
        let proteinScore = remaining.protein > 0 ? min(option.protein / remaining.protein, 1) : 0
        return mealTypeScore + calorieScore + proteinScore
    }

    private func fits(_ option: AssistantMealOption, within remaining: NutritionTotals) -> Bool {
        option.calories <= max(remaining.calories, 0)
            && option.protein <= max(remaining.protein, 0)
            && option.carbs <= max(remaining.carbs, 0)
            && option.fat <= max(remaining.fat, 0)
    }

    private func remainingSummary() -> String {
        let remaining = remainingTotals()
        return "Remaining today:\n- Calories: \(remaining.calories) kcal\n- Protein: \(Self.format(remaining.protein))g\n- Carbs: \(Self.format(remaining.carbs))g\n- Fat: \(Self.format(remaining.fat))g"
    }

    private func remainingTotals() -> NutritionTotals {
        let dailyGoals = goals.first ?? DailyGoals()
        let calendar = Calendar.current
        let todaysEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: .now) }
        let totals = NutritionCalculator.totals(for: todaysEntries)
        return NutritionCalculator.remaining(goals: dailyGoals, totals: totals)
    }

    private func remainingTotals(afterEating option: AssistantMealOption) -> NutritionTotals {
        let remaining = remainingTotals()
        return NutritionTotals(
            calories: remaining.calories - option.calories,
            protein: remaining.protein - option.protein,
            carbs: remaining.carbs - option.carbs,
            fat: remaining.fat - option.fat
        )
    }

    private func isAnalyticsRequest(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        let analyticsTerms = ["analyze", "analyse", "analytics", "insight", "trend", "progress", "how am i doing", "last 2 weeks", "last two weeks", "coach summary"]
        return analyticsTerms.contains { lowercased.contains($0) }
    }

    private func isMealSuggestionRequest(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        let asksForSuggestion = lowercased.contains("what should")
            || lowercased.contains("suggest")
            || lowercased.contains("recommend")
            || lowercased.contains("what can i have")
            || lowercased.contains("what should i have")
        let mentionsMeal = lowercased.contains("dinner")
            || lowercased.contains("lunch")
            || lowercased.contains("breakfast")
            || lowercased.contains("snack")
            || lowercased.contains("eat")
            || lowercased.contains("meal")
        return asksForSuggestion && mentionsMeal
    }

    private func isLogRequest(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("log")
            || lowercased.contains("add")
            || lowercased.contains("track")
            || lowercased.contains("ate")
    }

    private func isAmbiguousLogConfirmation(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("that")
            || lowercased.contains("it")
            || lowercased == "yes"
            || lowercased == "yep"
            || lowercased == "yeah"
    }

    private func requestedMealType(from message: String) -> MealType? {
        let lowercased = message.lowercased()
        return MealType.allCases.first { mealType in
            lowercased.contains(mealType.displayName.lowercased())
                || lowercased.contains(mealType.rawValue.lowercased())
        }
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview("Light") {
    AssistantView()
        .modelContainer(PreviewData.container())
}

#Preview("Dark Large Text") {
    AssistantView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
