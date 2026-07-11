import Foundation

protocol AssistantService {
    func reply(to message: String) async throws -> String
}
