import SwiftUI
import AgentLoopCore

/// 营地管家辅助页：左营地笔记本 + 右管家常驻对话。
struct CampHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let campId: String
    var onEditGuide: () -> Void = {}
    var onNewMission: () -> Void = {}
    var onOpenMission: (String) -> Void = { _ in }
    @State private var notesPaneVisible = true
    @State private var renaming = false
    @State private var renameText = ""
    @State private var enabledStations: Set<String> = []
    @State private var showFeedComposer = false
    @State private var showRumination = false

    var body: some View {
        GeometryReader { proxy in
            // 窄窗口自动收起笔记本（m3.3 宽度自适应规则），用户偏好与自动收起互不覆盖。
            // 量的是 detail 区宽度（不含侧栏）：340 笔记本 + ≥400 向导对话 + 间距。
            let tooNarrowForNotes = proxy.size.width < 780
            let showNotes = notesPaneVisible && !tooNarrowForNotes

            VStack(alignment: .leading, spacing: 12) {
                header(notesVisible: showNotes, notesLocked: tooNarrowForNotes)

                HStack(alignment: .top, spacing: 14) {
                    if showNotes {
                        VStack(spacing: 10) {
                            notesPane
                            stationsPane
                            pastMissionsPane
                        }
                        .frame(width: 340)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    GuideChatColumn(onEditGuide: onEditGuide)
                        .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showNotes)
        }
        .background(Camp.canvas)
        .task(id: campId) {
            store.loadCampHome(campId: campId)
            await store.loadDashboard(campId: campId)
        }
        .sheet(isPresented: $showFeedComposer) {
            FeedComposerView(
                draft: FeedDraft(campId: campId),
                campName: store.campName,
                modelConnection: modelConnection,
                onSaveDraft: store.saveFeedDraft,
                onSubmit: { draft, start in
                    try await store.submitFeed(draft, startRumination: start)
                },
                onSubmitDuplicate: { draft, start in
                    try await store.submitDuplicateAnyway(draft, startRumination: start)
                },
                onCancel: {
                    showFeedComposer = false
                    Task { await store.loadDashboard(campId: campId) }
                }
            )
            .frame(minWidth: 640, minHeight: 680)
        }
        .sheet(isPresented: $showRumination) {
            CampRuminationSheet(
                campId: campId,
                onClose: {
                    showRumination = false
                    Task { await store.loadDashboard(campId: campId) }
                },
                onOpenMission: { missionId in
                    showRumination = false
                    onOpenMission(missionId)
                },
                onFeed: {
                    showRumination = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(180))
                        showFeedComposer = true
                    }
                }
            )
            .frame(width: 820, height: 600)
        }
        .alert("重命名营地", isPresented: $renaming) {
            TextField("营地名字", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") {
                store.renameCamp(id: campId, name: renameText)
            }
        }
    }

    private var notesPane: some View {
        NoteListPane(
                            title: "营地笔记",
                            items: store.campNotes.map(NoteItem.init),
                            emptyText: "还没有营地笔记——回营后会自动沉淀，或让营地管家帮你记。",
                            onSave: { id, title, body in
                                guard var record = store.campNotes.first(where: { $0.id == id }) else { return }
                                record.title = title
                                record.bodyMd = body
                                store.saveCampNoteEdits(record)
                            },
                            onTogglePin: { id in
                                guard let record = store.campNotes.first(where: { $0.id == id }) else { return }
                                store.toggleCampNotePin(record)
                            },
                            onDelete: { store.deleteCampNote(id: $0) }
                        )
        .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    /// 启用的驿站（M8-D7）：全局注册的 MCP server 按营地勾选启用；
    /// 启用只是「本营地行动可见」，伙伴还需在编辑器里显式勾选工具。
    @ViewBuilder private var stationsPane: some View {
        if !store.mcp.servers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    Text("驿站")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    Spacer()
                    Text("\(enabledStations.count)/\(store.mcp.servers.count) 启用")
                        .font(.caption2)
                        .foregroundStyle(Camp.stone)
                }
                ForEach(store.mcp.servers, id: \.id) { server in
                    Toggle(isOn: stationBinding(server.id)) {
                        HStack(spacing: 5) {
                            Text(server.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(Camp.ink)
                            if server.experimental {
                                Image(systemName: "flask")
                                    .font(.caption2)
                                    .foregroundStyle(Camp.amber)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                Text("启用后，本营地行动派发时会拉起驿站；工具还需在牛的档案里逐只勾选。")
                    .font(.caption2)
                    .foregroundStyle(Camp.stone)
            }
            .padding(10)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
            .task(id: campId) {
                enabledStations = store.mcp.enabledServerIds(campId: campId)
            }
        }
    }

    private func stationBinding(_ serverId: String) -> Binding<Bool> {
        Binding(
            get: { enabledStations.contains(serverId) },
            set: { enabled in
                store.mcp.setEnabled(campId: campId, serverId: serverId, enabled: enabled)
                enabledStations = store.mcp.enabledServerIds(campId: campId)
            }
        )
    }

    /// 往期行动收进营地首页（C1）：侧栏只留进行中
    @ViewBuilder private var pastMissionsPane: some View {
        let past = (store.missionsByCamp[campId] ?? [])
            .filter { $0.status == .accepted || $0.status == .failed }
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    Text("往期放牛任务")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    Spacer()
                    Text("\(past.count)")
                        .font(.caption2)
                        .foregroundStyle(Camp.stone)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(past, id: \.id) { mission in
                            Button {
                                onOpenMission(mission.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(mission.status == .accepted ? Camp.moss : Camp.stone)
                                        .frame(width: 6, height: 6)
                                    Text(Self.missionLine(mission))
                                        .font(.caption)
                                        .foregroundStyle(Camp.ink)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            .padding(10)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
        }
    }

    private static func missionLine(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        return String((base.split(whereSeparator: \.isNewline).first.map(String.init) ?? base).prefix(24))
    }

    private func header(notesVisible: Bool, notesLocked: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "tent.fill")
                        .foregroundStyle(Camp.ember)
                    Text(store.campName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                }
                .contextMenu {
                    Button("重命名营地…") {
                        renameText = store.campName
                        renaming = true
                    }
                }
                Text("任务经验和营地管家都在这儿")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            if store.missionStartBlocked {
                CampChip(
                    text: store.kernelStartupRecoveryPending ? "正在恢复上次状态" : "全部行动已暂停",
                    color: Camp.charcoalRed,
                    icon: store.kernelStartupRecoveryPending ? "arrow.clockwise" : "hand.raised.slash.fill"
                )
                    .help(store.missionStartBlockMessage)
            }
            Button {
                showFeedComposer = true
            } label: {
                Label("喂牛", systemImage: "plus.rectangle.on.rectangle")
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))

            Button {
                showRumination = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("待反刍")
                    if pendingRuminationCount > 0 {
                        Text("\(pendingRuminationCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Camp.ember, in: Capsule())
                    }
                }
            }
            .buttonStyle(CampSecondaryButtonStyle())

            Button {
                onNewMission()
            } label: {
                Label("发起放牛", systemImage: "flag.fill")
            }
            .buttonStyle(CampPrimaryButtonStyle(size: .small))
            .disabled(store.missionStartBlocked)
            .opacity(store.missionStartBlocked ? 0.5 : 1)
            .help(store.missionStartBlocked ? store.missionStartBlockMessage : "在这个营地发起放牛任务")

            Button {
                notesPaneVisible.toggle()
            } label: {
                Image(systemName: notesVisible ? "sidebar.leading" : "book.closed")
                    .foregroundStyle(notesVisible ? Camp.inkSecondary : Camp.ember)
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(notesLocked)
            .help(notesLocked ? "窗口太窄，加宽窗口后可展开笔记本" : (notesVisible ? "收起笔记本" : "展开笔记本"))

            if let guide = store.guideCompanion {
                CompanionAvatarView(
                    name: guide.name,
                    colorName: guide.color,
                    state: guideAnimState,
                    size: 34
                )
                .contextMenu {
                    Button("编辑营地管家…", action: onEditGuide)
                }
            }
        }
        .campCard(padding: 12)
    }

    private var pendingRuminationCount: Int {
        guard store.dashboard?.campId == campId else { return 0 }
        return (store.dashboard?.pendingRuminationCount ?? 0)
            + (store.dashboard?.pendingConfirmationCount ?? 0)
    }

    private var modelConnection: ModelConnectionViewState {
        store.apiKeyPresent || store.webCredentialPresent ? .configured : .missing
    }

    private var guideAnimState: CompanionAnimState {
        if store.guideToolActivity != nil { return .working }
        if store.guideStreaming { return .thinking }
        return .idle
    }
}

/// 反刍属于营地内部工作流：列表、确认和放牛草稿都留在同一个营地 sheet，
/// 不占用全局侧栏层级。
private struct CampRuminationSheet: View {
    @Environment(AppStore.self) private var store
    let campId: String
    var onClose: () -> Void
    var onOpenMission: (String) -> Void
    var onFeed: () -> Void

    @State private var ingestionId: String?
    @State private var missionDraft: MissionDraftViewState?

    var body: some View {
        Group {
            if let missionDraft {
                MissionDraftConfirmationView(
                    draft: missionDraft,
                    onStart: store.startMission,
                    onStarted: onOpenMission,
                    onCancel: { self.missionDraft = nil }
                )
            } else if let ingestionId {
                RuminationDetailHost(
                    ingestionId: ingestionId,
                    onMissionDraft: { missionDraft = $0 },
                    onClose: { self.ingestionId = nil }
                )
            } else {
                RuminationInboxHost(
                    campId: campId,
                    onOpen: { ingestionId = $0 },
                    onClose: onClose,
                    onFeed: onFeed
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Camp.canvas)
    }
}

// MARK: - 向导对话列

private struct GuideChatColumn: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onEditGuide: () -> Void
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.guideMessages.isEmpty && store.guideStreamingText == nil {
                            emptyOpening
                        }
                        ForEach(store.guideMessages) { message in
                            guideRow(message)
                                .id(message.id)
                        }
                        if let activity = store.guideToolActivity {
                            toolActivityLine(activity)
                                .id("tool-activity")
                        }
                        if let streaming = store.guideStreamingText {
                            streamingBubble(streaming)
                                .id("streaming")
                        }
                    }
                    .padding(14)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: store.guideMessages.count)
                }
                .onChange(of: scrollAnchor) { _, anchor in
                    proxy.scrollTo(anchor, anchor: .bottom)
                }
                // 流式增量跟随（UX 审计 P2）
                .onChange(of: store.guideStreamingText) { _, _ in
                    if store.guideStreaming {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            Divider().overlay(Camp.line)

            HStack(spacing: 8) {
                Button {
                    store.distillGuideChatNow()
                } label: {
                    if store.distillingGuideChat {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("沉淀笔记", systemImage: "sparkles")
                    }
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.amber))
                .disabled(store.distillingGuideChat)
                .help("把这段对话里值得记的内容沉淀为营地笔记")

                TextField("跟\(store.guideCompanion?.name ?? "营地管家")说点什么…", text: $input)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .onSubmit(send)
                if store.guideStreaming {
                    Button("停止") { store.stopGuideChat() }
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
        .background(Camp.surface)
    }

    private var scrollAnchor: String {
        if store.guideStreamingText != nil { return "streaming" }
        if store.guideToolActivity != nil { return "tool-activity" }
        return store.guideMessages.last?.id ?? ""
    }

    private func send() {
        guard !input.isEmpty, !store.guideStreaming else { return }
        store.sendGuideChat(text: input)
        input = ""
    }

    private var emptyOpening: some View {
        HStack(alignment: .top, spacing: 8) {
            guideAvatar(state: .idle)
            Text("我是营地管家。想了解营地情况、翻往期笔记，或者整理任务，都可以找我。")
                .font(.callout)
                .foregroundStyle(Camp.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Camp.surface, in: guideBubbleShape)
                .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
            Spacer(minLength: 40)
        }
    }

    @ViewBuilder private func guideRow(_ message: AppStore.GuideMessage) -> some View {
        if let proposal = message.proposal {
            ProposalCardView(
                messageId: message.id,
                proposal: proposal,
                confirming: store.confirmingProposals.contains(message.id)
            )
            .padding(.leading, 34)
        } else if message.role == "user" {
            HStack(alignment: .top, spacing: 8) {
                Spacer(minLength: 40)
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(Camp.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Camp.ember.opacity(0.14), in: UnevenRoundedRectangle(
                        topLeadingRadius: 12, bottomLeadingRadius: 12,
                        bottomTrailingRadius: 4, topTrailingRadius: 12, style: .continuous
                    ))
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                guideAvatar(state: .idle)
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(Camp.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Camp.surface, in: guideBubbleShape)
                    .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
                Spacer(minLength: 40)
            }
        }
    }

    private func streamingBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            guideAvatar(state: .thinking)
            Group {
                if text.isEmpty {
                    TypingIndicatorView()
                } else {
                    Text(text)
                        .foregroundStyle(Camp.ink)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Camp.surface, in: guideBubbleShape)
            .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
            Spacer(minLength: 40)
        }
    }

    private func toolActivityLine(_ activity: String) -> some View {
        HStack(spacing: 6) {
            TypingIndicatorView()
            Text(activity)
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .padding(.leading, 34)
    }

    private func guideAvatar(state: CompanionAnimState) -> some View {
        CompanionAvatarView(
            name: store.guideCompanion?.name ?? "营地管家",
            colorName: store.guideCompanion?.color ?? "amber",
            state: state,
            size: 26
        )
    }

    private var guideBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 4, bottomLeadingRadius: 12,
            bottomTrailingRadius: 12, topTrailingRadius: 12, style: .continuous
        )
    }
}

