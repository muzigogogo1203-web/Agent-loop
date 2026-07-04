import Foundation

public enum ContentBlock: Sendable, Equatable, Codable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case unknown(JSONValue)   // thinking/compaction 等：原样透传（spec §6.1）

    public init(from decoder: Decoder) throws {
        let v = try JSONValue(from: decoder)
        switch v["type"]?.stringValue {
        case "text":
            self = .text(v["text"]?.stringValue ?? "")
        case "tool_use":
            self = .toolUse(id: v["id"]?.stringValue ?? "",
                            name: v["name"]?.stringValue ?? "",
                            input: v["input"] ?? .object([:]))
        case "tool_result":
            self = .toolResult(toolUseId: v["tool_use_id"]?.stringValue ?? "",
                               content: v["content"]?.stringValue ?? "",
                               isError: v["is_error"]?.boolValue ?? false)
        default:
            self = .unknown(v)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    public var jsonValue: JSONValue {
        switch self {
        case .text(let t): return ["type": "text", "text": .string(t)]
        case .toolUse(let id, let name, let input):
            return ["type": "tool_use", "id": .string(id), "name": .string(name), "input": input]
        case .toolResult(let id, let content, let isError):
            return ["type": "tool_result", "tool_use_id": .string(id),
                    "content": .string(content), "is_error": .bool(isError)]
        case .unknown(let v): return v
        }
    }
}

public struct APIMessage: Sendable, Equatable, Codable {
    public var role: Role
    public var content: [ContentBlock]
    public enum Role: String, Sendable, Codable { case user, assistant }
    public init(role: Role, content: [ContentBlock]) { self.role = role; self.content = content }
    public static func user(_ text: String) -> APIMessage { .init(role: .user, content: [.text(text)]) }
    public static func user(toolResults: [ContentBlock]) -> APIMessage { .init(role: .user, content: toolResults) }
    public static func assistant(_ content: [ContentBlock]) -> APIMessage { .init(role: .assistant, content: content) }
}
