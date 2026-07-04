import Testing
import Foundation
import AgentLoopCore

private final class WebFetchStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, data, headers) = Self.handler!(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func fetchesAndStripsHTML() async throws {
    WebFetchStubProtocol.handler = { _ in
        (
            200,
            Data("<html><head><style>x{}</style></head><body><h1>标题</h1><p>正文 &amp; 内容</p></body></html>".utf8),
            ["Content-Type": "text/html"]
        )
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WebFetchStubProtocol.self]
    let tool = WebFetchTool(session: URLSession(configuration: configuration))
    let output = await tool.execute(input: ["url": "https://example.com/a"])
    guard case .result(let text) = output else {
        Issue.record("fetch failed")
        return
    }
    #expect(text.contains("标题") && text.contains("正文 & 内容"))
    #expect(!text.contains("<h1>") && !text.contains("style"))
}

@Test func rejectsNonHTTPS() async {
    let tool = WebFetchTool(session: .shared)
    let output = await tool.execute(input: ["url": "file:///etc/passwd"])
    guard case .error(let message) = output else { return }
    #expect(message.contains("https"))
}
