import Testing
import Darwin
import Foundation
import GRDB
import AgentLoopCore

private func harvestDatabase() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
}

private func completedHandoff(
    outcome: String = "完成",
    summary: String = "交付已验证",
    artifact: HandoffPayload.ArtifactDecl? = nil
) -> HandoffPayload {
    HandoffPayload(
        outcome: outcome,
        summary: summary,
        artifacts: artifact.map { [$0] } ?? [],
        noArtifactReason: artifact == nil ? "无需文件" : nil,
        verification: [.init(method: "检查", passed: true, note: "通过")],
        risks: []
    )
}

private func setMissionStatus(_ status: MissionStatus, missionId: String, db: AppDatabase) throws {
    try db.pool.write { database in
        guard var mission = try MissionRecord.fetchOne(database, key: missionId) else {
            throw RecordNotFoundError(table: "mission", id: missionId)
        }
        mission.status = status
        try mission.update(database)
    }
}

private func harvestRecoveryOrchestrator(
    db: AppDatabase,
    root: URL
) -> Orchestrator {
    Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver { _, _ in
            MockProvider(script: [])
        },
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
}

private struct HarvestRowEvent: Equatable {
    let kind: String
    let payloadJSON: String
}

private func harvestCardEventsByRowID(
    _ db: AppDatabase,
    cardID: String
) throws -> [HarvestRowEvent] {
    try db.pool.read { database in
        try Row.fetchAll(
            database,
            sql: "SELECT kind, payloadJson FROM event WHERE cardId=? ORDER BY rowid",
            arguments: [cardID]
        ).map { row in
            HarvestRowEvent(
                kind: row["kind"],
                payloadJSON: row["payloadJson"]
            )
        }
    }
}

@Test func artifactLedgerFiltersArchivedCampsAndBuildsStableReport() throws {
    let db = try harvestDatabase()
    let camp = try db.ensureDefaultCamp()
    let ids = try db.createSingleCardMission(
        campName: camp.name,
        squadName: "远征队",
        goal: "制作减肥大作战网页",
        cardTitle: "完成网页",
        cardDescription: "制作可运行页面",
        expectedOutput: "HTML 文件",
        assigneeId: nil,
        maxTurns: KernelDefaults.maxTurns,
        campId: camp.id
    )
    try db.transitionCard(
        id: ids.cardId,
        to: .running,
        eventKind: EventKind.cardStarted,
        payload: .object([:])
    )
    let declaration = HandoffPayload.ArtifactDecl(
        relativePath: "index.html",
        kind: "file",
        label: "减肥大作战网页"
    )
    let artifactDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-harvest-external-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: artifactDirectory,
        withIntermediateDirectories: true
    )
    let artifactURL = artifactDirectory.appendingPathComponent("index.html")
    try "<html><body>减肥大作战</body></html>".write(
        to: artifactURL,
        atomically: true,
        encoding: .utf8
    )
    let externalReference = try WorkspaceExternalArtifactReferenceV1.explicit(
        cardId: ids.cardId,
        path: artifactURL.path,
        kind: declaration.kind,
        label: declaration.label,
        classifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try db.completeCard(
        id: ids.cardId,
        runId: nil,
        handoff: completedHandoff(artifact: declaration),
        workspaceExternalArtifacts: [externalReference]
    )

    let ledger = try db.artifactLedger()
    #expect(ledger.count == 1)
    #expect(ledger[0].artifact.label == "减肥大作战网页")
    #expect(ledger[0].mission.id == ids.missionId)
    #expect(ledger[0].camp.id == camp.id)

    let input = try db.expeditionReportInput(missionId: ids.missionId)
    let first = ExpeditionReport.markdown(input)
    let second = ExpeditionReport.markdown(input)
    #expect(first == second)
    #expect(first.contains("# 远征报告：制作减肥大作战网页"))
    #expect(first.contains("减肥大作战网页"))
    #expect(first.contains("## 时间线"))

    try db.pool.write { database in
        try database.execute(
            sql: "UPDATE mission SET status='accepted' WHERE id=?",
            arguments: [ids.missionId]
        )
    }
    try db.setCampArchived(id: camp.id, archived: true)
    #expect(try db.artifactLedger(includeArchived: false).isEmpty)
    #expect(try db.artifactLedger(includeArchived: true).count == 1)
}

