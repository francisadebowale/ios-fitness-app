import Foundation

struct StubAssistantService: AssistantService {
    func reply(to message: String) async throws -> String {
        "I can help with your goals, today's log, saved meals, and saved foods."
    }
}
