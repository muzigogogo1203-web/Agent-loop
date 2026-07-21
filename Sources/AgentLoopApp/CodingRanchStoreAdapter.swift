import Foundation
import GRDB
import AgentLoopCore

@MainActor
extension AppStore: CodingRanchStoreProtocol {
    var dashboard: CampDashboardViewState? { codingRanchDashboard }
    var ruminationInbox: RuminationInboxViewState { codingRanchInbox }

    func loadDashboard(campId: String) async {
        do {
            let camp = try db.camp(id: campId) ?? camps.first(where: { $0.id == campId })
            guard let camp else {
                setDashboardLoadFailure(campId: campId, campName: "当前营地", message: "找不到这个营地，刷新后再试")
                return
            }
            let ingestionItems = try FeedService(db: db).items(campId: campId)
            let inboxItems = ingestionItems.map { inboxItem($0, campName: camp.name) }
            let pendingItems = inboxItems.filter {
                switch $0.status {
                case .queued, .ruminating, .needsReview, .failed: true
                case .materialized, .discarded: false
                }
            }
            let missions = try db.missions(campId: campId)
            let notes = try db.campNotes(campId: campId)
            let cows = companions.filter {
                ($0.campId == campId || ($0.campId ?? "").isEmpty) && $0.kind == .regular
            }
            let progress = newcomerProgress(campId: campId)
            codingRanchDashboard = CampDashboardViewState(
                loadState: .loaded,
                campId: camp.id,
                campName: camp.name,
                activeCow: cows.first.map(cowViewState),
                pendingRuminationCount: ingestionItems.filter { [.queued, .ruminating, .failed].contains($0.status) }.count,
                pendingConfirmationCount: ingestionItems.filter { $0.status == .needsReview }.count,
                pendingReturnCount: missions.filter { $0.status == .delivering }.count,
                pendingItems: Array(pendingItems.prefix(4)),
                activeMissions: missions.filter { [.planning, .executing, .delivering].contains($0.status) }.map(missionViewState),
                recentMissions: Array(missions.prefix(5)).map(missionViewState),
                recentNotes: Array(notes.prefix(5)).map(noteViewState),
                newcomerProgress: progress
            )
            codingRanchInbox = .init(loadState: .loaded, items: inboxItems)
        } catch {
            let campName = camps.first(where: { $0.id == campId })?.name ?? "当前营地"
            setDashboardLoadFailure(
                campId: campId,
                campName: campName,
                message: "营地暂时加载失败：\(error.localizedDescription)"
            )
        }
    }

