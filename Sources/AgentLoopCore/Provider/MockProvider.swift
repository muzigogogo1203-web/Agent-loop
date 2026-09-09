/// Scripted-replay test double. Single-consumer: early cancellation still consumes a script entry and bumps callCount.
public actor MockProvider: LLMProvider, LLMProviderRunDrivingV1 {
    private var script: [TurnResult]
    public private(set) var callCount = 0
    public private(set) var recordedHistories: [[APIMessage]] = []
    public private(set) var recordedToolChoices: [ToolChoice] = []
    public private(set) var recordedSystems: [String] = []
    public private(set) var recordedTools: [[ToolDef]] = []

    public init(script: [TurnResult]) { self.script = script }

    public nonisolated func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                                       toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        startTurn(
            system: system,
            history: history,
            tools: tools,
            toolChoice: toolChoice,
            maxTokens: maxTokens
        ).events
    }

    package nonisolated func startTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> LLMProviderTurnRunV1 {
        makeLLMProviderTurnRunV1 { continuation in
            let turn = await self.next(
                system: system,
                history: history,
                tools: tools,
                toolChoice: toolChoice
            )
            guard let turn else {
                throw ProviderError.malformedStream("mock script exhausted")
            }
            for block in turn.content {
                if case .text(let text) = block {
                    continuation.yield(.textDelta(text))
                }
            }
            continuation.yield(.turn(turn))
        }
    }

    private func next(system: String, history: [APIMessage], tools: [ToolDef],
                      toolChoice: ToolChoice) -> TurnResult? {
        callCount += 1
        recordedSystems.append(system)
        recordedHistories.append(history)
        recordedTools.append(tools)
        recordedToolChoices.append(toolChoice)
        return script.isEmpty ? nil : script.removeFirst()
    }
}
