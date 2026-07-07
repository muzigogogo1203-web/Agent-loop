import Foundation

/// 联网搜索（M6-D6，Tavily）：只读、parallel-safe。
/// 无 key 时该工具根本不会被装配（D8：能力自然降级，不给模型可见但必败的工具）；
/// 无网/超时/非 200 一律返回 .error 让回合继续自愈（与 web_fetch 同构，不抛出循环）。
public struct WebSearchTool: ToolHandler {
    let apiKey: String
    let session: URLSession

    static let endpoint = URL(string: "https://api.tavily.com/search")!
    static let maxResults = 5

    public init(apiKey: String, session: URLSession? = nil) {
        self.apiKey = apiKey
        self.session = session ?? Self.makeSession()
    }

    /// 专用会话：请求超时 20s（与 web_fetch v2 同参）——默认 60s 会白烧一轮等待。
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard let query = input["query"]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return .error("需要非空的 query")
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(
                SearchRequest(query: query, max_results: Self.maxResults))
        } catch {
            return .error("搜索请求编码失败：\(error.localizedDescription)")
        }

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                return .error("搜索服务返回 HTTP \(status)（key 无效或额度用尽时请到设置页检查 Tavily key）")
            }
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard !decoded.results.isEmpty else {
                return .result("没有找到与「\(query)」相关的结果，换个关键词试试。")
            }
            let rendered = decoded.results.prefix(Self.maxResults).enumerated()
                .map { index, item in
                    "\(index + 1). \(item.title)\n   \(item.url)\n   \(item.content)"
                }
                .joined(separator: "\n\n")
            return .result(ExternalContent.wrap(source: "网页搜索「\(query)」", body: rendered))
        } catch {
            return .error("搜索失败：\(error.localizedDescription)")
        }
    }

    private struct SearchRequest: Encodable {
        let query: String
        let max_results: Int
    }

    private struct SearchResponse: Decodable {
        let results: [Item]

        struct Item: Decodable {
            let title: String
            let url: String
            let content: String
        }
    }
}