@Test func archivedCampRejectsNewMissionShell() throws {
    let db = try harvestDatabase()
    let camp = try db.ensureDefaultCamp()
    try db.setCampArchived(id: camp.id, archived: true)

    #expect(throws: CampArchivedError(campId: camp.id)) {
        try db.createMissionShell(
            goal: "归档后不能开新行动",
            companionIds: [],
            workspacePath: nil,
            campId: camp.id
        )
    }
}

@Test func returningCompletedCardReopensMissionAndMarksDoneDependentsForReview() throws {
    let db = try harvestDatabase()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "小微",
        color: "blue",
        rolePrompt: "执行任务",
        model: "test-model",
        campId: camp.id
    )
    try db.saveCompanion(companion)
    let missionId = try db.createMissionShell(
        goal: "完成两阶段行动",
        companionIds: [companion.id],
        workspacePath: nil,
        campId: camp.id
    )
    try db.planMission(missionId: missionId, goalRefined: "完成两阶段行动", drafts: [
        .init(title: "上游", description: "先完成", expectedOutput: "结果 A", assignee: 0, dependsOn: []),
        .init(title: "下游", description: "基于上游", expectedOutput: "结果 B", assignee: 0, dependsOn: [0]),
    ])
    let cards = try db.cards(missionId: missionId)
    for card in cards {
        try db.transitionCard(
            id: card.id,
            to: .ready,
            eventKind: EventKind.cardReady,
            payload: .object([:])
        )
        try db.transitionCard(
            id: card.id,
            to: .running,
            eventKind: EventKind.cardStarted,
            payload: .object([:])
        )
        try db.completeCard(
            id: card.id,
            runId: nil,
            handoff: completedHandoff(outcome: "完成 \(card.title)", summary: "旧摘要 \(card.title)"),
            durableArtifacts: []
        )
    }
    #expect(try db.mission(id: missionId)?.status == .delivering)

    try db.returnCardForRework(cardId: cards[0].id, feedback: "请补充移动端适配")

    let returned = try #require(try db.card(id: cards[0].id))
    let dependent = try #require(try db.card(id: cards[1].id))
    let feedback = try #require(try db.latestReturnFeedback(cardId: cards[0].id))
    #expect(returned.status == .ready)
    #expect(dependent.status == .done)
    #expect(dependent.reviewFlag == "stale_upstream")
    #expect(try db.mission(id: missionId)?.status == .executing)
    #expect(feedback.feedback == "请补充移动端适配")
    #expect(feedback.previousOutcome == "完成 上游")
    #expect(feedback.previousSummary == "旧摘要 上游")
    #expect(try db.events(missionId: missionId, limit: 100).contains { $0.kind == EventKind.cardReturned })

    try db.clearCardReviewFlag(cardId: cards[1].id)
    let cleared = try #require(try db.card(id: cards[1].id))
    #expect(cleared.reviewFlag == nil)
    #expect(try db.events(missionId: missionId, limit: 100).contains {
        $0.kind == EventKind.cardReviewCleared && $0.cardId == cards[1].id
    })
}

