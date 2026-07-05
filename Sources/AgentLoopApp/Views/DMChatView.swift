import SwiftUI
import AgentLoopCore

struct DMChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let companion: CompanionRecord
    var onEdit: () -> Void
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
                    .animation(reduceMotion ? nil : .snappy, value: store.chatMessages.count)
                }
                .onChange(of: store.chatMessages.count) { _, newValue in
                    proxy.scrollTo(newValue - 1)
                }
            }
            Divider().overlay(Camp.line)
            HStack(spacing: 8) {
                TextField("跟\(companion.name)说点什么…", text: $input)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .onSubmit(send)
                Button("发送", action: send)
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .disabled(input.isEmpty || store.chatStreaming)
                    .opacity(input.isEmpty || store.chatStreaming ? 0.5 : 1)
            }
            .padding(10)
            .background(Camp.surface)
        }
        .background(Camp.canvas)
        .navigationTitle(companion.name)
        .toolbar {
            Button("编辑伙伴", action: onEdit)
        }
        .task(id: companion.id) {
            store.loadChatHistory(companion: companion)
        }
    }

    private func send() {
        // 回车键不经过按钮的 disabled 状态，这里同样要挡住流式中的重复发送
        guard !input.isEmpty, !store.chatStreaming else {
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
                        .foregroundStyle(Camp.ink)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                message.role == "user" ? Camp.ember.opacity(0.14) : Camp.surface,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: message.role == "user" ? 12 : 4,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: message.role == "user" ? 4 : 12,
                    topTrailingRadius: 12,
                    style: .continuous
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: message.role == "user" ? 12 : 4,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: message.role == "user" ? 4 : 12,
                    topTrailingRadius: 12,
                    style: .continuous
                )
                .stroke(Camp.line, lineWidth: message.role == "user" ? 0 : 1)
            )

            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }
}
