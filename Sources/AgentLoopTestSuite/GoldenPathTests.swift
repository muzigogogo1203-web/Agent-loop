import Testing
import Foundation
import GRDB
import AgentLoopCore

private final class ModelCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var models: [String] = []

    func append(_ model: String) {
        lock.withLock { models.append(model) }
    }

    var values: [String] {
        lock.withLock { models }
    }
}

private func goldenTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func goldenEvents(_ db: AppDatabase, missionId: String) throws -> [EventRecord] {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }
}

private func goldenProposalInput(cards: [JSONValue]) -> JSONValue {
    ["goalRefined": "两卡依赖行动", "cards": .array(cards)]
}

private func goldenCardDraftInput(
    title: String,
    description: String,
    expectedOutput: String,
    assignee: Int,
    dependsOn: [Int] = []
) -> JSONValue {
    [
        "title": .string(title),
        "description": .string(description),
        "expectedOutput": .string(expectedOutput),
        "assignee": .number(Double(assignee)),
        "dependsOn": .array(dependsOn.map { .number(Double($0)) }),
    ]
}

@Test func twoCardMissionEndToEndColdStart() async throws {
    let db = try goldenTempDB()
    let camp = try db.ensureDefaultCamp()
    let companionA = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理资料", model: "model-a", campId: camp.id)
    let companionB = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "写结论", model: "model-b", campId: camp.id)
    try db.saveCompanion(companionA)
    try db.saveCompanion(companionB)

    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let artifactRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)

    let plannerProvider = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "plan", name: "propose_plan", input: goldenProposalInput(cards: [
                goldenCardDraftInput(title: "整理事实", description: "写 facts.md", expectedOutput: "facts.md", assignee: 0),
                goldenCardDraftInput(title: "写结论", description: "基于 facts.md 写结论", expectedOutput: "文字结论", assignee: 1, dependsOn: [0]),
            ]))],
            stopReason: .toolUse
        ),
    ])
    let providerA = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "write", name: "write_file", input: ["path": "facts.md", "content": "A facts"])],
            stopReason: .toolUse
        ),
        TurnResult(
            content: [.toolUse(id: "complete-a", name: "complete_card", input: [
                "outcome": "facts ready",
                "summary": "A 产出了 facts.md",
                "artifacts": [[
                    "relativePath": "facts.md",
                    "kind": "markdown",
                    "label": "事实文件",
                ]],
                "verification": [["method": "read_file", "passed": true, "note": "facts.md 存在"]],
                "risks": [],
                "next": "请 B 基于 facts.md 总结",
            ])],
            stopReason: .toolUse
        ),
    ])
    let providerB = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "complete-b", name: "complete_card", input: [
                "outcome": "final ready",
                "summary": "B 已引用 A 的 facts.md 结论",
                "artifacts": [],
                "noArtifactReason": "最终结论写在交接包中",
                "verification": [["method": "检查上游摘要", "passed": true, "note": "已看到 facts.md"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let modelCalls = ModelCallLog()
    let orch = Orchestrator(
        db: db,
        makeProvider: { model in
            modelCalls.append(model)
            switch model {
            case "planner-model": return plannerProvider
            case "model-a": return providerA
            case "model-b": return providerB
            default: return MockProvider(script: [])
            }
        },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )

    let missionId = try await orch.startMission(
        goal: "两卡依赖行动",
        companionIds: [companionA.id, companionB.id],
        workspacePath: workspace.path,
        plannerModel: "planner-model"
    )
    await orch.waitUntilIdle()

    let mission = try #require(try db.mission(id: missionId))
    #expect(mission.status == .delivering)
    let events = try goldenEvents(db, missionId: missionId)
    let transitions = events
        .filter { $0.kind == "mission_status_changed" }
        .map(\.payloadJson)
        .joined(separator: "\n")
    #expect(transitions.contains("planning"))
    #expect(transitions.contains("executing"))
    #expect(transitions.contains("delivering"))

    let bHistory = await providerB.recordedHistories
    guard case .text(let bFirstUser) = bHistory.first?.first?.content.first else {
        Issue.record("expected B first user text")
        return
    }
    #expect(bFirstUser.contains("A 产出了 facts.md"))
    #expect(bFirstUser.contains("facts.md"))

    let artifacts = try db.missionArtifacts(missionId: missionId)
    #expect(artifacts.count == 1)
    #expect(FileManager.default.fileExists(atPath: try #require(artifacts.first?.path)))

    try await orch.closeout(missionId, distillModel: "distill-model")
    #expect(try db.mission(id: missionId)?.status == .accepted)
    #expect(modelCalls.values.contains("model-a"))
    #expect(modelCalls.values.contains("model-b"))
    await orch.shutdown()
}

@Test func twoCardMissionWithMidwayAskUser() async throws {
    let db = try goldenTempDB()
    let camp = try db.ensureDefaultCamp()
    let companionA = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理资料", model: "model-a", campId: camp.id)
    let companionB = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "写结论", model: "model-b", campId: camp.id)
    try db.saveCompanion(companionA)
    try db.saveCompanion(companionB)

    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let artifactRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)

    let plannerProvider = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "plan", name: "propose_plan", input: goldenProposalInput(cards: [
                goldenCardDraftInput(title: "整理事实", description: "中途问用户", expectedOutput: "事实摘要", assignee: 0),
                goldenCardDraftInput(title: "写结论", description: "基于事实摘要写结论", expectedOutput: "文字结论", assignee: 1, dependsOn: [0]),
            ]))],
            stopReason: .toolUse
        ),
    ])
    let providerA = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "ask", name: "ask_user", input: [
                "kind": "choice",
                "prompt": "请选择事实整理路线",
                "options": ["fact-route-alpha-unique", "fact-route-beta-unique"],
            ])],
            stopReason: .toolUse
        ),
        TurnResult(
            content: [.toolUse(id: "complete-a", name: "complete_card", input: [
                "outcome": "facts ready",
                "summary": "用户选择 fact-route-beta-unique，A 已整理事实摘要",
                "artifacts": [],
                "noArtifactReason": "事实摘要写在交接包中",
                "verification": [["method": "检查用户回答", "passed": true, "note": "已按 fact-route-beta-unique 整理"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let providerB = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "complete-b", name: "complete_card", input: [
                "outcome": "final ready",
                "summary": "B 已基于 A 的事实摘要交付结论",
                "artifacts": [],
                "noArtifactReason": "最终结论写在交接包中",
                "verification": [["method": "检查上游摘要", "passed": true, "note": "已看到 beta 路线摘要"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let orch = Orchestrator(
        db: db,
        makeProvider: { model in
            switch model {
            case "planner-model": return plannerProvider
            case "model-a": return providerA
            case "model-b": return providerB
            default: return MockProvider(script: [])
            }
        },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )

    let missionId = try await orch.startMission(
        goal: "两卡中途问答行动",
        companionIds: [companionA.id, companionB.id],
        workspacePath: workspace.path,
        plannerModel: "planner-model"
    )
    await orch.waitUntilIdle()
    let request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":1}"#)
    await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done])
    #expect(try db.mission(id: missionId)?.status == .delivering)

    let aHistory = await providerA.recordedHistories
    let aResumed = try #require(aHistory.indices.contains(1) ? aHistory[1].first : nil)
    guard case .text(let aUser) = aResumed.content.first else {
        Issue.record("expected A resumed user text")
        return
    }
    #expect(aUser.contains("请选择事实整理路线"))
    #expect(aUser.contains("fact-route-beta-unique"))

    let bHistory = await providerB.recordedHistories
    let bFirst = try #require(bHistory.first?.first)
    guard case .text(let bUser) = bFirst.content.first else {
        Issue.record("expected B first user text")
        return
    }
    #expect(bUser.contains("用户选择 fact-route-beta-unique"))
    #expect(!bUser.contains("# 此前你向用户提问的记录"))
    #expect(!bUser.contains("请选择事实整理路线"))
    await orch.shutdown()
}