@Test func readyProducingMissionAndReworkWritesEndWithCanonicalReadyEvent() throws {
    // Mutation caught: omitting the final card_ready append (or appending it
    // before card_returned) leaves a ready Card without its sole dispatch cause.
    let db = try harvestDatabase()
    let camp = try db.ensureDefaultCamp()
    let ids = try db.createSingleCardMission(
        campName: camp.name,
        squadName: "ready cause",
        goal: "verify ready writer",
        cardTitle: "write ready",
        cardDescription: "ready event must be final",
        expectedOutput: "event",
        assigneeId: nil,
        maxTurns: 1,
        campId: camp.id
    )

    let initialEvents = try db.events(cardId: ids.cardId)
    #expect(initialEvents.map(\.kind) == ["mission_created", "card_ready"])
    #expect(initialEvents.last?.payloadJson == "{}")

    try db.transitionCard(
        id: ids.cardId,
        to: .running,
        eventKind: "card_started",
        payload: .object([:])
    )
    try db.completeCard(
        id: ids.cardId,
        runId: nil,
        handoff: completedHandoff(),
        durableArtifacts: []
    )
    try db.returnCardForRework(cardId: ids.cardId, feedback: "make it clearer")

    let reworkEvents = try db.events(cardId: ids.cardId)
    #expect(reworkEvents.suffix(2).map(\.kind) == ["card_returned", "card_ready"])
    #expect(reworkEvents.last?.payloadJson == "{}")
}

@Test func orphanRecoveryWritesCanonicalReadyOnlyForGenuineLegacyRuns() async throws {
    // Mutation caught: orphan recovery omitting/reordering its ready cause, or
    // treating an engine-owned Run as a legacy crash orphan after any terminal state.
    let legacyRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("r9-a-legacy-orphan-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
    let legacyDB = try harvestDatabase()
    let legacyIDs = try legacyDB.createSingleCardMission(
        campName: "legacy orphan", squadName: "legacy orphan", goal: "recover",
        cardTitle: "legacy", cardDescription: "legacy", expectedOutput: "ready",
        assigneeId: nil, maxTurns: 1
    )
    try legacyDB.startRun(cardId: legacyIDs.cardId, runId: "r9-a-legacy-open-run")
    let legacyOrchestrator = harvestRecoveryOrchestrator(db: legacyDB, root: legacyRoot)
    await legacyOrchestrator.recoverAndReconcile()
    let legacyEvents = try harvestCardEventsByRowID(legacyDB, cardID: legacyIDs.cardId)
    let interruptedIndex = try #require(
        legacyEvents.lastIndex { $0.kind == EventKind.cardInterrupted }
    )
    #expect(interruptedIndex + 1 < legacyEvents.count)
    #expect(legacyEvents[interruptedIndex + 1].kind == EventKind.cardReady)
    #expect(legacyEvents[interruptedIndex + 1].payloadJSON == "{}")
    #expect(try legacyDB.runs(cardId: legacyIDs.cardId).first?.outcome == "interrupted")
    await legacyOrchestrator.shutdown()

    for terminal in [false, true] {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "r9-a-engine-orphan-\(terminal)")
        if terminal {
            let prepared = try await fixture.db.pool.read { database in
                try #require(try EngineExecutionRecord.fetchOne(database, key: request.executionId))
            }
            _ = try fixture.store.markEngineDispatchStarted(
                executionId: request.executionId,
                expectedVersion: prepared.version,
                requestHash: request.requestHash,
                commandIdempotencyKey: "r9-a-engine-orphan-terminal-dispatch",
                now: p1f1EngineTestNow.addingTimeInterval(1)
            )
            let proposal = try fixture.store.recordEngineTerminalProposal(
                EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: request.executionId,
                    runId: request.runId,
                    cardId: request.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "r9-a-engine-orphan-terminal",
                    terminalKind: .blocked,
                    terminalSubtype: .needsHumanInput,
                    payload: .needsHumanInput(
                        kind: .choice,
                        prompt: "retain engine ownership",
                        options: ["yes", "no"]
                    ),
                    artifacts: []
                )
            )
            _ = try fixture.store.commitEngineAskUser(
                proposalId: proposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1EngineTestNow.addingTimeInterval(2)
            )
            try fixture.db.transitionCard(
                id: request.cardId, to: .ready,
                eventKind: EventKind.cardReady, payload: .object([:])
            )
            try fixture.db.transitionCard(
                id: request.cardId, to: .running,
                eventKind: EventKind.cardStarted, payload: .object([:])
            )
        }
        #expect(try fixture.db.card(id: request.cardId)?.status == .running)
        let before = try harvestCardEventsByRowID(fixture.db, cardID: request.cardId)
        let engineRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("r9-a-engine-orphan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: engineRoot, withIntermediateDirectories: true)
        let engineOrchestrator = harvestRecoveryOrchestrator(db: fixture.db, root: engineRoot)
        await engineOrchestrator.recoverAndReconcile()
        #expect(try fixture.db.card(id: request.cardId)?.status == .running)
        #expect(try harvestCardEventsByRowID(fixture.db, cardID: request.cardId) == before)
        let execution = try await fixture.db.pool.read { database in
            try #require(try EngineExecutionRecord.fetchOne(database, key: request.executionId))
        }
        #expect(execution.redactedAt == nil)
        #expect((execution.terminalSubtype != nil) == terminal)
        await engineOrchestrator.shutdown()
    }
}

