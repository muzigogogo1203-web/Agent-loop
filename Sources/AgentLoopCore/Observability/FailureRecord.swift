import Foundation
import GRDB

public enum FailureOperation: String, Codable, Sendable, CaseIterable {
    case applicationBootstrap = "application.bootstrap"
    case runtimeBootstrap = "runtime.bootstrap"
    case runtimeLoad = "runtime.load"
    case runtimeProviderResolve = "runtime.provider.resolve"
    case runtimeSearchResolve = "runtime.search.resolve"
    case runtimeProfileSave = "runtime.profile.save"
    case runtimeProfileDelete = "runtime.profile.delete"
    case runtimeProfileSwitch = "runtime.profile.switch"
    case runtimeCatalogRefresh = "runtime.catalog.refresh"
    case runtimeProviderTest = "runtime.provider.test"
    case runtimeCredentialSet = "runtime.credential.set"
    case runtimeCredentialDelete = "runtime.credential.delete"
    case oauthAuthorization = "oauth.authorization"
    case oauthCallbackExchange = "oauth.callback.exchange"
    case oauthRefreshCommit = "oauth.refresh.commit"
    case oauthUnauthorizedDelete = "oauth.unauthorized.delete"
    case missionIndexLoad = "mission.index.load"
    case missionDetailLoad = "mission.detail.load"
    case missionStart = "mission.start"
    case missionCancel = "mission.cancel"
    case missionHarvest = "mission.harvest"
    case missionAccept = "mission.accept"
    case missionAnswer = "mission.answer"
    case missionConfirmProposal = "mission.proposal.confirm"
    case missionRetryContext = "mission.context.retry"
    case missionReturnForRework = "mission.rework"
    case missionAddBudget = "mission.budget.add"
    case missionBudgetEvent = "mission.budget.event"
    case missionRateLimitEvent = "mission.rate_limit.event"
    case missionRetryCard = "mission.card.retry"
    case missionClearReview = "mission.card.review.clear"
    case missionAutonomyWrite = "mission.autonomy.write"
    case missionProposalDismiss = "mission.proposal.dismiss"
    case missionReportEnsure = "mission.report.ensure"
    case missionReportOpen = "mission.report.open"
    case missionRunFinish = "mission.run.finish"
    case inputCampLoad = "input.camp.load"
    case inputReviewLoad = "input.review.load"
    case inputFeedSubmit = "input.feed.submit"
    case inputRuminationStart = "input.rumination.start"
    case inputRuminationCancel = "input.rumination.cancel"
    case inputReviewSave = "input.review.save"
    case inputMaterialize = "input.materialize"
    case inputDelete = "input.delete"
    case inputMissionDraft = "input.mission_draft.create"
    case inputCowUnlock = "input.cow.unlock"
    case campRename = "camp.rename"
    case campCreate = "camp.create"
    case campArchive = "camp.archive"
    case campWritableRead = "camp.writable.read"
    case campNoteSave = "camp.note.save"
    case campNoteDelete = "camp.note.delete"
    case campNotePin = "camp.note.pin"
    case campKnowledgeLoad = "camp.knowledge.load"
    case companionEditorLoad = "companion.editor.load"
    case companionEditorSave = "companion.editor.save"
    case companionRetire = "companion.retire"
    case memoryDMDistill = "memory.dm.distill"
    case memoryGuideDistill = "memory.guide.distill"
    case memoryNoteLoad = "memory.note.load"
    case memoryNoteSave = "memory.note.save"
    case memoryNoteDelete = "memory.note.delete"
    case memoryNotePin = "memory.note.pin"
    case mcpRegistryLoad = "mcp.registry.load"
    case mcpCampLoad = "mcp.camp.load"
    case mcpToolList = "mcp.tool.list"
    case mcpServerStart = "mcp.server.start"
    case mcpServerRestart = "mcp.server.restart"
    case mcpSecretPresence = "mcp.secret.presence"
    case mcpSecretSave = "mcp.secret.save"
    case mcpServerAdd = "mcp.server.add"
    case mcpSetEnabled = "mcp.server.enable"
    case mcpServerDelete = "mcp.server.delete"
    case mcpToolCall = "mcp.tool.call"
    case contextToolAccess = "context.tool_access"
    case contextSearch = "context.search"
    case contextMcpServer = "context.mcp.server"
    case contextMcpTool = "context.mcp.tool"
    case contextCampNotes = "context.camp_notes"
    case contextCompanionNotes = "context.companion_notes"
    case scheduleLoad = "schedule.load"
    case scheduleTemplateSave = "schedule.template.save"
    case scheduleTemplateDelete = "schedule.template.delete"
    case scheduleSave = "schedule.save"
    case scheduleEnable = "schedule.enable"
    case scheduleDelete = "schedule.delete"
    case scheduleNotification = "schedule.notification"
    case scheduleRefresh = "schedule.refresh"
    case scheduleFire = "schedule.fire"
    case scheduleReplay = "schedule.replay"
    case scheduleWake = "schedule.wake"
    case scheduleBroadcast = "schedule.broadcast"
    case haltRead = "halt.read"
    case haltPersist = "halt.persist"
    case dispatchResume = "dispatch.resume"
    case reconcile = "dispatch.reconcile"
    case startupRecovery = "startup.recovery"
    case chatLoad = "chat.load"
    case chatSend = "chat.send"
    case guideChatLoad = "guide_chat.load"
    case guideChatSend = "guide_chat.send"
    case projectionApply = "projection.apply"
    case previewRuntimeRead = "preview.runtime.read"

    public var accessibilityLabel: String {
        switch self {
        case .applicationBootstrap:
            return "应用启动"
        case .runtimeBootstrap, .runtimeLoad, .runtimeProviderResolve,
             .runtimeSearchResolve, .runtimeProfileSave,
             .runtimeProfileDelete, .runtimeProfileSwitch,
             .runtimeCatalogRefresh, .runtimeProviderTest,
             .runtimeCredentialSet, .runtimeCredentialDelete:
            return "运行供给线"
        case .oauthAuthorization, .oauthCallbackExchange,
             .oauthRefreshCommit, .oauthUnauthorizedDelete:
            return "网页登录"
        case .missionIndexLoad, .missionDetailLoad, .missionStart,
             .missionCancel, .missionHarvest, .missionAccept,
             .missionAnswer, .missionConfirmProposal,
             .missionRetryContext, .missionReturnForRework,
             .missionAddBudget, .missionBudgetEvent,
             .missionRateLimitEvent, .missionRetryCard,
             .missionClearReview, .missionAutonomyWrite,
             .missionProposalDismiss, .missionReportEnsure,
             .missionReportOpen, .missionRunFinish:
            return "任务执行"
        case .inputCampLoad, .inputReviewLoad, .inputFeedSubmit,
             .inputRuminationStart, .inputRuminationCancel,
             .inputReviewSave, .inputMaterialize, .inputDelete,
             .inputMissionDraft, .inputCowUnlock:
            return "资料处理"
        case .campRename, .campCreate, .campArchive, .campWritableRead,
             .campNoteSave, .campNoteDelete, .campNotePin,
             .campKnowledgeLoad:
            return "营地管理"
        case .companionEditorLoad, .companionEditorSave,
             .companionRetire:
            return "伙伴设置"
        case .memoryDMDistill, .memoryGuideDistill, .memoryNoteLoad,
             .memoryNoteSave, .memoryNoteDelete, .memoryNotePin:
            return "记忆整理"
        case .mcpRegistryLoad, .mcpCampLoad, .mcpToolList,
             .mcpServerStart, .mcpServerRestart, .mcpSecretPresence,
             .mcpSecretSave, .mcpServerAdd, .mcpSetEnabled,
             .mcpServerDelete, .mcpToolCall:
            return "外部工具"
        case .contextToolAccess, .contextSearch, .contextMcpServer,
             .contextMcpTool, .contextCampNotes, .contextCompanionNotes:
            return "上下文准备"
        case .scheduleLoad, .scheduleTemplateSave,
             .scheduleTemplateDelete, .scheduleSave, .scheduleEnable,
             .scheduleDelete, .scheduleNotification, .scheduleRefresh,
             .scheduleFire, .scheduleReplay, .scheduleWake,
             .scheduleBroadcast:
            return "定时行动"
        case .haltRead, .haltPersist, .dispatchResume, .reconcile,
             .startupRecovery:
            return "牧场调度"
        case .chatLoad, .chatSend, .guideChatLoad, .guideChatSend:
            return "对话"
        case .projectionApply:
            return "界面状态更新"
        case .previewRuntimeRead:
            return "预览验证"
        }
    }
}

