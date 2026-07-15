import Foundation

public struct CardExecutionContext: Sendable {
    public let cardId: String
    public let companionName: String
    public let rolePrompt: String
    public let upstreamHandoffs: [UpstreamHandoff]
    public let answeredRequests: [(prompt: String, answer: String)]
    public let campNotes: [NoteSnippet]
    public let companionNotes: [NoteSnippet]
    public let toolAccess: ToolAccess
    public let searchKey: String?
    public let autonomy: MissionAutonomy
    public let externalTools: [ExternalTool]

    public init(
        cardId: String,
        companionName: String,
        rolePrompt: String,
        upstreamHandoffs: [UpstreamHandoff] = [],
        answeredRequests: [(prompt: String, answer: String)] = [],
        campNotes: [NoteSnippet] = [],
        companionNotes: [NoteSnippet] = [],
        toolAccess: ToolAccess = .full,
        searchKey: String? = nil,
        autonomy: MissionAutonomy = .standard,
        externalTools: [ExternalTool] = []
    ) {
        self.cardId = cardId
        self.companionName = companionName
        self.rolePrompt = rolePrompt
        self.upstreamHandoffs = upstreamHandoffs
        self.answeredRequests = answeredRequests
        self.campNotes = campNotes
        self.companionNotes = companionNotes
        self.toolAccess = toolAccess
        self.searchKey = searchKey
        self.autonomy = autonomy
        self.externalTools = externalTools
    }
}

public protocol CardExecutionBackend: Sendable {
    func run(context: CardExecutionContext) throws -> AsyncThrowingStream<AgentEvent, Error>
}

public struct ModelLoopBackend: CardExecutionBackend {
    private let runner: CardRunner

    public init(runner: CardRunner) {
        self.runner = runner
    }

    public func run(context: CardExecutionContext) throws -> AsyncThrowingStream<AgentEvent, Error> {
        try runner.run(
            cardId: context.cardId,
            companionName: context.companionName,
            rolePrompt: context.rolePrompt,
            upstreamHandoffs: context.upstreamHandoffs,
            answeredRequests: context.answeredRequests,
            campNotes: context.campNotes,
            companionNotes: context.companionNotes,
            toolAccess: context.toolAccess,
            searchKey: context.searchKey,
            autonomy: context.autonomy,
            externalTools: context.externalTools
        )
    }
}
