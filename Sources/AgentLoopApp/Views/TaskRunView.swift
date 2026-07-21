import SwiftUI
import AgentLoopCore

struct TaskRunView: View {
    enum Mode: Equatable {
        case newMission(campId: String)
        case mission(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campWindowSize) private var windowSize
    @State private var goal = ""
    @State private var workspace = ""
    @State private var selectedCompanionIds: [String] = []
    @State private var theaterPulse = false
    @State private var theaterPulseToken = 0
    @State private var interactionGeneration = 0
    let mode: Mode
    var onNewMission: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onRecruit: () -> Void = {}
    var onReturnSummary: () -> Void = {}
    @State private var showAbandonConfirm = false
    @State private var submitting = false
    /// 交付物区收起态（多交付物时防挤压小目标区域；每次进入行动默认展开）
    @State private var artifactsCollapsed = false
    /// 详情弹层的键盘焦点（Esc 关闭）
    @FocusState private var detailFocused: Bool
    /// 花销分账浮层（M7-D7）
    @State private var showSpendPopover = false
    @State private var spendChipHovered = false
    @State private var detailHasDraftText = false
    @State private var draftCloseDeadline: Date?
    @State private var draftCloseToast: String?
    @State private var showEmergencyStopConfirmation = false
    /// 新行动表单的档位选择（M7-D2；.task 里以全局默认初始化）
    @State private var formAutonomy: MissionAutonomy = .standard

    private var formAutonomyCaption: String {
        switch formAutonomy {
        case .careful: return "谨慎：牛写文件、跑命令等一切落盘动作都先问你。"
        case .standard: return "标准：只有危险操作（如跑命令）需要你批准。"
        case .free: return "放手：预算内全放行，不打扰你。"
        }
    }
    @State private var submitError: String?

    var body: some View {
        Group {
            switch mode {
            case .newMission(let campId):
                newMissionForm(campId: campId)
            case .mission(let id):
                missionView
                    .padding(16)
                    .task(id: id) {
                        store.selectMission(id)
                        store.reloadCampKnowledge()
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.missionCards.map(\.status))
        .overlay { cardDetailOverlay }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: store.selectedCardId)
        .campToast(draftCloseToast)
    }

    // MARK: - 卡片详情弹层
    // 自绘居中弹层替代系统 sheet：背景微暗渐入 + 内容 scale/opacity 弹入，
    // 点背景或 Esc 关闭；Reduce Motion 时静态出现（spec §11.2）。

    @ViewBuilder private var cardDetailOverlay: some View {
        GeometryReader { proxy in
            if let card = selectedCard {
                let availableSize = CGSize(
                    width: windowSize.width > 0 ? min(proxy.size.width, windowSize.width) : proxy.size.width,
                    height: windowSize.height > 0 ? min(proxy.size.height, windowSize.height) : proxy.size.height
                )
                let inspectorSize = CampLayout.inspectorSize(in: availableSize)

                ZStack {
                    Camp.ink.opacity(0.22)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { requestCardDetailClose() }
                        .transition(.opacity)
                    CardDetailInspector(card: card, hasDraftText: $detailHasDraftText) {
                        requestCardDetailClose()
                    }
                    .frame(width: inspectorSize.width, height: inspectorSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 28, y: 12)
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.94).combined(with: .opacity))
                }
                // 弹出即接管键盘焦点：Esc 关闭（focusable 卡片行不再吞键）
                .focusable()
                .focused($detailFocused)
                .focusEffectDisabled()
                .onKeyPress(.escape) {
                    requestCardDetailClose()
                    return .handled
                }
                .onAppear { detailFocused = true }
            }
        }
    }

