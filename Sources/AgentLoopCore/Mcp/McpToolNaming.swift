import Foundation

/// MCP 工具命名（M8-D4）：`mcp__<server>__<tool>`。
/// 双下划线分段；整名须满足 Anthropic 工具名约束 `^[a-zA-Z0-9_-]{1,128}$`，
/// server/tool 段先做字符白名单清洗。server 段内的 "__" 压成 "_"，
/// 保证首个 "__" 是分隔符（display 解析用；调用路径不依赖解析——
/// Manager 在装配时就把原始工具名捕获进 handler）。
public enum McpToolNaming {
    public static let prefix = "mcp__"
    static let maxLength = 128

    /// 字符白名单清洗：合法字符保留，其余映射为 "-"。
    public static func sanitizeComponent(_ raw: String) -> String {
        let mapped = raw.map { ch -> Character in
            if ch.isASCII && (ch.isLetter || ch.isNumber) || ch == "-" || ch == "_" {
                return ch
            }
            return "-"
        }
        return String(mapped)
    }

    /// server 段：白名单清洗 + "__" 压缩（保护分隔符唯一性）。
    public static func serverComponent(_ raw: String) -> String {
        var s = sanitizeComponent(raw)
        while s.contains("__") {
            s = s.replacingOccurrences(of: "__", with: "_")
        }
        return s
    }

    /// 组合完整工具名；组件清洗后为空或超长（>128）时返回 nil（该工具跳过并留痕）。
    public static func compose(server: String, tool: String) -> String? {
        let serverPart = serverComponent(server)
        let toolPart = sanitizeComponent(tool)
        guard !serverPart.isEmpty, !toolPart.isEmpty else { return nil }
        let name = prefix + serverPart + "__" + toolPart
        guard name.count <= maxLength else { return nil }
        return name
    }

    /// 展示用解析（server 段不含 "__"，首个 "__" 即分隔）。
    public static func parse(_ name: String) -> (server: String, tool: String)? {
        guard name.hasPrefix(prefix) else { return nil }
        let body = name.dropFirst(prefix.count)
        guard let range = body.range(of: "__"), !body[..<range.lowerBound].isEmpty,
              !body[range.upperBound...].isEmpty else { return nil }
        return (String(body[..<range.lowerBound]), String(body[range.upperBound...]))
    }
}
