import Foundation
import AgentLoopCore

package struct InputCampSnapshot: Sendable {
    package let camp: CampRecord
    package let guide: CompanionRecord
    package let ingestionItems: [IngestionItemRecord]
    package let activeRuminationByIngestion: [String: DurableWorkRecord]
    package let materializedNoteIdByIngestion: [String: String]
    package let missions: [MissionRecord]
    package let artifactCountByMission: [String: Int]
    package let campNotes: [CampNoteRecord]
    package let regularCompanions: [CompanionRecord]
    package let newcomerProgress: NewcomerProgress

    package init(
        camp: CampRecord,
        guide: CompanionRecord,
        ingestionItems: [IngestionItemRecord],
        activeRuminationByIngestion: [String: DurableWorkRecord],
        materializedNoteIdByIngestion: [String: String],
        missions: [MissionRecord],
        artifactCountByMission: [String: Int],
        campNotes: [CampNoteRecord],
        regularCompanions: [CompanionRecord],
        newcomerProgress: NewcomerProgress
    ) {
        self.camp = camp
        self.guide = guide
        self.ingestionItems = ingestionItems
        self.activeRuminationByIngestion = activeRuminationByIngestion
        self.materializedNoteIdByIngestion = materializedNoteIdByIngestion
        self.missions = missions
        self.artifactCountByMission = artifactCountByMission
        self.campNotes = campNotes
        self.regularCompanions = regularCompanions
        self.newcomerProgress = newcomerProgress
    }

    package init(bundle: InputCampReadBundle) {
        self.init(
            camp: bundle.camp,
            guide: bundle.guide,
            ingestionItems: bundle.ingestionItems,
            activeRuminationByIngestion:
                bundle.activeRuminationByIngestion,
            materializedNoteIdByIngestion:
                bundle.materializedNoteIdByIngestion,
            missions: bundle.missions,
            artifactCountByMission: bundle.artifactCountByMission,
            campNotes: bundle.campNotes,
            regularCompanions: bundle.regularCompanions,
            newcomerProgress: bundle.newcomerProgress
        )
    }
}

package struct InputReviewSnapshot: Sendable {
    package let ingestion: IngestionItemRecord
    package let result: RuminationResult
    package let baseCow: CompanionRecord?

    package init(
        ingestion: IngestionItemRecord,
        result: RuminationResult,
        baseCow: CompanionRecord?
    ) {
        self.ingestion = ingestion
        self.result = result
        self.baseCow = baseCow
    }
}

package struct FeedSubmissionCommand: Sendable {
    package let campId: String
    package let rawText: String
    package let title: String?
    package let sourceURL: String?
    package let author: String?
    package let userIntent: String?
    package let sourceType: IngestionSourceType
    package let allowDuplicate: Bool
    package let startRumination: Bool

    package init(
        campId: String,
        rawText: String,
        title: String?,
        sourceURL: String?,
        author: String?,
        userIntent: String?,
        sourceType: IngestionSourceType,
        allowDuplicate: Bool,
        startRumination: Bool
    ) {
        self.campId = campId
        self.rawText = rawText
        self.title = title
        self.sourceURL = sourceURL
        self.author = author
        self.userIntent = userIntent
        self.sourceType = sourceType
        self.allowDuplicate = allowDuplicate
        self.startRumination = startRumination
    }
}

package struct InputWorkflowReads: Sendable {
    package let camp: @Sendable (String) throws -> InputCampReadBundle
    package let review: @Sendable (String) throws -> InputReviewReadBundle

    package init(
        camp: @escaping @Sendable (String) throws -> InputCampReadBundle,
        review: @escaping @Sendable (String) throws -> InputReviewReadBundle
    ) {
        self.camp = camp
        self.review = review
    }

    package static func live(database: AppDatabase) -> Self {
        Self(
            camp: { try database.readInputCampBundle(campId: $0) },
            review: { try database.readInputReviewBundle(ingestionId: $0) }
        )
    }
}

package enum InputDeletionScope: Sendable, Equatable {
    case resultOnly
    case sourceAndResult
}

package struct InputDeletionConfirmation: Sendable, Equatable {
    package let campId: String
    package let ingestionId: String
    package let scope: InputDeletionScope

    package init(
        campId: String,
        ingestionId: String,
        scope: InputDeletionScope
    ) {
        self.campId = campId
        self.ingestionId = ingestionId
        self.scope = scope
    }
}

package enum PendingActiveIngestionDeletionPhase:
    Sendable, Equatable
{
    case prepared
    case executing
    case executionResolutionPending
    case committedRefreshPending
}

package struct PendingActiveIngestionDeletion: Sendable, Equatable {
    package let preparedCommand: PreparedActiveIngestionDeletionV1
    package let envelope: CommandEnvelopeV1
    package let selection: InputDeletionConfirmation
    package let preview: ActiveIngestionDeletionSafePreviewV1
    package let phase: PendingActiveIngestionDeletionPhase
    package let result: ActiveIngestionDeletionResultV1?
    package let failure: UserVisibleFailure?
    package let resolutionDisposition:
        ActiveIngestionDeletionResolutionDispositionV1?
    package let trace: OperationTrace

    fileprivate init(
        preparedCommand: PreparedActiveIngestionDeletionV1,
        envelope: CommandEnvelopeV1,
        selection: InputDeletionConfirmation,
        preview: ActiveIngestionDeletionSafePreviewV1,
        phase: PendingActiveIngestionDeletionPhase,
        result: ActiveIngestionDeletionResultV1?,
        failure: UserVisibleFailure?,
        resolutionDisposition:
            ActiveIngestionDeletionResolutionDispositionV1?,
        trace: OperationTrace
    ) {
        self.preparedCommand = preparedCommand
        self.envelope = envelope
        self.selection = selection
        self.preview = preview
        self.phase = phase
        self.result = result
        self.failure = failure
        self.resolutionDisposition = resolutionDisposition
        self.trace = trace
    }

    fileprivate func replacing(
        phase: PendingActiveIngestionDeletionPhase,
        result: ActiveIngestionDeletionResultV1? = nil,
        failure: UserVisibleFailure? = nil,
        resolutionDisposition:
            ActiveIngestionDeletionResolutionDispositionV1? = nil
    ) -> Self {
        Self(
            preparedCommand: preparedCommand,
            envelope: envelope,
            selection: selection,
            preview: preview,
            phase: phase,
            result: result,
            failure: failure,
            resolutionDisposition: resolutionDisposition,
            trace: trace
        )
    }
}

