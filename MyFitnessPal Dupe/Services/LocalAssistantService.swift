import Foundation

struct LocalAssistantService: AssistantService {
    private let qwen: LocalQwenService

    init(qwen: LocalQwenService = .shared) {
        self.qwen = qwen
    }

    func sendMessage(_ message: String, context: String) async -> String {
        let instructions = """
        You are an on-device nutrition assistant inside Francis's private calorie tracker.
        Keep replies concise and practical.
        Reply in plain text only. Do not use Markdown, bold text, headings, or tables.
        Use only the app context provided by Swift for goals, totals, remaining values, entries, saved meals, and saved foods.
        Do not invent logged food, saved food, saved meals, meal suggestions, or nutrition totals.
        Meal and food suggestions must only come from saved meals and saved foods listed in the app context.
        If there are no saved meals or saved foods, say that none are saved yet and do not suggest generic foods.
        Do not do macro or calorie arithmetic yourself; if a number is not in the context, say it needs to be checked in the app.
        You cannot scan images in this chat.
        """

        let prompt = """
        /no_think
        App context:
        \(context)

        User message:
        \(message)
        """

        return await generate(prompt: prompt, instructions: instructions, maxTokens: 400)
    }

    func sendAnalyticsSummary(context: String) async -> String {
        let instructions = """
        You are an on-device nutrition coach inside Francis's private calorie tracker.
        Swift has already calculated the analytics. Do not do maths yourself.
        Use only the supplied analytics snapshot. Do not invent causes or missing data.
        Reply in plain text only. Keep it to exactly 3 short bullet points and 1 practical suggestion.
        Mention uncertainty where weight data is sparse.
        """

        let prompt = """
        /no_think
        Analytics snapshot calculated by Swift:
        \(context)

        Write a concise coaching summary.
        """

        return await generate(prompt: prompt, instructions: instructions, maxTokens: 220)
    }

    func sendMealSuggestion(_ message: String, context: String, eligibleOptionsContext: String) async -> String {
        let instructions = """
        You are an on-device nutrition assistant inside Francis's private calorie tracker.
        Keep replies concise and practical.
        Reply in plain text only. Do not use Markdown, bold text, headings, or tables.
        Suggest meals only from the eligible saved meals provided by Swift.
        Never invent meals, foods, ingredients, recipes, or nutrition totals.
        Swift has already filtered the eligible options so they fit within the remaining calories and macros.
        Pick one to three eligible options and mention the remaining calories and macros from the app context.
        If the eligible options list is empty, say there are no saved options that fit.
        """

        let prompt = """
        /no_think
        App context:
        \(context)

        Eligible saved meals and foods that Swift checked against remaining calories and macros:
        \(eligibleOptionsContext)

        User message:
        \(message)
        """

        return await generate(prompt: prompt, instructions: instructions, maxTokens: 260)
    }

    private func generate(prompt: String, instructions: String, maxTokens: Int) async -> String {
        do {
            return try await qwen.generate(
                prompt: prompt,
                instructions: instructions,
                maxTokens: maxTokens,
                temperature: 0.2
            )
        } catch {
            return "I couldn't load the local assistant model. \(error.localizedDescription)"
        }
    }
}
