import SwiftUI
import AgentLoopCore

struct DMChatView: View {
    @Environment(AppStore.self) private var store
    let companion: CompanionRecord
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(store.chatMessages.enumerated()), id: \.offset) { index, message in
                            ChatBubble(
                                message: message,
                                companion: companion,
                                thinking: store.chatStreaming && index == store.chatMessages.count - 1 && message.text.isEmpty
                            )
                            .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.chatMessages.count) { _, newValue in
                    proxy.scrollTo(newValue - 1)
                }
            }
            Divider()
            HStack {
                TextField("跟\(companion.name)说点什么...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("发送", action: send)
                    .disabled(input.isEmpty || store.chatStreaming)
            }
            .padding(10)
        }
        .navigationTitle(companion.name)
        .task(id: companion.id) {
            store.loadChatHistory(companion: companion)
        }
    }

    private func send() {
        guard !input.isEmpty else {
            return
        }
        store.sendChat(companion: companion, text: input)
        input = ""
    }
}

struct ChatBubble: View {
    let message: (role: String, text: String)
    let companion: CompanionRecord
    var thinking = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "companion" {
                CompanionAvatarView(
                    name: companion.name,
                    colorName: companion.color,
                    state: thinking ? .thinking : .idle,
                    size: 26
                )
            } else {
                Spacer(minLength: 60)
            }

            Group {
                if thinking {
                    TypingIndicatorView()
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(
                message.role == "user" ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 8)
            )

            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }
}
