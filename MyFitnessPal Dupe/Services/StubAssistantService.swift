import Foundation

struct StubAssistantService: AssistantService {
    func sendMessage(_ message: String, context: String) async -> String {
        "Assistant is not connected yet. Your message was: \"\(message)\""
    }
}
