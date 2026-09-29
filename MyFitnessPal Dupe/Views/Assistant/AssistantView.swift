import SwiftUI

private struct AssistantMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct AssistantView: View {
    private let service: AssistantService = StubAssistantService()

    @State private var draft = ""
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(text: "Assistant placeholder ready. No model is connected yet.", isUser: false)
    ]

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack {
                List(messages) { message in
                    HStack {
                        if message.isUser {
                            Spacer()
                        }

                        Text(message.text)
                            .padding(8)
                            .background(message.isUser ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if !message.isUser {
                            Spacer()
                        }
                    }
                }

                HStack {
                    TextField("Message", text: $draft)
                        .textFieldStyle(.roundedBorder)

                    Button("Send", action: sendMessage)
                        .disabled(!canSend)
                }
                .padding()
            }
            .navigationTitle("Assistant")
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(AssistantMessage(text: text, isUser: true))
        draft = ""

        Task {
            let response = await service.sendMessage(text)
            messages.append(AssistantMessage(text: response, isUser: false))
        }
    }
}
