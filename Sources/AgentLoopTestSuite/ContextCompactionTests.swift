import Testing
import Foundation
import AgentLoopCore

// MARK: - 切点选择（纯逻辑）

@Test func cutIndexLandsOnAssistantBoundary() {
    // [user, a, u, a, u, a, u, a, u, a, u] = 11 条；keep=6 → cut 起点 5，若非 assistant 则前进
    var history: [APIMessage] = [.user("首条")]
    for index in 0..<5 {
        history.append(.assistant([.text("a\(index)")]))
        history.append(.user(toolResults: [.toolResult(toolUseId: "t\(index)", content: "r", isError: false)]))
    }
    let cut = AgentLoop.compactionCutIndex(history: history)
    let cutIndex = try! #require(cut)
    #expect(history[cutIndex].role == .assistant) // 后缀从 assistant 起，工具配对不被切断
    #expect(history.count - cutIndex <= KernelDefaults.compactionKeepRecentMessages + 1)
}

@Test func cutIndexNilWhenHistoryShort() {
    var history: [APIMessage] = [.user("首条")]
    for index in 0..<3 {
        history.append(.assistant([.text("a\(index)")]))
        history.append(.user("u\(index)"))
    }
    #expect(AgentLoop.compactionCutIndex(history: history) == nil)
}

// MARK: - 压缩重建（结构与内容）

@Test func compactKeepsFirstMessageAndSuffixPairs() async throws {
    var history: [APIMessage] = [.user("上下文包首条")]
    for index in 0..<6 {
        history.append(.assistant([.toolUse(id: "tu\(index)", name: "write_file", input: ["path": "a.md"])]))
        history.append(.user(toolResults: [.toolResult(toolUseId: "tu\(index)", content: "写入结果 \(index)", isError: false)]))
    }
    let mock = MockProvider(script: [
        TurnResult(content: [.text("- 已写 a.md 六次\n- 无未决问题")], stopReason: .endTurn),
    ])
    let compacted = try #require(await AgentLoop.compact(history: history, provider: mock))

    // 首条 user 消息逐字节保留（缓存纪律）
    #expect(compacted[0] == history[0])
    // 摘要 assistant + 桥接 user
    guard case .text(let summaryText) = compacted[1].content[0] else {
        Issue.record("expected summary text"); return
    }
    #expect(compacted[1].role == .assistant)
    #expect(summaryText.contains("此前进展摘要"))
    #expect(summaryText.contains("已写 a.md"))
    #expect(compacted[2].role == .user)
    // 后缀第一条是 assistant（tool_use），其 tool_result 紧随其后——配对完整
    #expect(compacted[3].role == .assistant)
    if case .toolUse(let id, _, _) = compacted[3].content[0],
       case .toolResult(let resultId, _, _) = compacted[4].content[0] {
        #expect(id == resultId)
    } else {
        Issue.record("expected paired tool_use/tool_result at suffix start")
    }
    #expect(compacted.count < history.count)

    // 摘要调用是无工具单轮
    #expect(await mock.recordedToolChoices == [.auto])
    let summarySystem = await mock.recordedSystems[0]
    #expect(summarySystem.contains("压缩员"))
}

@Test func compactSkipsWhenSummaryFailsOrEmpty() async throws {
    var history: [APIMessage] = [.user("首条")]
    for index in 0..<6 {
        history.append(.assistant([.text("a\(index)")]))
        history.append(.user("u\(index)"))
    }
    // 摘要调用失败（脚本耗尽）→ 跳过压缩
    #expect(await AgentLoop.compact(history: history, provider: MockProvider(script: [])) == nil)
    // 摘要为空 → 跳过压缩
    let empty = MockProvider(script: [TurnResult(content: [.text("  ")], stopReason: .endTurn)])
    #expect(await AgentLoop.compact(history: history, provider: empty) == nil)
}

// MARK: - 循环内触发（端到端）

private struct CompactionEchoHandler: ToolHandler {
    func execute(input: JSONValue) async -> ToolOutcome {
        .result("echo ok")
    }
}

private struct CompactionCompleteHandler: ToolHandler {
    func execute(input: JSONValue) async -> ToolOutcome {
        .completed(HandoffPayload(
            outcome: "完成", summary: "s", artifacts: [], noArtifactReason: "无",
            verification: [], risks: []))
    }
}

@Test func loopCompactsAfterThresholdAndContinues() async throws {
    let echoTool = ToolDef(
        name: "echo", description: "回声",
        inputSchema: ["type": "object", "properties": .object([:]), "additionalProperties": false])
    let executor = ToolExecutor(handlers: [
        "echo": CompactionEchoHandler(),
        "complete_card": CompactionCompleteHandler(),
    ])
    let packet = ContextPacket(
        companionName: "甲", rolePrompt: "r", cardTitle: "长任务", cardDescription: "d",
        expectedOutput: "o", workspacePath: nil, upstreamHandoffs: [])

    func echoTurn(_ index: Int, inputTokens: Int) -> TurnResult {
        TurnResult(
            content: [.toolUse(id: "tu\(index)", name: "echo", input: ["text": "x"])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: inputTokens, outputTokens: 10))
    }
    // 5 轮工具（第 5 轮 usage 冲破阈值；历史需超过 keep+3 条才可压）→ 摘要轮 → 收尾轮
    let mock = MockProvider(script: [
        echoTurn(0, inputTokens: 1000),
        echoTurn(1, inputTokens: 2000),
        echoTurn(2, inputTokens: 3000),
        echoTurn(3, inputTokens: 4000),
        echoTurn(4, inputTokens: KernelDefaults.contextCompactionThreshold + 1),
        TurnResult(content: [.text("- 已回声五次")], stopReason: .endTurn), // 摘要调用
        TurnResult(
            content: [.toolUse(id: "done", name: "complete_card", input: [:])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 500, outputTokens: 10)),
    ])
    let loop = AgentLoop(
        provider: mock, executor: executor, packet: packet,
        tools: [echoTool, ToolDef.completeCard],
        maxTurns: 10, tokenBudget: 10_000_000,
        maxTokensPerTurn: 4096, retryDelays: [], turnTimeout: .seconds(30))

    var compactedEvent: (from: Int, to: Int)?
    var outcome: LoopOutcome?
    for try await event in loop.run() {
        switch event {
        case .contextCompacted(let from, let to): compactedEvent = (from, to)
        case .finished(let result): outcome = result
        default: break
        }
    }
    guard case .completed = outcome else {
        Issue.record("expected completion, got \(String(describing: outcome))")
        return
    }
    let compaction = try #require(compactedEvent)
    #expect(compaction.to < compaction.from)

    // 压缩后的最后一轮请求：首条不变、含摘要标记、比未压缩短
    let finalHistory = await mock.recordedHistories.last!
    guard case .text(let first) = finalHistory[0].content[0] else { return }
    #expect(first.contains("长任务"))
    let hasSummary = finalHistory.contains { message in
        message.content.contains { block in
            if case .text(let t) = block { return t.contains("此前进展摘要") }
            return false
        }
    }
    #expect(hasSummary)
}