package struct InputActiveIngestionDeletionPorts: Sendable {
    package let makeEnvelope:
        @Sendable () throws -> CommandEnvelopeV1
    package let prepare:
        @Sendable (ActiveIngestionDeletionPrepareRequestV1) throws
            -> PreparedActiveIngestionDeletionV1
    package let execute:
        @Sendable (PreparedActiveIngestionDeletionV1) async
            -> ActiveIngestionDeletionExecutionResolutionV1
    package let resolve:
        @Sendable (PreparedActiveIngestionDeletionV1) async
            -> ActiveIngestionDeletionExecutionResolutionV1
    package let beforeCommittedRefresh:
        @Sendable () async throws -> Void

    package init(
        makeEnvelope: @escaping @Sendable () throws -> CommandEnvelopeV1,
        prepare: @escaping @Sendable (
            ActiveIngestionDeletionPrepareRequestV1
        ) throws -> PreparedActiveIngestionDeletionV1,
        execute: @escaping @Sendable (
            PreparedActiveIngestionDeletionV1
        ) async -> ActiveIngestionDeletionExecutionResolutionV1,
        resolve: @escaping @Sendable (
            PreparedActiveIngestionDeletionV1
        ) async -> ActiveIngestionDeletionExecutionResolutionV1,
        beforeCommittedRefresh:
            @escaping @Sendable () async throws -> Void = {}
    ) {
        self.makeEnvelope = makeEnvelope
        self.prepare = prepare
        self.execute = execute
        self.resolve = resolve
        self.beforeCommittedRefresh = beforeCommittedRefresh
    }

    package static func live(database: AppDatabase) -> Self {
        return configured(
            store: IngestionDeletionStore(database: database)
        )
    }

#if DEBUG
    package static func preview(
        database: AppDatabase,
        checkpoint: ActiveIngestionDeletionPreviewCheckpointV1?,
        failCommittedRefreshOnce: Bool
    ) -> Self {
        let refreshCheckpoint =
            InputActiveIngestionDeletionPreviewRefreshCheckpoint(
                shouldFailOnce: failCommittedRefreshOnce
            )
        return configured(
            store: IngestionDeletionStore(
                database: database,
                previewCheckpoint: checkpoint
            ),
            beforeCommittedRefresh: {
                try await refreshCheckpoint.check()
            }
        )
    }
#endif

    private static func configured(
        store: IngestionDeletionStore,
        beforeCommittedRefresh:
            @escaping @Sendable () async throws -> Void = {}
    ) -> Self {
        let identity = LocalCaptureIdentity.live()
        return Self(
            makeEnvelope: {
                let operationID = UUID().uuidString
                return try CommandEnvelopeV1(
                    idempotencyKey:
                        "active-ingestion-deletion:v1:\(operationID)",
                    actorType: .user,
                    actorId: P1DActorID.localOwner,
                    deviceId: try identity.installationID(),
                    correlationId:
                        "active-ingestion-deletion:v1:\(operationID)",
                    causationId: nil,
                    occurredAt: try P1DTimestampV1.canonical(Date())
                )
            },
            prepare: {
                try store.prepareActiveIngestionDeletion(request: $0)
            },
            execute: {
                store.executeActiveIngestionDeletion(preparedCommand: $0)
            },
            resolve: {
                store.resolveActiveIngestionDeletionExecution(
                    preparedCommand: $0
                )
            },
            beforeCommittedRefresh: beforeCommittedRefresh
        )
    }
}

#if DEBUG
private struct InputActiveIngestionDeletionPreviewRefreshFailure:
    Error, Sendable
{}

private actor InputActiveIngestionDeletionPreviewRefreshCheckpoint {
    private var shouldFailOnce: Bool

    init(shouldFailOnce: Bool) {
        self.shouldFailOnce = shouldFailOnce
    }

    func check() throws {
        guard shouldFailOnce else { return }
        shouldFailOnce = false
        throw InputActiveIngestionDeletionPreviewRefreshFailure()
    }
}
#endif

private enum InputActiveIngestionDeletionWorkflowError:
    String, Error, Sendable
{
    case pendingSelectionConflict
    case commitOutcomeUnknown
    case integrityBlocked
    case terminalConflict
}

package enum InputReviewCandidateKind: String, Sendable, Equatable {
    case keyPoint, requirement, todo
}

package struct InputReviewCandidateDraft: Sendable, Equatable {
    package let kind: InputReviewCandidateKind
    package let title: String
    package let detail: String
    package let confidence: Double?
    package let evidenceQuotes: [String]

    package init(
        kind: InputReviewCandidateKind,
        title: String,
        detail: String,
        confidence: Double?,
        evidenceQuotes: [String]
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.confidence = confidence
        self.evidenceQuotes = evidenceQuotes
    }
}

package struct InputReviewEditDraft: Sendable, Equatable {
    package let suggestedTitle: String
    package let summary: String
    package let accepted: [InputReviewCandidateDraft]
    package let suggestedMission: RuminationResult.SuggestedMission?
    package let uncertainties: [String]

    package init(
        suggestedTitle: String,
        summary: String,
        accepted: [InputReviewCandidateDraft],
        suggestedMission: RuminationResult.SuggestedMission?,
        uncertainties: [String]
    ) {
        self.suggestedTitle = suggestedTitle
        self.summary = summary
        self.accepted = accepted
        self.suggestedMission = suggestedMission
        self.uncertainties = uncertainties
    }
}

package enum InputReviewDraftError: Error, Sendable, Equatable {
    case missingKeyPointEvidence
    case missingRequirementConfidence
    case invalidRequirementConfidence
}

package struct InputReviewSaveCommand: Sendable, Equatable {
    package let ingestionId: String
    package let edited: InputReviewEditDraft

    package init(ingestionId: String, edited: InputReviewEditDraft) {
        self.ingestionId = ingestionId
        self.edited = edited
    }
}

package struct InputRuminationRuntimeSelection: Sendable, Equatable {
    package let model: String
    package let runtimeProfileId: String

    package init(model: String, runtimeProfileId: String) {
        self.model = model
        self.runtimeProfileId = runtimeProfileId
    }
}

package struct InputRuminationStartCommand: Sendable, Equatable {
    package let ingestionId: String
    package let expectedCampId: String
    package let runtime: InputRuminationRuntimeSelection
    package let durableTraceId: String

    package init(
        ingestionId: String,
        expectedCampId: String,
        runtime: InputRuminationRuntimeSelection,
        durableTraceId: String
    ) {
        self.ingestionId = ingestionId
        self.expectedCampId = expectedCampId
        self.runtime = runtime
        self.durableTraceId = durableTraceId
    }
}

package struct InputRuminationStartReceipt: Sendable {
    package let work: DurableWorkRecord
    package let refreshedCamp: InputCampSnapshot?

    package init(
        work: DurableWorkRecord,
        refreshedCamp: InputCampSnapshot?
    ) {
        self.work = work
        self.refreshedCamp = refreshedCamp
    }
}

package struct InputMaterializationCommand: Sendable, Equatable {
    package let ingestionId: String
    package let edited: InputReviewEditDraft
    package let includeMissionDraft: Bool

    package init(
        ingestionId: String,
        edited: InputReviewEditDraft,
        includeMissionDraft: Bool
    ) {
        self.ingestionId = ingestionId
        self.edited = edited
        self.includeMissionDraft = includeMissionDraft
    }
}

package struct InputMissionDraftStartCapability: Sendable, Equatable {
    let draft: CodingRanchMissionDraft
    let companionId: String

    init(draft: CodingRanchMissionDraft, companionId: String) {
        self.draft = draft
        self.companionId = companionId
    }

    package func makeMissionStartRequest(
        goal: String,
        workspacePath: String?,
        plannerModel: String,
        runtimeProfileId: String,
        budgetTokens: Int,
        autonomy: MissionAutonomy,
        idempotencyKey: String,
        durableTraceId: String
    ) -> MissionStartRequest {
        MissionStartRequest(
            goal: goal,
            companionIds: [companionId],
            workspacePath: workspacePath,
            plannerModel: plannerModel,
            runtimeProfileId: runtimeProfileId,
            budgetTokens: budgetTokens,
            campId: draft.campId,
            autonomy: autonomy,
            idempotencyKey: idempotencyKey,
            durableTraceId: durableTraceId
        )
    }
}

package struct InputMissionDraftSnapshot: Sendable {
    package let draft: CodingRanchMissionDraft
    package let sourceNote: CampNoteRecord
    package let baseCow: CompanionRecord?
    package let startCapability: InputMissionDraftStartCapability?

    package init(
        draft: CodingRanchMissionDraft,
        sourceNote: CampNoteRecord,
        baseCow: CompanionRecord?,
        startCapability: InputMissionDraftStartCapability?
    ) {
        self.draft = draft
        self.sourceNote = sourceNote
        self.baseCow = baseCow
        self.startCapability = startCapability
    }
}

