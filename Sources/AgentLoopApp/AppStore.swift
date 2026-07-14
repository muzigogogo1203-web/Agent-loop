import SwiftUI
import CryptoKit
import Network
import Security
import AgentLoopCore

private final class OpenAIOAuthReloginHandler: @unchecked Sendable {
    @MainActor weak var store: AppStore?

    func markPermanentFailure() {
        Task { @MainActor [weak self] in
            guard let store = self?.store else { return }
            store.oauthNeedsRelogin = true
            store.oauthLoginStatus = "ChatGPT 登录已过期，请在设置里重新登录"
            store.reload()
        }
    }
}

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

    private let stateDirectoryLock: StateDirectoryLock
    let db: AppDatabase
    let keychain: KeychainStore
    private let openAIOAuthSession: OpenAIOAuthSession?
    let artifactStoreRoot: URL
    let reportStoreRoot: URL
    let orchestrator: Orchestrator
    /// MCP 驿站（M8-D8：绞杀第二刀，领域状态独立成 store）
    let mcp: McpStore

    var companions: [CompanionRecord] = []
    /// 营地=频道（M5-0）：全部营地，创建序
    var camps: [CampRecord] = []
    /// 侧栏用：各营地的行动列表（含历史，UI 侧再分组）
    var missionsByCamp: [String: [MissionRecord]] = [:]
    var codingRanchDashboard: CampDashboardViewState?
    var codingRanchInbox = RuminationInboxViewState(loadState: .idle, items: [])
    var apiKeyPresent = false
    var webCredentialPresent = false
    var preferredCredentialSource: ProviderCredentialSource = .apiKey {
        didSet { UserDefaults.standard.set(preferredCredentialSource.rawValue, forKey: "preferredCredentialSource") }
    }
    var oauthLoginStatus: String?
    var oauthNeedsRelogin = false
    /// M6-D8：Tavily key 在场与否决定 web_search 是否可用（编辑器置灰提示用）
    var searchKeyPresent = false
    /// M6-D11：默认模型持久化（修「重启复位」bug）
    var defaultModel = "claude-sonnet-4-6" {
        didSet { UserDefaults.standard.set(defaultModel, forKey: "defaultModel") }
    }
    /// M6-D11：模型目录从硬编码数组改为可编辑 + 持久化
    static let factoryModelChoices = [
        "claude-sonnet-4-6",
        "claude-fable-5",
        "claude-haiku-4-5-20251001",
        "gpt-4.1",
        "gpt-4o",
        "DeepSeek-V4-Flash-Third",
    ]
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

    enum HaltOperationState: Equatable {
        case idle
        case stopping
        case resuming
    }

    /// 持久化内核门的 UI 投影；启动时会在首次 reload 前同步回读。
    var campHalted = false
    var haltOperationState: HaltOperationState = .idle
    var haltRestoredFromPreviousSession = false
    var haltPersistencePending = false
    var haltErrorMessage: String?
    var kernelStartupRecoveryPending = false

    var missionStartBlocked: Bool {
        kernelStartupRecoveryPending || campHalted || haltOperationState != .idle
    }

    var missionStartBlockMessage: String {
        if kernelStartupRecoveryPending {
            return "正在检查并收编上次中断的任务，完成前不能启动新行动。"
        }
        switch haltOperationState {
        case .stopping:
            return "正在收哨，新的行动暂时不能开工。"
        case .resuming:
            return "正在安全恢复，完成前不会启动新的行动。"
        case .idle:
            return "全部行动已暂停。恢复全部行动后才能开工。"
        }
    }

    var showsGlobalHaltBanner: Bool {
        campHalted || haltOperationState != .idle
    }

    var canRequestEmergencyStop: Bool {
        haltOperationState == .idle && (!campHalted || haltPersistencePending)
    }

    var haltBannerTitle: String {
        switch haltOperationState {
        case .stopping: return "正在收哨…"
        case .resuming: return "正在恢复…"
        case .idle: return "全部行动已暂停"
        }
    }

    var haltBannerMessage: String {
        switch haltOperationState {
        case .stopping:
            if haltPersistencePending {
                return "当前行动工作仍保持停止，正在重试保存持久化收哨状态。"
            }
            return "正在停止行动规划、行动内模型调用和工具进程。完成前不会派发新的行动工作。"
        case .resuming:
            return "正在安全收编中断任务并持久化恢复状态。成功之前不会启动新的行动工作。"
        case .idle:
            if let haltErrorMessage { return haltErrorMessage }
            if haltRestoredFromPreviousSession {
                return "上次退出时仍处于收哨状态。为安全起见，没有自动恢复任何行动。"
            }
            return "行动规划、行动内模型调用和工具派发均已停止。私聊和手动沉淀仍可使用；恢复后，等待中的行动可能继续调用模型并产生花销。"
        }
    }
    /// 新行动的默认自主档位（M7-D2）
    var defaultAutonomy: MissionAutonomy = .standard {
        didSet { UserDefaults.standard.set(defaultAutonomy.rawValue, forKey: "defaultAutonomy") }
    }

    private struct StoredCredential: Sendable {
        var value: String
        var source: ProviderCredentialSource
        var chatGPTAccountID: String?

        var authScheme: ProviderAuthScheme {
            switch source {
            case .apiKey:
                return .automatic
            case .webLogin:
                return .oauthBearer
            }
        }
    }

    nonisolated private static let apiKeyAccount = "anthropic-api-key"
    nonisolated private static let oauthAccessTokenAccount = "oauth-access-token"
    nonisolated private static let oauthRefreshTokenAccount = "oauth-refresh-token"
    nonisolated private static let oauthIDTokenAccount = "oauth-id-token"
    nonisolated private static let oauthChatGPTAccountIDAccount = "oauth-chatgpt-account-id"
    nonisolated private static let oauthCodeVerifierAccount = "oauth-code-verifier"
    nonisolated private static let preferredCredentialSourceKey = "preferredCredentialSource"
    nonisolated private static let oauthStateKey = "oauthState"
    nonisolated private static let genericOAuthClientID = "agentloop"
    nonisolated private static let genericOAuthRedirectURI = "agentloop://oauth/callback"
    nonisolated private static let oauthCallbackQueue = DispatchQueue(label: "com.muzi.agentloop.oauth-callback")

    /// 默认行动预算（M5-2，spec §13：设置页可改；propose_squad 缺省随之）
    var defaultMissionBudget: Int = KernelDefaults.missionBudget {
        didSet { UserDefaults.standard.set(defaultMissionBudget, forKey: "defaultMissionBudget") }
    }

    static let defaultBaseURL = "https://api.anthropic.com"
    var apiBaseURL: String = AppStore.defaultBaseURL {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: "apiBaseURL") }
    }
    var apiFormat: ProviderAPIFormat = .anthropicMessages {
        didSet { UserDefaults.standard.set(apiFormat.rawValue, forKey: "apiFormat") }
    }
    var apiAuthScheme: ProviderAuthScheme = .automatic {
        didSet { UserDefaults.standard.set(apiAuthScheme.rawValue, forKey: "apiAuthScheme") }
    }
    var apiBaseURLValid: Bool { ProviderEndpoint.normalizedBaseURL(apiBaseURL) != nil }

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
    var artifactLedgerItems: [ArtifactLedgerItem] = []
    var artifactLedgerIncludeArchived = true
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
    private var oauthCallbackListener: NWListener?

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
        let reloginHandler = OpenAIOAuthReloginHandler()
        let openAISession = Self.isUIPreview ? nil : OpenAIOAuthSession(
            store: keychainStore,
            accessTokenAccount: Self.oauthAccessTokenAccount,
            refreshTokenAccount: Self.oauthRefreshTokenAccount,
            idTokenAccount: Self.oauthIDTokenAccount,
            chatGPTAccountIDAccount: Self.oauthChatGPTAccountIDAccount,
            onPermanentFailure: {
                reloginHandler.markPermanentFailure()
            }
        )
        keychain = keychainStore
        openAIOAuthSession = openAISession
        apiFormat = ProviderAPIFormat(
            rawValue: UserDefaults.standard.string(forKey: "apiFormat") ?? ""
        ) ?? .anthropicMessages
        apiAuthScheme = .automatic
        UserDefaults.standard.set(ProviderAuthScheme.automatic.rawValue, forKey: "apiAuthScheme")
        preferredCredentialSource = ProviderCredentialSource(
            rawValue: UserDefaults.standard.string(forKey: Self.preferredCredentialSourceKey) ?? ""
        ) ?? .apiKey
        // 开发用状态目录覆盖（UI 预览时指向临时库，避免污染真实数据）
        let appSupport = ProcessInfo.processInfo.environment["AGENTLOOP_STATE_DIR"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AgentLoop")
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            stateDirectoryLock = try StateDirectoryLock(directoryURL: appSupport)
        } catch {
            fatalError("AgentLoop 状态目录初始化失败：\(error.localizedDescription)")
        }
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        reportStoreRoot = appSupport.appendingPathComponent("reports")
        let database = try! AppDatabase(path: appSupport.appendingPathComponent("agentloop.sqlite").path)
        db = database
        do {
            let initialMode = try database.dispatchMode()
            let initiallyHalted = initialMode == .halted
            campHalted = initiallyHalted
            haltRestoredFromPreviousSession = initiallyHalted
        } catch {
            // 读取不出持久化门时必须 fail-closed，不得在第一帧短暂显示为可运行。
            campHalted = true
            haltErrorMessage = "无法确认上次的收哨状态。为安全起见，全部行动保持暂停：\(error.localizedDescription)"
        }
        let defaultBaseURL = Self.defaultBaseURL
        // M8-D5：MCP 敏感 env 从 Keychain 解析（account mcp-<serverId>-<key>）；预览模式不读钥匙串
        let isPreview = ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] == "1"
        kernelStartupRecoveryPending = !isPreview
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
                let credential = Self.storedProviderCredential(using: keychainStore)
                let rawBase = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
                let base = ProviderEndpoint.normalizedBaseURL(rawBase) ?? URL(string: defaultBaseURL)!
                let format = ProviderAPIFormat(
                    rawValue: UserDefaults.standard.string(forKey: "apiFormat") ?? ""
                ) ?? .anthropicMessages
                return Self.makeProvider(
                    credential: credential,
                    format: format,
                    model: model,
                    baseURL: base,
                    tokenRefresher: Self.tokenRefresher(for: openAISession)
                )
            },
            artifactStoreRoot: artifactStoreRoot,
            searchKeyProvider: {
                // M6-D7/D8：无 key（或预览模式）→ web_search 不装配
                guard ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] != "1",
                      let key = try? keychainStore.get(account: "tavily-api-key"),
                      !key.isEmpty else { return nil }
                return key
            },
            mcpManager: mcpManager,
            requiresStartupRecovery: !isPreview
        )
        try! db.ensureCodingRanchBootstrap()
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
        startKernelEventListener(recoverKernel: !Self.isUIPreview)
        // UI 预览模式（开发用）：不做启动领养调度，避免预览时真实派发与钥匙串弹窗
        reloginHandler.store = self
    }

    /// 环境变量 AGENTLOOP_UI_PREVIEW=1 时为 UI 预览模式：不读钥匙串、不调度任务
    static let isUIPreview = ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] == "1"
    /// 预览直达（截图循环用）：启动即打开指定行动，可选直接进小剧场
    static let previewMissionId = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_MISSION"]
    static let previewTheater = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_THEATER"] == "1"

    nonisolated private static func nonEmptyCredential(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    nonisolated private static func storedProviderCredential(using keychain: KeychainStore) -> StoredCredential? {
        let preferred = ProviderCredentialSource(
            rawValue: UserDefaults.standard.string(forKey: preferredCredentialSourceKey) ?? ""
        ) ?? .apiKey
        let apiKey = nonEmptyCredential(try? keychain.get(account: apiKeyAccount))
        let chatGPTAccountID = nonEmptyCredential(try? keychain.get(account: oauthChatGPTAccountIDAccount))
        let format = ProviderAPIFormat(
            rawValue: UserDefaults.standard.string(forKey: "apiFormat") ?? ""
        ) ?? .anthropicMessages
        let rawOAuthToken = nonEmptyCredential(try? keychain.get(account: oauthAccessTokenAccount))
        let oauthToken = format == .openAIChatCompletions && chatGPTAccountID == nil
            ? nil
            : rawOAuthToken

        switch preferred {
        case .webLogin:
            if let oauthToken { return StoredCredential(value: oauthToken, source: .webLogin, chatGPTAccountID: chatGPTAccountID) }
            if let apiKey { return StoredCredential(value: apiKey, source: .apiKey, chatGPTAccountID: nil) }
        case .apiKey:
            if let apiKey { return StoredCredential(value: apiKey, source: .apiKey, chatGPTAccountID: nil) }
            if let oauthToken { return StoredCredential(value: oauthToken, source: .webLogin, chatGPTAccountID: chatGPTAccountID) }
        }
        return nil
    }

    nonisolated private static func makeProvider(
        credential: StoredCredential?,
        format: ProviderAPIFormat,
        model: String,
        baseURL: URL,
        tokenRefresher: (@Sendable () async throws -> String)? = nil
    ) -> any LLMProvider {
        if format == .openAIChatCompletions,
           credential?.source == .webLogin {
            return OpenAIResponsesProvider(
                accessToken: credential?.value ?? "",
                accountID: credential?.chatGPTAccountID ?? "",
                model: model,
                tokenRefresher: tokenRefresher
            )
        }
        return LLMProviderFactory.make(
            format: format,
            authScheme: credential?.authScheme ?? .automatic,
            credential: credential?.value ?? "",
            model: model,
            baseURL: baseURL
        )
    }

    nonisolated private static func tokenRefresher(
        for session: OpenAIOAuthSession?
    ) -> (@Sendable () async throws -> String)? {
        guard let session else { return nil }
        return {
            try await session.refreshedAccessToken()
        }
    }

    func reload() {
        companions = (try? db.regularCompanions()) ?? []
        camps = (try? db.camps()) ?? []
        apiKeyPresent = !Self.isUIPreview
            && Self.nonEmptyCredential(try? keychain.get(account: Self.apiKeyAccount)) != nil
        searchKeyPresent = Self.isUIPreview
            ? false
            : (((try? keychain.get(account: "tavily-api-key")) ?? nil).map { !$0.isEmpty } ?? false)
        let hasOAuthToken = Self.nonEmptyCredential(
            try? keychain.get(account: Self.oauthAccessTokenAccount)
        ) != nil
        let hasChatGPTAccount = Self.nonEmptyCredential(
            try? keychain.get(account: Self.oauthChatGPTAccountIDAccount)
        ) != nil
        webCredentialPresent = !Self.isUIPreview
            && hasOAuthToken
            && (apiFormat != .openAIChatCompletions || hasChatGPTAccount)
        reloadMissionList()
        reloadArtifactLedger()
    }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? keychain.set(trimmed, account: Self.apiKeyAccount)
        preferredCredentialSource = .apiKey
        oauthLoginStatus = nil
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

    func provider(model: String) -> (any LLMProvider)? {
        // 预览模式语义 = 不读钥匙串（避免系统授权弹窗）；LLM 动作统一得到「请先配置凭据」提示
        guard !Self.isUIPreview,
              let credential = Self.storedProviderCredential(using: keychain) else {
            return nil
        }
        let base = ProviderEndpoint.normalizedBaseURL(apiBaseURL)
            ?? URL(string: Self.defaultBaseURL)!
        return Self.makeProvider(
            credential: credential,
            format: apiFormat,
            model: model,
            baseURL: base,
            tokenRefresher: Self.tokenRefresher(for: openAIOAuthSession)
        )
    }

    func openProviderAuth() {
        guard apiBaseURLValid else {
            oauthLoginStatus = "请先填一个有效的 API 端点"
            return
        }
        if apiFormat == .openAIChatCompletions {
            guard let url = openAIAuthLoginURL() else {
                return
            }
            oauthLoginStatus = NSWorkspace.shared.open(url)
                ? "已在浏览器打开 OpenAI 登录页"
                : "无法打开浏览器"
            return
        }
        guard let url = providerAuthURL() else {
            oauthLoginStatus = "无法生成网页登录地址"
            return
        }
        oauthLoginStatus = NSWorkspace.shared.open(url)
            ? "已在浏览器打开登录页"
            : "无法打开浏览器"
    }

    func handleOAuthCallback(_ url: URL) {
        guard url.scheme?.lowercased() == "agentloop",
              url.host()?.lowercased() == "oauth" else { return }
        finishOAuthCallback(
            params: Self.callbackParameters(from: url),
            tokenEndpoint: oauthTokenEndpoint(),
            redirectURI: Self.genericOAuthRedirectURI,
            clientID: Self.genericOAuthClientID
        )
    }

    private func openAIAuthLoginURL() -> URL? {
        guard startOpenAIAuthCallbackListener() else { return nil }

        let state = Self.randomURLSafeString(byteCount: 24)
        let codeVerifier = Self.randomURLSafeString(byteCount: 32)
        UserDefaults.standard.set(state, forKey: Self.oauthStateKey)
        try? keychain.set(codeVerifier, account: Self.oauthCodeVerifierAccount)

        return OpenAIChatGPTAuth.authorizationURL(
            state: state,
            codeChallenge: Self.codeChallenge(for: codeVerifier)
        )
    }

    private func startOpenAIAuthCallbackListener() -> Bool {
        stopOpenAIAuthCallbackListener()
        guard let port = NWEndpoint.Port(rawValue: OpenAIChatGPTAuth.callbackPort) else {
            oauthLoginStatus = "OpenAI Auth 回调端口无效"
            return false
        }
        do {
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                let store = self
                connection.start(queue: Self.oauthCallbackQueue)
                Self.receiveOAuthCallback(connection: connection) { url in
                    Task { @MainActor in
                        store?.handleOpenAIAuthLocalCallback(url)
                    }
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    Task { @MainActor [weak self] in
                        self?.oauthLoginStatus = "OpenAI Auth 回调监听失败：\(error.localizedDescription)"
                        self?.stopOpenAIAuthCallbackListener()
                    }
                }
            }
            listener.start(queue: Self.oauthCallbackQueue)
            oauthCallbackListener = listener
            return true
        } catch {
            oauthLoginStatus = "OpenAI Auth 需要本机端口 1455，当前被占用（可能是 Codex CLI 或上次未完成的登录）；请关闭占用程序后重试"
            return false
        }
    }

    private func stopOpenAIAuthCallbackListener() {
        oauthCallbackListener?.cancel()
        oauthCallbackListener = nil
    }

    private func handleOpenAIAuthLocalCallback(_ url: URL) {
        finishOAuthCallback(
            params: Self.callbackParameters(from: url),
            tokenEndpoint: OpenAIChatGPTAuth.tokenEndpoint,
            redirectURI: OpenAIChatGPTAuth.redirectURI,
            clientID: OpenAIChatGPTAuth.clientID,
            requiresChatGPTAccountID: true
        )
    }

    private func finishOAuthCallback(
        params: [String: String],
        tokenEndpoint: URL?,
        redirectURI: String,
        clientID: String,
        requiresChatGPTAccountID: Bool = false
    ) {
        if let error = Self.nonEmptyCredential(params["error"]) {
            oauthLoginStatus = "网页登录失败：\(params["error_description"] ?? error)"
            stopOpenAIAuthCallbackListener()
            return
        }
        guard let expectedState = UserDefaults.standard.string(forKey: Self.oauthStateKey) else {
            oauthLoginStatus = "网页登录状态已过期，请重新授权"
            stopOpenAIAuthCallbackListener()
            return
        }
        guard params["state"] == expectedState else {
            oauthLoginStatus = "网页登录回调校验失败"
            stopOpenAIAuthCallbackListener()
            return
        }
        if let accessToken = Self.nonEmptyCredential(params["access_token"]) {
            saveWebCredential(accessToken: accessToken, refreshToken: params["refresh_token"])
            return
        }
        if let code = Self.nonEmptyCredential(params["code"]) {
            oauthLoginStatus = "已收到授权码，正在完成授权"
            Task {
                await exchangeOAuthCode(
                    code,
                    tokenEndpoint: tokenEndpoint,
                    redirectURI: redirectURI,
                    clientID: clientID,
                    requiresChatGPTAccountID: requiresChatGPTAccountID
                )
            }
            return
        }
        oauthLoginStatus = "网页登录没有返回可用凭据"
        stopOpenAIAuthCallbackListener()
    }

    private func providerAuthURL() -> URL? {
        guard let base = ProviderEndpoint.normalizedBaseURL(apiBaseURL),
              let host = base.host()?.lowercased() else { return nil }

        if host == "api.anthropic.com" {
            return URL(string: "https://console.anthropic.com/settings/keys")
        }
        if host == "api.openai.com" {
            return URL(string: "https://platform.openai.com/api-keys")
        }

        let state = Self.randomURLSafeString(byteCount: 24)
        let codeVerifier = Self.randomURLSafeString(byteCount: 32)
        UserDefaults.standard.set(state, forKey: Self.oauthStateKey)
        try? keychain.set(codeVerifier, account: Self.oauthCodeVerifierAccount)

        var components = URLComponents(
            url: base.appending(path: "oauth").appending(path: "authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.genericOAuthClientID),
            URLQueryItem(name: "redirect_uri", value: Self.genericOAuthRedirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components?.url
    }

    private func oauthTokenEndpoint() -> URL? {
        guard let base = ProviderEndpoint.normalizedBaseURL(apiBaseURL),
              let host = base.host()?.lowercased(),
              host != "api.anthropic.com",
              host != "api.openai.com" else { return nil }
        return base.appending(path: "oauth").appending(path: "token")
    }

    private func exchangeOAuthCode(
        _ code: String,
        tokenEndpoint: URL?,
        redirectURI: String,
        clientID: String,
        requiresChatGPTAccountID: Bool
    ) async {
        guard let endpoint = tokenEndpoint else {
            oauthLoginStatus = "服务方没有提供可自动换取 token 的 OAuth 入口"
            stopOpenAIAuthCallbackListener()
            return
        }
        guard let codeVerifier = Self.nonEmptyCredential(try? keychain.get(account: Self.oauthCodeVerifierAccount)) else {
            oauthLoginStatus = "网页登录状态已过期，请重新授权"
            stopOpenAIAuthCallbackListener()
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        let requestBody: Data? = clientID == OpenAIChatGPTAuth.clientID
            ? OpenAIChatGPTAuth.tokenRequestBody(code: code, codeVerifier: codeVerifier)
            : Self.formURLEncoded([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirectURI,
                "client_id": clientID,
                "code_verifier": codeVerifier,
            ])
        guard let requestBody else {
            oauthLoginStatus = "无法编码 OAuth 请求体"
            stopOpenAIAuthCallbackListener()
            return
        }
        request.httpBody = requestBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                let body = String(data: Data(data.prefix(240)), encoding: .utf8) ?? ""
                oauthLoginStatus = "OAuth 换 token 失败（HTTP \(status)）：\(body)"
                stopOpenAIAuthCallbackListener()
                return
            }
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let accessToken = Self.nonEmptyCredential(object?["access_token"] as? String) else {
                oauthLoginStatus = "OAuth 响应里没有 access_token"
                stopOpenAIAuthCallbackListener()
                return
            }
            let idToken = Self.nonEmptyCredential(object?["id_token"] as? String)
            let chatGPTAccountID = idToken.flatMap {
                OpenAIChatGPTAuth.chatGPTAccountID(idToken: $0, accessToken: accessToken)
            }
            if requiresChatGPTAccountID, chatGPTAccountID == nil {
                oauthLoginStatus = "OpenAI Auth 响应缺少 ChatGPT 账户信息，请重新授权"
                stopOpenAIAuthCallbackListener()
                return
            }
            saveWebCredential(
                accessToken: accessToken,
                refreshToken: object?["refresh_token"] as? String,
                idToken: idToken,
                chatGPTAccountID: chatGPTAccountID
            )
        } catch {
            oauthLoginStatus = "OAuth 换 token 失败：\(readableError(error))"
            stopOpenAIAuthCallbackListener()
        }
    }

    private func saveWebCredential(
        accessToken: String,
        refreshToken: String?,
        idToken: String? = nil,
        chatGPTAccountID: String? = nil
    ) {
        try? keychain.set(accessToken, account: Self.oauthAccessTokenAccount)
        if let refreshToken = Self.nonEmptyCredential(refreshToken) {
            try? keychain.set(refreshToken, account: Self.oauthRefreshTokenAccount)
        }
        if let idToken = Self.nonEmptyCredential(idToken) {
            try? keychain.set(idToken, account: Self.oauthIDTokenAccount)
        } else {
            try? keychain.delete(account: Self.oauthIDTokenAccount)
        }
        if let chatGPTAccountID = Self.nonEmptyCredential(chatGPTAccountID) {
            try? keychain.set(chatGPTAccountID, account: Self.oauthChatGPTAccountIDAccount)
        } else {
            try? keychain.delete(account: Self.oauthChatGPTAccountIDAccount)
        }
        try? keychain.delete(account: Self.oauthCodeVerifierAccount)
        UserDefaults.standard.removeObject(forKey: Self.oauthStateKey)
        preferredCredentialSource = .webLogin
        oauthNeedsRelogin = false
        oauthLoginStatus = "网页登录授权已完成"
        stopOpenAIAuthCallbackListener()
        reload()
    }

    nonisolated private static func callbackParameters(from url: URL) -> [String: String] {
        var result: [String: String] = [:]
        func collect(_ items: [URLQueryItem]?) {
            for item in items ?? [] {
                if let value = item.value {
                    result[item.name] = value
                }
            }
        }
        collect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        if let fragment = url.fragment, !fragment.isEmpty {
            collect(URLComponents(string: "agentloop://oauth/callback?\(fragment)")?.queryItems)
        }
        return result
    }

    nonisolated private static func receiveOAuthCallback(
        connection: NWConnection,
        onCallback: @escaping @Sendable (URL) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let target = Self.httpRequestTarget(from: request),
                  let url = URL(string: "http://localhost:\(OpenAIChatGPTAuth.callbackPort)\(target)") else {
                Self.respondToOAuthCallback(connection: connection, ok: false)
                return
            }
            onCallback(url)
            Self.respondToOAuthCallback(connection: connection, ok: true)
        }
    }

    nonisolated private static func httpRequestTarget(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              parts[0] == "GET",
              parts[1].hasPrefix("/auth/callback") else { return nil }
        return String(parts[1])
    }

    nonisolated private static func respondToOAuthCallback(connection: NWConnection, ok: Bool) {
        let title = ok ? "Coding 牧场登录完成" : "Coding 牧场登录失败"
        let message = ok ? "可以回到 Coding 牧场继续了。" : "Coding 牧场没有识别这次登录回调，请重新授权。"
        let body = """
        <!doctype html>
        <html>
        <head><meta charset="utf-8"><title>\(title)</title></head>
        <body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:32px">
        <h2>\(title)</h2>
        <p>\(message)</p>
        </body>
        </html>
        """
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(ok ? "200 OK" : "400 Bad Request")\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        var response = Data(header.utf8)
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    nonisolated private static func formURLEncoded(_ values: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = values
            .sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
        return Data(pairs.joined(separator: "&").utf8)
    }

    nonisolated private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, byteCount, $0.baseAddress!)
        }
        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64URLEncodedString()
    }

    nonisolated private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    func startMission(goal: String, companionIds: [String], workspacePath: String?, campId: String? = nil,
                      autonomy: MissionAutonomy? = nil) {
        guard !missionStartBlocked else {
            missionPhase = .error(missionStartBlockMessage)
            showToast(missionStartBlockMessage)
            return
        }
        guard Self.storedProviderCredential(using: keychain) != nil else {
            missionPhase = .error("请先在设置里保存 API Key 或网页登录授权")
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
                reloadArtifactLedger()
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

    func returnCardForRework(cardId: String, feedback: String) async -> String? {
        do {
            try await orchestrator.returnCardForRework(cardId: cardId, feedback: feedback)
            if let currentMissionId {
                reloadMission(missionId: currentMissionId)
            }
            reloadMissionList()
            reloadArtifactLedger()
            showToast("已退回重做")
            return nil
        } catch {
            return readableError(error)
        }
    }

    func clearCardReviewFlag(cardId: String) {
        do {
            try db.clearCardReviewFlag(cardId: cardId)
            if let currentMissionId {
                reloadMission(missionId: currentMissionId)
            }
            reloadMissionList()
            showToast("已标记为复核过")
        } catch {
            showToast("清除复核标记失败：\(readableError(error))")
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

    private func startKernelEventListener(recoverKernel: Bool) {
        kernelEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = await orchestrator.events()
            if recoverKernel {
                // Subscribe before recovery so fail-closed startup events cannot race
                // past the UI listener. AsyncStream buffers events until this loop starts.
                await orchestrator.recoverAndReconcile()
                campHalted = await orchestrator.isHalted
                kernelStartupRecoveryPending = false
            }
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
            // Action-layer typed errors are more actionable than the parallel
            // diagnostic event. Preserve whichever classified message won first.
            if missionId.isEmpty && campHalted && haltErrorMessage == nil {
                haltErrorMessage = message
            }
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
            if !halted {
                haltRestoredFromPreviousSession = false
                haltPersistencePending = false
                haltErrorMessage = nil
            }
            reloadMissionList()
            if let currentMissionId { reloadMission(missionId: currentMissionId) }
        }
    }

    // MARK: 哨卡动作（M7-D5/D2/D7）

    func emergencyStopCamp() {
        guard canRequestEmergencyStop else { return }
        haltOperationState = .stopping
        haltRestoredFromPreviousSession = false
        haltErrorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            defer { haltOperationState = .idle }
            do {
                try await orchestrator.emergencyStop()
                campHalted = true
                haltPersistencePending = false
                haltErrorMessage = nil
                showToast("全部行动已暂停")
            } catch {
                // Core 保证持久化或规划收口失败也会停掉当前进程内的行动工作。
                campHalted = true
                haltPersistencePending = error is HaltPersistenceError
                haltErrorMessage = readableError(error)
                showToast(haltPersistencePending
                          ? "当前行动工作已停止，但收哨状态未能保存"
                          : "当前行动工作已停止，但安全收口未完成")
            }
            reloadMissionList()
            if let currentMissionId { reloadMission(missionId: currentMissionId) }
        }
    }

    func resumeCamp() {
        guard campHalted, haltOperationState == .idle else { return }
        haltOperationState = .resuming
        haltErrorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            defer { haltOperationState = .idle }
            do {
                try await orchestrator.resume()
                campHalted = false
                haltRestoredFromPreviousSession = false
                haltPersistencePending = false
                haltErrorMessage = nil
                showToast("全部行动已恢复")
            } catch {
                campHalted = true
                haltErrorMessage = "恢复失败，全部行动仍保持暂停，没有启动新的行动工作：\(readableError(error))"
                showToast("恢复失败，全部行动仍保持暂停")
            }
            reloadMissionList()
            if let currentMissionId { reloadMission(missionId: currentMissionId) }
        }
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
        let activeCampId: String
        if let campId {
            activeCampId = campId
        } else if let camp = try? db.ensureDefaultCamp() {
            campId = camp.id
            campName = camp.name
            activeCampId = camp.id
        } else {
            return
        }
        campNotes = (try? db.campNotes(campId: activeCampId)) ?? []
    }

    private func reloadMission(missionId: String, clearNotice: Bool = true) {
        guard let mission = try? db.mission(id: missionId) else { return }
        if clearNotice {
            feedNotice = nil
        }
        missionCards = (try? db.cards(missionId: missionId)) ?? []
        missionArtifacts = (try? db.missionArtifacts(missionId: missionId)) ?? []
        reloadArtifactLedger()
        pendingRequests = (try? db.pendingUserRequests(missionId: missionId)) ?? []
        let companionIds: [String]
        if let squad = try? db.squad(forMission: missionId),
           let ids = try? JSONDecoder().decode([String].self, from: Data(squad.memberIdsJson.utf8)),
           !ids.isEmpty {
            companionIds = ids
        } else {
            var seenAssigneeIds = Set<String>()
            companionIds = missionCards.compactMap(\.assigneeId).filter { seenAssigneeIds.insert($0).inserted }
        }
        let companions = (try? db.companions(ids: companionIds)) ?? []
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

    func reloadArtifactLedger(includeArchived: Bool? = nil) {
        if let includeArchived {
            artifactLedgerIncludeArchived = includeArchived
        }
        artifactLedgerItems = (try? db.artifactLedger(includeArchived: artifactLedgerIncludeArchived)) ?? []
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
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return String(describing: error)
    }

    private static func missionTitle(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        let firstLine = base.split(whereSeparator: \.isNewline).first.map(String.init) ?? base
        return firstLine.isEmpty ? "未命名行动" : String(firstLine.prefix(36))
    }

    func revealArtifact(_ artifact: ArtifactRecord) {
        revealPath(artifact.path)
    }

    func revealPath(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func openPath(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func reportURL(missionId: String) -> URL {
        reportStoreRoot.appendingPathComponent("\(missionId).md")
    }

    @discardableResult
    func ensureReport(missionId: String) -> URL? {
        let url = reportURL(missionId: missionId)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        do {
            let input = try db.expeditionReportInput(missionId: missionId)
            try FileManager.default.createDirectory(at: reportStoreRoot, withIntermediateDirectories: true)
            try ExpeditionReport.markdown(input).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            showToast("报告生成失败：\(readableError(error))")
            return nil
        }
    }

    func openReport(missionId: String) {
        guard let url = ensureReport(missionId: missionId) else { return }
        NSWorkspace.shared.open(url)
    }

    func revealReport(missionId: String) {
        guard let url = ensureReport(missionId: missionId) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 返回是否受理（未受理时调用方不应清空输入——UX 审计 P1：无 key 静默吞消息）
    @discardableResult
    func sendChat(companion: CompanionRecord, text: String) -> Bool {
        guard !text.isEmpty, !chatStreaming else {
            return false
        }
        guard let provider = provider(model: companion.model) else {
            showToast("请先在设置里保存 API Key 或网页登录授权")
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
        showToast("已停下营地管家这条回复")
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

    func setCampArchived(id: String, archived: Bool) {
        do {
            try db.setCampArchived(id: id, archived: archived)
            reload()
            showToast(archived ? "营地已归档" : "营地已恢复")
        } catch {
            showToast("营地状态修改失败：\(readableError(error))")
        }
    }

    func isCampArchived(id: String) throws -> Bool {
        guard let camp = try db.camp(id: id) else {
            throw RecordNotFoundError(table: "camp", id: id)
        }
        return camp.archived
    }

    private func canWriteCamp(id: String, archivedMessage: String) -> Bool {
        do {
            if try isCampArchived(id: id) {
                showToast(archivedMessage)
                return false
            }
            return true
        } catch {
            showToast("营地状态读取失败：\(readableError(error))")
            return false
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
        guard canWriteCamp(id: campId, archivedMessage: "营地已归档,恢复后才能继续对话") else { return }
        guard let provider = provider(model: defaultModel) else {
            showToast("请先在设置里保存 API Key 或网页登录授权")
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
                    showToast("营地管家这会儿联系不上：\(readableError(error))")
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
        guard !missionStartBlocked else {
            showToast(missionStartBlockMessage)
            return
        }
        guard provider(model: defaultModel) != nil else {
            showToast("请先在设置里保存 API Key 或网页登录授权")
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
            showToast("请先在设置里保存 API Key 或网页登录授权")
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
        guard canWriteCamp(id: note.campId, archivedMessage: "营地已归档,恢复后才能编辑笔记") else { return }
        var updated = note
        updated.updatedAt = Date()
        do {
            try db.saveCampNote(updated)
            reloadCampKnowledge()
        } catch {
            showToast("笔记保存失败：\(readableError(error))")
        }
    }

    func deleteCampNote(id: String) {
        do {
            guard let note = try db.pool.read({ database in
                try CampNoteRecord.fetchOne(database, key: id)
            }) else {
                throw RecordNotFoundError(table: "camp_note", id: id)
            }
            guard canWriteCamp(id: note.campId, archivedMessage: "营地已归档,恢复后才能删除笔记") else { return }
            try db.deleteCampNote(id: id)
            reloadCampKnowledge()
        } catch {
            showToast("笔记删除失败：\(readableError(error))")
        }
    }

    func toggleCampNotePin(_ note: CampNoteRecord) {
        guard canWriteCamp(id: note.campId, archivedMessage: "营地已归档,恢复后才能编辑笔记") else { return }
        var updated = note
        updated.pinned.toggle()
        updated.updatedAt = Date()
        do {
            try db.saveCampNote(updated)
            reloadCampKnowledge()
        } catch {
            showToast("笔记保存失败：\(readableError(error))")
        }
    }

    // MARK: - 伙伴记忆（M4）

    func reloadMemoryNotes(companionId: String) {
        memoryNotes = (try? db.companionNotes(companionId: companionId)) ?? []
    }

    func distillMemoryNow(companion: CompanionRecord) {
        guard !distillingMemory else { return }
        guard let provider = provider(model: effectiveDistillModel) else {
            showToast("请先在设置里保存 API Key 或网页登录授权")
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
        case "search_camp_notes": return "营地管家翻了翻笔记本…"
        case "camp_status": return "营地管家看了看营地各处…"
        case "propose_squad": return "营地管家在拟组队提案…"
        default: return "营地管家在忙…"
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
