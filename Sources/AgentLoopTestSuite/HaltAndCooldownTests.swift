import Testing
import Foundation
import GRDB
import AgentLoopCore

// M7-D5/D8：紧急收哨 + 429 全局冷却

private func haltTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func haltCompanion(_ db: AppDatabase) throws -> CompanionRecord {
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    return companion
}

private func completeScript() -> [TurnResult] {
    [TurnResult(content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
        "outcome": "o", "summary": "s", "noArtifactReason": "无",
        "verification": [["method": "自查", "passed": true, "note": "ok"]],
        "risks": [],
    ])], stopReason: .toolUse)]
}

private func waitForCard(
    _ db: AppDatabase, _ cardId: String, status: CardStatus, timeout: Duration = .seconds(5)
) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if try db.card(id: cardId)?.status == status { return true }
        try await Task.sleep(for: .milliseconds(30))
    }
    return try db.card(id: cardId)?.status == status
}

private func globalEvents(_ db: AppDatabase, kind: String) throws -> Int {
    try db.pool.read { database in
        try EventRecord.filter(Column("kind") == kind).fetchCount(database)
    }
}

/// 立抛 429 的替身：AgentLoop 层 429 不重试（provider 层已重试过），错误直达 Orchestrator
private struct RateLimitedProvider: LLMProvider {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                    toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.http(status: 429, body: "rate limited"))
        }
    }
}

@Test func emergencyStopHaltsDispatchAndResumeContinues() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in MockProvider(script: completeScript()) },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    // 收哨后 reconcile 不派发
    await orchestrator.emergencyStop()
    await orchestrator.reconcile()
    try await Task.sleep(for: .milliseconds(150))
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(try globalEvents(db, kind: "camp_halted") == 1)
    let halted = await orchestrator.isHalted
    #expect(halted)

    // 解除收哨 → 立即派发 → 完成
    await orchestrator.resume()
    let done = try await waitForCard(db, ids.cardId, status: .done)
    #expect(done)
    #expect(try globalEvents(db, kind: "camp_resumed") == 1)
}

@Test func rateLimitTriggersGlobalCooldownThenRecovers() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let first = try db.createSingleCardMission(
        campName: "c", squadName: "s1", goal: "g",
        cardTitle: "t1", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    // 首个 provider 抛 429，之后的派发换成正常 Mock（按调用次数切换）
    let counter = CallCounter()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in
            if counter.next() == 0 {
                return RateLimitedProvider()
            }
            return MockProvider(script: completeScript())
        },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        rateLimitCooldown: .milliseconds(400)
    )

    await orchestrator.reconcile()
    // 429 → 卡片按错误路径 blocked + 冷却事件
    let blocked = try await waitForCard(db, first.cardId, status: .blocked)
    #expect(blocked)
    #expect(try globalEvents(db, kind: "rate_limit_cooldown") == 1)

    // 冷却期内：第二个行动不派发
    let second = try db.createSingleCardMission(
        campName: "c", squadName: "s2", goal: "g",
        cardTitle: "t2", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    await orchestrator.reconcile()
    try await Task.sleep(for: .milliseconds(100))
    #expect(try db.runs(cardId: second.cardId).isEmpty)

    // 冷却过点：恢复派发
    try await Task.sleep(for: .milliseconds(400))
    await orchestrator.reconcile()
    let done = try await waitForCard(db, second.cardId, status: .done)
    #expect(done)
}

/// 线程安全的调用计数器（makeProvider 是 @Sendable 闭包）
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = count
        count += 1
        return current
    }
}
