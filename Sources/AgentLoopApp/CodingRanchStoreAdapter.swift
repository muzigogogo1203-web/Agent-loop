import Foundation
import GRDB
import AgentLoopCore
import AgentLoopApplication
import os

private let codingRanchDiagnosticLogger = Logger(
    subsystem: "com.muzi.agentloop",
    category: "coding-ranch"
)

@MainActor
extension AppStore: CodingRanchStoreProtocol {
    var dashboard: CampDashboardViewState? { codingRanchDashboard }
    var ruminationInbox: RuminationInboxViewState { codingRanchInbox }

    func recordCodingRanchDiagnostic(
        _ error: Error,
        operation: String
    ) {
        let errorType = String(reflecting: type(of: error))
        codingRanchDiagnosticLogger.error(
            "operation=\(operation, privacy: .public) error_type=\(errorType, privacy: .public)"
        )
    }

    func safeRuminationStartMessage(for error: Error) -> String {
        if let safe = error as? CodingRanchUserFacingError {
            return safe.message
        }
        if let operation = error as? UserVisibleOperationError {
            return operation.failure.message
        }
        if let failure = error as? RuminationAttemptFailure,
           let safeMessage = failure.failure.message
        {
            return "反刍没有开始：\(safeMessage)"
        }
        if error is SupervisorDispatchSuppressedError {
            return "牧场当前已停营，反刍暂时不能开始。"
        }
        if error is SupervisorRecoveryRequiredError {
            return "牧场仍在恢复，反刍暂时不能开始。"
        }
        if let profileError = error as? RuntimeProfileStoreError,
           profileError == .defaultProfileNotFound
        {
            return "请先设置唯一的默认供给线。"
        }
        return "反刍暂时没有开始，请稍后重试。"
    }

    func loadDashboard(campId: String) async {
        await refreshInputCampProjection(
            campId: campId,
            makeVisible: true
        )
    }

    func loadRuminationInbox(campId: String) async {
        await refreshInputCampProjection(
            campId: campId,
            makeVisible: true
        )
    }

    func submitFeed(_ draft: FeedDraft, startRumination: Bool) async throws -> FeedSubmissionResult {
        try await submitFeed(draft, startRumination: startRumination, allowDuplicate: false)
    }

    func submitDuplicateAnyway(_ draft: FeedDraft, startRumination: Bool) async throws -> FeedSubmissionResult {
        try await submitFeed(draft, startRumination: startRumination, allowDuplicate: true)
    }

    func saveFeedDraft(_ draft: FeedDraft) {
        UserDefaults.standard.set([
            "title": draft.title, "body": draft.body, "sourceURL": draft.sourceURL,
            "author": draft.author, "userIntent": draft.userIntent, "campId": draft.campId,
        ], forKey: "codingRanch.feedDraft.\(draft.campId)")
    }

    func startRumination(ingestionId: String) async {
        guard !ruminationActionInFlightIds.contains(ingestionId) else {
            return
        }
        ruminationActionInFlightIds.insert(ingestionId)
        defer { ruminationActionInFlightIds.remove(ingestionId) }
        ruminationActionError = nil
        do {
            _ = try await executeRuminationCommand(
                ingestionId: ingestionId
            )
        } catch {
            recordCodingRanchDiagnostic(
                error,
                operation: "start-rumination"
            )
            ruminationActionError =
                safeRuminationStartMessage(for: error)
        }
    }

    func retryRumination(ingestionId: String) async {
        await startRumination(ingestionId: ingestionId)
    }

    func cancelRumination(ingestionId: String) async throws {
        let trace = makeInputOperationTrace(
            operation: .inputRuminationCancel
        )
        switch await inputWorkflowController.cancelRumination(
            ingestionId: ingestionId,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed:
            clearInputFailure(operation: .inputRuminationCancel)
        case .committedWithVisibilityFailure(_, let failure):
            recordInputVisibilityFailure(failure)
        }
    }

    func loadRuminationReview(ingestionId: String) async throws -> RuminationReviewViewState {
        let terminal = await refreshInputReviewProjection(
            ingestionId: ingestionId
        )
        switch terminal {
        case .loaded(let snapshot):
            codingRanchIngestionCampIds[ingestionId] =
                snapshot.ingestion.campId
            return reviewViewState(snapshot)
        case .failed(let failure):
            throw inputOperationError(failure)
        case .idle, .loading:
            throw ProjectionContractError.invalidTerminal
        }
    }

    func loadRuminationSource(ingestionId: String) async throws -> SourceViewState {
        let terminal = await refreshInputReviewProjection(
            ingestionId: ingestionId
        )
        switch terminal {
        case .loaded(let snapshot):
            codingRanchIngestionCampIds[ingestionId] =
                snapshot.ingestion.campId
            return sourceViewState(snapshot.ingestion)
        case .failed(let failure):
            throw inputOperationError(failure)
        case .idle, .loading:
            throw ProjectionContractError.invalidTerminal
        }
    }

    func saveRuminationReview(_ review: RuminationReviewViewState) async throws {
        let trace = makeInputOperationTrace(
            operation: .inputReviewSave
        )
        let command = InputReviewSaveCommand(
            ingestionId: review.ingestionId,
            edited: inputReviewEditDraft(review)
        )
        switch await inputWorkflowController.saveReview(
            command,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed:
            clearInputFailure(operation: .inputReviewSave)
        case .committedWithVisibilityFailure(_, let failure):
            recordInputVisibilityFailure(failure)
        }
    }