    private func requestCardDetailClose() {
        guard detailHasDraftText else {
            closeCardDetail()
            return
        }

        let now = Date()
        if let deadline = draftCloseDeadline, now <= deadline {
            closeCardDetail()
            return
        }

        let deadline = now.addingTimeInterval(2)
        draftCloseDeadline = deadline
        draftCloseToast = "意见还没提交，再点一次关闭"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard draftCloseDeadline == deadline else { return }
            draftCloseDeadline = nil
            draftCloseToast = nil
        }
    }

    private func closeCardDetail() {
        store.selectedCardId = nil
        detailHasDraftText = false
        draftCloseDeadline = nil
        draftCloseToast = nil
    }

    // MARK: - 新行动（英雄表单）

    private func newMissionForm(campId: String) -> some View {
        ScrollView {
            let availableCompanions = missionCompanions(campId: campId)
            let singleCow = newcomerSingleCow(campId: campId)

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("发起放牛")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Camp.ink)
                    HStack(spacing: 6) {
                        // 行动在营地内发起（M5-0 C1）：表单锁定所属营地
                        CampChip(
                            text: store.camps.first { $0.id == campId }?.name ?? "营地",
                            color: Camp.ember,
                            icon: "tent.fill"
                        )
                        Text("说清目标和验收标准，基础牛就会进入 Coding 草原。")
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("任务目标")
                    TextField("这次放牛要达成什么？越具体越好…", text: $goal, axis: .vertical)
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
                        CampSectionTitle(singleCow ? "参与的牛" : "参与的牛")
                        Spacer()
                        if !selectedCompanionIds.isEmpty {
                            Text("已选 \(selectedCompanionIds.count) 位")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                    if singleCow, let cow = availableCompanions.first(where: { $0.kind == .regular }) {
                        HStack(spacing: 9) {
                            CompanionAvatarView(name: cow.name, colorName: cow.color, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cow.name)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Camp.ink)
                                Text("首次任务默认由基础牛完成")
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                            Spacer()
                            CampChip(text: "已准备", color: Camp.moss, icon: "checkmark")
                        }
                    } else if availableCompanions.isEmpty {
                        HStack(spacing: 10) {
                            Text("牛棚还是空的——先创建一只自定义牛。")
                                .font(.callout)
                                .foregroundStyle(Camp.inkSecondary)
                            Button {
                                onRecruit() // 直达入口（UX 审计 P2：草稿已暂存，回来还在）
                            } label: {
                                Label("创建自定义牛…", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                        }
                    } else {
                        FlowLayoutLite(spacing: 10) {
                            ForEach(availableCompanions, id: \.id) { companion in
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

                // M7-D2：自主档位（决定哪些工具动作需要你批准）
                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("自主档位")
                    Picker("自主档位", selection: $formAutonomy) {
                        ForEach(MissionAutonomy.allCases, id: \.self) { autonomy in
                            Text(autonomy.displayName).tag(autonomy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 320)
                    Text(formAutonomyCaption)
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .campCard()

                // 出发反馈（UX 审计 P1：进行中/失败都要可见）
                if let submitError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Camp.charcoalRed)
                        Text(submitError)
                            .font(.callout)
                            .foregroundStyle(Camp.charcoalRed)
                        if submitError.contains("API key") {
                            Button("去设置", action: onOpenSettings)
                                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                        }
                        Spacer()
                    }
                    .campCard(padding: 10, highlighted: true)
                }

                if store.missionStartBlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.slash.fill")
                            .foregroundStyle(Camp.charcoalRed)
                        Text(store.missionStartBlockMessage)
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                        Spacer()
                    }
                    .campCard(padding: 10, highlighted: true)
                }

                HStack(spacing: 8) {
                    Button {
                        guard !store.missionStartBlocked else {
                            submitError = store.missionStartBlockMessage
                            return
                        }
                        submitError = nil
                        submitting = true
                        store.startMission(
                            goal: goal,
                            companionIds: selectedCompanionIds,
                            workspacePath: workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : workspace,
                            campId: campId,
                            autonomy: formAutonomy
                        )
                    } label: {
                        HStack {
                            Spacer()
                            if submitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                Text("正在开工…")
                            } else {
                                Label("开始放牛", systemImage: "flag.fill")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(CampPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(submitting
                              || store.missionStartBlocked
                              || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || selectedCompanionIds.isEmpty)
                    .help(store.missionStartBlocked ? store.missionStartBlockMessage : "让基础牛开始任务")
                    Text("⌘↩ 开始")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                }
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .task(id: campId) {
            // 读入该营地的草稿（防切页丢输入）
            let draft = store.missionDrafts[campId] ?? AppStore.MissionDraft()
            goal = draft.goal
            workspace = draft.workspace
            selectedCompanionIds = draft.companionIds
            if newcomerSingleCow(campId: campId),
               let baseCow = missionCompanions(campId: campId).first(where: { $0.id == CowTemplate.baseCowId }) {
                selectedCompanionIds = [baseCow.id]
            }
            formAutonomy = store.defaultAutonomy
            submitting = false
            submitError = nil
        }
        .onChange(of: goal) { _, _ in saveDraft(campId: campId) }
        .onChange(of: workspace) { _, _ in saveDraft(campId: campId) }
        .onChange(of: selectedCompanionIds) { _, _ in saveDraft(campId: campId) }
        .onChange(of: store.missionPhase) { _, phase in
            guard submitting else { return }
            if case .error(let message) = phase {
                submitting = false
                submitError = message
            }
        }
    }

    private func saveDraft(campId: String) {
        store.missionDrafts[campId] = AppStore.MissionDraft(
            goal: goal, workspace: workspace, companionIds: selectedCompanionIds)
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
            let windowWidth = windowSize.width > 0 ? windowSize.width : proxy.size.width
            let tooNarrowForFeed = windowWidth < CampLayout.secondaryPanelWindowWidth
            let showFeed = store.feedPanelVisible && !tooNarrowForFeed
            let compact = windowWidth < CampLayout.windowCompactWidth

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    missionHeader(compact: compact)
                    if store.currentMissionBudgetExhausted {
                        budgetBanner(compact: compact)
                    }
                    viewToggle(
                        feedVisible: showFeed,
                        feedLocked: tooNarrowForFeed,
                        compact: compact
                    )

                    if store.theaterMode {
                        ScrollView {
                            VStack(spacing: 14) {
                                CodingPastureTheaterView(
                                    phase: store.missionPhase,
                                    cards: store.missionCards,
                                    companions: store.cardCompanions,
                                    states: store.companionAnimStates,
                                    campMemoryCount: store.campNotes.count,
                                    onSelectCard: {
                                        recordInteraction()
                                        store.selectedCardId = $0
                                    }
                                )
                                artifactsView
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        cardList
                        artifactsView
                    }
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
                        onCloseout: onReturnSummary,
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

    @ViewBuilder private func missionHeader(compact: Bool) -> some View {
        VStack(spacing: 0) {
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            missionLeadCow
                            VStack(alignment: .leading, spacing: 7) {
                                missionTitle(lineLimit: 3)
                                missionStatusSummary
                            }
                        }
                        missionOperationSummary
                        HStack(spacing: 10) {
                            presentCompanions
                            Spacer(minLength: 8)
                            missionActions
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        missionLeadCow
                        VStack(alignment: .leading, spacing: 7) {
                            missionTitle(lineLimit: 2)
                            missionStatusSummary
                            missionOperationSummary
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 10) {
                            presentCompanions
                            missionActions
                        }
                    }
                }
            }
            .padding(14)

            LinearGradient(
                colors: [Camp.pasture, Camp.hay],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)
        }
        .background(
            Camp.surface,
            in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    private func missionTitle(lineLimit: Int) -> some View {
        Text(missionGoalLine)
            .font(.title2.weight(.bold))
            .foregroundStyle(Camp.ink)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var missionStatusSummary: some View {
        FlowLayoutLite(spacing: 8) {
            statusChip
            if doneCount > 0 || store.missionCards.count > 0 {
                Text("\(doneCount)/\(store.missionCards.count) 张工作卡完成")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var missionOperationSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                autonomyMenu
                spendChip
            }
            FlowLayoutLite(spacing: 8) {
                autonomyMenu
                spendChip
            }
        }
    }

    private var missionLeadCow: some View {
        ZStack(alignment: .topTrailing) {
            RanchCowSpriteView(colorName: leadingCowColor, height: 56, flipped: false)
            if case .planning = store.missionPhase {
                TypingIndicatorView()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Camp.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .offset(x: 10, y: -7)
            }
        }
        .padding(.top, 7)
    }

    // MARK: - 哨卡（M7）

    private var currentMission: MissionRecord? {
        guard let missionId = store.currentMissionId else { return nil }
        return store.missionList.first { $0.id == missionId }
            ?? store.missionsByCamp.values.lazy.flatMap { $0 }.first { $0.id == missionId }
    }

    /// 档位菜单（M7-D2）：行动执行中可改，收营后只读
    @ViewBuilder private var autonomyMenu: some View {
        if let mission = currentMission {
            let editable = mission.status == .executing || mission.status == .planning || mission.status == .delivering
            Menu {
                ForEach(MissionAutonomy.allCases, id: \.self) { autonomy in
                    Button {
                        store.setCurrentMissionAutonomy(autonomy)
                    } label: {
                        if autonomy == mission.autonomy {
                            Label(autonomyLabel(autonomy), systemImage: "checkmark")
                        } else {
                            Text(autonomyLabel(autonomy))
                        }
                    }
                }
            } label: {
                CampChip(text: "档位 · \(mission.autonomy.displayName)", color: Camp.amber, icon: "shield.lefthalf.filled")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!editable)
            .help("自主档位：谨慎=写入即审批；标准=危险操作才审批；放手=预算内全放行")
        }
    }

    private func autonomyLabel(_ autonomy: MissionAutonomy) -> String {
        switch autonomy {
        case .careful: return "谨慎——写入与危险操作都需要批准"
        case .standard: return "标准——危险操作（如跑命令）需要批准"
        case .free: return "放手——预算内全放行"
        }
    }

    /// 花销签（M7-D7）：点开分账浮层（本地估算口径）
    @ViewBuilder private var spendChip: some View {
        if let mission = currentMission, mission.spentTokens > 0 {
            Button {
                showSpendPopover.toggle()
            } label: {
                CampChip(
                    text: "花销 ~\(CampFormat.tokens(mission.spentTokens))",
                    color: Camp.stone,
                    icon: "creditcard",
                    trailingIcon: "chevron.down"
                )
                .overlay(
                    Capsule()
                        .stroke(Camp.stone.opacity(spendChipHovered ? 0.72 : 0.26), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("查看花销分账")
            .onHover { spendChipHovered = $0 }
            .popover(isPresented: $showSpendPopover, arrowEdge: .bottom) {
                spendBreakdownView(mission: mission)
            }
        }
    }

    private func spendBreakdownView(mission: MissionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("花销分账")
                .font(.headline)
                .foregroundStyle(Camp.ink)
            if let breakdown = store.spendBreakdown(missionId: mission.id) {
                if breakdown.planningTokens > 0 {
                    spendRow(name: "营地管家规划", tokens: breakdown.planningTokens)
                }
                ForEach(breakdown.companions) { spend in
                    spendRow(name: spend.name, tokens: spend.tokens)
                }
            }
            Divider()
            spendRow(name: "合计 / 预算", tokens: mission.spentTokens, budget: mission.budgetTokens)
            Text("本地估算：按 API 回报用量累计;CLI 牧工用量未上报时计 0")
                .font(.caption2)
                .foregroundStyle(Camp.inkSecondary)
        }
        .padding(14)
        .frame(width: 260)
    }

    private func spendRow(name: String, tokens: Int, budget: Int? = nil) -> some View {
        HStack {
            Text(name)
                .font(.callout)
                .foregroundStyle(Camp.ink)
            Spacer()
            Text(budget.map { "\(CampFormat.tokens(tokens)) / \(CampFormat.tokens($0))" }
                ?? "\(CampFormat.tokens(tokens)) tokens")
                .font(.callout.monospacedDigit())
                .foregroundStyle(Camp.inkSecondary)
        }
    }

    @ViewBuilder private var statusChip: some View {
        switch store.missionPhase {
        case .planning:
            CampChip(text: "正在规划路线…", color: Camp.creek, icon: "sparkles")
        case .executing:
            CampChip(text: "基础牛正在制作首版", color: Camp.creek, icon: "bolt.fill")
        case .delivering:
            CampChip(text: "基础牛带着成果回来了", color: Camp.moss, icon: "flag.checkered")
        case .accepted:
            CampChip(text: "已回营", color: Camp.moss, icon: "checkmark")
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
                    onReturnSummary()
                } label: {
                    Label("回营验收", systemImage: "flag.checkered")
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
                Label("发起新放牛任务", systemImage: "flag.fill")
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            .disabled(store.missionStartBlocked)
            .help(store.missionStartBlocked ? store.missionStartBlockMessage : "在当前营地发起新放牛任务")
        case .idle:
            EmptyView()
        }
    }

    /// 预算三选（M5-2，spec §13）：加预算 / 就地收成果 / 放弃
    @ViewBuilder private func budgetBanner(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    budgetSummary
                    budgetActions
                }
            } else {
                HStack(spacing: 10) {
                    budgetSummary
                    Spacer(minLength: 8)
                    budgetActions
                }
            }
        }
        .campCard(padding: 12, highlighted: true)
    }

    private var budgetSummary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.circle.fill")
                .foregroundStyle(Camp.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("预算见底了")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text(budgetLine)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
    }

    private var budgetActions: some View {
        HStack(spacing: 8) {
            Button {
                store.addBudgetToCurrentMission()
            } label: {
                Label("续 \(store.defaultMissionBudget / 1000)k", systemImage: "plus")
            }
            .buttonStyle(CampPrimaryButtonStyle(size: .small))
            Button("就地收成果") {
                store.harvestCurrentMission()
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.moss))
            .help("取消未完成的工作卡，保留已有成果，直接进入回营验收")
            abandonButton
        }
    }

    private var budgetLine: String {
        guard let mission = currentMission else {
            return ""
        }
        return "已用 \(CampFormat.tokens(mission.spentTokens)) / \(CampFormat.tokens(mission.budgetTokens)) tokens，任务已暂停派发"
    }

    private var abandonButton: some View {
        Button(role: .destructive) {
            showAbandonConfirm = true // 二次确认（UX 审计 P1：不可逆操作）
        } label: {
            Text("放弃")
        }
        .buttonStyle(CampSecondaryButtonStyle())
        .confirmationDialog("放弃这次放牛任务？", isPresented: $showAbandonConfirm, titleVisibility: .visible) {
            Button("放弃任务", role: .destructive) {
                store.cancelCurrentMission()
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("未完成的小目标会作废，已产出的交付物保留。")
        }
    }

    private func viewToggle(feedVisible: Bool, feedLocked: Bool, compact: Bool) -> some View {
        Group {
            if compact {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        viewModePicker
                        theaterPulseIndicator
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        missionToolbarActions(feedVisible: feedVisible, feedLocked: feedLocked)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    viewModePicker
                    theaterPulseIndicator
                    Spacer(minLength: 8)
                    missionToolbarActions(feedVisible: feedVisible, feedLocked: feedLocked)
                }
            }
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

    private var viewModePicker: some View {
        HStack(spacing: 2) {
            viewModeSegment(title: "工作卡", icon: "checklist", theater: false)
            viewModeSegment(title: "Coding 草原", icon: "leaf.fill", theater: true)
        }
        .padding(3)
        .background(Camp.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Camp.line, lineWidth: 1))
        .frame(width: 190)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.theaterMode)
    }

    private func viewModeSegment(title: String, icon: String, theater: Bool) -> some View {
        let selected = store.theaterMode == theater
        return Button {
            theaterBinding.wrappedValue = theater
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(selected && theater ? Camp.moss : (selected ? Camp.ember : Camp.inkSecondary))
                Text(title)
                    .foregroundStyle(selected ? Camp.ember : Camp.inkSecondary)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(selected ? Camp.surface : .clear, in: Capsule())
            .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 3, y: 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var theaterPulseIndicator: some View {
        Image(systemName: "sparkles")
            .foregroundStyle(Camp.amber)
            .opacity(theaterPulse ? 1 : 0)
            .symbolEffect(.pulse, options: .repeat(2), value: theaterPulseToken)
    }

    private func missionToolbarActions(feedVisible: Bool, feedLocked: Bool) -> some View {
        HStack(spacing: 20) {
            // M7-D5 / D8：按钮保留在行动页，Cmd+. 由 App 全局 Commands 接管。
            if !store.campHalted {
                Button {
                    showEmergencyStopConfirmation = true
                } label: {
                    if store.haltOperationState == .stopping {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("正在收哨…")
                        }
                    } else {
                        Label("收哨", systemImage: "hand.raised.fill")
                    }
                }
                .foregroundStyle(Camp.charcoalRed)
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                .disabled(!store.canRequestEmergencyStop)
                .help("紧急收哨：暂停全部行动并终止子进程（全局 Cmd+.）")
                .confirmationDialog(
                    "收哨会暂停全营任务并终止牛群的执行进程",
                    isPresented: $showEmergencyStopConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("确认收哨", role: .destructive) {
                        store.emergencyStopCamp()
                    }
                    Button("取消", role: .cancel) {}
                }
            }

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
                        isSelected: store.selectedCardId == card.id,
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
            // 水平呼吸位：卡片阴影/描边不再贴着裁剪边界被硬切出「容器切割线」
            .padding(.horizontal, Self.cardListBleed)
            .padding(.vertical, Self.cardListBleed)
        }
        // 视觉边缘与下方交付物卡对齐（呼吸位向外抵消）
        .padding(.horizontal, -Self.cardListBleed)
        // 滚动上下边渐隐渐显，替代硬切
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.cardListBleed)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.cardListBleed)
            }
        )
    }

    /// 清单滚动区的边缘呼吸位（阴影伸展 + 上下渐隐带高度）
    private static let cardListBleed: CGFloat = 10

    /// 交付物列表高度封顶（约 5 行），超出走内部滚动——交付物再多也不挤压小目标区域
    private static let artifactsMaxHeight: CGFloat = 240
    private static let artifactsScrollThreshold = 4

    @ViewBuilder private var artifactsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RanchSectionHeader(icon: "shippingbox.fill", title: "回营成果", tint: Camp.amber)
                if !store.missionArtifacts.isEmpty {
                    CampChip(text: "\(store.missionArtifacts.count) 件", color: Camp.moss, icon: "doc.fill")
                }
                Spacer()
                if let mission = currentMission, !store.missionCards.isEmpty {
                    Button {
                        store.openReport(missionId: mission.id)
                    } label: {
                        Label("远征报告", systemImage: "doc.text")
                    }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                }
                if !store.missionArtifacts.isEmpty {
                    Button {
                        if reduceMotion {
                            artifactsCollapsed.toggle()
                        } else {
                            withAnimation(.snappy(duration: 0.2)) { artifactsCollapsed.toggle() }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(artifactsCollapsed ? "展开" : "收起")
                            // 披露语义：展开态 ∨（内容敞开着）、收起态 ›（内容收着）
                            Image(systemName: artifactsCollapsed ? "chevron.right" : "chevron.down")
                        }
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(artifactsCollapsed ? "展开交付物列表" : "收起交付物列表")
                }
            }
            if store.missionArtifacts.isEmpty {
                Text("基础牛完成的成果会出现在这里")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else if !artifactsCollapsed {
                if store.missionArtifacts.count > Self.artifactsScrollThreshold {
                    ScrollView {
                        artifactList
                    }
                    .frame(maxHeight: Self.artifactsMaxHeight)
                } else {
                    artifactList
                }
            }
        }
        .campCard()
    }

    private var artifactList: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                            .modifier(ArtifactRowHoverBackground())
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 派生

    private var missionGoalLine: String {
        guard let mission = currentMission else {
            return "放牛任务"
        }
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        return base.split(whereSeparator: \.isNewline).first.map(String.init) ?? "放牛任务"
    }

    private func newcomerSingleCow(campId: String? = nil) -> Bool {
        let regular = missionCompanions(campId: campId).filter { $0.kind == .regular }
        return regular.count == 1 && regular.first?.id == CowTemplate.baseCowId
    }

    private func missionCompanions(campId: String?) -> [CompanionRecord] {
        guard let campId else { return store.companions }
        return store.companions.filter {
            $0.campId == campId || ($0.campId ?? "").isEmpty
        }
    }

    private var doneCount: Int {
        store.missionCards.filter { $0.status == .done }.count
    }

    private var presentCompanionList: [CompanionRecord] {
        store.cardCompanions.values.sorted(by: { $0.name < $1.name })
    }

    private var companionColors: [String: String] {
        Dictionary(store.cardCompanions.map { ($0.key, $0.value.color) }, uniquingKeysWith: { first, _ in first })
    }

    private var leadingCowColor: String {
        guard let color = presentCompanionList.first?.color,
              RanchArtView.spriteImage(colorName: color) != nil else {
            return "purple"
        }
        return color
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

private struct ArtifactRowHoverBackground: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                hovering ? Camp.pasture.opacity(0.5) : Camp.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .onHover { hovering = $0 }
    }
}
