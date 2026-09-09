import Testing
import Foundation
import AgentLoopCore

private actor BoardTerminalIntentRecorder: EngineBoardTerminalSink {
    private var storage: [EngineBoardTerminalIntentV1] = []

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        storage.append(intent)
    }

    func snapshot() -> [EngineBoardTerminalIntentV1] { storage }
}

private actor BoardProgressPayloadRecorder: EngineProgressSink {
    private var storage: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        storage.append(payload)
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] { storage }
}

private struct BoardFixture {
    let tools: BoardTools
    let terminal: BoardTerminalIntentRecorder
    let progress: BoardProgressPayloadRecorder
}

private func makeBoardFixture() -> BoardFixture {
    let terminal = BoardTerminalIntentRecorder()
    let progress = BoardProgressPayloadRecorder()
    return BoardFixture(
        tools: BoardTools(
            boardTerminalSink: terminal,
            progressSink: progress
        ),
        terminal: terminal,
        progress: progress
    )
}

@Test func completeEmitsTypedHandoffWithoutFilesystemAuthority() async throws {
    let fixture = makeBoardFixture()
    let output = try await fixture.tools.complete(input: [
        "outcome": "完成",
        "summary": "已整理",
        "artifacts": [["relativePath": "清单.md", "kind": "markdown", "label": "装备清单"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ])

    guard case .completed = output else {
        Issue.record("should complete")
        return
    }
    let intents = await fixture.terminal.snapshot()
    #expect(intents.count == 1)
    guard case let .completed(handoff) = try #require(intents.first) else {
        Issue.record("expected one completed intent")
        return
    }
    #expect(handoff.artifacts.map(\.relativePath) == ["清单.md"])
    #expect(await fixture.progress.snapshot().isEmpty)
}

@Test func repeatedCompletionForwardsTypedIntentsWithoutVersionAuthority()
    async throws
{
    let fixture = makeBoardFixture()
    let input: JSONValue = [
        "outcome": "完成",
        "summary": "已交付",
        "artifacts": [["relativePath": "交付.md", "kind": "markdown", "label": "行动交付"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ]
    guard case .completed = try await fixture.tools.complete(input: input) else {
        Issue.record("first completion should succeed")
        return
    }
    guard case .completed = try await fixture.tools.complete(input: input) else {
        Issue.record("second typed intent should succeed")
        return
    }
    #expect(await fixture.terminal.snapshot().count == 2)
}

@Test func invalidArtifactDeclarationDoesNotReachSink() async throws {
    let fixture = makeBoardFixture()
    let output = try await fixture.tools.complete(input: [
        "outcome": "完成",
        "summary": "x",
        "artifacts": [["relativePath": "../越界.md", "kind": "md", "label": "l"]],
        "verification": [],
        "risks": [],
    ])
    guard case .error(let message) = output else {
        Issue.record("should error")
        return
    }
    #expect(message.contains("relativePath") || message.contains("路径"))
    #expect(await fixture.terminal.snapshot().isEmpty)
}

@Test func invalidHandoffDoesNotReachSink() async throws {
    let fixture = makeBoardFixture()
    let output = try await fixture.tools.complete(input: [
        "outcome": "",
        "summary": "",
        "artifacts": [],
        "verification": [],
        "risks": [],
    ])
    guard case .error = output else {
        Issue.record("should error")
        return
    }
    #expect(await fixture.terminal.snapshot().isEmpty)
}

@Test func blockEmitsTypedReason() async throws {
    let fixture = makeBoardFixture()
    let output = try await fixture.tools.block(
        input: ["reason": "needs_human_input", "detail": "缺预算数字"]
    )
    guard case .blocked = output else { return }
    let intents = await fixture.terminal.snapshot()
    guard case let .blocked(reason, detail) = try #require(intents.first) else {
        Issue.record("expected blocked intent")
        return
    }
    #expect(reason == "needs_human_input")
    #expect(detail == "缺预算数字")
}

@Test func progressNoteEmitsTypedPayload() async throws {
    let fixture = makeBoardFixture()
    _ = try await fixture.tools.progressNote(input: ["text": "整理到第 8 件"])
    #expect(
        await fixture.progress.snapshot()
            == [.progress(message: "整理到第 8 件")]
    )
}

@Test func p1f1_059RawStringDurablePathCompletionAPIRemoved() async throws {
    let fixture = makeBoardFixture()
    let output = try await fixture.tools.complete(input: [
        "outcome": "完成",
        "summary": "产物必须交给 terminal sink 和 ArtifactStager",
        "artifacts": [[
            "relativePath": "typed-only.md",
            "kind": "markdown",
            "label": "typed-only",
        ]],
        "verification": [[
            "method": "readback",
            "passed": true,
            "note": "ok",
        ]],
        "risks": [],
    ])
    guard case let .completed(handoff) = output else {
        Issue.record("typed Board completion must reach the terminal sink")
        return
    }
    #expect(handoff.artifacts.map(\.relativePath) == ["typed-only.md"])
    let intents = await fixture.terminal.snapshot()
    #expect(intents.count == 1)
    guard case let .completed(recorded) = try #require(intents.first) else {
        Issue.record("terminal sink must receive the same typed handoff")
        return
    }
    #expect(recorded == handoff)
}