    func materializeRumination(
        _ review: RuminationReviewViewState, mode: MaterializationMode
    ) async throws -> MaterializationResult {
        let trace = makeInputOperationTrace(
            operation: .inputMaterialize
        )
        let command = InputMaterializationCommand(
            ingestionId: review.ingestionId,
            edited: inputReviewEditDraft(review),
            includeMissionDraft: mode == .notesAndMission
        )
        let receipt: InputMaterializationReceipt
        switch await inputWorkflowController.materialize(
            command,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed(let committed):
            receipt = committed
            clearInputFailure(operation: .inputMaterialize)
        case .committedWithVisibilityFailure(
            let committed,
            let failure
        ):
            receipt = committed
            recordInputVisibilityFailure(failure)
        }
        let campId = receipt.missionDraft?.draft.campId
            ?? codingRanchIngestionCampIds[review.ingestionId]
        invalidateInputReviewProjection(ingestionId: review.ingestionId)
        if let campId {
            await refreshInputCampProjection(
                campId: campId,
                makeVisible: self.campId == campId
            )
        }
        return MaterializationResult(
            noteId: receipt.materialization.noteId,
            missionDraft: receipt.missionDraft.map(
                inputMissionDraftViewState
            )
        )
    }

    func prepareIngestionDeletion(
        ingestionId: String,
        scope: IngestionDeletionScope
    ) async throws {
        guard let campId = codingRanchIngestionCampIds[ingestionId] else {
            throw CodingRanchUserFacingError(
                message: "无法确认这条资料所属的营地，请重新载入后再试。"
            )
        }
        let controllerScope: InputDeletionScope
        switch scope {
        case .resultOnly:
            controllerScope = .resultOnly
        case .sourceAndResult:
            controllerScope = .sourceAndResult
        }
        let trace = makeInputOperationTrace(
            operation: .inputDelete
        )
        do {
            let pending = try await inputWorkflowController
                .prepareActiveIngestionDeletion(
                    InputDeletionConfirmation(
                        campId: campId,
                        ingestionId: ingestionId,
                        scope: controllerScope
                    ),
                    trace: trace
                )
            applyPendingIngestionDeletion(pending)
        } catch {
            if let operation = error as? UserVisibleOperationError {
                globalVisibleFailure = operation.failure
            }
            throw error
        }
    }

    func executeIngestionDeletion() async -> Bool {
        let controller = inputWorkflowController
        let execution = Task {
            await controller.executePendingActiveIngestionDeletion()
        }
        await Task.yield()
        applyPendingIngestionDeletion(
            await controller.activeIngestionDeletionPendingState()
        )
        let pending = await execution.value
        applyPendingIngestionDeletion(pending)
        guard pending?.phase == .committedRefreshPending else {
            return false
        }
        return await completeCommittedIngestionDeletionRefresh()
    }

    func resolveIngestionDeletion() async -> Bool {
        let pending = await inputWorkflowController
            .resolvePendingActiveIngestionDeletion()
        applyPendingIngestionDeletion(pending)
        guard pending?.phase == .committedRefreshPending else {
            return false
        }
        return await completeCommittedIngestionDeletionRefresh()
    }

    func cancelIngestionDeletion() async -> Bool {
        let cleared = await inputWorkflowController
            .cancelPreparedActiveIngestionDeletion()
        applyPendingIngestionDeletion(
            await inputWorkflowController
                .activeIngestionDeletionPendingState()
        )
        return cleared
    }

    func retryIngestionDeletionRefresh() async -> Bool {
        await executeIngestionDeletion()
    }

    func abandonIngestionDeletionConflict() async -> Bool {
        guard let current = await inputWorkflowController
            .activeIngestionDeletionPendingState()
        else { return false }
        let campId = current.selection.campId
        let abandoned = await inputWorkflowController
            .abandonTerminalConflict { [weak self] in
                guard let self else { throw CancellationError() }
                try await self.reloadDeletionCamp(campId: campId)
            }
        applyPendingIngestionDeletion(
            await inputWorkflowController
                .activeIngestionDeletionPendingState()
        )
        return abandoned
    }

    func dismissCommittedIngestionDeletion() async -> Bool {
        guard let current = await inputWorkflowController
            .activeIngestionDeletionPendingState()
        else { return false }
        let dismissed = await inputWorkflowController
            .dismissCommittedActiveIngestionDeletion()
        guard dismissed else {
            applyPendingIngestionDeletion(current)
            return false
        }
        pendingIngestionDeletion = nil
        finalizeDeletionProjectionState(current)
        do {
            try await reloadDeletionCamp(
                campId: current.selection.campId
            )
        } catch {
            recordCodingRanchDiagnostic(
                error,
                operation: "dismiss-deletion-reload"
            )
            if let operation = error as? UserVisibleOperationError {
                globalVisibleFailure = operation.failure
            }
        }
        return true
    }

    func createMissionDraft(from ingestionId: String) async throws -> MissionDraftViewState {
        let trace = makeInputOperationTrace(
            operation: .inputMissionDraft
        )
        switch await inputWorkflowController.createMissionDraft(
            ingestionId: ingestionId,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed(let snapshot):
            clearInputFailure(operation: .inputMissionDraft)
            return inputMissionDraftViewState(snapshot)
        case .committedWithVisibilityFailure(let snapshot, let failure):
            recordInputVisibilityFailure(failure)
            return inputMissionDraftViewState(snapshot)
        }
    }

