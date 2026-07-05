import SwiftUI
import AgentLoopCore

struct TaskRunView: View {
    enum Mode: Equatable {
        case newMission
        case mission(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var goal = ""
    @State private var workspace = ""
    @State private var selectedCompanionIds: [String] = []
    @State private var theaterPulse = false
    @State private var theaterPulseToken = 0
    @State private var interactionGeneration = 0
    let mode: Mode
    var onNewMission: () -> Void = {}

    var body: some View {
        Group {
            switch mode {
            case .newMission:
                newMissionForm
            case .mission(let id):
                missionView
                    .padding(16)
                    .task(id: id) {
                        store.selectMission(id)
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.missionCards.map(\.status))
        .sheet(isPresented: inspectorBinding) {
            if let card = selectedCard {
                CardDetailInspector(card: card) {
                    store.selectedCardId = nil
                }
            }
        }
    }

    // MARK: - 新行动（英雄表单）

    private var newMissionForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("出发新行动")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Camp.ink)
                    Text("说清目标，选好伙伴，剩下的交给营地。")
                        .font(.callout)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("行动目标")
                    TextField("这次行动要达成什么？越具体越好…", text: $goal, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .lineLimit(4...10)
                        .padding(12)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("同行伙伴")
                        Spacer()
                        if !selectedCompanionIds.isEmpty {
                            Text("已选 \(selectedCompanionIds.count) 位")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                    if store.companions.isEmpty {
                        Text("名册还是空的——先去侧栏创建一位伙伴。")
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                    } else {
                        FlowLayoutLite(spacing: 10) {
                            ForEach(store.companions, id: \.id) { companion in
                                companionChip(companion)
                            }
                        }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("工作目录")
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundStyle(Camp.inkSecondary)
                        Text(workspace.isEmpty ? "未选择（产出文件类交付物需要它）" : workspace)
                            .font(.callout)
                            .foregroundStyle(workspace.isEmpty ? Camp.inkSecondary : Camp.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("选择…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK {
                                workspace = panel.url?.path ?? ""
                            }
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
                        if !workspace.isEmpty {
                            Button {
                                workspace = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Camp.stone)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .campCard()

                Button {
                    store.startMission(
                        goal: goal,
                        companionIds: selectedCompanionIds,
                        workspacePath: workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : workspace
                    )
                } label: {
                    HStack {
                        Spacer()
                        Label("出发", systemImage: "flag.fill")
                        Spacer()
                    }
                }
                .buttonStyle(CampPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCompanionIds.isEmpty)
                .opacity(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCompanionIds.isEmpty ? 0.5 : 1)
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
    }

    private func companionChip(_ companion: CompanionRecord) -> some View {
        let selectedIndex = selectedCompanionIds.firstIndex(of: companion.id)
        return Button {
            if let index = selectedIndex {
                selectedCompanionIds.remove(at: index)
            } else {
                selectedCompanionIds.append(companion.id)
            }
        } label: {
            HStack(spacing: 7) {
                CompanionAvatarView(name: companion.name, colorName: companion.color, size: 26)
                Text(companion.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Camp.ink)
                if let index = selectedIndex {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Camp.ember, in: Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                selectedIndex != nil ? Camp.ember.opacity(0.12) : Camp.surfaceRaised,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(selectedIndex != nil ? Camp.ember.opacity(0.6) : Camp.line, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 行动视图

    private var missionView: some View {
        GeometryReader { proxy in
            // 窄窗口自动收起右栏，避免各栏互相挤压错乱；用户偏好与自动收起互不覆盖
            let tooNarrowForFeed = proxy.size.width < 820
            let showFeed = store.feedPanelVisible && !tooNarrowForFeed

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    missionHeader
                    viewToggle(feedVisible: showFeed, feedLocked: tooNarrowForFeed)

                    if store.theaterMode {
                        CampfireTheaterView(
                            phase: store.missionPhase,
                            cards: store.missionCards,
                            companions: store.cardCompanions,
                            states: store.companionAnimStates,
                            onSelectCard: {
                                recordInteraction()
                                store.selectedCardId = $0
                            }
                        )
                    } else {
                        cardList
                    }

                    artifactsView
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                if showFeed {
                    FeedView(
                        entries: store.feedEntries,
                        pendingRequests: visiblePendingRequests,
                        cardTitles: cardTitles,
                        companionColors: companionColors,
                        phase: store.missionPhase,
                        notice: store.feedNotice,
                        onAnswer: { requestId, answer in
                            recordInteraction()
                            store.answerRequest(requestId: requestId, answer: answer)
                        },
                        onCloseout: { store.closeoutCurrentMission() },
                        onInteract: { recordInteraction() }
                    )
                    .frame(width: 330)
                    .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showFeed)
        }
    }

    private var missionHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(missionGoalLine)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    statusChip
                    if doneCount > 0 || store.missionCards.count > 0 {
                        Text("\(doneCount)/\(store.missionCards.count) 个小目标完成")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
            }
            Spacer()
            presentCompanions
            missionActions
        }
        .campCard()
    }

    @ViewBuilder private var statusChip: some View {
        switch store.missionPhase {
        case .planning:
            HStack(spacing: 6) {
                CompanionAvatarView(name: "向导", colorName: "amber", state: .thinking, size: 22)
                TypingIndicatorView()
                Text("向导正在铺开地图规划…")
                    .font(.caption)
                    .foregroundStyle(Camp.amber)
            }
        case .executing:
            CampChip(text: "进行中", color: Camp.creek, icon: "bolt.fill")
        case .delivering:
            CampChip(text: "全部完成，等你收营", color: Camp.moss, icon: "flag.checkered")
        case .accepted:
            CampChip(text: "已收营", color: Camp.moss, icon: "checkmark")
        case .failed:
            CampChip(text: "已放弃", color: Camp.stone, icon: "xmark")
        case .error(let message):
            CampChip(text: CampCopy.humanizeBlockedDetail(message), color: Camp.charcoalRed, icon: "exclamationmark.triangle.fill")
        case .idle:
            EmptyView()
        }
    }

    private var presentCompanions: some View {
        HStack(spacing: -6) {
            ForEach(presentCompanionList, id: \.id) { companion in
                CompanionAvatarView(
                    name: companion.name,
                    colorName: companion.color,
                    state: store.companionAnimStates[companion.id] ?? .idle,
                    size: 30
                )
                .background(Circle().fill(Camp.surface).padding(-2))
            }
        }
    }

    @ViewBuilder private var missionActions: some View {
        switch store.missionPhase {
        case .delivering:
            HStack(spacing: 8) {
                Button {
                    store.closeoutCurrentMission()
                } label: {
                    Label("收营", systemImage: "flag.checkered")
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                abandonButton
            }
        case .planning, .executing:
            abandonButton
        case .accepted, .failed, .error:
            Button {
                onNewMission()
            } label: {
                Label("开启新行动", systemImage: "flag.fill")
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
        case .idle:
            EmptyView()
        }
    }

    private var abandonButton: some View {
        Button(role: .destructive) {
            store.cancelCurrentMission()
        } label: {
            Text("放弃")
        }
        .buttonStyle(CampSecondaryButtonStyle())
    }

    private func viewToggle(feedVisible: Bool, feedLocked: Bool) -> some View {
        HStack(spacing: 8) {
            Picker("视图", selection: theaterBinding) {
                Label("清单", systemImage: "checklist").tag(false)
                Label("小剧场", systemImage: "flame").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 190)
            Image(systemName: "sparkles")
                .foregroundStyle(Camp.amber)
                .opacity(theaterPulse ? 1 : 0)
                .symbolEffect(.pulse, options: .repeat(2), value: theaterPulseToken)
            Spacer()
            Button {
                store.feedPanelVisible.toggle()
            } label: {
                Image(systemName: feedVisible ? "sidebar.trailing" : "text.bubble")
                    .foregroundStyle(feedVisible ? Camp.inkSecondary : Camp.ember)
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(feedLocked)
            .help(feedLocked ? "窗口太窄，加宽窗口后可展开小队动态" : (feedVisible ? "收起小队动态" : "展开小队动态"))
        }
        .task(id: pulseTaskKey) {
            theaterPulse = false
            guard !reduceMotion else { return }
            guard case .executing = store.missionPhase else { return }
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if case .executing = store.missionPhase {
                theaterPulse = true
                theaterPulseToken += 1
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    theaterPulse = false
                }
            }
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(sortedCards, id: \.id) { card in
                    CardRowView(
                        card: card,
                        companion: card.assigneeId.flatMap { store.cardCompanions[$0] },
                        latest: store.cardLatest[card.id],
                        animState: card.assigneeId.flatMap { store.companionAnimStates[$0] } ?? .idle,
                        pendingRequest: pendingRequest(for: card.id),
                        onRetry: { store.retryCard(card.id) },
                        onAnswer: { requestId, answer in
                            recordInteraction()
                            store.answerRequest(requestId: requestId, answer: answer)
                        },
                        onSelect: {
                            recordInteraction()
                            store.selectedCardId = card.id
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder private var artifactsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            CampSectionTitle("交付物")
            if store.missionArtifacts.isEmpty {
                Text("行动完成的交付物会出现在这里")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(groupedArtifacts, id: \.card.id) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.card.title)
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                        ForEach(group.artifacts, id: \.id) { artifact in
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
                }
            }
        }
        .campCard()
    }

    // MARK: - 派生

    private var missionGoalLine: String {
        guard let mission = store.missionList.first(where: { $0.id == store.currentMissionId }) else {
            return "行动"
        }
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        return base.split(whereSeparator: \.isNewline).first.map(String.init) ?? "行动"
    }

    private var doneCount: Int {
        store.missionCards.filter { $0.status == .done }.count
    }

    private var presentCompanionList: [CompanionRecord] {
        var seen = Set<String>()
        return store.missionCards.compactMap { card in
            guard let id = card.assigneeId, seen.insert(id).inserted else { return nil }
            return store.cardCompanions[id]
        }
    }

    private var companionColors: [String: String] {
        Dictionary(store.cardCompanions.map { ($0.key, $0.value.color) }, uniquingKeysWith: { first, _ in first })
    }

    private var sortedCards: [CardRecord] {
        store.missionCards.sorted { lhs, rhs in
            let leftNeeds = pendingRequest(for: lhs.id) != nil
            let rightNeeds = pendingRequest(for: rhs.id) != nil
            if leftNeeds != rightNeeds { return leftNeeds }
            return lhs.stage < rhs.stage
        }
    }

    private var visiblePendingRequests: [UserRequestRecord] {
        ActivityFeed.visiblePendingRequests(store.pendingRequests, cards: store.missionCards)
    }

    private func pendingRequest(for cardId: String) -> UserRequestRecord? {
        visiblePendingRequests.first { $0.cardId == cardId }
    }

    private var groupedArtifacts: [(card: CardRecord, artifacts: [ArtifactRecord])] {
        store.missionCards.compactMap { card in
            let artifacts = store.missionArtifacts.filter { $0.cardId == card.id }
            return artifacts.isEmpty ? nil : (card, artifacts)
        }
    }

    private var cardTitles: [String: String] {
        Dictionary(store.missionCards.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }

    private var selectedCard: CardRecord? {
        guard let id = store.selectedCardId else { return nil }
        return store.missionCards.first { $0.id == id }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { store.selectedCardId != nil },
            set: { if !$0 { store.selectedCardId = nil } }
        )
    }

    private var theaterBinding: Binding<Bool> {
        Binding(
            get: { store.theaterMode },
            set: {
                theaterPulse = false
                store.theaterMode = $0
            }
        )
    }

    private var pulseTaskKey: String {
        "\(store.currentMissionId ?? "none")-\(String(describing: store.missionPhase))-\(store.theaterMode)-\(interactionGeneration)"
    }

    private func recordInteraction() {
        theaterPulse = false
        interactionGeneration += 1
    }
}

// MARK: - 轻量流式布局（伙伴选择 chips 换行用）

struct FlowLayoutLite: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
