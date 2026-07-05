import SwiftUI
import AgentLoopCore

struct CardDetailInspector: View {
    @Environment(AppStore.self) private var store
    let card: CardRecord
    @State private var timelineEntries: [FeedEntry] = []
    @State private var runRecords: [RunRecord] = []
    @State private var cardArtifacts: [ArtifactRecord] = []
    @State private var handoffPayload: HandoffPayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                timeline
                handoff
                runs
                artifacts
                developer
            }
            .padding()
        }
        .navigationTitle("小目标详情")
        .task(id: card.id) {
            loadDetails()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.title3.weight(.semibold))
            Text(card.descriptionText)
                .foregroundStyle(.secondary)
            Label(statusText, systemImage: statusIcon)
                .foregroundStyle(statusColor)
        }
    }

    private var timeline: some View {
        GroupBox("时间线") {
            if timelineEntries.isEmpty {
                Text("暂无事件")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(timelineEntries) { entry in
                        Label(entry.text, systemImage: icon(for: entry.kind))
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder private var handoff: some View {
        GroupBox("交接包") {
            if let handoff = handoffPayload {
                VStack(alignment: .leading, spacing: 6) {
                    Text("结果：\(handoff.outcome)")
                    Text("摘要：\(handoff.summary)")
                    if let next = handoff.next, !next.isEmpty {
                        Text("下一步：\(next)")
                    }
                    Text("验证")
                        .font(.caption.weight(.semibold))
                    ForEach(Array(handoff.verification.enumerated()), id: \.offset) { _, item in
                        Label("\(item.method)：\(item.note)", systemImage: item.passed ? "checkmark.circle" : "xmark.circle")
                    }
                    if !handoff.risks.isEmpty {
                        Text("风险：\(handoff.risks.joined(separator: "、"))")
                    }
                }
                .font(.caption)
            } else {
                Text("暂无交接包")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var runs: some View {
        GroupBox("Run 历史") {
            if runRecords.isEmpty {
                Text("暂无运行记录")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(runRecords, id: \.id) { run in
                        Text("#\(run.attempt) \(run.outcome ?? "running") · \(run.tokensIn + run.tokensOut) tokens")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var artifacts: some View {
        GroupBox("产物") {
            if cardArtifacts.isEmpty {
                Text("暂无产物")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cardArtifacts, id: \.id) { artifact in
                        HStack {
                            Label(artifact.label, systemImage: "doc")
                            Spacer()
                            Button {
                                store.revealArtifact(artifact)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("在 Finder 中显示")
                        }
                    }
                }
            }
        }
    }

    private func loadDetails() {
        let events = (try? store.db.events(cardId: card.id)) ?? []
        timelineEntries = ActivityFeed.entries(events: events, cards: [card], companions: store.cardCompanions)
        runRecords = (try? store.db.runs(cardId: card.id)) ?? []
        cardArtifacts = (try? store.db.artifacts(cardId: card.id)) ?? []
        if let handoffJson = card.handoffJson {
            handoffPayload = try? JSONDecoder().decode(HandoffPayload.self, from: Data(handoffJson.utf8))
        } else {
            handoffPayload = nil
        }
    }

    private var developer: some View {
        GroupBox("开发者视角") {
            VStack(alignment: .leading, spacing: 4) {
                Text("id: \(card.id)")
                Text("idemKey: \(card.idemKey)")
                Text("stage: \(card.stage)")
                Text("maxTurns: \(card.maxTurns)")
                Text("tokenBudget: \(card.tokenBudget)")
                if let blocked = card.blockedReasonJson {
                    Text("blockedReasonJson: \(blocked)")
                }
            }
            .font(.caption.monospaced())
            .textSelection(.enabled)
        }
    }

    private var statusText: String {
        switch card.status {
        case .todo: "排队中"
        case .ready: "待启动"
        case .running: "进行中"
        case .blocked: "等你处理"
        case .done: "已完成"
        case .canceled: "已取消"
        }
    }

    private var statusIcon: String {
        switch card.status {
        case .todo: "clock"
        case .ready: "play.circle"
        case .running: "bolt.circle"
        case .blocked: "hand.raised"
        case .done: "checkmark.circle"
        case .canceled: "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .done: .green
        case .running: .blue
        case .blocked: .orange
        case .canceled: .secondary
        default: .secondary
        }
    }

    private func icon(for kind: FeedEntry.Kind) -> String {
        switch kind {
        case .directive: "flag"
        case .planned: "list.bullet"
        case .claimed: "hand.tap"
        case .progress: "ellipsis.message"
        case .question: "questionmark.bubble"
        case .blocked: "exclamationmark.triangle"
        case .delivered: "shippingbox"
        case .canceled: "xmark.circle"
        case .statusChange: "arrow.triangle.2.circlepath"
        case .error: "exclamationmark.octagon"
        }
    }
}
