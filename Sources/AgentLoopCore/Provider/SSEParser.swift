public struct RawSSEEvent: Sendable, Equatable {
    public let event: String
    public let data: String
    public init(event: String, data: String) { self.event = event; self.data = data }
}

public struct SSELineParser: Sendable {
    private var pendingEvent: String = "message"
    public init() {}

    public mutating func consume(line: String) -> RawSSEEvent? {
        if line.hasPrefix(":") || line.isEmpty { return nil }
        if line.hasPrefix("event:") {
            pendingEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return nil
        }
        if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return RawSSEEvent(event: pendingEvent, data: data)
        }
        return nil
    }
}
