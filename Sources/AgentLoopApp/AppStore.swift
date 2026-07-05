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

    var companions: [CompanionRecord] = []
    var apiKeyPresent = false
    var defaultModel = "claude-sonnet-4-6"
    static let modelChoices = ["claude-sonnet-4-6", "claude-fable-5", "claude-haiku-4-5-20251001"]

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
    var feedNotice: String?
    var selectedCardId: String?
    private var missionTask: Task<Void, Never>?
    private var kernelEventsTask: Task<Void, Never>?

    var chatMessages: [(role: String, text: String)] = []
    var chatStreaming = false
    private var chatTask: Task<Void, Never>?
    private var chatCoalescer: DeltaCoalescer?
    private var chatStreamID = 0

    init() {
        let keychainStore = KeychainStore()
        keychain = keychainStore
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentLoop")
        try! FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        db = try! AppDatabase(path: appSupport.appendingPathComponent("agentloop.sqlite").path)
        let defaultBaseURL = Self.defaultBaseURL
        orchestrator = Orchestrator(
            db: db,
            makeProvider: { model in
                let key = (try? keychainStore.get(account: "anthropic-api-key")) ?? ""
                let rawBase = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
                let base = AnthropicProvider.normalizedBaseURL(rawBase) ?? URL(string: defaultBaseURL)!
                return AnthropicProvider(apiKey: key, model: model, baseURL: base)
            },
            artifactStoreRoot: artifactStoreRoot
        )
        try! db.ensureDefaultCamp()
        apiBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? Self.defaultBaseURL
        reload()
        startKernelEventListener()
        Task { await orchestrator.reconcile() }
    }

    func reload() {
        companions = (try? db.regularCompanions()) ?? []
        apiKeyPresent = ((try? keychain.get(account: "anthropic-api-key")) ?? nil) != nil
        reloadMissionList()
    }

    func saveAPIKey(_ key: String) {
        try? keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: "anthropic-api-key")
        reload()
    }

    func provider(model: String) -> AnthropicProvider? {
        guard let key = try? keychain.get(account: "anthropic-api-key") else {
            return nil
        }
        let base = AnthropicProvider.normalizedBaseURL(apiBaseURL)
            ?? URL(string: Self.defaultBaseURL)!
        return AnthropicProvider(apiKey: key, model: model, baseURL: base)
    }

    func startMission(goal: String, companionIds: [String], workspacePath: String?) {
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
                    plannerModel: defaultModel
                )
                currentMissionId = missionId
                theaterMode = false
                reloadMission(missionId: missionId)
                reloadMissionList()
            } catch {
                missionPhase = .error(readableError(error))
            }
        }
    }

    func selectMission(_ missionId: String) {
        currentMissionId = missionId
        theaterMode = false
        selectedCardId = nil
        feedNotice = nil
        reloadMission(missionId: missionId)
    }

    func closeoutCurrentMission() {
        guard let currentMissionId else { return }
        missionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.closeout(currentMissionId)
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
        }
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
        missionList = (try? db.missions(limit: 20)) ?? []
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
        switch name {
        case "write_file": return "写文件"
        case "read_file": return "读文件"
        case "list_dir": return "查看目录"
        case "web_fetch": return "查网页"
        case "complete_card": return "提交交接包"
        case "block_card": return "报告受阻"
        case "add_progress_note": return "汇报进展"
        case "ask_user": return "提问"
        default: return name
        }
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

    func sendChat(companion: CompanionRecord, text: String) {
        guard !text.isEmpty, !chatStreaming else {
            return
        }
        guard let provider = provider(model: companion.model) else {
            return
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
                    chatMessages[companionMessageIndex].text = "（出错了：\(error)）"
                }
            }
            if chatStreamID == streamID {
                chatStreaming = false
                chatCoalescer = nil
                chatTask = nil
            }
        }
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
    }
}
