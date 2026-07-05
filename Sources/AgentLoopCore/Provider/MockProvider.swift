/// Scripted-replay test double. Single-consumer: early cancellation still consumes a script entry and bumps callCount.
public actor MockProvider: LLMProvider {
    private var script: [TurnResult]
    public private(set) var callCount = 0
    public private(set) var recordedHistories: [[APIMessage]] = []
    public private(set) var recordedToolChoices: [ToolChoice] = []
    public private(set) var recordedSystems: [String] = []

    public init(script: [TurnResult]) { self.script = script }

    public nonisolated func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                                       toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let turn = await self.next(system: system, history: history, toolChoice: toolChoice)
                guard let turn else {
                    continuation.finish(throwing: ProviderError.malformedStream("mock script exhausted"))
                    return
                }
                for block in turn.content {
                    if case .text(let t) = block { continuation.yield(.textDelta(t)) }
                }
                continuation.yield(.turn(turn))
                continuation.finish()
            }
        }
    }

    private func next(system: String, history: [APIMessage], toolChoice: ToolChoice) -> TurnResult? {
        callCount += 1
        recordedSystems.append(system)
        recordedHistories.append(history)
        recordedToolChoices.append(toolChoice)
        return script.isEmpty ? nil : script.removeFirst()
    }
}
