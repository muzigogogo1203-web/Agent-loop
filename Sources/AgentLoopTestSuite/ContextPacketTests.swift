import Testing
import AgentLoopCore

@Test func packetContainsContractAndCard() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "你是产品伙伴",
        cardTitle: "写装备清单",
        cardDescription: "整理一份露营装备清单",
        expectedOutput: "一份分类清晰的 markdown 清单文件",
        workspacePath: "/tmp/ws",
        upstreamHandoffs: []
    )
    #expect(packet.system.contains("你是产品伙伴"))
    #expect(packet.system.contains("complete_card"))
    #expect(packet.system.contains("block_card"))
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    #expect(user.contains("写装备清单"))
    #expect(user.contains("分类清晰"))
    #expect(user.contains("/tmp/ws"))
}

@Test func systemIsStableAcrossCards() {
    let first = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "A",
        cardDescription: "a",
        expectedOutput: "x",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    let second = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "B",
        cardDescription: "b",
        expectedOutput: "y",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    #expect(first.system == second.system)
}