public enum FailureSeverity: String, Codable, Sendable, CaseIterable {
    case info, warning, error, critical
}

public enum FailureCode: String, Codable, Sendable, CaseIterable {
    case databaseReadFailed = "database_read_failed"
    case databaseWriteFailed = "database_write_failed"
    case recordNotFound = "record_not_found"
    case projectionDecodeFailed = "projection_decode_failed"
    case projectionContractFailed = "projection_contract_failed"
    case keychainReadFailed = "keychain_read_failed"
    case keychainWriteFailed = "keychain_write_failed"
    case keychainDeleteFailed = "keychain_delete_failed"
    case credentialValueInvalid = "credential_value_invalid"
    case oauthStateInvalid = "oauth_state_invalid"
    case oauthAuthorizationFailed = "oauth_authorization_failed"
    case oauthListenerFailed = "oauth_listener_failed"
    case oauthTokenExchangeFailed = "oauth_token_exchange_failed"
    case oauthCredentialCommitFailed = "oauth_credential_commit_failed"
    case oauthCredentialRollbackFailed = "oauth_credential_rollback_failed"
    case oauthCredentialDeleteFailed = "oauth_credential_delete_failed"
    case runtimeProfileReadFailed = "runtime_profile_read_failed"
    case runtimeProfileWriteFailed = "runtime_profile_write_failed"
    case runtimeProfileDeleteFailed = "runtime_profile_delete_failed"
    case runtimeReconcileFailed = "runtime_reconcile_failed"
    case runtimeProviderUnavailable = "runtime_provider_unavailable"
    case runtimeModelUnsupported = "runtime_model_unsupported"
    case runtimeEndpointInvalid = "runtime_endpoint_invalid"
    case missionReadFailed = "mission_read_failed"
    case missionWriteFailed = "mission_write_failed"
    case missionTransitionFailed = "mission_transition_failed"
    case missionVisibilityFailed = "mission_visibility_failed"
    case traceIdentityConflict = "trace_identity_conflict"
    case proposalRecoveryFailed = "proposal_recovery_failed"
    case ruminationReadFailed = "rumination_read_failed"
    case ruminationStartFailed = "rumination_start_failed"
    case ruminationCancelFailed = "rumination_cancel_failed"
    case mcpRegistryReadFailed = "mcp_registry_read_failed"
    case mcpServerNotFound = "mcp_server_not_found"
    case mcpConfigInvalid = "mcp_config_invalid"
    case mcpSecretMissing = "mcp_secret_missing"
    case mcpSecretReadFailed = "mcp_secret_read_failed"
    case mcpSecretWriteFailed = "mcp_secret_write_failed"
    case mcpSecretDeleteFailed = "mcp_secret_delete_failed"
    case mcpSecretRollbackFailed = "mcp_secret_rollback_failed"
    case mcpStartFailed = "mcp_start_failed"
    case mcpToolListFailed = "mcp_tool_list_failed"
    case mcpRequiredToolMissing = "mcp_required_tool_missing"
    case mcpConnectionDown = "mcp_connection_down"
    case mcpToolCallFailed = "mcp_tool_call_failed"
    case mcpServerMaintenance = "mcp_server_maintenance"
    case knowledgeReadFailed = "knowledge_read_failed"
    case contextDependencyRequiredFailed = "context_dependency_required_failed"
    case contextDependencyOptionalFailed = "context_dependency_optional_failed"
    case contextBackendCapabilityUnsupported = "context_backend_capability_unsupported"
    case memoryOwnerNotFound = "memory_owner_not_found"
    case memoryThreadInvariantFailed = "memory_thread_invariant_failed"
    case memoryReadFailed = "memory_read_failed"
    case memoryProviderFailed = "memory_provider_failed"
    case memoryWriteFailed = "memory_write_failed"
    case memoryRaceLost = "memory_race_lost"
    case notificationProjectionFailed = "notification_projection_failed"
    case schedulePlatformFailed = "schedule_platform_failed"
    case lifecycleBlocked = "lifecycle_blocked"
    case cleanupIntegrityFailed = "cleanup_integrity_failed"
    case operationCancelled = "operation_cancelled"
    case unexpectedFailure = "unexpected_failure"
}

public enum FailureMetadataValidationError: Error, Sendable, Equatable {
    case invalidTraceId
    case invalidRecordId
    case invalidCoordinate
    case invalidUserMessage
    case invalidDiagnostics
}

public enum FailureScopeType: String, Codable, Sendable, CaseIterable {
    case application, database, credential, oauth, camp, mission, card
    case ingestion, companion
    case runtimeProfile = "runtime_profile"
    case campNote = "camp_note"
    case companionNote = "companion_note"
    case mcpServer = "mcp_server"
    case mcpTool = "mcp_tool"
    case schedule, notification, projection
}

package enum FailureRecordKind: String, Sendable, Equatable, Hashable {
    case camp, mission, card, ingestion, runtimeProfile, companion
    case campNote, companionNote, mcpServer, schedule
}

public struct FailureRecordID: Sendable, Equatable, Hashable {
    public let rawValue: String
    package let recordKind: FailureRecordKind

    private init(
        validatedRawValue: String,
        recordKind: FailureRecordKind
    ) {
        rawValue = validatedRawValue
        self.recordKind = recordKind
    }

    package static func camp(_ record: CampRecord) throws -> Self {
        try make(record.id, kind: .camp)
    }

    package static func mission(_ record: MissionRecord) throws -> Self {
        try make(record.id, kind: .mission)
    }

    package static func card(_ record: CardRecord) throws -> Self {
        try make(record.id, kind: .card)
    }

    package static func ingestion(_ record: IngestionItemRecord) throws -> Self {
        try make(record.id, kind: .ingestion)
    }

    package static func runtimeProfile(
        _ record: RuntimeProfileRecord
    ) throws -> Self {
        try make(record.id, kind: .runtimeProfile)
    }

    package static func companion(_ record: CompanionRecord) throws -> Self {
        try make(record.id, kind: .companion)
    }

    package static func campNote(_ record: CampNoteRecord) throws -> Self {
        try make(record.id, kind: .campNote)
    }

    package static func companionNote(
        _ record: CompanionNoteRecord
    ) throws -> Self {
        try make(record.id, kind: .companionNote)
    }

    package static func mcpServer(_ record: McpServerRecord) throws -> Self {
        try make(record.id, kind: .mcpServer)
    }

    package static func schedule(_ record: ScheduleRecord) throws -> Self {
        try make(record.id, kind: .schedule)
    }

    private static func make(
        _ rawValue: String,
        kind: FailureRecordKind
    ) throws -> Self {
        guard FailureMetadataGrammar.isSafeID(rawValue) else {
            throw FailureMetadataValidationError.invalidRecordId
        }
        return Self(validatedRawValue: rawValue, recordKind: kind)
    }
}

package enum FailureFixedCoordinate:
    String, Sendable, Equatable, CaseIterable
{
    case application, database, runtime, runtimeBootstrap
    case credential, oauth, missionIndex, mcpRegistry, scheduleIndex
    case notification, projection, preview
    case memoryDM = "memory_dm"
    case memoryGuide = "memory_guide"
}

public struct FailureScope: Sendable, Equatable {
    public let campId: String?
    public let type: FailureScopeType
    public let id: String

    fileprivate init(
        campId: String?,
        type: FailureScopeType,
        id: String
    ) {
        self.campId = campId
        self.type = type
        self.id = id
    }

    package static func validatingPersistedRow(
        scopeType: String,
        scopeId: String,
        campId: String?
    ) throws -> Self {
        guard let type = FailureScopeType(rawValue: scopeType),
              FailureMetadataGrammar.isSafeID(scopeId),
              campId.map(FailureMetadataGrammar.isSafeID) ?? true
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }

        if let campId {
            guard FailureTraceScope.campAllowedTypes.contains(type) else {
                throw FailureMetadataValidationError.invalidCoordinate
            }
            return Self(campId: campId, type: type, id: scopeId)
        }

