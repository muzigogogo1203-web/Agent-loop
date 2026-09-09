import Testing
import Foundation
import AgentLoopCore

private func textTurn(_ text: String) -> TurnResult {
    TurnResult(content: [.text(text)], stopReason: .endTurn)
}

// MARK: - 解析（剥围栏 → JSON → 首行回退）

@Test func parseNoteJSONHappyPath() throws {
    let parsed = try Distiller.parseNoteJSON(###"{"title":"露营经验","body":"## 做了什么\n搭了帐篷"}"###)
    #expect(parsed == .note(title: "露营经验", body: "## 做了什么\n搭了帐篷"))
}

@Test func parseNoteJSONStripsCodeFence() throws {
    let fenced = """
    ```json
    {"title":"带围栏","body":"正文"}
    ```
    """
    #expect(try Distiller.parseNoteJSON(fenced) == .note(title: "带围栏", body: "正文"))
}

@Test func parseNoteJSONTruncatesLongTitle() throws {
    let long = String(repeating: "长", count: 50)
    let parsed = try Distiller.parseNoteJSON(#"{"title":"\#(long)","body":"b"}"#)
    guard case .note(let title, _) = parsed else { Issue.record("expected note"); return }
    #expect(title.count == 30)
}

@Test func parseNoteJSONMalformedFallsBackToFirstLine() {
    #expect(throws: DistillerError.invalidPayload) {
        try Distiller.parseNoteJSON("这是标题行\n这是正文第一行\n这是正文第二行")
    }
    #expect(throws: DistillerError.invalidPayload) {
        try Distiller.parseNoteJSON("只有一行")
    }
}

@Test func parseNoteJSONSkipConvention() throws {
    #expect(try Distiller.parseNoteJSON(#"{"skip":true}"#) == .skip)
    #expect(throws: DistillerError.invalidPayload) {
        try Distiller.parseNoteJSON("")
    }
    #expect(throws: DistillerError.invalidPayload) {
        try Distiller.parseNoteJSON("   \n  ")
    }
}

// MARK: - Prompt 确定性（无时间戳）

@Test func promptsAreDeterministic() {
    let cards = [Distiller.CardDigest(title: "A", outcome: "o", summary: "s", risks: ["r"])]
    #expect(Distiller.closeoutPrompt(goal: "g", cards: cards) == Distiller.closeoutPrompt(goal: "g", cards: cards))
    let messages = [(role: "user", text: "hi")]
    #expect(Distiller.memoryPrompt(companionName: "甲", rolePrompt: "r", messages: messages)
        == Distiller.memoryPrompt(companionName: "甲", rolePrompt: "r", messages: messages))
    #expect(Distiller.guideChatPrompt(messages: messages) == Distiller.guideChatPrompt(messages: messages))
    // 固定模板里不该混入日期
    #expect(!Distiller.closeoutSystem.contains("202"))
    #expect(!Distiller.memorySystem.contains("202"))
}

// MARK: - 收营蒸馏（成功 / 回退）

@Test func distillCloseoutParsesLLMNote() async {
    let mock = MockProvider(script: [
        textTurn(###"{"title":"北岭探索复盘","body":"## 做了什么\n…\n## 什么做法有效\n…\n## 关键产物在哪\n…\n## 踩了什么坑\n…"}"###),
    ])
    let distiller = Distiller(provider: mock)
    let (note, fallback) = await distiller.distillCloseout(
        goal: "探索北岭",
        cards: [.init(title: "画地图", outcome: "完成", summary: "地图已画好", risks: [])])
    #expect(!fallback)
    #expect(note.title == "北岭探索复盘")
    #expect(note.bodyMd.contains("做了什么"))
}

@Test func distillCloseoutFallsBackOnProviderFailure() async {
    // 空脚本 → mock script exhausted → 确定性回退，仍产出非空笔记
    let mock = MockProvider(script: [])
    let distiller = Distiller(provider: mock)
    let (note, fallback) = await distiller.distillCloseout(
        goal: "探索北岭\n第二行",
        cards: [
            .init(title: "画地图", outcome: "完成", summary: "地图已画好", risks: ["天气"]),
            .init(title: "写报告", outcome: "完成", summary: "报告成文", risks: []),
        ])
    #expect(fallback)
    #expect(note.title == "探索北岭")
    #expect(note.bodyMd.contains("画地图"))
    #expect(note.bodyMd.contains("地图已画好"))
    #expect(note.bodyMd.contains("天气"))
    #expect(note.bodyMd.contains("写报告"))
}

@Test func distillCloseoutFallsBackOnUnparseableEmptyText() async {
    let mock = MockProvider(script: [textTurn("")])
    let distiller = Distiller(provider: mock)
    let (note, fallback) = await distiller.distillCloseout(goal: "目标", cards: [])
    #expect(fallback)
    #expect(!note.title.isEmpty)
    #expect(!note.bodyMd.isEmpty)
}

// MARK: - 记忆蒸馏（skip / note / 失败上抛）

@Test func distillMemoryReturnsNilOnSkip() async throws {
    let mock = MockProvider(script: [textTurn(#"{"skip":true}"#)])
    let distiller = Distiller(provider: mock)
    let note = try await distiller.distillMemory(
        companionName: "细细", rolePrompt: "审校", messages: [(role: "user", text: "今天天气不错")])
    #expect(note == nil)
}

@Test func distillMemoryReturnsNote() async throws {
    let mock = MockProvider(script: [textTurn(#"{"title":"用户偏好 markdown","body":"- 交付物用 markdown"}"#)])
    let distiller = Distiller(provider: mock)
    let note = try await distiller.distillMemory(
        companionName: "细细", rolePrompt: "审校", messages: [(role: "user", text: "以后都给我 markdown")])
    #expect(note?.title == "用户偏好 markdown")
}

@Test func distillMemoryThrowsOnProviderFailure() async {
    let mock = MockProvider(script: [])
    let distiller = Distiller(provider: mock)
    await #expect(throws: (any Error).self) {
        _ = try await distiller.distillMemory(companionName: "甲", rolePrompt: "r",
                                              messages: [(role: "user", text: "x")])
    }
}

// MARK: - 向导对话沉淀（D9）

@Test func distillGuideChatNoteAndSkip() async throws {
    let mockNote = MockProvider(script: [textTurn(#"{"title":"营地决策","body":"- 下一步先修桥"}"#)])
    let note = try await Distiller(provider: mockNote)
        .distillGuideChat(messages: [(role: "user", text: "我们决定先修桥")])
    #expect(note?.title == "营地决策")

    let mockSkip = MockProvider(script: [textTurn(#"{"skip":true}"#)])
    let skipped = try await Distiller(provider: mockSkip)
        .distillGuideChat(messages: [(role: "user", text: "哈哈")])
    #expect(skipped == nil)
}
