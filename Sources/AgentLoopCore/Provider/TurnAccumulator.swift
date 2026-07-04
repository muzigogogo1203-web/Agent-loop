import Foundation

public struct TurnAccumulator: Sendable {
    private enum Pending {
        case text(String)
        case toolUse(id: String, name: String, jsonBuffer: String)
        case unknown(JSONValue)
    }
    private var pending: [Int: Pending] = [:]
    private var finished: [(index: Int, block: ContentBlock)] = []
    private var stopReason: StopReason?
    private var usage = Usage()
    public private(set) var finishedTurn: TurnResult?

    public init() {}

    public mutating func consume(_ raw: RawSSEEvent, onTextDelta: (String) -> Void) throws {
        let v = try JSONValue.decoded(from: raw.data)
        switch raw.event {
        case "message_start":
            usage.inputTokens = v["message"]?["usage"]?["input_tokens"]?.intValue ?? 0
            usage.cacheReadTokens = v["message"]?["usage"]?["cache_read_input_tokens"]?.intValue ?? 0
        case "content_block_start":
            let idx = v["index"]?.intValue ?? 0
            let block = v["content_block"] ?? .object([:])
            switch block["type"]?.stringValue {
            case "text": pending[idx] = .text(block["text"]?.stringValue ?? "")
            case "tool_use":
                pending[idx] = .toolUse(id: block["id"]?.stringValue ?? "",
                                        name: block["name"]?.stringValue ?? "", jsonBuffer: "")
            default: pending[idx] = .unknown(block)
            }
        case "content_block_delta":
            let idx = v["index"]?.intValue ?? 0
            let delta = v["delta"] ?? .object([:])
            switch delta["type"]?.stringValue {
            case "text_delta":
                let t = delta["text"]?.stringValue ?? ""
                if case .text(let existing) = pending[idx] { pending[idx] = .text(existing + t) }
                onTextDelta(t)
            case "input_json_delta":
                let part = delta["partial_json"]?.stringValue ?? ""
                if case .toolUse(let id, let name, let buf) = pending[idx] {
                    pending[idx] = .toolUse(id: id, name: name, jsonBuffer: buf + part)
                }
            default: break
            }
        case "content_block_stop":
            let idx = v["index"]?.intValue ?? 0
            guard let p = pending.removeValue(forKey: idx) else { break }
            let block: ContentBlock
            switch p {
            case .text(let t): block = .text(t)
            case .toolUse(let id, let name, let buf):
                let input = buf.isEmpty ? JSONValue.object([:]) : ((try? JSONValue.decoded(from: buf)) ?? .object([:]))
                block = .toolUse(id: id, name: name, input: input)
            case .unknown(let v): block = .unknown(v)
            }
            finished.append((idx, block))
        case "message_delta":
            if let sr = v["delta"]?["stop_reason"]?.stringValue { stopReason = StopReason(apiValue: sr) }
            if let out = v["usage"]?["output_tokens"]?.intValue { usage.outputTokens = out }
        case "message_stop":
            finishedTurn = TurnResult(
                content: finished.sorted { $0.index < $1.index }.map(\.block),
                stopReason: stopReason ?? .endTurn, usage: usage)
        case "error":
            throw ProviderError.apiError(type: v["error"]?["type"]?.stringValue ?? "unknown",
                                         message: v["error"]?["message"]?.stringValue ?? "")
        default: break // ping 等
        }
    }
}
