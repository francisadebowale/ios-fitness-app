import Foundation

protocol AssistantService {
    func sendMessage(_ message: String, context: String) async -> String
}