        if let fixed = FailureTraceScope.fixedScope(for: type, id: scopeId) {
            return fixed
        }
        guard FailureTraceScope.globalRecordTypes.contains(type) else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        return Self(campId: nil, type: type, id: scopeId)
    }
}

package struct FailureTraceScope: Sendable, Equatable {
    fileprivate let value: FailureScope

    fileprivate static let campAllowedTypes: Set<FailureScopeType> = [
        .mission, .card, .ingestion, .companion, .campNote,
        .companionNote, .mcpServer, .mcpTool, .schedule,
    ]

    fileprivate static let globalRecordTypes: Set<FailureScopeType> = [
        .runtimeProfile, .camp, .mission, .card, .ingestion, .companion,
        .mcpServer, .mcpTool, .schedule, .notification,
    ]

    package static func fixed(_ coordinate: FailureFixedCoordinate) -> Self {
        let pair: (FailureScopeType, String)
        switch coordinate {
        case .application: pair = (.application, "application")
        case .database: pair = (.database, "database")
        case .runtime: pair = (.runtimeProfile, "runtime")
        case .runtimeBootstrap: pair = (.runtimeProfile, "runtime_bootstrap")
        case .credential: pair = (.credential, "credential")
        case .oauth: pair = (.oauth, "oauth")
        case .missionIndex: pair = (.mission, "mission_index")
        case .mcpRegistry: pair = (.mcpServer, "mcp_registry")
        case .scheduleIndex: pair = (.schedule, "schedule_index")
        case .notification: pair = (.notification, "notification")
        case .projection: pair = (.projection, "projection")
        case .preview: pair = (.projection, "preview")
        case .memoryDM: pair = (.application, "memory_dm")
        case .memoryGuide: pair = (.application, "memory_guide")
        }
        return Self(
            value: FailureScope(campId: nil, type: pair.0, id: pair.1)
        )
    }

    package static func global(
        recordId: FailureRecordID,
        as type: FailureScopeType
    ) throws -> Self {
        guard expectedKind(for: type) == recordId.recordKind,
              globalRecordTypes.contains(type)
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        return Self(
            value: FailureScope(
                campId: nil,
                type: type,
                id: recordId.rawValue
            )
        )
    }

    package static func camp(
        campId: FailureRecordID,
        recordId: FailureRecordID,
        as type: FailureScopeType
    ) throws -> Self {
        guard campId.recordKind == .camp,
              campAllowedTypes.contains(type),
              expectedKind(for: type) == recordId.recordKind
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        return Self(
            value: FailureScope(
                campId: campId.rawValue,
                type: type,
                id: recordId.rawValue
            )
        )
    }

    fileprivate static func fixedScope(
        for type: FailureScopeType,
        id: String
    ) -> FailureScope? {
        for coordinate in FailureFixedCoordinate.allCases {
            let scope = fixed(coordinate).value
            if scope.type == type, scope.id == id {
                return scope
            }
        }
        return nil
    }

    private static func expectedKind(
        for type: FailureScopeType
    ) -> FailureRecordKind? {
        switch type {
        case .camp: return .camp
        case .mission, .notification: return .mission
        case .card: return .card
        case .ingestion: return .ingestion
        case .runtimeProfile: return .runtimeProfile
        case .companion: return .companion
        case .campNote: return .campNote
        case .companionNote: return .companionNote
        case .mcpServer, .mcpTool: return .mcpServer
        case .schedule: return .schedule
        case .application, .database, .credential, .oauth, .projection:
            return nil
        }
    }
}

public struct OperationTrace: Sendable, Equatable {
    public let traceId: String
    public let operation: FailureOperation
    public let scope: FailureScope
    package let traceScope: FailureTraceScope
    public let startedAt: Date

    fileprivate init(
        validatedTraceId: String,
        operation: FailureOperation,
        traceScope: FailureTraceScope,
        startedAt: Date
    ) {
        traceId = validatedTraceId
        self.operation = operation
        scope = traceScope.value
        self.traceScope = traceScope
        self.startedAt = startedAt
    }
}

package struct OperationTraceFactory: Sendable {
    package static let live = OperationTraceFactory(
        makeID: { UUID() },
        now: { Date() }
    )

    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    package init(
        makeID: @escaping @Sendable () -> UUID,
        now: @escaping @Sendable () -> Date
    ) {
        self.makeID = makeID
        self.now = now
    }

    package func generated(
        operation: FailureOperation,
        scope: FailureTraceScope
    ) -> OperationTrace {
        OperationTrace(
            validatedTraceId: makeID().uuidString,
            operation: operation,
            traceScope: scope,
            startedAt: now()
        )
    }

    package func adopting(
        _ durableTraceId: String,
        operation: FailureOperation,
        scope: FailureTraceScope
    ) throws -> OperationTrace {
        guard FailureMetadataGrammar.isSafeID(durableTraceId) else {
            throw FailureMetadataValidationError.invalidTraceId
        }
        return OperationTrace(
            validatedTraceId: durableTraceId,
            operation: operation,
            traceScope: scope,
            startedAt: now()
        )
    }
}

enum FailureMetadataGrammar {
    static func isSafeID(_ value: String) -> Bool {
        guard (1...128).contains(value.utf8.count),
              value.unicodeScalars.count == value.utf8.count
        else {
            return false
        }
        return value.utf8.allSatisfy { byte in
            switch byte {
            case 48...57, 65...90, 97...122, 46, 58, 95, 45:
                return true
            default:
                return false
            }
        }
    }
}

package struct RuntimeCredentialResolutionError:
    LocalizedError, Sendable, Equatable
{
    package enum Kind: Sendable, Equatable {
        case runtimeProfileReadFailed
        case defaultProfileNotFound
        case companionNotFound
        case selectedProfileNotFound
        case modelCatalogUnavailable
        case runtimeModelUnsupported
        case credentialAccountMissing
        case credentialValueInvalid
        case credentialReadFailed
        case keychainReadFailed(osStatus: Int32)
        case oauthAccountIdNotFound
        case endpointInvalid
    }

    package let kind: Kind

    package init(_ kind: Kind) {
        self.kind = kind
    }

    package var code: String { failureCode.rawValue }

    package var failureCode: FailureCode {
        switch kind {
        case .runtimeProfileReadFailed:
            return .runtimeProfileReadFailed
        case .defaultProfileNotFound, .companionNotFound,
             .selectedProfileNotFound, .modelCatalogUnavailable,
             .credentialAccountMissing, .oauthAccountIdNotFound:
            return .runtimeProviderUnavailable
        case .runtimeModelUnsupported:
            return .runtimeModelUnsupported
        case .credentialValueInvalid:
            return .credentialValueInvalid
        case .credentialReadFailed, .keychainReadFailed:
            return .keychainReadFailed
        case .endpointInvalid:
            return .runtimeEndpointInvalid
        }
    }

    package var retryable: Bool {
        switch kind {
        case .runtimeProfileReadFailed, .modelCatalogUnavailable,
             .credentialReadFailed, .keychainReadFailed:
            return true
        case .defaultProfileNotFound, .companionNotFound,
             .selectedProfileNotFound, .runtimeModelUnsupported,
             .credentialAccountMissing, .credentialValueInvalid,
             .oauthAccountIdNotFound, .endpointInvalid:
            return false
        }
    }

    package var osStatus: Int32? {
        switch kind {
        case .keychainReadFailed(let status):
            return status
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .credentialValueInvalid,
             .credentialReadFailed, .oauthAccountIdNotFound,
             .endpointInvalid:
            return nil
        }
    }

    package var diagnosticCategory: FailureDiagnosticCategory {
        switch kind {
        case .credentialValueInvalid, .credentialReadFailed,
             .keychainReadFailed, .oauthAccountIdNotFound:
            return .credential
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .endpointInvalid:
            return .runtime
        }
    }

    package var diagnosticDomain: FailureDiagnosticDomain {
        switch kind {
        case .credentialValueInvalid, .credentialReadFailed,
             .keychainReadFailed, .oauthAccountIdNotFound:
            return .keychain
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .endpointInvalid:
            return .runtime
        }
    }

    package var safeMessage: String {
        switch kind {
        case .runtimeProfileReadFailed:
            return "无法读取供给线配置。"
        case .defaultProfileNotFound:
            return "默认供给线不存在。"
        case .companionNotFound:
            return "所选伙伴不存在。"
        case .selectedProfileNotFound:
            return "所选供给线不存在。"
        case .modelCatalogUnavailable:
            return "供给线的模型目录不可用。"
        case .runtimeModelUnsupported:
            return "所选模型不受当前供给线支持。"
        case .credentialAccountMissing:
            return "供给线缺少凭据账户配置。"
        case .credentialValueInvalid:
            return "凭据格式无效。"
        case .credentialReadFailed, .keychainReadFailed:
            return "无法读取供给线凭据。"
        case .oauthAccountIdNotFound:
            return "ChatGPT 账户标识不存在。"
        case .endpointInvalid:
            return "供给线的 API 端点无效。"
        }
    }

    package var errorDescription: String? { safeMessage }
}

