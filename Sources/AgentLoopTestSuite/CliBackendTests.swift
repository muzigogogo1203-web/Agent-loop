import Foundation
import Testing
import AgentLoopCore

@Test func cliBackendPolicyPinsBannedFlags() {
    #expect(CliBackendPolicy.bannedFlags.contains("--dangerously-bypass-approvals-and-sandbox"))
    #expect(CliBackendPolicy.bannedFlags.contains("--dangerously-skip-permissions"))
    #expect(CliBackendPolicy.bannedFlags.contains("--yolo"))
    #expect(CliBackendPolicy.bannedFlags.contains("bypassPermissions"))
}

@Test func cliBackendPolicyMapsAutonomyWithoutEscalatingFreeTier() throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let socket = base.appendingPathComponent("b.sock")
    let codexCareful = try CliBackendPolicy.commandSpec(
        kind: .cliCodex,
        commandOverride: "/tmp/fake-codex",
        workspace: base,
        prompt: "p",
        bridgeExecutablePath: "/tmp/bridge",
        socketURL: socket,
        token: "token",
        cardId: "card",
        toolNames: ["complete_card", "block_card"],
        autonomy: .careful
    )
    let codexStandard = try CliBackendPolicy.commandSpec(
        kind: .cliCodex,
        commandOverride: "/tmp/fake-codex",
        workspace: base,
        prompt: "p",
        bridgeExecutablePath: "/tmp/bridge",
        socketURL: socket,
        token: "token",
        cardId: "card",
        toolNames: ["complete_card", "block_card"],
        autonomy: .standard
    )
    let codexFree = try CliBackendPolicy.commandSpec(
        kind: .cliCodex,
        commandOverride: "/tmp/fake-codex",
        workspace: base,
        prompt: "p",
        bridgeExecutablePath: "/tmp/bridge",
        socketURL: socket,
        token: "token",
        cardId: "card",
        toolNames: ["complete_card", "block_card"],
        autonomy: .free
    )

    #expect(codexCareful.arguments.contains("read-only"))
    #expect(codexStandard.arguments.contains("workspace-write"))
    #expect(codexFree.arguments.contains("workspace-write"))
    #expect(!codexFree.arguments.contains("danger-full-access"))
    #expect(codexCareful.arguments.contains("-m"))
    #expect(codexCareful.arguments.contains { $0.contains("model_reasoning_effort") })

    let claudeCareful = try CliBackendPolicy.commandSpec(
        kind: .cliClaude,
        commandOverride: "/tmp/fake-claude",
        workspace: base,
        prompt: "p",
        bridgeExecutablePath: "/tmp/bridge",
        socketURL: socket,
        token: "token",
        cardId: "card",
        toolNames: ["complete_card", "block_card"],
        autonomy: .careful
    )
    let claudeFree = try CliBackendPolicy.commandSpec(
        kind: .cliClaude,
        commandOverride: "/tmp/fake-claude",
        workspace: base,
        prompt: "p",
        bridgeExecutablePath: "/tmp/bridge",
        socketURL: socket,
        token: "token",
        cardId: "card",
        toolNames: ["complete_card", "block_card"],
        autonomy: .free
    )
    #expect(claudeCareful.arguments.contains("plan"))
    #expect(claudeFree.arguments.contains("acceptEdits"))
    #expect(!claudeFree.arguments.contains("bypassPermissions"))

    for url in claudeCareful.cleanupURLs + claudeFree.cleanupURLs {
        try? FileManager.default.removeItem(at: url)
    }
}

@Test func cliBackendPolicyRejectsBannedArguments() throws {
    #expect(throws: CliProcessBackendError.bannedFlag("--yolo")) {
        try CliBackendPolicy.assertNoBannedFlags(CliCommandSpec(command: "codex", arguments: ["exec", "--yolo"]))
    }
    #expect(throws: CliProcessBackendError.bannedFlag("bypassPermissions")) {
        try CliBackendPolicy.assertNoBannedFlags(CliCommandSpec(command: "claude", arguments: ["--permission-mode", "bypassPermissions"]))
    }
}

@Test func cliOutputParserExtractsTextAndUsageFromJsonl() {
    let events = CliOutputParser.events(from: #"{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}],"usage":{"input_tokens":3,"output_tokens":5,"cache_read_input_tokens":2}}}"#)
    #expect(events.contains { if case .textDelta("hello") = $0 { return true }; return false })
    #expect(events.contains {
        if case .turnEnded(let usage) = $0 {
            return usage.inputTokens == 3 && usage.outputTokens == 5 && usage.cacheReadTokens == 2
        }
        return false
    })
}