package struct InputMaterializationReceipt: Sendable {
    package let materialization: RuminationMaterialization
    package let missionDraft: InputMissionDraftSnapshot?

    package init(
        materialization: RuminationMaterialization,
        missionDraft: InputMissionDraftSnapshot?
    ) {
        self.materialization = materialization
        self.missionDraft = missionDraft
    }
}

package struct ChatHistorySnapshot: Sendable {
    package let thread: ChatThreadRecord
    package let messages: [ChatMessageProjection]

    package init(
        thread: ChatThreadRecord,
        messages: [ChatMessageProjection]
    ) {
        self.thread = thread
        self.messages = messages
    }
}

package struct CampNavigationResolution: Sendable, Equatable {
    package let campId: String
    package let usedPreferredCamp: Bool

    package init(campId: String, usedPreferredCamp: Bool) {
        self.campId = campId
        self.usedPreferredCamp = usedPreferredCamp
    }
}

package struct InputNoteDeletionReceipt: Sendable, Equatable {
    package let noteId: String
    package let ownerId: String

    package init(noteId: String, ownerId: String) {
        self.noteId = noteId
        self.ownerId = ownerId
    }
}

package struct InputLifecyclePortUnavailableError:
    Error, Sendable, Equatable
{
    package init() {}
}

package struct InputWorkflowPorts: Sendable {
    package let submitFeed:
        @Sendable (FeedSubmissionCommand) throws -> FeedSubmission
    package let ruminationRuntime:
        @Sendable () throws -> InputRuminationRuntimeSelection
    package let startRumination:
        @Sendable (InputRuminationStartCommand) async throws
            -> DurableWorkRecord
    package let cancelRumination:
        @Sendable (String) async throws -> Void
    package let saveReview:
        @Sendable (String, RuminationResult) throws -> Void
    package let materialize:
        @Sendable (String, RuminationResult) throws
            -> RuminationMaterialization
    package let missionDraft:
        @Sendable (String) throws -> InputMissionDraftSnapshot
    package let unlockTestCow: @Sendable (String) throws -> CompanionRecord
    package let ensureDefaultCamp:
        @Sendable () throws -> DefaultCampResolutionReceipt
    package let createCamp:
        @Sendable (String, String?) throws -> CampRecord
    package let renameCamp: @Sendable (String, String) throws -> Void
    package let campWritable: @Sendable (String) throws -> Bool
    package let campNotes: @Sendable (String) throws -> [CampNoteRecord]
    package let saveCampNote: @Sendable (CampNoteRecord) throws -> Void
    package let deleteCampNote:
        @Sendable (String) throws -> InputNoteDeletionReceipt
    package let companionNotes:
        @Sendable (String) throws -> [CompanionNoteRecord]
    package let saveCompanionNote:
        @Sendable (CompanionNoteRecord) throws -> Void
    package let deleteCompanionNote:
        @Sendable (String, String) throws -> InputNoteDeletionReceipt
    package let chatHistory:
        @Sendable (String) throws -> ChatHistorySnapshot
    package let guideHistory:
        @Sendable (String) throws -> ChatHistorySnapshot
    package let chatStream:
        @Sendable (String, String, String) throws
            -> AsyncThrowingStream<ProviderEvent, Error>
    package let guideStream:
        @Sendable (String, String, String) throws
            -> AsyncThrowingStream<GuideChatEvent, Error>
    package let resolveCampNavigation:
        @Sendable (String, String?) throws -> CampNavigationResolution
    package let setCampArchived:
        @Sendable (String, Bool) throws -> CampRecord
    package let retireCow:
        @Sendable (String) throws -> CowRetirementReceiptV1

    package init(
        submitFeed: @escaping @Sendable (FeedSubmissionCommand) throws
            -> FeedSubmission,
        ruminationRuntime: @escaping @Sendable () throws
            -> InputRuminationRuntimeSelection,
        startRumination: @escaping @Sendable (InputRuminationStartCommand)
            async throws -> DurableWorkRecord,
        cancelRumination: @escaping @Sendable (String) async throws -> Void,
        saveReview: @escaping @Sendable (String, RuminationResult) throws
            -> Void,
        materialize: @escaping @Sendable (String, RuminationResult) throws
            -> RuminationMaterialization,
        missionDraft: @escaping @Sendable (String) throws
            -> InputMissionDraftSnapshot,
        unlockTestCow: @escaping @Sendable (String) throws
            -> CompanionRecord,
        ensureDefaultCamp: @escaping @Sendable () throws
            -> DefaultCampResolutionReceipt,
        createCamp: @escaping @Sendable (String, String?) throws
            -> CampRecord,
        renameCamp: @escaping @Sendable (String, String) throws -> Void,
        campWritable: @escaping @Sendable (String) throws -> Bool,
        campNotes: @escaping @Sendable (String) throws -> [CampNoteRecord],
        saveCampNote: @escaping @Sendable (CampNoteRecord) throws -> Void,
        deleteCampNote: @escaping @Sendable (String) throws
            -> InputNoteDeletionReceipt,
        companionNotes: @escaping @Sendable (String) throws
            -> [CompanionNoteRecord],
        saveCompanionNote: @escaping @Sendable (CompanionNoteRecord) throws
            -> Void,
        deleteCompanionNote: @escaping @Sendable (String, String) throws
            -> InputNoteDeletionReceipt,
        chatHistory: @escaping @Sendable (String) throws
            -> ChatHistorySnapshot,
        guideHistory: @escaping @Sendable (String) throws
            -> ChatHistorySnapshot,
        chatStream: @escaping @Sendable (String, String, String) throws
            -> AsyncThrowingStream<ProviderEvent, Error>,
        guideStream: @escaping @Sendable (String, String, String) throws
            -> AsyncThrowingStream<GuideChatEvent, Error>,
        resolveCampNavigation: @escaping @Sendable (String, String?) throws
            -> CampNavigationResolution,
        setCampArchived: @escaping @Sendable (String, Bool) throws
            -> CampRecord = { _, _ in
                throw InputLifecyclePortUnavailableError()
            },
        retireCow: @escaping @Sendable (String) throws
            -> CowRetirementReceiptV1 = { _ in
                throw InputLifecyclePortUnavailableError()
            }
    ) {
        self.submitFeed = submitFeed
        self.ruminationRuntime = ruminationRuntime
        self.startRumination = startRumination
        self.cancelRumination = cancelRumination
        self.saveReview = saveReview
        self.materialize = materialize
        self.missionDraft = missionDraft
        self.unlockTestCow = unlockTestCow
        self.ensureDefaultCamp = ensureDefaultCamp
        self.createCamp = createCamp
        self.renameCamp = renameCamp
        self.campWritable = campWritable
        self.campNotes = campNotes
        self.saveCampNote = saveCampNote
        self.deleteCampNote = deleteCampNote
        self.companionNotes = companionNotes
        self.saveCompanionNote = saveCompanionNote
        self.deleteCompanionNote = deleteCompanionNote
        self.chatHistory = chatHistory
        self.guideHistory = guideHistory
        self.chatStream = chatStream
        self.guideStream = guideStream
        self.resolveCampNavigation = resolveCampNavigation
        self.setCampArchived = setCampArchived
        self.retireCow = retireCow
    }

    package static func live(
        database: AppDatabase,
        orchestrator: Orchestrator,
        resolver: RuntimeCredentialResolver,
        defaults: ProfileScopedDefaults
    ) -> Self {
        Self(
            submitFeed: { command in
                guard let camp = try database.camp(id: command.campId)
                else {
                    throw RecordNotFoundError(
                        table: CampRecord.databaseTableName,
                        id: command.campId
                    )
                }
                guard !camp.archived else {
                    throw CampArchivedError(campId: command.campId)
                }
                return try FeedService(db: database).submit(
                    campId: command.campId,
                    rawText: command.rawText,
                    title: command.title,
                    sourceURL: command.sourceURL,
                    author: command.author,
                    userIntent: command.userIntent,
                    sourceType: command.sourceType,
                    allowDuplicate: command.allowDuplicate
                )
            },
            ruminationRuntime: {
                let bundle = try database
                    .readRuntimeProviderResolutionBundle(companionId: nil)
                guard let profile = bundle.defaultProfile else {
                    throw RuntimeProfileStoreError.defaultProfileNotFound
                }
                let distill = defaults.distillModel(profileID: profile.id)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let model = distill.isEmpty
                    ? defaults.defaultModel(
                        profileID: profile.id,
                        fallback: KernelDefaults.defaultGuideModel
                    )
                    : distill
                return InputRuminationRuntimeSelection(
                    model: model,
                    runtimeProfileId: profile.id
                )
            },
            startRumination: { command in
                let snapshot = try database.readInputCampBundle(
                    campId: command.expectedCampId
                )
                guard snapshot.ingestionItems.contains(where: {
                    $0.id == command.ingestionId
                        && $0.campId == command.expectedCampId
                }) else {
                    throw FeedServiceError.ingestionNotFound(
                        command.ingestionId
                    )
                }
                let preparation = try database.prepareRuminationStart(
                    ingestionId: command.ingestionId
                )
                switch preparation {
                case .replay(let ingestionId, _):
                    guard ingestionId == command.ingestionId else {
                        throw DurableWorkReplayConflictError()
                    }
                    return try await orchestrator.startRumination(
                        preparation: preparation,
                        command: nil
                    )
                case .new:
                    let durableCommand = try RuminationStartCommand(
                        preparation: preparation,
                        traceId: command.durableTraceId,
                        input: RuminationWorkInput(
                            model: command.runtime.model,
                            runtimeProfileId: command.runtime.runtimeProfileId
                        )
                    )
                    return try await orchestrator.startRumination(
                        preparation: preparation,
                        command: durableCommand
                    )
                }
            },
            cancelRumination: {
                try await orchestrator.cancelRumination(ingestionId: $0)
            },
            saveReview: {
                try database.saveRuminationReview(
                    ingestionId: $0,
                    result: $1
                )
            },
            materialize: {
                try RuminationMaterializer(db: database).materialize(
                    ingestionId: $0,
                    edited: $1
                )
            },
            missionDraft: { ingestionId in
                let bundle = try database.readInputMissionDraftBundle(
                    ingestionId: ingestionId
                )
                return InputMissionDraftSnapshot(
                    draft: bundle.draft,
                    sourceNote: bundle.sourceNote,
                    baseCow: bundle.baseCow,
                    startCapability: bundle.baseCow.map {
                        InputMissionDraftStartCapability(
                            draft: bundle.draft,
                            companionId: $0.id
                        )
                    }
                )
            },
            unlockTestCow: {
                try NewcomerUnlockPolicy(db: database).unlockTestCow(
                    campId: $0
                )
            },
            ensureDefaultCamp: { try database.resolveDefaultCamp() },
            createCamp: {
                try database.createCamp(name: $0, guidePrompt: $1)
            },
            renameCamp: { try database.renameCamp(id: $0, name: $1) },
            campWritable: {
                guard let camp = try database.camp(id: $0) else {
                    throw RecordNotFoundError(
                        table: CampRecord.databaseTableName,
                        id: $0
                    )
                }
                return !camp.archived
            },
            campNotes: { try database.campNotes(campId: $0) },
            saveCampNote: { try database.saveCampNote($0) },
            deleteCampNote: {
                let record = try database.deleteCampNoteWithPreimage(id: $0)
                return InputNoteDeletionReceipt(
                    noteId: record.id,
                    ownerId: record.campId
                )
            },
            companionNotes: {
                try database.companionNotes(companionId: $0)
            },
            saveCompanionNote: { try database.saveCompanionNote($0) },
            deleteCompanionNote: {
                let record = try database.deleteCompanionNoteWithPreimage(
                    id: $0,
                    companionId: $1
                )
                return InputNoteDeletionReceipt(
                    noteId: record.id,
                    ownerId: record.companionId
                )
            },
            chatHistory: {
                let bundle = try database.loadOrCreateDMHistoryBundle(
                    companionId: $0
                )
                return ChatHistorySnapshot(
                    thread: bundle.thread,
                    messages: bundle.messages
                )
            },
            guideHistory: {
                let bundle = try database.loadOrCreateGuideHistoryBundle(
                    campId: $0
                )
                return ChatHistorySnapshot(
                    thread: bundle.thread,
                    messages: bundle.messages
                )
            },
            chatStream: { companionId, text, model in
                guard let provider = try resolver.provider(
                    model: model,
                    companionId: companionId
                ) else {
                    throw ProviderError.unauthorized
                }
                return try ChatService(
                    db: database,
                    provider: provider
                ).send(companionId: companionId, userText: text)
            },
            guideStream: { campId, text, model in
                guard let provider = try resolver.provider(
                    model: model,
                    companionId: nil
                ) else {
                    throw ProviderError.unauthorized
                }
                return try GuideChatService(
                    db: database,
                    provider: provider
                ).send(campId: campId, userText: text)
            },
            resolveCampNavigation: { missionId, preferredCampId in
                guard let squad = try database.squad(forMission: missionId)
                else {
                    throw RecordNotFoundError(
                        table: MissionRecord.databaseTableName,
                        id: missionId
                    )
                }
                guard try database.camp(id: squad.campId) != nil else {
                    throw RecordNotFoundError(
                        table: CampRecord.databaseTableName,
                        id: squad.campId
                    )
                }
                return CampNavigationResolution(
                    campId: squad.campId,
                    usedPreferredCamp: preferredCampId == squad.campId
                )
            },
            setCampArchived: {
                try database.setCampArchived(id: $0, archived: $1)
            },
            retireCow: {
                try CowResidencyStore(database: database).retireCow(
                    cowId: $0
                )
            }
        )
    }
}

