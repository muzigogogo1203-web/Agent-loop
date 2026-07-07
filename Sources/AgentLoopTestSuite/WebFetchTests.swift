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

// MARK: - v2（M6-D10）

private final class HTTPDowngradeStubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // 模拟「重定向后落在 http」：响应的最终 URL 是明文地址
        let response = HTTPURLResponse(
            url: URL(string: "http://mirror.example.com/a")!,
            statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<p>hi</p>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class FailingStubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }
    override func stopLoading() {}
}

@Test func truncatesOnUTF8ByteBoundary() {
    // v1 真 bug：字节判断 + 字符截断。v2 按 UTF-8 字节裁到合法字符边界
    let text = String(repeating: "汉", count: 20_000) // 60,000 字节
    let truncated = WebFetchTool.truncateUTF8(text, maxBytes: 50_000)
    #expect(truncated.utf8.count <= 50_000 + 64) // 含截断标记
    #expect(truncated.contains("截断"))
    #expect(truncated.unicodeScalars.allSatisfy { $0 != "\u{FFFD}" }) // 无替换字符=边界合法
    // 50,000 不是 3 的倍数（汉=3 字节）：必须裁到 49,998，不能裁出半个字
    let body = truncated.replacingOccurrences(of: "\n…（已按 50KB 截断）", with: "")
    #expect(body.utf8.count == 49_998)
}

@Test func rejectsRedirectDowngradeToHTTP() async {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HTTPDowngradeStubProtocol.self]
    let tool = WebFetchTool(session: URLSession(configuration: configuration))
    let output = await tool.execute(input: ["url": "https://example.com/a"])
    guard case .error(let message) = output else {
        Issue.record("expected error")
        return
    }
    #expect(message.contains("http"))
}

@Test func fetchTimeoutReturnsError() async {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FailingStubProtocol.self]
    let tool = WebFetchTool(session: URLSession(configuration: configuration))
    let output = await tool.execute(input: ["url": "https://example.com/slow"])
    guard case .error = output else {
        Issue.record("expected error")
        return
    }
}

@Test func prefersArticleContentOverChrome() {
    let html = """
    <html><body>
    <nav>首页 关于 登录 注册 侧边栏广告位面包屑</nav>
    <article><h1>正文标题</h1><p>\(String(repeating: "这是正文内容。", count: 20))</p></article>
    <footer>版权所有 友情链接</footer>
    </body></html>
    """
    let text = WebFetchTool.extractReadable(html)
    #expect(text.contains("正文标题"))
    #expect(!text.contains("友情链接"))
    #expect(!text.contains("侧边栏广告位"))
}

// 专属 stub（不共享 handler 静态量——并行测试下共享可变态会互相覆盖）
private final class WrapFixtureStubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "text/html"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<p>外部页面内容</p>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func fetchResultWrappedAsExternalContent() async {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WrapFixtureStubProtocol.self]
    let tool = WebFetchTool(session: URLSession(configuration: configuration))
    let output = await tool.execute(input: ["url": "https://example.com/a"])
    guard case .result(let text) = output else {
        Issue.record("expected result")
        return
    }
    // D9①：抓取结果同样过信任边界包裹
    #expect(text.contains("外部来源"))
    #expect(text.contains("外部页面内容"))
}