@Test func cliProcessBackendBlocksWhenCliExitsWithoutBoardTerminator() async throws {
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliBackendHarness()
    let script = try harness.fakeScript("""
    #!/bin/bash
    printf '%s\\n' '{"type":"assistant","text":"fake progress","usage":{"input_tokens":7,"output_tokens":9}}'
    printf '%s\\n' 'diagnostic tail' >&2
    exit 7
    """)
    let backend = CliProcessBackend(
        db: harness.db,
        artifactStoreRoot: harness.artifacts,
        profileKind: .cliCodex,
        commandOverride: script.path,
        bridgeExecutablePath: "/bin/echo",
        timeout: .seconds(5),
        socketDirectory: harness.sockets
    )
    var sawText = false
    var sawBlocked = false
    for try await event in try backend.run(context: harness.context()) {
        if case .textDelta(let text) = event, text.contains("fake progress") {
            sawText = true
        }
        if case .finished(.blocked(let reason, let detail)) = event {
            sawBlocked = reason == "tool_failure" && detail.contains("退出码 7") && detail.contains("diagnostic tail")
        }
    }

    #expect(sawText)
    #expect(sawBlocked)
    #expect(try harness.db.card(id: harness.cardId)?.status == .blocked)
    let run = try #require(try harness.db.runs(cardId: harness.cardId).first)
    #expect(run.outcome == "blocked")
    #expect(run.tokensIn == 7)
    #expect(run.tokensOut == 9)
}

@Test func cliProcessBackendTimeoutBlocksCard() async throws {
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliBackendHarness()
    let script = try harness.fakeScript("""
    #!/bin/bash
    sleep 20
    """)
    let backend = CliProcessBackend(
        db: harness.db,
        artifactStoreRoot: harness.artifacts,
        profileKind: .cliCodex,
        commandOverride: script.path,
        bridgeExecutablePath: "/bin/echo",
        timeout: .milliseconds(50),
        socketDirectory: harness.sockets
    )
    var blockedDetail = ""
    for try await event in try backend.run(context: harness.context()) {
        if case .finished(.blocked(_, let detail)) = event {
            blockedDetail = detail
        }
    }
    #expect(blockedDetail.contains("超过"))
    #expect(try harness.db.card(id: harness.cardId)?.status == .blocked)
}

@Test func cliProcessBackendCancellationReturnsCardToReady() async throws {
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliBackendHarness()
    let script = try harness.fakeScript("""
    #!/bin/bash
    sleep 20
    """)
    let backend = CliProcessBackend(
        db: harness.db,
        artifactStoreRoot: harness.artifacts,
        profileKind: .cliCodex,
        commandOverride: script.path,
        bridgeExecutablePath: "/bin/echo",
        timeout: .seconds(30),
        socketDirectory: harness.sockets
    )
    let task = Task {
        for try await _ in try backend.run(context: harness.context()) {}
    }
    for _ in 0..<40 {
        if try harness.db.card(id: harness.cardId)?.status == .running { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    task.cancel()
    _ = await task.result
    var status: CardStatus?
    for _ in 0..<40 {
        status = try harness.db.card(id: harness.cardId)?.status
        if status == .ready { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(status == .ready)
    let run = try #require(try harness.db.runs(cardId: harness.cardId).first)
    #expect(run.outcome == "canceled")
}

@Test func cliBackendLiveSpikeRunsOnlyWhenEnabled() async throws {
    guard ProcessInfo.processInfo.environment["AGENTLOOP_CLI_SPIKE"] == "1" else { return }
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliBackendHarness()
    let backend = CliProcessBackend(
        db: harness.db,
        artifactStoreRoot: harness.artifacts,
        profileKind: .cliCodex,
        timeout: .seconds(120),
        socketDirectory: harness.sockets
    )
    for try await _ in try backend.run(context: harness.context(rolePrompt: "只调用 ranchboard.block_card，reason=other，detail=spike-ok。")) {}
    #expect(try harness.db.card(id: harness.cardId)?.status == .blocked)
}

private struct CliBackendHarness {
    let base: URL
    let workspace: URL
    let artifacts: URL
    let sockets: URL
    let db: AppDatabase
    let cardId: String

    init() throws {
        base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
            .appendingPathComponent("t")
            .appendingPathComponent("c\(UUID().uuidString.prefix(8))")
        workspace = base.appendingPathComponent("ws")
        artifacts = base.appendingPathComponent("artifacts")
        sockets = base.appendingPathComponent("s")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sockets, withIntermediateDirectories: true)
        db = try AppDatabase(path: base.appendingPathComponent("test.sqlite").path)
        let ids = try db.createSingleCardMission(
            campName: "c",
            squadName: "s",
            goal: "g",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            assigneeId: nil,
            maxTurns: 5,
            workspacePath: workspace.path
        )
        cardId = ids.cardId
    }

    func fakeScript(_ body: String) throws -> URL {
        let url = base.appendingPathComponent("fake-\(UUID().uuidString).sh")
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func context(rolePrompt: String = "执行") -> CardExecutionContext {
        CardExecutionContext(
            cardId: cardId,
            companionName: "测试牛",
            rolePrompt: rolePrompt,
            toolAccess: .full,
            autonomy: .standard
        )
    }
}