package enum MemoryKnowledgeOwner: Hashable, Sendable, Equatable {
    case companion(String)
    case guide(String)
}

package struct MemoryKnowledgeRefreshRequest: Sendable, Equatable {
    package let owner: MemoryKnowledgeOwner
    fileprivate let attempt: UUID

    fileprivate init(owner: MemoryKnowledgeOwner, attempt: UUID) {
        self.owner = owner
        self.attempt = attempt
    }
}

fileprivate enum MemoryDistillationCommittedRecord: Sendable {
    case companion(CompanionNoteRecord)
    case guide(CampNoteRecord)

    fileprivate var id: String {
        switch self {
        case .companion(let record):
            return record.id
        case .guide(let record):
            return record.id
        }
    }
}

package struct MemoryDistillationVisibilityCard: Identifiable, Sendable {
    package let id: UUID
    package let failure: UserVisibleFailure
    package var ownerKind: MemoryDistillOwnerKind {
        switch owner {
        case .companion:
            return .companion
        case .guide:
            return .guide
        }
    }
    package var committedRecordCount: Int { committedRecords.count }
    package var committedRecordIds: [String] {
        committedRecords.map(\.id)
    }

    fileprivate let owner: MemoryKnowledgeOwner
    fileprivate let committedRecords: [MemoryDistillationCommittedRecord]

    fileprivate init(
        id: UUID,
        failure: UserVisibleFailure,
        owner: MemoryKnowledgeOwner,
        committedRecords: [MemoryDistillationCommittedRecord]
    ) {
        self.id = id
        self.failure = failure
        self.owner = owner
        self.committedRecords = committedRecords
    }
}

