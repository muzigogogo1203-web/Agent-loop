import Foundation
import GRDB

package enum ContextToolSelectionProvenance: Sendable, Equatable {
    case explicitV2(Set<String>)
    case legacyInherited
}

package struct ContextDependencyRequest: Sendable {
    package let missionId: String
    package let cardId: String
    package let campId: String?
    package let companionId: String
    package let missionScope: FailureTraceScope
    package let cardScope: FailureTraceScope
    package let campScope: FailureTraceScope?
    package let companionScope: FailureTraceScope
    package let runtimeProfileKind: RuntimeProfileKind
    package let toolAccess: ToolAccess
    package let toolsJson: String
    fileprivate let campRecordID: FailureRecordID?
    fileprivate let companionRecordID: FailureRecordID

    package init(
        mission: MissionRecord,
        card: CardRecord,
        camp: CampRecord?,
        companion: CompanionRecord,
        runtimeProfileKind: RuntimeProfileKind,
        toolAccess: ToolAccess,
        toolsJson: String
    ) throws {
        guard card.missionId == mission.id,
              card.assigneeId == companion.id,
              camp.map({ companion.campId == $0.id }) ?? true
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        let missionID = try FailureRecordID.mission(mission)
        let cardID = try FailureRecordID.card(card)
        let companionID = try FailureRecordID.companion(companion)
        companionRecordID = companionID
        if let camp {
            let campID = try FailureRecordID.camp(camp)
            campRecordID = campID
            missionScope = try .camp(
                campId: campID,
                recordId: missionID,
                as: .mission
            )
            cardScope = try .camp(
                campId: campID,
                recordId: cardID,
                as: .card
            )
            campScope = try .global(recordId: campID, as: .camp)
            companionScope = try .camp(
                campId: campID,
                recordId: companionID,
                as: .companion
            )
        } else {
            campRecordID = nil
            missionScope = try .global(recordId: missionID, as: .mission)
            cardScope = try .global(recordId: cardID, as: .card)
            campScope = nil
            companionScope = try .global(
                recordId: companionID,
                as: .companion
            )
        }
        missionId = mission.id
        cardId = card.id
        campId = camp?.id
        companionId = companion.id
        self.runtimeProfileKind = runtimeProfileKind
        self.toolAccess = toolAccess
        self.toolsJson = toolsJson
    }
}

package enum ContextDependencyCoordinate: Sendable, Equatable {
    case search
    case campNotes(FailureRecordID)
    case companionNotes(FailureRecordID)
    case mcpRegistry
    case mcpServer(FailureRecordID)
    case mcpTool(FailureRecordID)

    package var durableId: String {
        switch self {
        case .search:
            return "search"
        case .mcpRegistry:
            return "mcpRegistry"
        case .campNotes(let id), .companionNotes(let id),
             .mcpServer(let id), .mcpTool(let id):
            return id.rawValue
        }
    }
}

public struct ContextDegradationNotice: Sendable, Equatable {
    public let degradationId: String
    public let missionId: String?
    public let cardId: String
    public let dependencyType: ContextDependencyType
    public let policy: ContextDependencyPolicy
    public let failure: UserVisibleFailure

    package init(
        degradationId: String,
        missionId: String?,
        cardId: String,
        dependencyType: ContextDependencyType,
        policy: ContextDependencyPolicy,
        failure: UserVisibleFailure
    ) {
        self.degradationId = degradationId
        self.missionId = missionId
        self.cardId = cardId
        self.dependencyType = dependencyType
        self.policy = policy
        self.failure = failure
    }
}

package struct ContextDependencyReady: Sendable {
    package let campNotes: [NoteSnippet]
    package let companionNotes: [NoteSnippet]
    package let searchKey: String?
    package let externalTools: [ExternalTool]
    package let degradations: [ContextDegradationNotice]

    package init(
        campNotes: [NoteSnippet],
        companionNotes: [NoteSnippet],
        searchKey: String?,
        externalTools: [ExternalTool],
        degradations: [ContextDegradationNotice]
    ) {
        self.campNotes = campNotes
        self.companionNotes = companionNotes
        self.searchKey = searchKey
        self.externalTools = externalTools
        self.degradations = degradations
    }
}

package enum ContextDependencyResult: Sendable {
    case ready(ContextDependencyReady)
    case blocked(failure: UserVisibleFailure, suppressForSession: Bool)
}