@Test func returnCardForReworkRejectsAcceptedAndFailedMissions() throws {
    for terminalStatus in [MissionStatus.accepted, .failed] {
        let db = try harvestDatabase()
        let camp = try db.ensureDefaultCamp()
        let ids = try db.createSingleCardMission(
            campName: camp.name,
            squadName: "远征队",
            goal: "完成并收营",
            cardTitle: "完成网页",
            cardDescription: "制作可运行页面",
            expectedOutput: "HTML 文件",
            assigneeId: nil,
            maxTurns: KernelDefaults.maxTurns,
            campId: camp.id
        )
        try db.transitionCard(
            id: ids.cardId,
            to: .running,
            eventKind: EventKind.cardStarted,
            payload: .object([:])
        )
        try db.completeCard(
            id: ids.cardId,
            runId: nil,
            handoff: completedHandoff(),
            durableArtifacts: []
        )
        try setMissionStatus(terminalStatus, missionId: ids.missionId, db: db)

        #expect(throws: MissionStateError.self) {
            try db.returnCardForRework(cardId: ids.cardId, feedback: "终局后不能退回")
        }
        #expect(try db.card(id: ids.cardId)?.status == .done)
        #expect(try db.mission(id: ids.missionId)?.status == terminalStatus)
    }
}

private struct P1F1ReportInjectedFailure: Error, Equatable {}

private final class P1F1ReportCheckpointFault: @unchecked Sendable {
    private let lock = NSLock()
    private let target: ManagedExpeditionReportCheckpointV1
    private var didThrow = false

    init(target: ManagedExpeditionReportCheckpointV1) {
        self.target = target
    }

    func callAsFunction(
        _ checkpoint: ManagedExpeditionReportCheckpointV1
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard checkpoint == target, !didThrow else { return }
        didThrow = true
        throw P1F1ReportInjectedFailure()
    }
}

private final class P1F1ReportRootWalkSwap: @unchecked Sendable {
    private let lock = NSLock()
    private let targetName: String
    private let originalURL: URL
    private let replacementURL: URL
    private let selectedURL: URL
    private var didSwap = false

    init(
        targetName: String,
        originalURL: URL,
        replacementURL: URL,
        selectedURL: URL
    ) {
        self.targetName = targetName
        self.originalURL = originalURL
        self.replacementURL = replacementURL
        self.selectedURL = selectedURL
    }

    func callAsFunction(_ component: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard component == targetName, !didSwap else { return }
        try FileManager.default.moveItem(at: selectedURL, to: originalURL)
        try FileManager.default.moveItem(at: replacementURL, to: selectedURL)
        didSwap = true
    }
}

private func p1f1ReportMission(
    database: AppDatabase
) throws -> (campId: String, missionId: String) {
    let camp = try database.ensureDefaultCamp()
    let ids = try database.createSingleCardMission(
        campName: camp.name,
        squadName: "report-owner",
        goal: "生成可恢复远征报告",
        cardTitle: "完成报告材料",
        cardDescription: "deterministic",
        expectedOutput: "markdown",
        assigneeId: nil,
        maxTurns: KernelDefaults.maxTurns,
        campId: camp.id
    )
    return (camp.id, ids.missionId)
}

