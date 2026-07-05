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
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    if let companion {
                        CompanionAvatarView(
                            name: companion.name,
                            colorName: companion.color,
                            state: card.status == .running || card.status == .blocked ? animState : .idle,
                            size: 30
                        )
                        .padding(.top, 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(card.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(card.status == .canceled ? Camp.inkSecondary : Camp.ink)
                                .strikethrough(card.status == .canceled)
                            CampChip(text: statusText, color: color, icon: statusIcon)
                        }
                        if let companion {
                            Text(companion.name)
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                        Text(detailText)
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if card.status == .blocked && pendingRequest == nil {
                        Button {
                            onRetry()
                        } label: {
                            Label("重试", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(CampSecondaryButtonStyle(tint: Camp.amber))
                    }
                }
                if let pendingRequest {
                    AskUserPromptView(request: pendingRequest) { answer in
                        onAnswer(pendingRequest.id, answer)
                    }
                }
            }
            .padding(.leading, 10)
        }
        .campCard(padding: 12, highlighted: pendingRequest != nil)
        .opacity(card.status == .canceled ? 0.65 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: card.status)
    }

    private var detailText: String {
        if card.status == .blocked, pendingRequest == nil, let detail = blockedDetail {
            return CampCopy.humanizeBlockedDetail(detail)
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
        case .blocked: return pendingRequest == nil ? "等你处理" : "等你回答"
        case .done: return "已完成"
        case .canceled: return "已取消"
        }
    }

    private var statusIcon: String {
        switch card.status {
        case .todo: return "clock"
        case .ready: return "play.fill"
        case .running: return "bolt.fill"
        case .blocked: return pendingRequest == nil ? "exclamationmark.triangle.fill" : "hand.raised.fill"
        case .done: return "checkmark"
        case .canceled: return "xmark"
        }
    }

    private var color: Color {
        switch card.status {
        case .done: return Camp.moss
        case .blocked: return Camp.amber
        case .canceled: return Camp.stone
        case .running: return Camp.creek
        case .todo, .ready: return Camp.stone
        }
    }
}