    func startMission(from draft: MissionDraftViewState) async throws -> String {
        guard !missionStartBlocked else {
            throw CodingRanchAdapterError.missionBlocked(
                missionStartBlockMessage
            )
        }
        guard let capability = draft.startCapability else {
            throw CodingRanchAdapterError.missionBlocked(
                draft.startBlockReason
                    ?? "当前资料没有可用的行动伙伴，暂时不能开始行动"
            )
        }
        let trace = makeMissionOperationTrace(operation: .missionStart)
        let runtime: PlanningEntryRuntimeSelection
        switch capturePlanningRuntimeSelection(trace: trace) {
        case .value(let selection):
            runtime = selection
        case .failed(let failure):
            throw UserVisibleOperationError(failure: failure)
        }
        let acceptance = draft.acceptance.map { "- [ ] \($0)" }.joined(separator: "\n")
        let goal = """
        \(draft.goal)

        验收清单：
        \(acceptance)
        """
        let request = capability.makeMissionStartRequest(
            goal: goal,
            workspacePath: draft.workspacePath.isEmpty
                ? nil
                : draft.workspacePath,
            plannerModel: runtime.plannerModel,
            runtimeProfileId: runtime.runtimeProfileId,
            budgetTokens: defaultMissionBudget,
            autonomy: defaultAutonomy,
            idempotencyKey:
                "mission-start:candidate:\(draft.draftId):v1",
            durableTraceId: trace.traceId
        )
        let missionId: String
        switch await missionWorkflowController.start(
            request,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw UserVisibleOperationError(failure: failure)
        case .committed(let committedMissionId):
            missionId = committedMissionId
        case .committedWithVisibilityFailure(
            let committedMissionId,
            let failure
        ):
            missionId = committedMissionId
            globalVisibleFailure = failure
        }
        currentMissionId = missionId
        _ = await refreshMissionDetailProjection(missionId: missionId)
        _ = await refreshMissionIndexProjection()
        return missionId
    }

    func loadReturnSummary(missionId: String) async throws -> ReturnSummaryViewState {
        let snapshot: MissionDetailSnapshot
        switch await refreshMissionDetailProjection(missionId: missionId) {
        case .loaded(let loaded):
            snapshot = loaded
        case .failed(let failure):
            throw UserVisibleOperationError(failure: failure)
        case .idle, .loading:
            throw ProjectionContractError.invalidTerminal
        }
        let progress: NewcomerProgress
        switch await refreshInputCampProjection(
            campId: snapshot.squad.campId,
            makeVisible: false
        ) {
        case .loaded(let campSnapshot):
            progress = campSnapshot.newcomerProgress
        case .failed(let failure):
            throw UserVisibleOperationError(failure: failure)
        case .idle, .loading:
            throw ProjectionContractError.invalidTerminal
        }
        let viewed = snapshot.artifacts.contains {
            hasViewedReturnArtifact(id: $0.id)
        }
        return .init(
            mission: missionViewState(snapshot.mission),
            artifacts: snapshot.artifacts.map {
                .init(
                    id: $0.id,
                    label: $0.label,
                    path: $0.path,
                    exists: FileManager.default.fileExists(atPath: $0.path),
                    previewable: true
                )
            },
            validationChecklist: snapshot.cards.map {
                .init(
                    id: $0.id,
                    title: $0.expectedOutput,
                    completed: $0.status == .done,
                    evidence: $0.handoffJson
                )
            },
            hasViewedArtifact: viewed,
            usedKnowledge: [],
            writtenBackNotes: [],
            newcomerProgress: newcomerProgress(progress),
            canAccept: snapshot.mission.status == .delivering
                && !snapshot.artifacts.isEmpty
                && snapshot.cards.allSatisfy { $0.status == .done },
            blockReason: snapshot.artifacts.isEmpty
                ? "任务还没有真实交付物"
                : nil
        )
    }

    func unlockTestCow() async throws -> CowSummaryViewState {
        let campId: String
        if let current = codingRanchDashboard?.campId {
            campId = current
        } else {
            let resolveTrace = makeInputOperationTrace(
                operation: .inputCampLoad
            )
            switch await inputWorkflowController.ensureDefaultCamp(
                trace: resolveTrace
            ) {
            case .notCommitted(let failure):
                throw inputOperationError(failure)
            case .committed(let receipt):
                campId = receipt.camp.id
            case .committedWithVisibilityFailure(
                let receipt,
                let failure
            ):
                campId = receipt.camp.id
                recordInputVisibilityFailure(failure)
            }
        }
        let trace = makeInputOperationTrace(
            operation: .inputCowUnlock
        )
        let cow: CompanionRecord
        switch await inputWorkflowController.unlockTestCow(
            campId: campId,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed(let record):
            cow = record
            clearInputFailure(operation: .inputCowUnlock)
        case .committedWithVisibilityFailure(let record, let failure):
            cow = record
            recordInputVisibilityFailure(failure)
        }
        await refreshInputCampProjection(
            campId: campId,
            makeVisible: self.campId == campId
        )
        return cowViewState(cow)
    }

    private func submitFeed(
        _ draft: FeedDraft, startRumination: Bool, allowDuplicate: Bool
    ) async throws -> FeedSubmissionResult {
        let trace = makeInputOperationTrace(
            operation: .inputFeedSubmit
        )
        let terminal = await inputWorkflowController.submit(
            FeedSubmissionCommand(
                campId: draft.campId,
                rawText: draft.body,
                title: draft.title,
                sourceURL: draft.sourceURL,
                author: draft.author,
                userIntent: draft.userIntent,
                sourceType: .text,
                allowDuplicate: allowDuplicate,
                startRumination: startRumination
            ),
            trace: trace
        )
        let submission: FeedSubmission
        let didStartRumination: Bool
        switch terminal {
        case .notCommitted(let failure):
            throw inputOperationError(failure)
        case .committed(let value):
            submission = value
            didStartRumination = startRumination
            clearInputFailure(operation: .inputFeedSubmit)
        case .committedWithVisibilityFailure(let value, let failure):
            submission = value
            didStartRumination = false
            recordInputVisibilityFailure(failure)
        }
        switch submission {
        case .duplicate(let existing):
            return .duplicate(existingId: existing.id, title: existing.title ?? "未命名资料")
        case .created(let item):
            codingRanchIngestionCampIds[item.id] = draft.campId
            await refreshInputCampProjection(
                campId: draft.campId,
                makeVisible: campId == draft.campId
            )
            return .saved(
                ingestionId: item.id,
                startsRumination: didStartRumination
            )
        }
    }