public struct UserVisibleFailure: Sendable, Equatable {
    public let traceId: String
    public let operation: FailureOperation
    public let scope: FailureScope
    public let message: String

    fileprivate init(
        validatedTrace trace: OperationTrace,
        message: String
    ) {
        traceId = trace.traceId
        operation = trace.operation
        scope = trace.scope
        self.message = message
    }
}

public struct UserVisibleOperationError:
    Error, LocalizedError, Sendable, Equatable
{
    public let failure: UserVisibleFailure
    public var errorDescription: String? { failure.message }

    package init(failure: UserVisibleFailure) {
        self.failure = failure
    }
}

package enum OperationCommitOutcome<Value: Sendable>: Sendable {
    case notCommitted(UserVisibleFailure)
    case committed(Value)
    case committedWithVisibilityFailure(
        value: Value,
        failure: UserVisibleFailure
    )
}

public enum ContextDependencyPolicy:
    String, Codable, Sendable, Equatable
{
    case required, optionalApproved
}

public enum ContextDependencyType:
    String, Codable, Sendable, Equatable
{
    case search
    case campNote = "camp_note"
    case companionNote = "companion_note"
    case mcpServer = "mcp_server"
    case mcpTool = "mcp_tool"
}

package enum ContextFailureCardDisposition: Sendable, Equatable {
    case leaveReady
    case block
}

package enum FailureDiagnosticCategory:
    String, Codable, Sendable, CaseIterable
{
    case database, credential, oauth, runtime, mission, rumination, mcp
    case knowledge, context, memory, notification, projection, cancellation
    case integrity, lifecycle, unknown
}

package enum FailureDiagnosticDomain:
    String, Codable, Sendable, CaseIterable
{
    case grdb, keychain, oauth, runtime, mission, rumination, mcp
    case knowledge, context, memory, notification, projection, cancellation
    case lifecycle, unknown
}

public struct ValidatedHTTPStatus: Sendable, Equatable {
    public let value: Int

    fileprivate init(validatedValue: Int) {
        value = validatedValue
    }

    package init(_ value: Int) throws {
        guard (100...599).contains(value) else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        self.init(validatedValue: value)
    }

    package static func recognizingDiagnostic(
        _ value: Int
    ) -> Self? {
        guard (100...599).contains(value) else { return nil }
        return Self(validatedValue: value)
    }
}

package struct FailureDiagnostics: Codable, Sendable, Equatable {
    package let category: FailureDiagnosticCategory
    package let domain: FailureDiagnosticDomain
    package let retryable: Bool
    package let dependencyType: ContextDependencyType?
    package let policy: ContextDependencyPolicy?
    package let grdbResultCode: Int32?
    package let osStatus: Int32?
    package let httpStatus: Int?
    package let attempt: Int?
    package let primaryCode: FailureCode?
    package let rollbackCode: FailureCode?

    fileprivate init(
        validatedFor code: FailureCode,
        category: FailureDiagnosticCategory,
        domain: FailureDiagnosticDomain,
        retryable: Bool,
        dependencyType: ContextDependencyType? = nil,
        policy: ContextDependencyPolicy? = nil,
        grdbResultCode: Int32? = nil,
        osStatus: Int32? = nil,
        httpStatus: ValidatedHTTPStatus? = nil,
        attempt: Int? = nil,
        primaryCode: FailureCode? = nil,
        rollbackCode: FailureCode? = nil
    ) {
        precondition(attempt.map { $0 >= 0 } ?? true)
        precondition(
            (primaryCode == nil && rollbackCode == nil)
                || code == .proposalRecoveryFailed
                || code == .cleanupIntegrityFailed
        )
        self.category = category
        self.domain = domain
        self.retryable = retryable
        self.dependencyType = dependencyType
        self.policy = policy
        self.grdbResultCode = grdbResultCode
        self.osStatus = osStatus
        self.httpStatus = httpStatus?.value
        self.attempt = attempt
        self.primaryCode = primaryCode
        self.rollbackCode = rollbackCode
    }

    fileprivate var canonicalJSON: String {
        var fields: [(String, String)] = [
            ("category", Self.quoted(category.rawValue)),
            ("domain", Self.quoted(domain.rawValue)),
            ("retryable", retryable ? "true" : "false"),
        ]
        if let attempt {
            fields.append(("attempt", String(attempt)))
        }
        if let dependencyType {
            fields.append(("dependencyType", Self.quoted(dependencyType.rawValue)))
        }
        if let grdbResultCode {
            fields.append(("grdbResultCode", String(grdbResultCode)))
        }
        if let httpStatus {
            fields.append(("httpStatus", String(httpStatus)))
        }
        if let osStatus {
            fields.append(("osStatus", String(osStatus)))
        }
        if let policy {
            fields.append(("policy", Self.quoted(policy.rawValue)))
        }
        if let primaryCode {
            fields.append(("primaryCode", Self.quoted(primaryCode.rawValue)))
        }
        if let rollbackCode {
            fields.append(("rollbackCode", Self.quoted(rollbackCode.rawValue)))
        }
        fields.sort { $0.0 < $1.0 }
        return "{" + fields.map { key, value in
            "\(Self.quoted(key)):\(value)"
        }.joined(separator: ",") + "}"
    }

    private static func quoted(_ value: String) -> String {
        "\"\(value)\""
    }
}

package enum FailureRecordState: String, Sendable, Equatable {
    case open, resolved
}