private final class P1F1D077LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private actor P1F1D077EventRecorder {
    private var storage: [EngineExecutionEvent] = []

    func append(_ event: EngineExecutionEvent) {
        storage.append(event)
    }

    func snapshot() -> [EngineExecutionEvent] { storage }
}

private actor P1F1D077ProgressRecorder: EngineProgressSink {
    private var storage: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        storage.append(payload)
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] { storage }
}

@Test func p1f1_077BoardToolsOnlyEmitTerminalProposal() async throws {
    let executionId = "00000000-0000-4000-8000-000000000077"
    let router = EngineEventRouterV1(
        executionId: executionId,
        runId: "10000000-0000-4000-8000-000000000077",
        cardId: "20000000-0000-4000-8000-000000000077",
        nextSequence: 7,
        initialUsage: .zero
    )
    let manifestCalls = P1F1D077LockedCounter()
    let commits = P1F1D077EventRecorder()
    let progress = P1F1D077ProgressRecorder()
    let sink = EngineBoardTerminalRouterSinkV1(
        router: router,
        manifestResolver: { _ in
            manifestCalls.increment()
            return []
        },
        commit: { event in
            await commits.append(event)
        }
    )
    let tools = BoardTools(
        boardTerminalSink: sink,
        progressSink: progress
    )
    let input: JSONValue = [
        "outcome": "implemented",
        "summary": "Board emitted one typed proposal",
        "artifacts": [],
        "noArtifactReason": "This conformance case has no file artifact.",
        "verification": [[
            "method": "router receipt",
            "passed": true,
            "note": "one terminal intent",
        ]],
        "risks": [],
    ]

    let outcome = try await tools.complete(input: input)

    guard case let .completed(handoff) = outcome else {
        Issue.record("complete_card must return its accepted handoff")
        return
    }
    #expect(handoff.outcome == "implemented")
    #expect(manifestCalls.value == 1)
    #expect(await progress.snapshot().isEmpty)

    let events = await commits.snapshot()
    #expect(events.count == 1)
    let event = try #require(events.first)
    #expect(event.executionId == executionId)
    #expect(event.sequence == 7)
    guard case let .terminal(proposal) = event.payload else {
        Issue.record("Board intent must reach the shared terminal router")
        return
    }
    #expect(proposal.terminalKind == .completed)
    #expect(proposal.terminalSubtype == nil)
    #expect(proposal.artifacts.isEmpty)
    #expect(proposal.payload == .completed(handoff: handoff))
    #expect(
        try await router.state()
            == .accepted(
                sequence: 7,
                terminalIdempotencyKey:
                    "engine.terminal.v1:\(executionId):7"
            )
    )
}