private struct P1F1ReportEvidence {
    let expectedBytes: Data
    let expectedCursorBytes: Data
    let temporaryURL: URL
    let cursorURL: URL
    let finalURL: URL
}

private func p1f1ReportEvidence(
    database: AppDatabase,
    mission: (campId: String, missionId: String),
    root: URL
) throws -> P1F1ReportEvidence {
    let temporaryName = ".\(mission.missionId).report.tmp"
    let finalName = "\(mission.missionId).md"
    let input = try database.expeditionReportInput(
        missionId: mission.missionId
    )
    let expectedBytes = Data(ExpeditionReport.markdown(input).utf8)
    let cursor = ManagedExpeditionReportCursorV1(
        missionId: mission.missionId,
        campId: mission.campId,
        contentHash: CanonicalJSONV1.sha256Hex(expectedBytes),
        byteCount: expectedBytes.count,
        temporaryName: temporaryName,
        finalName: finalName
    )
    return P1F1ReportEvidence(
        expectedBytes: expectedBytes,
        expectedCursorBytes: try CanonicalJSONV1.encode(cursor),
        temporaryURL: root.appendingPathComponent(temporaryName),
        cursorURL: root.appendingPathComponent(
            ".\(mission.missionId).report.cursor.json"
        ),
        finalURL: root.appendingPathComponent(finalName)
    )
}

@Test func p1f1_060ManagedExpeditionReportIsOnlyWriterAndRegistryOwner() throws {
    let database = try harvestDatabase()
    let mission = try p1f1ReportMission(database: database)
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("reports")
    let store = ManagedExpeditionReportStore(
        database: database,
        reportStoreRoot: root
    )

    let first = try store.ensureReport(missionId: mission.missionId)
    let second = try store.ensureReport(missionId: mission.missionId)
    let registered = try store.reportURL(missionId: mission.missionId)
    let reportInput = try database.expeditionReportInput(
        missionId: mission.missionId
    )
    let expected = ExpeditionReport.markdown(reportInput)
    let rendered = try String(contentsOf: first, encoding: .utf8)

    #expect(first == second)
    #expect(first == registered)
    #expect(
        first.deletingLastPathComponent().standardizedFileURL.path
            == root.standardizedFileURL.path
    )
    #expect(FileManager.default.fileExists(atPath: first.path))
    #expect(rendered == expected)
    #expect(reportInput.camp.id == mission.campId)
}