    private func inputReviewEditDraft(
        _ review: RuminationReviewViewState
    ) -> InputReviewEditDraft {
        let accepted = review.candidates.filter { $0.disposition == .accepted }
        let candidates: [InputReviewCandidateDraft] = accepted.compactMap {
            candidate in
            let kind: InputReviewCandidateKind
            switch candidate.kind {
            case .keyPoint:
                kind = .keyPoint
            case .requirement:
                kind = .requirement
            case .todo:
                kind = .todo
            case .mission:
                return nil
            }
            return InputReviewCandidateDraft(
                kind: kind,
                title: candidate.title,
                detail: candidate.detail,
                confidence: candidate.confidence,
                evidenceQuotes: candidate.evidence.map(\.quote)
            )
        }
        return InputReviewEditDraft(
            suggestedTitle: review.title,
            summary: review.summary,
            accepted: candidates,
            suggestedMission: review.suggestedMission.map {
                RuminationResult.SuggestedMission(
                    goal: $0.draft.goal,
                    acceptance: $0.draft.acceptance,
                    why: $0.why
                )
            },
            uncertainties: review.uncertainties
        )
    }

    private func reviewViewState(
        _ snapshot: InputReviewSnapshot
    ) -> RuminationReviewViewState {
        let ingestion = snapshot.ingestion
        let result = snapshot.result
        var candidates: [EditableCandidateViewState] = result.keyPoints.enumerated().map { index, point in
            .init(id: "key-\(index)", kind: .keyPoint, title: "关键点 \(index + 1)", detail: point.text,
                  disposition: .accepted, confidence: nil,
                  evidence: [.init(id: "evidence-key-\(index)", quote: point.sourceQuote, locator: nil, originLabel: "原始材料")], origin: nil)
        }
        candidates += result.requirements.enumerated().map { index, requirement in
            .init(id: "requirement-\(index)", kind: .requirement, title: requirement.title, detail: requirement.detail,
                  disposition: .accepted, confidence: requirement.confidence == .high ? 0.9 : (requirement.confidence == .medium ? 0.6 : 0.3),
                  evidence: [], origin: "AI 整理")
        }
        candidates += result.todos.enumerated().map { index, todo in
            .init(id: "todo-\(index)", kind: .todo, title: todo.title,
                  detail: [todo.owner, todo.dueText].compactMap { $0 }.joined(separator: " · "),
                  disposition: .accepted, confidence: nil, evidence: [], origin: "AI 整理")
        }
        let suggestedMission = result.suggestedMission.map { suggestion in
            let cow = snapshot.baseCow.map(cowViewState)
            let canStart = snapshot.baseCow != nil && !missionStartBlocked
            let blockReason: String?
            if snapshot.baseCow == nil {
                blockReason = "基础牛当前不可用"
            } else if missionStartBlocked {
                blockReason = missionStartBlockMessage
            } else {
                blockReason = nil
            }
            return SuggestedMissionReviewViewState(
                draft: MissionDraftViewState(
                    draftId: "pending",
                    ingestionId: ingestion.id,
                    campId: ingestion.campId,
                    cow: cow,
                    goal: suggestion.goal,
                    acceptance: suggestion.acceptance,
                    knowledge: [],
                    deliverableType:
                        MissionDraftViewState.defaultDeliverableType,
                    workspacePath: "",
                    isNewcomer: cow != nil,
                    canStart: canStart,
                    startBlockReason: blockReason,
                    startCapability: nil
                ),
                why: suggestion.why
            )
        }
        return .init(
            ingestionId: ingestion.id, title: result.suggestedTitle, summary: result.summary,
            candidates: candidates, suggestedMission: suggestedMission,
            source: .init(
                title: ingestion.title ?? result.suggestedTitle, sourceURL: ingestion.sourceURL,
                author: ingestion.author, userIntent: ingestion.userIntent,
                sourceKind: ingestion.sourceType == .manual ? .directThought : .pastedText,
                createdAt: ingestion.createdAt, rawText: ingestion.rawText
            ),
            uncertainties: result.uncertainties, isSaving: false, error: nil, hasChanges: false, canMaterialize: true
        )
    }

    private func inputMissionDraftViewState(
        _ snapshot: InputMissionDraftSnapshot
    ) -> MissionDraftViewState {
        let cow = snapshot.baseCow.map(cowViewState)
        let canStart = snapshot.startCapability != nil
            && !missionStartBlocked
        let blockReason: String?
        if snapshot.startCapability == nil {
            blockReason = "基础牛当前不可用"
        } else if missionStartBlocked {
            blockReason = missionStartBlockMessage
        } else {
            blockReason = nil
        }
        return MissionDraftViewState(
            draftId: snapshot.draft.candidateId,
            ingestionId: snapshot.draft.ingestionId,
            campId: snapshot.draft.campId,
            cow: cow,
            goal: snapshot.draft.goal,
            acceptance: snapshot.draft.acceptance,
            knowledge: [
                MissionKnowledgeItemViewState(
                    id: snapshot.sourceNote.id,
                    title: snapshot.sourceNote.title,
                    sourceLabel: "主动喂入"
                )
            ],
            deliverableType: MissionDraftViewState.defaultDeliverableType,
            workspacePath: "",
            isNewcomer: cow != nil,
            canStart: canStart,
            startBlockReason: blockReason,
            startCapability: snapshot.startCapability
        )
    }

