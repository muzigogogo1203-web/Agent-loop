import SwiftUI
import AgentLoopCore

/// 小目标详情弹层（sheet 呈现，营地风）。
struct CardDetailInspector: View {
    @Environment(AppStore.self) private var store
    let card: CardRecord
    var onClose: () -> Void = {}
    @State private var timelineEntries: [FeedEntry] = []
    @State private var runRecords: [RunRecord] = []
    @State private var cardArtifacts: [ArtifactRecord] = []
    @State private var handoffPayload: HandoffPayload?
    @State private var developerExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
            Divider().overlay(Camp.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let handoffPayload {
                        handoffSection(handoffPayload)
                    }
                    timelineSection
                    if !cardArtifacts.isEmpty {
                        artifactsSection
                    }
                    runsSection
                    developerSection
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 640)
        .background(Camp.canvas)
        .fontDesign(.rounded)
        .task(id: card.id) {
            loadDetails()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if let companion = card.assigneeId.flatMap({ store.cardCompanions[$0] }) {
                CompanionAvatarView(name: companion.name, colorName: companion.color, size: 38)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text(card.descriptionText)
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    CampChip(text: statusText, color: statusColor, icon: statusIcon)
                    Text("预期产出：\(card.expectedOutput)")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Camp.stone)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    // MARK: - 交接包

    private func handoffSection(_ handoff: HandoffPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("交接包")
            VStack(alignment: .leading, spacing: 6) {
                detailLine("结果", handoff.outcome)
                detailLine("摘要", handoff.summary)
                if let next = handoff.next, !next.isEmpty {
                    detailLine("建议下一步", next)
                }
                if !handoff.verification.isEmpty {
                    Text("验证")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(Array(handoff.verification.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.passed ? Camp.moss : Camp.charcoalRed)
                            Text("\(item.method)：\(item.note)")
                                .foregroundStyle(Camp.ink)
                        }
                        .font(.caption)
                    }
                }
                if !handoff.risks.isEmpty {
                    detailLine("风险", handoff.risks.joined(separator: "、"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Camp.inkSecondary)
            Text(value)
                .font(.callout)
                .foregroundStyle(Camp.ink)
                .textSelection(.enabled)
        }
    }

    // MARK: - 时间线

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("时间线")
            if timelineEntries.isEmpty {
                Text("还没有动静")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(timelineEntries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon(for: entry.kind))
                                .font(.caption)
                                .foregroundStyle(iconColor(for: entry.kind))
                                .frame(width: 16)
                            Text(entry.text)
                                .font(.caption)
                                .foregroundStyle(Camp.ink)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    // MARK: - 产物

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("产物")
            ForEach(cardArtifacts, id: \.id) { artifact in
                Button {
                    store.revealArtifact(artifact)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Camp.moss)
                        Text(artifact.label)
                            .font(.callout)
                            .foregroundStyle(Camp.ink)
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    // MARK: - Run 历史

    private var runsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("运行记录")
            if runRecords.isEmpty {
                Text("暂无运行记录")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(runRecords, id: \.id) { run in
                        HStack(spacing: 8) {
                            Text("#\(run.attempt)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Camp.inkSecondary)
                            CampChip(text: outcomeText(run.outcome), color: outcomeColor(run.outcome))
                            Text("\(run.turns) 轮 · \(run.tokensIn + run.tokensOut) tokens")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    // MARK: - 开发者视角

    private var developerSection: some View {
        DisclosureGroup(isExpanded: $developerExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                Text("id: \(card.id)")
                Text("idemKey: \(card.idemKey)")
                Text("stage: \(card.stage) · maxTurns: \(card.maxTurns) · tokenBudget: \(card.tokenBudget)")
                if let blocked = card.blockedReasonJson {
                    Text("blockedReasonJson: \(blocked)")
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(Camp.inkSecondary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            CampSectionTitle("开发者视角")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    // MARK: - 数据

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
        case .ready: "play.fill"
        case .running: "bolt.fill"
        case .blocked: "hand.raised.fill"
        case .done: "checkmark"
        case .canceled: "xmark"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .done: Camp.moss
        case .running: Camp.creek
        case .blocked: Camp.amber
        case .canceled: Camp.stone
        default: Camp.stone
        }
    }

    private func outcomeText(_ outcome: String?) -> String {
        switch outcome {
        case "completed": "完成"
        case "blocked": "受阻"
        case "failed": "失败"
        case "canceled": "取消"
        case nil: "进行中"
        default: outcome ?? "未知"
        }
    }

    private func outcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "completed": Camp.moss
        case "blocked": Camp.amber
        case "failed": Camp.charcoalRed
        case "canceled": Camp.stone
        case nil: Camp.creek
        default: Camp.stone
        }
    }

    private func icon(for kind: FeedEntry.Kind) -> String {
        switch kind {
        case .directive: "flag.fill"
        case .planned: "map"
        case .claimed: "hand.tap"
        case .progress: "ellipsis.message"
        case .question: "questionmark.bubble"
        case .blocked: "exclamationmark.triangle.fill"
        case .delivered: "shippingbox.fill"
        case .canceled: "xmark.circle"
        case .statusChange: "arrow.triangle.2.circlepath"
        case .error: "exclamationmark.octagon.fill"
        }
    }

    private func iconColor(for kind: FeedEntry.Kind) -> Color {
        switch kind {
        case .delivered: Camp.moss
        case .question, .blocked: Camp.amber
        case .error: Camp.charcoalRed
        case .claimed, .progress: Camp.creek
        default: Camp.inkSecondary
        }
    }
}
