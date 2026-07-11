import SwiftUI

struct AssistantView: View {
    @State private var messages = ["Local assistant ready."]
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack {
                List(messages, id: \.self) { message in
                    Text(message)
                }

                HStack {
                    TextField("Message", text: $draft)
                    Button("Send", action: send)
                }
                .padding()
            }
            .navigationTitle("Assistant")
        }
    }

    private func send() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(draft)
        messages.append("I'll use your local nutrition context.")
        draft = ""
    }
}