    private func inputOperationError(
        _ failure: UserVisibleFailure
    ) -> UserVisibleOperationError {
        globalVisibleFailure = failure
        return UserVisibleOperationError(failure: failure)
    }

    private func applyPendingIngestionDeletion(
        _ pending: PendingActiveIngestionDeletion?
    ) {
        guard let pending else {
            pendingIngestionDeletion = nil
            return
        }
        let scope: IngestionDeletionScope
        switch pending.selection.scope {
        case .resultOnly:
            scope = .resultOnly
        case .sourceAndResult:
            scope = .sourceAndResult
        }
        let phase: IngestionDeletionPhaseViewState
        switch pending.phase {
        case .prepared:
            phase = .prepared
        case .executing:
            phase = .executing
        case .executionResolutionPending:
            phase = .executionResolutionPending
        case .committedRefreshPending:
            phase = .committedRefreshPending
        }
        let resolution: IngestionDeletionResolutionViewState?
        switch pending.resolutionDisposition {
        case .commitOutcomeUnknown:
            resolution = .commitOutcomeUnknown
        case .integrityBlocked:
            resolution = .integrityBlocked
        case .terminalConflict:
            resolution = .terminalConflict
        case nil:
            resolution = nil
        }
        pendingIngestionDeletion = PendingIngestionDeletionViewState(
            campId: pending.selection.campId,
            ingestionId: pending.selection.ingestionId,
            scope: scope,
            phase: phase,
            deletedResultCount: pending.preview.deletedResultCount,
            deletedSourceCount: pending.preview.deletedIngestionCount,
            campResultsAreRetained: true,
            failureMessage: pending.failure?.message,
            traceId: pending.trace.traceId,
            resolution: resolution
        )
        if let failure = pending.failure {
            globalVisibleFailure = failure
        } else {
            clearInputFailure(operation: .inputDelete)
        }
    }

    private func completeCommittedIngestionDeletionRefresh() async -> Bool {
        let refreshed = await inputWorkflowController
            .refreshCommittedActiveIngestionDeletion { [weak self] in
                guard let self else { throw CancellationError() }
                try await self.refreshCommittedDeletionProjection()
            }
        applyPendingIngestionDeletion(
            await inputWorkflowController
                .activeIngestionDeletionPendingState()
        )
        return refreshed
    }

    private func refreshCommittedDeletionProjection() async throws {
        guard let current = await inputWorkflowController
            .activeIngestionDeletionPendingState(),
              current.phase == .committedRefreshPending
        else {
            throw CodingRanchUserFacingError(
                message: "删除结果句柄不可用，请重新载入后确认。"
            )
        }
        try await reloadDeletionCamp(campId: current.selection.campId)
        finalizeDeletionProjectionState(current)
    }

    private func reloadDeletionCamp(campId: String) async throws {
        let terminal = await refreshInputCampProjection(
            campId: campId,
            makeVisible: self.campId == campId
        )
        switch terminal {
        case .loaded:
            return
        case .failed(let failure):
            throw UserVisibleOperationError(failure: failure)
        case .idle, .loading:
            throw CodingRanchUserFacingError(
                message: "营地尚未完成重新载入，请稍后重试。"
            )
        }
    }

    private func finalizeDeletionProjectionState(
        _ pending: PendingActiveIngestionDeletion
    ) {
        let ingestionId = pending.selection.ingestionId
        invalidateInputReviewProjection(ingestionId: ingestionId)
        ruminationPhases.removeValue(forKey: ingestionId)
        if pending.selection.scope == .sourceAndResult {
            codingRanchIngestionCampIds.removeValue(forKey: ingestionId)
        }
    }

    private func recordInputVisibilityFailure(
        _ failure: UserVisibleFailure
    ) {
        globalVisibleFailure = failure
        showToast(failure.message)
    }

    private func clearInputFailure(operation: FailureOperation) {
        if globalVisibleFailure?.operation == operation {
            globalVisibleFailure = nil
        }
    }

    private func sourceViewState(_ ingestion: IngestionItemRecord) -> SourceViewState {
        .init(
            title: ingestion.title ?? "未命名资料",
            sourceURL: ingestion.sourceURL,
            author: ingestion.author,
            userIntent: ingestion.userIntent,
            sourceKind: ingestion.sourceType == .manual ? .directThought : .pastedText,
            createdAt: ingestion.createdAt,
            rawText: ingestion.rawText
        )
    }

    func reconcileRuminationLiveStages(
        with snapshot: InputCampSnapshot
    ) {
        let itemById = Dictionary(
            uniqueKeysWithValues:
                snapshot.ingestionItems.map { ($0.id, $0) }
        )
        for ingestionId in Array(ruminationPhases.keys) {
            guard codingRanchIngestionCampIds[ingestionId]
                == snapshot.camp.id
            else {
                continue
            }
            guard let live = ruminationPhases[ingestionId] else {
                continue
            }
            guard let item = itemById[ingestionId],
                  item.status == .ruminating,
                  let work = snapshot.activeRuminationByIngestion[
                    ingestionId
                  ],
                  work.state == .running,
                  work.id == live.identity.workId,
                  work.attempt == live.identity.attempt
            else {
                ruminationPhases.removeValue(forKey: ingestionId)
                continue
            }
        }
    }

