import Testing
import AgentLoopCore

private func firstUserText(_ packet: ContextPacket) throws -> String {
    guard case .text(let text) = try #require(packet.firstUserMessage.content.first) else {
        Issue.record("expected text user message")
        return ""
    }
    return text
}

@Test func downstreamPacketCarriesUpstreamHandoffAndPaths() throws {
    let upstream = UpstreamHandoff(
        cardTitle: "资料整理",
        handoff: HandoffPayload(
            outcome: "资料已整理",
            summary: "A 已生成 facts.md",
            artifacts: [.init(relativePath: "facts.md", kind: "markdown", label: "事实表")],
            verification: [.init(method: "读取文件", passed: true, note: "内容完整")],
            next: "基于 facts.md 写最终稿",
            risks: ["来源较少"]
        ),
        workspaceRelativePaths: ["facts.md"],
        durablePaths: ["/tmp/artifacts/card-a/facts.md"]
    )
    let packet = ContextPacket(
        companionName: "乙",
        rolePrompt: "你是写作伙伴",
        cardTitle: "写最终稿",
        cardDescription: "使用上游资料写最终稿",
        expectedOutput: "final.md",
        workspacePath: "/tmp/ws",
        upstreamHandoffs: [upstream]
    )

    let text = try firstUserText(packet)
    #expect(text.contains("# 上游交接"))
    #expect(text.contains("资料整理"))
    #expect(text.contains("资料已整理"))
    #expect(text.contains("A 已生成 facts.md"))
    #expect(text.contains("facts.md"))
    #expect(text.contains("/tmp/artifacts/card-a/facts.md"))
    #expect(text.contains("工作目录内路径可直接用 read_file 读取"))
}

@Test func packetRenderingIsDeterministic() throws {
    let upstream = UpstreamHandoff(
        cardTitle: "无产物卡",
        handoff: HandoffPayload(
            outcome: "完成分析",
            summary: "没有文件产物",
            artifacts: [],
            noArtifactReason: "只需文字结论",
            verification: [.init(method: "复核", passed: false, note: "待二次确认")],
            next: nil,
            risks: []
        ),
        workspaceRelativePaths: [],
        durablePaths: []
    )
    let makePacket = {
        ContextPacket(
            companionName: "乙",
            rolePrompt: "r",
            cardTitle: "B",
            cardDescription: "b",
            expectedOutput: "e",
            workspacePath: nil,
            upstreamHandoffs: [upstream]
        )
    }
    let first = try firstUserText(makePacket())
    let second = try firstUserText(makePacket())
    #expect(first == second)
    #expect(!first.contains("UUID"))
    #expect(!first.contains("createdAt"))
    #expect(first.contains("无文件产物：只需文字结论"))
    #expect(first.contains("✗"))
}
