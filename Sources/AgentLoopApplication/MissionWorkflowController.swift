import Foundation
import AgentLoopCore

package struct MissionDetailSnapshot: Sendable {
    package let mission: MissionRecord
    package let cards: [CardRecord]
    package let artifacts: [ArtifactRecord]
    package let pendingRequests: [UserRequestRecord]
    package let squad: SquadRecord
    package let squadMemberIds: [String]
    package let companionsById: [String: CompanionRecord]
    package let events: [EventRecord]
    package let spend: MissionSpendBreakdown

    package init(
        mission: MissionRecord,
        cards: [CardRecord],
        artifacts: [ArtifactRecord],
        pendingRequests: [UserRequestRecord],
        squad: SquadRecord,
        squadMemberIds: [String],
        companionsById: [String: CompanionRecord],
        events: [EventRecord],
        spend: MissionSpendBreakdown
    ) {
        self.mission = mission
        self.cards = cards
        self.artifacts = artifacts
        self.pendingRequests = pendingRequests
        self.squad = squad
        self.squadMemberIds = squadMemberIds
        self.companionsById = companionsById
        self.events = events
        self.spend = spend
    }
}

package struct MissionIndexSnapshot: Sendable {
    package let missions: [MissionRecord]
    package let camps: [CampRecord]
    package let missionsByCamp: [String: [MissionRecord]]
    package let artifactLedger: [ArtifactLedgerItem]

    package init(
        missions: [MissionRecord],
        camps: [CampRecord],
        missionsByCamp: [String: [MissionRecord]],
        artifactLedger: [ArtifactLedgerItem]
    ) {
        self.missions = missions
        self.camps = camps
        self.missionsByCamp = missionsByCamp
        self.artifactLedger = artifactLedger
    }
}

package struct MissionWorkflowReads: Sendable {
    package let detail: @Sendable (String) throws -> MissionDetailReadBundle
    package let index: @Sendable (Bool) throws -> MissionIndexReadBundle

    package init(
        detail: @escaping @Sendable (String) throws
            -> MissionDetailReadBundle,
        index: @escaping @Sendable (Bool) throws
            -> MissionIndexReadBundle
    ) {
        self.detail = detail
        self.index = index
    }

    package static func live(database: AppDatabase) -> Self {
        Self(
            detail: {
                try database.readMissionDetailBundle(missionId: $0)
            },
            index: {
                try database.readMissionIndexBundle(includeArchived: $0)
            }
        )
    }
}

package struct MissionStartRequest: Sendable, Equatable {
    package let goal: String
    package let companionIds: [String]
    package let workspacePath: String?
    package let plannerModel: String
    package let runtimeProfileId: String
    package let budgetTokens: Int
    package let campId: String?
    package let autonomy: MissionAutonomy
    package let idempotencyKey: String
    package let durableTraceId: String

    package init(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        plannerModel: String,
        runtimeProfileId: String,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        idempotencyKey: String,
        durableTraceId: String
    ) {
        self.goal = goal
        self.companionIds = companionIds
        self.workspacePath = workspacePath
        self.plannerModel = plannerModel
        self.runtimeProfileId = runtimeProfileId
        self.budgetTokens = budgetTokens
        self.campId = campId
        self.autonomy = autonomy
        self.idempotencyKey = idempotencyKey
        self.durableTraceId = durableTraceId
    }
}

package struct ScheduleWorkflowSnapshot: Sendable, Equatable {
    package let campId: String
    package let templates: [ScheduleTemplateProjection]
    package let schedules: [ScheduleRecordProjection]

    package init(
        campId: String,
        templates: [ScheduleTemplateProjection],
        schedules: [ScheduleRecordProjection]
    ) {
        self.campId = campId
        self.templates = templates
        self.schedules = schedules
    }
}

package struct ScheduleTemplateProjection: Sendable, Equatable {
    package let record: MissionTemplateRecord
    package let companionIds: [String]
    package let primaryCompanionId: String
    package let budgetTokens: Int

    package init(
        record: MissionTemplateRecord,
        companionIds: [String],
        primaryCompanionId: String,
        budgetTokens: Int
    ) {
        self.record = record
        self.companionIds = companionIds
        self.primaryCompanionId = primaryCompanionId
        self.budgetTokens = budgetTokens
    }
}

package struct ScheduleRecordProjection: Sendable, Equatable {
    package let record: ScheduleRecord
    package let validatedWeekday: Int?

    package init(record: ScheduleRecord, validatedWeekday: Int?) {
        self.record = record
        self.validatedWeekday = validatedWeekday
    }
}

package struct EnabledScheduleProjection: Sendable, Equatable {
    package let record: EnabledScheduleRecord
    package let nextFireDate: Date

    package init(record: EnabledScheduleRecord, nextFireDate: Date) {
        self.record = record
        self.nextFireDate = nextFireDate
    }
}

package struct SchedulePresentationSnapshot: Sendable, Equatable {
    package let enabled: [EnabledScheduleProjection]
    package let requestedTemplate: ScheduleTemplateProjection?

    package init(
        enabled: [EnabledScheduleProjection],
        requestedTemplate: ScheduleTemplateProjection?
    ) {
        self.enabled = enabled
        self.requestedTemplate = requestedTemplate
    }
}

package struct ScheduleTemplateDraftCommand: Sendable, Equatable {
    package let existingId: String?
    package let campId: String
    package let name: String
    package let goal: String
    package let companionId: String
    package let workspacePath: String
    package let budgetText: String
    package let autonomy: MissionAutonomy

    package init(
        existingId: String?,
        campId: String,
        name: String,
        goal: String,
        companionId: String,
        workspacePath: String,
        budgetText: String,
        autonomy: MissionAutonomy
    ) {
        self.existingId = existingId
        self.campId = campId
        self.name = name
        self.goal = goal
        self.companionId = companionId
        self.workspacePath = workspacePath
        self.budgetText = budgetText
        self.autonomy = autonomy
    }
}

package struct ScheduleDraftCommand: Sendable, Equatable {
    package let templateId: String
    package let frequency: ScheduleFrequency
    package let selectedTime: Date
    package let weekday: Int?
    package let enabled: Bool

    package init(
        templateId: String,
        frequency: ScheduleFrequency,
        selectedTime: Date,
        weekday: Int?,
        enabled: Bool
    ) {
        self.templateId = templateId
        self.frequency = frequency
        self.selectedTime = selectedTime
        self.weekday = weekday
        self.enabled = enabled
    }
}

package struct ScheduleFireRequest: Sendable, Equatable {
    package let scheduleId: String
    package let context: ScheduleSlotContextV1

    package init(scheduleId: String, context: ScheduleSlotContextV1) {
        self.scheduleId = scheduleId
        self.context = context
    }
}

package struct ScheduleReplayRequest: Sendable, Equatable {
    package let originalFireId: String

    package init(originalFireId: String) {
        self.originalFireId = originalFireId
    }
}

package enum ScheduleNotificationKind: String, Sendable, Equatable {
    case closeout
    case failure
    case budgetExhausted
}

package struct ScheduleNotificationRequest: Sendable, Equatable {
    package let notificationId: String
    package let missionId: String
    package let title: String
    package let body: String
    package let kind: ScheduleNotificationKind

    package init(
        notificationId: String,
        missionId: String,
        title: String,
        body: String,
        kind: ScheduleNotificationKind
    ) {
        self.notificationId = notificationId
        self.missionId = missionId
        self.title = title
        self.body = body
        self.kind = kind
    }
}

package struct ScheduleActivityRegistration: Sendable, Equatable {
    package let scheduleId: String
    package let request: ScheduleFireRequest

    package init(scheduleId: String, request: ScheduleFireRequest) {
        self.scheduleId = scheduleId
        self.request = request
    }
}

package struct ScheduleRegistrationReceipt: Sendable, Equatable {
    package let registeredScheduleIds: [String]

    package init(registeredScheduleIds: [String]) {
        self.registeredScheduleIds = registeredScheduleIds
    }
}

package struct ScheduleRegistrationEvaluation: Sendable, Equatable {
    package let now: Date
    package let timeZone: TimeZone

    package init(now: Date, timeZone: TimeZone) {
        self.now = now
        self.timeZone = timeZone
    }
}

package struct ScheduleTemplateDeletionReceipt: Sendable, Equatable {
    package let template: MissionTemplateRecord
    package let deletedSchedules: [ScheduleRecord]

    package init(
        template: MissionTemplateRecord,
        deletedSchedules: [ScheduleRecord]
    ) {
        self.template = template
        self.deletedSchedules = deletedSchedules
    }
}

package struct ScheduleDeletionReceipt: Sendable, Equatable {
    package let schedule: ScheduleRecord

    package init(schedule: ScheduleRecord) {
        self.schedule = schedule
    }
}

package enum ScheduleMutationCommittedIdentity: Sendable, Equatable {
    case templateSaved(MissionTemplateRecord)
    case templateDeleted(ScheduleTemplateDeletionReceipt)
    case scheduleSaved(ScheduleRecord)
    case scheduleEnablementChanged(ScheduleRecord)
    case scheduleDeleted(ScheduleDeletionReceipt)
}

fileprivate enum SchedulePostCommitRepairKey: Hashable, Sendable {
    case template(String)
    case schedule(String)
}

fileprivate enum SchedulePostCommitRepairStage: Sendable, Equatable {
    case authorizationThenRegistration
    case registration
}

fileprivate enum SchedulePostCommitOwnerPhase: Sendable, Equatable {
    case performing
    case repair(SchedulePostCommitRepairReceipt)
    case globallyVisibleAwaitingTerminal(applicationCarrierId: UUID)
}

package enum ScheduleAuthorizationDisposition: String, Sendable, Equatable {
    case unavailable
    case alreadyRequested
    case granted
    case denied
}

package struct ScheduleAuthorizationReceipt: Sendable, Equatable {
    package let disposition: ScheduleAuthorizationDisposition

    package init(disposition: ScheduleAuthorizationDisposition) {
        self.disposition = disposition
    }
}