package struct FailureRecord: FetchableRecord, Sendable, Equatable {
    package let id: String
    package let operation: FailureOperation
    package let scope: FailureScope
    package let severity: FailureSeverity
    package let errorCode: FailureCode
    package let userMessage: String
    package let diagnosticJson: String
    package let state: FailureRecordState
    package let firstSeenAt: Date
    package let lastSeenAt: Date
    package let occurrenceCount: Int64
    package let resolvedAt: Date?
    package let redactedAt: Date?

    fileprivate init(
        validated classification: ValidatedFailureClassification,
        trace: OperationTrace,
        diagnosticJson: String,
        userMessage: String,
        now: Date
    ) {
        id = trace.traceId
        operation = trace.operation
        scope = trace.scope
        severity = classification.severity
        errorCode = classification.code
        self.userMessage = userMessage
        self.diagnosticJson = diagnosticJson
        state = .open
        firstSeenAt = now
        lastSeenAt = now
        occurrenceCount = 1
        resolvedAt = nil
        redactedAt = nil
    }

    package init(row: Row) throws {
        let id: String = row["id"]
        let operationRaw: String = row["operation"]
        let scopeKind: String = row["scopeKind"]
        let campId: String? = row["campId"]
        let scopeType: String = row["scopeType"]
        let scopeId: String = row["scopeId"]
        let severityRaw: String = row["severity"]
        let errorCodeRaw: String = row["errorCode"]
        let userMessage: String = row["userMessage"]
        let diagnosticJson: String = row["diagnosticJson"]
        let stateRaw: String = row["state"]
        let firstSeenAt: Date = row["firstSeenAt"]
        let lastSeenAt: Date = row["lastSeenAt"]
        let occurrenceCount: Int64 = row["occurrenceCount"]
        let resolvedAt: Date? = row["resolvedAt"]
        let redactedAt: Date? = row["redactedAt"]

        guard FailureMetadataGrammar.isSafeID(id),
              let operation = FailureOperation(rawValue: operationRaw),
              let severity = FailureSeverity(rawValue: severityRaw),
              let errorCode = FailureCode(rawValue: errorCodeRaw),
              let state = FailureRecordState(rawValue: stateRaw),
              occurrenceCount >= 1,
              lastSeenAt >= firstSeenAt,
              (state == .open ? resolvedAt == nil : resolvedAt != nil),
              scopeKind == (campId == nil ? "global" : "camp")
        else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        let scope = try FailureScope.validatingPersistedRow(
            scopeType: scopeType,
            scopeId: scopeId,
            campId: campId
        )
        guard Self.isValidUserMessage(userMessage, traceId: id),
              redactedAt == nil
                || (campId != nil
                    && userMessage == "[deleted]"
                    && diagnosticJson == "{}")
        else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        try Self.validateDiagnosticJSON(
            diagnosticJson,
            permitsRedactedEmpty: redactedAt != nil
        )

        self.id = id
        self.operation = operation
        self.scope = scope
        self.severity = severity
        self.errorCode = errorCode
        self.userMessage = userMessage
        self.diagnosticJson = diagnosticJson
        self.state = state
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.occurrenceCount = occurrenceCount
        self.resolvedAt = resolvedAt
        self.redactedAt = redactedAt
    }

    fileprivate static func isValidUserMessage(
        _ message: String,
        traceId: String
    ) -> Bool {
        guard !message.isEmpty,
              message.unicodeScalars.count <= 1_000
        else {
            return false
        }
        if message == "[deleted]" { return true }
        return message.hasSuffix("\n追踪 ID：\(traceId)")
    }

    fileprivate static func validateDiagnosticJSON(
        _ json: String,
        permitsRedactedEmpty: Bool
    ) throws {
        guard json.utf8.count <= 4_096 else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        if permitsRedactedEmpty, json == "{}" { return }

        let value = try JSONValue.decoded(from: json)
        guard case .object(let dictionary) = value,
              try value.encodedString() == json
        else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        let allowed = Set([
            "attempt", "category", "dependencyType", "domain",
            "grdbResultCode", "httpStatus", "osStatus", "policy",
            "primaryCode", "retryable", "rollbackCode",
        ])
        guard Set(dictionary.keys).isSubset(of: allowed),
              let categoryRaw = dictionary["category"]?.stringValue,
              FailureDiagnosticCategory(rawValue: categoryRaw) != nil,
              let domainRaw = dictionary["domain"]?.stringValue,
              FailureDiagnosticDomain(rawValue: domainRaw) != nil,
              dictionary["retryable"]?.boolValue != nil,
              Self.isValidOptionalInteger(
                dictionary["attempt"],
                range: 0...Int.max
              ),
              Self.isValidOptionalStringEnum(
                dictionary["dependencyType"],
                decode: ContextDependencyType.init(rawValue:)
              ),
              Self.isValidOptionalInt32(dictionary["grdbResultCode"]),
              Self.isValidOptionalInteger(
                dictionary["httpStatus"],
                range: 100...599
              ),
              Self.isValidOptionalInt32(dictionary["osStatus"]),
              Self.isValidOptionalStringEnum(
                dictionary["policy"],
                decode: ContextDependencyPolicy.init(rawValue:)
              ),
              Self.isValidOptionalStringEnum(
                dictionary["primaryCode"],
                decode: FailureCode.init(rawValue:)
              ),
              Self.isValidOptionalStringEnum(
                dictionary["rollbackCode"],
                decode: FailureCode.init(rawValue:)
              )
        else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
    }

    private static func isValidOptionalInt32(_ value: JSONValue?) -> Bool {
        guard let value else { return true }
        guard let integer = value.intValue else { return false }
        return Int32(exactly: integer) != nil
    }

    private static func isValidOptionalInteger(
        _ value: JSONValue?,
        range: ClosedRange<Int>
    ) -> Bool {
        guard let value else { return true }
        guard let integer = value.intValue else { return false }
        return range.contains(integer)
    }

    private static func isValidOptionalStringEnum<Value>(
        _ value: JSONValue?,
        decode: (String) -> Value?
    ) -> Bool {
        guard let value else { return true }
        guard let raw = value.stringValue else { return false }
        return decode(raw) != nil
    }
}

package struct ContextDegradationRecord:
    FetchableRecord, Sendable, Equatable
{
    package let id: String
    package let missionId: String?
    package let cardId: String?
    package let dependencyType: ContextDependencyType
    package let dependencyId: String
    package let policy: ContextDependencyPolicy
    package let traceId: String
    package let detail: String
    package let createdAt: Date
    package let redactedAt: Date?

    package init(
        id: String,
        missionId: String?,
        cardId: String?,
        dependencyType: ContextDependencyType,
        dependencyId: String,
        policy: ContextDependencyPolicy,
        traceId: String,
        detail: String,
        createdAt: Date,
        redactedAt: Date?
    ) throws {
        guard FailureMetadataGrammar.isSafeID(id),
              missionId.map(FailureMetadataGrammar.isSafeID) ?? true,
              cardId.map(FailureMetadataGrammar.isSafeID) ?? true,
              missionId != nil || cardId != nil,
              FailureMetadataGrammar.isSafeID(dependencyId),
              FailureMetadataGrammar.isSafeID(traceId),
              !detail.isEmpty,
              detail.unicodeScalars.count <= 1_000,
              redactedAt == nil || detail == "[deleted]"
        else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        self.id = id
        self.missionId = missionId
        self.cardId = cardId
        self.dependencyType = dependencyType
        self.dependencyId = dependencyId
        self.policy = policy
        self.traceId = traceId
        self.detail = detail
        self.createdAt = createdAt
        self.redactedAt = redactedAt
    }

    package init(row: Row) throws {
        let dependencyTypeRaw: String = row["dependencyType"]
        let policyRaw: String = row["policy"]
        guard let dependencyType = ContextDependencyType(
            rawValue: dependencyTypeRaw
        ), let policy = ContextDependencyPolicy(rawValue: policyRaw) else {
            throw FailureMetadataValidationError.invalidDiagnostics
        }
        try self.init(
            id: row["id"],
            missionId: row["missionId"],
            cardId: row["cardId"],
            dependencyType: dependencyType,
            dependencyId: row["dependencyId"],
            policy: policy,
            traceId: row["traceId"],
            detail: row["detail"],
            createdAt: row["createdAt"],
            redactedAt: row["redactedAt"]
        )
    }
}

package struct PreparedFailure: Sendable {
    package let record: FailureRecord
    package let visible: UserVisibleFailure

    package init(record: FailureRecord, visible: UserVisibleFailure) {
        self.record = record
        self.visible = visible
    }
}

struct ValidatedFailureClassification: Sendable, Equatable {
    let code: FailureCode
    let severity: FailureSeverity
    let userBody: String
    let diagnostics: FailureDiagnostics

    fileprivate init(
        code: FailureCode,
        severity: FailureSeverity,
        userBody: String,
        diagnostics: FailureDiagnostics
    ) {
        self.code = code
        self.severity = severity
        self.userBody = userBody
        self.diagnostics = diagnostics
    }
}

enum FailureRecordFactory {
    static func prepared(
        classification: ValidatedFailureClassification,
        trace: OperationTrace,
        now: Date
    ) -> PreparedFailure {
        let diagnosticJSON = classification.diagnostics.canonicalJSON
        precondition(diagnosticJSON.utf8.count <= 4_096)
        let message = formattedMessage(
            body: classification.userBody,
            traceId: trace.traceId
        )
        let record = FailureRecord(
            validated: classification,
            trace: trace,
            diagnosticJson: diagnosticJSON,
            userMessage: message,
            now: now
        )
        return PreparedFailure(
            record: record,
            visible: UserVisibleFailure(
                validatedTrace: trace,
                message: message
            )
        )
    }

    static func bootstrapVisible(
        stage: ApplicationBootstrapStage,
        trace: OperationTrace
    ) -> UserVisibleFailure {
        let body: String
        switch stage {
        case .previewUserDefaults:
            body = "应用预览偏好存储不可用。"
        case .stateDirectory:
            body = "应用状态目录不可用。"
        case .databaseOpen:
            body = "应用数据库无法打开。"
        }
        return UserVisibleFailure(
            validatedTrace: trace,
            message: formattedMessage(body: body, traceId: trace.traceId)
        )
    }

