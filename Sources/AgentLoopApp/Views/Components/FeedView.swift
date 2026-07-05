import SwiftUI
import AgentLoopCore

struct FeedView: View {
    let entries: [FeedEntry]
    let pendingRequests: [UserRequestRecord]
    let cardTitles: [String: String]
    var companionColors: [String: String] = [:]
    let phase: AppStore.MissionPhase
    let notice: String?
    var onAnswer: (String, AskUserAnswer) -> Void
    var onCloseout: () -> Void
    var onInteract: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.ember)
                Text("小队动态")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Camp.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Camp.line)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(entries) { entry in
                            feedRow(entry)
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

            Divider().overlay(Camp.line)

            VStack(alignment: .leading, spacing: 10) {
                if let notice {
                    Label(notice, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                if !pendingRequests.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(pendingRequests, id: \.id) { request in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cardTitles[request.cardId] ?? "小目标")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Camp.inkSecondary)
                                    AskUserPromptView(request: request) { answer in
                                        onInteract()
                                        onAnswer(request.id, answer)
                                    }
                                }
                            }
                        }
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in onInteract() })
                    .frame(maxHeight: 230)
                }
                if case .delivering = phase {
                    Button {
                        onCloseout()
                    } label: {
                        HStack {
                            Spacer()
                            Label("收营", systemImage: "flag.checkered")
                            Spacer()
                        }
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                }
            }
            .padding(12)
        }
        .background(Camp.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Camp.line)
                .frame(width: 1)
        }
    }

    // MARK: - 气泡

    @ViewBuilder private func feedRow(_ entry: FeedEntry) -> some View {
        switch entry.actor {
        case .system:
            HStack {
                Spacer()
                systemLine(entry)
                Spacer()
            }
        case .user:
            HStack(alignment: .top, spacing: 8) {
                Spacer(minLength: 30)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("你")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                    Text(entry.text)
                        .textSelection(.enabled)
                        .font(.callout)
                        .foregroundStyle(Camp.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Camp.ember.opacity(0.14), in: UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 4, topTrailingRadius: 12, style: .continuous
                        ))
                }
            }
        case .companion(let id, let name):
            HStack(alignment: .top, spacing: 8) {
                CompanionAvatarView(
                    name: name,
                    colorName: companionColors[id] ?? "blue",
                    size: 26
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                    Text(displayText(entry))
                        .textSelection(.enabled)
                        .font(.callout)
                        .foregroundStyle(Camp.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(bubbleColor(for: entry.kind), in: UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 12, topTrailingRadius: 12, style: .continuous
                        ))
                }
                Spacer(minLength: 30)
            }
        }
    }

    private func systemLine(_ entry: FeedEntry) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemIcon(for: entry.kind))
                .font(.caption2)
            Text(displayText(entry))
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(entry.kind == .error ? Camp.charcoalRed : Camp.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Camp.canvas, in: Capsule())
    }

    private func displayText(_ entry: FeedEntry) -> String {
        switch entry.kind {
        case .blocked, .error:
            return CampCopy.humanizeBlockedDetail(entry.text)
        default:
            return entry.text
        }
    }

    private func systemIcon(for kind: FeedEntry.Kind) -> String {
        switch kind {
        case .planned: "map"
        case .statusChange: "flag.checkered"
        case .canceled: "xmark.circle"
        case .error: "exclamationmark.triangle.fill"
        default: "sparkle"
        }
    }

    private func bubbleColor(for kind: FeedEntry.Kind) -> Color {
        switch kind {
        case .question: Camp.amber.opacity(0.16)
        case .blocked, .error: Camp.charcoalRed.opacity(0.12)
        case .delivered: Camp.moss.opacity(0.14)
        default: Camp.canvas
        }
    }
}