package struct ContextKnowledgeReaders: Sendable {
    package let camp: @Sendable (String) throws -> [NoteSnippet]
    package let companion: @Sendable (String) throws -> [NoteSnippet]

    package init(
        camp: @escaping @Sendable (String) throws -> [NoteSnippet],
        companion: @escaping @Sendable (String) throws -> [NoteSnippet]
    ) {
        self.camp = camp
        self.companion = companion
    }

    package static func live(database: AppDatabase) -> Self {
        Self(
            camp: { campId in
                let notes = try database.pinnedAndRecentCampNotes(
                    campId: campId
                )
                return NoteSnippet.from(
                    pinned: notes.pinned,
                    recent: notes.recent
                )
            },
            companion: { companionId in
                let notes = try database.pinnedAndRecentCompanionNotes(
                    companionId: companionId
                )
                return NoteSnippet.from(
                    pinned: notes.pinned,
                    recent: notes.recent
                )
            }
        )
    }
}

package typealias ContextTraceFactory = @Sendable
    (FailureOperation, FailureTraceScope) -> OperationTrace

package protocol ContextDependencyLoading: Sendable {
    func load(
        _ request: ContextDependencyRequest,
        onOptionalDegradation: @escaping @Sendable
            (ContextDegradationNotice) async -> Void
    ) async -> ContextDependencyResult
}

package enum ContextDependencyLoadError: Error, Sendable, Equatable {
    case searchCredentialMissing
    case searchCredentialRead(osStatus: Int32?)
    case knowledgeRead(
        dependencyType: ContextDependencyType,
        grdbResultCode: Int32?
    )
}

package struct McpRequiredToolMissingError: Error, Sendable, Equatable {
    package let serverId: String

    package init(serverId: String) {
        self.serverId = serverId
    }
}

package struct EngineApprovalRequiredToolHandlerV1: ToolHandler {
    package init() {}

    package func execute(input: JSONValue) async -> ToolOutcome {
        _ = input
        return .error("engine_approval_required")
    }
}

