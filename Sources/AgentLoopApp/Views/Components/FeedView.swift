import SwiftUI
import AgentLoopCore

struct FeedView: View {
    let entries: [FeedEntry]
    let pendingRequests: [UserRequestRecord]
    let cardTitles: [String: String]
    let phase: AppStore.MissionPhase
    let notice: String?
    var onAnswer: (String, AskUserAnswer) -> Void
    var onCloseout: () -> Void
    var onInteract: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("小队动态")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            feedBubble(entry)
                                .id(entry.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(12)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: entries.count)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in onInteract() })
                .onChange(of: entries.count) { _, _ in
                    if let id = entries.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let notice {
                    Label(notice, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !pendingRequests.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(pendingRequests, id: \.id) { request in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cardTitles[request.cardId] ?? "小目标")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    AskUserPromptView(request: request) { answer in
                                        onInteract()
                                        onAnswer(request.id, answer)
                                    }
                                }
                            }
                        }
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in onInteract() })
                    .frame(maxHeight: 220)
                }
                if case .delivering = phase {
                    Button {
                        onCloseout()
                    } label: {
                        Label("收营", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func feedBubble(_ entry: FeedEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            actorIcon(entry.actor)
            VStack(alignment: .leading, spacing: 3) {
                Text(actorName(entry.actor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .textSelection(.enabled)
                    .font(.callout)
            }
            .padding(9)
            .background(background(for: entry.kind), in: RoundedRectangle(cornerRadius: 8))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func actorIcon(_ actor: FeedEntry.Actor) -> some View {
        switch actor {
        case .companion(_, let name):
            CompanionAvatarView(name: name, colorName: "blue", size: 24)
        case .system:
            Image(systemName: "gearshape")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        case .user:
            Image(systemName: "person.crop.circle")
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func actorName(_ actor: FeedEntry.Actor) -> String {
        switch actor {
        case .companion(_, let name): name
        case .system: "系统"
        case .user: "你"
        }
    }

    private func background(for kind: FeedEntry.Kind) -> Color {
        switch kind {
        case .question: Color.orange.opacity(0.14)
        case .blocked, .error: Color.red.opacity(0.10)
        case .delivered, .statusChange: Color.green.opacity(0.10)
        default: Color.gray.opacity(0.10)
        }
    }
}