package struct SchedulePlatformEvidence: Sendable, Equatable {
    package let authorization: ScheduleAuthorizationReceipt?
    package let registration: ScheduleRegistrationReceipt?

    fileprivate init(
        authorization: ScheduleAuthorizationReceipt?,
        registration: ScheduleRegistrationReceipt?
    ) {
        self.authorization = authorization
        self.registration = registration
    }
}

package struct SchedulePostCommitRepairReceipt: Sendable, Equatable {
    fileprivate let repairId: UUID
    fileprivate let identity: ScheduleMutationCommittedIdentity
    fileprivate let stage: SchedulePostCommitRepairStage
    fileprivate let traceScope: FailureTraceScope
    fileprivate let ownedKeys: Set<SchedulePostCommitRepairKey>
    fileprivate let evidence: SchedulePlatformEvidence

    fileprivate init(
        repairId: UUID,
        identity: ScheduleMutationCommittedIdentity,
        stage: SchedulePostCommitRepairStage,
        traceScope: FailureTraceScope,
        ownedKeys: Set<SchedulePostCommitRepairKey>,
        evidence: SchedulePlatformEvidence
    ) {
        self.repairId = repairId
        self.identity = identity
        self.stage = stage
        self.traceScope = traceScope
        self.ownedKeys = ownedKeys
        self.evidence = evidence
    }

    package func isSameRepairOwner(
        as other: SchedulePostCommitRepairReceipt
    ) -> Bool {
        repairId == other.repairId
    }
}

package struct SchedulePostCommitApplicationReceipt: Sendable, Equatable {
    fileprivate let applicationId: UUID

    fileprivate init(applicationId: UUID) {
        self.applicationId = applicationId
    }
}

package struct ScheduleCommittedTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt

    fileprivate init(application: SchedulePostCommitApplicationReceipt) {
        self.application = application
    }
}

package struct ScheduleVisibilityFailureTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt

    fileprivate init(application: SchedulePostCommitApplicationReceipt) {
        self.application = application
    }
}

package struct ScheduleRepairedTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt

    fileprivate init(application: SchedulePostCommitApplicationReceipt) {
        self.application = application
    }
}

package struct ScheduleStillPendingTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt

    fileprivate init(application: SchedulePostCommitApplicationReceipt) {
        self.application = application
    }
}

package enum SchedulePostCommitApplicationOperation: Sendable, Equatable {
    case project(ScheduleMutationCommittedIdentity)
    case authorizationEvidence(ScheduleAuthorizationReceipt)
    case registrationEvidence(ScheduleRegistrationReceipt)
    case clearRepair(SchedulePostCommitRepairReceipt)
    case installRepair(
        identity: ScheduleMutationCommittedIdentity,
        repair: SchedulePostCommitRepairReceipt,
        failure: UserVisibleFailure
    )
}

package struct SchedulePostCommitCanonicalProgram: Sendable, Equatable {
    package let operations: [SchedulePostCommitApplicationOperation]
    package let currentIdentity: ScheduleMutationCommittedIdentity

    fileprivate init(
        operations: [SchedulePostCommitApplicationOperation],
        currentIdentity: ScheduleMutationCommittedIdentity
    ) {
        self.operations = operations
        self.currentIdentity = currentIdentity
    }
}

package enum ScheduleMutationOutcome: Sendable, Equatable {
    case notCommitted(UserVisibleFailure)
    case committed(ScheduleCommittedTerminal)
    case committedSuperseded
    case committedWithVisibilityFailure(ScheduleVisibilityFailureTerminal)
}

package enum SchedulePostCommitRepairOutcome: Sendable, Equatable {
    case repaired(ScheduleRepairedTerminal)
    case stillPending(ScheduleStillPendingTerminal)
    case superseded
}

package struct SchedulePostCommitApplicationDecision: Sendable, Equatable {
    fileprivate enum Storage: Sendable, Equatable {
        case apply(SchedulePostCommitCanonicalProgram)
        case mutationSuperseded
        case alreadyConsumed
    }

    fileprivate let storage: Storage

    fileprivate init(storage: Storage) {
        self.storage = storage
    }

    package func fold<Value>(
        apply: (SchedulePostCommitCanonicalProgram) -> Value,
        mutationSuperseded: () -> Value,
        alreadyConsumed: () -> Value
    ) -> Value {
        switch storage {
        case .apply(let program):
            return apply(program)
        case .mutationSuperseded:
            return mutationSuperseded()
        case .alreadyConsumed:
            return alreadyConsumed()
        }
    }
}

package enum ScheduleRegistrationRefreshOutcome: Sendable, Equatable {
    case refreshed(
        registration: ScheduleRegistrationReceipt,
        supersededRepairs: [SchedulePostCommitRepairReceipt]
    )
    case failed(UserVisibleFailure)
}

package struct ScheduleRegistrationPort: Sendable {
    package let replaceAll:
        @MainActor @Sendable ([ScheduleActivityRegistration]) async throws
            -> ScheduleRegistrationReceipt

    package init(
        replaceAll: @escaping @MainActor @Sendable
            ([ScheduleActivityRegistration]) async throws
            -> ScheduleRegistrationReceipt
    ) {
        self.replaceAll = replaceAll
    }
}

package enum ScheduleNotificationDisposition: String, Sendable, Equatable {
    case unavailable
    case notAuthorized
    case submitted
}

package struct ScheduleNotificationReceipt: Sendable, Equatable {
    package let notificationId: String
    package let disposition: ScheduleNotificationDisposition

    package init(
        notificationId: String,
        disposition: ScheduleNotificationDisposition
    ) {
        self.notificationId = notificationId
        self.disposition = disposition
    }
}

package struct ScheduleBroadcastReceipt: Sendable, Equatable {
    package let effectKey: String
    package let campId: String
    package let messageId: String

    package init(effectKey: String, campId: String, messageId: String) {
        self.effectKey = effectKey
        self.campId = campId
        self.messageId = messageId
    }
}

package struct ScheduledMissionOutcomePlan: Sendable, Equatable {
    package let effectKey: String
    package let missionId: String
    package let broadcastCampId: String?
    package let broadcastText: String?
    package let notification: ScheduleNotificationRequest

    package init(
        effectKey: String,
        missionId: String,
        broadcastCampId: String?,
        broadcastText: String?,
        notification: ScheduleNotificationRequest
    ) {
        self.effectKey = effectKey
        self.missionId = missionId
        self.broadcastCampId = broadcastCampId
        self.broadcastText = broadcastText
        self.notification = notification
    }
}

package struct ScheduleNotificationPort: Sendable {
    package let requestAuthorization:
        @MainActor @Sendable () async throws -> ScheduleAuthorizationReceipt
    package let submit:
        @MainActor @Sendable (ScheduleNotificationRequest) async throws
            -> ScheduleNotificationReceipt

    package init(
        requestAuthorization: @escaping @MainActor @Sendable () async throws
            -> ScheduleAuthorizationReceipt,
        submit: @escaping @MainActor @Sendable (ScheduleNotificationRequest)
            async throws -> ScheduleNotificationReceipt
    ) {
        self.requestAuthorization = requestAuthorization
        self.submit = submit
    }
}

