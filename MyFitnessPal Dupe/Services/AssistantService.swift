import Foundation

protocol AssistantService {
    func sendMessage(_ message: String) async -> String
}