    func loadRuminationInbox(campId: String) async {
        do {
            let campName = try db.camp(id: campId)?.name ?? camps.first(where: { $0.id == campId })?.name ?? "当前营地"
            let items = try FeedService(db: db).items(campId: campId).map { inboxItem($0, campName: campName) }
            codingRanchInbox = .init(loadState: .loaded, items: items)
        } catch {
            codingRanchInbox = .init(
                loadState: .failed("待反刍列表暂时加载失败：\(error.localizedDescription)"),
                items: []
            )
        }
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

    /// 反刍阶段回调:把 Core 的真实阶段(extracting/organizing)映射进内存态供 UI 展示。
    private func ruminationPhaseHandler(ingestionId: String) -> @Sendable (RuminationService.RuminationPhase) -> Void {
        { [weak self] phase in
            Task { @MainActor [weak self] in
                self?.setRuminationStage(
                    phase == .extracting ? .extracting : .organizing,
                    ingestionId: ingestionId
                )
            }
        }
    }

    func startRumination(ingestionId: String) async {
        ruminationActionError = nil
        let item: IngestionItemRecord
        do {
            guard let storedItem = try FeedService(db: db).item(id: ingestionId) else {
                ruminationActionError = "这条材料不存在了，刷新看看"
                return
            }
            item = storedItem
        } catch {
            ruminationActionError = "这条材料暂时读不到，请刷新后再试"
            return
        }
        guard let provider = provider(model: effectiveDistillModel) else {
            ruminationActionError = "请先在设置里配置模型供给线"
            return
        }
        let service = RuminationService(db: db, provider: provider)
        do {
            _ = try service.start(ingestionId: ingestionId)
        } catch FeedServiceError.invalidState(.ruminating) {
            await loadDashboard(campId: item.campId)
            return
        } catch {
            ruminationActionError = "反刍没有开始：\(error.localizedDescription)"
            return
        }
        await loadDashboard(campId: item.campId)
        Task { [weak self] in
            guard let self else { return }
            setRuminationStage(.reading, ingestionId: ingestionId)
            do {
                _ = try await service.processStarted(
                    ingestionId: ingestionId,
                    onPhase: ruminationPhaseHandler(ingestionId: ingestionId)
                )
            } catch {
                ruminationActionError = "反刍没有完成，请查看失败原因后重试"
            }
            setRuminationStage(nil, ingestionId: ingestionId)
            await loadDashboard(campId: item.campId)
        }
    }

    func retryRumination(ingestionId: String) async { await startRumination(ingestionId: ingestionId) }

    func cancelRumination(ingestionId: String) async throws {
        guard let provider = provider(model: effectiveDistillModel) else { return }
        try RuminationService(db: db, provider: provider).cancel(ingestionId: ingestionId)
    }

    func loadRuminationReview(ingestionId: String) async throws -> RuminationReviewViewState {
        let pair = try await db.pool.read { database in
            guard let ingestion = try IngestionItemRecord.fetchOne(database, key: ingestionId),
                  let stored = try RuminationResultRecord.filter(Column("ingestionId") == ingestionId).fetchOne(database) else {
                throw FeedServiceError.ingestionNotFound(ingestionId)
            }
            let result = try RuminationCoding.decode(stored.userEditedJson ?? stored.resultJson)
            return (ingestion, result)
        }
        return reviewViewState(ingestion: pair.0, result: pair.1)
    }

    func loadRuminationSource(ingestionId: String) async throws -> SourceViewState {
        guard let ingestion = try FeedService(db: db).item(id: ingestionId) else {
            throw FeedServiceError.ingestionNotFound(ingestionId)
        }
        return sourceViewState(ingestion)
    }

    func saveRuminationReview(_ review: RuminationReviewViewState) async throws {
        let edited = coreResult(review)
        try await db.pool.write { database in
            guard var stored = try RuminationResultRecord
                .filter(Column("ingestionId") == review.ingestionId).fetchOne(database) else {
                throw FeedServiceError.ingestionNotFound(review.ingestionId)
            }
            stored.userEditedJson = try RuminationCoding.encode(edited)
            stored.updatedAt = Date()
            try stored.update(database)
        }
    }

    func materializeRumination(
        _ review: RuminationReviewViewState, mode: MaterializationMode
    ) async throws -> MaterializationResult {
        let result = try RuminationMaterializer(db: db).materialize(
            ingestionId: review.ingestionId, edited: coreResult(review)
        )
        let missionDraft: MissionDraftViewState?
        if mode == .notesAndMission {
            missionDraft = try await createMissionDraft(from: review.ingestionId)
        } else {
            missionDraft = nil
        }
        if let campId = try FeedService(db: db).item(id: review.ingestionId)?.campId {
            reload()
            await loadDashboard(campId: campId)
        }
        return .init(noteId: result.noteId, missionDraft: missionDraft)
    }

    func deleteIngestion(ingestionId: String, scope: IngestionDeletionScope) async throws {
        try await db.pool.write { database in
            switch scope {
            case .resultOnly:
                try RuminationResultRecord.filter(Column("ingestionId") == ingestionId).deleteAll(database)
                if var item = try IngestionItemRecord.fetchOne(database, key: ingestionId) {
                    item.status = .queued; item.errorText = nil; item.updatedAt = Date(); try item.update(database)
                }
            case .sourceAndResult:
                guard try KnowledgeSourceLinkRecord.filter(Column("ingestionId") == ingestionId).fetchCount(database) == 0 else {
                    throw FeedServiceError.invalidState(.materialized)
                }
                try ActionCandidateRecord.filter(Column("ingestionId") == ingestionId).deleteAll(database)
                try RuminationResultRecord.filter(Column("ingestionId") == ingestionId).deleteAll(database)
                try IngestionItemRecord.deleteOne(database, key: ingestionId)
            case .everythingIncludingProjection:
                throw FeedServiceError.invalidState(.materialized)
            }
        }
    }

    func createMissionDraft(from ingestionId: String) async throws -> MissionDraftViewState {
        let candidate = try await db.pool.read { database in
            try ActionCandidateRecord
                .filter(Column("ingestionId") == ingestionId && Column("type") == ActionCandidateType.mission.rawValue)
                .fetchOne(database)
        }
        guard let candidate else { throw RecordNotFoundError(table: "action_candidate", id: ingestionId) }
        let core = try MissionDraftFactory(db: db).draft(candidateId: candidate.id)
        let cow = companions.first(where: { $0.id == CowTemplate.baseCowId }).map(cowViewState)
        let note = try await db.pool.read { try CampNoteRecord.fetchOne($0, key: core.noteId) }
        return .init(
            draftId: core.candidateId, ingestionId: core.ingestionId, campId: core.campId,
            cow: cow, goal: core.goal, acceptance: core.acceptance,
            knowledge: [.init(id: core.noteId, title: note?.title ?? "来源笔记", sourceLabel: "主动喂入")],
            deliverableType: MissionDraftViewState.defaultDeliverableType, workspacePath: "", isNewcomer: cow != nil,
            canStart: provider(model: effectivePlannerModel) != nil && !missionStartBlocked,
            startBlockReason: missionStartBlocked ? missionStartBlockMessage : (apiKeyPresent ? nil : "请先配置模型")
        )
    }

    func startMission(from draft: MissionDraftViewState) async throws -> String {
        let factory = MissionDraftFactory(db: db)
        if let existing = try factory.existingMissionId(candidateId: draft.draftId) { return existing }
        guard !missionStartBlocked else { throw CodingRanchAdapterError.missionBlocked(missionStartBlockMessage) }
        guard provider(model: effectivePlannerModel) != nil else { throw CodingRanchAdapterError.modelMissing }
        let acceptance = draft.acceptance.map { "- [ ] \($0)" }.joined(separator: "\n")
        let selectedNotes = try await db.pool.read { database in
            try CampNoteRecord.fetchAll(database, keys: draft.knowledge.map(\.id))
        }
        let knowledgeContext = selectedNotes.map { note in
            "### \(note.title)\n\(String(note.bodyMd.prefix(8_000)))"
        }.joined(separator: "\n\n")
        let goal = """
        \(draft.goal)

        验收清单：
        \(acceptance)

        本次明确选择的营地知识：
        \(knowledgeContext)
        """
        let missionId = try await orchestrator.startMission(
            goal: goal,
            companionIds: [draft.cow?.id ?? CowTemplate.baseCowId],
            workspacePath: draft.workspacePath.isEmpty ? nil : draft.workspacePath,
            plannerModel: effectivePlannerModel,
            budgetTokens: defaultMissionBudget,
            campId: draft.campId,
            autonomy: defaultAutonomy
        )
        _ = try factory.linkConverted(candidateId: draft.draftId, missionId: missionId)
        currentMissionId = missionId
        reload()
        return missionId
    }

    func loadReturnSummary(missionId: String) async throws -> ReturnSummaryViewState {
        guard let mission = try db.mission(id: missionId) else {
            throw RecordNotFoundError(table: "mission", id: missionId)
        }
        let cards = try db.cards(missionId: missionId)
        let artifacts = try await db.pool.read { database in
            try ArtifactRecord
                .filter(cards.map(\.id).contains(Column("cardId")))
                .fetchAll(database)
        }
        let viewed = !artifacts.isEmpty
        return .init(
            mission: missionViewState(mission),
            artifacts: artifacts.map { .init(id: $0.id, label: $0.label, path: $0.path, exists: FileManager.default.fileExists(atPath: $0.path), previewable: true) },
            validationChecklist: cards.map { .init(id: $0.id, title: $0.expectedOutput, completed: $0.status == .done, evidence: $0.handoffJson) },
            hasViewedArtifact: viewed,
            usedKnowledge: [], writtenBackNotes: [], newcomerProgress: newcomerProgress(campId: camp(forMission: missionId) ?? ""),
            canAccept: mission.status == .delivering && !artifacts.isEmpty && cards.allSatisfy { $0.status == .done },
            blockReason: artifacts.isEmpty ? "任务还没有真实交付物" : nil
        )
    }

    func unlockTestCow() async throws -> CowSummaryViewState {
        let campId: String
        if let current = codingRanchDashboard?.campId {
            campId = current
        } else {
            campId = try db.ensureDefaultCamp().id
        }
        let cow = try NewcomerUnlockPolicy(db: db).unlockTestCow(campId: campId)
        reload()
        await loadDashboard(campId: campId)
        return cowViewState(cow)
    }

    private func submitFeed(
        _ draft: FeedDraft, startRumination: Bool, allowDuplicate: Bool
    ) async throws -> FeedSubmissionResult {
        if try isCampArchived(id: draft.campId) {
            showToast("营地已归档,恢复后才能继续喂牛")
            throw CampArchivedError(campId: draft.campId)
        }
        let submission = try FeedService(db: db).submit(
            campId: draft.campId, rawText: draft.body, title: draft.title,
            sourceURL: draft.sourceURL, author: draft.author, userIntent: draft.userIntent,
            sourceType: .text, allowDuplicate: allowDuplicate
        )
        switch submission {
        case .duplicate(let existing):
            return .duplicate(existingId: existing.id, title: existing.title ?? "未命名资料")
        case .created(let item):
            let ruminationProvider = provider(model: effectiveDistillModel)
            if startRumination, let ruminationProvider {
                let service = RuminationService(db: db, provider: ruminationProvider)
                _ = try service.start(ingestionId: item.id)
                Task { [weak self] in
                    guard let self else { return }
                    setRuminationStage(.reading, ingestionId: item.id)
                    _ = try? await service.processStarted(
                        ingestionId: item.id,
                        onPhase: ruminationPhaseHandler(ingestionId: item.id)
                    )
                    setRuminationStage(nil, ingestionId: item.id)
                    await loadDashboard(campId: draft.campId)
                }
            }
            await loadDashboard(campId: draft.campId)
            return .saved(ingestionId: item.id, startsRumination: startRumination && ruminationProvider != nil)
        }
    }

    private func coreResult(_ review: RuminationReviewViewState) -> RuminationResult {
        let accepted = review.candidates.filter { $0.disposition == .accepted }
        return .init(
            suggestedTitle: review.title,
            summary: review.summary,
            keyPoints: accepted.filter { $0.kind == .keyPoint }.map {
                .init(text: $0.detail, sourceQuote: $0.evidence.first?.quote ?? "用户确认")
            },
            requirements: accepted.filter { $0.kind == .requirement }.map {
                .init(title: $0.title, detail: $0.detail, confidence: ($0.confidence ?? 0.5) >= 0.8 ? .high : (($0.confidence ?? 0.5) >= 0.5 ? .medium : .low))
            },
            todos: accepted.filter { $0.kind == .todo }.map { .init(title: $0.title) },
            suggestedMission: review.missionDraft.map {
                .init(goal: $0.goal, acceptance: $0.acceptance, why: "由用户确认的反刍结果生成")
            },
            uncertainties: review.uncertainties
        )
    }

    private func reviewViewState(ingestion: IngestionItemRecord, result: RuminationResult) -> RuminationReviewViewState {
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
        let mission = result.suggestedMission.map {
            MissionDraftViewState(
                draftId: "pending", ingestionId: ingestion.id, campId: ingestion.campId,
                cow: companions.first(where: { $0.id == CowTemplate.baseCowId }).map(cowViewState),
                goal: $0.goal, acceptance: $0.acceptance, knowledge: [], deliverableType: MissionDraftViewState.defaultDeliverableType,
                workspacePath: "", isNewcomer: true, canStart: true, startBlockReason: nil
            )
        }
        return .init(
            ingestionId: ingestion.id, title: result.suggestedTitle, summary: result.summary,
            candidates: candidates, missionDraft: mission,
            source: .init(
                title: ingestion.title ?? result.suggestedTitle, sourceURL: ingestion.sourceURL,
                author: ingestion.author, userIntent: ingestion.userIntent,
                sourceKind: ingestion.sourceType == .manual ? .directThought : .pastedText,
                createdAt: ingestion.createdAt, rawText: ingestion.rawText
            ),
            uncertainties: result.uncertainties, isSaving: false, error: nil, hasChanges: false, canMaterialize: true
        )
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

    private func setRuminationStage(_ stage: RuminationStage?, ingestionId: String) {
        ruminationStages[ingestionId] = stage
        guard let stage,
              let index = codingRanchInbox.items.firstIndex(where: { $0.id == ingestionId }) else {
            return
        }
        let current = codingRanchInbox.items[index]
        guard case .ruminating = current.status else { return }
        var items = codingRanchInbox.items
        items[index] = .init(
            id: current.id,
            title: current.title,
            sourceKind: current.sourceKind,
            createdAt: current.createdAt,
            campName: current.campName,
            status: .ruminating(stage: stage),
            resultCountText: current.resultCountText,
            isPossibleDuplicate: current.isPossibleDuplicate,
            error: current.error
        )
        codingRanchInbox = .init(loadState: codingRanchInbox.loadState, items: items)
    }

    private func setDashboardLoadFailure(campId: String, campName: String, message: String) {
        let cows = companions.filter {
            ($0.campId == campId || ($0.campId ?? "").isEmpty) && $0.kind == .regular
        }
        codingRanchDashboard = .init(
            loadState: .failed(message),
            campId: campId,
            campName: campName,
            activeCow: cows.first.map(cowViewState),
            pendingRuminationCount: 0,
            pendingConfirmationCount: 0,
            pendingReturnCount: 0,
            pendingItems: [],
            activeMissions: [],
            recentMissions: [],
            recentNotes: [],
            newcomerProgress: newcomerProgress(campId: campId)
        )
        codingRanchInbox = .init(loadState: .failed(message), items: [])
    }

    private func inboxItem(_ item: IngestionItemRecord, campName: String) -> RuminationInboxItemViewState {
        let status: RuminationStatusViewState
        switch item.status {
        case .queued: status = .queued
        case .ruminating: status = .ruminating(stage: ruminationStages[item.id] ?? .reading)
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