    private static func formattedMessage(
        body: String,
        traceId: String
    ) -> String {
        let prefix = "操作失败："
        let suffix = "\n追踪 ID：\(traceId)"
        let fixedCount = prefix.unicodeScalars.count
            + suffix.unicodeScalars.count
        let budget = max(0, 1_000 - fixedCount)
        let bodyScalars = body.unicodeScalars
        let safeBody: String
        if bodyScalars.count <= budget {
            safeBody = body
        } else {
            safeBody = String(
                String.UnicodeScalarView(bodyScalars.prefix(budget))
            )
        }
        return prefix + safeBody + suffix
    }
}

enum FailureClassifier {
    static func classify(
        _ error: any Error,
        trace: OperationTrace
    ) -> ValidatedFailureClassification {
        if error is CancellationError {
            return make(
                code: .operationCancelled,
                severity: .warning,
                body: "操作已取消。",
                category: .cancellation,
                domain: .cancellation,
                retryable: true
            )
        }
        if let memory = error as? MemoryDistillNormalizedFailure {
            return classify(memory)
        }
        if let runtime = error as? RuntimeCredentialResolutionError {
            return make(
                code: runtime.failureCode,
                body: runtime.safeMessage,
                category: runtime.diagnosticCategory,
                domain: runtime.diagnosticDomain,
                retryable: runtime.retryable,
                osStatus: runtime.osStatus
            )
        }
        if let blocked = error as? CampArchiveBlockedError {
            let body: String
            switch blocked {
            case .activeMission:
                body = "营地还有进行中的任务，请先完成或放弃任务。"
            case .enabledSchedule:
                body = "营地还有启用中的日程，请先停用日程。"
            }
            return make(
                code: .lifecycleBlocked,
                body: body,
                category: .lifecycle,
                domain: .lifecycle,
                retryable: false
            )
        }
        if let blocked = error as? CowRetirementBlockedError {
            let body: String
            switch blocked {
            case .protectedCow, .unsupportedCompanionKind:
                body = "这只系统牛不能移出牛群。"
            case .activeMission:
                body = "这只牛仍在进行中的任务里，请先完成或放弃任务。"
            case .enabledSchedule:
                body = "这只牛仍被启用中的日程使用，请先停用日程。"
            case .pendingResidency:
                body = "这只牛还有待确认的入营关系，暂时不能移出牛群。"
            }
            return make(
                code: .lifecycleBlocked,
                body: body,
                category: .lifecycle,
                domain: .lifecycle,
                retryable: false
            )
        }
        if let validation = error as? MissionTemplateValidationError,
           case .inactiveCompanion = validation
        {
            return make(
                code: .lifecycleBlocked,
                body: "这只牛已移出牛群，请重新选择仍在牛群中的伙伴。",
                category: .lifecycle,
                domain: .lifecycle,
                retryable: false
            )
        }
        if error is InvalidDurableWorkStateError,
           trace.operation == .campArchive
        {
            return make(
                code: .lifecycleBlocked,
                body: "营地还有正在反刍的资料，请等待反刍结束。",
                category: .lifecycle,
                domain: .lifecycle,
                retryable: true
            )
        }
        if error is RecordNotFoundError {
            return make(
                code: .recordNotFound,
                body: "所需记录不存在。",
                category: .database,
                domain: .grdb,
                retryable: false
            )
        }
        if let databaseError = error as? DatabaseError {
            let isRead = isReadOperation(trace.operation)
            return make(
                code: isRead ? .databaseReadFailed : .databaseWriteFailed,
                body: isRead ? "数据读取失败。" : "数据保存失败。",
                category: .database,
                domain: .grdb,
                retryable: true,
                grdbResultCode: databaseError.extendedResultCode.rawValue
            )
        }
        if let keychainError = error as? KeychainError {
            let code: FailureCode
            let body: String
            switch trace.operation {
            case .runtimeCredentialDelete, .oauthUnauthorizedDelete,
                 .mcpServerDelete:
                code = .keychainDeleteFailed
                body = "凭据删除失败。"
            case .runtimeCredentialSet, .oauthCallbackExchange,
                 .oauthRefreshCommit, .mcpSecretSave:
                code = .keychainWriteFailed
                body = "凭据保存失败。"
            default:
                code = .keychainReadFailed
                body = "凭据读取失败。"
            }
            return make(
                code: code,
                body: body,
                category: .credential,
                domain: .keychain,
                retryable: true,
                osStatus: keychainError.status
            )
        }
        if error is CredentialValueInvalidError {
            return make(
                code: .credentialValueInvalid,
                body: "凭据格式无效。",
                category: .credential,
                domain: .keychain,
                retryable: false
            )
        }
        if error is OAuthCredentialBundleUnavailableError {
            return make(
                code: .oauthCredentialCommitFailed,
                body: "OAuth 凭据暂不可用，请重新授权。",
                category: .oauth,
                domain: .oauth,
                retryable: false
            )
        }
        if let credential = error as? CredentialBundleError {
            return classify(credential)
        }
        if let composite = error as? McpDeletionCleanupCompositeError {
            return make(
                code: .cleanupIntegrityFailed,
                severity: .critical,
                body: "清理未完整完成。",
                category: .integrity,
                domain: .mcp,
                retryable: false,
                dependencyType: .mcpServer,
                primaryCode: mcpDeletionCode(composite.primary),
                rollbackCode: .cleanupIntegrityFailed
            )
        }
        if let deletion = error as? McpServerDeletionFailure {
            switch deletion {
            case .credential(let credential):
                return classify(credential)
            case .maintenance(let maintenance):
                return classify(maintenance)
            }
        }
        if let deletion = error as? McpCredentialDeletionError {
            return classify(deletion)
        }
        if let maintenance = error as? McpMaintenanceCleanupError {
            return classify(maintenance)
        }
        if error is McpRequiredToolMissingError {
            return make(
                code: .mcpRequiredToolMissing,
                body: "所需驿站工具不存在。",
                category: .mcp,
                domain: .mcp,
                retryable: false,
                dependencyType: .mcpTool,
                policy: .required
            )
        }
        if let mcp = error as? McpOperationError {
            return classify(mcp)
        }
        if error is RuntimeProfileReadError {
            return make(
                code: .runtimeProfileReadFailed,
                body: "供给线读取失败。",
                category: .runtime,
                domain: .runtime,
                retryable: true
            )
        }
        if error is TraceIdentityConflictError {
            return make(
                code: .traceIdentityConflict,
                severity: .critical,
                body: "操作追踪身份不一致。",
                category: .integrity,
                domain: .mission,
                retryable: false
            )
        }
        if let composite = error as? ProposalRecoveryCompositeError {
            return make(
                code: .proposalRecoveryFailed,
                severity: .critical,
                body: "操作未完成，且恢复原状态失败。",
                category: .integrity,
                domain: .mission,
                retryable: false,
                primaryCode: composite.primaryCode,
                rollbackCode: composite.rollbackCode
            )
        }
        if let composite = error as? CloseoutFallbackCompositeError {
            return make(
                code: .cleanupIntegrityFailed,
                severity: .critical,
                body: "清理未完整完成。",
                category: .integrity,
                domain: .mission,
                retryable: false,
                primaryCode: composite.primaryCode,
                rollbackCode: composite.fallbackWriteCode
            )
        }
        if let backend = error as? ContextBackendCapabilityError {
            let type: ContextDependencyType = backend == .search
                ? .search
                : .mcpServer
            return make(
                code: .contextBackendCapabilityUnsupported,
                body: "当前供给线无法提供所选必需能力。",
                category: .context,
                domain: .context,
                retryable: false,
                dependencyType: type,
                policy: .required
            )
        }
        if let context = error as? ContextDependencyLoadError {
            switch context {
            case .searchCredentialMissing:
                return make(
                    code: .contextDependencyRequiredFailed,
                    body: "必需上下文不可用。",
                    category: .context,
                    domain: .context,
                    retryable: false,
                    dependencyType: .search,
                    policy: .required
                )
            case .searchCredentialRead(let status):
                return make(
                    code: .contextDependencyRequiredFailed,
                    body: "必需上下文读取失败。",
                    category: .context,
                    domain: .context,
                    retryable: true,
                    dependencyType: .search,
                    policy: .required,
                    osStatus: status
                )
            case .knowledgeRead(let dependencyType, let resultCode):
                return make(
                    code: .knowledgeReadFailed,
                    severity: .warning,
                    body: "知识上下文读取失败。",
                    category: .context,
                    domain: .context,
                    retryable: true,
                    dependencyType: dependencyType,
                    policy: .optionalApproved,
                    grdbResultCode: resultCode
                )
            }
        }
        if let projection = error as? ProjectionContractError {
            switch projection {
            case .invalidPayload:
                return make(
                    code: .projectionDecodeFailed,
                    body: "数据格式损坏。",
                    category: .projection,
                    domain: .projection,
                    retryable: false
                )
            case .generationOverflow, .invalidTerminal, .alreadyCompleted:
                return make(
                    code: .projectionContractFailed,
                    severity: .critical,
                    body: "界面状态契约不一致。",
                    category: .integrity,
                    domain: .projection,
                    retryable: false
                )
            }
        }
        if let schedule = error as? SchedulePlatformFailure {
            let category: FailureDiagnosticCategory =
                schedule == .documentPresentation
                ? .projection
                : .notification
            return make(
                code: .schedulePlatformFailed,
                body: "定时行动平台操作失败。",
                category: category,
                domain: .notification,
                retryable: true
            )
        }
        if let oauth = error as? RuntimeOAuthBoundaryError {
            return classify(oauth)
        }
        if error is RuntimeOAuthListenerFailure {
            return make(
                code: .oauthListenerFailed,
                body: "网页登录回调监听失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true
            )
        }
        return make(
            code: .unexpectedFailure,
            body: "发生未预期的错误。",
            category: .unknown,
            domain: .unknown,
            retryable: false
        )
    }

