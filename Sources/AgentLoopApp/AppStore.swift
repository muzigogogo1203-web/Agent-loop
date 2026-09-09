import SwiftUI
import CryptoKit
import Network
import Security
import AgentLoopCore
import AgentLoopApplication
import GRDB

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

private final class RuntimeProfileResolutionFailureHandler: @unchecked Sendable {
    @MainActor weak var store: AppStore?

    func report(_ message: String) {
        Task { @MainActor [weak self] in
            self?.store?.showToast(message)
        }
    }
}

private struct CredentialPresenceSnapshot: Sendable {
    let apiKeyPresent: Bool
    let searchKeyPresent: Bool
    let oauthAccessTokenPresent: Bool
    let chatGPTAccountIDPresent: Bool
}

/// Preview-only defaults whose currently used read/write surface stays in memory.
///
/// `ProfileScopedDefaults` accepts `UserDefaults`, so a process-local subclass
/// keeps the preview dependency injectable without changing the Core contract.
/// Its unique superclass suite never selects the normal app domain, and every
/// API currently used by AppStore/Core is overridden onto the locked dictionary.
private final class ProcessLocalPreviewUserDefaults:
    UserDefaults,
    @unchecked Sendable
{
    private let valuesLock = NSLock()
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        valuesLock.withLock { values[defaultName] }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        valuesLock.withLock {
            values[defaultName] = value
        }
    }

    override func set(_ value: Int, forKey defaultName: String) {
        set(NSNumber(value: value), forKey: defaultName)
    }

    override func set(_ value: Float, forKey defaultName: String) {
        set(NSNumber(value: value), forKey: defaultName)
    }

    override func set(_ value: Double, forKey defaultName: String) {
        set(NSNumber(value: value), forKey: defaultName)
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        set(NSNumber(value: value), forKey: defaultName)
    }

    override func set(_ url: URL?, forKey defaultName: String) {
        set(url as Any?, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        set(nil, forKey: defaultName)
    }

    override func string(forKey defaultName: String) -> String? {
        switch object(forKey: defaultName) {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    override func integer(forKey defaultName: String) -> Int {
        switch object(forKey: defaultName) {
        case let value as NSNumber:
            return value.intValue
        case let value as NSString:
            return value.integerValue
        default:
            return 0
        }
    }

    override func bool(forKey defaultName: String) -> Bool {
        switch object(forKey: defaultName) {
        case let value as NSNumber:
            return value.boolValue
        case let value as NSString:
            return value.boolValue
        default:
            return false
        }
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        object(forKey: defaultName) as? [String]
    }
}

private struct AppPlanningRuntimeProfileSource:
    PlanningRuntimeProfileSource, Sendable
{
    let db: AppDatabase

    package func planningRuntimeProfile(
        id: String
    ) throws -> RuntimeProfileRecord? {
        try db.runtimeProfile(id: id)
    }
}

private struct AppPlanningModelCatalogSource:
    PlanningModelCatalogSource, Sendable
{
    let defaults: ProfileScopedDefaults

    package func planningCachedCatalog(
        profileId: String
    ) throws -> [String]? {
        defaults.cachedCatalog(profileID: profileId)
    }

    package func planningModelChoices(
        profileId: String
    ) throws -> [String]? {
        defaults.stringArray(
            profileID: profileId,
            suffix: "modelChoices"
        )
    }

    package func planningManualModels(
        profileId: String
    ) throws -> [String] {
        defaults.manualModels(profileID: profileId)
    }
}

private struct AppPlanningCredentialSource:
    PlanningCredentialSource, Sendable
{
    let keychain: KeychainStore

    package func planningCredential(account: String) throws -> String? {
        try keychain.get(
            account: account,
            interactionPolicy: .failIfInteractionRequired
        )
    }
}

private struct AppPlanningProviderFactory:
    PlanningProviderFactory, Sendable
{
    let tokenRefresher: (@Sendable () async throws -> String)?

    package func makePlanningAPIProvider(
        format: ProviderAPIFormat,
        credential: String,
        model: String,
        baseURL: URL
    ) throws -> any LLMProvider {
        LLMProviderFactory.make(
            format: format,
            authScheme: .automatic,
            credential: credential,
            model: model,
            baseURL: baseURL
        )
    }

    package func makePlanningOAuthProvider(
        accessToken: String,
        accountId: String,
        model: String
    ) throws -> any LLMProvider {
        OpenAIResponsesProvider(
            accessToken: accessToken,
            accountID: accountId,
            model: model,
            tokenRefresher: tokenRefresher
        )
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

    private let userDefaults: UserDefaults
    private let stateDirectoryLock: StateDirectoryLock
    private let engineRuntimeDirectories:
        EngineRuntimeDirectoryAuthoritySetV1
    private let engineExecutionEnvironment: EngineExecutionEnvironmentV1
    let db: AppDatabase
    let keychain: KeychainStore
    private let openAIOAuthSession: OpenAIOAuthSession?
    let artifactStoreRoot: URL
    let reportStoreRoot: URL
    private let reportStore: ManagedExpeditionReportStore
    let externalOperationWorkflow: ExternalOperationWorkflowCoordinator
    let orchestrator: Orchestrator
    let inputWorkflowController: InputWorkflowController
    let missionWorkflowController: MissionWorkflowController
    let planningEntryCoordinator: PlanningEntryCoordinator
    let scheduledMissionNotifier: ScheduledMissionNotifier
    let missionScheduler: MissionScheduler
    /// MCP 驿站（M8-D8：绞杀第二刀，领域状态独立成 store）
    let mcp: McpStore
    var globalVisibleFailure: UserVisibleFailure?
    var inputCampProjectionByCampId:
        [String: WorkflowProjection<InputCampSnapshot>] = [:]
    var inputReviewProjectionByIngestionId:
        [String: WorkflowProjection<InputReviewSnapshot>] = [:]
    var missionIndexProjection = WorkflowProjection<MissionIndexSnapshot>()
    var missionDetailProjectionByMissionId:
        [String: WorkflowProjection<MissionDetailSnapshot>] = [:]
    var runtimeProjection: WorkflowProjection<RuntimeWorkflowSnapshot>
    private(set) var codingRanchBootstrapState:
        WorkflowLoadState<CodingRanchBootstrapResult>
    private var applicationStartupGate: ApplicationStartupGate
    private let synchronousRuntimeBootstrap: SynchronousRuntimeBootstrap
    private let runtimeBootstrapRequest: RuntimeBootstrapRequest
    private let codingRanchBootstrapBoundary:
        ApplicationPostDatabaseBootstrapBoundary
    private let productBootstrapService: ProductBootstrapService
    private let failureReporter: FailureReporter

    var companions: [CompanionRecord] = []
    /// 营地=频道（M5-0）：全部营地，创建序
    var camps: [CampRecord] = []
    /// 侧栏用：各营地的行动列表（含历史，UI 侧再分组）
    var missionsByCamp: [String: [MissionRecord]] = [:]
    var codingRanchDashboard: CampDashboardViewState?
    var codingRanchInbox = RuminationInboxViewState(loadState: .idle, items: [])
    var ruminationActionError: String?
    var ruminationActionInFlightIds: Set<String> = []
    var pendingIngestionDeletion: PendingIngestionDeletionViewState?
    var apiKeyPresent = false
    var webCredentialPresent = false
    var credentialAccessInProgress = false
    var credentialAccessError: String?
    var runtimeProfiles: [RuntimeProfileRecord] = []
    var currentRuntimeProfile: RuntimeProfileRecord?
    var preferredCredentialSource: ProviderCredentialSource = .apiKey {
        didSet {
            userDefaults.set(
                preferredCredentialSource.rawValue,
                forKey: "preferredCredentialSource"
            )
        }
    }
    var oauthLoginStatus: String?
    var oauthNeedsRelogin = false
    /// M6-D8：Tavily key 在场与否决定 web_search 是否可用（编辑器置灰提示用）
    var searchKeyPresent = false
    /// M6-D11：默认模型持久化（修「重启复位」bug）
    var defaultModel = "claude-sonnet-4-6" {
        didSet { persistProfileString(defaultModel, suffix: "defaultModel") }
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
    var modelChoices: [String] = AppStore.factoryModelChoices
    private(set) var removableCatalogModels: Set<String> = []
    /// M6-D12：轻任务模型（空 = 跟随默认模型）——蒸馏与规划是最便宜的降档位
    var distillModel: String = "" {
        didSet { persistProfileString(distillModel, suffix: "distillModel") }
    }
    var plannerModel: String = "" {
        didSet { persistProfileString(plannerModel, suffix: "plannerModel") }
    }
    var effectiveDistillModel: String { distillModel.isEmpty ? defaultModel : distillModel }
    var effectivePlannerModel: String { plannerModel.isEmpty ? defaultModel : plannerModel }

    func planningRuntimeSelection() throws -> PlanningEntryRuntimeSelection {
        try Self.scheduledPlanningRuntimeSelection(
            database: db,
            defaults: profileScopedDefaults
        )
    }

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
    var pendingScheduleCatchups: [ScheduleCatchup] = []
    struct LiveRuminationPhase: Sendable, Equatable {
        let identity: RuminationPhaseIdentity
        let phase: RuminationPhase
    }

    /// 反刍真实阶段与 durable identity 的进程内 overlay。
    var ruminationPhases:
        [String: LiveRuminationPhase] = [:]
    var codingRanchReadyCampIds: Set<String> = []
    var codingRanchIngestionCampIds: [String: String] = [:]
    var codingRanchInboxCache:
        [String: RuminationInboxViewState] = [:]
    var codingRanchDashboardCache:
        [String: CampDashboardViewState] = [:]
    private var inputCampTaskByCampId:
        [String: Task<Void, Never>] = [:]
    private var inputReviewTaskByIngestionId:
        [String: Task<Void, Never>] = [:]
    private var missionIndexTask: Task<Void, Never>?
    private var missionDetailTaskByMissionId:
        [String: Task<Void, Never>] = [:]
    /// 设置页「测试连接」状态文案
    var modelConnectionTestStatus: String?

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
        didSet {
            userDefaults.set(
                defaultAutonomy.rawValue,
                forKey: "defaultAutonomy"
            )
        }
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

    nonisolated private static let apiKeyAccount = RuntimeProfileBootstrap.apiKeyCredentialAccount
    nonisolated private static let oauthAccessTokenAccount = RuntimeProfileBootstrap.oauthAccessTokenCredentialAccount
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
        didSet {
            userDefaults.set(
                defaultMissionBudget,
                forKey: "defaultMissionBudget"
            )
        }
    }

    nonisolated static let defaultBaseURL = RuntimeProfileBootstrap.defaultAnthropicBaseURL
    var apiBaseURL: String = AppStore.defaultBaseURL {
        didSet { userDefaults.set(apiBaseURL, forKey: "apiBaseURL") }
    }
    var apiFormat: ProviderAPIFormat = .anthropicMessages {
        didSet { userDefaults.set(apiFormat.rawValue, forKey: "apiFormat") }
    }
    var apiAuthScheme: ProviderAuthScheme = .automatic {
        didSet {
            userDefaults.set(
                apiAuthScheme.rawValue,
                forKey: "apiAuthScheme"
            )
        }
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
    var returnAcceptanceError: String?
    private var viewedReturnArtifactIDs: Set<String> = []
    private var missionTask: Task<Void, Never>?
    private var pendingManualMissionStart: PendingManualMissionStart?
    private var kernelEventsTask: Task<Void, Never>?
    private var oauthCallbackListener: NWListener?
    private var sentScheduledMissionNotifications: Set<String> = []
    private var scheduledMissionOutcomeInFlight: Set<String> = []
    private enum ScheduleMutationKey: Hashable {
        case template(String)
        case schedule(String)
    }
    private struct SchedulePostCommitRepairCarrier {
        let generation: UInt64
        let identity: ScheduleMutationCommittedIdentity
        let receipt: SchedulePostCommitRepairReceipt
    }
    private var scheduleMutationGenerationByKey:
        [ScheduleMutationKey: UInt64] = [:]
    private var schedulePostCommitRepairByKey:
        [ScheduleMutationKey: SchedulePostCommitRepairCarrier] = [:]
    private enum ScheduleCommandFlightPurpose: Equatable {
        case mutation
        case repair(startingReceipt: SchedulePostCommitRepairReceipt)
    }
    private struct ScheduleCommandFlight {
        let attempt: UUID
        let generation: UInt64
        let purpose: ScheduleCommandFlightPurpose
        let task: Task<Void, Never>
    }
    private var scheduleCommandFlightByKey:
        [ScheduleMutationKey: ScheduleCommandFlight] = [:]
    @MainActor private final class ScheduleCommandCompletion {
        var committed = false
    }
    private var scheduleTemplateRecordById:
        [String: MissionTemplateRecord] = [:]
    private var scheduleRecordById: [String: ScheduleRecord] = [:]
    private var scheduleAuthorizationEvidence: ScheduleAuthorizationReceipt?
    private var scheduleRegistrationEvidence: ScheduleRegistrationReceipt?
    private var scheduleMenuTitle = "下次日程：暂无"
    private let operationTraceFactory = OperationTraceFactory.live

    /// 新行动表单草稿（按营地暂存，防切页丢输入——UX 审计 P2）
    struct MissionDraft {
        var goal = ""
        var workspace = ""
        var companionIds: [String] = []
    }
    var missionDrafts: [String: MissionDraft] = [:]

    var chatMessages: [(role: String, text: String)] = []
    var chatStreaming = false
    private var chatCompanionId: String?
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
    private var memoryKnowledgeProjection =
        MemoryKnowledgeProjectionCoordinator()
    var campNotes: [CampNoteRecord] {
        memoryKnowledgeProjection.visibleCampNotes
    }
    var campNotesState: WorkflowLoadState<[CampNoteRecord]> {
        memoryKnowledgeProjection.visibleCampState
    }
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
    private var campHomeLoadID = 0
    private var toastTask: Task<Void, Never>?

    // MARK: DM 记忆（M4）

    var memoryNotes: [CompanionNoteRecord] {
        memoryKnowledgeProjection.visibleMemoryNotes
    }
    var memoryNotesState: WorkflowLoadState<[CompanionNoteRecord]> {
        memoryKnowledgeProjection.visibleMemoryState
    }
    var memoryDistillationVisibilityCards:
        [MemoryDistillationVisibilityCard]
    {
        memoryKnowledgeProjection.visibilityCards
    }
    var memoryDrawerVisible = false
    var distillingMemory = false
    /// 切走沉淀的在途防重（快速来回切换时避免同一增量重复送蒸）
    private var autoDistillInFlight: Set<String> = []

    init() {
        let appDefaults = Self.makeUserDefaults()
        userDefaults = appDefaults
        let keychainStore = KeychainStore()
        let reloginHandler = OpenAIOAuthReloginHandler()
        let runtimeProfileFailureHandler = RuntimeProfileResolutionFailureHandler()
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
        let initialAPIFormat = ProviderAPIFormat(
            rawValue: appDefaults.string(forKey: "apiFormat") ?? ""
        ) ?? .anthropicMessages
        apiFormat = initialAPIFormat
        apiAuthScheme = .automatic
        appDefaults.set(
            ProviderAuthScheme.automatic.rawValue,
            forKey: "apiAuthScheme"
        )
        let initialPreferredCredentialSource = ProviderCredentialSource(
            rawValue: appDefaults.string(
                forKey: Self.preferredCredentialSourceKey
            ) ?? ""
        ) ?? .apiKey
        preferredCredentialSource = initialPreferredCredentialSource
        // 开发用状态目录覆盖（UI 预览时指向临时库，避免污染真实数据）
        let appSupport = ProcessInfo.processInfo.environment["AGENTLOOP_STATE_DIR"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AgentLoop")
        let processInspector = DarwinEngineRuntimeProcessInspectorV1()
        let lockedStateDirectory: StateDirectoryLock
        let runtimeDirectories: EngineRuntimeDirectoryAuthoritySetV1
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            lockedStateDirectory = try StateDirectoryLock(
                directoryURL: appSupport
            )
            runtimeDirectories = try EngineRuntimeDirectoryBootstrapV1
                .prepareBeforeDatabase(
                    stateDirectoryLock: lockedStateDirectory,
                    processInspector: processInspector
                )
        } catch {
            fatalError("AgentLoop 状态目录初始化失败：\(error.localizedDescription)")
        }
        stateDirectoryLock = lockedStateDirectory
        engineRuntimeDirectories = runtimeDirectories
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        let managedReportRoot = appSupport.appendingPathComponent("reports")
        reportStoreRoot = managedReportRoot
        let database: AppDatabase
        do {
            database = try AppDatabase(
                path: appSupport.appendingPathComponent("agentloop.sqlite").path
            )
        } catch {
            fatalError(
                "AgentLoop 数据库初始化失败：\(String(describing: error))"
            )
        }
        db = database
        let managedReportStore = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: managedReportRoot
        )
        do {
            try managedReportStore.recoverPendingWrites()
        } catch {
            fatalError(
                "远征报告恢复失败，应用已停止启动以保留恢复证据：\(String(describing: error))"
            )
        }
        reportStore = managedReportStore
        let externalCoordinator = ExternalOperationWorkflowCoordinator(
            store: ApprovalGrantStore(database: database)
        )
        externalOperationWorkflow = externalCoordinator
        let scopedDefaults = ProfileScopedDefaults(defaults: appDefaults)
        let defaultBaseURL = Self.defaultBaseURL
        let initialAPIBaseURL =
            appDefaults.string(forKey: "apiBaseURL")
            ?? defaultBaseURL
        let reporter = FailureReporter(database: database)
        failureReporter = reporter
        let runtimeResolver = RuntimeCredentialResolver(
            database: database,
            defaults: scopedDefaults,
            credentialAccess: SynchronizedCredentialAccess(
                store: keychainStore
            ),
            accounts: RuntimeCredentialAccounts(
                apiKey: Self.apiKeyAccount,
                searchKey: "tavily-api-key",
                oauth: .live
            ),
            defaultBaseURL: defaultBaseURL,
            tokenRefresher: Self.tokenRefresher(for: openAISession)
        )
#if DEBUG
        let runtimePresence: RuntimeCredentialPresencePort =
            Self.isUIPreview
            ? .preview(
                RuntimeCredentialPresence(
                    apiKeyPresent: false,
                    searchKeyPresent: false,
                    oauthAccessTokenPresent: false,
                    chatGPTAccountIdPresent: false
                )
            )
            : .live(resolver: runtimeResolver)
#else
        let runtimePresence = RuntimeCredentialPresencePort.live(
            resolver: runtimeResolver
        )
#endif
        let localRuntimeBootstrap = SynchronousRuntimeBootstrap(
            database: database,
            defaults: scopedDefaults,
            resolver: runtimeResolver,
            reporter: reporter,
            presence: runtimePresence
        )
        let localRuntimeRequest = RuntimeBootstrapRequest(
            apiFormat: initialAPIFormat,
            apiBaseURL: initialAPIBaseURL,
            preferredSource: initialPreferredCredentialSource,
            fallbackModelChoices: Self.factoryModelChoices,
            interactionPolicy: .failIfInteractionRequired
        )
        let runtimeTrace = OperationTraceFactory.live.generated(
            operation: .runtimeBootstrap,
            scope: .fixed(.runtimeBootstrap)
        )
        let localRuntimeResult = captureSynchronous(
            reporter: reporter,
            trace: runtimeTrace
        ) {
            try localRuntimeBootstrap.run(
                localRuntimeRequest,
                trace: runtimeTrace
            )
        }
        let localRuntimeProjection = WorkflowProjection(
            initial: localRuntimeResult
        )
        let localRanchBoundary =
            ApplicationPostDatabaseBootstrapBoundary(reporter: reporter)
        let localProductBootstrap = ProductBootstrapService(db: database)
        let ranchTrace = OperationTraceFactory.live.generated(
            operation: .applicationBootstrap,
            scope: .fixed(.application)
        )
        let localRanchOutcome = localRanchBoundary
            .ensureCodingRanchBootstrap(trace: ranchTrace) {
                try localProductBootstrap.ensureBootstrap()
            }
        let localRanchProjection = Self.codingRanchBootstrapProjection(
            localRanchOutcome
        )
        let localStartupGate = ApplicationStartupGate(
            runtime: localRuntimeProjection.state,
            codingRanch: localRanchProjection.state
        )
        let localRuntimeFailure: UserVisibleFailure?
        switch localRuntimeResult {
        case .value:
            localRuntimeFailure = nil
        case .failed(let failure):
            localRuntimeFailure = failure
        }
        synchronousRuntimeBootstrap = localRuntimeBootstrap
        runtimeBootstrapRequest = localRuntimeRequest
        runtimeProjection = localRuntimeProjection
        codingRanchBootstrapBoundary = localRanchBoundary
        productBootstrapService = localProductBootstrap
        codingRanchBootstrapState = localRanchProjection.state
        applicationStartupGate = localStartupGate
        globalVisibleFailure =
            localRanchProjection.visibilityFailure ?? localRuntimeFailure
        switch localRuntimeResult {
        case .value(let snapshot):
            runtimeProfiles = snapshot.profiles
            currentRuntimeProfile = snapshot.defaultProfile
            companions = snapshot.companions
            camps = snapshot.camps
            apiKeyPresent = snapshot.credentials.apiKeyPresent
            searchKeyPresent = snapshot.credentials.searchKeyPresent
            webCredentialPresent =
                snapshot.credentials.oauthAccessTokenPresent
                && (
                    initialAPIFormat != .openAIChatCompletions
                    || snapshot.credentials.chatGPTAccountIdPresent
                )
        case .failed:
            break
        }
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
        let dependencyLoader = ContextDependencyLoader(
            database: database,
            manager: mcpManager,
            reporter: reporter,
            searchCredential: {
                guard !isPreview else { return nil }
                return try keychainStore.get(
                    account: "tavily-api-key",
                    interactionPolicy: .failIfInteractionRequired
                )
            },
            knowledge: .live(database: database),
            makeTrace: { operation, scope in
                OperationTraceFactory.live.generated(
                    operation: operation,
                    scope: scope
                )
            }
        )
        let providerTokenRefresher = Self.tokenRefresher(
            for: openAISession
        )
        let helpProbe = CliHelpProbeV1(
            processInspector: processInspector
        )
        let packagedBridgeExecutablePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/AgentLoopBoardBridge")
            .path
        let engineEnvironment: EngineExecutionEnvironmentV1
        do {
            engineEnvironment = try EngineExecutionEnvironmentV1(
                database: database,
                stateDirectoryLock: lockedStateDirectory,
                artifactStoreRoot: artifactStoreRoot,
                bridgeExecutablePath: packagedBridgeExecutablePath,
                boardSocketDirectoryAuthority:
                    runtimeDirectories.boardSocketDirectoryAuthority,
                validateCodexManagedPolicy:
                    EngineCliManagedPolicyValidatorV1.codex(
                        processInspector: processInspector
                    ),
                validateClaudeManagedPolicy:
                    EngineCliManagedPolicyValidatorV1.claude(
                        processInspector: processInspector
                    ),
                claudeConfigDirectory:
                    runtimeDirectories.claudeConfigDirectory,
                cliExecutableDirectory:
                    runtimeDirectories.cliExecutableDirectory,
                processInspector: processInspector,
                dependencyLoader: dependencyLoader,
                resolveInitialModelLoopProvider: {
                    profile, companionId, companionModel, modelPolicy in
                    try Self.resolveInitialEngineProviderAuthority(
                        profile: profile,
                        companionId: companionId,
                        companionModel: companionModel,
                        modelPolicy: modelPolicy,
                        database: database,
                        defaults: scopedDefaults,
                        keychain: keychainStore,
                        defaultBaseURL: defaultBaseURL,
                        tokenRefresher: providerTokenRefresher
                    )
                },
                resolveRecoveryModelLoopProvider: {
                    profile, companionId, persistedModel in
                    try Self.resolveRecoveryEngineProviderAuthority(
                        profile: profile,
                        companionId: companionId,
                        persistedModel: persistedModel,
                        database: database,
                        defaults: scopedDefaults,
                        keychain: keychainStore,
                        defaultBaseURL: defaultBaseURL,
                        tokenRefresher: providerTokenRefresher
                    )
                },
                helpProbe: helpProbe,
                makeCliProcessDriver: {
                    try CliProcessBackend(
                        processInspector: processInspector
                    )
                },
                clock: { Date() }
            )
        } catch {
            fatalError(
                "AgentLoop 执行环境初始化失败：\(String(describing: error))"
            )
        }
        engineExecutionEnvironment = engineEnvironment
        mcp = McpStore(db: database, manager: mcpManager, keychain: keychainStore)
        let planningProviderResolver = StrictPlanningProviderResolver(
            profiles: AppPlanningRuntimeProfileSource(db: database),
            catalogs: AppPlanningModelCatalogSource(defaults: scopedDefaults),
            credentials: AppPlanningCredentialSource(keychain: keychainStore),
            factory: AppPlanningProviderFactory(
                tokenRefresher: Self.tokenRefresher(for: openAISession)
            )
        )
        let legacyRuminationSnapshot: LegacyRuminationStartupSnapshot
        switch localRuntimeResult {
        case .value(let snapshot):
            legacyRuminationSnapshot = snapshot.legacyRuminationSnapshot
        case .failed:
            legacyRuminationSnapshot = .legacyProfileUnresolved
        }
        let orchestratorInstance = Orchestrator(
            db: database,
            planningProviderResolver: planningProviderResolver,
            makeProvider: { model, companionId in
                Self.resolveProvider(
                    model: model,
                    companionId: companionId,
                    db: database,
                    defaults: scopedDefaults,
                    keychain: keychainStore,
                    defaultBaseURL: defaultBaseURL,
                    tokenRefresher: Self.tokenRefresher(for: openAISession),
                    reportFailure: { message in
                        runtimeProfileFailureHandler.report(message)
                    }
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
            externalOperationWorkflow: externalCoordinator,
            requiresStartupRecovery: !isPreview,
            legacyRuminationSnapshot:
                legacyRuminationSnapshot,
            contextDependencyLoader: dependencyLoader,
            reportStore: managedReportStore,
            engineEnvironment: engineEnvironment
        )
        orchestrator = orchestratorInstance
#if DEBUG
        let deletionPreviewScenario = Self.p1eDeletionPreviewScenario
        let activeIngestionDeletionPorts =
            InputActiveIngestionDeletionPorts.preview(
                database: database,
                checkpoint: deletionPreviewScenario
                    == .storeBeforeEvidenceFailure
                    ? .beforeEvidenceWrites
                    : nil,
                failCommittedRefreshOnce: deletionPreviewScenario
                    == .refreshAfterCommitOnce
            )
#else
        let activeIngestionDeletionPorts =
            InputActiveIngestionDeletionPorts.live(database: database)
#endif
        inputWorkflowController = InputWorkflowController(
            database: database,
            orchestrator: orchestratorInstance,
            resolver: runtimeResolver,
            reporter: reporter,
            activeIngestionDeletionPorts: activeIngestionDeletionPorts
        )
        let planningCoordinator = PlanningEntryCoordinator(
            db: database,
            orchestrator: orchestratorInstance
        )
        planningEntryCoordinator = planningCoordinator
        missionWorkflowController = MissionWorkflowController(
            database: database,
            orchestrator: orchestratorInstance,
            planningCoordinator: planningCoordinator,
            reportStoreRoot: reportStoreRoot,
            selectRuntime: {
                try AppStore.scheduledPlanningRuntimeSelection(
                    database: database,
                    defaults: scopedDefaults
                )
            },
            reporter: reporter,
            traceFactory: .live,
            registrationEvaluation: {
                ScheduleRegistrationEvaluation(
                    now: Date(),
                    timeZone: .current
                )
            },
            reportStore: managedReportStore
        )
        let notifier = ScheduledMissionNotifier()
        scheduledMissionNotifier = notifier
        missionScheduler = MissionScheduler()
        apiBaseURL =
            appDefaults.string(forKey: "apiBaseURL")
            ?? Self.defaultBaseURL
        let storedBudget = appDefaults.integer(
            forKey: "defaultMissionBudget"
        )
        if storedBudget > 0 {
            defaultMissionBudget = storedBudget
        }
        loadModelDefaultsForCurrentProfile()
        if let storedAutonomy = appDefaults.string(forKey: "defaultAutonomy"),
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
        missionScheduler.onFire = { [weak self] request, completion in
            Task { @MainActor [weak self] in
                guard let self else {
                    completion()
                    return
                }
                await self.handleScheduledFire(request)
                completion()
            }
        }
        // UI 预览模式（开发用）：不做启动领养调度，避免预览时真实派发与钥匙串弹窗
        reloginHandler.store = self
        runtimeProfileFailureHandler.store = self
    }

    private static func codingRanchBootstrapProjection(
        _ outcome: OperationCommitOutcome<CodingRanchBootstrapResult>
    ) -> (
        state: WorkflowLoadState<CodingRanchBootstrapResult>,
        visibilityFailure: UserVisibleFailure?
    ) {
        switch outcome {
        case .notCommitted(let failure):
            return (.failed(failure), failure)
        case .committed(let result):
            return (.loaded(result), nil)
        case .committedWithVisibilityFailure(let result, let failure):
            return (.loaded(result), failure)
        }
    }

    var runtimeBootstrapRetryAvailable: Bool {
        if case .failed = runtimeProjection.state {
            return true
        }
        return false
    }

    var codingRanchBootstrapRetryAvailable: Bool {
        if case .failed = codingRanchBootstrapState {
            return true
        }
        return false
    }

    func activatePostBootstrapDispatchIfReady() {
        applyStartupGateDecision(
            applicationStartupGate.claimStartIfReady()
        )
    }

    func runCodingRanchBootstrap() {
        guard case .failed = codingRanchBootstrapState else {
            return
        }
        codingRanchBootstrapState = .loading
        let trace = operationTraceFactory.generated(
            operation: .applicationBootstrap,
            scope: .fixed(.application)
        )
        let outcome = codingRanchBootstrapBoundary
            .ensureCodingRanchBootstrap(trace: trace) {
                try productBootstrapService.ensureBootstrap()
            }
        let projection = Self.codingRanchBootstrapProjection(outcome)
        codingRanchBootstrapState = projection.state
        switch projection.state {
        case .loaded(let result):
            if case .failed(let runtimeFailure) = runtimeProjection.state {
                globalVisibleFailure = runtimeFailure
            } else {
                globalVisibleFailure = projection.visibilityFailure
            }
            applyStartupGateDecision(
                applicationStartupGate.acceptCodingRanchLoaded(result)
            )
        case .failed(let failure):
            globalVisibleFailure = failure
        case .idle, .loading:
            return
        }
    }

    func runRuntimeBootstrap() {
        guard case .failed = runtimeProjection.state else {
            return
        }
        let trace = operationTraceFactory.generated(
            operation: .runtimeBootstrap,
            scope: .fixed(.runtimeBootstrap)
        )
        let generationCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try runtimeProjection.beginRefresh()
        }
        let generation: WorkflowRequestGeneration
        switch generationCapture {
        case .value(let value):
            generation = value
        case .failed(let failure):
            globalVisibleFailure = failure
            return
        }
        let terminal = captureSynchronousLoad(
            reporter: failureReporter,
            trace: trace
        ) {
            try synchronousRuntimeBootstrap.run(
                runtimeBootstrapRequest,
                trace: trace
            )
        }
        let applyCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try runtimeProjection.applyTerminal(
                terminal,
                for: generation
            )
        }
        switch applyCapture {
        case .value(false):
            return
        case .value(true):
            break
        case .failed(let failure):
            globalVisibleFailure = failure
            return
        }
        switch terminal {
        case .loaded(let snapshot):
            installRuntimeSnapshot(snapshot)
            if case .failed(let ranchFailure) = codingRanchBootstrapState {
                globalVisibleFailure = ranchFailure
            } else {
                globalVisibleFailure = nil
            }
            applyStartupGateDecision(
                applicationStartupGate.acceptRuntimeLoaded(snapshot)
            )
        case .failed(let failure):
            globalVisibleFailure = failure
        case .idle, .loading:
            return
        }
    }

    private func installRuntimeSnapshot(
        _ snapshot: RuntimeWorkflowSnapshot
    ) {
        runtimeProfiles = snapshot.profiles
        currentRuntimeProfile = snapshot.defaultProfile
        companions = snapshot.companions
        camps = snapshot.camps
        apiKeyPresent = snapshot.credentials.apiKeyPresent
        searchKeyPresent = snapshot.credentials.searchKeyPresent
        webCredentialPresent =
            snapshot.credentials.oauthAccessTokenPresent
            && (
                apiFormat != .openAIChatCompletions
                || snapshot.credentials.chatGPTAccountIdPresent
            )
        loadModelDefaultsForCurrentProfile()
    }

    private func applyStartupGateDecision(
        _ decision: ApplicationStartupGateDecision
    ) {
        switch decision {
        case .waitingForOther, .alreadyStarted:
            return
        case .startNow:
            startKernelEventListener(recoverKernel: !Self.isUIPreview)
        }
    }

    /// 环境变量 AGENTLOOP_UI_PREVIEW=1 时为 UI 预览模式：不读钥匙串、不调度任务
    nonisolated static let isUIPreview = ProcessInfo.processInfo.environment["AGENTLOOP_UI_PREVIEW"] == "1"

#if DEBUG
    private enum P1EDeletionPreviewScenario: String {
        case storeBeforeEvidenceFailure
        case refreshAfterCommitOnce
    }

    nonisolated private static var p1eDeletionPreviewScenario:
        P1EDeletionPreviewScenario?
    {
        guard isUIPreview else { return nil }
        return P1EDeletionPreviewScenario(
            rawValue: ProcessInfo.processInfo.environment[
                "AGENTLOOP_P1E_DELETION_PREVIEW_SCENARIO"
            ] ?? ""
        )
    }
#endif

    nonisolated private static func makeUserDefaults() -> UserDefaults {
        guard isUIPreview else {
            return .standard
        }
        let suiteName = [
            "com.muzi.agentloop.ui-preview",
            String(ProcessInfo.processInfo.processIdentifier),
            UUID().uuidString,
        ].joined(separator: ".")
        guard let defaults = ProcessLocalPreviewUserDefaults(
            suiteName: suiteName
        ) else {
            fatalError("无法创建进程内 UI 预览偏好存储")
        }
        return defaults
    }

    var profileScopedDefaults: ProfileScopedDefaults {
        ProfileScopedDefaults(defaults: userDefaults)
    }

    /// 预览直达（截图循环用）：启动即打开指定行动，可选直接进小剧场
    static let previewMissionId = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_MISSION"]
    static let previewTheater = ProcessInfo.processInfo.environment["AGENTLOOP_PREVIEW_THEATER"] == "1"

    nonisolated private static func scheduledPlanningRuntimeSelection(
        database: AppDatabase,
        defaults: ProfileScopedDefaults
    ) throws -> PlanningEntryRuntimeSelection {
        guard let profile = try database.defaultProfile() else {
            throw RecordNotFoundError(
                table: "runtime_profile(default)",
                id: "default"
            )
        }
        let planner = defaults.plannerModel(profileID: profile.id)
        let model = planner.isEmpty
            ? defaults.defaultModel(
                profileID: profile.id,
                fallback: KernelDefaults.defaultGuideModel
            )
            : planner
        return PlanningEntryRuntimeSelection(
            runtimeProfileId: profile.id,
            plannerModel: model
        )
    }

    nonisolated private static func nonEmptyCredential(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    nonisolated private static func storedProviderCredential(
        using keychain: KeychainStore,
        defaults: UserDefaults
    ) -> StoredCredential? {
        let preferred = ProviderCredentialSource(
            rawValue: defaults.string(forKey: preferredCredentialSourceKey) ?? ""
        ) ?? .apiKey
        let apiKey = nonEmptyCredential(try? keychain.get(account: apiKeyAccount))
        let chatGPTAccountID = nonEmptyCredential(try? keychain.get(account: oauthChatGPTAccountIDAccount))
        let format = ProviderAPIFormat(
            rawValue: defaults.string(forKey: "apiFormat") ?? ""
        ) ?? .anthropicMessages
        let rawOAuthToken = nonEmptyCredential(try? keychain.get(account: oauthAccessTokenAccount))
        let oauthToken = format == .openAIChatCompletions && chatGPTAccountID == nil
            ? nil
            : rawOAuthToken

        switch preferred {
        case .webLogin:
            if let oauthToken { return StoredCredential(value: oauthToken, source: .webLogin, chatGPTAccountID: chatGPTAccountID) }
        case .apiKey:
            if let apiKey { return StoredCredential(value: apiKey, source: .apiKey, chatGPTAccountID: nil) }
        }
        return nil
    }

    nonisolated private static func resolveInitialEngineProviderAuthority(
        profile: RuntimeProfileRecord,
        companionId: String,
        companionModel: String,
        modelPolicy: CompanionModelPolicy,
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        keychain: KeychainStore,
        defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?
    ) throws -> EngineModelLoopProviderAuthorityV1 {
        guard let storedProfile = try database.runtimeProfile(id: profile.id),
              storedProfile == profile,
              !profile.kind.isCLI,
              let companion = try database.companion(id: companionId),
              companion.model == companionModel,
              companion.modelPolicy == modelPolicy,
              companion.runtimeProfileId == profile.id
                || (companion.runtimeProfileId == nil && profile.isDefault)
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let effectiveModel: String
        switch modelPolicy {
        case .pinned:
            effectiveModel = companionModel
        case .inherit:
            guard let inherited = defaults.string(
                profileID: profile.id,
                suffix: "defaultModel"
            ) else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            effectiveModel = inherited
        }
        try validateExactEngineModel(
            effectiveModel,
            profile: profile,
            defaults: defaults
        )
        return try deferredEngineProviderAuthority(
            profile: profile,
            model: effectiveModel,
            keychain: keychain,
            defaultBaseURL: defaultBaseURL,
            tokenRefresher: tokenRefresher
        )
    }

    nonisolated private static func resolveRecoveryEngineProviderAuthority(
        profile: RuntimeProfileRecord,
        companionId: String,
        persistedModel: String,
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        keychain: KeychainStore,
        defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?
    ) throws -> EngineModelLoopProviderAuthorityV1 {
        guard let storedProfile = try database.runtimeProfile(id: profile.id),
              storedProfile == profile,
              !profile.kind.isCLI,
              let companion = try database.companion(id: companionId),
              companion.runtimeProfileId == profile.id
                || (companion.runtimeProfileId == nil && profile.isDefault)
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        try validateExactEngineModel(
            persistedModel,
            profile: profile,
            defaults: defaults
        )
        return try deferredEngineProviderAuthority(
            profile: profile,
            model: persistedModel,
            keychain: keychain,
            defaultBaseURL: defaultBaseURL,
            tokenRefresher: tokenRefresher
        )
    }

    nonisolated private static func validateExactEngineModel(
        _ model: String,
        profile: RuntimeProfileRecord,
        defaults: ProfileScopedDefaults
    ) throws {
        guard !model.isEmpty,
              model == model.trimmingCharacters(in: .whitespacesAndNewlines),
              model != "cli-default",
              let catalog = ModelCatalogService.trustedCatalog(
                  profile: profile,
                  defaults: defaults
              ),
              catalog.contains(model)
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    nonisolated private static func deferredEngineProviderAuthority(
        profile: RuntimeProfileRecord,
        model: String,
        keychain: KeychainStore,
        defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?
    ) throws -> EngineModelLoopProviderAuthorityV1 {
        let baseValue = profile.baseURL ?? defaultBaseURL
        guard let baseURL = ProviderEndpoint.normalizedBaseURL(baseValue) else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let format: ProviderAPIFormat
        switch profile.kind {
        case .anthropicAPI:
            format = .anthropicMessages
        case .openAIAPI, .chatGPTOAuth:
            format = .openAIChatCompletions
        case .cliCodex, .cliClaude:
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return try EngineModelLoopProviderAuthorityV1(
            profileId: profile.id,
            effectiveModel: model,
            makeProvider: {
                let credential = try exactRuntimeProfileCredential(
                    profile: profile,
                    keychain: keychain
                )
                return makeProvider(
                    credential: credential,
                    format: format,
                    model: model,
                    baseURL: baseURL,
                    tokenRefresher: tokenRefresher
                )
            }
        )
    }

    nonisolated private static func exactRuntimeProfileCredential(
        profile: RuntimeProfileRecord,
        keychain: KeychainStore
    ) throws -> StoredCredential {
        guard let account = profile.credentialAccount,
              !account.isEmpty,
              let rawValue = try keychain.get(
                  account: account,
                  interactionPolicy: .failIfInteractionRequired
              ),
              let value = nonEmptyCredential(rawValue)
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        switch profile.kind {
        case .anthropicAPI, .openAIAPI:
            return StoredCredential(
                value: value,
                source: .apiKey,
                chatGPTAccountID: nil
            )
        case .chatGPTOAuth:
            guard let rawAccountID = try keychain.get(
                account: oauthChatGPTAccountIDAccount,
                interactionPolicy: .failIfInteractionRequired
            ),
                  let accountID = nonEmptyCredential(rawAccountID)
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            return StoredCredential(
                value: value,
                source: .webLogin,
                chatGPTAccountID: accountID
            )
        case .cliCodex, .cliClaude:
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    nonisolated private static func resolveProvider(
        model requestedModel: String,
        companionId: String?,
        db: AppDatabase,
        defaults: ProfileScopedDefaults,
        keychain: KeychainStore,
        defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?,
        reportFailure: (@Sendable (String) -> Void)? = nil
    ) -> (any LLMProvider)? {
        guard !Self.isUIPreview else { return nil }
        let defaultProfile = try? db.defaultProfile()
        let companion = companionId.flatMap { try? db.companion(id: $0) }
        let profile: RuntimeProfileRecord?
        if let runtimeProfileId = companion?.runtimeProfileId {
            profile = (try? db.runtimeProfile(id: runtimeProfileId)) ?? defaultProfile
        } else {
            profile = defaultProfile
        }
        guard let profile else { return nil }
        guard !profile.kind.isCLI else { return nil }

        let policy = companion?.modelPolicy ?? .pinned
        let model = policy == .inherit
            ? defaults.defaultModel(profileID: profile.id, fallback: KernelDefaults.defaultGuideModel)
            : requestedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveModel = model.isEmpty
            ? defaults.defaultModel(profileID: profile.id, fallback: KernelDefaults.defaultGuideModel)
            : model

        if let catalog = ModelCatalogService.trustedCatalog(profile: profile, defaults: defaults),
           !catalog.contains(effectiveModel) {
            let message: String
            if let companion {
                message = "\(companion.name)钉着 \(effectiveModel)，供给线「\(profile.name)」没有这个模型"
            } else {
                message = "供给线「\(profile.name)」没有模型 \(effectiveModel)"
            }
            db.appendKernelErrorEvent(missionId: "", message: message)
            reportFailure?(message)
            return nil
        }

        guard let credential = runtimeProfileCredential(profile: profile, keychain: keychain) else {
            return nil
        }
        let base = ProviderEndpoint.normalizedBaseURL(profile.baseURL ?? defaultBaseURL)
            ?? URL(string: defaultBaseURL)!
        let format: ProviderAPIFormat = switch profile.kind {
        case .anthropicAPI:
            .anthropicMessages
        case .openAIAPI, .chatGPTOAuth:
            .openAIChatCompletions
        case .cliCodex, .cliClaude:
            .openAIChatCompletions
        }
        return makeProvider(
            credential: credential,
            format: format,
            model: effectiveModel,
            baseURL: base,
            tokenRefresher: tokenRefresher
        )
    }

    nonisolated private static func runtimeProfileCredential(
        profile: RuntimeProfileRecord,
        keychain: KeychainStore
    ) -> StoredCredential? {
        switch profile.kind {
        case .anthropicAPI, .openAIAPI:
            guard let account = profile.credentialAccount,
                  let value = nonEmptyCredential(try? keychain.get(account: account)) else {
                return nil
            }
            return StoredCredential(value: value, source: .apiKey, chatGPTAccountID: nil)
        case .chatGPTOAuth:
            guard let account = profile.credentialAccount,
                  let value = nonEmptyCredential(try? keychain.get(account: account)) else {
                return nil
            }
            let chatGPTAccountID = nonEmptyCredential(try? keychain.get(account: oauthChatGPTAccountIDAccount))
            return StoredCredential(value: value, source: .webLogin, chatGPTAccountID: chatGPTAccountID)
        case .cliCodex, .cliClaude:
            return nil
        }
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

    func reload(
        keychainInteractionPolicy: KeychainInteractionPolicy = .failIfInteractionRequired
    ) {
        let previousDefaultProfileId = currentRuntimeProfile?.id
        runtimeProfiles = (try? db.runtimeProfiles()) ?? []
        currentRuntimeProfile = (try? db.defaultProfile()) ?? runtimeProfiles.first
        if previousDefaultProfileId != currentRuntimeProfile?.id {
            loadModelDefaultsForCurrentProfile()
        }
        companions = (try? db.regularCompanions()) ?? []
        camps = (try? db.camps()) ?? []
        apiKeyPresent = !Self.isUIPreview
            && Self.nonEmptyCredential(try? keychain.get(
                account: Self.apiKeyAccount,
                interactionPolicy: keychainInteractionPolicy
            )) != nil
        searchKeyPresent = Self.isUIPreview
            ? false
            : (((try? keychain.get(
                account: "tavily-api-key",
                interactionPolicy: keychainInteractionPolicy
            )) ?? nil).map { !$0.isEmpty } ?? false)
        let hasOAuthToken = !Self.isUIPreview
            && Self.nonEmptyCredential(
                try? keychain.get(
                    account: Self.oauthAccessTokenAccount,
                    interactionPolicy: keychainInteractionPolicy
                )
            ) != nil
        let hasChatGPTAccount = !Self.isUIPreview
            && Self.nonEmptyCredential(
                try? keychain.get(
                    account: Self.oauthChatGPTAccountIDAccount,
                    interactionPolicy: keychainInteractionPolicy
                )
            ) != nil
        webCredentialPresent = !Self.isUIPreview
            && hasOAuthToken
            && (apiFormat != .openAIChatCompletions || hasChatGPTAccount)
        reloadMissionList()
        reloadArtifactLedger()
    }

    /// 首屏出现后再允许 SecurityAgent 交互，避免钥匙串授权把 App 主线程堵在窗口创建之前。
    /// 读取在独立任务中完成；这里只回写“是否存在”，绝不把凭据带回 UI 或日志。
    func refreshCredentialPresence() async {
        guard !Self.isUIPreview, !credentialAccessInProgress else { return }
        credentialAccessInProgress = true
        credentialAccessError = nil
        defer { credentialAccessInProgress = false }

        let keychainStore = keychain
        do {
            let snapshot = try await Task.detached(priority: .userInitiated) {
                try Self.readCredentialPresence(using: keychainStore)
            }.value
            apiKeyPresent = snapshot.apiKeyPresent
            searchKeyPresent = snapshot.searchKeyPresent
            webCredentialPresent = snapshot.oauthAccessTokenPresent
                && (apiFormat != .openAIChatCompletions || snapshot.chatGPTAccountIDPresent)
        } catch {
            let message = "无法读取系统钥匙串：\(readableError(error))"
            credentialAccessError = message
            showToast(message)
        }
    }

    nonisolated private static func readCredentialPresence(
        using keychain: KeychainStore
    ) throws -> CredentialPresenceSnapshot {
        CredentialPresenceSnapshot(
            apiKeyPresent: nonEmptyCredential(try keychain.get(account: apiKeyAccount)) != nil,
            searchKeyPresent: nonEmptyCredential(try keychain.get(account: "tavily-api-key")) != nil,
            oauthAccessTokenPresent: nonEmptyCredential(
                try keychain.get(account: oauthAccessTokenAccount)
            ) != nil,
            chatGPTAccountIDPresent: nonEmptyCredential(
                try keychain.get(account: oauthChatGPTAccountIDAccount)
            ) != nil
        )
    }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? keychain.set(trimmed, account: Self.apiKeyAccount)
        attachAPIKeyToEmptyDefaultProfileIfNeeded()
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
        provider(model: model, companionId: nil)
    }

    func provider(model: String, companionId: String?) -> (any LLMProvider)? {
        let failureHandler = RuntimeProfileResolutionFailureHandler()
        failureHandler.store = self
        return Self.resolveProvider(
            model: model,
            companionId: companionId,
            db: db,
            defaults: profileScopedDefaults,
            keychain: keychain,
            defaultBaseURL: Self.defaultBaseURL,
            tokenRefresher: Self.tokenRefresher(for: openAIOAuthSession),
            reportFailure: { message in failureHandler.report(message) }
        )
    }

    nonisolated static func credentialAccount(for kind: RuntimeProfileKind) -> String? {
        switch kind {
        case .anthropicAPI, .openAIAPI:
            return Self.apiKeyAccount
        case .chatGPTOAuth:
            return Self.oauthAccessTokenAccount
        case .cliCodex, .cliClaude:
            return nil
        }
    }

    func saveRuntimeProfileAndReload(_ profile: RuntimeProfileRecord) {
        do {
            try db.saveRuntimeProfile(profile)
            reloadRuntimeProfiles(loadModelDefaults: false)
        } catch {
            showToast("保存供给线失败：\(readableError(error))")
        }
    }

    func deleteRuntimeProfileAndReload(id: String) {
        do {
            try db.deleteRuntimeProfile(id: id)
            reloadRuntimeProfiles(loadModelDefaults: false)
        } catch {
            showToast(readableError(error))
        }
    }

    func reconciliationItems(switchingTo profileId: String) -> [ReconciliationItem] {
        (try? db.reconciliationReport(
            switchingTo: profileId,
            defaults: profileScopedDefaults
        )) ?? []
    }

    /// V1.1a-D3:切默认供给线——先按用户对账选择改写,再切换;未勾选的保持不动(派单 fail-closed)。
    func switchDefaultRuntimeProfile(
        id: String,
        inheritCompanionIds: Set<String>,
        resetSettingScopes: Set<String>
    ) {
        let items = reconciliationItems(switchingTo: id).filter { item in
            switch item.scope {
            case .companion(let companionId, _): return inheritCompanionIds.contains(companionId)
            default: return resetSettingScopes.contains(item.id)
            }
        }
        try? db.applyReconciliation(
            items: items,
            defaults: profileScopedDefaults
        )
        setDefaultRuntimeProfile(id: id)
        reload()
    }

    /// 目录选项(伙伴编辑器/设置/对账共用):OAuth/CLI 只读静态目录;
    /// 官方 API 使用服务端目录 + 手动项;网关使用该档案自己的可编辑目录。
    func catalogChoices(profile: RuntimeProfileRecord) -> [String] {
        ModelCatalogService.resolvedCatalog(
            profile: profile,
            defaults: profileScopedDefaults,
            fallback: Self.factoryModelChoices
        )
    }

    var currentModelCatalogAllowsManualInput: Bool {
        currentRuntimeProfile?.kind.allowsManualModelEntry ?? false
    }

    func canRemoveModelFromCurrentCatalog(_ model: String) -> Bool {
        currentModelCatalogAllowsManualInput && removableCatalogModels.contains(model)
    }

    func addModelToCurrentCatalog(_ rawModel: String) {
        guard let profile = currentRuntimeProfile, currentModelCatalogAllowsManualInput else { return }
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return }
        let defaults = profileScopedDefaults
        defaults.setManualModels(defaults.manualModels(profileID: profile.id) + [model], profileID: profile.id)
        loadModelDefaultsForCurrentProfile()
    }

    func removeModelFromCurrentCatalog(_ model: String) {
        guard let profile = currentRuntimeProfile, canRemoveModelFromCurrentCatalog(model) else { return }
        let defaults = profileScopedDefaults
        defaults.setManualModels(defaults.manualModels(profileID: profile.id).filter { $0 != model }, profileID: profile.id)
        if !ModelCatalogService.isOfficialCatalogProfile(profile) {
            let stored = defaults.modelChoices(profileID: profile.id, fallback: Self.factoryModelChoices)
            defaults.setStringArray(stored.filter { $0 != model }, profileID: profile.id, suffix: "modelChoices")
        }
        loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: true)
    }

    func resetCurrentModelCatalog() {
        guard let profile = currentRuntimeProfile, currentModelCatalogAllowsManualInput else { return }
        let defaults = profileScopedDefaults
        defaults.setManualModels([], profileID: profile.id)
        if !ModelCatalogService.isOfficialCatalogProfile(profile) {
            defaults.setStringArray(Self.factoryModelChoices, profileID: profile.id, suffix: "modelChoices")
        }
        loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: true)
    }

    /// 刷新目录;返回人话结果供设置页展示。
    func refreshCatalog(profileId: String) async -> String? {
        guard let profile = try? db.runtimeProfile(id: profileId) else { return "供给线不存在" }
        let credential: String
        if !profile.kind.allowsManualModelEntry {
            credential = ""
        } else if let value = Self.nonEmptyCredential(
            try? keychain.get(account: profile.credentialAccount ?? Self.apiKeyAccount)
        ) {
            credential = value
        } else {
            return "「\(profile.name)」还没有可用凭据,先保存 API Key"
        }
        do {
            let models = try await ModelCatalogService(
                defaults: profileScopedDefaults
            )
            .refresh(
                profile: profile,
                credential: credential
            )
            reloadRuntimeProfiles(loadModelDefaults: profile.isDefault)
            return "「\(profile.name)」目录已更新:\(models.count) 个模型"
        } catch {
            return "刷新失败:\(readableError(error))(保留上次缓存)"
        }
    }

    func setDefaultRuntimeProfile(id: String) {
        do {
            try db.setDefaultProfile(id: id)
            reloadRuntimeProfiles(loadModelDefaults: true)
        } catch {
            showToast("供给线切换失败：\(readableError(error))")
        }
    }

    private func reloadRuntimeProfiles(loadModelDefaults: Bool) {
        runtimeProfiles = (try? db.runtimeProfiles()) ?? []
        currentRuntimeProfile = (try? db.defaultProfile()) ?? runtimeProfiles.first
        if loadModelDefaults {
            loadModelDefaultsForCurrentProfile()
        }
    }

    private func loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: Bool = false) {
        guard let profile = currentRuntimeProfile else { return }
        let defaults = profileScopedDefaults
        let choices = catalogChoices(profile: profile)
        modelChoices = choices
        removableCatalogModels = !profile.kind.allowsManualModelEntry ? [] :
            (ModelCatalogService.isOfficialCatalogProfile(profile)
                ? Set(defaults.manualModels(profileID: profile.id))
                : (choices.count > 1 ? Set(choices) : []))
        if !profile.kind.allowsManualModelEntry || clampAfterCatalogEdit {
            defaults.clampModelSelections(profileID: profile.id, catalog: choices)
        }
        defaultModel = defaults.defaultModel(
            profileID: profile.id,
            fallback: choices.first ?? KernelDefaults.defaultGuideModel
        )
        distillModel = defaults.distillModel(profileID: profile.id)
        plannerModel = defaults.plannerModel(profileID: profile.id)
    }

    private func persistProfileString(_ value: String, suffix: String) {
        guard let profileId = currentRuntimeProfile?.id else { return }
        profileScopedDefaults.setString(
            value,
            profileID: profileId,
            suffix: suffix
        )
    }

    private func attachAPIKeyToEmptyDefaultProfileIfNeeded() {
        guard var profile = currentRuntimeProfile,
              (profile.kind == .anthropicAPI || profile.kind == .openAIAPI),
              profile.credentialAccount == nil else {
            return
        }
        profile.credentialAccount = Self.apiKeyAccount
        try? db.saveRuntimeProfile(profile)
        currentRuntimeProfile = profile
        runtimeProfiles = (try? db.runtimeProfiles()) ?? runtimeProfiles
    }

    // MARK: - 定时行动逻辑接线（UI 由 Claude 单独实现）

    func loadScheduleWorkflow(
        campId: String
    ) async -> WorkflowLoadState<ScheduleWorkflowSnapshot> {
        let trace = operationTraceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
        let terminal = await missionWorkflowController.loadSchedules(
            campId: campId,
            trace: trace
        )
        switch terminal {
        case .loaded(let snapshot):
            for template in snapshot.templates {
                scheduleTemplateRecordById[template.record.id] =
                    template.record
            }
            for schedule in snapshot.schedules {
                scheduleRecordById[schedule.record.id] = schedule.record
            }
        case .failed(let failure):
            showToast(failure.message)
        case .idle, .loading:
            break
        }
        return terminal
    }

    func saveScheduledMissionTemplate(
        _ command: ScheduleTemplateDraftCommand
    ) async -> Bool {
        let templateId = command.existingId ?? UUID().uuidString
        let normalized = ScheduleTemplateDraftCommand(
            existingId: templateId,
            campId: command.campId,
            name: command.name,
            goal: command.goal,
            companionId: command.companionId,
            workspacePath: command.workspacePath,
            budgetText: command.budgetText,
            autonomy: command.autonomy
        )
        return await performScheduleMutation(
            key: .template(templateId),
            operation: .scheduleTemplateSave
        ) { [self] trace in
            await missionWorkflowController.saveTemplateDraft(
                normalized,
                registration: missionScheduler.registrationPort(),
                trace: trace
            )
        }
    }

    func saveMissionSchedule(
        _ command: ScheduleDraftCommand,
        calendar: Calendar
    ) async -> Bool {
        let commandKey = ScheduleMutationKey.schedule(
            "draft:\(UUID().uuidString)"
        )
        return await performScheduleMutation(
            key: commandKey,
            operation: .scheduleSave
        ) { [self] trace in
            await missionWorkflowController.saveScheduleDraft(
                command,
                calendar: calendar,
                registration: missionScheduler.registrationPort(),
                notifications: scheduledMissionNotifier.port(),
                trace: trace
            )
        }
    }

    func setMissionScheduleEnabled(
        id: String,
        enabled: Bool
    ) async -> Bool {
        return await performScheduleMutation(
            key: .schedule(id),
            operation: .scheduleEnable
        ) { [self] trace in
            await missionWorkflowController.setScheduleEnabled(
                id: id,
                enabled: enabled,
                registration: missionScheduler.registrationPort(),
                notifications: scheduledMissionNotifier.port(),
                trace: trace
            )
        }
    }

    func deleteMissionSchedule(id: String) async -> Bool {
        return await performScheduleMutation(
            key: .schedule(id),
            operation: .scheduleDelete
        ) { [self] trace in
            await missionWorkflowController.deleteSchedule(
                id: id,
                registration: missionScheduler.registrationPort(),
                trace: trace
            )
        }
    }

    func deleteScheduledMissionTemplate(id: String) async -> Bool {
        return await performScheduleMutation(
            key: .template(id),
            operation: .scheduleTemplateDelete
        ) { [self] trace in
            await missionWorkflowController.deleteTemplate(
                id: id,
                registration: missionScheduler.registrationPort(),
                trace: trace
            )
        }
    }

    private func performScheduleMutation(
        key: ScheduleMutationKey,
        operation: FailureOperation,
        action: @escaping @MainActor @Sendable (OperationTrace) async
            -> ScheduleMutationOutcome
    ) async -> Bool {
        let trace = operationTraceFactory.generated(
            operation: operation,
            scope: .fixed(.scheduleIndex)
        )
        let currentGeneration = scheduleMutationGenerationByKey[key] ?? 0
        let (generation, overflow) = currentGeneration
            .addingReportingOverflow(1)
        guard !overflow else {
            showToast(
                failureReporter.capture(
                    ProjectionContractError.generationOverflow,
                    trace: trace
                ).message
            )
            return false
        }

        scheduleCommandFlightByKey[key]?.task.cancel()
        scheduleMutationGenerationByKey[key] = generation
        let attempt = UUID()
        let purpose = ScheduleCommandFlightPurpose.mutation
        let completion = ScheduleCommandCompletion()
        let task = Task { @MainActor [self] in
            guard isCurrentScheduleFlight(
                key: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            ) else {
                return
            }
            let outcome = await action(trace)
            completion.committed = applyScheduleMutationOutcome(
                outcome,
                originKey: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            )
            finishScheduleCommandFlight(
                key: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            )
        }
        scheduleCommandFlightByKey[key] = ScheduleCommandFlight(
            attempt: attempt,
            generation: generation,
            purpose: purpose,
            task: task
        )
        await task.value
        if completion.committed {
            await refreshScheduleMenuPresentation()
        }
        return completion.committed
    }

    private func retrySchedulePostCommit(key: ScheduleMutationKey) async {
        guard let carrier = schedulePostCommitRepairByKey[key],
              scheduleCommandFlightByKey[key] == nil
        else {
            return
        }
        let currentGeneration = scheduleMutationGenerationByKey[key] ?? 0
        let (generation, overflow) = currentGeneration
            .addingReportingOverflow(1)
        guard !overflow else {
            let trace = operationTraceFactory.generated(
                operation: .scheduleRefresh,
                scope: .fixed(.scheduleIndex)
            )
            showToast(
                failureReporter.capture(
                    ProjectionContractError.generationOverflow,
                    trace: trace
                ).message
            )
            return
        }

        scheduleMutationGenerationByKey[key] = generation
        let attempt = UUID()
        let purpose = ScheduleCommandFlightPurpose.repair(
            startingReceipt: carrier.receipt
        )
        let task = Task { @MainActor [self] in
            guard isCurrentScheduleFlight(
                key: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            ), schedulePostCommitRepairByKey[key]?.receipt == carrier.receipt
            else {
                return
            }
            let outcome = await missionWorkflowController
                .retrySchedulePostCommit(
                    carrier.receipt,
                    registration: missionScheduler.registrationPort(),
                    notifications: scheduledMissionNotifier.port()
                )
            applyScheduleRepairOutcome(
                outcome,
                originKey: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            )
            finishScheduleCommandFlight(
                key: key,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            )
        }
        scheduleCommandFlightByKey[key] = ScheduleCommandFlight(
            attempt: attempt,
            generation: generation,
            purpose: purpose,
            task: task
        )
        await task.value
    }

    private func applyScheduleMutationOutcome(
        _ outcome: ScheduleMutationOutcome,
        originKey: ScheduleMutationKey,
        generation: UInt64,
        attempt: UUID,
        purpose: ScheduleCommandFlightPurpose
    ) -> Bool {
        switch outcome {
        case .notCommitted(let failure):
            guard isCurrentScheduleFlight(
                key: originKey,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            ) else {
                return false
            }
            showToast(failure.message)
            return false
        case .committed(let terminal):
            _ = consumeAndApplyScheduleApplication(
                terminal.application,
                originKey: originKey,
                originPurpose: purpose
            )
            return true
        case .committedWithVisibilityFailure(let terminal):
            _ = consumeAndApplyScheduleApplication(
                terminal.application,
                originKey: originKey,
                originPurpose: purpose
            )
            return true
        case .committedSuperseded:
            return true
        }
    }

    private func applyScheduleRepairOutcome(
        _ outcome: SchedulePostCommitRepairOutcome,
        originKey: ScheduleMutationKey,
        generation: UInt64,
        attempt: UUID,
        purpose: ScheduleCommandFlightPurpose
    ) {
        switch outcome {
        case .repaired(let terminal):
            _ = consumeAndApplyScheduleApplication(
                terminal.application,
                originKey: originKey,
                originPurpose: purpose
            )
        case .stillPending(let terminal):
            _ = consumeAndApplyScheduleApplication(
                terminal.application,
                originKey: originKey,
                originPurpose: purpose
            )
        case .superseded:
            guard isCurrentScheduleFlight(
                key: originKey,
                generation: generation,
                attempt: attempt,
                purpose: purpose
            ) else {
                return
            }
        }
    }

    private func consumeAndApplyScheduleApplication(
        _ receipt: SchedulePostCommitApplicationReceipt,
        originKey: ScheduleMutationKey,
        originPurpose: ScheduleCommandFlightPurpose
    ) -> Bool {
        let decision = missionWorkflowController
            .consumeSchedulePostCommitApplication(receipt)
        return decision.fold(
            apply: { [self] program in
                applyScheduleProgram(
                    program,
                    originKey: originKey,
                    originPurpose: originPurpose
                )
                return true
            },
            mutationSuperseded: { false },
            alreadyConsumed: { false }
        )
    }

    private func applyScheduleProgram(
        _ program: SchedulePostCommitCanonicalProgram,
        originKey: ScheduleMutationKey,
        originPurpose: ScheduleCommandFlightPurpose
    ) {
        var templates = scheduleTemplateRecordById
        var schedules = scheduleRecordById
        var repairs = schedulePostCommitRepairByKey
        var authorization = scheduleAuthorizationEvidence
        var registration = scheduleRegistrationEvidence
        var visibleFailure: UserVisibleFailure?
        var flightKeysToClear: Set<ScheduleMutationKey> = []

        for operation in program.operations {
            switch operation {
            case .project(let identity):
                Self.projectScheduleIdentity(
                    identity,
                    templates: &templates,
                    schedules: &schedules
                )
            case .authorizationEvidence(let receipt):
                authorization = receipt
            case .registrationEvidence(let receipt):
                registration = receipt
            case .clearRepair(let receipt):
                for key in Array(repairs.keys) where
                    repairs[key]?.receipt.isSameRepairOwner(as: receipt)
                        == true
                {
                    repairs[key] = nil
                    guard let flight = scheduleCommandFlightByKey[key],
                          case .repair(let startingReceipt) = flight.purpose,
                          startingReceipt.isSameRepairOwner(as: receipt)
                    else {
                        continue
                    }
                    if key == originKey, flight.purpose == originPurpose {
                        continue
                    }
                    flightKeysToClear.insert(key)
                }
            case .installRepair(let identity, let receipt, let failure):
                visibleFailure = failure
                for key in Self.scheduleMutationKeys(for: identity) {
                    repairs[key] = SchedulePostCommitRepairCarrier(
                        generation: scheduleMutationGenerationByKey[key] ?? 0,
                        identity: identity,
                        receipt: receipt
                    )
                }
            }
        }

        scheduleTemplateRecordById = templates
        scheduleRecordById = schedules
        schedulePostCommitRepairByKey = repairs
        scheduleAuthorizationEvidence = authorization
        scheduleRegistrationEvidence = registration
        if let visibleFailure {
            globalVisibleFailure = visibleFailure
            showToast(visibleFailure.message)
        } else if globalVisibleFailure.map({
            Self.isScheduleOperation($0.operation)
        }) == true {
            globalVisibleFailure = nil
        }
        for key in flightKeysToClear {
            scheduleCommandFlightByKey.removeValue(forKey: key)?.task.cancel()
        }
    }

    private func isCurrentScheduleFlight(
        key: ScheduleMutationKey,
        generation: UInt64,
        attempt: UUID,
        purpose: ScheduleCommandFlightPurpose
    ) -> Bool {
        guard let current = scheduleCommandFlightByKey[key] else {
            return false
        }
        return current.generation == generation
            && current.attempt == attempt
            && current.purpose == purpose
    }

    private func finishScheduleCommandFlight(
        key: ScheduleMutationKey,
        generation: UInt64,
        attempt: UUID,
        purpose: ScheduleCommandFlightPurpose
    ) {
        guard isCurrentScheduleFlight(
            key: key,
            generation: generation,
            attempt: attempt,
            purpose: purpose
        ) else {
            return
        }
        scheduleCommandFlightByKey[key] = nil
    }

    private static func scheduleMutationKeys(
        for identity: ScheduleMutationCommittedIdentity
    ) -> Set<ScheduleMutationKey> {
        switch identity {
        case .templateSaved(let template):
            return [.template(template.id)]
        case .templateDeleted(let receipt):
            return Set(
                [.template(receipt.template.id)]
                    + receipt.deletedSchedules.map { .schedule($0.id) }
            )
        case .scheduleSaved(let schedule),
             .scheduleEnablementChanged(let schedule):
            return [.schedule(schedule.id)]
        case .scheduleDeleted(let receipt):
            return [.schedule(receipt.schedule.id)]
        }
    }

    private static func projectScheduleIdentity(
        _ identity: ScheduleMutationCommittedIdentity,
        templates: inout [String: MissionTemplateRecord],
        schedules: inout [String: ScheduleRecord]
    ) {
        switch identity {
        case .templateSaved(let template):
            templates[template.id] = template
        case .templateDeleted(let receipt):
            templates[receipt.template.id] = nil
            for schedule in receipt.deletedSchedules {
                schedules[schedule.id] = nil
            }
        case .scheduleSaved(let schedule),
             .scheduleEnablementChanged(let schedule):
            schedules[schedule.id] = schedule
        case .scheduleDeleted(let receipt):
            schedules[receipt.schedule.id] = nil
        }
    }

    private static func isScheduleOperation(
        _ operation: FailureOperation
    ) -> Bool {
        switch operation {
        case .scheduleLoad, .scheduleTemplateSave,
             .scheduleTemplateDelete, .scheduleSave, .scheduleEnable,
             .scheduleDelete, .scheduleNotification, .scheduleRefresh,
             .scheduleFire, .scheduleReplay, .scheduleWake,
             .scheduleBroadcast:
            return true
        default:
            return false
        }
    }

    private func startScheduleSystem() async {
        missionScheduler.start()
        await refreshScheduleRegistrations()
        let trace = operationTraceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
        switch await missionWorkflowController.loadStartupMissedFires(
            now: Date(),
            timeZone: .current,
            trace: trace
        ) {
        case .loaded(let requests):
            for request in requests {
                await executeScheduledFire(request, missed: true)
            }
            if !pendingScheduleCatchups.isEmpty {
                showToast("有定时行动错过了触发点，等待你确认是否补跑")
            }
        case .failed(let failure):
            showToast(failure.message)
        case .idle, .loading:
            break
        }
    }

    private func handleScheduledFire(_ request: ScheduleFireRequest) async {
        await executeScheduledFire(request, missed: false)
    }

    private func executeScheduledFire(
        _ request: ScheduleFireRequest,
        missed: Bool
    ) async {
        let trace = operationTraceFactory.generated(
            operation: .scheduleFire,
            scope: .fixed(.scheduleIndex)
        )
        let outcome: OperationCommitOutcome<ScheduleFireCommitResult>
        if missed {
            outcome = await missionWorkflowController.recordMissedSchedule(
                request,
                trace: trace
            )
        } else {
            outcome = await missionWorkflowController.fireSchedule(
                request,
                trace: trace
            )
        }
        switch outcome {
        case .notCommitted(let failure):
            showToast(failure.message)
        case .committed(let result):
            await applyScheduledFireEffects(result)
            if missed {
                await appendScheduleCatchupIfNeeded(result)
            }
        case .committedWithVisibilityFailure(let result, let failure):
            showToast(failure.message)
            await applyScheduledFireEffects(result)
            if missed {
                await appendScheduleCatchupIfNeeded(result)
            }
        }
    }

    private func applyScheduledFireEffects(
        _ result: ScheduleFireCommitResult
    ) async {
        if result.fire.state == .started {
            let wakeTrace = operationTraceFactory.generated(
                operation: .scheduleWake,
                scope: .fixed(.scheduleIndex)
            )
            switch await missionWorkflowController.publishScheduleWake(
                result,
                trace: wakeTrace
            ) {
            case .notCommitted(let failure),
                 .committedWithVisibilityFailure(_, let failure):
                showToast(failure.message)
            case .committed:
                break
            }
        }

        let broadcastTrace = operationTraceFactory.generated(
            operation: .scheduleBroadcast,
            scope: .fixed(.scheduleIndex)
        )
        switch await missionWorkflowController.publishScheduleBroadcast(
            result,
            trace: broadcastTrace
        ) {
        case .notCommitted(let failure),
             .committedWithVisibilityFailure(_, let failure):
            showToast(failure.message)
        case .committed:
            break
        }

        if let missionId = result.missionId {
            reloadMissionList()
            notifyScheduledMissionOutcomeIfNeeded(missionId: missionId)
        }
        await refreshScheduleRegistrations()
    }

    private func appendScheduleCatchupIfNeeded(
        _ result: ScheduleFireCommitResult
    ) async {
        guard result.disposition == .inserted,
              result.fire.state == .failed,
              result.fire.errorCode == "schedule_missed_while_offline",
              let reason = result.fire.errorMessage,
              reason == "定时行动在应用离线期间错过了触发时间。"
        else {
            return
        }
        let trace = operationTraceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
        switch await missionWorkflowController.loadSchedulePresentation(
            templateId: result.fire.templateId,
            now: Date(),
            timeZone: .current,
            trace: trace
        ) {
        case .loaded(let snapshot):
            guard let template = snapshot.requestedTemplate else { return }
            let catchup = ScheduleCatchup(
                fireId: result.fire.id,
                scheduleId: result.fire.scheduleId,
                templateId: result.fire.templateId,
                fireDate: result.fire.scheduledAt,
                reason: reason,
                title: template.record.name
            )
            if !pendingScheduleCatchups.contains(where: {
                $0.fireId == catchup.fireId
            }) {
                pendingScheduleCatchups.append(catchup)
            }
        case .failed(let failure):
            showToast(failure.message)
        case .idle, .loading:
            break
        }
    }

    private func refreshScheduleRegistrations() async {
        let trace = operationTraceFactory.generated(
            operation: .scheduleRefresh,
            scope: .fixed(.scheduleIndex)
        )
        switch await missionWorkflowController.refreshSchedules(
            registration: missionScheduler.registrationPort(),
            trace: trace
        ) {
        case .refreshed(let receipt, let supersededRepairs):
            scheduleRegistrationEvidence = receipt
            clearScheduleRepairs(supersededRepairs)
            await refreshScheduleMenuPresentation()
        case .failed(let failure):
            showToast(failure.message)
        }
    }

    private func clearScheduleRepairs(
        _ receipts: [SchedulePostCommitRepairReceipt]
    ) {
        guard !receipts.isEmpty else { return }
        let keys = Array(schedulePostCommitRepairByKey.keys)
        for key in keys {
            guard let carrier = schedulePostCommitRepairByKey[key],
                  receipts.contains(where: {
                      carrier.receipt.isSameRepairOwner(as: $0)
                  })
            else {
                continue
            }
            schedulePostCommitRepairByKey[key] = nil
            guard let flight = scheduleCommandFlightByKey[key],
                  case .repair(let startingReceipt) = flight.purpose,
                  receipts.contains(where: {
                      startingReceipt.isSameRepairOwner(as: $0)
                  })
            else {
                continue
            }
            scheduleCommandFlightByKey[key] = nil
            flight.task.cancel()
        }
    }

    func runScheduleNow(id: String) {
        Task { [self] in
            let trace = operationTraceFactory.generated(
                operation: .scheduleLoad,
                scope: .fixed(.scheduleIndex)
            )
            switch await missionWorkflowController.prepareRunNow(
                scheduleId: id,
                now: Date(),
                timeZone: .current,
                trace: trace
            ) {
            case .loaded(let request):
                await executeScheduledFire(request, missed: false)
            case .failed(let failure):
                showToast(failure.message)
            case .idle, .loading:
                break
            }
        }
    }

    func resolveScheduleCatchup(_ catchup: ScheduleCatchup, run: Bool) {
        guard pendingScheduleCatchups.contains(where: {
            $0.fireId == catchup.fireId
        }) else {
            return
        }
        guard run else {
            pendingScheduleCatchups.removeAll {
                $0.fireId == catchup.fireId
            }
            return
        }
        Task { [self] in
            let trace = operationTraceFactory.generated(
                operation: .scheduleReplay,
                scope: .fixed(.scheduleIndex)
            )
            let outcome = await missionWorkflowController.replaySchedule(
                ScheduleReplayRequest(originalFireId: catchup.fireId),
                trace: trace
            )
            switch outcome {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed(let result):
                pendingScheduleCatchups.removeAll {
                    $0.fireId == catchup.fireId
                }
                await applyScheduledFireEffects(result)
            case .committedWithVisibilityFailure(let result, let failure):
                pendingScheduleCatchups.removeAll {
                    $0.fireId == catchup.fireId
                }
                showToast(failure.message)
                await applyScheduledFireEffects(result)
            }
        }
    }

    func scheduleCatchupTitle(_ catchup: ScheduleCatchup) -> String {
        "定时行动「\(catchup.title)」"
    }

    /// 设置页「测试连接」:用当前凭据发一次最小请求,人话化报告结果。
    func testModelConnection() {
        guard let provider = provider(model: defaultModel) else {
            modelConnectionTestStatus = "还没有可用凭据——先保存 API Key 或完成网页登录"
            return
        }
        modelConnectionTestStatus = "正在测试连接…"
        let model = defaultModel
        Task { [weak self] in
            do {
                let stream = provider.streamTurn(
                    system: "Connectivity check. Reply with OK.",
                    history: [.user("ping")],
                    tools: [],
                    toolChoice: .auto,
                    maxTokens: 8
                )
                for try await event in stream {
                    if case .turn = event { break }
                }
                await MainActor.run { [weak self] in
                    self?.modelConnectionTestStatus = "连接正常（\(model)）"
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.modelConnectionTestStatus = "连接失败：\(self.readableError(error))"
                }
            }
        }
    }

    func nextScheduleMenuTitle(now: Date = Date()) -> String {
        _ = now
        return scheduleMenuTitle
    }

    private func refreshScheduleMenuPresentation(
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) async {
        let trace = operationTraceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
        let terminal = await missionWorkflowController
            .loadSchedulePresentation(
                templateId: nil,
                now: now,
                timeZone: timeZone,
                trace: trace
            )
        guard case .loaded(let snapshot) = terminal else {
            if case .failed(let failure) = terminal {
                showToast(failure.message)
            }
            return
        }
        guard let next = snapshot.enabled.min(by: {
            $0.nextFireDate < $1.nextFireDate
        }) else {
            scheduleMenuTitle = "下次日程：暂无"
            return
        }
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d HH:mm"
        scheduleMenuTitle =
            "下次日程：\(formatter.string(from: next.nextFireDate)) "
            + next.record.template.name
    }

    func openProviderAuth() {
        guard !Self.isUIPreview else {
            oauthLoginStatus = "预览模式不读取登录凭据；请用真实模式启动 Coding 牧场后再登录"
            return
        }
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
        userDefaults.set(state, forKey: Self.oauthStateKey)
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
        guard let expectedState = userDefaults.string(
            forKey: Self.oauthStateKey
        ) else {
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
        userDefaults.set(state, forKey: Self.oauthStateKey)
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
        userDefaults.removeObject(forKey: Self.oauthStateKey)
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
        let command: PendingManualMissionStart
        do {
            let snapshot = ManualMissionStartSnapshot(
                mission: PlanningMissionStartArguments(
                    goal: goal,
                    companionIds: companionIds,
                    workspacePath: workspacePath,
                    budgetTokens: defaultMissionBudget,
                    campId: campId,
                    autonomy: autonomy ?? defaultAutonomy
                ),
                runtime: try planningRuntimeSelection()
            )
            command = planningEntryCoordinator.prepareManual(
                snapshot: snapshot,
                pending: pendingManualMissionStart,
                forceNewCommand: false
            )
            pendingManualMissionStart = command
        } catch {
            missionPhase = .error(readableError(error))
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
        missionTask = Task { [weak self, command] in
            guard let self else { return }
            do {
                let missionId = try await planningEntryCoordinator.startManual(
                    command
                )
                pendingManualMissionStart =
                    planningEntryCoordinator.clearManualAfterSuccess(
                        current: pendingManualMissionStart,
                        completed: command
                    )
                currentMissionId = missionId
                theaterMode = false
                if let campId = command.snapshot.mission.campId {
                    missionDrafts[campId] = nil
                }
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

    func closeoutCurrentMission() async -> Bool {
        guard let currentMissionId else { return false }
        returnAcceptanceError = nil
        do {
            let outcomeStore = OutcomeStore(database: db)
            if let outcome = try outcomeStore.outcome(
                missionId: currentMissionId
            ) {
                let acceptanceId = UUID().uuidString
                let deviceId = try LocalCaptureIdentity.live()
                    .installationID()
                let envelope = try CommandEnvelopeV1(
                    idempotencyKey: "acceptance.accept:v1:\(acceptanceId)",
                    actorType: .user,
                    actorId: P1DActorID.localOwner,
                    deviceId: deviceId,
                    correlationId: "trace:acceptance:\(acceptanceId)",
                    causationId: nil,
                    occurredAt: try P1DTimestampV1.canonical(Date())
                )
                let command = try AcceptOutcomeCommandV1(
                    envelope: envelope,
                    acceptanceId: acceptanceId,
                    outcome: outcome.currentRef,
                    expectedOutcomeAggregateVersion:
                        outcome.aggregateVersion,
                    subject: AcceptanceSubjectV1.user(
                        P1DActorID.localOwner
                    ),
                    reason: "Accepted in Coding Ranch return summary"
                )
                switch AcceptanceWorkflowController
                    .live(store: outcomeStore)
                    .accept(command)
                {
                case .committed:
                    reloadMission(missionId: currentMissionId)
                    reloadMissionList()
                    reloadArtifactLedger()
                    return true
                case .notCommitted(let failure):
                    returnAcceptanceError = failure.message
                    return false
                }
            }
            guard try !outcomeStore.missionHasActiveContractLink(
                missionId: currentMissionId
            ) else {
                let trace = "trace:acceptance:\(UUID().uuidString)"
                returnAcceptanceError =
                    "Contract-linked mission has no deliverable Outcome [trace: \(trace)]"
                return false
            }
            try await orchestrator.closeout(
                currentMissionId,
                distillModel: effectiveDistillModel
            )
            reloadMission(missionId: currentMissionId)
            reloadMissionList()
            reloadArtifactLedger()
            return true
        } catch {
            let trace = "trace:acceptance:\(UUID().uuidString)"
            let message = "\(readableError(error)) [trace: \(trace)]"
            returnAcceptanceError = message
            missionPhase = .error(message)
            return false
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
                let deviceId = try LocalCaptureIdentity.live()
                    .installationID()
                try await orchestrator.answerUserRequest(
                    requestId: requestId,
                    answerJson: try answerJson(for: answer),
                    deviceId: deviceId
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
                if let targetCampId =
                    campId ?? codingRanchDashboard?.campId
                {
                    await loadDashboard(campId: targetCampId)
                }
                await startScheduleSystem()
            }
            for await event in stream {
                await handleKernelEvent(event)
            }
        }
    }

    private func handleKernelEvent(_ event: KernelEvent) async {
        switch event {
        case .planningStarted(let missionId):
            reloadMissionList()
            guard currentMissionId == missionId else { return }
            missionPhase = .planning
        case .planCompleted(let missionId, _), .missionChanged(let missionId):
            reloadMissionList()
            notifyScheduledMissionOutcomeIfNeeded(missionId: missionId)
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
        case .operationFailed(let failure):
            reloadMissionList()
            feedNotice = failure.message
            if let currentMissionId {
                reloadMission(missionId: currentMissionId)
            }
            missionPhase = .error(failure.message)
        case .contextDegraded(let notice):
            feedNotice = notice.failure.message
            if let currentMissionId,
               currentMissionId == notice.missionId
            {
                reloadMission(missionId: currentMissionId)
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
        case let .ruminationPhase(
            ingestionId,
            workId,
            attempt,
            phase
        ):
            do {
                let identity = try RuminationPhaseIdentity(
                    ingestionId: ingestionId,
                    workId: workId,
                    attempt: attempt
                )
                await applyRuminationPhase(
                    identity: identity,
                    phase: phase
                )
            } catch {
                ruminationActionError =
                    "反刍阶段身份无效，已停止显示实时进度"
            }
        case let .ruminationChanged(change):
            await applyRuminationChange(change)
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
        Task { [self] in
            let activeCampId: String
            if let campId {
                activeCampId = campId
            } else {
                let trace = operationTraceFactory.generated(
                    operation: .inputCampLoad,
                    scope: .fixed(.application)
                )
                switch await inputWorkflowController.ensureDefaultCamp(
                    trace: trace
                ) {
                case .notCommitted(let failure):
                    showToast(failure.message)
                    return
                case .committed(let receipt),
                     .committedWithVisibilityFailure(let receipt, _):
                    campId = receipt.camp.id
                    campName = receipt.camp.name
                    activeCampId = receipt.camp.id
                }
            }
            let request = memoryKnowledgeProjection.selectGuide(
                activeCampId
            )
            await refreshCampKnowledge(
                request,
                operation: .campKnowledgeLoad
            )
        }
    }

    private func refreshCampKnowledge(
        _ request: MemoryKnowledgeRefreshRequest,
        operation: FailureOperation
    ) async {
        let trace = operationTraceFactory.generated(
            operation: operation,
            scope: .fixed(.memoryGuide)
        )
        let terminal: WorkflowReadTerminal<[CampNoteRecord]>
        switch request.owner {
        case .guide(let ownerCampId):
            terminal = await inputWorkflowController.loadCampNotes(
                campId: ownerCampId,
                trace: trace
            )
        case .companion:
            return
        }
        _ = memoryKnowledgeProjection.apply(terminal, for: request)
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
        if let providerError = error as? ProviderError, providerError == .unauthorized {
            return currentRuntimeProfile?.kind == .chatGPTOAuth
                ? "ChatGPT 登录已过期，请在设置重新登录"
                : "API key 无效或无权限"
        }
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

    private func notifyScheduledMissionOutcomeIfNeeded(missionId: String) {
        let trace = operationTraceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
        Task { [self] in
            switch await missionWorkflowController
                .loadScheduledMissionOutcomePlans(
                    missionId: missionId,
                    trace: trace
                )
            {
            case .loaded(let plans):
                for plan in plans {
                    await publishScheduledMissionOutcomeIfNeeded(plan)
                }
            case .failed(let failure):
                showToast(failure.message)
            case .idle, .loading:
                break
            }
        }
    }

    private func publishScheduledMissionOutcomeIfNeeded(
        _ plan: ScheduledMissionOutcomePlan
    ) async {
        let broadcastKey = "broadcast:\(plan.effectKey)"
        if !sentScheduledMissionNotifications.contains(broadcastKey),
           scheduledMissionOutcomeInFlight.insert(broadcastKey).inserted
        {
            let trace = operationTraceFactory.generated(
                operation: .scheduleBroadcast,
                scope: .fixed(.scheduleIndex)
            )
            let outcome = await missionWorkflowController
                .publishScheduledMissionOutcomeBroadcast(plan, trace: trace)
            scheduledMissionOutcomeInFlight.remove(broadcastKey)
            switch outcome {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed, .committedWithVisibilityFailure:
                if plan.broadcastCampId != nil, plan.broadcastText != nil {
                    sentScheduledMissionNotifications.insert(broadcastKey)
                    if campId == plan.broadcastCampId {
                        reloadGuideMessages()
                    }
                }
            }
        }

        let notificationKey = "notification:\(plan.notification.notificationId)"
        guard !sentScheduledMissionNotifications.contains(notificationKey),
              scheduledMissionOutcomeInFlight.insert(notificationKey).inserted
        else {
            return
        }
        let trace = operationTraceFactory.generated(
            operation: .scheduleNotification,
            scope: .fixed(.notification)
        )
        let outcome = await missionWorkflowController
            .submitScheduleNotification(
                plan.notification,
                notifications: scheduledMissionNotifier.port(),
                trace: trace
            )
        scheduledMissionOutcomeInFlight.remove(notificationKey)
        switch outcome {
        case .notCommitted(let failure):
            showToast(failure.message)
        case .committed(let receipt),
             .committedWithVisibilityFailure(let receipt, _):
            if receipt.disposition == .submitted {
                sentScheduledMissionNotifications.insert(notificationKey)
            }
        }
    }

    func revealArtifact(_ artifact: ArtifactRecord) {
        revealPath(artifact.path)
    }

    func revealPath(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func revealReturnArtifact(_ artifact: ArtifactSummaryViewState) {
        viewedReturnArtifactIDs.insert(artifact.id)
        revealPath(artifact.path)
    }

    func hasViewedReturnArtifact(id: String) -> Bool {
        viewedReturnArtifactIDs.contains(id)
    }

    func openPath(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func reportURL(missionId: String) -> URL? {
        do {
            return try reportStore.reportURL(missionId: missionId)
        } catch {
            showToast("报告定位失败：\(readableError(error))")
            return nil
        }
    }

    @discardableResult
    func ensureReport(missionId: String) -> URL? {
        do {
            return try reportStore.ensureReport(missionId: missionId)
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
        chatStreamID += 1
        let streamID = chatStreamID
        chatCompanionId = companion.id
        chatMessages.append((role: "user", text: text))
        chatMessages.append((role: "companion", text: ""))
        let companionMessageIndex = chatMessages.count - 1
        chatStreaming = true
        chatCoalescer = nil
        let trace = operationTraceFactory.generated(
            operation: .chatSend,
            scope: .fixed(.application)
        )
        chatTask = Task { [self] in
            let terminal = await inputWorkflowController.sendChat(
                companionId: companion.id,
                text: text,
                model: companion.model,
                onEvent: { [weak self] event in
                    guard let self, self.chatStreamID == streamID else {
                        return
                    }
                    if case .textDelta(let text) = event {
                        guard chatMessages.indices.contains(
                            companionMessageIndex
                        ) else {
                            return
                        }
                        chatMessages[companionMessageIndex].text += text
                    }
                },
                isOwnedCancellation: { Task.isCancelled },
                trace: trace
            )
            switch terminal {
            case .finished:
                break
            case .cancelled:
                break
            case .failed(let failure, _):
                if chatStreamID == streamID,
                   chatMessages.indices.contains(companionMessageIndex)
                {
                    chatMessages[companionMessageIndex].text =
                        "（没发出去：\(failure.message)）"
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
        chatCompanionId = companion.id
        chatMessages = []
        let loadID = chatStreamID
        let trace = operationTraceFactory.generated(
            operation: .chatLoad,
            scope: .fixed(.application)
        )
        Task { [self] in
            let terminal = await inputWorkflowController.loadChat(
                companionId: companion.id,
                trace: trace
            )
            guard chatStreamID == loadID,
                  chatCompanionId == companion.id
            else {
                return
            }
            switch terminal {
            case .loaded(let snapshot):
                chatMessages = snapshot.messages.map {
                    (role: $0.role, text: $0.text)
                }
            case .failed(let failure):
                showToast(failure.message)
            case .idle, .loading:
                return
            }
        }
        reloadMemoryNotes(companionId: companion.id)
    }

    // MARK: - 营地首页（M4）

    func loadCampHome(campId targetCampId: String? = nil) {
        campHomeLoadID += 1
        let loadID = campHomeLoadID
        Task { [self] in
            let resolvedCampId: String
            if let targetCampId {
                resolvedCampId = targetCampId
            } else {
                let resolveTrace = operationTraceFactory.generated(
                    operation: .campCreate,
                    scope: .fixed(.application)
                )
                switch await inputWorkflowController.ensureDefaultCamp(
                    trace: resolveTrace
                ) {
                case .notCommitted(let failure):
                    if campHomeLoadID == loadID {
                        showToast(failure.message)
                    }
                    return
                case .committed(let receipt):
                    resolvedCampId = receipt.camp.id
                case .committedWithVisibilityFailure(
                    let receipt,
                    let failure
                ):
                    resolvedCampId = receipt.camp.id
                    if campHomeLoadID == loadID {
                        showToast(failure.message)
                    }
                }
            }
            let trace = operationTraceFactory.generated(
                operation: .inputCampLoad,
                scope: .fixed(.application)
            )
            let terminal = await inputWorkflowController.loadCamp(
                campId: resolvedCampId,
                trace: trace
            )
            guard campHomeLoadID == loadID else { return }
            switch terminal {
            case .loaded(let snapshot):
                applyCampHomeSnapshot(snapshot)
            case .failed(let failure):
                showToast(failure.message)
            case .idle, .loading:
                return
            }
        }
    }

    @discardableResult
    func refreshInputCampProjection(
        campId: String,
        makeVisible: Bool
    ) async -> WorkflowLoadState<InputCampSnapshot> {
        let trace = operationTraceFactory.generated(
            operation: .inputCampLoad,
            scope: .fixed(.application)
        )
        var projection = inputCampProjectionByCampId[campId]
            ?? WorkflowProjection<InputCampSnapshot>()
        let generationCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try projection.beginRefresh()
        }
        let generation: WorkflowRequestGeneration
        switch generationCapture {
        case .value(let value):
            generation = value
        case .failed(let failure):
            globalVisibleFailure = failure
            recordCodingRanchLoadFailure(
                campId: campId,
                message: failure.message,
                makeVisible: makeVisible
            )
            return .failed(failure)
        }
        inputCampProjectionByCampId[campId] = projection

        inputCampTaskByCampId[campId]?.cancel()
        let task = Task { [self] in
            let terminal = await inputWorkflowController.loadCamp(
                campId: campId,
                trace: trace
            )
            guard var current = inputCampProjectionByCampId[campId]
            else {
                return
            }
            let applyCapture = captureSynchronous(
                reporter: failureReporter,
                trace: trace
            ) {
                try current.applyTerminal(
                    terminal,
                    for: generation
                )
            }
            switch applyCapture {
            case .value(false):
                return
            case .failed(let failure):
                globalVisibleFailure = failure
                return
            case .value(true):
                inputCampProjectionByCampId[campId] = current
            }

            switch terminal {
            case .loaded(let snapshot):
                globalVisibleFailure = nil
                reconcileRuminationLiveStages(with: snapshot)
                applyInputCampSnapshot(
                    snapshot,
                    makeVisible: makeVisible
                )
            case .failed(let failure):
                globalVisibleFailure = failure
                recordCodingRanchLoadFailure(
                    campId: campId,
                    message: failure.message,
                    makeVisible: makeVisible
                )
            case .idle, .loading:
                return
            }

            if inputCampProjectionByCampId[campId]?.generation
                == generation
            {
                inputCampTaskByCampId.removeValue(forKey: campId)
            }
        }
        inputCampTaskByCampId[campId] = task
        await task.value
        while let currentTask = inputCampTaskByCampId[campId] {
            await currentTask.value
        }
        return inputCampProjectionByCampId[campId]?.state ?? .idle
    }

    func makeInputOperationTrace(
        operation: FailureOperation
    ) -> OperationTrace {
        operationTraceFactory.generated(
            operation: operation,
            scope: .fixed(.application)
        )
    }

    func makeMissionOperationTrace(
        operation: FailureOperation
    ) -> OperationTrace {
        operationTraceFactory.generated(
            operation: operation,
            scope: .fixed(.missionIndex)
        )
    }

    func capturePlanningRuntimeSelection(
        trace: OperationTrace
    ) -> SynchronousCaptureResult<PlanningEntryRuntimeSelection> {
        captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try planningRuntimeSelection()
        }
    }

    func refreshMissionDetailProjection(
        missionId: String
    ) async -> WorkflowLoadState<MissionDetailSnapshot> {
        let trace = makeMissionOperationTrace(operation: .missionDetailLoad)
        var projection = missionDetailProjectionByMissionId[missionId]
            ?? WorkflowProjection<MissionDetailSnapshot>()
        let generationCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try projection.beginRefresh()
        }
        let generation: WorkflowRequestGeneration
        switch generationCapture {
        case .value(let value):
            generation = value
        case .failed(let failure):
            globalVisibleFailure = failure
            return .failed(failure)
        }
        missionDetailProjectionByMissionId[missionId] = projection
        missionDetailTaskByMissionId[missionId]?.cancel()
        let task = Task { [self] in
            defer {
                if missionDetailProjectionByMissionId[missionId]?.generation
                    == generation
                {
                    missionDetailTaskByMissionId.removeValue(
                        forKey: missionId
                    )
                }
            }
            let terminal = await missionWorkflowController.loadDetail(
                missionId: missionId,
                trace: trace
            )
            guard var current =
                missionDetailProjectionByMissionId[missionId]
            else {
                return
            }
            let applyCapture = captureSynchronous(
                reporter: failureReporter,
                trace: trace
            ) {
                try current.applyTerminal(terminal, for: generation)
            }
            switch applyCapture {
            case .value(false):
                return
            case .failed(let failure):
                globalVisibleFailure = failure
                return
            case .value(true):
                missionDetailProjectionByMissionId[missionId] = current
            }
            switch terminal {
            case .loaded(let snapshot):
                if globalVisibleFailure?.operation == .missionDetailLoad {
                    globalVisibleFailure = nil
                }
                guard currentMissionId == missionId else {
                    return
                }
                missionCards = snapshot.cards
                missionArtifacts = snapshot.artifacts
                pendingRequests = snapshot.pendingRequests
                cardCompanions = snapshot.companionsById
                feedEntries = ActivityFeed.entries(
                    events: snapshot.events,
                    cards: snapshot.cards,
                    companions: snapshot.companionsById
                )
                if let selectedCardId,
                   !snapshot.cards.contains(where: {
                       $0.id == selectedCardId
                   })
                {
                    self.selectedCardId = nil
                }
                switch snapshot.mission.status {
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
            case .failed(let failure):
                globalVisibleFailure = failure
            case .idle, .loading:
                return
            }
        }
        missionDetailTaskByMissionId[missionId] = task
        await task.value
        while let currentTask = missionDetailTaskByMissionId[missionId] {
            await currentTask.value
        }
        return missionDetailProjectionByMissionId[missionId]?.state ?? .idle
    }

    func refreshMissionIndexProjection()
        async -> WorkflowLoadState<MissionIndexSnapshot>
    {
        let trace = makeMissionOperationTrace(operation: .missionIndexLoad)
        var projection = missionIndexProjection
        let generationCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try projection.beginRefresh()
        }
        let generation: WorkflowRequestGeneration
        switch generationCapture {
        case .value(let value):
            generation = value
        case .failed(let failure):
            globalVisibleFailure = failure
            return .failed(failure)
        }
        missionIndexProjection = projection
        missionIndexTask?.cancel()
        let task = Task { [self] in
            defer {
                if missionIndexProjection.generation == generation {
                    missionIndexTask = nil
                }
            }
            let terminal = await missionWorkflowController.loadIndex(
                includeArchived: artifactLedgerIncludeArchived,
                trace: trace
            )
            var current = missionIndexProjection
            let applyCapture = captureSynchronous(
                reporter: failureReporter,
                trace: trace
            ) {
                try current.applyTerminal(terminal, for: generation)
            }
            switch applyCapture {
            case .value(false):
                return
            case .failed(let failure):
                globalVisibleFailure = failure
                return
            case .value(true):
                missionIndexProjection = current
            }
            switch terminal {
            case .loaded(let snapshot):
                if globalVisibleFailure?.operation == .missionIndexLoad {
                    globalVisibleFailure = nil
                }
                missionList = snapshot.missions
                camps = snapshot.camps
                missionsByCamp = snapshot.missionsByCamp
                artifactLedgerItems = snapshot.artifactLedger
            case .failed(let failure):
                globalVisibleFailure = failure
            case .idle, .loading:
                return
            }
        }
        missionIndexTask = task
        await task.value
        while let currentTask = missionIndexTask {
            await currentTask.value
        }
        return missionIndexProjection.state
    }

    func refreshInputReviewProjection(
        ingestionId: String
    ) async -> WorkflowLoadState<InputReviewSnapshot> {
        let trace = operationTraceFactory.generated(
            operation: .inputReviewLoad,
            scope: .fixed(.application)
        )
        var projection = inputReviewProjectionByIngestionId[ingestionId]
            ?? WorkflowProjection<InputReviewSnapshot>()
        let generationCapture = captureSynchronous(
            reporter: failureReporter,
            trace: trace
        ) {
            try projection.beginRefresh()
        }
        let generation: WorkflowRequestGeneration
        switch generationCapture {
        case .value(let value):
            generation = value
        case .failed(let failure):
            globalVisibleFailure = failure
            return .failed(failure)
        }
        inputReviewProjectionByIngestionId[ingestionId] = projection

        inputReviewTaskByIngestionId[ingestionId]?.cancel()
        let task = Task { [self] in
            let terminal = await inputWorkflowController.loadReview(
                ingestionId: ingestionId,
                trace: trace
            )
            guard var current =
                inputReviewProjectionByIngestionId[ingestionId]
            else {
                return
            }
            let applyCapture = captureSynchronous(
                reporter: failureReporter,
                trace: trace
            ) {
                try current.applyTerminal(
                    terminal,
                    for: generation
                )
            }
            switch applyCapture {
            case .value(false):
                return
            case .failed(let failure):
                globalVisibleFailure = failure
                return
            case .value(true):
                inputReviewProjectionByIngestionId[ingestionId] = current
            }

            switch terminal {
            case .loaded:
                if globalVisibleFailure?.operation == .inputReviewLoad {
                    globalVisibleFailure = nil
                }
            case .failed(let failure):
                globalVisibleFailure = failure
            case .idle, .loading:
                return
            }

            if inputReviewProjectionByIngestionId[ingestionId]?.generation
                == generation
            {
                inputReviewTaskByIngestionId.removeValue(
                    forKey: ingestionId
                )
            }
        }
        inputReviewTaskByIngestionId[ingestionId] = task
        await task.value
        while let currentTask = inputReviewTaskByIngestionId[ingestionId] {
            await currentTask.value
        }
        return inputReviewProjectionByIngestionId[ingestionId]?.state
            ?? .idle
    }

    func invalidateInputReviewProjection(ingestionId: String) {
        inputReviewTaskByIngestionId.removeValue(forKey: ingestionId)?
            .cancel()
        inputReviewProjectionByIngestionId.removeValue(forKey: ingestionId)
    }

    private func applyCampHomeSnapshot(_ snapshot: InputCampSnapshot) {
        let camp = snapshot.camp
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
        if let index = camps.firstIndex(where: { $0.id == camp.id }) {
            camps[index] = camp
        } else {
            camps.append(camp)
            camps.sort { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
        }
        missionsByCamp[camp.id] = snapshot.missions
        campId = camp.id
        campName = camp.name
        guideCompanion = snapshot.guide
        reloadCampKnowledge()
        reloadGuideMessages()
    }

    /// 建营地（C2）：返回新营地供导航；失败 toast。
    func createCamp(
        name: String,
        guidePrompt: String?
    ) async -> CampRecord? {
        let trace = operationTraceFactory.generated(
            operation: .campCreate,
            scope: .fixed(.application)
        )
        switch await inputWorkflowController.createCamp(
            name: name,
            guidePrompt: guidePrompt,
            trace: trace
        ) {
        case .notCommitted(let failure):
            showToast(failure.message)
            return nil
        case .committed(let camp):
            upsertCampProjection(camp)
            return camp
        case .committedWithVisibilityFailure(let camp, let failure):
            upsertCampProjection(camp)
            showToast(failure.message)
            return camp
        }
    }

    /// 改名（C3）；当前正看这个营地时同步刷新 header。
    func renameCamp(id: String, name: String) {
        let trace = operationTraceFactory.generated(
            operation: .campRename,
            scope: .fixed(.application)
        )
        Task { [self] in
            switch await inputWorkflowController.renameCamp(
                id: id,
                name: name,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed, .committedWithVisibilityFailure:
                if let index = camps.firstIndex(where: { $0.id == id }) {
                    camps[index].name = name
                }
                if campId == id {
                    campName = name
                }
            }
        }
    }

    @discardableResult
    func setCampArchived(
        id: String,
        archived: Bool
    ) async -> Bool {
        let trace = operationTraceFactory.generated(
            operation: .campArchive,
            scope: .fixed(.application)
        )
        switch await inputWorkflowController.setCampArchived(
            id: id,
            archived: archived,
            trace: trace
        ) {
        case .notCommitted(let failure):
            showToast(failure.message)
            return false
        case .committed(let camp):
            upsertCampProjection(camp)
            showToast(archived ? "营地已归档，可随时恢复。" : "营地已恢复。")
            return true
        case .committedWithVisibilityFailure(let camp, let failure):
            upsertCampProjection(camp)
            showToast(failure.message)
            return true
        }
    }

    @discardableResult
    func retireCow(id: String) async -> Bool {
        let trace = operationTraceFactory.generated(
            operation: .companionRetire,
            scope: .fixed(.application)
        )
        switch await inputWorkflowController.retireCow(
            id: id,
            trace: trace
        ) {
        case .notCommitted(let failure):
            showToast(failure.message)
            return false
        case .committed:
            let refreshMessage = await applyCowRetirementProjection(id: id)
            showToast(
                refreshMessage
                    ?? "这只牛已移出牛群，历史记录仍然保留。"
            )
            return true
        case .committedWithVisibilityFailure(_, let failure):
            globalVisibleFailure = failure
            _ = await applyCowRetirementProjection(id: id)
            showToast("这只牛已移出，但界面刷新失败。\n\(failure.message)")
            return true
        }
    }

    private func applyCowRetirementProjection(
        id: String
    ) async -> String? {
        companions.removeAll { $0.id == id }
        codingRanchDashboardCache.removeAll()
        guard let visibleCampId = campId else { return nil }
        switch await refreshInputCampProjection(
            campId: visibleCampId,
            makeVisible: true
        ) {
        case .failed(let failure):
            return "这只牛已移出，但界面刷新失败。\n\(failure.message)"
        case .idle, .loading:
            recordCodingRanchDiagnostic(
                ProjectionContractError.invalidTerminal,
                operation: "retire-cow-refresh"
            )
            return "这只牛已移出，但界面刷新尚未完成。"
        case .loaded:
            return nil
        }
    }

    func upsertCampProjection(_ camp: CampRecord) {
        if let index = camps.firstIndex(where: { $0.id == camp.id }) {
            camps[index] = camp
        } else {
            camps.append(camp)
            camps.sort { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
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
        guard let targetCampId = campId else { return }
        let loadID = guideStreamID
        let trace = operationTraceFactory.generated(
            operation: .guideChatLoad,
            scope: .fixed(.application)
        )
        Task { [self] in
            let terminal = await inputWorkflowController.loadGuideChat(
                campId: targetCampId,
                trace: trace
            )
            guard campId == targetCampId, guideStreamID == loadID else {
                return
            }
            switch terminal {
            case .loaded(let snapshot):
                guideMessages = snapshot.messages.map {
                    GuideMessage(
                        id: $0.id,
                        role: $0.role,
                        text: $0.text,
                        proposal: $0.proposal
                    )
                }
            case .failed(let failure):
                showToast(failure.message)
            case .idle, .loading:
                return
            }
        }
    }

    func sendGuideChat(text: String) {
        guard !text.isEmpty, !guideStreaming, let campId else { return }
        guideStreamID += 1
        let streamID = guideStreamID
        guideStreaming = true
        guideStreamingText = ""
        guideToolActivity = nil
        guideCoalescer = nil
        let trace = operationTraceFactory.generated(
            operation: .guideChatSend,
            scope: .fixed(.application)
        )
        guideTask = Task { [self] in
            guard await campIsWritable(
                campId,
                archivedMessage: "营地已归档,恢复后才能继续对话"
            ), guideStreamID == streamID else {
                if guideStreamID == streamID {
                    guideStreaming = false
                    guideStreamingText = nil
                    guideTask = nil
                }
                return
            }
            guideMessages.append(
                GuideMessage(
                    id: "local-user-\(streamID)",
                    role: "user",
                    text: text,
                    proposal: nil
                )
            )
            let terminal = await inputWorkflowController.sendGuideChat(
                campId: campId,
                text: text,
                model: defaultModel,
                onEvent: { [weak self] event in
                    guard let self, self.guideStreamID == streamID else {
                        return
                    }
                    switch event {
                    case .textDelta(let delta):
                        guideStreamingText = (guideStreamingText ?? "") + delta
                        guideToolActivity = nil
                    case .toolActivity(let name):
                        guideToolActivity = Self.humanGuideToolName(name)
                    case .proposalCreated:
                        reloadGuideMessages()
                    case .finished:
                        break
                    }
                },
                isOwnedCancellation: { Task.isCancelled },
                trace: trace
            )
            switch terminal {
            case .finished, .cancelled:
                break
            case .failed(let failure, _):
                if guideStreamID == streamID {
                    showToast(failure.message)
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
        let captured: CapturedProposalMissionStart
        do {
            captured = try planningEntryCoordinator.captureConfirmedProposal(
                messageId: messageId,
                runtime: planningRuntimeSelection(),
                fallbackBudget: defaultMissionBudget,
                autonomy: defaultAutonomy
            )
        } catch {
            showToast("建队失败：\(readableError(error))")
            return
        }
        confirmingProposals.insert(messageId)
        Task { [weak self, captured] in
            guard let self else { return }
            do {
                let missionId =
                    try await planningEntryCoordinator.startConfirmedProposal(
                        captured
                    )
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
            let terminal = await MemoryDistillService(db: db, provider: provider)
                .distillGuideChat(campId: campId)
            distillingGuideChat = false
            switch terminal {
            case .noEligibleInput:
                showToast("这段对话还没有可沉淀的内容")
            case .skipped:
                showToast("这段对话暂时没什么可记的")
            case .created(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
                showToast("已沉淀 1 条营地笔记")
            case .failed(let failure):
                showToast(failure.message)
            }
        }
    }

    // MARK: - 营地笔记 CRUD（M4）

    func saveCampNoteEdits(_ note: CampNoteRecord) {
        var updated = note
        updated.updatedAt = Date()
        Task { [self] in
            guard await campIsWritable(
                note.campId,
                archivedMessage: "营地已归档,恢复后才能编辑笔记"
            ) else { return }
            let trace = operationTraceFactory.generated(
                operation: .campNoteSave,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.saveCampNote(
                updated,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
            case .committedWithVisibilityFailure(
                let record,
                let failure
            ):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
                showToast(failure.message)
            }
        }
    }

    func deleteCampNote(id: String) {
        guard let note = campNotes.first(where: { $0.id == id }) else {
            showToast("笔记不存在或已被删除")
            return
        }
        Task { [self] in
            guard await campIsWritable(
                note.campId,
                archivedMessage: "营地已归档,恢复后才能删除笔记"
            ) else { return }
            let trace = operationTraceFactory.generated(
                operation: .campNoteDelete,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.deleteCampNote(
                id: id,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed, .committedWithVisibilityFailure:
                let request = memoryKnowledgeProjection
                    .beginGuideRefresh(campId: note.campId)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
            }
        }
    }

    func toggleCampNotePin(_ note: CampNoteRecord) {
        var updated = note
        updated.pinned.toggle()
        updated.updatedAt = Date()
        Task { [self] in
            guard await campIsWritable(
                note.campId,
                archivedMessage: "营地已归档,恢复后才能编辑笔记"
            ) else { return }
            let trace = operationTraceFactory.generated(
                operation: .campNotePin,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.pinCampNote(
                updated,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
            case .committedWithVisibilityFailure(
                let record,
                let failure
            ):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
                showToast(failure.message)
            }
        }
    }

    private func campIsWritable(
        _ campId: String,
        archivedMessage: String
    ) async -> Bool {
        let trace = operationTraceFactory.generated(
            operation: .campWritableRead,
            scope: .fixed(.application)
        )
        switch await inputWorkflowController.campWritable(
            id: campId,
            trace: trace
        ) {
        case .loaded(true):
            return true
        case .loaded(false):
            showToast(archivedMessage)
        case .failed(let failure):
            showToast(failure.message)
        case .idle, .loading:
            showToast("营地状态暂时不可用")
        }
        return false
    }

    // MARK: - 伙伴记忆（M4）

    func reloadMemoryNotes(companionId: String) {
        let request = memoryKnowledgeProjection.selectCompanion(companionId)
        Task { [self] in
            await refreshMemoryNotes(
                request,
                operation: .memoryNoteLoad
            )
        }
    }

    private func refreshMemoryNotes(
        _ request: MemoryKnowledgeRefreshRequest,
        operation: FailureOperation
    ) async {
        let trace = operationTraceFactory.generated(
            operation: operation,
            scope: .fixed(.memoryDM)
        )
        let terminal: WorkflowReadTerminal<[CompanionNoteRecord]>
        switch request.owner {
        case .companion(let companionId):
            terminal = await inputWorkflowController.loadMemoryNotes(
                companionId: companionId,
                trace: trace
            )
        case .guide:
            return
        }
        _ = memoryKnowledgeProjection.apply(terminal, for: request)
    }

    func retryMemoryDistillationVisibility(cardId: UUID) {
        guard let request = memoryKnowledgeProjection
            .beginVisibilityRetry(cardId: cardId)
        else {
            return
        }
        Task { [self] in
            switch request.owner {
            case .companion:
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
            case .guide:
                await refreshCampKnowledge(
                    request,
                    operation: .campKnowledgeLoad
                )
            }
        }
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
            let terminal = await MemoryDistillService(db: db, provider: provider)
                .distillDM(companionId: companion.id, minMessages: 1)
            distillingMemory = false
            switch terminal {
            case .noEligibleInput:
                showToast("还没有可沉淀的对话")
            case .skipped:
                showToast("暂时没什么要记的")
            case .created(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
                showToast("已记住这段对话")
            case .failed(let failure):
                showToast(failure.message)
            }
        }
    }

    /// 切走 DM 线程时的自动沉淀（D7：未蒸馏增量 ≥4 条才触发，后台静默）
    func autoDistillOnLeave(companionId: String) {
        // 预览模式不触发（避免钥匙串弹窗）；正常模式无 key 时静默跳过
        guard !Self.isUIPreview, let provider = provider(model: effectiveDistillModel) else { return }
        guard autoDistillInFlight.insert(companionId).inserted else { return }
        Task { [weak self] in
            guard let self else { return }
            let terminal = await MemoryDistillService(db: db, provider: provider)
                .distillDM(companionId: companionId, minMessages: MemoryDistillService.autoMinMessages)
            autoDistillInFlight.remove(companionId)
            switch terminal {
            case .noEligibleInput:
                break
            case .skipped:
                showToast("这段私聊暂时没有值得长期记住的内容")
            case .created(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
                showToast("这段私聊已沉淀为记忆")
            case .failed(let failure):
                showToast(failure.message)
            }
        }
    }

    func saveMemoryEdits(_ note: CompanionNoteRecord) {
        var updated = note
        updated.updatedAt = Date()
        Task { [self] in
            let trace = operationTraceFactory.generated(
                operation: .memoryNoteSave,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.saveMemoryNote(
                updated,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
            case .committedWithVisibilityFailure(
                let record,
                let failure
            ):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
                showToast(failure.message)
            }
        }
    }

    func deleteMemoryNote(id: String, companionId: String) {
        Task { [self] in
            let trace = operationTraceFactory.generated(
                operation: .memoryNoteDelete,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.deleteMemoryNote(
                id: id,
                companionId: companionId,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed, .committedWithVisibilityFailure:
                let request = memoryKnowledgeProjection
                    .beginCompanionRefresh(companionId: companionId)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
            }
        }
    }

    func toggleMemoryPin(_ note: CompanionNoteRecord) {
        var updated = note
        updated.pinned.toggle()
        updated.updatedAt = Date()
        Task { [self] in
            let trace = operationTraceFactory.generated(
                operation: .memoryNotePin,
                scope: .fixed(.application)
            )
            switch await inputWorkflowController.pinMemoryNote(
                updated,
                trace: trace
            ) {
            case .notCommitted(let failure):
                showToast(failure.message)
            case .committed(let record):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
            case .committedWithVisibilityFailure(
                let record,
                let failure
            ):
                let request = memoryKnowledgeProjection
                    .beginCommittedRefresh(record)
                await refreshMemoryNotes(
                    request,
                    operation: .memoryNoteLoad
                )
                showToast(failure.message)
            }
        }
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

@MainActor
extension AppStore {
    @discardableResult
    func executeRuminationCommand(
        ingestionId: String,
        expectedCampId: String? = nil
    ) async throws -> DurableWorkRecord {
        guard let targetCampId =
            expectedCampId
                ?? codingRanchIngestionCampIds[ingestionId]
        else {
            throw RuminationStartRecoveryRequiredError(
                ingestionId: ingestionId
            )
        }

        guard let runtime = runtimeProjection.lastLoadedValue else {
            throw RuminationStartRecoveryRequiredError(
                ingestionId: ingestionId
            )
        }
        let runtimeProfileId: String
        let model: String
        switch runtime.legacyRuminationSnapshot {
        case .valid(let profileId, let selectedModel):
            runtimeProfileId = profileId
            model = selectedModel
        case .legacyProfileUnresolved, .legacyModelUnavailable,
             .legacyProfileCLIUnsupported:
            throw RuminationStartRecoveryRequiredError(
                ingestionId: ingestionId
            )
        }
        let trace = operationTraceFactory.generated(
            operation: .inputRuminationStart,
            scope: .fixed(.application)
        )
        switch await inputWorkflowController.startRumination(
            ingestionId: ingestionId,
            expectedCampId: targetCampId,
            model: model,
            runtimeProfileId: runtimeProfileId,
            trace: trace
        ) {
        case .notCommitted(let failure):
            globalVisibleFailure = failure
            throw UserVisibleOperationError(failure: failure)
        case .committed(let receipt):
            applyRuminationStartReceipt(receipt)
            if globalVisibleFailure?.operation == .inputRuminationStart {
                globalVisibleFailure = nil
            }
            return receipt.work
        case .committedWithVisibilityFailure(let receipt, let failure):
            applyRuminationStartReceipt(receipt)
            globalVisibleFailure = failure
            let message = receipt.refreshedCamp == nil
                ? "反刍已经开始，但界面刷新失败。请切换营地或稍后重试。"
                : failure.message
            ruminationActionError = message
            showToast(message)
            return receipt.work
        }
    }

    func applyRuminationStartReceipt(
        _ receipt: InputRuminationStartReceipt
    ) {
        guard let snapshot = receipt.refreshedCamp else { return }
        let targetCampId = snapshot.camp.id
        reconcileRuminationLiveStages(with: snapshot)
        applyInputCampSnapshot(
            snapshot,
            makeVisible: campId == targetCampId
        )
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