@Test func p1f1_061ManagedReportCursorRecoversWithoutLostFile() throws {
    let checkpoints: [ManagedExpeditionReportCheckpointV1] = [
        .afterTemporaryFileSync,
        .afterCursorFileSync,
        .afterFinalRename,
        .afterReportDirectorySync,
    ]

    for (ordinal, checkpoint) in checkpoints.enumerated() {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("reports-\(ordinal)")
        let fault = P1F1ReportCheckpointFault(target: checkpoint)
        let failing = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root,
            checkpoint: { try fault($0) }
        )

        #expect(throws: P1F1ReportInjectedFailure.self) {
            _ = try failing.regenerateReport(missionId: mission.missionId)
        }

        let evidence = try p1f1ReportEvidence(
            database: database,
            mission: mission,
            root: root
        )
        switch checkpoint {
        case .afterTemporaryFileSync:
            #expect(FileManager.default.fileExists(
                atPath: evidence.temporaryURL.path
            ))
            #expect(!FileManager.default.fileExists(
                atPath: evidence.cursorURL.path
            ))
            #expect(!FileManager.default.fileExists(
                atPath: evidence.finalURL.path
            ))
        case .afterCursorFileSync:
            #expect(FileManager.default.fileExists(
                atPath: evidence.temporaryURL.path
            ))
            #expect(FileManager.default.fileExists(
                atPath: evidence.cursorURL.path
            ))
            #expect(!FileManager.default.fileExists(
                atPath: evidence.finalURL.path
            ))
        case .afterFinalRename, .afterReportDirectorySync:
            #expect(!FileManager.default.fileExists(
                atPath: evidence.temporaryURL.path
            ))
            #expect(FileManager.default.fileExists(
                atPath: evidence.cursorURL.path
            ))
            #expect(FileManager.default.fileExists(
                atPath: evidence.finalURL.path
            ))
        }
        let recovering = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root
        )
        try recovering.recoverPendingWrites()
        #expect(FileManager.default.fileExists(atPath: evidence.finalURL.path))
        #expect(!FileManager.default.fileExists(
            atPath: evidence.temporaryURL.path
        ))
        #expect(!FileManager.default.fileExists(atPath: evidence.cursorURL.path))
        #expect(try Data(contentsOf: evidence.finalURL) == evidence.expectedBytes)
        try recovering.recoverPendingWrites()
        #expect(try Data(contentsOf: evidence.finalURL) == evidence.expectedBytes)
        #expect(!FileManager.default.fileExists(
            atPath: evidence.temporaryURL.path
        ))
        #expect(!FileManager.default.fileExists(atPath: evidence.cursorURL.path))
        let registered = try recovering.reportURL(
            missionId: mission.missionId
        )
        #expect(
            registered.standardizedFileURL.path
                == evidence.finalURL.standardizedFileURL.path
        )
        let ensured = try recovering.ensureReport(
            missionId: mission.missionId
        )
        #expect(ensured == registered)
    }

    do {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("report-lookup-is-read-only")
        let fault = P1F1ReportCheckpointFault(
            target: .afterCursorFileSync
        )
        let failing = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root,
            checkpoint: { try fault($0) }
        )
        #expect(throws: P1F1ReportInjectedFailure.self) {
            _ = try failing.regenerateReport(missionId: mission.missionId)
        }

        let evidence = try p1f1ReportEvidence(
            database: database,
            mission: mission,
            root: root
        )
        let temporaryEvidence = try Data(contentsOf: evidence.temporaryURL)
        let cursorEvidence = try Data(contentsOf: evidence.cursorURL)
        #expect(temporaryEvidence == evidence.expectedBytes)
        #expect(cursorEvidence == evidence.expectedCursorBytes)
        let lookup = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root
        )

        #expect(throws: (any Error).self) {
            _ = try lookup.reportURL(missionId: mission.missionId)
        }
        #expect(FileManager.default.fileExists(
            atPath: evidence.temporaryURL.path
        ))
        #expect(FileManager.default.fileExists(atPath: evidence.cursorURL.path))
        #expect(!FileManager.default.fileExists(atPath: evidence.finalURL.path))
        if FileManager.default.fileExists(atPath: evidence.temporaryURL.path) {
            #expect(
                try Data(contentsOf: evidence.temporaryURL)
                    == temporaryEvidence
            )
        }
        if FileManager.default.fileExists(atPath: evidence.cursorURL.path) {
            #expect(try Data(contentsOf: evidence.cursorURL) == cursorEvidence)
        }
    }

    do {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("report-mismatch-evidence")
        let fault = P1F1ReportCheckpointFault(
            target: .afterCursorFileSync
        )
        let failing = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root,
            checkpoint: { try fault($0) }
        )
        #expect(throws: P1F1ReportInjectedFailure.self) {
            _ = try failing.regenerateReport(missionId: mission.missionId)
        }

        let evidence = try p1f1ReportEvidence(
            database: database,
            mission: mission,
            root: root
        )
        let temporaryEvidence = try Data(contentsOf: evidence.temporaryURL)
        let cursorEvidence = try Data(contentsOf: evidence.cursorURL)
        #expect(temporaryEvidence == evidence.expectedBytes)
        #expect(cursorEvidence == evidence.expectedCursorBytes)
        let finalEvidence = Data("mismatched-final-evidence".utf8)
        try finalEvidence.write(to: evidence.finalURL)
        let recovering = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root
        )

        #expect(throws: (any Error).self) {
            try recovering.recoverPendingWrites()
        }
        #expect(FileManager.default.fileExists(
            atPath: evidence.temporaryURL.path
        ))
        #expect(FileManager.default.fileExists(atPath: evidence.cursorURL.path))
        if FileManager.default.fileExists(atPath: evidence.temporaryURL.path) {
            #expect(
                try Data(contentsOf: evidence.temporaryURL)
                    == temporaryEvidence
            )
        }
        if FileManager.default.fileExists(atPath: evidence.cursorURL.path) {
            #expect(try Data(contentsOf: evidence.cursorURL) == cursorEvidence)
        }
        #expect(try Data(contentsOf: evidence.finalURL) == finalEvidence)
    }

    do {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let outside = container.appendingPathComponent("outside")
        let alias = container.appendingPathComponent("report-root-alias")
        try FileManager.default.createDirectory(
            at: outside,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: outside
        )
        let root = alias.appendingPathComponent("reports")
        let escapedRoot = outside.appendingPathComponent("reports")
        let store = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root
        )

        #expect(throws: (any Error).self) {
            _ = try store.ensureReport(missionId: mission.missionId)
        }
        #expect(!FileManager.default.fileExists(atPath: escapedRoot.path))
    }

    do {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let outside = container.appendingPathComponent("outside")
        let escapedRoot = outside.appendingPathComponent("reports")
        let alias = container.appendingPathComponent("existing-root-alias")
        try FileManager.default.createDirectory(
            at: escapedRoot,
            withIntermediateDirectories: true
        )
        let sentinel = escapedRoot.appendingPathComponent("sentinel.txt")
        let sentinelBytes = Data("preserve-existing-root-evidence".utf8)
        try sentinelBytes.write(to: sentinel)
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: outside
        )
        let root = alias.appendingPathComponent("reports")
        let escapedFinal = escapedRoot.appendingPathComponent(
            "\(mission.missionId).md"
        )
        let store = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root
        )

        #expect(throws: (any Error).self) {
            _ = try store.ensureReport(missionId: mission.missionId)
        }
        #expect(!FileManager.default.fileExists(atPath: escapedFinal.path))
        #expect(try Data(contentsOf: sentinel) == sentinelBytes)
    }

    do {
        var information = stat()
        #expect(lstat("/etc", &information) == 0)
        #expect(information.st_mode & S_IFMT == S_IFLNK)
        #expect(information.st_uid == 0)
        #expect(try FileManager.default.destinationOfSymbolicLink(
            atPath: "/etc"
        ) == "private/etc")

        let database = try harvestDatabase()
        let store = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: URL(fileURLWithPath: "/etc", isDirectory: true)
        )
        #expect(throws: (any Error).self) {
            try store.recoverPendingWrites()
        }
    }

    do {
        let database = try harvestDatabase()
        let mission = try p1f1ReportMission(database: database)
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let selectedName = "report-root-selected"
        let selected = container.appendingPathComponent(selectedName)
        let original = container.appendingPathComponent("original-snapshot")
        let replacement = container.appendingPathComponent("replacement")
        try FileManager.default.createDirectory(
            at: selected,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: replacement,
            withIntermediateDirectories: true
        )
        let sentinel = replacement.appendingPathComponent("sentinel.txt")
        let sentinelBytes = Data("preserve-identity-swap-evidence".utf8)
        try sentinelBytes.write(to: sentinel)
        let root = selected.appendingPathComponent("reports")
        let escapedFinal = root.appendingPathComponent(
            "\(mission.missionId).md"
        )
        let swap = P1F1ReportRootWalkSwap(
            targetName: selectedName,
            originalURL: original,
            replacementURL: replacement,
            selectedURL: selected
        )
        let store = ManagedExpeditionReportStore(
            database: database,
            reportStoreRoot: root,
            rootWalkCheckpoint: { try swap($0) }
        )

        #expect(throws: (any Error).self) {
            _ = try store.ensureReport(missionId: mission.missionId)
        }
        #expect(!FileManager.default.fileExists(atPath: escapedFinal.path))
        #expect(
            try Data(contentsOf: selected.appendingPathComponent(
                "sentinel.txt"
            )) == sentinelBytes
        )
    }
}
