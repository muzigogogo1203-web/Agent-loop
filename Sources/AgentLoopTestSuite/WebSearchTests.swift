import Testing
import Foundation
import AgentLoopCore

// 每个用例专属 stub 类（并行测试下共享 handler 静态量会互相覆盖，是竞态源）
private class FixedResponseStubProtocol: URLProtocol {
    class var status: Int { 200 }
    class var body: String { "{}" }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class SearchOKStubProtocol: FixedResponseStubProtocol {
    nonisolated(unsafe) static var seenAuthorization: String?
    override class var body: String {
        #"{"results":[{"title":"Swift 6 发布","url":"https://example.com/1","content":"摘要一"},{"title":"GRDB 7","url":"https://example.com/2","content":"摘要二"}]}"#
    }
    override func startLoading() {
        Self.seenAuthorization = request.value(forHTTPHeaderField: "Authorization")
        super.startLoading()
    }
}

private final class Search401StubProtocol: FixedResponseStubProtocol {
    override class var status: Int { 401 }
}

private final class SearchTimeoutStubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }
    override func stopLoading() {}
}

private func webSearchStubSession(_ protocolClass: AnyClass) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [protocolClass]
    return URLSession(configuration: configuration)
}

@Test func webSearchRendersResultsWithSourceMarker() async {
    let tool = WebSearchTool(
        apiKey: "test-key", session: webSearchStubSession(SearchOKStubProtocol.self))
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
    #expect(SearchOKStubProtocol.seenAuthorization == "Bearer test-key")
}

@Test func webSearchNon200ReturnsError() async {
    let tool = WebSearchTool(
        apiKey: "bad-key", session: webSearchStubSession(Search401StubProtocol.self))
    let outcome = await tool.execute(input: ["query": "q"])
    guard case .error(let message) = outcome else {
        Issue.record("expected error")
        return
    }
    #expect(message.contains("401"))
}

@Test func webSearchTimeoutReturnsError() async {
    // D6：无网/超时一律 .error，回合继续自愈，不抛出循环
    let tool = WebSearchTool(
        apiKey: "k", session: webSearchStubSession(SearchTimeoutStubProtocol.self))
    let outcome = await tool.execute(input: ["query": "q"])
    guard case .error = outcome else {
        Issue.record("expected error")
        return
    }
}

@Test func webSearchRejectsEmptyQuery() async {
    let tool = WebSearchTool(
        apiKey: "k", session: webSearchStubSession(SearchTimeoutStubProtocol.self))
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
