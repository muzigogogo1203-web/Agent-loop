import Foundation

/// 网页抓取 v2（M6-D10）：专用 20s 超时会话、字节安全截断、重定向后 scheme 复验、
/// article/main 优先抽取；结果经 ExternalContent 包裹（D9①）。只读。
public struct WebFetchTool: ToolHandler {
    let session: URLSession
    static let maxBytes = 50_000

    public init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    /// 专用会话：请求超时 20s（与 web_search 同参）——v1 用 URLSession.shared 无显式超时。
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard let urlString = input["url"]?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "https" else {
            return .error("需要一个 https:// 开头的合法 URL")
        }

        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                return .error("HTTP \(status)")
            }
            // D10：重定向后复验最终 URL 仍是 https，拒绝降级到明文
            if let finalScheme = response.url?.scheme?.lowercased(), finalScheme != "https" {
                return .error("目标经重定向落在非 https 地址（\(finalScheme)://），已拒绝抓取")
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            let text = Self.truncateUTF8(Self.extractReadable(raw), maxBytes: Self.maxBytes)
            return .result(ExternalContent.wrap(
                source: "网页 \(response.url?.absoluteString ?? urlString)",
                body: text))
        } catch {
            return .error("抓取失败：\(error.localizedDescription)")
        }
    }

    /// article/main 内容优先（正文密度高），太短说明只是壳，退回全文剥标签。
    package static func extractReadable(_ html: String) -> String {
        for tag in ["article", "main"] {
            if let range = html.range(
                of: "<\(tag)[\\s>][\\s\\S]*?</\(tag)>",
                options: [.regularExpression, .caseInsensitive]) {
                let stripped = stripHTML(String(html[range]))
                if stripped.count >= 80 {
                    return stripped
                }
            }
        }
        return stripHTML(html)
    }

    /// 字节安全截断（修 v1「字节判断 + 字符截断」bug）：
    /// 按 UTF-8 字节上限裁剪，再从尾部去掉不完整序列，保证落在合法字符边界。
    package static func truncateUTF8(_ text: String, maxBytes: Int) -> String {
        guard text.utf8.count > maxBytes else { return text }
        var data = Data(text.utf8.prefix(maxBytes))
        while !data.isEmpty, String(data: data, encoding: .utf8) == nil {
            data.removeLast()
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return body + "\n…（已按 50KB 截断）"
    }

    static func stripHTML(_ html: String) -> String {
        var text = html
        for tag in ["script", "style"] {
            text = text.replacingOccurrences(
                of: "<\(tag)[\\s\\S]*?</\(tag)>",
                with: "",
                options: .regularExpression
            )
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " ",
        ]
        for (source, replacement) in entities {
            text = text.replacingOccurrences(of: source, with: replacement)
        }
        return text
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
