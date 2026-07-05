import SwiftUI
import AgentLoopCore

struct CardRowView: View {
    let card: CardRecord
    let companion: CompanionRecord?
    let latest: String?
    let animState: CompanionAnimState
    let pendingRequest: UserRequestRecord?
    let onRetry: () -> Void
    let onAnswer: (String, AskUserAnswer) -> Void
    let onSelect: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(card.title)
                            .font(.headline)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(color)
                    }
                    if let companion {
                        HStack(spacing: 6) {
                            CompanionAvatarView(
                                name: companion.name,
                                colorName: companion.color,
                                state: animState,
                                size: 20
                            )
                            Text(companion.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if card.status == .blocked && pendingRequest == nil {
                    Button {
                        onRetry()
                    } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let pendingRequest {
                AskUserPromptView(request: pendingRequest) { answer in
                    onAnswer(pendingRequest.id, answer)
                }
            }
        }
        .padding(10)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pendingRequest == nil ? Color.clear : Color.orange.opacity(0.6), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: card.status)
    }

    private var detailText: String {
        if card.status == .blocked, let detail = blockedDetail {
            return detail
        }
        if let latest, !latest.isEmpty {
            return latest
        }
        return card.expectedOutput
    }

    private var blockedDetail: String? {
        guard let blockedReasonJson = card.blockedReasonJson,
              let json = try? JSONValue.decoded(from: blockedReasonJson) else {
            return nil
        }
        return json["detail"]?.stringValue
    }

    private var statusText: String {
        switch card.status {
        case .todo: return "排队中"
        case .ready: return "待启动"
        case .running: return "进行中"
        case .blocked: return pendingRequest == nil ? "等你处理" : "待回答"
        case .done: return "已完成"
        case .canceled: return "已取消"
        }
    }

    private var icon: String {
        switch card.status {
        case .todo: return "clock"
        case .ready: return "play.circle"
        case .running: return "bolt.circle"
        case .blocked: return pendingRequest == nil ? "exclamationmark.triangle" : "hand.raised"
        case .done: return "checkmark.circle"
        case .canceled: return "xmark.circle"
        }
    }

    private var color: Color {
        switch card.status {
        case .done: return .green
        case .blocked: return .orange
        case .canceled: return .secondary
        case .running: return .blue
        default: return .secondary
        }
    }

    private var background: Color {
        pendingRequest == nil ? Color.gray.opacity(0.10) : Color.orange.opacity(0.16)
    }
}