fileprivate struct MemoryOwnerProjection<Record: Sendable>: Sendable {
    var state: WorkflowLoadState<[Record]> = .idle
    var lastLoaded: [Record]?
    var attempt: UUID?
    var pendingCommitted: [Record] = []
    var cardID: UUID?
}

@MainActor
package struct MemoryKnowledgeProjectionCoordinator {
    package private(set) var visibilityCards:
        [MemoryDistillationVisibilityCard] = []

    private var selectedCompanionID: String?
    private var selectedCampID: String?
    private var companionByID:
        [String: MemoryOwnerProjection<CompanionNoteRecord>] = [:]
    private var guideByCampID:
        [String: MemoryOwnerProjection<CampNoteRecord>] = [:]

    package var visibleMemoryNotes: [CompanionNoteRecord] {
        guard let selectedCompanionID else { return [] }
        return companionByID[selectedCompanionID]?.lastLoaded ?? []
    }

    package var visibleCampNotes: [CampNoteRecord] {
        guard let selectedCampID else { return [] }
        return guideByCampID[selectedCampID]?.lastLoaded ?? []
    }

    package var visibleMemoryState:
        WorkflowLoadState<[CompanionNoteRecord]>
    {
        guard let selectedCompanionID else { return .idle }
        return companionByID[selectedCompanionID]?.state ?? .idle
    }

    package var visibleCampState: WorkflowLoadState<[CampNoteRecord]> {
        guard let selectedCampID else { return .idle }
        return guideByCampID[selectedCampID]?.state ?? .idle
    }

    package init() {}

    package mutating func selectCompanion(
        _ companionId: String
    ) -> MemoryKnowledgeRefreshRequest {
        selectedCompanionID = companionId
        return beginCompanionRefresh(companionId: companionId)
    }

    package mutating func selectGuide(
        _ campId: String
    ) -> MemoryKnowledgeRefreshRequest {
        selectedCampID = campId
        return beginGuideRefresh(campId: campId)
    }

    package mutating func beginCompanionRefresh(
        companionId: String
    ) -> MemoryKnowledgeRefreshRequest {
        let attempt = UUID()
        var projection = companionByID[companionId] ?? .init()
        projection.attempt = attempt
        projection.state = .loading
        companionByID[companionId] = projection
        return MemoryKnowledgeRefreshRequest(
            owner: .companion(companionId),
            attempt: attempt
        )
    }

    package mutating func beginGuideRefresh(
        campId: String
    ) -> MemoryKnowledgeRefreshRequest {
        let attempt = UUID()
        var projection = guideByCampID[campId] ?? .init()
        projection.attempt = attempt
        projection.state = .loading
        guideByCampID[campId] = projection
        return MemoryKnowledgeRefreshRequest(
            owner: .guide(campId),
            attempt: attempt
        )
    }

    package mutating func beginCommittedRefresh(
        _ record: CompanionNoteRecord
    ) -> MemoryKnowledgeRefreshRequest {
        var projection = companionByID[record.companionId] ?? .init()
        Self.upsert(record, in: &projection.pendingCommitted)
        companionByID[record.companionId] = projection
        return beginCompanionRefresh(companionId: record.companionId)
    }

    package mutating func beginCommittedRefresh(
        _ record: CampNoteRecord
    ) -> MemoryKnowledgeRefreshRequest {
        var projection = guideByCampID[record.campId] ?? .init()
        Self.upsert(record, in: &projection.pendingCommitted)
        guideByCampID[record.campId] = projection
        return beginGuideRefresh(campId: record.campId)
    }

    package mutating func beginVisibilityRetry(
        cardId: UUID
    ) -> MemoryKnowledgeRefreshRequest? {
        guard let card = visibilityCards.first(where: { $0.id == cardId })
        else {
            return nil
        }
        switch card.owner {
        case .companion(let companionId):
            return beginCompanionRefresh(companionId: companionId)
        case .guide(let campId):
            return beginGuideRefresh(campId: campId)
        }
    }

    @discardableResult
    package mutating func apply(
        _ terminal: WorkflowReadTerminal<[CompanionNoteRecord]>,
        for request: MemoryKnowledgeRefreshRequest
    ) -> Bool {
        guard case .companion(let companionId) = request.owner,
              var projection = companionByID[companionId],
              projection.attempt == request.attempt
        else {
            return false
        }
        switch terminal {
        case .loaded(let records):
            projection.lastLoaded = records
            projection.state = .loaded(records)
            projection.pendingCommitted.removeAll()
            removeCard(for: request.owner)
            projection.cardID = nil
        case .failed(let failure):
            projection.state = .failed(failure)
            if !projection.pendingCommitted.isEmpty {
                let cardID = projection.cardID ?? UUID()
                projection.cardID = cardID
                upsertCard(
                    id: cardID,
                    failure: failure,
                    owner: request.owner,
                    committed: projection.pendingCommitted.map {
                        .companion($0)
                    }
                )
            }
        }
        companionByID[companionId] = projection
        return true
    }

    @discardableResult
    package mutating func apply(
        _ terminal: WorkflowReadTerminal<[CampNoteRecord]>,
        for request: MemoryKnowledgeRefreshRequest
    ) -> Bool {
        guard case .guide(let campId) = request.owner,
              var projection = guideByCampID[campId],
              projection.attempt == request.attempt
        else {
            return false
        }
        switch terminal {
        case .loaded(let records):
            projection.lastLoaded = records
            projection.state = .loaded(records)
            projection.pendingCommitted.removeAll()
            removeCard(for: request.owner)
            projection.cardID = nil
        case .failed(let failure):
            projection.state = .failed(failure)
            if !projection.pendingCommitted.isEmpty {
                let cardID = projection.cardID ?? UUID()
                projection.cardID = cardID
                upsertCard(
                    id: cardID,
                    failure: failure,
                    owner: request.owner,
                    committed: projection.pendingCommitted.map { .guide($0) }
                )
            }
        }
        guideByCampID[campId] = projection
        return true
    }

    private mutating func upsertCard(
        id: UUID,
        failure: UserVisibleFailure,
        owner: MemoryKnowledgeOwner,
        committed: [MemoryDistillationCommittedRecord]
    ) {
        let card = MemoryDistillationVisibilityCard(
            id: id,
            failure: failure,
            owner: owner,
            committedRecords: committed
        )
        if let index = visibilityCards.firstIndex(where: { $0.id == id }) {
            visibilityCards[index] = card
        } else {
            visibilityCards.append(card)
        }
    }

    private mutating func removeCard(for owner: MemoryKnowledgeOwner) {
        visibilityCards.removeAll { $0.owner == owner }
    }

    private static func upsert(
        _ record: CompanionNoteRecord,
        in records: inout [CompanionNoteRecord]
    ) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    private static func upsert(
        _ record: CampNoteRecord,
        in records: inout [CampNoteRecord]
    ) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }
}

