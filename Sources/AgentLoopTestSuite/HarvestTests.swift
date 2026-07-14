import Testing
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
    try db.completeCard(
        id: ids.cardId,
        runId: nil,
        handoff: completedHandoff(artifact: declaration),
        durableArtifacts: [(declaration, "/tmp/agentloop-harvest/index.html")]
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