    private static func classify(
        _ error: MemoryDistillNormalizedFailure
    ) -> ValidatedFailureClassification {
        switch error {
        case .input(let source):
            switch source {
            case .invalidMinimumMessages, .invalidCapturedMessages:
                return make(
                    code: .projectionContractFailed,
                    body: "记忆沉淀输入无效。",
                    category: .projection,
                    domain: .memory,
                    retryable: false
                )
            case .ownerNotFound, .threadInvariant, .read, .provider,
                 .invalidPayload, .write:
                return unexpectedMemoryFailure()
            }
        case .ownerRead(let source):
            switch source {
            case .ownerNotFound:
                return make(
                    code: .memoryOwnerNotFound,
                    body: "找不到记忆沉淀对象。",
                    category: .memory,
                    domain: .memory,
                    retryable: false
                )
            case .read(let resultCode):
                return make(
                    code: .memoryReadFailed,
                    body: "记忆数据读取失败。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    grdbResultCode: resultCode
                )
            case .invalidMinimumMessages, .invalidCapturedMessages,
                 .threadInvariant, .provider, .invalidPayload, .write:
                return unexpectedMemoryFailure()
            }
        case .threadEnsure(let source):
            switch source {
            case .threadInvariant:
                return make(
                    code: .memoryThreadInvariantFailed,
                    severity: .critical,
                    body: "记忆对话状态不一致。",
                    category: .integrity,
                    domain: .memory,
                    retryable: false
                )
            case .write(let resultCode):
                return make(
                    code: .memoryWriteFailed,
                    body: "记忆对话准备失败。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    grdbResultCode: resultCode
                )
            case .invalidMinimumMessages, .invalidCapturedMessages,
                 .ownerNotFound, .read, .provider, .invalidPayload:
                return unexpectedMemoryFailure()
            }
        case .messageRead(let source):
            switch source {
            case .read(let resultCode):
                return make(
                    code: .memoryReadFailed,
                    body: "记忆数据读取失败。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    grdbResultCode: resultCode
                )
            case .invalidPayload:
                return make(
                    code: .projectionDecodeFailed,
                    body: "记忆数据格式损坏。",
                    category: .projection,
                    domain: .memory,
                    retryable: false
                )
            case .invalidMinimumMessages, .invalidCapturedMessages,
                 .ownerNotFound, .threadInvariant, .provider, .write:
                return unexpectedMemoryFailure()
            }
        case .provider(let source):
            switch source {
            case .provider(let status):
                return make(
                    code: .memoryProviderFailed,
                    body: "记忆沉淀服务不可用。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    httpStatus: status
                )
            case .invalidPayload:
                return make(
                    code: .projectionDecodeFailed,
                    body: "记忆数据格式损坏。",
                    category: .projection,
                    domain: .memory,
                    retryable: false
                )
            case .invalidMinimumMessages, .invalidCapturedMessages,
                 .ownerNotFound, .threadInvariant, .read, .write:
                return unexpectedMemoryFailure()
            }
        case .watermark(let source):
            switch source {
            case .invalidCapturedMessages:
                return make(
                    code: .projectionContractFailed,
                    body: "记忆沉淀输入无效。",
                    category: .projection,
                    domain: .memory,
                    retryable: false
                )
            case .write(let resultCode):
                return make(
                    code: .memoryWriteFailed,
                    body: "记忆沉淀水位更新失败。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    grdbResultCode: resultCode
                )
            case .invalidMinimumMessages, .ownerNotFound,
                 .threadInvariant, .read, .provider, .invalidPayload:
                return unexpectedMemoryFailure()
            }
        case .persistence(let source):
            switch source {
            case .invalidCapturedMessages:
                return make(
                    code: .projectionContractFailed,
                    body: "记忆沉淀输入无效。",
                    category: .projection,
                    domain: .memory,
                    retryable: false
                )
            case .write(let resultCode):
                return make(
                    code: .memoryWriteFailed,
                    body: "记忆沉淀保存失败。",
                    category: .memory,
                    domain: .memory,
                    retryable: true,
                    grdbResultCode: resultCode
                )
            case .invalidMinimumMessages, .ownerNotFound,
                 .threadInvariant, .read, .provider, .invalidPayload:
                return unexpectedMemoryFailure()
            }
        case .watermarkRace, .persistenceRace:
            return make(
                code: .memoryRaceLost,
                body: "记忆沉淀状态已被其他操作更新。",
                category: .memory,
                domain: .memory,
                retryable: true
            )
        }
    }

    private static func unexpectedMemoryFailure()
        -> ValidatedFailureClassification
    {
        make(
            code: .unexpectedFailure,
            body: "发生未预期的错误。",
            category: .unknown,
            domain: .unknown,
            retryable: false
        )
    }

    private static func classify(
        _ error: RuntimeOAuthBoundaryError
    ) -> ValidatedFailureClassification {
        switch error {
        case .stateMissing, .stateMismatch:
            return make(
                code: .oauthStateInvalid,
                body: "网页登录状态校验失败。",
                category: .oauth,
                domain: .oauth,
                retryable: false
            )
        case .httpStatus(let status):
            return make(
                code: .oauthTokenExchangeFailed,
                body: "网页登录令牌交换失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true,
                httpStatus: status
            )
        case .nonHTTPResponse, .malformedTokenResponse, .accountIDMissing,
             .formEncoding:
            return make(
                code: .oauthTokenExchangeFailed,
                body: "网页登录令牌交换失败。",
                category: .oauth,
                domain: .oauth,
                retryable: false
            )
        case .randomGeneration, .authorizationAlreadyActive,
             .callbackMalformed, .callbackDenied, .browserOpen:
            return make(
                code: .oauthAuthorizationFailed,
                body: "网页登录授权失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true
            )
        }
    }

    private static func classify(
        _ error: CredentialBundleError
    ) -> ValidatedFailureClassification {
        switch error {
        case .preimageRead(_, let status), .commit(_, _, let status):
            return make(
                code: .oauthCredentialCommitFailed,
                body: "OAuth 凭据保存失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true,
                osStatus: status
            )
        case .rollback(_, let status):
            return make(
                code: .oauthCredentialRollbackFailed,
                severity: .critical,
                body: "OAuth 凭据恢复失败。",
                category: .integrity,
                domain: .oauth,
                retryable: false,
                osStatus: status
            )
        case .preimageChanged:
            return make(
                code: .oauthCredentialCommitFailed,
                body: "OAuth credentials changed while this request was in flight. Retry.",
                category: .oauth,
                domain: .oauth,
                retryable: true
            )
        case .unauthorizedDelete(let status):
            return make(
                code: .oauthCredentialDeleteFailed,
                body: "OAuth 凭据删除失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true,
                osStatus: status
            )
        case .authorizationPreparationCommit(let status):
            return make(
                code: .oauthAuthorizationFailed,
                body: "网页登录授权准备失败。",
                category: .oauth,
                domain: .oauth,
                retryable: true,
                osStatus: status
            )
        }
    }

