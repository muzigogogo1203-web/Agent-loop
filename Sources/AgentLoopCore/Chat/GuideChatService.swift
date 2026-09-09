public enum GuideChatEvent: Sendable {
    case textDelta(String)
    case toolActivity(name: String)
    case proposalCreated(messageId: String)
    case finished
}

/// Public Guide facade. Provider ownership, asynchronous execution, durable
/// checkpoints, lifecycle fencing, and message commits live behind the P1-E
/// Camp provider runtime.
public struct GuideChatService: Sendable {
    package static let maxToolRounds = 6

    private let runtime: CampProviderRuntimeV1

    package init(runtime: CampProviderRuntimeV1) {
        self.runtime = runtime
    }

    public func send(
        campId: String,
        userText: String
    ) throws -> AsyncThrowingStream<GuideChatEvent, Error> {
        try runtime.guideStream(campId: campId, userText: userText)
    }
}
