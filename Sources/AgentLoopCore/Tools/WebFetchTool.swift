import Foundation

public struct WebFetchTool: ToolHandler {
    let session: URLSession
    let maxBytes = 50_000

    public init(session: URLSession = .shared) {
        self.session = session
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
            let raw = String(data: data, encoding: .utf8) ?? ""
            let text = Self.stripHTML(raw)
            if text.utf8.count > maxBytes {
                return .result(String(text.prefix(maxBytes)) + "\n...(截断)")
            }
            return .result(text)
        } catch {
            return .error("抓取失败：\(error.localizedDescription)")
        }
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