package actor InputWorkflowController {
    private let reporter: FailureReporter
    private let reads: InputWorkflowReads
    private let ports: InputWorkflowPorts
    private let activeIngestionDeletionPorts:
        InputActiveIngestionDeletionPorts
    private var pendingActiveIngestionDeletion:
        PendingActiveIngestionDeletion?
    private var activeIngestionDeletionAuxiliaryActionInFlight = false

    package init(
        database: AppDatabase,
        orchestrator: Orchestrator,
        resolver: RuntimeCredentialResolver,
        reporter: FailureReporter,
        reads: InputWorkflowReads? = nil,
        ports: InputWorkflowPorts? = nil,
        activeIngestionDeletionPorts:
            InputActiveIngestionDeletionPorts? = nil
    ) {
        self.reporter = reporter
        self.reads = reads ?? .live(database: database)
        self.ports = ports ?? .live(
            database: database,
            orchestrator: orchestrator,
            resolver: resolver,
            defaults: ProfileScopedDefaults()
        )
        self.activeIngestionDeletionPorts =
            activeIngestionDeletionPorts ?? .live(database: database)
        pendingActiveIngestionDeletion = nil
    }

    package func loadCamp(
        campId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<InputCampSnapshot> {
        let read = reads.camp
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(campId)
            return InputCampSnapshot(bundle: bundle)
        }
    }

    package func ensureDefaultCamp(
        trace: OperationTrace
    ) async -> OperationCommitOutcome<DefaultCampResolutionReceipt> {
        let port = ports.ensureDefaultCamp
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try port())
        }
    }

    package func loadReview(
        ingestionId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<InputReviewSnapshot> {
        let read = reads.review
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read(ingestionId)
            return InputReviewSnapshot(
                ingestion: bundle.ingestion,
                result: bundle.result,
                baseCow: bundle.baseCow
            )
        }
    }

    package func submit(
        _ command: FeedSubmissionCommand,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<FeedSubmission> {
        let submit = ports.submitFeed
        let initial: OperationCommitOutcome<FeedSubmission> =
            await captureAsyncOperation(
                reporter: reporter,
                trace: trace,
                onFailure: { .notCommitted($0) }
            ) {
                .committed(try submit(command))
            }
        guard command.startRumination else {
            return initial
        }
        let submission: FeedSubmission
        switch initial {
        case .committed(let value):
            submission = value
        case .notCommitted, .committedWithVisibilityFailure:
            return initial
        }
        guard case .created(let ingestion) = submission else {
            return initial
        }
        let runtime = ports.ruminationRuntime
        let start = ports.startRumination
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: {
                .committedWithVisibilityFailure(
                    value: submission,
                    failure: $0
                )
            }
        ) {
            let selection = try runtime()
            _ = try await start(
                InputRuminationStartCommand(
                    ingestionId: ingestion.id,
                    expectedCampId: command.campId,
                    runtime: selection,
                    durableTraceId: trace.traceId
                )
            )
            return .committed(submission)
        }
    }

    package func startRumination(
        ingestionId: String,
        expectedCampId: String,
        model: String,
        runtimeProfileId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputRuminationStartReceipt> {
        let start = ports.startRumination
        let started = await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: {
                failure -> OperationCommitOutcome<DurableWorkRecord> in
                .notCommitted(failure)
            }
        ) {
            .committed(
                try await start(
                    InputRuminationStartCommand(
                        ingestionId: ingestionId,
                        expectedCampId: expectedCampId,
                        runtime: InputRuminationRuntimeSelection(
                            model: model,
                            runtimeProfileId: runtimeProfileId
                        ),
                        durableTraceId: trace.traceId
                    )
                )
            )
        }
        switch started {
        case .notCommitted(let failure):
            return .notCommitted(failure)
        case .committedWithVisibilityFailure(let work, let failure):
            return .committedWithVisibilityFailure(
                value: InputRuminationStartReceipt(
                    work: work,
                    refreshedCamp: nil
                ),
                failure: failure
            )
        case .committed(let work):
            let read = reads.camp
            return await captureAsyncOperation(
                reporter: reporter,
                trace: trace,
                onFailure: {
                    .committedWithVisibilityFailure(
                        value: InputRuminationStartReceipt(
                            work: work,
                            refreshedCamp: nil
                        ),
                        failure: $0
                    )
                }
            ) {
                let bundle = try read(expectedCampId)
                return .committed(
                    InputRuminationStartReceipt(
                        work: work,
                        refreshedCamp: InputCampSnapshot(bundle: bundle)
                    )
                )
            }
        }
    }

    package func cancelRumination(
        ingestionId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        let cancel = ports.cancelRumination
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            try await cancel(ingestionId)
            return .committed(())
        }
    }

    package func saveReview(
        _ command: InputReviewSaveCommand,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        let save = ports.saveReview
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            let result = try Self.reviewResult(command.edited)
            try save(command.ingestionId, result)
            return .committed(())
        }
    }

    package func materialize(
        _ command: InputMaterializationCommand,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputMaterializationReceipt> {
        let materialize = ports.materialize
        let draft = ports.missionDraft
        let initial: OperationCommitOutcome<RuminationMaterialization> =
            await captureAsyncOperation(
                reporter: reporter,
                trace: trace,
                onFailure: { .notCommitted($0) }
            ) {
                let converted = try Self.reviewResult(command.edited)
                return .committed(
                    try materialize(command.ingestionId, converted)
                )
            }
        let materialization: RuminationMaterialization
        switch initial {
        case .notCommitted(let failure):
            return .notCommitted(failure)
        case .committed(let value):
            materialization = value
        case .committedWithVisibilityFailure(_, let failure):
            return .notCommitted(failure)
        }
        let committed = InputMaterializationReceipt(
            materialization: materialization,
            missionDraft: nil
        )
        guard command.includeMissionDraft else {
            return .committed(committed)
        }
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: {
                .committedWithVisibilityFailure(
                    value: committed,
                    failure: $0
                )
            }
        ) {
            .committed(
                InputMaterializationReceipt(
                    materialization: materialization,
                    missionDraft: try draft(command.ingestionId)
                )
            )
        }
    }

    package func prepareActiveIngestionDeletion(
        _ selection: InputDeletionConfirmation,
        trace: OperationTrace
    ) async throws -> PendingActiveIngestionDeletion {
        if let pendingActiveIngestionDeletion {
            guard pendingActiveIngestionDeletion.selection == selection else {
                throw UserVisibleOperationError(
                    failure: reporter.capture(
                        InputActiveIngestionDeletionWorkflowError
                            .pendingSelectionConflict,
                        trace: trace
                    )
                )
            }
            return pendingActiveIngestionDeletion
        }

        do {
            let envelope = try activeIngestionDeletionPorts.makeEnvelope()
            let scope: ActiveIngestionDeletionScopeV1
            switch selection.scope {
            case .resultOnly:
                scope = .resultOnly
            case .sourceAndResult:
                scope = .sourceAndResult
            }
            let prepared = try activeIngestionDeletionPorts.prepare(
                ActiveIngestionDeletionPrepareRequestV1(
                    envelope: envelope,
                    campId: selection.campId,
                    ingestionId: selection.ingestionId,
                    scope: scope
                )
            )
            let pending = PendingActiveIngestionDeletion(
                preparedCommand: prepared,
                envelope: envelope,
                selection: selection,
                preview: prepared.preview,
                phase: .prepared,
                result: nil,
                failure: nil,
                resolutionDisposition: nil,
                trace: trace
            )
            pendingActiveIngestionDeletion = pending
            return pending
        } catch {
            throw UserVisibleOperationError(
                failure: reporter.capture(error, trace: trace)
            )
        }
    }

    package func executePendingActiveIngestionDeletion()
        async -> PendingActiveIngestionDeletion?
    {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              let current = pendingActiveIngestionDeletion
        else { return pendingActiveIngestionDeletion }
        switch current.phase {
        case .prepared, .committedRefreshPending:
            break
        case .executing, .executionResolutionPending:
            return current
        }

        let executing = current.replacing(phase: .executing)
        pendingActiveIngestionDeletion = executing
        let resolution = await activeIngestionDeletionPorts.execute(
            current.preparedCommand
        )
        guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                == current.envelope.idempotencyKey
        else { return pendingActiveIngestionDeletion }
        return applyActiveIngestionDeletionResolution(
            resolution,
            to: current
        )
    }

    package func resolvePendingActiveIngestionDeletion()
        async -> PendingActiveIngestionDeletion?
    {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              let current = pendingActiveIngestionDeletion,
              current.phase == .executionResolutionPending,
              current.resolutionDisposition != .terminalConflict
        else { return pendingActiveIngestionDeletion }
        activeIngestionDeletionAuxiliaryActionInFlight = true
        defer { activeIngestionDeletionAuxiliaryActionInFlight = false }
        let resolution = await activeIngestionDeletionPorts.resolve(
            current.preparedCommand
        )
        guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                == current.envelope.idempotencyKey
        else { return pendingActiveIngestionDeletion }
        return applyActiveIngestionDeletionResolution(
            resolution,
            to: current
        )
    }

    package func cancelPreparedActiveIngestionDeletion() async -> Bool {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              pendingActiveIngestionDeletion?.phase == .prepared
        else { return false }
        pendingActiveIngestionDeletion = nil
        return true
    }

    package func activeIngestionDeletionPendingState()
        async -> PendingActiveIngestionDeletion?
    {
        pendingActiveIngestionDeletion
    }

    package func refreshCommittedActiveIngestionDeletion(
        _ refresh: @Sendable () async throws -> Void
    ) async -> Bool {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              let current = pendingActiveIngestionDeletion,
              current.phase == .committedRefreshPending
        else { return false }
        activeIngestionDeletionAuxiliaryActionInFlight = true
        defer { activeIngestionDeletionAuxiliaryActionInFlight = false }
        do {
            try await activeIngestionDeletionPorts.beforeCommittedRefresh()
            try await refresh()
        } catch {
            guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                    == current.envelope.idempotencyKey
            else { return false }
            pendingActiveIngestionDeletion = current.replacing(
                phase: .committedRefreshPending,
                result: current.result,
                failure: reporter.capture(error, trace: current.trace)
            )
            return false
        }
        guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                == current.envelope.idempotencyKey
        else { return false }
        pendingActiveIngestionDeletion = nil
        return true
    }

    package func abandonTerminalConflict(
        _ reload: @Sendable () async throws -> Void
    ) async -> Bool {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              let current = pendingActiveIngestionDeletion,
              current.phase == .executionResolutionPending,
              current.resolutionDisposition == .terminalConflict
        else { return false }
        activeIngestionDeletionAuxiliaryActionInFlight = true
        defer { activeIngestionDeletionAuxiliaryActionInFlight = false }
        do {
            try await reload()
        } catch {
            guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                    == current.envelope.idempotencyKey
            else { return false }
            pendingActiveIngestionDeletion = current.replacing(
                phase: .executionResolutionPending,
                failure: reporter.capture(error, trace: current.trace),
                resolutionDisposition: .terminalConflict
            )
            return false
        }
        guard pendingActiveIngestionDeletion?.envelope.idempotencyKey
                == current.envelope.idempotencyKey
        else { return false }
        pendingActiveIngestionDeletion = nil
        return true
    }

    package func dismissCommittedActiveIngestionDeletion() async -> Bool {
        guard !activeIngestionDeletionAuxiliaryActionInFlight,
              pendingActiveIngestionDeletion?.phase
                == .committedRefreshPending
        else { return false }
        pendingActiveIngestionDeletion = nil
        return true
    }

    private func applyActiveIngestionDeletionResolution(
        _ resolution: ActiveIngestionDeletionExecutionResolutionV1,
        to current: PendingActiveIngestionDeletion
    ) -> PendingActiveIngestionDeletion {
        let next: PendingActiveIngestionDeletion
        switch resolution {
        case .committed(let result):
            next = current.replacing(
                phase: .committedRefreshPending,
                result: result
            )
        case .notCommitted(let failure):
            next = current.replacing(
                phase: .prepared,
                failure: reporter.capture(failure, trace: current.trace)
            )
        case .resolutionPending(let disposition):
            let error: InputActiveIngestionDeletionWorkflowError
            switch disposition {
            case .commitOutcomeUnknown:
                error = .commitOutcomeUnknown
            case .integrityBlocked:
                error = .integrityBlocked
            case .terminalConflict:
                error = .terminalConflict
            }
            next = current.replacing(
                phase: .executionResolutionPending,
                failure: reporter.capture(error, trace: current.trace),
                resolutionDisposition: disposition
            )
        }
        pendingActiveIngestionDeletion = next
        return next
    }

    package func createMissionDraft(
        ingestionId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputMissionDraftSnapshot> {
        let draft = ports.missionDraft
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try draft(ingestionId))
        }
    }

    package func unlockTestCow(
        campId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CompanionRecord> {
        let unlock = ports.unlockTestCow
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try unlock(campId))
        }
    }

    package func createCamp(
        name: String,
        guidePrompt: String?,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CampRecord> {
        let create = ports.createCamp
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try create(name, guidePrompt))
        }
    }

    package func renameCamp(
        id: String,
        name: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        let rename = ports.renameCamp
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            try rename(id, name)
            return .committed(())
        }
    }

    package func setCampArchived(
        id: String,
        archived: Bool,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CampRecord> {
        let update = ports.setCampArchived
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try update(id, archived))
        }
    }

    package func retireCow(
        id: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CowRetirementReceiptV1> {
        let retire = ports.retireCow
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try retire(id))
        }
    }

    package func campWritable(
        id: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<Bool> {
        let read = ports.campWritable
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try read(id)
        }
    }

    package func loadCampNotes(
        campId: String,
        trace: OperationTrace
    ) async -> WorkflowReadTerminal<[CampNoteRecord]> {
        let read = ports.campNotes
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .failed($0) }
        ) {
            .loaded(try read(campId))
        }
    }

    package func saveCampNote(
        _ note: CampNoteRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CampNoteRecord> {
        let save = ports.saveCampNote
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            try save(note)
            return .committed(note)
        }
    }

    package func deleteCampNote(
        id: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputNoteDeletionReceipt> {
        let delete = ports.deleteCampNote
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try delete(id))
        }
    }

    package func pinCampNote(
        _ note: CampNoteRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CampNoteRecord> {
        await saveCampNote(note, trace: trace)
    }

    package func loadMemoryNotes(
        companionId: String,
        trace: OperationTrace
    ) async -> WorkflowReadTerminal<[CompanionNoteRecord]> {
        let read = ports.companionNotes
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .failed($0) }
        ) {
            .loaded(try read(companionId))
        }
    }

    package func saveMemoryNote(
        _ note: CompanionNoteRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CompanionNoteRecord> {
        let save = ports.saveCompanionNote
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            try save(note)
            return .committed(note)
        }
    }

    package func deleteMemoryNote(
        id: String,
        companionId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputNoteDeletionReceipt> {
        let delete = ports.deleteCompanionNote
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try delete(id, companionId))
        }
    }

    package func pinMemoryNote(
        _ note: CompanionNoteRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CompanionNoteRecord> {
        await saveMemoryNote(note, trace: trace)
    }

    package func loadChat(
        companionId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<ChatHistorySnapshot> {
        let load = ports.chatHistory
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try load(companionId)
        }
    }

    package func sendChat(
        companionId: String,
        text: String,
        model: String,
        onEvent: @escaping @MainActor @Sendable (ProviderEvent) -> Void,
        isOwnedCancellation: @escaping @Sendable () -> Bool,
        trace: OperationTrace
    ) async -> WorkflowStreamTerminal {
        let openPort = ports.chatStream
        return await captureAsyncStream(
            reporter: reporter,
            trace: trace,
            isOwnedCancellation: isOwnedCancellation,
            open: {
                let stream = try openPort(companionId, text, model)
                return {
                    for try await event in stream {
                        await onEvent(event)
                    }
                }
            }
        )
    }

    package func loadGuideChat(
        campId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<ChatHistorySnapshot> {
        let load = ports.guideHistory
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try load(campId)
        }
    }

    package func sendGuideChat(
        campId: String,
        text: String,
        model: String,
        onEvent: @escaping @MainActor @Sendable (GuideChatEvent) -> Void,
        isOwnedCancellation: @escaping @Sendable () -> Bool,
        trace: OperationTrace
    ) async -> WorkflowStreamTerminal {
        let openPort = ports.guideStream
        return await captureAsyncStream(
            reporter: reporter,
            trace: trace,
            isOwnedCancellation: isOwnedCancellation,
            open: {
                let stream = try openPort(campId, text, model)
                return {
                    for try await event in stream {
                        await onEvent(event)
                    }
                }
            }
        )
    }

    package func resolveCampNavigation(
        missionId: String,
        preferredCampId: String?,
        trace: OperationTrace
    ) async -> WorkflowLoadState<CampNavigationResolution> {
        let resolve = ports.resolveCampNavigation
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try resolve(missionId, preferredCampId)
        }
    }

    private static func reviewResult(
        _ draft: InputReviewEditDraft
    ) throws -> RuminationResult {
        var keyPoints: [RuminationResult.KeyPoint] = []
        var requirements: [RuminationResult.Requirement] = []
        var todos: [RuminationResult.Todo] = []
        for candidate in draft.accepted {
            switch candidate.kind {
            case .keyPoint:
                guard let quote = candidate.evidenceQuotes.first(where: {
                    !$0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }) else {
                    throw InputReviewDraftError.missingKeyPointEvidence
                }
                keyPoints.append(
                    .init(text: candidate.detail, sourceQuote: quote)
                )
            case .requirement:
                guard let confidence = candidate.confidence else {
                    throw InputReviewDraftError.missingRequirementConfidence
                }
                guard confidence.isFinite, (0...1).contains(confidence) else {
                    throw InputReviewDraftError.invalidRequirementConfidence
                }
                let mapped: RuminationResult.Confidence
                if confidence >= 0.8 {
                    mapped = .high
                } else if confidence >= 0.5 {
                    mapped = .medium
                } else {
                    mapped = .low
                }
                requirements.append(
                    .init(
                        title: candidate.title,
                        detail: candidate.detail,
                        confidence: mapped
                    )
                )
            case .todo:
                todos.append(.init(title: candidate.title))
            }
        }
        return RuminationResult(
            suggestedTitle: draft.suggestedTitle,
            summary: draft.summary,
            keyPoints: keyPoints,
            requirements: requirements,
            todos: todos,
            suggestedMission: draft.suggestedMission,
            uncertainties: draft.uncertainties
        )
    }
}
// P1-C-BEGIN LocalInputCaptureWorkflow
package struct InputCapturePorts: Sendable {
    package let capture:
        @Sendable (CaptureInputCommandV1) throws -> InputCaptureReceiptV1
    package let read:
        @Sendable (String) throws -> InputEnvelopeRecord?

    package init(
        capture: @escaping @Sendable (CaptureInputCommandV1) throws
            -> InputCaptureReceiptV1,
        read: @escaping @Sendable (String) throws -> InputEnvelopeRecord?
    ) {
        self.capture = capture
        self.read = read
    }

    package static func live(database: AppDatabase) -> Self {
        let store = InputGoalStore(database: database)
        return Self(
            capture: { try store.captureAndEnqueueParsing($0) },
            read: { try store.input(id: $0) }
        )
    }
}