    func applyInputCampSnapshot(
        _ snapshot: InputCampSnapshot,
        makeVisible: Bool
    ) {
        let campId = snapshot.camp.id
        for item in snapshot.ingestionItems {
            codingRanchIngestionCampIds[item.id] = campId
        }
        upsertCampProjection(snapshot.camp)
        missionsByCamp[campId] = snapshot.missions
        for companion in snapshot.regularCompanions {
            if let index = companions.firstIndex(
                where: { $0.id == companion.id }
            ) {
                companions[index] = companion
            } else {
                companions.append(companion)
            }
        }

        let inboxItems = snapshot.ingestionItems.map {
            inputInboxItem(
                $0,
                campName: snapshot.camp.name,
                activeWork: snapshot.activeRuminationByIngestion[$0.id],
                materializedNoteId:
                    snapshot.materializedNoteIdByIngestion[$0.id]
            )
        }
        let pendingItems = inboxItems.filter {
            switch $0.status {
            case .queued, .ruminating, .needsReview, .failed:
                return true
            case .materialized, .discarded:
                return false
            }
        }
        let loadState: CodingRanchLoadState =
            kernelStartupRecoveryPending ? .loading : .loaded
        let missionSummaries = snapshot.missions.map {
            inputMissionViewState(
                $0,
                artifactCount:
                    snapshot.artifactCountByMission[$0.id] ?? 0
            )
        }
        let pendingRuminationCount = snapshot.ingestionItems.filter {
            [IngestionStatus.queued, .ruminating, .failed]
                .contains($0.status)
        }.count
        let pendingConfirmationCount = snapshot.ingestionItems.filter {
            $0.status == .needsReview
        }.count
        let pendingReturnCount = snapshot.missions.filter {
            $0.status == .delivering
        }.count
        let activeMissionSummaries = snapshot.missions.filter {
            [MissionStatus.planning, .executing, .delivering]
                .contains($0.status)
        }.map {
            inputMissionViewState(
                $0,
                artifactCount:
                    snapshot.artifactCountByMission[$0.id] ?? 0
            )
        }
        let recentMissionSummaries = Array(missionSummaries.prefix(5))
        let recentNoteSummaries = Array(snapshot.campNotes.prefix(5))
            .map(noteViewState)
        let progress = newcomerProgressViewState(snapshot.newcomerProgress)
        let dashboard = CampDashboardViewState(
            loadState: loadState,
            campId: campId,
            campName: snapshot.camp.name,
            activeCow: snapshot.regularCompanions.first.map(cowViewState),
            pendingRuminationCount: pendingRuminationCount,
            pendingConfirmationCount: pendingConfirmationCount,
            pendingReturnCount: pendingReturnCount,
            pendingItems: Array(pendingItems.prefix(4)),
            activeMissions: activeMissionSummaries,
            recentMissions: recentMissionSummaries,
            recentNotes: recentNoteSummaries,
            newcomerProgress: progress
        )
        let inbox = RuminationInboxViewState(
            loadState: loadState,
            items: inboxItems
        )
        codingRanchDashboardCache[campId] = dashboard
        codingRanchInboxCache[campId] = inbox
        if !kernelStartupRecoveryPending {
            codingRanchReadyCampIds.insert(campId)
        }
        guard makeVisible else { return }
        codingRanchDashboard = dashboard
        codingRanchInbox = inbox
    }