// MARK: - 组队提案卡片（spec §10.2 确认卡片）

struct ProposalCardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let messageId: String
    let proposal: SquadProposalBlock
    let confirming: Bool
    @State private var appeared = false

    private var members: [CompanionRecord] {
        proposal.memberIds.compactMap { id in
            store.companions.first { $0.id == id }
        }
    }

    private var hasGhostMembers: Bool {
        members.count != proposal.memberIds.count
    }

    private var borderColor: Color {
        switch proposal.status {
        case .pending: Camp.amber.opacity(0.75)
        case .confirmed: Camp.moss.opacity(0.65)
        case .dismissed: Camp.line
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.ember)
                Text("组队提案 · \(proposal.name)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Spacer()
                statusTag
            }

            Text("目标：\(proposal.goal)")
                .font(.callout)
                .foregroundStyle(Camp.ink)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(members, id: \.id) { member in
                        CompanionAvatarView(name: member.name, colorName: member.color, size: 24)
                            .background(Circle().fill(Camp.surface).padding(-2))
                    }
                }
                Text(memberLine)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(1)
                Spacer()
                if let budget = proposal.budget {
                    CampChip(text: "预算 \(Self.compactTokens(budget))", color: Camp.stone)
                }
            }

            footer
        }
        .padding(13)
        .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: proposal.status == .pending ? 1.5 : 1)
        )
        .opacity(proposal.status == .dismissed ? 0.6 : 1)
        .frame(maxWidth: 460, alignment: .leading)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                appeared = true
            }
        }
    }

    @ViewBuilder private var statusTag: some View {
        switch proposal.status {
        case .pending:
            CampChip(text: "等你拿主意", color: Camp.amber)
        case .confirmed:
            CampChip(text: "已开工", color: Camp.moss, icon: "checkmark")
        case .dismissed:
            CampChip(text: "已搁置", color: Camp.stone)
        }
    }

    private var memberLine: String {
        var line = members.map(\.name).joined(separator: "、")
        if hasGhostMembers {
            line += line.isEmpty ? "有成员已不在名册" : "（有成员已不在名册）"
        }
        return line
    }

    @ViewBuilder private var footer: some View {
        switch proposal.status {
        case .pending:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        store.confirmProposal(messageId: messageId)
                    } label: {
                        if confirming {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Label("就这么办", systemImage: "flame.fill")
                        }
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .disabled(confirming || hasGhostMembers || store.missionStartBlocked)
                    .opacity(hasGhostMembers || store.missionStartBlocked ? 0.5 : 1)
                    .help(proposalConfirmationHelp)

                    Button("先不") {
                        store.dismissProposal(messageId: messageId)
                    }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .disabled(confirming)
                }
                if store.missionStartBlocked {
                    Text(store.missionStartBlockMessage)
                        .font(.caption2)
                        .foregroundStyle(Camp.charcoalRed)
                }
            }
        case .confirmed:
            if let missionId = proposal.missionId {
                Button {
                    store.navigateToMissionId = missionId
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                        Text("已开工 · 去看看")
                        Image(systemName: "arrow.right")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.moss)
                }
                .buttonStyle(.plain)
            } else {
                Text("已开工")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.moss)
            }
        case .dismissed:
            EmptyView()
        }
    }

    private static func compactTokens(_ value: Int) -> String {
        value >= 1000 ? "\(value / 1000)k" : "\(value)"
    }

    private var proposalConfirmationHelp: String {
        if store.missionStartBlocked { return store.missionStartBlockMessage }
        if hasGhostMembers { return "提案里有已删除的牛，无法开工" }
        return "确认后立即建队开工"
    }
}
