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

// MARK: - Engine preparation semantics

private func webSearchPreparationResolver(
    fixture: P1F1DCanonicalExecutionFixture,
    key: String?
) -> EngineContextTransportResolverV1 {
    EngineContextTransportResolverV1(
        database: fixture.db,
        dependencyLoader: ContextDependencyLoader(
            database: fixture.db,
            manager: nil,
            reporter: FailureReporter(database: fixture.db),
            searchCredential: { key },
            knowledge: .live(database: fixture.db),
            makeTrace: { operation, scope in
                OperationTraceFactory.live.generated(
                    operation: operation,
                    scope: scope
                )
            }
        )
    )
}

@Test func selectedWebSearchRequiresCredentialDuringPreparation() async throws {
    let toolsJson = ToolAccess.explicitJson(allow: ["web_search"])
    let missingFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: toolsJson
    )
    let missingResolver = webSearchPreparationResolver(
        fixture: missingFixture,
        key: nil
    )

    // Mutation caught: silently omitting a selected required search tool or
    // restoring the former profile-kind-wide CLI rejection.
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await missingResolver.prepareCurrent(
            campId: missingFixture.camp.id,
            cardId: missingFixture.card.id,
            companionId: missingFixture.companion.id
        )
    }
    #expect(try missingFixture.db.card(id: missingFixture.card.id)?.status == .blocked)
    let failures = try missingFixture.db.contextDegradations(
        missionId: missingFixture.mission.id,
        cardId: missingFixture.card.id
    )
    #expect(failures.count == 1)
    #expect(failures[0].dependencyType == .search)
    #expect(failures[0].policy == .required)
    #expect(!failures[0].detail.isEmpty)
    #expect(
        try missingFixture.db.failureRecord(id: failures[0].traceId) != nil
    )

    let availableFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: toolsJson
    )
    let available = try await webSearchPreparationResolver(
        fixture: availableFixture,
        key: "test-search-key"
    ).prepareCurrent(
        campId: availableFixture.camp.id,
        cardId: availableFixture.card.id,
        companionId: availableFixture.companion.id
    )
    #expect(
        available.capabilityTools.logicalDefinitions.map(\.name)
            == [
                "complete_card",
                "block_card",
                "add_progress_note",
                "ask_user",
                "web_search",
            ]
    )
    let bound = try available.capabilityTools.makeCapabilityTools(
        availableFixture.workspaceURL
    )
    let search = try #require(
        bound.capabilityTools.first { $0.def.name == "web_search" }
    )
    guard case .error(let message) = await search.handler.execute(
        input: ["query": "  "]
    ) else {
        Issue.record("credentialed web_search must use the real read-only handler")
        return
    }
    #expect(message == "需要非空的 query")
    #expect(message != "engine_approval_required")
    #expect(try availableFixture.db.card(id: availableFixture.card.id)?.status == .ready)
    #expect(
        try availableFixture.db.contextDegradations(
            missionId: availableFixture.mission.id,
            cardId: availableFixture.card.id
        ).isEmpty
    )
}
