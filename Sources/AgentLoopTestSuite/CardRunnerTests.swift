import Testing
import Foundation
import AgentLoopCore

@Test func runnerDrivesCardToDoneWithRunRecord() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try "内容".write(to: workspace.appendingPathComponent("out.md"), atomically: true, encoding: .utf8)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: nil,
        maxTurns: 10,
        workspacePath: workspace.path
    )

    let handoffInput: JSONValue = [
        "outcome": "ok",
        "summary": "s",
        "artifacts": [["relativePath": "out.md", "kind": "markdown", "label": "产出"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ]
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "t1", name: "complete_card", input: handoffInput)],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 100, outputTokens: 50)
        ),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))
    var sawFinished = false
    for try await event in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
        if case .finished(.completed) = event {
            sawFinished = true
        }
    }

    #expect(sawFinished)
    #expect(try db.card(id: ids.cardId)?.status == .done)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "completed")
    #expect(runs[0].tokensOut == 50)
    #expect(runs[0].endedAt != nil)
}

@Test func runnerCancellationLeavesCardReady() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 20, workspacePath: workspace.path
    )
    // Long script — 20 progress-note turns so it never finishes on its own
    let script: [TurnResult] = (0..<20).map { i in
        TurnResult(
            content: [.toolUse(id: "n\(i)", name: "add_progress_note", input: ["text": .string("step \(i)")])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 10, outputTokens: 5)
        )
    }
    let mock = MockProvider(script: script)
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))

    let consumerTask = Task {
        var count = 0
        for try await _ in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
            count += 1
            if count >= 2 { break }   // consume a couple events then stop iterating
        }
    }

    // Let it start, then cancel
    try await Task.sleep(for: .milliseconds(50))
    consumerTask.cancel()

    // Poll up to 2 seconds for card to land in .ready
    var finalStatus: CardStatus?
    for _ in 0..<40 {
        try await Task.sleep(for: .milliseconds(50))
        finalStatus = try db.card(id: ids.cardId)?.status
        if finalStatus == .ready { break }
    }

    #expect(finalStatus == .ready, "card should be .ready after cancellation, got \(String(describing: finalStatus))")

    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "canceled")
}

@Test func cancelDuringArmedTimeoutLeavesCardReady() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 20, workspacePath: workspace.path
    )
    let provider = RunnerHangingProvider()
    let runner = CardRunner(
        db: db,
        provider: provider,
        artifactStoreRoot: base.appendingPathComponent("store"),
        turnTimeout: .milliseconds(50)
    )

    let consumerTask = Task {
        do {
            for try await _ in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {}
        } catch is CancellationError {
        } catch {
            Issue.record("unexpected runner error: \(error)")
        }
    }

    await provider.waitUntilStarted()
    consumerTask.cancel()

    var finalStatus: CardStatus?
    for _ in 0..<40 {
        try await Task.sleep(for: .milliseconds(50))
        finalStatus = try db.card(id: ids.cardId)?.status
        if finalStatus == .ready { break }
    }

    #expect(finalStatus == .ready, "card should be .ready after cancellation, got \(String(describing: finalStatus))")

    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "canceled")
}

@Test func runnerTransportErrorSetsFailedAndBlocked() async throws {
    // Empty script → MockProvider throws malformedStream on first call
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10, workspacePath: workspace.path
    )
    let mock = MockProvider(script: [])  // exhausted immediately → malformedStream
    let runner = CardRunner(
        db: db,
        provider: mock,
        artifactStoreRoot: base.appendingPathComponent("store"),
        retryDelays: [.milliseconds(1), .milliseconds(1)]
    )

    var threw = false
    do {
        for try await _ in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {}
    } catch {
        threw = true
    }
    #expect(threw, "runner should rethrow the transport error")
    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "failed")
}

@Test func runnerBlocksCardWhenLoopBlocksItself() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: nil,
        maxTurns: 10,
        workspacePath: workspace.path
    )
    let mock = MockProvider(script: [
        TurnResult(content: [.text("done?")], stopReason: .endTurn),
        TurnResult(content: [.text("still done")], stopReason: .endTurn),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))
    var sawBlocked = false
    for try await event in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
        if case .finished(.blocked) = event {
            sawBlocked = true
        }
    }

    #expect(sawBlocked)
    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "blocked")
}

private actor RunnerHangingProvider: LLMProvider {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(3600))
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func markStarted() {
        started = true
        let current = waiters
        waiters.removeAll()
        for waiter in current {
            waiter.resume()
        }
    }
}