package struct LocalInputCaptureRequestV1: Sendable {
    package let inputId: String
    package let idempotencyKey: String
    package let auditCampId: String
    package let initialCampId: String?
    package let sourceType: InputSourceTypeV1
    package let connectorId: String?
    package let authorId: String?
    package let capturedAt: Date
    package let inlineText: String?
    package let payloadRef: String?
    package let contentHash: String
    package let candidateCampIds: [String]
    package let explicitIntent: InputExplicitIntentV1
    package let privacyLevel: InputPrivacyLevelV1
    package let parentInputId: String?
    package let causationId: String?

    package init(
        inputId: String,
        idempotencyKey: String,
        auditCampId: String,
        initialCampId: String?,
        sourceType: InputSourceTypeV1,
        connectorId: String?,
        authorId: String?,
        capturedAt: Date,
        inlineText: String?,
        payloadRef: String?,
        contentHash: String,
        candidateCampIds: [String],
        explicitIntent: InputExplicitIntentV1,
        privacyLevel: InputPrivacyLevelV1,
        parentInputId: String?,
        causationId: String?
    ) {
        self.inputId = inputId
        self.idempotencyKey = idempotencyKey
        self.auditCampId = auditCampId
        self.initialCampId = initialCampId
        self.sourceType = sourceType
        self.connectorId = connectorId
        self.authorId = authorId
        self.capturedAt = capturedAt
        self.inlineText = inlineText
        self.payloadRef = payloadRef
        self.contentHash = contentHash
        self.candidateCampIds = candidateCampIds
        self.explicitIntent = explicitIntent
        self.privacyLevel = privacyLevel
        self.parentInputId = parentInputId
        self.causationId = causationId
    }
}

