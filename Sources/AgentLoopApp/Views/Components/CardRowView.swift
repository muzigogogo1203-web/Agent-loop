import SwiftUI
import AgentLoopCore

struct CardRowView: View {
    let card: CardRecord
    let companion: CompanionRecord?
    let latest: String?
    let onRetry: () -> Void

    var body: some View {
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
                        CompanionAvatarView(name: companion.name, colorName: companion.color, size: 18)
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
            if card.status == .blocked {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
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
        case .blocked: return "等你处理"
        case .done: return "已完成"
        case .canceled: return "已取消"
        }
    }

    private var icon: String {
        switch card.status {
        case .todo: return "clock"
        case .ready: return "play.circle"
        case .running: return "bolt.circle"
        case .blocked: return "hand.raised"
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
}
