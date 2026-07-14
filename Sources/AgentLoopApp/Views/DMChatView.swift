import SwiftUI
import AgentLoopCore

struct DMChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campWindowSize) private var windowSize
    let companion: CompanionRecord
    var onEdit: () -> Void
    @State private var input = ""

    var body: some View {
        GeometryReader { proxy in
            // 记忆抽屉宽度自适应（m3.3 规则）：窄窗口锁定收起
            let windowWidth = windowSize.width > 0 ? windowSize.width : proxy.size.width
            let tooNarrowForDrawer = windowWidth < CampLayout.secondaryPanelWindowWidth
            let showDrawer = store.memoryDrawerVisible && !tooNarrowForDrawer

            HStack(spacing: 0) {
                chatColumn
                if showDrawer {
                    Divider().overlay(Camp.line)
                    NoteListPane(
                        title: "\(companion.name)的记忆",
                        items: store.memoryNotes.map(NoteItem.init),
                        emptyText: "还没有记忆——聊出值得记住的内容后，点「沉淀记忆」。",
                        onSave: { id, title, body in
                            guard var record = store.memoryNotes.first(where: { $0.id == id }) else { return }
                            record.title = title
                            record.bodyMd = body
                            store.saveMemoryEdits(record)
                        },
                        onTogglePin: { id in
                            guard let record = store.memoryNotes.first(where: { $0.id == id }) else { return }
                            store.toggleMemoryPin(record)
                        },
                        onDelete: { store.deleteMemoryNote(id: $0, companionId: companion.id) }
                    )
                    .frame(width: 330)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showDrawer)
            .background(Camp.canvas)
            .navigationTitle(companion.name)
            .toolbar {
                Button {
                    store.distillMemoryNow(companion: companion)
                } label: {
                    if store.distillingMemory {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("沉淀记忆", systemImage: "sparkles")
                    }
                }
                .disabled(store.distillingMemory)
                .help("把这段对话里值得记住的内容沉淀为\(companion.name)的记忆")

                Button {
                    store.memoryDrawerVisible.toggle()
                } label: {
                    Label("记忆", systemImage: "book.closed")
                        .foregroundStyle(showDrawer ? Camp.ember : Camp.inkSecondary)
                }
                .disabled(tooNarrowForDrawer)
                .help(tooNarrowForDrawer ? "窗口太窄，加宽窗口后可查看记忆" : (showDrawer ? "收起记忆" : "查看记忆"))

                Button("牛的档案", action: onEdit)
            }
        }
        .task(id: companion.id) {
            store.loadChatHistory(companion: companion)
        }
    }

    private var chatColumn: some View {
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
                // 流式增量跟随（UX 审计 P2：长回复不再在视口外无声生长）
                .onChange(of: store.chatMessages.last?.text) { _, _ in
                    if store.chatStreaming {
                        proxy.scrollTo(store.chatMessages.count - 1, anchor: .bottom)
                    }
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
                if store.chatStreaming {
                    // 无死等（UX 审计 P2）：流式期间可停止
                    Button("停止") { store.stopChat() }
                        .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button("发送", action: send)
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(input.isEmpty)
                        .opacity(input.isEmpty ? 0.5 : 1)
                }
            }
            .padding(10)
            .background(Camp.surface)
        }
    }

    private func send() {
        // 回车键不经过按钮的 disabled 状态，这里同样要挡住流式中的重复发送
        guard !input.isEmpty, !store.chatStreaming else {
            return
        }
        // 未受理（如没配 key）不清空输入（UX 审计 P1）
        if store.sendChat(companion: companion, text: input) {
            input = ""
        }
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