package actor InputCaptureWorkflowController {
    private let reporter: FailureReporter
    private let capturePorts: InputCapturePorts
    private let localCaptureIdentity: LocalCaptureIdentity

    package init(
        database: AppDatabase,
        reporter: FailureReporter,
        capturePorts: InputCapturePorts? = nil,
        localCaptureIdentity: LocalCaptureIdentity? = nil
    ) {
        self.reporter = reporter
        self.capturePorts = capturePorts ?? .live(database: database)
        self.localCaptureIdentity = localCaptureIdentity ?? .live()
    }

    package func captureLocalInput(
        _ request: LocalInputCaptureRequestV1,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputCaptureReceiptV1> {
        let reporter = reporter
        let capturePorts = capturePorts
        let localCaptureIdentity = localCaptureIdentity
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            let installationID = try localCaptureIdentity.installationID()
            let envelope = try CommandEnvelopeV1(
                idempotencyKey: request.idempotencyKey,
                actorType: .user,
                actorId: "user:local-owner",
                deviceId: installationID,
                correlationId: trace.traceId,
                causationId: request.causationId,
                occurredAt: request.capturedAt
            )
            let command = try CaptureInputCommandV1(
                envelope: envelope,
                inputId: request.inputId,
                auditCampId: request.auditCampId,
                initialCampId: request.initialCampId,
                sourceType: request.sourceType,
                sourceDeviceId: installationID,
                connectorId: request.connectorId,
                authorId: request.authorId,
                capturedAt: request.capturedAt,
                inlineText: request.inlineText,
                payloadRef: request.payloadRef,
                contentHash: request.contentHash,
                candidateCampIds: request.candidateCampIds,
                explicitIntent: request.explicitIntent,
                privacyLevel: request.privacyLevel,
                parentInputId: request.parentInputId
            )
            return .committed(try capturePorts.capture(command))
        }
    }

    package func loadInput(
        id: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<InputEnvelopeRecord> {
        let reporter = reporter
        let capturePorts = capturePorts
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            guard let input = try capturePorts.read(id) else {
                throw RecordNotFoundError(table: "input_envelope", id: id)
            }
            return input
        }
    }
}
// P1-C-END LocalInputCaptureWorkflow
