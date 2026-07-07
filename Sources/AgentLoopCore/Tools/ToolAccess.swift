import Foundation

/// 伙伴工具白名单（M6-D3/D5b）。
///
/// 语义：
/// - 板工具（complete_card/block_card/add_progress_note/ask_user）是内核契约
///   （工具唯一终结 + 人工门 + 进展汇报），永不可剥夺，不在白名单管辖内。
/// - 能力工具可勾选。存量 `"[]"`（数组格式）= 内置能力工具全量，用户无感兼容。
/// - 「空=全量」只覆盖**内置**工具：未来的外部（MCP）工具必须显式勾选，
///   不被空名单继承（V2 设计 §5-M8 的地基螺栓）。
/// - 编辑器保存永远写 v2 对象格式 `{"v":2,"allow":[...]}`——显式授权；
///   其中空 allow 是合法的「零能力工具」（纯推理伙伴），与存量 `"[]"` 语义不同。
public struct ToolAccess: Sendable, Equatable {
    /// 板工具：永远在场。
    public static let boardToolNames: Set<String> = [
        "complete_card", "block_card", "add_progress_note", "ask_user",
    ]
    /// 内置能力工具全集（可被白名单勾选的部分）。
    public static let builtinCapabilityNames: [String] = [
        "list_dir", "read_file", "write_file", "web_fetch", "web_search", "search_camp_notes",
    ]

    /// 解析后的能力工具集合（已应用「空=全量(仅内置)」）。
    public let capabilities: Set<String>
    /// toolsJson 解析失败（已回退全量）；调用方应记 kernel_error 事件。
    public let parseFailed: Bool

    public static let full = ToolAccess(
        capabilities: Set(builtinCapabilityNames), parseFailed: false)

    init(capabilities: Set<String>, parseFailed: Bool) {
        self.capabilities = capabilities
        self.parseFailed = parseFailed
    }

    public static func parse(toolsJson: String) -> ToolAccess {
        let data = Data(toolsJson.utf8)
        if let explicit = try? JSONDecoder().decode(ExplicitList.self, from: data), explicit.v == 2 {
            return ToolAccess(capabilities: Set(explicit.allow), parseFailed: false)
        }
        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            if legacy.isEmpty { return .full }
            return ToolAccess(
                capabilities: Set(legacy).intersection(builtinCapabilityNames),
                parseFailed: false)
        }
        return ToolAccess(capabilities: Set(builtinCapabilityNames), parseFailed: true)
    }

    /// 编辑器保存格式（D5b）：显式 v2 列表，排序保证字节确定。
    public static func explicitJson(allow: Set<String>) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let list = ExplicitList(v: 2, allow: allow.sorted())
        guard let data = try? encoder.encode(list) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    public func allows(_ name: String) -> Bool {
        Self.boardToolNames.contains(name) || capabilities.contains(name)
    }

    private struct ExplicitList: Codable {
        let v: Int
        let allow: [String]
    }
}
