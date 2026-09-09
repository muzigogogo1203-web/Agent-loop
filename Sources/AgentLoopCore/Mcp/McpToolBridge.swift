import Foundation

#if DEBUG
package struct McpBridgeAuditHooks: Sendable {
    package let onCall: @Sendable () -> Void

    package init(onCall: @escaping @Sendable () -> Void) {
        self.onCall = onCall
    }
}
#endif

/// MCP 工具到 ToolHandler 的信任边界。外部正文只在成功时进入
/// ExternalContent；失败只投影固定文案和可追踪的 typed failure。
public struct McpToolBridge: ToolHandler {
    private let manager: McpServerManager
    private let db: AppDatabase
    private let missionId: String
    private let cardId: String
    private let serverId: String
    private let serverName: String
    private let toolName: String
    private let campId: String?
    private let reporter: FailureReporter
    private let makeTrace: OperationTraceFactory
#if DEBUG
    private let auditHooks: McpBridgeAuditHooks?
#endif

    public init(
        manager: McpServerManager,
        db: AppDatabase,
        missionId: String,
        cardId: String,
        serverId: String,
        serverName: String,
        toolName: String,
        campId: String? = nil,
        reporter: FailureReporter? = nil
    ) {
        self.manager = manager
        self.db = db
        self.missionId = missionId
        self.cardId = cardId
        self.serverId = serverId
        self.serverName = serverName
        self.toolName = toolName
        self.campId = campId
        self.reporter = reporter ?? FailureReporter(database: db)
        makeTrace = .live
#if DEBUG
        auditHooks = nil
#endif
    }

#if DEBUG
    package init(
        manager: McpServerManager,
        db: AppDatabase,
        missionId: String,
        cardId: String,
        serverId: String,
        serverName: String,
        toolName: String,
        campId: String?,
        reporter: FailureReporter,
        makeTrace: OperationTraceFactory,
        auditHooks: McpBridgeAuditHooks
    ) {
        self.manager = manager
        self.db = db
        self.missionId = missionId
        self.cardId = cardId
        self.serverId = serverId
        self.serverName = serverName
        self.toolName = toolName
        self.campId = campId
        self.reporter = reporter
        self.makeTrace = makeTrace
        self.auditHooks = auditHooks
    }
#endif

    public func execute(input: JSONValue) async -> ToolOutcome {
        let trace = makeTrace.generated(
            operation: .mcpToolCall,
            scope: traceScope()
        )
#if DEBUG
        auditHooks?.onCall()
#endif
        let outcome = await manager.call(
            serverId: serverId,
            toolName: toolName,
            arguments: input
        )
        switch outcome {
        case .success(let call):
            return .result(
                ExternalContent.wrap(
                    source: "MCP·\(serverName)",
                    body: call.text
                )
            )
        case .failure(let error):
            let prepared = reporter.prepare(error, trace: trace)
            let persistence: FailurePersistence
            if case .connectionDown = error {
                do {
                    try db.persistMcpConnectionDown(
                        prepared,
                        missionId: missionId,
                        cardId: cardId,
                        serverId: serverId
                    )
                    persistence = .stored
                } catch {
                    persistence = reporter.persistPrepared(prepared)
                }
            } else {
                persistence = reporter.persistPrepared(prepared)
            }
            let failure = reporter.complete(
                prepared,
                persistence: persistence
            )
            return .error(Self.fixedMessage(
                for: error,
                visible: failure
            ))
        }
    }

    private func traceScope() -> FailureTraceScope {
        let serverResult = Result { try db.mcpServer(id: serverId) }
        guard case .success(.some(let server)) = serverResult else {
            return .fixed(.mcpRegistry)
        }
        let recordIDResult = Result { try FailureRecordID.mcpServer(server) }
        guard case .success(let serverRecordID) = recordIDResult else {
            return .fixed(.mcpRegistry)
        }
        if let campId {
            let campResult = Result { try db.camp(id: campId) }
            if case .success(.some(let camp)) = campResult {
                let scopeResult = Result {
                    try FailureTraceScope.camp(
                        campId: .camp(camp),
                        recordId: serverRecordID,
                        as: .mcpTool
                    )
                }
                if case .success(let scope) = scopeResult {
                    return scope
                }
            }
        }
        let globalResult = Result {
            try FailureTraceScope.global(
                recordId: serverRecordID,
                as: .mcpTool
            )
        }
        if case .success(let scope) = globalResult {
            return scope
        }
        return .fixed(.mcpRegistry)
    }

    private static func fixedMessage(
        for error: McpOperationError,
        visible: UserVisibleFailure
    ) -> String {
        switch error {
        case .connectionDown:
            return "驿站连接已中断。它不会自动重启；请在设置中手动重启。若无法绕开该工具，请用 block_card（reason=tool_failure）挂起。\n\(visible.message)"
        case .serverMaintenance:
            return "驿站正在维护，当前无法调用。\n\(visible.message)"
        default:
            return "驿站工具调用失败。\n\(visible.message)"
        }
    }
}