    private static func classify(
        _ error: McpOperationError
    ) -> ValidatedFailureClassification {
        let code: FailureCode
        let body: String
        let retryable: Bool
        let dependencyType: ContextDependencyType
        let osStatus: Int32?
        switch error {
        case .registryRead:
            code = .mcpRegistryReadFailed
            body = "驿站注册表读取失败。"
            retryable = true
            dependencyType = .mcpServer
            osStatus = nil
        case .serverMissing:
            code = .mcpServerNotFound
            body = "所需驿站不存在。"
            retryable = false
            dependencyType = .mcpServer
            osStatus = nil
        case .invalidConfig:
            code = .mcpConfigInvalid
            body = "驿站配置无效。"
            retryable = false
            dependencyType = .mcpServer
            osStatus = nil
        case .secretMissing:
            code = .mcpSecretMissing
            body = "驿站凭据缺失。"
            retryable = false
            dependencyType = .mcpServer
            osStatus = nil
        case .secretRead(_, let status):
            code = .mcpSecretReadFailed
            body = "驿站凭据读取失败。"
            retryable = true
            dependencyType = .mcpServer
            osStatus = status
        case .transportStart:
            code = .mcpStartFailed
            body = "驿站启动失败。"
            retryable = true
            dependencyType = .mcpServer
            osStatus = nil
        case .toolList:
            code = .mcpToolListFailed
            body = "驿站工具清单读取失败。"
            retryable = true
            dependencyType = .mcpServer
            osStatus = nil
        case .connectionDown:
            code = .mcpConnectionDown
            body = "驿站连接已中断。"
            retryable = true
            dependencyType = .mcpTool
            osStatus = nil
        case .toolCall:
            code = .mcpToolCallFailed
            body = "驿站工具调用失败。"
            retryable = true
            dependencyType = .mcpTool
            osStatus = nil
        case .serverMaintenance:
            code = .mcpServerMaintenance
            body = "驿站正在维护。"
            retryable = true
            dependencyType = .mcpServer
            osStatus = nil
        }
        return make(
            code: code,
            body: body,
            category: .mcp,
            domain: .mcp,
            retryable: retryable,
            dependencyType: dependencyType,
            osStatus: osStatus
        )
    }

    private static func classify(
        _ error: McpCredentialDeletionError
    ) -> ValidatedFailureClassification {
        switch error {
        case .preimageRead(let status):
            return make(
                code: .mcpSecretReadFailed,
                body: "驿站凭据读取失败。",
                category: .mcp,
                domain: .mcp,
                retryable: true,
                dependencyType: .mcpServer,
                osStatus: status
            )
        case .commit(.secret, let status):
            return make(
                code: .mcpSecretDeleteFailed,
                body: "驿站凭据删除失败。",
                category: .mcp,
                domain: .mcp,
                retryable: true,
                dependencyType: .mcpServer,
                osStatus: status
            )
        case .commit(.databaseRow, let status):
            return make(
                code: .databaseWriteFailed,
                body: "数据保存失败。",
                category: .mcp,
                domain: .mcp,
                retryable: true,
                dependencyType: .mcpServer,
                osStatus: status
            )
        case .rollback(let status):
            return make(
                code: .mcpSecretRollbackFailed,
                severity: .critical,
                body: "驿站凭据恢复失败。",
                category: .integrity,
                domain: .mcp,
                retryable: false,
                dependencyType: .mcpServer,
                osStatus: status
            )
        }
    }

    private static func classify(
        _ error: McpMaintenanceCleanupError
    ) -> ValidatedFailureClassification {
        let retryable: Bool
        switch error {
        case .finishFailed:
            retryable = true
        case .invalidLease:
            retryable = false
        }
        return make(
            code: .cleanupIntegrityFailed,
            severity: .critical,
            body: "清理未完整完成。",
            category: .integrity,
            domain: .mcp,
            retryable: retryable,
            dependencyType: .mcpServer
        )
    }

    private static func mcpDeletionCode(
        _ error: McpCredentialDeletionError
    ) -> FailureCode {
        switch error {
        case .preimageRead:
            return .mcpSecretReadFailed
        case .commit(.secret, _):
            return .mcpSecretDeleteFailed
        case .commit(.databaseRow, _):
            return .databaseWriteFailed
        case .rollback:
            return .mcpSecretRollbackFailed
        }
    }

    private static func make(
        code: FailureCode,
        severity: FailureSeverity = .error,
        body: String,
        category: FailureDiagnosticCategory,
        domain: FailureDiagnosticDomain,
        retryable: Bool,
        dependencyType: ContextDependencyType? = nil,
        policy: ContextDependencyPolicy? = nil,
        grdbResultCode: Int32? = nil,
        osStatus: Int32? = nil,
        httpStatus: ValidatedHTTPStatus? = nil,
        primaryCode: FailureCode? = nil,
        rollbackCode: FailureCode? = nil
    ) -> ValidatedFailureClassification {
        ValidatedFailureClassification(
            code: code,
            severity: severity,
            userBody: body,
            diagnostics: FailureDiagnostics(
                validatedFor: code,
                category: category,
                domain: domain,
                retryable: retryable,
                dependencyType: dependencyType,
                policy: policy,
                grdbResultCode: grdbResultCode,
                osStatus: osStatus,
                httpStatus: httpStatus,
                primaryCode: primaryCode,
                rollbackCode: rollbackCode
            )
        )
    }

    private static func isReadOperation(
        _ operation: FailureOperation
    ) -> Bool {
        switch operation {
        case .runtimeBootstrap, .runtimeLoad, .runtimeProviderResolve,
             .runtimeSearchResolve, .missionIndexLoad, .missionDetailLoad,
             .inputCampLoad, .inputReviewLoad, .campWritableRead,
             .campKnowledgeLoad, .companionEditorLoad, .memoryNoteLoad,
             .mcpRegistryLoad, .mcpCampLoad, .mcpToolList,
             .mcpSecretPresence, .contextToolAccess, .contextSearch,
             .contextMcpServer, .contextMcpTool, .contextCampNotes,
             .contextCompanionNotes, .scheduleLoad, .haltRead,
             .chatLoad, .guideChatLoad, .previewRuntimeRead:
            return true
        default:
            return false
        }
    }
}

package struct TraceIdentityConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct ProposalRecoveryCompositeError: Error, Sendable, Equatable {
    package let primaryCode: FailureCode
    package let rollbackCode: FailureCode

    package init(primaryCode: FailureCode, rollbackCode: FailureCode) {
        self.primaryCode = primaryCode
        self.rollbackCode = rollbackCode
    }
}

package struct CloseoutFallbackCompositeError: Error, Sendable, Equatable {
    package let primaryCode: FailureCode
    package let fallbackWriteCode: FailureCode

    package init(
        primaryCode: FailureCode,
        fallbackWriteCode: FailureCode
    ) {
        self.primaryCode = primaryCode
        self.fallbackWriteCode = fallbackWriteCode
    }
}

package struct FailureRecordRedactedError: Error, Sendable, Equatable {
    package init() {}
}

package struct CredentialValueInvalidError: Error, Sendable, Equatable {
    package init() {}
}

package struct OAuthCredentialBundleUnavailableError:
    Error, Sendable, Equatable
{
    package init() {}
}

package enum ContextBackendCapabilityError: Error, Sendable, Equatable {
    case search
    case mcp
}

package enum ProjectionContractError: Error, Sendable, Equatable {
    case invalidPayload
    case generationOverflow
    case invalidTerminal
    case alreadyCompleted
}

package struct RuntimeProfileReadError: Error, Sendable, Equatable {
    package init() {}
}

package enum SchedulePlatformFailure: Error, Sendable, Equatable {
    case registration
    case authorization
    case notificationSettings
    case notificationSubmission
    case documentPresentation
}

package enum RuntimeOAuthBoundaryError: Error, Sendable, Equatable {
    case randomGeneration
    case authorizationAlreadyActive
    case callbackMalformed
    case callbackDenied
    case stateMissing
    case stateMismatch
    case formEncoding
    case nonHTTPResponse
    case httpStatus(ValidatedHTTPStatus)
    case malformedTokenResponse
    case accountIDMissing
    case browserOpen
}

package enum RuntimeOAuthListenerFailure: Error, Sendable, Equatable {
    case invalidPort
    case bind
    case accept
    case malformedCallback
    case cancelled
}
