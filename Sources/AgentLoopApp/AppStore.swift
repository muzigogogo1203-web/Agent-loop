import SwiftUI
import AgentLoopCore

@MainActor @Observable
final class AppStore {
    struct ActivityItem: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var kind: Kind

        enum Kind {
            case start, tool, toolDone, toolError, note, retry, finish
        }
    }

    let db: AppDatabase
    let keychain: KeychainStore
    let artifactStoreRoot: URL
    let orchestrator: Orchestrator
    /// MCP 驿站（M8-D8：绞杀第二刀，领域状态独立成 store）
    let mcp: McpStore

    var companions: [CompanionRecord] = []
    /// 营地=频道（M5-0）：全部营地，创建序
    var camps: [CampRecord] = []
    /// 侧栏用：各营地的行动列表（含历史，UI 侧再分组）
    var missionsByCamp: [String: [MissionRecord]] = [:]
    var apiKeyPresent = false
    /// M6-D8：Tavily key 在场与否决定 web_search 是否可用（编辑器置灰提示用）
    var searchKeyPresent = false
    /// M6-D11：默认模型持久化（修「重启复位」bug）
    var defaultModel = "claude-sonnet-4-6" {
        didSet { UserDefaults.standard.set(defaultModel, forKey: "defaultModel") }
    }
    /// M6-D11：模型目录从硬编码数组改为可编辑 + 持久化
    static let factoryModelChoices = ["claude-sonnet-4-6", "claude-fable-5", "claude-haiku-4-5-20251001"]
    var modelChoices: [String] = AppStore.factoryModelChoices {
        didSet { UserDefaults.standard.set(modelChoices, forKey: "modelChoices") }
    }
    /// M6-D12：轻任务模型（空 = 跟随默认模型）——蒸馏与规划是最便宜的降档位
    var distillModel: String = "" {
        didSet { UserDefaults.standard.set(distillModel, forKey: "distillModel") }
    }
    var plannerModel: String = "" {
        didSet { UserDefaults.standard.set(plannerModel, forKey: "plannerModel") }
    }
    var effectiveDistillModel: String { distillModel.isEmpty ? defaultModel : distillModel }
    var effectivePlannerModel: String { plannerModel.isEmpty ? defaultModel : plannerModel }

    // MARK: 哨卡（M7）

    /// 紧急收哨状态（内核事件驱动）
    var campHalted = false
    /// 新行动的默认自主档位（M7-D2）
    var defaultAutonomy: MissionAutonomy = .standard {
        didSet { UserDefaults.standard.set(defaultAutonomy.rawValue, forKey: "defaultAutonomy") }
    }

    /// 默认行动预算（M5-2，spec §13：设置页可改；propose_squad 缺省随之）
    var defaultMissionBudget: Int = KernelDefaults.missionBudget {
        didSet { UserDefaults.standard.set(defaultMissionBudget, forKey: "defaultMissionBudget") }
    }

    static let defaultBaseURL = "https://api.anthropic.com"
    var apiBaseURL: String = AppStore.defaultBaseURL {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: "apiBaseURL") }
    }
    var apiBaseURLValid: Bool { AnthropicProvider.normalizedBaseURL(apiBaseURL) != nil }

    enum MissionPhase: Equatable {
        case idle
        case planning
        case executing
        case delivering
        case accepted
        case failed
        case error(String)
    }

    var missionPhase: MissionPhase = .idle
    var currentMissionId: String?
    var missionList: [MissionRecord] = []
    var missionCards: [CardRecord] = []
    var missionArtifacts: [ArtifactRecord] = []
    var cardCompanions: [String: CompanionRecord] = [:]
    var cardLatest: [String: String] = [:]
    var cardActivity: [String: [ActivityItem]] = [:]
    var feedEntries: [FeedEntry] = []
    var pendingRequests: [UserRequestRecord] = []
    var cardPhases: [String: TurnPhase] = [:]
    var recentlyCompleted: Set<String> = []
    var companionAnimStates: [String: CompanionAnimState] = [:]
    var theaterMode = false
    /// 右栏（小队动态）用户偏好：是否展开
    var feedPanelVisible = true
    var feedNotice: String?
    var selectedCardId: String?
    private var missionTask: Task<Void, Never>?
    private var kernelEventsTask: Task<Void, Never>?

    /// 新行动表单草稿（按营地暂存，防切页丢输入——UX 审计 P2）
    struct MissionDraft {
        var goal = ""
        var workspace = ""
        var companionIds: [String] = []
    }
    var missionDrafts: [String: MissionDraft] = [:]

    var chatMessages: [(role: String, text: String)] = []
    var chatStreaming = false
    private var chatTask: Task<Void, Never>?
    private var chatCoalescer: DeltaCoalescer?
    private var chatStreamID = 0

    // MARK: 营地首页（M4）

    struct GuideMessage: Identifiable, Equatable {
        let id: String
        let role: String
        let text: String
        let proposal: SquadProposalBlock?
    }

    var campId: String?
    var campName = "我的营地"
    var guideCompanion: CompanionRecord?
    var campNotes: [CampNoteRecord] = []
    var guideMessages: [GuideMessage] = []
    var guideStreamingText: String?
    var guideStreaming = false
    var guideToolActivity: String?
    var confirmingProposals: Set<String> = []
    var distillingGuideChat = false
    /// 统一知识层 toast（沉淀反馈/提案过期提示），自动消失
    var knowledgeToast: String?
    /// 提案确认后要跳转的行动（RootView 消费后置回 nil）
    var navigateToMissionId: String?
    private var guideTask: Task<Void, Never>?
    private var guideCoalescer: DeltaCoalescer?
    private var guideStreamID = 0
    private var toastTask: Task<Void, Never>?

    // MARK: DM 记忆（M4）

    var memoryNotes: [CompanionNoteRecord] = []
    var memoryDrawerVisible = false
    var distillingMemory = false
    /// 切走沉淀的在途防重（快速来回切换时避免同一增量重复送蒸）
    private var autoDistillInFlight: Set<String> = []

    init() {
        let keychainStore = KeychainStore()
        keychain = keychainStore
        // 开发用状态目录覆盖（UI 预览时指向临时库，避免污染真实数据）
        let appSupport = ProcessInfo.processInfo.environment["AGENTLOOP_STATE_DIR"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AgentLoop")
        try! FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        let database = try! AppDatabase(path: appSupport.appendingPathComponent("agentloop.sqlite").path)
        db = database
        let defaultBaseURL = Self.defaultBaseURL
        // M8-D5：MCP 敏感 env 从 Keychain 解析（account mcp-<serverId>-<key>）；预览模式不读钥匙串
        let isPreview = ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] == "1"
        let mcpManager = McpServerManager(
            db: database,
            secretProvider: { serverId, key in
                guard !isPreview else { return nil }
                return (try? keychainStore.get(account: "mcp-\(serverId)-\(key)")) ?? nil
            }
        )
        mcp = McpStore(db: database, manager: mcpManager, keychain: keychainStore)
        orchestrator = Orchestrator(
            db: database,
            makeProvider: { model in
                let key = (try? keychainStore.get(account: "anthropic-api-key")) ?? ""
                let rawBase = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
                let base = AnthropicProvider.normalizedBaseURL(rawBase) ?? URL(string: defaultBaseURL)!
                return AnthropicProvider(apiKey: key, model: model, baseURL: base)
            },
            artifactStoreRoot: artifactStoreRoot,
            searchKeyProvider: {
                // M6-D7/D8：无 key（或预览模式）→ web_search 不装配
                guard ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] != "1",
                      let key = try? keychainStore.get(account: "tavily-api-key"),
                      !key.isEmpty else { return nil }
                return key
            },
            mcpManager: mcpManager
        )
        try! db.ensureDefaultCamp()
        apiBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? Self.defaultBaseURL
        let storedBudget = UserDefaults.standard.integer(forKey: "defaultMissionBudget")
        if storedBudget > 0 {
            defaultMissionBudget = storedBudget
        }
        // M6-D11/D12：模型目录与各档模型回读
        if let storedChoices = UserDefaults.standard.stringArray(forKey: "modelChoices"),
           !storedChoices.isEmpty {
            modelChoices = storedChoices
        }
        if let storedDefault = UserDefaults.standard.string(forKey: "defaultModel"),
           !storedDefault.isEmpty {
            defaultModel = storedDefault
        }
        distillModel = UserDefaults.standard.string(forKey: "distillModel") ?? ""
        plannerModel = UserDefaults.standard.string(forKey: "plannerModel") ?? ""
        if let storedAutonomy = UserDefaults.standard.string(forKey: "defaultAutonomy"),
           let autonomy = MissionAutonomy(rawValue: storedAutonomy) {
            defaultAutonomy = autonomy
        }
        // M7-D5：退出时终止 shell/MCP 子进程，防僵尸（同步、最要紧的一件）
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            ShellProcessRegistry.shared.terminateAll()
        }
        mcp.onToast = { [weak self] message in self?.showToast(message) }
        reload()
        startKernelEventListener()
        // UI 预览模式（开发用）：不做启动领养调度，避免预览时真实派发与钥匙串弹窗
        if !Self.isUIPreview {
            // M5-1 启动恢复：收编崩溃遗留的 running 孤儿卡 + 提案自愈，再照常调度
            Task { await orchestrator.recoverAndReconcile() }
        }
    }

    /// 环境变量 AGENTLOOP_UI_PREVIEW=1 时为 UI 预览模式：不读钥匙串、不调度任务
    static let isUIPreview = ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] == "1"
    /// 预览直达（截图循环用）：启动即打开指定行动，可选直接进小剧场
    static let previewMissionId = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_MISSION"]
    static let previewTheater = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_THEATER"] == "1"

    func reload() {
        companions = (try? db.regularCompanions()) ?? []
        camps = (try? db.camps()) ?? []
        apiKeyPresent = Self.isUIPreview
            ? false
            : ((try? keychain.get(account: "anthropic-api-key")) ?? nil) != nil
        searchKeyPresent = Self.isUIPreview
            ? false
            : (((try? keychain.get(account: "tavily-api-key")) ?? nil).map { !$0.isEmpty } ?? false)
        reloadMissionList()
    }

    func saveAPIKey(_ key: String) {
        try? keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: "anthropic-api-key")
        reload()
    }

    /// M6-D7：Tavily 搜索 key（Keychain 第二槽）
    func saveSearchKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? keychain.delete(account: "tavily-api-key")
        } else {
            try? keychain.set(trimmed, account: "tavily-api-key")
        }
        reload()
    }

    func provider(model: String) -> AnthropicProvider? {
        // 预览模式语义 = 不读钥匙串（避免系统授权弹窗）；LLM 动作统一得到「请先填 key」提示
        guard !Self.isUIPreview, let key = try? keychain.get(account: "anthropic-api-key") else {
            return nil
        }
        let base = AnthropicProvider.normalizedBaseURL(apiBaseURL)
            ?? URL(string: Self.defaultBaseURL)!
        return AnthropicProvider(apiKey: key, model: model, baseURL: base)
    }

    func startMission(goal: String, companionIds: [String], workspacePath: String?, campId: String? = nil,
                      autonomy: MissionAutonomy? = nil) {
        guard ((try? keychain.get(account: "anthropic-api-key")) ?? nil) != nil else {
            missionPhase = .error("请先在设置里填入 API key")
            return
        }
        currentMissionId = nil
        missionCards = []
        missionArtifacts = []
        cardCompanions = [:]
        cardLatest = [:]
        cardActivity = [:]
        feedEntries = []
        pendingRequests = []
        cardPhases = [:]
        recentlyCompleted = []
        companionAnimStates = [:]
        feedNotice = nil
        selectedCardId = nil
        theaterMode = false
        missionPhase = .planning
        reloadMissionList()
        missionTask?.cancel()
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let missionId = try await orchestrator.startMission(
                    goal: goal,
                    companionIds: companionIds,
                    workspacePath: workspacePath,
                    plannerModel: effectivePlannerModel,
                    budgetTokens: defaultMissionBudget,
                    campId: campId,
                    autonomy: autonomy ?? defaultAutonomy
                )
                currentMissionId = missionId
                theaterMode = false
                if let campId { missionDrafts[campId] = nil } // 出发成功才清草稿
                reloadMission(missionId: missionId)
                reloadMissionList()
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func selectMission(_ missionId: String) {
        currentMissionId = missionId
        theaterMode = Self.isUIPreview && Self.previewTheater
        selectedCardId = nil
        feedNotice = nil
        reloadMission(missionId: missionId)
    }

    func closeoutCurrentMission() {
        guard let currentMissionId else { return }
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.closeout(currentMissionId, distillModel: effectiveDistillModel)
                reloadMission(missionId: currentMissionId)
                reloadMissionList()
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func cancelCurrentMission() {
        guard let currentMissionId else { return }
        missionTask = Task { [weak self] in
            guard let self else { return }
            await cancelMission(missionId: currentMissionId)
        }
    }

    func cancelMission(missionId: String) async {
        await orchestrator.cancelMission(missionId)
        if currentMissionId == missionId {
            reloadMission(missionId: missionId)
        }
        reloadMissionList()
    }

    // MARK: - 预算三选（M5-2）

    /// 当前行动是否预算见底（executing 且 spent>=budget）——UI banner 条件
    var currentMissionBudgetExhausted: Bool {
        guard let mission = missionList.first(where: { $0.id == currentMissionId }) else { return false }
        return mission.status == .executing && mission.spentTokens >= mission.budgetTokens
    }

    func addBudgetToCurrentMission() {
        guard let currentMissionId else { return }
        let tokens = defaultMissionBudget
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.addBudget(missionId: currentMissionId, tokens: tokens)
                reloadMission(missionId: currentMissionId)
                reloadMissionList()
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func harvestCurrentMission() {
        guard let currentMissionId else { return }
        missionTask = Task { [weak self] in
            guard let self else { return }
            await orchestrator.harvestMission(currentMissionId)
            reloadMission(missionId: currentMissionId)
            reloadMissionList()
        }
    }

    func retryCard(_ cardId: String) {
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.retryCard(cardId)
                if let currentMissionId {
                    reloadMission(missionId: currentMissionId)
                }
                reloadMissionList()
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func answerRequest(requestId: String, answer: AskUserAnswer) {
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.answerUserRequest(
                    requestId: requestId,
                    answerJson: try answerJson(for: answer)
                )
                feedNotice = nil
                if let currentMissionId {
                    reloadMission(missionId: currentMissionId)
                }
                reloadMissionList()
            } catch is StaleUserRequestError {
                if let currentMissionId {
                    reloadMission(missionId: currentMissionId, clearNotice: false)
                }
                feedNotice = "这个问题已经过期"
                showToast("这个问题已经过期") // 右栏收起时也能看到（UX 审计 P2）
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func resetMission() {
        currentMissionId = nil
        missionPhase = .idle
        missionCards = []
        missionArtifacts = []
        cardCompanions = [:]
        cardLatest = [:]
        cardActivity = [:]
        feedEntries = []
        pendingRequests = []
        cardPhases = [:]
        recentlyCompleted = []
        companionAnimStates = [:]
        feedNotice = nil
        selectedCardId = nil
        theaterMode = false
    }

    private func startKernelEventListener() {
        kernelEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = await orchestrator.events()
            for await event in stream {
                handleKernelEvent(event)
            }
        }
    }

    private func handleKernelEvent(_ event: KernelEvent) {
        switch event {
        case .planningStarted(let missionId):
            reloadMissionList()
            guard currentMissionId == missionId else { return }
            missionPhase = .planning
        case .planCompleted(let missionId, _), .missionChanged(let missionId):
            reloadMissionList()
            guard currentMissionId == missionId else { return }
            reloadMission(missionId: missionId)
        case .cardEvent(let cardId, let agentEvent):
            if missionCards.contains(where: { $0.id == cardId }) {
                handleCardEvent(cardId: cardId, event: agentEvent)
            } else if case .finished = agentEvent,
                      missionId(forCardId: cardId) == currentMissionId {
                handleCardEvent(cardId: cardId, event: agentEvent)
            }
        case .kernelError(let missionId, let message):
            reloadMissionList()
            if currentMissionId == missionId || missionId.isEmpty {
                if let currentMissionId {
                    reloadMission(missionId: currentMissionId)
                }
                missionPhase = .error(message)
            }
        case .campNoteCreated:
            reloadCampKnowledge()
        case .haltStateChanged(let halted):
            campHalted = halted
            reloadMissionList()
            if let currentMissionId { reloadMission(missionId: currentMissionId) }
        }
    }

    // MARK: 哨卡动作（M7-D5/D2/D7）

    func emergencyStopCamp() {
        Task { await orchestrator.emergencyStop() }
    }

    func resumeCamp() {
        Task { await orchestrator.resume() }
    }

    /// 当前行动档位中途可改（记 autonomy_changed 事件）
    func setCurrentMissionAutonomy(_ autonomy: MissionAutonomy) {
        guard let currentMissionId else { return }
        do {
            try db.setMissionAutonomy(missionId: currentMissionId, to: autonomy)
            reloadMissionList()
        } catch {
            showToast("档位修改失败：\(readableError(error))")
        }
    }

    /// 行动花销分账（M7-D7，本地估算）
    func spendBreakdown(missionId: String) -> MissionSpendBreakdown? {
        try? db.missionSpendBreakdown(missionId: missionId)
    }

    /// 收营蒸馏/沉淀产出笔记后刷新营地首页数据
    func reloadCampKnowledge() {
        guard let campId else { return }
        campNotes = (try? db.campNotes(campId: campId)) ?? []
    }

    private func reloadMission(missionId: String, clearNotice: Bool = true) {
        guard let mission = try? db.mission(id: missionId) else { return }
        if clearNotice {
            feedNotice = nil
        }
        missionCards = (try? db.cards(missionId: missionId)) ?? []
        missionArtifacts = (try? db.missionArtifacts(missionId: missionId)) ?? []
        pendingRequests = (try? db.pendingUserRequests(missionId: missionId)) ?? []
        var seenAssigneeIds = Set<String>()
        let assigneeIds = missionCards.compactMap(\.assigneeId).filter { seenAssigneeIds.insert($0).inserted }
        let companions = (try? db.companions(ids: assigneeIds)) ?? []
        cardCompanions = Dictionary(companions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let events = (try? db.events(missionId: missionId, limit: 200)) ?? []
        feedEntries = ActivityFeed.entries(events: events, cards: missionCards, companions: cardCompanions)
        if let selectedCardId, !missionCards.contains(where: { $0.id == selectedCardId }) {
            self.selectedCardId = nil
        }
        switch mission.status {
        case .planning:
            missionPhase = .planning
        case .executing:
            missionPhase = .executing
        case .delivering:
            missionPhase = .delivering
        case .accepted:
            missionPhase = .accepted
        case .failed:
            missionPhase = .failed
        }
        recomputeAnimStates()
    }

    private func reloadMissionList() {
        missionList = (try? db.missions(limit: 50)) ?? []
        if camps.isEmpty {
            camps = (try? db.camps()) ?? []
        }
        var byCamp: [String: [MissionRecord]] = [:]
        for camp in camps {
            byCamp[camp.id] = (try? db.missions(campId: camp.id)) ?? []
        }
        missionsByCamp = byCamp
    }

    private func handleCardEvent(cardId: String, event: AgentEvent) {
        switch event {
        case .turnStarted:
            cardPhases[cardId] = .waitingProvider
            setCardLatest(cardId: cardId, "正在思考")
            cardActivity[cardId, default: []].append(ActivityItem(text: "开始新一轮", kind: .start))
        case .textDelta:
            cardPhases[cardId] = .streaming
            setCardLatest(cardId: cardId, "正在生成")
        case .toolStarted(let name):
            cardPhases[cardId] = .toolRunning
            setCardLatest(cardId: cardId, "正在\(humanToolName(name))")
            cardActivity[cardId, default: []].append(ActivityItem(text: "正在\(humanToolName(name))…", kind: .tool))
        case .toolFinished(let name, let isError):
            cardPhases[cardId] = .streaming
            markToolActivityFinished(cardId: cardId, name: name, isError: isError)
            setCardLatest(cardId: cardId, isError ? "\(humanToolName(name))失败" : "\(humanToolName(name))完成")
            if (name == "add_progress_note" || name == "ask_user"), let currentMissionId {
                reloadMission(missionId: currentMissionId)
            } else {
                recomputeAnimStates()
            }
        case .turnRetrying(let attempt, let reason):
            setCardLatest(cardId: cardId, "网络重试 \(attempt)")
            cardActivity[cardId, default: []].append(ActivityItem(text: "网络波动，正在重试（\(attempt)/2）：\(reason)", kind: .retry))
        case .contextCompacted:
            setCardLatest(cardId: cardId, "整理了一下背包")
            cardActivity[cardId, default: []].append(ActivityItem(text: "上下文变长，压缩了早期过程继续赶路", kind: .note))
        case .turnEnded:
            break
        case .finished(let outcome):
            cardPhases.removeValue(forKey: cardId)
            switch outcome {
            case .completed(let handoff):
                setCardLatest(cardId: cardId, handoff.summary)
                markRecentlyCompleted(cardId)
            case .blocked(_, let detail):
                setCardLatest(cardId: cardId, detail)
            }
            cardActivity[cardId, default: []].append(ActivityItem(text: "运行结束", kind: .finish))
            if let currentMissionId {
                reloadMission(missionId: currentMissionId)
            }
        }
        recomputeAnimStates()
    }

    private func setCardLatest(cardId: String, _ value: String) {
        guard cardLatest[cardId] != value else { return }
        cardLatest[cardId] = value
    }

    private func markToolActivityFinished(cardId: String, name: String, isError: Bool) {
        let label = humanToolName(name)
        let pendingText = "正在\(label)…"
        if let index = cardActivity[cardId, default: []].lastIndex(where: { $0.kind == .tool && $0.text == pendingText }) {
            cardActivity[cardId, default: []][index].text = isError ? "\(label)失败" : "\(label)完成"
            cardActivity[cardId, default: []][index].kind = isError ? .toolError : .toolDone
        }
    }

    private func humanToolName(_ name: String) -> String {
        // M6-D5：中文名收敛到 ToolDef.displayName 单点维护
        ToolDef.displayName(name)
    }

    private func missionId(forCardId cardId: String) -> String? {
        if let current = missionCards.first(where: { $0.id == cardId })?.missionId {
            return current
        }
        return try? db.card(id: cardId)?.missionId
    }

    private func markRecentlyCompleted(_ cardId: String) {
        recentlyCompleted.insert(cardId)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.recentlyCompleted.remove(cardId)
            self?.recomputeAnimStates()
        }
    }

    private func recomputeAnimStates() {
        var states: [String: CompanionAnimState] = [:]
        for companion in cardCompanions.values {
            states[companion.id] = AnimStateDeriver.derive(
                companionId: companion.id,
                cards: missionCards,
                phases: cardPhases,
                recentlyCompletedCardIds: recentlyCompleted
            )
        }
        companionAnimStates = states
    }

    private func answerJson(for answer: AskUserAnswer) throws -> String {
        let value: JSONValue
        switch answer {
        case .choice(let index):
            value = ["choice": .number(Double(index))]
        case .confirm(let confirm):
            value = ["confirm": .bool(confirm)]
        case .text(let text):
            value = ["text": .string(text)]
        case .approval(let approved, let reason):
            // M7-D4：审批答复；decided 事件在 DB 层随答复同事务落
            var object: [String: JSONValue] = ["decision": .string(approved ? "approve" : "deny")]
            if let reason, !reason.isEmpty {
                object["reason"] = .string(reason)
            }
            value = .object(object)
        }
        return try value.encodedString()
    }

    private func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return String(describing: error)
    }

    func revealArtifact(_ artifact: ArtifactRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: artifact.path)])
    }

    /// 返回是否受理（未受理时调用方不应清空输入——UX 审计 P1：无 key 静默吞消息）
    @discardableResult
    func sendChat(companion: CompanionRecord, text: String) -> Bool {
        guard !text.isEmpty, !chatStreaming else {
            return false
        }
        guard let provider = provider(model: companion.model) else {
            showToast("请先在设置里填入 API key")
            return false
        }
        chatStreamID += 1
        let streamID = chatStreamID
        chatMessages.append((role: "user", text: text))
        chatMessages.append((role: "companion", text: ""))
        let companionMessageIndex = chatMessages.count - 1
        chatStreaming = true
        let chat = ChatService(db: db, provider: provider)
        let coalescer = DeltaCoalescer { [weak self] batch in
            await MainActor.run {
                guard let self,
                      self.chatStreamID == streamID,
                      self.chatMessages.indices.contains(companionMessageIndex) else {
                    return
                }
                self.chatMessages[companionMessageIndex].text += batch
            }
        }
        chatCoalescer = coalescer
        chatTask = Task {
            do {
                for try await event in try chat.send(companionId: companion.id, userText: text) {
                    if case .textDelta(let text) = event {
                        await coalescer.push(text)
                    }
                }
                if Task.isCancelled {
                    await coalescer.discard()
                } else {
                    await coalescer.flush()
                }
            } catch is CancellationError {
                await coalescer.discard()
            } catch {
                await coalescer.discard()
                if chatStreamID == streamID, chatMessages.indices.contains(companionMessageIndex) {
                    // 人话化错误（UX 审计 P3：不倒原始 error 串）
                    chatMessages[companionMessageIndex].text =
                        "（没发出去：\(CampCopy.humanizeBlockedDetail(readableError(error)))）"
                }
            }
            if chatStreamID == streamID {
                chatStreaming = false
                chatCoalescer = nil
                chatTask = nil
            }
        }
        return true
    }

    /// 停止当前 DM 流式（UX 审计 P2：无死等）；已收到的增量保留在气泡里
    func stopChat() {
        guard chatStreaming else { return }
        chatStreamID += 1
        chatTask?.cancel()
        chatTask = nil
        let coalescer = chatCoalescer
        chatCoalescer = nil
        chatStreaming = false
        Task { await coalescer?.flush() }
        showToast("已停下这条回复")
    }

    /// 停止向导流式
    func stopGuideChat() {
        guard guideStreaming else { return }
        guideStreamID += 1
        guideTask?.cancel()
        guideTask = nil
        let coalescer = guideCoalescer
        guideCoalescer = nil
        guideStreaming = false
        guideStreamingText = nil
        guideToolActivity = nil
        Task { await coalescer?.discard() }
        reloadGuideMessages()
        showToast("已停下向导这条回复")
    }

    func loadChatHistory(companion: CompanionRecord) {
        // 切换伙伴时终止在途流，防止上一位伙伴的增量写进新伙伴的气泡
        chatStreamID += 1
        chatTask?.cancel()
        chatTask = nil
        let coalescer = chatCoalescer
        chatCoalescer = nil
        chatStreaming = false
        Task {
            await coalescer?.discard()
        }
        let thread = try? db.findOrCreateDMThread(companionId: companion.id)
        chatMessages = (thread.flatMap { try? db.messages(threadId: $0.id) } ?? [])
            .map { (role: $0.role, text: $0.text) }
        reloadMemoryNotes(companionId: companion.id)
    }

    // MARK: - 营地首页（M4）

    func loadCampHome(campId targetCampId: String? = nil) {
        let camp: CampRecord?
        if let targetCampId {
            camp = try? db.camp(id: targetCampId)
        } else {
            camp = try? db.ensureDefaultCamp()
        }
        guard let camp else { return }
        // 切换营地时终止在途向导流，防串台（对齐 DM 的 streamID 语义）
        if campId != camp.id {
            guideStreamID += 1
            guideTask?.cancel()
            guideTask = nil
            let coalescer = guideCoalescer
            guideCoalescer = nil
            guideStreaming = false
            guideStreamingText = nil
            guideToolActivity = nil
            Task { await coalescer?.discard() }
        }
        campId = camp.id
        campName = camp.name
        guideCompanion = try? db.guide(campId: camp.id)
        reloadCampKnowledge()
        reloadGuideMessages()
        reloadMissionList()
    }

    /// 建营地（C2）：返回新营地供导航；失败 toast。
    func createCamp(name: String, guidePrompt: String?) -> CampRecord? {
        do {
            let camp = try db.createCamp(name: name, guidePrompt: guidePrompt)
            reload()
            return camp
        } catch {
            showToast("建营地失败：\(readableError(error))")
            return nil
        }
    }

    /// 改名（C3）；当前正看这个营地时同步刷新 header。
    func renameCamp(id: String, name: String) {
        try? db.renameCamp(id: id, name: name)
        reload()
        if campId == id, let camp = try? db.camp(id: id) {
            campName = camp.name
        }
    }

    func camp(forMission missionId: String) -> String? {
        (try? db.squad(forMission: missionId))?.campId
    }

    private func reloadGuideMessages() {
        guard let campId, let thread = try? db.findOrCreateGuideThread(campId: campId) else { return }
        guideMessages = ((try? db.messages(threadId: thread.id)) ?? []).map {
            GuideMessage(id: $0.id, role: $0.role, text: $0.text, proposal: $0.proposal)
        }
    }

    func sendGuideChat(text: String) {
        guard !text.isEmpty, !guideStreaming, let campId else { return }
        guard let provider = provider(model: defaultModel) else {
            showToast("请先在设置里填入 API key")
            return
        }
        guideStreamID += 1
        let streamID = guideStreamID
        guideStreaming = true
        guideStreamingText = ""
        guideToolActivity = nil
        // 乐观呈现用户消息；后续 reload 时以落库消息为准（全量替换，不会重复）
        guideMessages.append(GuideMessage(id: "local-user-\(streamID)", role: "user", text: text, proposal: nil))
        let service = GuideChatService(db: db, provider: provider)
        let coalescer = DeltaCoalescer { [weak self] batch in
            await MainActor.run {
                guard let self, self.guideStreamID == streamID else { return }
                self.guideStreamingText = (self.guideStreamingText ?? "") + batch
                self.guideToolActivity = nil
            }
        }
        guideCoalescer = coalescer
        guideTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in try service.send(campId: campId, userText: text) {
                    switch event {
                    case .textDelta(let delta):
                        await coalescer.push(delta)
                    case .toolActivity(let name):
                        await coalescer.flush()
                        if guideStreamID == streamID {
                            guideToolActivity = Self.humanGuideToolName(name)
                        }
                    case .proposalCreated:
                        await coalescer.flush()
                        if guideStreamID == streamID {
                            reloadGuideMessages()
                        }
                    case .finished:
                        break
                    }
                }
                await coalescer.flush()
            } catch {
                await coalescer.discard()
                if guideStreamID == streamID {
                    showToast("向导这会儿联系不上：\(readableError(error))")
                }
            }
            if guideStreamID == streamID {
                guideStreaming = false
                guideStreamingText = nil
                guideToolActivity = nil
                guideCoalescer = nil
                guideTask = nil
                reloadGuideMessages()
            }
        }
    }

    func confirmProposal(messageId: String) {
        guard !confirmingProposals.contains(messageId) else { return }
        guard provider(model: defaultModel) != nil else {
            showToast("请先在设置里填入 API key")
            return
        }
        confirmingProposals.insert(messageId)
        Task { [weak self] in
            guard let self else { return }
            do {
                let missionId = try await orchestrator.confirmSquadProposal(
                    messageId: messageId, plannerModel: effectivePlannerModel,
                    fallbackBudget: defaultMissionBudget,
                    autonomy: defaultAutonomy)
                reloadGuideMessages()
                reloadMissionList()
                navigateToMissionId = missionId
            } catch is StaleProposalError {
                reloadGuideMessages()
                showToast("这个提案已经处理过了")
            } catch {
                reloadGuideMessages()
                showToast("建队失败：\(readableError(error))")
            }
            confirmingProposals.remove(messageId)
        }
    }

    func dismissProposal(messageId: String) {
        do {
            try db.dismissProposalBlock(messageId: messageId)
        } catch is StaleProposalError {
            showToast("这个提案已经处理过了")
        } catch {
            showToast("操作失败：\(readableError(error))")
        }
        reloadGuideMessages()
    }

    func distillGuideChatNow() {
        guard let campId, !distillingGuideChat else { return }
        guard let provider = provider(model: effectiveDistillModel) else {
            showToast("请先在设置里填入 API key")
            return
        }
        distillingGuideChat = true
        Task { [weak self] in
            guard let self else { return }
            let note = await MemoryDistillService(db: db, provider: provider).distillGuideChat(campId: campId)
            distillingGuideChat = false
            reloadCampKnowledge()
            showToast(note != nil ? "已沉淀 1 条营地笔记" : "这段对话暂时没什么可记的")
        }
    }

    // MARK: - 营地笔记 CRUD（M4）

    func saveCampNoteEdits(_ note: CampNoteRecord) {
        var updated = note
        updated.updatedAt = Date()
        try? db.saveCampNote(updated)
        reloadCampKnowledge()
    }

    func deleteCampNote(id: String) {
        try? db.deleteCampNote(id: id)
        reloadCampKnowledge()
    }

    func toggleCampNotePin(_ note: CampNoteRecord) {
        var updated = note
        updated.pinned.toggle()
        updated.updatedAt = Date()
        try? db.saveCampNote(updated)
        reloadCampKnowledge()
    }

    // MARK: - 伙伴记忆（M4）

    func reloadMemoryNotes(companionId: String) {
        memoryNotes = (try? db.companionNotes(companionId: companionId)) ?? []
    }

    func distillMemoryNow(companion: CompanionRecord) {
        guard !distillingMemory else { return }
        guard let provider = provider(model: effectiveDistillModel) else {
            showToast("请先在设置里填入 API key")
            return
        }
        distillingMemory = true
        Task { [weak self] in
            guard let self else { return }
            let note = await MemoryDistillService(db: db, provider: provider)
                .distillDM(companionId: companion.id, minMessages: 1)
            distillingMemory = false
            reloadMemoryNotes(companionId: companion.id)
            showToast(note != nil ? "已记住这段对话" : "暂时没什么要记的")
        }
    }

    /// 切走 DM 线程时的自动沉淀（D7：未蒸馏增量 ≥4 条才触发，后台静默）
    func autoDistillOnLeave(companionId: String) {
        // 预览模式不触发（避免钥匙串弹窗）；正常模式无 key 时静默跳过
        guard !Self.isUIPreview, let provider = provider(model: effectiveDistillModel) else { return }
        guard autoDistillInFlight.insert(companionId).inserted else { return }
        Task { [weak self] in
            guard let self else { return }
            let note = await MemoryDistillService(db: db, provider: provider)
                .distillDM(companionId: companionId, minMessages: MemoryDistillService.autoMinMessages)
            autoDistillInFlight.remove(companionId)
            if note != nil {
                showToast("这段私聊已沉淀为记忆")
            }
        }
    }

    func saveMemoryEdits(_ note: CompanionNoteRecord) {
        var updated = note
        updated.updatedAt = Date()
        try? db.saveCompanionNote(updated)
        reloadMemoryNotes(companionId: note.companionId)
    }

    func deleteMemoryNote(id: String, companionId: String) {
        try? db.deleteCompanionNote(id: id)
        reloadMemoryNotes(companionId: companionId)
    }

    func toggleMemoryPin(_ note: CompanionNoteRecord) {
        var updated = note
        updated.pinned.toggle()
        updated.updatedAt = Date()
        try? db.saveCompanionNote(updated)
        reloadMemoryNotes(companionId: note.companionId)
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        knowledgeToast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.knowledgeToast = nil
        }
    }

    private static func humanGuideToolName(_ name: String) -> String {
        switch name {
        case "search_camp_notes": return "向导翻了翻笔记本…"
        case "camp_status": return "向导看了看营地各处…"
        case "propose_squad": return "向导在拟组队提案…"
        default: return "向导在忙…"
        }
    }
}
