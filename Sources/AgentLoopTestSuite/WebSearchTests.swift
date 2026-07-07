import Testing
import Foundation
import AgentLoopCore

private final class WebSearchStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Result<(Int, Data), URLError>)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.handler!(request) {
        case .success(let (status, data)):
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func webSearchStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WebSearchStubProtocol.self]
    return URLSession(configuration: configuration)
}

@Test func webSearchRendersResultsWithSourceMarker() async {
    WebSearchStubProtocol.handler = { request in
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let body = #"{"results":[{"title":"Swift 6 发布","url":"https://example.com/1","content":"摘要一"},{"title":"GRDB 7","url":"https://example.com/2","content":"摘要二"}]}"#
        return .success((200, Data(body.utf8)))
    }
    let tool = WebSearchTool(apiKey: "test-key", session: webSearchStubSession())
    let outcome = await tool.execute(input: ["query": "swift 6"])
    guard case .result(let text) = outcome else {
        Issue.record("expected result")
        return
    }
    #expect(text.contains("Swift 6 发布"))
    #expect(text.contains("https://example.com/2"))
    #expect(text.contains("摘要一"))
    // D9①：外部内容包裹来源标记，指令视为数据
    #expect(text.contains("外部来源"))
    #expect(text.contains("不代表用户"))
}

@Test func webSearchNon200ReturnsError() async {
    WebSearchStubProtocol.handler = { _ in .success((401, Data("{}".utf8))) }
    let tool = WebSearchTool(apiKey: "bad-key", session: webSearchStubSession())
    let outcome = await tool.execute(input: ["query": "q"])
    guard case .error(let message) = outcome else {
        Issue.record("expected error")
        return
    }
    #expect(message.contains("401"))
}

@Test func webSearchTimeoutReturnsError() async {
    // D6：无网/超时一律 .error，回合继续自愈，不抛出循环
    WebSearchStubProtocol.handler = { _ in .failure(URLError(.timedOut)) }
    let tool = WebSearchTool(apiKey: "k", session: webSearchStubSession())
    let outcome = await tool.execute(input: ["query": "q"])
    guard case .error = outcome else {
        Issue.record("expected error")
        return
    }
}

@Test func webSearchRejectsEmptyQuery() async {
    let tool = WebSearchTool(apiKey: "k", session: webSearchStubSession())
    let outcome = await tool.execute(input: ["query": "  "])
    guard case .error = outcome else {
        Issue.record("expected error")
        return
    }
}

// MARK: - 装配语义（M6-D8：无 key 时工具不出现）

@Test func runnerOmitsWebSearchWithoutKey() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )
    let complete = TurnResult(
        content: [.toolUse(id: "t1", name: "complete_card", input: [
            "outcome": "o", "summary": "s", "noArtifactReason": "无",
            "verification": [["method": "自查", "passed": true, "note": "ok"]],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
    // 无 key：web_search 不进提示词工具区（即便白名单全量）
    let mockWithout = MockProvider(script: [complete])
    let runner = CardRunner(db: db, provider: mockWithout, artifactStoreRoot: base.appendingPathComponent("a"))
    for try await _ in try runner.run(cardId: ids.cardId, companionName: "n", rolePrompt: "r") {}
    let namesWithout = await mockWithout.recordedTools.first?.map(\.name) ?? []
    #expect(!namesWithout.contains("web_search"))

    // 有 key：web_search 在场
    let ids2 = try db.createSingleCardMission(
        campName: "c", squadName: "s2", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )
    let mockWith = MockProvider(script: [complete])
    let runner2 = CardRunner(db: db, provider: mockWith, artifactStoreRoot: base.appendingPathComponent("a"))
    for try await _ in try runner2.run(
        cardId: ids2.cardId, companionName: "n", rolePrompt: "r", searchKey: "k") {}
    let namesWith = await mockWith.recordedTools.first?.map(\.name) ?? []
    #expect(namesWith.contains("web_search"))
}
