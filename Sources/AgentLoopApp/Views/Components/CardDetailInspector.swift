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
    @State private var returnEditorVisible = false
    @State private var returnFeedback = ""
    @State private var returnError: String?
    @State private var returning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
            Divider().overlay(Camp.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if card.reviewFlag != nil || canReturnForRework {
                        reviewSection
                    }
                    if let handoffPayload {
                        handoffSection(handoffPayload)
                    } else if !cardArtifacts.isEmpty {
                        artifactsSection
                    }
                    timelineSection
                    developerSection
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    if card.reviewFlag != nil {
                        CampChip(text: "待复核", color: Camp.amber, icon: "exclamationmark.circle.fill")
                    }
                }
                Text("预期产出：\(card.expectedOutput)")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - 归营复核

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: card.reviewFlag != nil ? "exclamationmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(card.reviewFlag != nil ? Camp.amber : Camp.ember)
                CampSectionTitle(card.reviewFlag != nil ? "待复核" : "验收动作")
                Spacer()
                if card.reviewFlag != nil {
                    Button {
                        store.clearCardReviewFlag(cardId: card.id)
                    } label: {
                        Label("标记已复核", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.moss))
                }
            }

            if card.reviewFlag != nil {
                Text("上游交付已经进入重做，这张交付可能需要重新检查。")
                    .font(.callout)
                    .foregroundStyle(Camp.ink)
            }

            if canReturnForRework {
                if returnEditorVisible {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $returnFeedback)
                            .font(.callout)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 78)
                            .padding(8)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                    .stroke(returnError == nil ? Camp.line : Camp.charcoalRed.opacity(0.65), lineWidth: 1)
                            )
                        if let returnError {
                            Label(returnError, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Camp.charcoalRed)
                        }
                        HStack(spacing: 8) {
                            Button {
                                submitReturnForRework()
                            } label: {
                                if returning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("退回重做", systemImage: "arrow.uturn.backward")
                                }
                            }
                            .buttonStyle(CampPrimaryButtonStyle(size: .small))
                            .disabled(returning || returnFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("取消") {
                                withOptionalAnimation {
                                    returnEditorVisible = false
                                    returnError = nil
                                }
                            }
                            .buttonStyle(CampSecondaryButtonStyle())
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        withOptionalAnimation {
                            returnEditorVisible = true
                            returnError = nil
                        }
                    } label: {
                        Label("退回重做", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard(highlighted: card.reviewFlag != nil)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: returnEditorVisible)
    }

    private var canReturnForRework: Bool {
        guard card.status == .done,
              let mission = store.missionList.first(where: { $0.id == store.currentMissionId }) else {
            return false
        }
        return mission.status == .executing || mission.status == .delivering
    }

    private func submitReturnForRework() {
        let feedback = returnFeedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty else {
            returnError = "先写一句退回意见"
            return
        }
        returning = true
        returnError = nil
        Task { @MainActor in
            if let error = await store.returnCardForRework(cardId: card.id, feedback: feedback) {
                returning = false
                returnError = error
            } else {
                returning = false
                onClose()
            }
        }
    }

    private func withOptionalAnimation(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                updates()
            }
        }
    }

    // MARK: - 交接包

    private func handoffSection(_ handoff: HandoffPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CampSectionTitle("成果")
            Text(handoff.outcome)
                .font(.body.weight(.semibold))
                .foregroundStyle(Camp.ink)
            Text(handoff.summary)
                .font(.callout)
                .foregroundStyle(Camp.ink)
                .textSelection(.enabled)
            if !cardArtifacts.isEmpty {
                artifactRows
            }
            if !handoff.verification.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(handoff.verification.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.passed ? Camp.moss : Camp.charcoalRed)
                            Text("\(item.method)：\(item.note)")
                                .foregroundStyle(Camp.inkSecondary)
                        }
                        .font(.caption)
                    }
                }
            }
            if let next = handoff.next, !next.isEmpty {
                detailLine("建议下一步", next)
            }
            if !handoff.risks.isEmpty {
                detailLine("风险", handoff.risks.joined(separator: "、"))
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

    /// 时间线只保留关键节拍（认领/进展/提问/受阻/交付），错误一律人话化；完整原始事件在开发者视角。
    private var keyBeats: [FeedEntry] {
        let kinds: Set<FeedEntry.Kind> = [.claimed, .progress, .question, .blocked, .delivered, .canceled]
        let filtered = timelineEntries.filter { kinds.contains($0.kind) }
        return Array(filtered.suffix(12))
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("经过")
            if keyBeats.isEmpty {
                Text("还没有动静")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(keyBeats) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon(for: entry.kind))
                                .font(.caption)
                                .foregroundStyle(iconColor(for: entry.kind))
                                .frame(width: 16)
                            Text(entry.kind == .blocked || entry.kind == .error
                                 ? CampCopy.humanizeBlockedDetail(entry.text)
                                 : entry.text)
                                .font(.caption)
                                .foregroundStyle(Camp.ink)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                    if timelineEntries.count > keyBeats.count {
                        Text("更早的经过与完整事件在「开发者视角」里")
                            .font(.caption2)
                            .foregroundStyle(Camp.stone)
                    }
                    // M8-D7：驿站停摆导致的受阻，给「去设置页重启」引导
                    if card.status == .blocked, hasStationDownBeat {
                        Label("驿站不会自动重启——到「设置 → MCP 驿站」手动重启，然后回来点「重试」。", systemImage: "bolt.slash.fill")
                            .font(.caption)
                            .foregroundStyle(Camp.amber)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    private var hasStationDownBeat: Bool {
        timelineEntries.contains { $0.kind == .blocked && $0.text.contains("驿站") }
    }

    // MARK: - 产物

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CampSectionTitle("产物")
            artifactRows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    private var artifactRows: some View {
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

    // MARK: - Run 历史

    // MARK: - 开发者视角（后台细节全部收在这里）

    private var developerSection: some View {
        DisclosureGroup(isExpanded: $developerExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if !runRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("运行记录")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Camp.inkSecondary)
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

                if !timelineEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("完整事件（原始）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Camp.inkSecondary)
                        ForEach(timelineEntries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: icon(for: entry.kind))
                                    .font(.caption2)
                                    .foregroundStyle(iconColor(for: entry.kind))
                                    .frame(width: 14)
                                Text(entry.text)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Camp.inkSecondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("id: \(card.id)")
                    Text("idemKey: \(card.idemKey)")
                    Text("stage: \(card.stage) · maxTurns: \(card.maxTurns) · tokenBudget: \(card.tokenBudget)")
                    if let blocked = card.blockedReasonJson {
                        Text("blockedReasonJson: \(blocked)")
                    }
                }
                .font(.caption2.monospaced())
                .foregroundStyle(Camp.inkSecondary)
                .textSelection(.enabled)
            }
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