package struct MissionWorkflowPorts: Sendable {
    package let retryCard:
        @MainActor @Sendable (String) async throws -> Void
    package let returnForRework:
        @MainActor @Sendable (String, String) async throws -> Void
    package let addBudget:
        @MainActor @Sendable (String, Int) async throws -> Void
    package let clearReview: @Sendable (String) throws -> Void
    package let setAutonomy:
        @Sendable (String, MissionAutonomy) throws -> Void
    package let dismissProposal: @Sendable (String) throws -> Void
    package let ensureReport: @Sendable (String) throws -> URL
    package let loadSchedules:
        @Sendable (String) throws -> ScheduleWorkflowSnapshot
    package let loadSchedulePresentation:
        @Sendable (String?, Date, TimeZone) throws
            -> SchedulePresentationSnapshot
    package let saveTemplate:
        @Sendable (MissionTemplateRecord) throws -> Void
    package let deleteTemplate:
        @Sendable (String) throws -> ScheduleTemplateDeletionReceipt
    package let saveSchedule: @Sendable (ScheduleRecord) throws -> Void
    package let setScheduleEnabled:
        @Sendable (String, Bool) throws -> ScheduleRecord
    package let deleteSchedule:
        @Sendable (String) throws -> ScheduleDeletionReceipt
    package let fire:
        @MainActor @Sendable (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let recordMissed:
        @MainActor @Sendable (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let replay:
        @MainActor @Sendable (ScheduleReplayRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let wake:
        @MainActor @Sendable (ScheduleFireCommitResult) async throws -> Void
    package let broadcastFire:
        @Sendable (ScheduleFireCommitResult) throws
            -> ScheduleBroadcastReceipt?
    package let broadcastOutcome:
        @Sendable (ScheduledMissionOutcomePlan) throws
            -> ScheduleBroadcastReceipt?

    package init(
        retryCard: @escaping @MainActor @Sendable (String) async throws
            -> Void,
        returnForRework: @escaping @MainActor @Sendable
            (String, String) async throws -> Void,
        addBudget: @escaping @MainActor @Sendable
            (String, Int) async throws -> Void,
        clearReview: @escaping @Sendable (String) throws -> Void,
        setAutonomy: @escaping @Sendable
            (String, MissionAutonomy) throws -> Void,
        dismissProposal: @escaping @Sendable (String) throws -> Void,
        ensureReport: @escaping @Sendable (String) throws -> URL,
        loadSchedules: @escaping @Sendable (String) throws
            -> ScheduleWorkflowSnapshot,
        loadSchedulePresentation: @escaping @Sendable
            (String?, Date, TimeZone) throws
            -> SchedulePresentationSnapshot,
        saveTemplate: @escaping @Sendable (MissionTemplateRecord) throws
            -> Void,
        deleteTemplate: @escaping @Sendable (String) throws
            -> ScheduleTemplateDeletionReceipt,
        saveSchedule: @escaping @Sendable (ScheduleRecord) throws -> Void,
        setScheduleEnabled: @escaping @Sendable
            (String, Bool) throws -> ScheduleRecord,
        deleteSchedule: @escaping @Sendable (String) throws
            -> ScheduleDeletionReceipt,
        fire: @escaping @MainActor @Sendable
            (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult,
        recordMissed: @escaping @MainActor @Sendable
            (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult,
        replay: @escaping @MainActor @Sendable
            (ScheduleReplayRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult,
        wake: @escaping @MainActor @Sendable
            (ScheduleFireCommitResult) async throws -> Void,
        broadcastFire: @escaping @Sendable
            (ScheduleFireCommitResult) throws -> ScheduleBroadcastReceipt?,
        broadcastOutcome: @escaping @Sendable
            (ScheduledMissionOutcomePlan) throws -> ScheduleBroadcastReceipt?
    ) {
        self.retryCard = retryCard
        self.returnForRework = returnForRework
        self.addBudget = addBudget
        self.clearReview = clearReview
        self.setAutonomy = setAutonomy
        self.dismissProposal = dismissProposal
        self.ensureReport = ensureReport
        self.loadSchedules = loadSchedules
        self.loadSchedulePresentation = loadSchedulePresentation
        self.saveTemplate = saveTemplate
        self.deleteTemplate = deleteTemplate
        self.saveSchedule = saveSchedule
        self.setScheduleEnabled = setScheduleEnabled
        self.deleteSchedule = deleteSchedule
        self.fire = fire
        self.recordMissed = recordMissed
        self.replay = replay
        self.wake = wake
        self.broadcastFire = broadcastFire
        self.broadcastOutcome = broadcastOutcome
    }

    package static func live(
        database: AppDatabase,
        orchestrator: Orchestrator,
        planningCoordinator: PlanningEntryCoordinator,
        reportStoreRoot: URL,
        reportStore: ManagedExpeditionReportStore? = nil,
        selectRuntime: @escaping @MainActor @Sendable () throws
            -> PlanningEntryRuntimeSelection
    ) -> Self {
        let activeReportStore = reportStore
            ?? ManagedExpeditionReportStore(
                database: database,
                reportStoreRoot: reportStoreRoot
            )
        return Self(
            retryCard: { try await orchestrator.retryCard($0) },
            returnForRework: {
                try await orchestrator.returnCardForRework(
                    cardId: $0,
                    feedback: $1
                )
            },
            addBudget: {
                try await orchestrator.addBudget(
                    missionId: $0,
                    tokens: $1
                )
            },
            clearReview: { try database.clearCardReviewFlag(cardId: $0) },
            setAutonomy: {
                try database.setMissionAutonomy(missionId: $0, to: $1)
            },
            dismissProposal: {
                _ = try database.dismissProposalBlock(messageId: $0)
            },
            ensureReport: { missionId in
                try activeReportStore.ensureReport(missionId: missionId)
            },
            loadSchedules: { campId in
                try Self.scheduleWorkflowSnapshot(
                    try database.readScheduleWorkflowBundle(campId: campId)
                )
            },
            loadSchedulePresentation: { templateId, now, timeZone in
                try Self.schedulePresentationSnapshot(
                    try database.readScheduleRuntimeBundle(
                        templateId: templateId
                    ),
                    now: now,
                    timeZone: timeZone
                )
            },
            saveTemplate: { try database.saveMissionTemplate($0) },
            deleteTemplate: { id in
                let preimage = try database
                    .deleteMissionTemplateWithPreimage(id: id)
                return ScheduleTemplateDeletionReceipt(
                    template: preimage.template,
                    deletedSchedules: preimage.deletedSchedules
                )
            },
            saveSchedule: { try database.saveSchedule($0) },
            setScheduleEnabled: {
                try database.setScheduleEnabled(id: $0, enabled: $1)
            },
            deleteSchedule: { id in
                ScheduleDeletionReceipt(
                    schedule: try database.deleteScheduleWithPreimage(id: id)
                )
            },
            fire: { request, trace in
                let command = try planningCoordinator.captureScheduledMission(
                    scheduleId: request.scheduleId,
                    context: request.context,
                    selectRuntime: selectRuntime,
                    traceId: trace.traceId
                )
                return try await planningCoordinator
                    .startScheduledMission(command)
            },
            recordMissed: { request, trace in
                let command = planningCoordinator
                    .captureMissedScheduledMission(
                        scheduleId: request.scheduleId,
                        context: request.context,
                        traceId: trace.traceId
                    )
                return try await planningCoordinator
                    .startScheduledMission(command)
            },
            replay: { request, trace in
                let command = try planningCoordinator.captureScheduleReplay(
                    originalFireId: request.originalFireId,
                    selectRuntime: selectRuntime,
                    traceId: trace.traceId
                )
                return try await planningCoordinator
                    .replayMissedScheduleFire(command)
            },
            wake: { try await planningCoordinator.wakeScheduledPlanning($0) },
            broadcastFire: { result in
                guard result.disposition == .inserted,
                      result.fire.state == .started
                else {
                    return nil
                }
                guard let template = try database.missionTemplate(
                    id: result.fire.templateId
                ) else {
                    throw RecordNotFoundError(
                        table: MissionTemplateRecord.databaseTableName,
                        id: result.fire.templateId
                    )
                }
                let messageId = try database.appendGuideBroadcast(
                    campId: template.campId,
                    text: "定时行动「\(template.name)」已出发：\(template.goal)"
                )
                return ScheduleBroadcastReceipt(
                    effectKey: "schedule-fire:\(result.fire.id):broadcast:v1",
                    campId: template.campId,
                    messageId: messageId
                )
            },
            broadcastOutcome: { plan in
                guard let campId = plan.broadcastCampId,
                      let text = plan.broadcastText
                else {
                    return nil
                }
                let messageId = try database.appendGuideBroadcast(
                    campId: campId,
                    text: text
                )
                return ScheduleBroadcastReceipt(
                    effectKey: plan.effectKey,
                    campId: campId,
                    messageId: messageId
                )
            }
        )
    }

    private static func scheduleWorkflowSnapshot(
        _ bundle: ScheduleWorkflowReadBundle
    ) throws -> ScheduleWorkflowSnapshot {
        ScheduleWorkflowSnapshot(
            campId: bundle.campId,
            templates: try bundle.templates.map(templateProjection),
            schedules: try bundle.schedules.map(scheduleProjection)
        )
    }

    private static func schedulePresentationSnapshot(
        _ bundle: ScheduleRuntimeReadBundle,
        now: Date,
        timeZone: TimeZone
    ) throws -> SchedulePresentationSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let enabled = try bundle.enabled.map { item in
            guard let nextFireDate = ScheduleMath.nextFireDate(
                after: now,
                frequency: item.schedule.frequency,
                hour: item.schedule.hour,
                minute: item.schedule.minute,
                weekday: item.schedule.weekday,
                calendar: calendar,
                timeZone: timeZone
            ) else {
                throw ProjectionContractError.invalidPayload
            }
            return EnabledScheduleProjection(
                record: item,
                nextFireDate: nextFireDate
            )
        }
        return SchedulePresentationSnapshot(
            enabled: enabled,
            requestedTemplate: try bundle.requestedTemplate.map(
                templateProjection
            )
        )
    }

    fileprivate static func templateProjection(
        _ record: MissionTemplateRecord
    ) throws -> ScheduleTemplateProjection {
        let budget = try record.validateForScheduledMission()
        let companionIds = try record.companionIds().map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let primaryCompanionId = companionIds.first,
              !primaryCompanionId.isEmpty
        else {
            throw MissionTemplateValidationError.invalidCompanionIds
        }
        return ScheduleTemplateProjection(
            record: record,
            companionIds: companionIds,
            primaryCompanionId: primaryCompanionId,
            budgetTokens: budget
        )
    }

    fileprivate static func scheduleProjection(
        _ record: ScheduleRecord
    ) throws -> ScheduleRecordProjection {
        try record.validate()
        return ScheduleRecordProjection(
            record: record,
            validatedWeekday: record.frequency == .daily
                ? nil
                : record.weekday
        )
    }
}

@MainActor
package final class MissionWorkflowController {
    private enum SchedulePostCommitApplicationStatus:
        Sendable, Equatable
    {
        case current
        case globallyVisible
    }

    private struct SchedulePostCommitApplicationState:
        Sendable, Equatable
    {
        let receipt: SchedulePostCommitApplicationReceipt
        let carrierId: UUID
    }

    private enum SchedulePostCommitApplicationCarrierLocation:
        Sendable, Equatable
    {
        case unpublished(ownerId: UUID)
        case published(receipt: SchedulePostCommitApplicationReceipt)
    }

    private struct SchedulePostCommitApplicationCarrier:
        Sendable, Equatable
    {
        let carrierId: UUID
        var ownedKeys: Set<SchedulePostCommitRepairKey>
        var program: SchedulePostCommitCanonicalProgram
        var visibilityStage: SchedulePostCommitRepairStage
        var status: SchedulePostCommitApplicationStatus
        var location: SchedulePostCommitApplicationCarrierLocation
    }

    private struct SchedulePostCommitApplicationTombstone:
        Sendable, Equatable
    {
        let receipt: SchedulePostCommitApplicationReceipt
    }

    fileprivate struct SchedulePostCommitOwnerState: Sendable, Equatable {
        let ownerId: UUID
        let identity: ScheduleMutationCommittedIdentity
        let ownedKeys: Set<SchedulePostCommitRepairKey>
        var evidence: SchedulePlatformEvidence
        var pendingSupersededRepairs: [SchedulePostCommitRepairReceipt]
        var applicationCarrierId: UUID
        var phase: SchedulePostCommitOwnerPhase
        var pendingApplicationId: UUID?
    }

    private struct SchedulePostCommitRepairFlight {
        let attempt: UUID
        let startingReceipt: SchedulePostCommitRepairReceipt
        let applicationCarrierId: UUID
        let task: Task<SchedulePostCommitRepairOutcome, Never>
    }

    private let orchestrator: Orchestrator
    private let reporter: FailureReporter
    private let reads: MissionWorkflowReads
    private let ports: MissionWorkflowPorts
    private let traceFactory: OperationTraceFactory
    private let registrationEvaluation:
        @Sendable () -> ScheduleRegistrationEvaluation
    private let scheduleRuntimeRead:
        @Sendable (String?) throws -> ScheduleRuntimeReadBundle
    private let scheduledMissionNotificationRead:
        @Sendable (String) throws -> ScheduledMissionNotificationReadBundle?

    private var schedulePostCommitOwnerStateById:
        [UUID: SchedulePostCommitOwnerState] = [:]
    private var schedulePostCommitCurrentOwnerIdByKey:
        [SchedulePostCommitRepairKey: UUID] = [:]
    private var schedulePostCommitApplicationStateById:
        [UUID: SchedulePostCommitApplicationState] = [:]
    private var schedulePostCommitApplicationCarrierById:
        [UUID: SchedulePostCommitApplicationCarrier] = [:]
    private var schedulePostCommitCurrentCarrierIdByKey:
        [SchedulePostCommitRepairKey: UUID] = [:]
    private var schedulePostCommitApplicationTombstoneById:
        [UUID: SchedulePostCommitApplicationTombstone] = [:]
    private var schedulePostCommitRepairFlightById:
        [UUID: SchedulePostCommitRepairFlight] = [:]

    package init(
        database: AppDatabase,
        orchestrator: Orchestrator,
        planningCoordinator: PlanningEntryCoordinator,
        reportStoreRoot: URL,
        selectRuntime: @escaping @MainActor @Sendable () throws
            -> PlanningEntryRuntimeSelection,
        reporter: FailureReporter,
        traceFactory: OperationTraceFactory,
        registrationEvaluation: @escaping @Sendable ()
            -> ScheduleRegistrationEvaluation,
        reads: MissionWorkflowReads? = nil,
        ports: MissionWorkflowPorts? = nil,
        reportStore: ManagedExpeditionReportStore? = nil
    ) {
        self.orchestrator = orchestrator
        self.reporter = reporter
        self.reads = reads ?? .live(database: database)
        self.traceFactory = traceFactory
        self.registrationEvaluation = registrationEvaluation
        self.scheduleRuntimeRead = {
            try database.readScheduleRuntimeBundle(templateId: $0)
        }
        self.scheduledMissionNotificationRead = {
            try database.readScheduledMissionNotificationBundle(
                missionId: $0
            )
        }
        self.ports = ports ?? .live(
            database: database,
            orchestrator: orchestrator,
            planningCoordinator: planningCoordinator,
            reportStoreRoot: reportStoreRoot,
            reportStore: reportStore,
            selectRuntime: selectRuntime
        )
    }

    package func loadDetail(
        missionId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<MissionDetailSnapshot> {
        let read = reads.detail
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(missionId)
            return MissionDetailSnapshot(
                mission: bundle.mission,
                cards: bundle.cards,
                artifacts: bundle.artifacts,
                pendingRequests: bundle.pendingRequests,
                squad: bundle.squad,
                squadMemberIds: bundle.squadMemberIds,
                companionsById: bundle.companionsById,
                events: bundle.events,
                spend: bundle.spend
            )
        }
    }

    package func loadIndex(
        includeArchived: Bool,
        trace: OperationTrace
    ) async -> WorkflowLoadState<MissionIndexSnapshot> {
        let read = reads.index
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(includeArchived)
            return MissionIndexSnapshot(
                missions: bundle.missions,
                camps: bundle.camps,
                missionsByCamp: bundle.missionsByCamp,
                artifactLedger: bundle.artifactLedger
            )
        }
    }

    package func start(
        _ request: MissionStartRequest,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<String> {
        guard request.durableTraceId == trace.traceId else {
            return .notCommitted(
                reporter.capture(
                    TraceIdentityConflictError(),
                    trace: trace
                )
            )
        }
        return await orchestrator.startMission(
            goal: request.goal,
            companionIds: request.companionIds,
            workspacePath: request.workspacePath,
            plannerModel: request.plannerModel,
            runtimeProfileId: request.runtimeProfileId,
            budgetTokens: request.budgetTokens,
            campId: request.campId,
            autonomy: request.autonomy,
            idempotencyKey: request.idempotencyKey,
            trace: trace
        )
    }

    package func loadSchedules(
        campId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<ScheduleWorkflowSnapshot> {
        let load = ports.loadSchedules
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try load(campId)
        }
    }

    package func loadSchedulePresentation(
        templateId: String?,
        now: Date,
        timeZone: TimeZone,
        trace: OperationTrace
    ) async -> WorkflowLoadState<SchedulePresentationSnapshot> {
        let load = ports.loadSchedulePresentation
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try load(templateId, now, timeZone)
        }
    }

    package func saveTemplateDraft(
        _ draft: ScheduleTemplateDraftCommand,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let template: MissionTemplateRecord
        do {
            let companionId = draft.companionId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !companionId.isEmpty,
                  let budget = Int(
                    draft.budgetText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                  )
            else {
                throw MissionTemplateValidationError.invalidCompanionIds
            }
            template = MissionTemplateRecord(
                id: draft.existingId ?? UUID().uuidString,
                name: draft.name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                goal: draft.goal.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                companionIdsJson: try MissionTemplateRecord
                    .companionIdsJSON([companionId]),
                workspacePath: Self.optionalNonBlank(draft.workspacePath),
                budgetTokens: budget,
                autonomy: draft.autonomy,
                campId: draft.campId,
                createdAt: Date()
            )
            _ = try template.validateForScheduledMission()
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await saveTemplate(
            template,
            registration: registration,
            trace: trace
        )
    }

    package func saveTemplate(
        _ template: MissionTemplateRecord,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        do {
            _ = try template.validateForScheduledMission()
            try ports.saveTemplate(template)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await completeCommittedScheduleMutation(
            identity: .templateSaved(template),
            requiresAuthorization: false,
            registration: registration,
            notifications: nil,
            trace: trace
        )
    }

    package func deleteTemplate(
        id: String,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let receipt: ScheduleTemplateDeletionReceipt
        do {
            receipt = try ports.deleteTemplate(id)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await completeCommittedScheduleMutation(
            identity: .templateDeleted(receipt),
            requiresAuthorization: false,
            registration: registration,
            notifications: nil,
            trace: trace
        )
    }

    package func saveScheduleDraft(
        _ draft: ScheduleDraftCommand,
        calendar: Calendar,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: draft.selectedTime
        )
        guard let hour = components.hour,
              let minute = components.minute
        else {
            return .notCommitted(
                reporter.capture(
                    ProjectionContractError.invalidPayload,
                    trace: trace
                )
            )
        }
        let schedule = ScheduleRecord.new(
            templateId: draft.templateId,
            frequency: draft.frequency,
            hour: hour,
            minute: minute,
            weekday: draft.weekday,
            enabled: draft.enabled
        )
        return await saveSchedule(
            schedule,
            registration: registration,
            notifications: notifications,
            trace: trace
        )
    }

    package func saveSchedule(
        _ schedule: ScheduleRecord,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        do {
            try schedule.validate()
            try ports.saveSchedule(schedule)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await completeCommittedScheduleMutation(
            identity: .scheduleSaved(schedule),
            requiresAuthorization: schedule.enabled,
            registration: registration,
            notifications: notifications,
            trace: trace
        )
    }

    package func setScheduleEnabled(
        id: String,
        enabled: Bool,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let schedule: ScheduleRecord
        do {
            schedule = try ports.setScheduleEnabled(id, enabled)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await completeCommittedScheduleMutation(
            identity: .scheduleEnablementChanged(schedule),
            requiresAuthorization: schedule.enabled,
            registration: registration,
            notifications: notifications,
            trace: trace
        )
    }

    package func deleteSchedule(
        id: String,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let receipt: ScheduleDeletionReceipt
        do {
            receipt = try ports.deleteSchedule(id)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
        return await completeCommittedScheduleMutation(
            identity: .scheduleDeleted(receipt),
            requiresAuthorization: false,
            registration: registration,
            notifications: nil,
            trace: trace
        )
    }

    private func completeCommittedScheduleMutation(
        identity: ScheduleMutationCommittedIdentity,
        requiresAuthorization: Bool,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort?,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        let stage: SchedulePostCommitRepairStage = requiresAuthorization
            ? .authorizationThenRegistration
            : .registration
        let ownerId = installCommittedScheduleOwner(
            identity: identity,
            stage: stage,
            traceScope: trace.traceScope
        )

        if requiresAuthorization {
            guard let notifications else {
                return currentInitialFailure(
                    ownerId: ownerId,
                    stage: .authorizationThenRegistration,
                    error: SchedulePlatformFailure.authorization,
                    trace: trace
                )
            }
            do {
                let authorization = try await notifications
                    .requestAuthorization()
                guard updateInitialAuthorization(
                    ownerId: ownerId,
                    authorization: authorization
                ) else {
                    return .committedSuperseded
                }
            } catch {
                guard isCurrentPerformingOwner(ownerId) else {
                    return .committedSuperseded
                }
                return currentInitialFailure(
                    ownerId: ownerId,
                    stage: .authorizationThenRegistration,
                    error: error,
                    trace: trace
                )
            }
        }

        return await completeInitialRegistration(
            ownerId: ownerId,
            registration: registration,
            trace: trace
        )
    }

    private func completeInitialRegistration(
        ownerId: UUID,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome {
        guard isCurrentPerformingOwner(ownerId) else {
            return .committedSuperseded
        }
        let evaluation = registrationEvaluation()
        let registrations: [ScheduleActivityRegistration]
        do {
            registrations = try scheduleRegistrations(evaluation)
        } catch {
            guard isCurrentPerformingOwner(ownerId) else {
                return .committedSuperseded
            }
            return currentInitialFailure(
                ownerId: ownerId,
                stage: .registration,
                error: error,
                trace: trace
            )
        }

        do {
            let receipt = try await registration.replaceAll(registrations)
            if isCurrentPerformingOwner(ownerId) {
                guard recordInitialRegistration(
                    ownerId: ownerId,
                    registration: receipt
                ), let terminal = publishInitialSuccess(ownerId: ownerId)
                else {
                    return .committedSuperseded
                }
                return .committed(terminal)
            }
            if isGloballyVisibleAwaitingTerminal(ownerId) {
                guard let terminal = publishGloballyVisibleInitial(
                    ownerId: ownerId
                ) else {
                    return .committedSuperseded
                }
                return .committed(terminal)
            }
            return .committedSuperseded
        } catch {
            if isGloballyVisibleAwaitingTerminal(ownerId) {
                guard let terminal = publishGloballyVisibleInitial(
                    ownerId: ownerId
                ) else {
                    return .committedSuperseded
                }
                return .committed(terminal)
            }
            guard isCurrentPerformingOwner(ownerId) else {
                return .committedSuperseded
            }
            return currentInitialFailure(
                ownerId: ownerId,
                stage: .registration,
                error: error,
                trace: trace
            )
        }
    }

    package func consumeSchedulePostCommitApplication(
        _ receipt: SchedulePostCommitApplicationReceipt
    ) -> SchedulePostCommitApplicationDecision {
        if let state = schedulePostCommitApplicationStateById[
            receipt.applicationId
        ], state.receipt == receipt,
           let carrier = schedulePostCommitApplicationCarrierById[
            state.carrierId
           ], carrier.location == .published(receipt: receipt)
        {
            schedulePostCommitApplicationStateById[receipt.applicationId] = nil
            schedulePostCommitApplicationCarrierById[state.carrierId] = nil
            for key in carrier.ownedKeys where
                schedulePostCommitCurrentCarrierIdByKey[key]
                    == state.carrierId
            {
                schedulePostCommitCurrentCarrierIdByKey[key] = nil
            }
            for ownerId in schedulePostCommitOwnerStateById.keys {
                guard var owner = schedulePostCommitOwnerStateById[ownerId],
                      owner.pendingApplicationId == receipt.applicationId
                else {
                    continue
                }
                owner.pendingApplicationId = nil
                schedulePostCommitOwnerStateById[ownerId] = owner
            }
            return SchedulePostCommitApplicationDecision(
                storage: .apply(carrier.program)
            )
        }
        if schedulePostCommitApplicationTombstoneById[
            receipt.applicationId
        ]?.receipt == receipt {
            schedulePostCommitApplicationTombstoneById[
                receipt.applicationId
            ] = nil
            return SchedulePostCommitApplicationDecision(
                storage: .mutationSuperseded
            )
        }
        return SchedulePostCommitApplicationDecision(
            storage: .alreadyConsumed
        )
    }

    // P1-B-SEAM schedulePostCommitRepair
    package func retrySchedulePostCommit(
        _ receipt: SchedulePostCommitRepairReceipt,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort
    ) async -> SchedulePostCommitRepairOutcome {
        guard let owner = schedulePostCommitOwnerStateById[receipt.repairId],
              case .repair(let currentReceipt) = owner.phase,
              currentReceipt == receipt,
              owner.pendingApplicationId == nil,
              owner.ownedKeys.allSatisfy({
                schedulePostCommitCurrentOwnerIdByKey[$0]
                    == receipt.repairId
              })
        else {
            return .superseded
        }
        if let flight = schedulePostCommitRepairFlightById[
            receipt.repairId
        ] {
            guard flight.startingReceipt == receipt else {
                return .superseded
            }
            return await flight.task.value
        }

        let attempt = UUID()
        let carrierId = UUID()
        let carrier = SchedulePostCommitApplicationCarrier(
            carrierId: carrierId,
            ownedKeys: owner.ownedKeys,
            program: SchedulePostCommitCanonicalProgram(
                operations: [.project(owner.identity)],
                currentIdentity: owner.identity
            ),
            visibilityStage: receipt.stage,
            status: .current,
            location: .unpublished(ownerId: owner.ownerId)
        )
        var updatedOwner = owner
        updatedOwner.applicationCarrierId = carrierId
        schedulePostCommitOwnerStateById[owner.ownerId] = updatedOwner
        schedulePostCommitApplicationCarrierById[carrierId] = carrier
        for key in owner.ownedKeys {
            schedulePostCommitCurrentCarrierIdByKey[key] = carrierId
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return SchedulePostCommitRepairOutcome.superseded
            }
            let outcome = await self.runSchedulePostCommitRepair(
                startingReceipt: receipt,
                attempt: attempt,
                carrierId: carrierId,
                registration: registration,
                notifications: notifications
            )
            self.finishScheduleRepairFlight(
                repairId: receipt.repairId,
                attempt: attempt
            )
            return outcome
        }
        schedulePostCommitRepairFlightById[receipt.repairId] =
            SchedulePostCommitRepairFlight(
                attempt: attempt,
                startingReceipt: receipt,
                applicationCarrierId: carrierId,
                task: task
            )
        return await task.value
    }

    package func refreshSchedules(
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleRegistrationRefreshOutcome {
        let evaluation = registrationEvaluation()
        let registrations: [ScheduleActivityRegistration]
        do {
            registrations = try scheduleRegistrations(evaluation)
        } catch {
            return .failed(reporter.capture(error, trace: trace))
        }
        do {
            let receipt = try await registration.replaceAll(registrations)
            return .refreshed(
                registration: receipt,
                supersededRepairs:
                    markRegistrationVisibilityGloballyVisible()
            )
        } catch {
            return .failed(reporter.capture(error, trace: trace))
        }
    }

    package func loadStartupMissedFires(
        now: Date,
        timeZone: TimeZone,
        trace: OperationTrace
    ) async -> WorkflowLoadState<[ScheduleFireRequest]> {
        let read = scheduleRuntimeRead
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(nil)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            var requests: [ScheduleFireRequest] = []
            for item in bundle.enabled {
                guard let context = try ScheduleMath.latestUnevaluatedSlot(
                    now: now,
                    createdAt: item.schedule.createdAt,
                    cursor: bundle.cursorByScheduleId[item.schedule.id],
                    frequency: item.schedule.frequency,
                    hour: item.schedule.hour,
                    minute: item.schedule.minute,
                    weekday: item.schedule.weekday,
                    calendar: calendar,
                    timeZone: timeZone
                ) else {
                    continue
                }
                requests.append(
                    ScheduleFireRequest(
                        scheduleId: item.schedule.id,
                        context: context
                    )
                )
            }
            return requests
        }
    }

    package func prepareRunNow(
        scheduleId: String,
        now: Date,
        timeZone: TimeZone,
        trace: OperationTrace
    ) async -> WorkflowLoadState<ScheduleFireRequest> {
        let read = scheduleRuntimeRead
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(nil)
            guard let item = bundle.enabled.first(where: {
                $0.schedule.id == scheduleId
            }) else {
                throw RecordNotFoundError(
                    table: ScheduleRecord.databaseTableName,
                    id: scheduleId
                )
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let context = try ScheduleMath.slotContext(
                for: now,
                frequency: item.schedule.frequency,
                hour: item.schedule.hour,
                minute: item.schedule.minute,
                weekday: item.schedule.weekday,
                calendar: calendar,
                timeZone: timeZone
            )
            return ScheduleFireRequest(
                scheduleId: scheduleId,
                context: context
            )
        }
    }

    package func fireSchedule(
        _ request: ScheduleFireRequest,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleFireCommitResult> {
        do {
            return .committed(try await ports.fire(request, trace))
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    package func recordMissedSchedule(
        _ request: ScheduleFireRequest,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleFireCommitResult> {
        do {
            return .committed(try await ports.recordMissed(request, trace))
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    package func replaySchedule(
        _ request: ScheduleReplayRequest,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleFireCommitResult> {
        do {
            return .committed(try await ports.replay(request, trace))
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    package func publishScheduleWake(
        _ result: ScheduleFireCommitResult,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleFireCommitResult> {
        do {
            try await ports.wake(result)
            return .committed(result)
        } catch {
            return .committedWithVisibilityFailure(
                value: result,
                failure: reporter.capture(error, trace: trace)
            )
        }
    }

    package func publishScheduleBroadcast(
        _ result: ScheduleFireCommitResult,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleFireCommitResult> {
        do {
            _ = try ports.broadcastFire(result)
            return .committed(result)
        } catch {
            return .committedWithVisibilityFailure(
                value: result,
                failure: reporter.capture(error, trace: trace)
            )
        }
    }

    package func loadScheduledMissionOutcomePlans(
        missionId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<[ScheduledMissionOutcomePlan]> {
        let read = scheduledMissionNotificationRead
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            guard let bundle = try read(missionId) else { return [] }
            let title = Self.scheduledMissionTitle(bundle.mission)
            var plans: [ScheduledMissionOutcomePlan] = []
            if bundle.events.contains(where: {
                $0.kind == EventKind.missionBudgetExhausted
            }) {
                plans.append(
                    Self.scheduledMissionOutcomePlan(
                        missionId: missionId,
                        campId: bundle.squad.campId,
                        title: title,
                        kind: .budgetExhausted,
                        broadcastText:
                            "定时行动「\(title)」预算用尽，已暂停派发。"
                    )
                )
            }
            switch bundle.mission.status {
            case .accepted:
                plans.append(
                    Self.scheduledMissionOutcomePlan(
                        missionId: missionId,
                        campId: bundle.squad.campId,
                        title: title,
                        kind: .closeout,
                        broadcastText: "定时行动「\(title)」已收营。"
                    )
                )
            case .failed:
                plans.append(
                    Self.scheduledMissionOutcomePlan(
                        missionId: missionId,
                        campId: bundle.squad.campId,
                        title: title,
                        kind: .failure,
                        broadcastText:
                            "定时行动「\(title)」失败了，请回来查看原因。"
                    )
                )
            case .planning, .executing, .delivering:
                break
            }
            return plans
        }
    }

    package func publishScheduledMissionOutcomeBroadcast(
        _ plan: ScheduledMissionOutcomePlan,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduledMissionOutcomePlan> {
        do {
            _ = try ports.broadcastOutcome(plan)
            return .committed(plan)
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    package func requestScheduleAuthorization(
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleAuthorizationReceipt> {
        do {
            return .committed(
                try await notifications.requestAuthorization()
            )
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    package func submitScheduleNotification(
        _ request: ScheduleNotificationRequest,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleNotificationReceipt> {
        do {
            return .committed(try await notifications.submit(request))
        } catch {
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }

    private func runSchedulePostCommitRepair(
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort
    ) async -> SchedulePostCommitRepairOutcome {
        guard isCurrentRepairFlight(
            receipt: startingReceipt,
            attempt: attempt,
            carrierId: carrierId
        ) else {
            return .superseded
        }
        let trace = traceFactory.generated(
            operation: Self.repairOperation(
                for: startingReceipt.identity
            ),
            scope: startingReceipt.traceScope
        )
        switch startingReceipt.stage {
        case .authorizationThenRegistration:
            do {
                let authorization = try await notifications
                    .requestAuthorization()
                guard let transitioned = transitionRepairAuthorization(
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    authorization: authorization
                ) else {
                    return .superseded
                }
                return await completeRepairRegistration(
                    currentReceipt: transitioned,
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    registration: registration,
                    trace: trace
                )
            } catch {
                guard isCurrentRepairFlight(
                    receipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId
                ) else {
                    return .superseded
                }
                return publishRepairFailure(
                    currentReceipt: startingReceipt,
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    error: error,
                    trace: trace
                )
            }
        case .registration:
            return await completeRepairRegistration(
                currentReceipt: startingReceipt,
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId,
                registration: registration,
                trace: trace
            )
        }
    }

    private func completeRepairRegistration(
        currentReceipt: SchedulePostCommitRepairReceipt,
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> SchedulePostCommitRepairOutcome {
        guard isCurrentRepairFlight(
            receipt: currentReceipt,
            attempt: attempt,
            carrierId: carrierId
        ) else {
            return .superseded
        }
        let evaluation = registrationEvaluation()
        let registrations: [ScheduleActivityRegistration]
        do {
            registrations = try scheduleRegistrations(evaluation)
        } catch {
            guard isCurrentRepairFlight(
                receipt: currentReceipt,
                attempt: attempt,
                carrierId: carrierId
            ) else {
                return .superseded
            }
            return publishRepairFailure(
                currentReceipt: currentReceipt,
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId,
                error: error,
                trace: trace
            )
        }

        do {
            let registrationReceipt = try await registration
                .replaceAll(registrations)
            if isCurrentRepairFlight(
                receipt: currentReceipt,
                attempt: attempt,
                carrierId: carrierId
            ) {
                guard recordRepairRegistration(
                    receipt: currentReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    registration: registrationReceipt
                ) else {
                    return .superseded
                }
                return publishRepairSuccess(
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    globallyVisible: false
                )
            }
            if isGloballyVisibleRepairFlight(
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId
            ) {
                return publishRepairSuccess(
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    globallyVisible: true
                )
            }
            return .superseded
        } catch {
            if isGloballyVisibleRepairFlight(
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId
            ) {
                return publishRepairSuccess(
                    startingReceipt: startingReceipt,
                    attempt: attempt,
                    carrierId: carrierId,
                    globallyVisible: true
                )
            }
            guard isCurrentRepairFlight(
                receipt: currentReceipt,
                attempt: attempt,
                carrierId: carrierId
            ) else {
                return .superseded
            }
            return publishRepairFailure(
                currentReceipt: currentReceipt,
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId,
                error: error,
                trace: trace
            )
        }
    }

    private func isCurrentRepairFlight(
        receipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID
    ) -> Bool {
        guard let owner = schedulePostCommitOwnerStateById[receipt.repairId],
              case .repair(let currentReceipt) = owner.phase,
              currentReceipt == receipt,
              owner.pendingApplicationId == nil,
              owner.applicationCarrierId == carrierId,
              owner.ownedKeys.allSatisfy({
                schedulePostCommitCurrentOwnerIdByKey[$0]
                    == receipt.repairId
              }),
              let flight = schedulePostCommitRepairFlightById[
                receipt.repairId
              ],
              flight.attempt == attempt,
              flight.startingReceipt.repairId == receipt.repairId,
              flight.applicationCarrierId == carrierId,
              let carrier = schedulePostCommitApplicationCarrierById[
                carrierId
              ],
              carrier.location == .unpublished(ownerId: receipt.repairId),
              owner.ownedKeys.allSatisfy({
                schedulePostCommitCurrentCarrierIdByKey[$0] == carrierId
              })
        else {
            return false
        }
        return true
    }

    private func isGloballyVisibleRepairFlight(
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID
    ) -> Bool {
        guard let owner = schedulePostCommitOwnerStateById[
            startingReceipt.repairId
        ], case .globallyVisibleAwaitingTerminal(let currentCarrierId)
            = owner.phase,
           currentCarrierId == carrierId,
           owner.applicationCarrierId == carrierId,
           owner.ownedKeys.allSatisfy({
               schedulePostCommitCurrentOwnerIdByKey[$0]
                   == startingReceipt.repairId
           }),
           let flight = schedulePostCommitRepairFlightById[
            startingReceipt.repairId
           ], flight.attempt == attempt,
           flight.startingReceipt == startingReceipt,
           flight.applicationCarrierId == carrierId,
           let carrier = schedulePostCommitApplicationCarrierById[carrierId],
           carrier.location == .unpublished(
            ownerId: startingReceipt.repairId
           ), carrier.status == .globallyVisible
        else {
            return false
        }
        return true
    }

    private func transitionRepairAuthorization(
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        authorization: ScheduleAuthorizationReceipt
    ) -> SchedulePostCommitRepairReceipt? {
        guard isCurrentRepairFlight(
            receipt: startingReceipt,
            attempt: attempt,
            carrierId: carrierId
        ), var owner = schedulePostCommitOwnerStateById[
            startingReceipt.repairId
        ], var carrier = schedulePostCommitApplicationCarrierById[carrierId]
        else {
            return nil
        }
        let evidence = SchedulePlatformEvidence(
            authorization: authorization,
            registration: nil
        )
        let transitioned = SchedulePostCommitRepairReceipt(
            repairId: startingReceipt.repairId,
            identity: owner.identity,
            stage: .registration,
            traceScope: startingReceipt.traceScope,
            ownedKeys: owner.ownedKeys,
            evidence: evidence
        )
        owner.evidence = evidence
        owner.phase = .repair(transitioned)
        carrier.visibilityStage = .registration
        schedulePostCommitOwnerStateById[owner.ownerId] = owner
        schedulePostCommitApplicationCarrierById[carrierId] = carrier
        return transitioned
    }

    private func recordRepairRegistration(
        receipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        registration: ScheduleRegistrationReceipt
    ) -> Bool {
        guard isCurrentRepairFlight(
            receipt: receipt,
            attempt: attempt,
            carrierId: carrierId
        ), var owner = schedulePostCommitOwnerStateById[receipt.repairId]
        else {
            return false
        }
        owner.evidence = SchedulePlatformEvidence(
            authorization: owner.evidence.authorization,
            registration: registration
        )
        schedulePostCommitOwnerStateById[owner.ownerId] = owner
        return true
    }

    private func publishRepairFailure(
        currentReceipt: SchedulePostCommitRepairReceipt,
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        error: Error,
        trace: OperationTrace
    ) -> SchedulePostCommitRepairOutcome {
        guard isCurrentRepairFlight(
            receipt: currentReceipt,
            attempt: attempt,
            carrierId: carrierId
        ), var owner = schedulePostCommitOwnerStateById[
            currentReceipt.repairId
        ] else {
            return .superseded
        }
        let failure = reporter.capture(error, trace: trace)
        let returnedRepair = SchedulePostCommitRepairReceipt(
            repairId: currentReceipt.repairId,
            identity: owner.identity,
            stage: currentReceipt.stage,
            traceScope: currentReceipt.traceScope,
            ownedKeys: owner.ownedKeys,
            evidence: owner.evidence
        )
        owner.phase = .repair(returnedRepair)
        schedulePostCommitOwnerStateById[owner.ownerId] = owner
        let operations: [SchedulePostCommitApplicationOperation] =
            [.clearRepair(startingReceipt)]
            + Self.evidenceOperations(owner.evidence)
            + [.installRepair(
                identity: owner.identity,
                repair: returnedRepair,
                failure: failure
            )]
        guard let application = publishScheduleApplication(
            ownerId: owner.ownerId,
            terminalOperations: operations,
            globallyVisible: false,
            retainsOwner: true
        ) else {
            return .superseded
        }
        return .stillPending(
            ScheduleStillPendingTerminal(application: application)
        )
    }

    private func publishRepairSuccess(
        startingReceipt: SchedulePostCommitRepairReceipt,
        attempt: UUID,
        carrierId: UUID,
        globallyVisible: Bool
    ) -> SchedulePostCommitRepairOutcome {
        let owner: SchedulePostCommitOwnerState
        if globallyVisible {
            guard isGloballyVisibleRepairFlight(
                startingReceipt: startingReceipt,
                attempt: attempt,
                carrierId: carrierId
            ), let current = schedulePostCommitOwnerStateById[
                startingReceipt.repairId
            ] else {
                return .superseded
            }
            owner = current
        } else {
            guard let current = schedulePostCommitOwnerStateById[
                startingReceipt.repairId
            ], case .repair(let receipt) = current.phase,
               isCurrentRepairFlight(
                receipt: receipt,
                attempt: attempt,
                carrierId: carrierId
               )
            else {
                return .superseded
            }
            owner = current
        }
        let operations: [SchedulePostCommitApplicationOperation] =
            [.clearRepair(startingReceipt)]
            + Self.evidenceOperations(owner.evidence)
        guard let application = publishScheduleApplication(
            ownerId: owner.ownerId,
            terminalOperations: operations,
            globallyVisible: globallyVisible,
            retainsOwner: false
        ) else {
            return .superseded
        }
        removeScheduleOwner(owner.ownerId, cancelFlight: false)
        return .repaired(
            ScheduleRepairedTerminal(application: application)
        )
    }

    private func finishScheduleRepairFlight(
        repairId: UUID,
        attempt: UUID
    ) {
        guard schedulePostCommitRepairFlightById[repairId]?.attempt
                == attempt
        else {
            return
        }
        schedulePostCommitRepairFlightById[repairId] = nil
    }

    private func markRegistrationVisibilityGloballyVisible()
        -> [SchedulePostCommitRepairReceipt]
    {
        var returnedRepairs: [SchedulePostCommitRepairReceipt] = []
        let ownerIds = schedulePostCommitOwnerStateById.keys.sorted {
            $0.uuidString.utf8.lexicographicallyPrecedes($1.uuidString.utf8)
        }
        for ownerId in ownerIds {
            guard var owner = schedulePostCommitOwnerStateById[ownerId]
            else {
                continue
            }
            switch owner.phase {
            case .performing:
                guard var carrier = schedulePostCommitApplicationCarrierById[
                    owner.applicationCarrierId
                ], carrier.visibilityStage == .registration,
                   carrier.location == .unpublished(ownerId: ownerId)
                else {
                    continue
                }
                carrier.status = .globallyVisible
                schedulePostCommitApplicationCarrierById[
                    carrier.carrierId
                ] = carrier
                owner.phase = .globallyVisibleAwaitingTerminal(
                    applicationCarrierId: carrier.carrierId
                )
                schedulePostCommitOwnerStateById[ownerId] = owner
            case .repair(let receipt):
                guard receipt.stage == .registration else {
                    continue
                }
                if var carrier = schedulePostCommitApplicationCarrierById[
                    owner.applicationCarrierId
                ] {
                    switch carrier.location {
                    case .unpublished(let carrierOwnerId)
                        where carrierOwnerId == ownerId:
                        carrier.status = .globallyVisible
                        schedulePostCommitApplicationCarrierById[
                            carrier.carrierId
                        ] = carrier
                        owner.phase = .globallyVisibleAwaitingTerminal(
                            applicationCarrierId: carrier.carrierId
                        )
                        schedulePostCommitOwnerStateById[ownerId] = owner
                    case .published:
                        carrier.program = SchedulePostCommitCanonicalProgram(
                            operations: Self
                                .normalizedGloballyVisibleOperations(
                                    carrier.program.operations
                                ),
                            currentIdentity: carrier.program.currentIdentity
                        )
                        carrier.status = .globallyVisible
                        schedulePostCommitApplicationCarrierById[
                            carrier.carrierId
                        ] = carrier
                        removeScheduleOwner(ownerId, cancelFlight: true)
                    case .unpublished:
                        continue
                    }
                } else {
                    returnedRepairs.append(receipt)
                    removeScheduleOwner(ownerId, cancelFlight: true)
                }
            case .globallyVisibleAwaitingTerminal:
                continue
            }
        }

        let carrierIds = schedulePostCommitApplicationCarrierById.keys
        for carrierId in carrierIds {
            guard var carrier = schedulePostCommitApplicationCarrierById[
                carrierId
            ], carrier.visibilityStage == .registration,
               carrier.status == .current,
               case .published = carrier.location
            else {
                continue
            }
            carrier.program = SchedulePostCommitCanonicalProgram(
                operations: Self.normalizedGloballyVisibleOperations(
                    carrier.program.operations
                ),
                currentIdentity: carrier.program.currentIdentity
            )
            carrier.status = .globallyVisible
            schedulePostCommitApplicationCarrierById[carrierId] = carrier
        }
        return Self.uniqueSortedRepairs(returnedRepairs)
    }

    private static func repairOperation(
        for identity: ScheduleMutationCommittedIdentity
    ) -> FailureOperation {
        switch identity {
        case .templateSaved:
            return .scheduleTemplateSave
        case .templateDeleted:
            return .scheduleTemplateDelete
        case .scheduleSaved:
            return .scheduleSave
        case .scheduleEnablementChanged:
            return .scheduleEnable
        case .scheduleDeleted:
            return .scheduleDelete
        }
    }

    private func installCommittedScheduleOwner(
        identity: ScheduleMutationCommittedIdentity,
        stage: SchedulePostCommitRepairStage,
        traceScope: FailureTraceScope
    ) -> UUID {
        let committedKeys = Self.scheduleKeys(for: identity)
        var predecessorCarrierIds = Set<UUID>()
        for key in committedKeys {
            if let carrierId = schedulePostCommitCurrentCarrierIdByKey[key] {
                predecessorCarrierIds.insert(carrierId)
            }
        }
        let predecessorCarriers = predecessorCarrierIds.compactMap {
            schedulePostCommitApplicationCarrierById[$0]
        }.sorted {
            Self.carrierSortKey($0).utf8.lexicographicallyPrecedes(
                Self.carrierSortKey($1).utf8
            )
        }

        var predecessorOwnerIds = Set<UUID>()
        for key in committedKeys {
            if let ownerId = schedulePostCommitCurrentOwnerIdByKey[key] {
                predecessorOwnerIds.insert(ownerId)
            }
        }
        for carrier in predecessorCarriers {
            if case .unpublished(let ownerId) = carrier.location {
                predecessorOwnerIds.insert(ownerId)
            }
            for owner in schedulePostCommitOwnerStateById.values where
                owner.applicationCarrierId == carrier.carrierId
            {
                predecessorOwnerIds.insert(owner.ownerId)
            }
        }
        let predecessorOwners = predecessorOwnerIds.compactMap {
            schedulePostCommitOwnerStateById[$0]
        }

        var inheritedKeys = committedKeys
        var operations: [SchedulePostCommitApplicationOperation] = []
        for carrier in predecessorCarriers {
            inheritedKeys.formUnion(carrier.ownedKeys)
            operations.append(contentsOf: carrier.program.operations)
        }

        var repairs: [SchedulePostCommitRepairReceipt] = []
        for owner in predecessorOwners {
            if !predecessorCarrierIds.contains(owner.applicationCarrierId) {
                repairs.append(contentsOf: owner.pendingSupersededRepairs)
            }
            if case .repair(let receipt) = owner.phase {
                repairs.append(receipt)
            }
        }
        repairs = Self.uniqueSortedRepairs(repairs)

        for carrier in predecessorCarriers {
            if case .published(let receipt) = carrier.location {
                schedulePostCommitApplicationStateById[
                    receipt.applicationId
                ] = nil
                schedulePostCommitApplicationTombstoneById[
                    receipt.applicationId
                ] = SchedulePostCommitApplicationTombstone(
                    receipt: receipt
                )
            }
            schedulePostCommitApplicationCarrierById[carrier.carrierId] = nil
            for key in carrier.ownedKeys where
                schedulePostCommitCurrentCarrierIdByKey[key]
                    == carrier.carrierId
            {
                schedulePostCommitCurrentCarrierIdByKey[key] = nil
            }
        }
        for owner in predecessorOwners {
            removeScheduleOwner(owner.ownerId, cancelFlight: true)
        }

        operations.append(.project(identity))
        operations.append(contentsOf: repairs.map {
            .clearRepair($0)
        })

        let ownerId = UUID()
        let carrierId = UUID()
        let carrier = SchedulePostCommitApplicationCarrier(
            carrierId: carrierId,
            ownedKeys: inheritedKeys,
            program: SchedulePostCommitCanonicalProgram(
                operations: operations,
                currentIdentity: identity
            ),
            visibilityStage: stage,
            status: .current,
            location: .unpublished(ownerId: ownerId)
        )
        let owner = SchedulePostCommitOwnerState(
            ownerId: ownerId,
            identity: identity,
            ownedKeys: committedKeys,
            evidence: SchedulePlatformEvidence(
                authorization: nil,
                registration: nil
            ),
            pendingSupersededRepairs: repairs,
            applicationCarrierId: carrierId,
            phase: .performing,
            pendingApplicationId: nil
        )
        schedulePostCommitApplicationCarrierById[carrierId] = carrier
        for key in inheritedKeys {
            schedulePostCommitCurrentCarrierIdByKey[key] = carrierId
        }
        schedulePostCommitOwnerStateById[ownerId] = owner
        for key in committedKeys {
            schedulePostCommitCurrentOwnerIdByKey[key] = ownerId
        }
        _ = traceScope
        return ownerId
    }

    private func isCurrentPerformingOwner(_ ownerId: UUID) -> Bool {
        guard let owner = schedulePostCommitOwnerStateById[ownerId],
              owner.phase == .performing,
              owner.pendingApplicationId == nil
        else {
            return false
        }
        return owner.ownedKeys.allSatisfy {
            schedulePostCommitCurrentOwnerIdByKey[$0] == ownerId
        }
    }

    private func isGloballyVisibleAwaitingTerminal(_ ownerId: UUID) -> Bool {
        guard let owner = schedulePostCommitOwnerStateById[ownerId],
              case .globallyVisibleAwaitingTerminal(let carrierId)
                = owner.phase,
              carrierId == owner.applicationCarrierId
        else {
            return false
        }
        return owner.ownedKeys.allSatisfy {
            schedulePostCommitCurrentOwnerIdByKey[$0] == ownerId
        }
    }

    private func updateInitialAuthorization(
        ownerId: UUID,
        authorization: ScheduleAuthorizationReceipt
    ) -> Bool {
        guard var owner = schedulePostCommitOwnerStateById[ownerId],
              isCurrentPerformingOwner(ownerId),
              var carrier = schedulePostCommitApplicationCarrierById[
                owner.applicationCarrierId
              ],
              carrier.location == .unpublished(ownerId: ownerId),
              carrier.visibilityStage == .authorizationThenRegistration
        else {
            return false
        }
        owner.evidence = SchedulePlatformEvidence(
            authorization: authorization,
            registration: nil
        )
        carrier.visibilityStage = .registration
        schedulePostCommitOwnerStateById[ownerId] = owner
        schedulePostCommitApplicationCarrierById[carrier.carrierId] = carrier
        return true
    }

    private func recordInitialRegistration(
        ownerId: UUID,
        registration: ScheduleRegistrationReceipt
    ) -> Bool {
        guard var owner = schedulePostCommitOwnerStateById[ownerId],
              isCurrentPerformingOwner(ownerId)
        else {
            return false
        }
        owner.evidence = SchedulePlatformEvidence(
            authorization: owner.evidence.authorization,
            registration: registration
        )
        schedulePostCommitOwnerStateById[ownerId] = owner
        return true
    }

    private func currentInitialFailure(
        ownerId: UUID,
        stage: SchedulePostCommitRepairStage,
        error: Error,
        trace: OperationTrace
    ) -> ScheduleMutationOutcome {
        guard var owner = schedulePostCommitOwnerStateById[ownerId],
              isCurrentPerformingOwner(ownerId)
        else {
            return .committedSuperseded
        }
        let failure = reporter.capture(error, trace: trace)
        let repair = SchedulePostCommitRepairReceipt(
            repairId: ownerId,
            identity: owner.identity,
            stage: stage,
            traceScope: trace.traceScope,
            ownedKeys: owner.ownedKeys,
            evidence: owner.evidence
        )
        owner.phase = .repair(repair)
        schedulePostCommitOwnerStateById[ownerId] = owner
        guard let terminal = publishScheduleApplication(
            ownerId: ownerId,
            terminalOperations:
                Self.evidenceOperations(owner.evidence)
                + [.installRepair(
                    identity: owner.identity,
                    repair: repair,
                    failure: failure
                )],
            globallyVisible: false,
            retainsOwner: true
        ) else {
            return .committedSuperseded
        }
        return .committedWithVisibilityFailure(
            ScheduleVisibilityFailureTerminal(
                application: terminal
            )
        )
    }

    private func publishInitialSuccess(
        ownerId: UUID
    ) -> ScheduleCommittedTerminal? {
        guard let owner = schedulePostCommitOwnerStateById[ownerId],
              isCurrentPerformingOwner(ownerId),
              let receipt = publishScheduleApplication(
                ownerId: ownerId,
                terminalOperations: Self.evidenceOperations(owner.evidence),
                globallyVisible: false,
                retainsOwner: false
              )
        else {
            return nil
        }
        removeScheduleOwner(ownerId, cancelFlight: false)
        return ScheduleCommittedTerminal(application: receipt)
    }

    private func publishGloballyVisibleInitial(
        ownerId: UUID
    ) -> ScheduleCommittedTerminal? {
        guard let owner = schedulePostCommitOwnerStateById[ownerId],
              isGloballyVisibleAwaitingTerminal(ownerId),
              let receipt = publishScheduleApplication(
                ownerId: ownerId,
                terminalOperations: Self.evidenceOperations(owner.evidence),
                globallyVisible: true,
                retainsOwner: false
              )
        else {
            return nil
        }
        removeScheduleOwner(ownerId, cancelFlight: false)
        return ScheduleCommittedTerminal(application: receipt)
    }

    private func publishScheduleApplication(
        ownerId: UUID,
        terminalOperations: [SchedulePostCommitApplicationOperation],
        globallyVisible: Bool,
        retainsOwner: Bool
    ) -> SchedulePostCommitApplicationReceipt? {
        guard var owner = schedulePostCommitOwnerStateById[ownerId],
              owner.pendingApplicationId == nil,
              var carrier = schedulePostCommitApplicationCarrierById[
                owner.applicationCarrierId
              ],
              carrier.location == .unpublished(ownerId: ownerId)
        else {
            return nil
        }
        var operations = carrier.program.operations
        operations.append(contentsOf: terminalOperations)
        if globallyVisible {
            operations = Self.normalizedGloballyVisibleOperations(operations)
            carrier.status = .globallyVisible
        }
        carrier.program = SchedulePostCommitCanonicalProgram(
            operations: operations,
            currentIdentity: owner.identity
        )
        let receipt = SchedulePostCommitApplicationReceipt(
            applicationId: UUID()
        )
        carrier.location = .published(receipt: receipt)
        schedulePostCommitApplicationCarrierById[carrier.carrierId] = carrier
        schedulePostCommitApplicationStateById[receipt.applicationId] =
            SchedulePostCommitApplicationState(
                receipt: receipt,
                carrierId: carrier.carrierId
            )
        if retainsOwner {
            owner.pendingApplicationId = receipt.applicationId
            owner.pendingSupersededRepairs = []
            schedulePostCommitOwnerStateById[ownerId] = owner
        }
        return receipt
    }

    private func removeScheduleOwner(
        _ ownerId: UUID,
        cancelFlight: Bool
    ) {
        guard let owner = schedulePostCommitOwnerStateById.removeValue(
            forKey: ownerId
        ) else {
            return
        }
        for key in owner.ownedKeys where
            schedulePostCommitCurrentOwnerIdByKey[key] == ownerId
        {
            schedulePostCommitCurrentOwnerIdByKey[key] = nil
        }
        if let flight = schedulePostCommitRepairFlightById.removeValue(
            forKey: ownerId
        ), cancelFlight {
            flight.task.cancel()
        }
    }

    private func scheduleRegistrations(
        _ evaluation: ScheduleRegistrationEvaluation
    ) throws -> [ScheduleActivityRegistration] {
        let snapshot = try ports.loadSchedulePresentation(
            nil,
            evaluation.now,
            evaluation.timeZone
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = evaluation.timeZone
        return try snapshot.enabled.map { projection in
            let schedule = projection.record.schedule
            let context = try ScheduleMath.slotContext(
                for: projection.nextFireDate,
                frequency: schedule.frequency,
                hour: schedule.hour,
                minute: schedule.minute,
                weekday: schedule.weekday,
                calendar: calendar,
                timeZone: evaluation.timeZone
            )
            return ScheduleActivityRegistration(
                scheduleId: schedule.id,
                request: ScheduleFireRequest(
                    scheduleId: schedule.id,
                    context: context
                )
            )
        }
    }

    private static func scheduleKeys(
        for identity: ScheduleMutationCommittedIdentity
    ) -> Set<SchedulePostCommitRepairKey> {
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

    private static func carrierSortKey(
        _ carrier: SchedulePostCommitApplicationCarrier
    ) -> String {
        carrier.ownedKeys.map(scheduleKeyString).min {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        } ?? ""
    }

    private static func scheduleKeyString(
        _ key: SchedulePostCommitRepairKey
    ) -> String {
        switch key {
        case .template(let id): return "template:\(id)"
        case .schedule(let id): return "schedule:\(id)"
        }
    }

    private static func uniqueSortedRepairs(
        _ receipts: [SchedulePostCommitRepairReceipt]
    ) -> [SchedulePostCommitRepairReceipt] {
        var byId: [UUID: SchedulePostCommitRepairReceipt] = [:]
        for receipt in receipts {
            byId[receipt.repairId] = receipt
        }
        return byId.values.sorted {
            $0.repairId.uuidString.utf8.lexicographicallyPrecedes(
                $1.repairId.uuidString.utf8
            )
        }
    }

    private static func evidenceOperations(
        _ evidence: SchedulePlatformEvidence
    ) -> [SchedulePostCommitApplicationOperation] {
        var operations: [SchedulePostCommitApplicationOperation] = []
        if let authorization = evidence.authorization {
            operations.append(.authorizationEvidence(authorization))
        }
        if let registration = evidence.registration {
            operations.append(.registrationEvidence(registration))
        }
        return operations
    }

    private static func normalizedGloballyVisibleOperations(
        _ operations: [SchedulePostCommitApplicationOperation]
    ) -> [SchedulePostCommitApplicationOperation] {
        operations.filter {
            switch $0 {
            case .registrationEvidence, .installRepair:
                return false
            case .project, .authorizationEvidence, .clearRepair:
                return true
            }
        }
    }

    nonisolated private static func scheduledMissionOutcomePlan(
        missionId: String,
        campId: String,
        title: String,
        kind: ScheduleNotificationKind,
        broadcastText: String
    ) -> ScheduledMissionOutcomePlan {
        let notificationTitle: String
        switch kind {
        case .closeout:
            notificationTitle = "定时行动已收营"
        case .failure:
            notificationTitle = "定时行动受阻"
        case .budgetExhausted:
            notificationTitle = "定时行动预算用尽"
        }
        let effectKey = "\(kind.rawValue):\(missionId)"
        return ScheduledMissionOutcomePlan(
            effectKey: effectKey,
            missionId: missionId,
            broadcastCampId: campId,
            broadcastText: broadcastText,
            notification: ScheduleNotificationRequest(
                notificationId:
                    "agentloop.scheduled.\(missionId).\(kind.rawValue)",
                missionId: missionId,
                title: notificationTitle,
                body: title,
                kind: kind
            )
        )
    }

    nonisolated private static func scheduledMissionTitle(
        _ mission: MissionRecord
    ) -> String {
        let refined = mission.goalRefined.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let raw = mission.goalRaw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let base = refined.isEmpty ? raw : refined
        let firstLine = base.split(whereSeparator: \.isNewline).first
            .map(String.init) ?? base
        return firstLine.isEmpty
            ? "未命名行动"
            : String(firstLine.prefix(36))
    }

    private static func optionalNonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? nil : trimmed
    }
}
