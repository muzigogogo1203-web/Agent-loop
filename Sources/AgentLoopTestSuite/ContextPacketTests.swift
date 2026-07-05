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

// MARK: - 知识注入（M4，spec §6.2-5/6 + plan D2）

@Test func packetRendersCampNotesAndMemorySections() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "写清单",
        cardDescription: "d",
        expectedOutput: "o",
        workspacePath: nil,
        upstreamHandoffs: [],
        campNotes: [NoteSnippet(title: "上次的教训", body: "别在雨天搭帐篷")],
        companionNotes: [NoteSnippet(title: "用户偏好", body: "交付物要 markdown")]
    )
    guard case .text(let user) = packet.firstUserMessage.content[0] else {
        Issue.record("expected text user message")
        return
    }
    #expect(user.contains("# 营地笔记（往期经验）"))
    #expect(user.contains("## 上次的教训"))
    #expect(user.contains("别在雨天搭帐篷"))
    #expect(user.contains("# 你的记忆"))
    #expect(user.contains("交付物要 markdown"))
    // 渲染顺序：营地笔记 → 记忆
    let campIndex = user.range(of: "# 营地笔记")!.lowerBound
    let memoryIndex = user.range(of: "# 你的记忆")!.lowerBound
    #expect(campIndex < memoryIndex)
}

@Test func packetOmitsEmptyKnowledgeSections() {
    let packet = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "o", workspacePath: nil, upstreamHandoffs: [])
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    #expect(!user.contains("营地笔记"))
    #expect(!user.contains("你的记忆"))
}

@Test func knowledgeSectionsRenderBeforeUpstreamHandoffs() {
    let handoff = HandoffPayload(
        outcome: "上游完成", summary: "s", artifacts: [], noArtifactReason: "无",
        verification: [], risks: [])
    let packet = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "o", workspacePath: nil,
        upstreamHandoffs: [UpstreamHandoff(cardTitle: "上游卡", handoff: handoff,
                                           workspaceRelativePaths: [], durablePaths: [])],
        campNotes: [NoteSnippet(title: "笔记", body: "b")]
    )
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    let notesIndex = user.range(of: "# 营地笔记")!.lowerBound
    let upstreamIndex = user.range(of: "# 上游交接")!.lowerBound
    #expect(notesIndex < upstreamIndex)
}

@Test func noteSnippetTruncationLimits() {
    // D2：置顶 801 字 → 800 + 省略号；最近 150 字上限
    let long = String(repeating: "长", count: 801)
    var pinnedNote = CampNoteRecord.new(campId: "c", title: "钉", bodyMd: long)
    pinnedNote.pinned = true
    let recentNote = CampNoteRecord.new(campId: "c", title: "近", bodyMd: long)

    let snippets = NoteSnippet.from(pinned: [pinnedNote], recent: [recentNote])
    #expect(snippets.count == 2)
    #expect(snippets[0].body.count == 801) // 800 + "…"
    #expect(snippets[0].body.hasSuffix("…"))
    #expect(snippets[1].body.count == 151) // 150 + "…"
    #expect(snippets[1].body.hasSuffix("…"))

    // 恰好 800 字不截断
    var exact = CampNoteRecord.new(campId: "c", title: "整", bodyMd: String(repeating: "字", count: 800))
    exact.pinned = true
    let exactSnippet = NoteSnippet.from(pinned: [exact], recent: [])
    #expect(exactSnippet[0].body.count == 800)
    #expect(!exactSnippet[0].body.hasSuffix("…"))
}

@Test func renderSectionDeterministicAndNilWhenEmpty() {
    #expect(NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: []) == nil)
    let snippets = [NoteSnippet(title: "t", body: "b")]
    let first = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: snippets)
    let second = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: snippets)
    #expect(first == second)
    #expect(first == "# 营地笔记（往期经验）\n## t\nb")
}

@Test func contractMentionsChunkedWrites() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "A",
        cardDescription: "a",
        expectedOutput: "x",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    #expect(packet.system.contains("append"))
    #expect(packet.system.contains("3000"))
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