package struct ContextDependencyLoader:
    ContextDependencyLoading, Sendable
{
    private let database: AppDatabase
    private let reporter: FailureReporter
    private let searchCredential: @Sendable () throws -> String?
    private let knowledge: ContextKnowledgeReaders
    private let makeTrace: ContextTraceFactory

    package init(
        database: AppDatabase,
        manager: McpServerManager?,
        reporter: FailureReporter,
        searchCredential: @escaping @Sendable () throws -> String?,
        knowledge: ContextKnowledgeReaders,
        makeTrace: @escaping ContextTraceFactory
    ) {
        _ = manager
        self.database = database
        self.reporter = reporter
        self.searchCredential = searchCredential
        self.knowledge = knowledge
        self.makeTrace = makeTrace
    }

    package func load(
        _ request: ContextDependencyRequest,
        onOptionalDegradation: @escaping @Sendable
            (ContextDegradationNotice) async -> Void
    ) async -> ContextDependencyResult {
        let provenance = Self.selectionProvenance(request)
        if request.toolAccess.parseFailed {
            let trace = makeTrace(.contextToolAccess, request.cardScope)
            return requiredFailure(
                ProjectionContractError.invalidPayload,
                trace: trace,
                coordinate: .mcpRegistry,
                dependencyType: .mcpServer,
                request: request
            )
        }

        let explicitCapabilities: Set<String>
        switch provenance {
        case .explicitV2(let capabilities):
            explicitCapabilities = capabilities
        case .legacyInherited:
            explicitCapabilities = []
        }
        let selectedRequired = explicitCapabilities.filter {
            $0 == "web_search" || $0.hasPrefix("mcp__")
        }.sorted(by: Self.utf8Less)

        var searchKey: String?
        if selectedRequired.contains("web_search") {
            let trace = makeTrace(.contextSearch, request.cardScope)
            let read = Result { try searchCredential() }
            switch read {
            case .success(.some(let value)) where !value.isEmpty:
                searchKey = value
            case .success:
                return requiredFailure(
                    ContextDependencyLoadError.searchCredentialMissing,
                    trace: trace,
                    coordinate: .search,
                    dependencyType: .search,
                    request: request
                )
            case .failure(let error):
                let status = (error as? KeychainError).map {
                    Int32($0.status)
                }
                return requiredFailure(
                    ContextDependencyLoadError.searchCredentialRead(
                        osStatus: status
                    ),
                    trace: trace,
                    coordinate: .search,
                    dependencyType: .search,
                    request: request
                )
            }
        }

        let mcpSelection = selectedRequired.filter { $0.hasPrefix("mcp__") }
        let toolsResult = await resolveMcpTools(
            selectedNames: mcpSelection,
            request: request
        )
        let externalTools: [ExternalTool]
        switch toolsResult {
        case .ready(let tools):
            externalTools = tools
        case .blocked(let result):
            return result
        }

        var campNotes: [NoteSnippet] = []
        var companionNotes: [NoteSnippet] = []
        var degradations: [ContextDegradationNotice] = []

        if let campId = request.campId,
           let campScope = request.campScope,
           let campRecordID = request.campRecordID
        {
            let trace = makeTrace(.contextCampNotes, campScope)
            let read = Result { try knowledge.camp(campId) }
            switch read {
            case .success(let notes):
                campNotes = notes
            case .failure(let error):
                let typed = ContextDependencyLoadError.knowledgeRead(
                    dependencyType: .campNote,
                    grdbResultCode: Self.databaseCode(error)
                )
                switch persistFailure(
                    typed,
                    trace: trace,
                    coordinate: .campNotes(
                        campRecordID
                    ),
                    dependencyType: .campNote,
                    policy: .optionalApproved,
                    request: request
                ) {
                case .committed(let notice):
                    await onOptionalDegradation(notice)
                    degradations.append(notice)
                    campNotes.append(Self.missingMarker(notice.failure))
                case .suppressed(let failure):
                    return .blocked(
                        failure: failure,
                        suppressForSession: true
                    )
                }
            }
        }

        let companionTrace = makeTrace(
            .contextCompanionNotes,
            request.companionScope
        )
        let companionRead = Result {
            try knowledge.companion(request.companionId)
        }
        switch companionRead {
        case .success(let notes):
            companionNotes = notes
        case .failure(let error):
            let typed = ContextDependencyLoadError.knowledgeRead(
                dependencyType: .companionNote,
                grdbResultCode: Self.databaseCode(error)
            )
            switch persistFailure(
                typed,
                trace: companionTrace,
                coordinate: .companionNotes(
                    request.companionRecordID
                ),
                dependencyType: .companionNote,
                policy: .optionalApproved,
                request: request
            ) {
            case .committed(let notice):
                await onOptionalDegradation(notice)
                degradations.append(notice)
                companionNotes.append(Self.missingMarker(notice.failure))
            case .suppressed(let failure):
                return .blocked(
                    failure: failure,
                    suppressForSession: true
                )
            }
        }

        return .ready(ContextDependencyReady(
            campNotes: campNotes,
            companionNotes: companionNotes,
            searchKey: searchKey,
            externalTools: externalTools,
            degradations: degradations
        ))
    }

    private func resolveMcpTools(
        selectedNames: [String],
        request: ContextDependencyRequest
    ) async -> McpResolution {
        guard !selectedNames.isEmpty else { return .ready([]) }
        let registryTrace = makeTrace(
            .contextMcpServer,
            .fixed(.mcpRegistry)
        )
        let inputSchema = JSONValue.object([
            "additionalProperties": true,
            "properties": .object([:]),
            "type": "object",
        ])
        var output: [ExternalTool] = []
        output.reserveCapacity(selectedNames.count)
        for selected in selectedNames.sorted(by: Self.utf8Less) {
            guard let parsed = McpToolNaming.parse(selected),
                  McpToolNaming.compose(
                    server: parsed.server,
                    tool: parsed.tool
                  ) == selected
            else {
                return .blocked(requiredFailure(
                    ProjectionContractError.invalidPayload,
                    trace: registryTrace,
                    coordinate: .mcpRegistry,
                    dependencyType: .mcpServer,
                    request: request
                ))
            }
            output.append(ExternalTool(
                def: ToolDef(
                    name: selected,
                    description: "Unavailable in F1D engine execution.",
                    inputSchema: inputSchema
                ),
                handler: EngineApprovalRequiredToolHandlerV1()
            ))
        }
        return .ready(output)
    }

    private func requiredFailure(
        _ error: any Error,
        trace: OperationTrace,
        coordinate: ContextDependencyCoordinate,
        dependencyType: ContextDependencyType,
        request: ContextDependencyRequest
    ) -> ContextDependencyResult {
        switch persistFailure(
            error,
            trace: trace,
            coordinate: coordinate,
            dependencyType: dependencyType,
            policy: .required,
            request: request
        ) {
        case .committed(let notice):
            return .blocked(
                failure: notice.failure,
                suppressForSession: false
            )
        case .suppressed(let failure):
            return .blocked(
                failure: failure,
                suppressForSession: true
            )
        }
    }

    private func persistFailure(
        _ error: any Error,
        trace: OperationTrace,
        coordinate: ContextDependencyCoordinate,
        dependencyType: ContextDependencyType,
        policy: ContextDependencyPolicy,
        request: ContextDependencyRequest
    ) -> ContextPersistenceResult {
        let prepared = reporter.prepare(error, trace: trace)
        let degradationID = UUID().uuidString
        let recordResult = Result {
            try ContextDegradationRecord(
                id: degradationID,
                missionId: request.missionId,
                cardId: request.cardId,
                dependencyType: dependencyType,
                dependencyId: coordinate.durableId,
                policy: policy,
                traceId: trace.traceId,
                detail: prepared.visible.message,
                createdAt: Date(),
                redactedAt: nil
            )
        }
        guard case .success(let degradation) = recordResult else {
            let persistence = reporter.persistPrepared(prepared)
            return .suppressed(reporter.complete(
                prepared,
                persistence: persistence
            ))
        }
        let write = Result {
            try database.persistContextFailure(
                prepared,
                degradation: degradation,
                cardId: request.cardId,
                disposition: policy == .required ? .block : .leaveReady
            )
        }
        switch write {
        case .success:
            let visible = reporter.complete(
                prepared,
                persistence: .stored
            )
            return .committed(ContextDegradationNotice(
                degradationId: degradationID,
                missionId: request.missionId,
                cardId: request.cardId,
                dependencyType: dependencyType,
                policy: policy,
                failure: visible
            ))
        case .failure:
            let persistence = reporter.persistPrepared(prepared)
            return .suppressed(reporter.complete(
                prepared,
                persistence: persistence
            ))
        }
    }

    private static func selectionProvenance(
        _ request: ContextDependencyRequest
    ) -> ContextToolSelectionProvenance {
        let decoded = Result { try JSONValue.decoded(from: request.toolsJson) }
        guard case .success(.object(let object)) = decoded,
              Set(object.keys) == ["allow", "v"],
              object["v"]?.intValue == 2,
              let rawAllow = object["allow"]?.arrayValue,
              rawAllow.allSatisfy({ $0.stringValue != nil })
        else {
            return .legacyInherited
        }
        let allow = Set(rawAllow.compactMap(\.stringValue))
        guard !request.toolAccess.parseFailed,
              allow == request.toolAccess.capabilities
        else {
            return .legacyInherited
        }
        return .explicitV2(allow)
    }

    private static func serverScope(
        request: ContextDependencyRequest,
        recordID: FailureRecordID
    ) -> FailureTraceScope {
        if let campID = request.campRecordID {
            let scope = Result {
                try FailureTraceScope.camp(
                    campId: campID,
                    recordId: recordID,
                    as: .mcpServer
                )
            }
            if case .success(let value) = scope { return value }
        }
        let global = Result {
            try FailureTraceScope.global(
                recordId: recordID,
                as: .mcpServer
            )
        }
        if case .success(let value) = global { return value }
        return .fixed(.mcpRegistry)
    }

    private static func missingMarker(
        _ failure: UserVisibleFailure
    ) -> NoteSnippet {
        NoteSnippet(
            title: "上下文降级",
            body: "可选上下文暂时不可用。追踪 ID：\(failure.traceId)"
        )
    }

    private static func utf8Less(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private static func databaseCode(_ error: any Error) -> Int32? {
        (error as? DatabaseError)?.extendedResultCode.rawValue
    }

}

private enum McpResolution {
    case ready([ExternalTool])
    case blocked(ContextDependencyResult)
}

private enum ContextPersistenceResult {
    case committed(ContextDegradationNotice)
    case suppressed(UserVisibleFailure)
}