    private func inputInboxItem(
        _ item: IngestionItemRecord,
        campName: String,
        activeWork: DurableWorkRecord?,
        materializedNoteId: String?
    ) -> RuminationInboxItemViewState {
        let status: RuminationStatusViewState
        switch item.status {
        case .queued:
            status = .queued
        case .ruminating:
            if let live = ruminationPhases[item.id],
               let activeWork,
               activeWork.state == .running,
               activeWork.id == live.identity.workId,
               activeWork.attempt == live.identity.attempt
            {
                let stage: RuminationStage
                switch live.phase {
                case .reading: stage = .reading
                case .extracting: stage = .extracting
                case .organizing: stage = .organizing
                }
                status = .ruminating(stage: stage)
            } else {
                status = .ruminating(stage: .recovering)
            }
        case .needsReview:
            status = .needsReview
        case .materialized:
            status = .materialized(noteId: materializedNoteId ?? "")
        case .failed:
            status = .failed(
                message: item.errorText ?? "反刍失败",
                retryable: !item.rawText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        case .discarded:
            status = .discarded
        }
        return RuminationInboxItemViewState(
            id: item.id,
            title: item.title ?? "未命名资料",
            sourceKind: item.sourceType == .manual
                ? .directThought
                : .pastedText,
            createdAt: item.createdAt,
            campName: campName,
            status: status,
            resultCountText:
                item.status == .needsReview ? "待确认" : "",
            isPossibleDuplicate: false,
            error: item.errorText
        )
    }

    private func inputMissionViewState(
        _ mission: MissionRecord,
        artifactCount: Int
    ) -> MissionSummaryViewState {
        MissionSummaryViewState(
            id: mission.id,
            title: mission.goalRefined.isEmpty
                ? String(mission.goalRaw.prefix(50))
                : mission.goalRefined,
            phaseText: mission.status.rawValue,
            cowName: nil,
            lastActivity: nil,
            pendingUserAction:
                mission.status == .delivering ? "等待验收" : nil,
            artifactCount: artifactCount
        )
    }

    private func newcomerProgressViewState(
        _ core: NewcomerProgress
    ) -> NewcomerProgressViewState {
        let steps = [
            UnlockStepViewState(
                id: "feed",
                title: "喂牛并收进营地",
                status: core.hasMaterializedKnowledge
                    ? .completed
                    : .pending,
                evidenceText: nil
            ),
            UnlockStepViewState(
                id: "mission",
                title: "从资料开始放牛",
                status: core.hasReferencedMission
                    ? .completed
                    : .pending,
                evidenceText: nil
            ),
            UnlockStepViewState(
                id: "artifact",
                title: "得到真实成果",
                status: core.hasArtifact ? .completed : .pending,
                evidenceText: nil
            ),
            UnlockStepViewState(
                id: "accept",
                title: "验收并回营",
                status: core.hasAcceptedMission
                    ? .completed
                    : .pending,
                evidenceText: nil
            ),
        ]
        let profile = CowTemplate.displayProfile(for: CowTemplate.testCowId)
        return NewcomerProgressViewState(
            steps: steps,
            nextCow: LockedCowViewState(
                id: CowTemplate.testCowId,
                name: "测试牛",
                role: profile?.role ?? "验收与测试",
                capabilities: profile?.capabilities ?? [],
                learningGoal: profile?.learningGoal ?? "",
                conditions: steps.map(\.title)
            ),
            canUnlock: core.eligible && !core.isTestCowOwned,
            isUnlocked: core.isTestCowOwned
        )
    }

    private func emptyNewcomerProgressViewState()
        -> NewcomerProgressViewState
    {
        newcomerProgressViewState(
            NewcomerProgress(
                hasMaterializedKnowledge: false,
                hasReferencedMission: false,
                hasArtifact: false,
                hasUserConfirmation: false,
                hasAcceptedMission: false,
                isTestCowOwned: false
            )
        )
    }

    private func loadRuminationCampProjection(
        ingestionId: String,
        requireFreshReview: Bool
    ) async -> InputCampSnapshot? {
        var targetCampId = codingRanchIngestionCampIds[ingestionId]
        if requireFreshReview || targetCampId == nil {
            let reviewTerminal = await refreshInputReviewProjection(
                ingestionId: ingestionId
            )
            guard case .loaded(let snapshot) = reviewTerminal else {
                return nil
            }
            targetCampId = snapshot.ingestion.campId
            codingRanchIngestionCampIds[ingestionId] =
                snapshot.ingestion.campId
        }
        guard let targetCampId else {
            return nil
        }
        let campTerminal = await refreshInputCampProjection(
            campId: targetCampId,
            makeVisible: self.campId == targetCampId
        )
        guard case .loaded(let snapshot) = campTerminal else {
            return nil
        }
        return snapshot
    }

    func applyRuminationPhase(
        identity: RuminationPhaseIdentity,
        phase: RuminationPhase
    ) async {
        guard let snapshot = await loadRuminationCampProjection(
            ingestionId: identity.ingestionId,
            requireFreshReview: false
        ) else {
            return
        }
        let campId = snapshot.camp.id
        let matchesPersistedOwner = snapshot.ingestionItems.first(
            where: { $0.id == identity.ingestionId }
        ).map { item in
            guard item.status == .ruminating,
                  let work = snapshot.activeRuminationByIngestion[
                    identity.ingestionId
                  ]
            else {
                return false
            }
            return work.state == .running
                && work.id == identity.workId
                && work.attempt == identity.attempt
        } ?? false
        guard matchesPersistedOwner else {
            return
        }
        ruminationPhases[identity.ingestionId] = LiveRuminationPhase(
            identity: identity,
            phase: phase
        )
        applyInputCampSnapshot(
            snapshot,
            makeVisible: self.campId == campId
        )
    }

    func applyRuminationChange(
        _ change: RuminationChange
    ) async {
        let ingestionId: String
        switch change {
        case let .phaseInvalidated(identity):
            ingestionId = identity.ingestionId
            if ruminationPhases[ingestionId]?.identity
                == identity
            {
                ruminationPhases.removeValue(
                    forKey: ingestionId
                )
            }
        case let .projectionCommitted(
            identity,
            invalidatedPhaseIdentity
        ):
            ingestionId = identity.phaseIdentity.ingestionId
            if let invalidatedPhaseIdentity,
               ruminationPhases[ingestionId]?.identity
                    == invalidatedPhaseIdentity
            {
                ruminationPhases.removeValue(
                    forKey: ingestionId
                )
            }
        }
        _ = await loadRuminationCampProjection(
            ingestionId: ingestionId,
            requireFreshReview: true
        )
    }

    private func setDashboardLoadFailure(campId: String, campName: String, message: String) {
        recordCodingRanchLoadFailure(
            campId: campId,
            campName: campName,
            message: message,
            makeVisible: true
        )
    }

    func recordCodingRanchLoadFailure(
        campId: String,
        campName: String? = nil,
        message: String,
        makeVisible: Bool
    ) {
        codingRanchReadyCampIds.remove(campId)
        let dashboard: CampDashboardViewState
        if let prior = codingRanchDashboardCache[campId] {
            dashboard = CampDashboardViewState(
                loadState: .failed(message),
                campId: prior.campId,
                campName: prior.campName,
                activeCow: prior.activeCow,
                pendingRuminationCount: prior.pendingRuminationCount,
                pendingConfirmationCount:
                    prior.pendingConfirmationCount,
                pendingReturnCount: prior.pendingReturnCount,
                pendingItems: prior.pendingItems,
                activeMissions: prior.activeMissions,
                recentMissions: prior.recentMissions,
                recentNotes: prior.recentNotes,
                newcomerProgress: prior.newcomerProgress
            )
        } else {
            let cows = companions.filter {
                ($0.campId == campId || ($0.campId ?? "").isEmpty)
                    && $0.kind == .regular
            }
            dashboard = CampDashboardViewState(
                loadState: .failed(message),
                campId: campId,
                campName:
                    campName
                    ?? camps.first(where: { $0.id == campId })?.name
                    ?? "当前营地",
                activeCow: cows.first.map(cowViewState),
                pendingRuminationCount: 0,
                pendingConfirmationCount: 0,
                pendingReturnCount: 0,
                pendingItems: [],
                activeMissions: [],
                recentMissions: [],
                recentNotes: [],
                newcomerProgress: emptyNewcomerProgressViewState()
            )
        }
        let priorInbox = codingRanchInboxCache[campId]
        let inbox = RuminationInboxViewState(
            loadState: .failed(message),
            items: priorInbox?.items ?? []
        )
        codingRanchDashboardCache[campId] = dashboard
        codingRanchInboxCache[campId] = inbox
        guard makeVisible else {
            return
        }
        codingRanchDashboard = dashboard
        codingRanchInbox = inbox
    }

    private func inboxItem(
        _ item: IngestionItemRecord,
        campName: String,
        activeWork: DurableWorkRecord?
    ) -> RuminationInboxItemViewState {
        let status: RuminationStatusViewState
        switch item.status {
        case .queued: status = .queued
        case .ruminating:
            if let live = ruminationPhases[item.id],
               let activeWork,
               activeWork.state == .running,
               activeWork.id == live.identity.workId,
               activeWork.attempt == live.identity.attempt
            {
                let stage: RuminationStage
                switch live.phase {
                case .reading:
                    stage = .reading
                case .extracting:
                    stage = .extracting
                case .organizing:
                    stage = .organizing
                }
                status = .ruminating(stage: stage)
            } else {
                status = .ruminating(stage: .recovering)
            }
        case .needsReview: status = .needsReview
        case .materialized:
            let noteId = (try? db.pool.read { database in
                try KnowledgeSourceLinkRecord.filter(Column("ingestionId") == item.id).fetchOne(database)?.campNoteId
            }) ?? nil
            status = .materialized(noteId: noteId ?? "")
        case .failed:
            status = .failed(
                message: item.errorText ?? "反刍失败",
                retryable: !item.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        case .discarded: status = .discarded
        }
        return .init(
            id: item.id, title: item.title ?? "未命名资料",
            sourceKind: item.sourceType == .manual ? .directThought : .pastedText,
            createdAt: item.createdAt, campName: campName, status: status,
            resultCountText: item.status == .needsReview ? "待确认" : "", isPossibleDuplicate: false, error: item.errorText
        )
    }

    private func cowViewState(_ cow: CompanionRecord) -> CowSummaryViewState {
        let profile = CowTemplate.displayProfile(for: cow.id)
        return .init(
            id: cow.id, name: cow.name,
            role: profile?.role ?? "牧场伙伴",
            colorName: cow.color, specialties: profile?.specialties ?? [],
            status: .idle, lastActivity: nil, recentMission: nil, isSystemGuide: cow.kind == .guide
        )
    }

    private func missionViewState(_ mission: MissionRecord) -> MissionSummaryViewState {
        let artifactCount = (try? db.pool.read { database in
            try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM artifact
                JOIN card ON card.id = artifact.cardId
                WHERE card.missionId = ?
                """, arguments: [mission.id]) ?? 0
        }) ?? 0
        return .init(
            id: mission.id, title: mission.goalRefined.isEmpty ? String(mission.goalRaw.prefix(50)) : mission.goalRefined,
            phaseText: mission.status.rawValue, cowName: nil, lastActivity: nil,
            pendingUserAction: mission.status == .delivering ? "等待验收" : nil,
            artifactCount: artifactCount
        )
    }

    private func noteViewState(_ note: CampNoteRecord) -> CampNoteSummaryViewState {
        .init(
            id: note.id, title: note.title, excerpt: String(note.bodyMd.prefix(100)),
            sourceType: "camp_note", sourceLabel: "营地知识", updatedAt: note.updatedAt, pinned: note.pinned
        )
    }

    private func newcomerProgress(campId: String) -> NewcomerProgressViewState {
        let core = (try? NewcomerUnlockPolicy(db: db).progress(campId: campId))
            ?? .init(hasMaterializedKnowledge: false, hasReferencedMission: false, hasArtifact: false,
                     hasUserConfirmation: false, hasAcceptedMission: false, isTestCowOwned: false)
        return newcomerProgress(core)
    }

    private func newcomerProgress(
        _ core: NewcomerProgress
    ) -> NewcomerProgressViewState {
        let steps = [
            UnlockStepViewState(id: "feed", title: "喂牛并收进营地", status: core.hasMaterializedKnowledge ? .completed : .pending, evidenceText: nil),
            UnlockStepViewState(id: "mission", title: "从资料开始放牛", status: core.hasReferencedMission ? .completed : .pending, evidenceText: nil),
            UnlockStepViewState(id: "artifact", title: "得到真实成果", status: core.hasArtifact ? .completed : .pending, evidenceText: nil),
            UnlockStepViewState(id: "accept", title: "验收并回营", status: core.hasAcceptedMission ? .completed : .pending, evidenceText: nil),
        ]
        return .init(
            steps: steps,
            nextCow: {
                let profile = CowTemplate.displayProfile(for: CowTemplate.testCowId)
                return .init(
                    id: CowTemplate.testCowId, name: "测试牛", role: profile?.role ?? "验收与测试",
                    capabilities: profile?.capabilities ?? [], learningGoal: profile?.learningGoal ?? "",
                    conditions: steps.map { $0.title }
                )
            }(),
            canUnlock: core.eligible && !core.isTestCowOwned,
            isUnlocked: core.isTestCowOwned
        )
    }
}

enum CodingRanchAdapterError: Error, LocalizedError {
    case modelMissing
    case missionBlocked(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing: "请先在设置中配置模型"
        case .missionBlocked(let message): message
        }
    }
}
