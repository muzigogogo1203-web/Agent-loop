import Foundation
import AgentLoopCore

package enum McpServerStatusSummary: Sendable, Equatable {
    case stopped
    case starting
    case running(toolCount: Int)
    case down
}

package struct McpRegistrySnapshot: Sendable {
    package let servers: [McpServerRecord]
    package let statuses: [String: McpServerStatusSummary]

    package init(
        servers: [McpServerRecord],
        statuses: [String: McpServerStatusSummary]
    ) {
        self.servers = servers
        self.statuses = statuses
    }
}

package struct McpCampSnapshot: Sendable, Equatable {
    package let campId: String
    package let enabledServerIds: Set<String>

    package init(campId: String, enabledServerIds: Set<String>) {
        self.campId = campId
        self.enabledServerIds = enabledServerIds
    }
}

package struct McpToolSnapshot: Sendable {
    package let serverId: String
    package let tools: [McpServerManager.AssembledTool]

    package init(
        serverId: String,
        tools: [McpServerManager.AssembledTool]
    ) {
        self.serverId = serverId
        self.tools = tools
    }
}

package struct CompanionEditorSnapshot: Sendable {
    package let companion: CompanionRecord
    package let toolAccess: ToolAccess
    package let selectedProfile: RuntimeProfileRecord
    package let availableModels: [String]
    package let modelSelection: CompanionEditorModelSelection

    package init(
        companion: CompanionRecord,
        toolAccess: ToolAccess,
        selectedProfile: RuntimeProfileRecord,
        availableModels: [String],
        modelSelection: CompanionEditorModelSelection
    ) {
        self.companion = companion
        self.toolAccess = toolAccess
        self.selectedProfile = selectedProfile
        self.availableModels = availableModels
        self.modelSelection = modelSelection
    }
}

package enum CompanionEditorModelSelection: Sendable, Equatable {
    case preserved(String)
    case selectedFirstForMissingValue(String)
    case manualEntryRequired
}

package enum McpServerDraftConfiguration: Sendable, Equatable {
    case template(
        args: [String],
        env: [String: String],
        secretEnvironmentKeys: [String]
    )
    case custom(
        argsLine: String,
        envLines: String,
        secretKeysLine: String
    )
}

package struct McpServerDraft: Sendable, Equatable {
    package let name: String
    package let command: String
    package let configuration: McpServerDraftConfiguration
    package let experimental: Bool

    package init(
        name: String,
        command: String,
        configuration: McpServerDraftConfiguration,
        experimental: Bool
    ) {
        self.name = name
        self.command = command
        self.configuration = configuration
        self.experimental = experimental
    }
}

package enum McpSecretMutation: Sendable, Equatable {
    case set(SecretValue)
    case delete
}

package struct McpSecretMutationReceipt: Sendable, Equatable {
    package let serverId: String
    package let present: Bool

    package init(serverId: String, present: Bool) {
        self.serverId = serverId
        self.present = present
    }
}

package struct McpServerDeletionReceipt: Sendable, Equatable {
    package let serverId: String

    init(cleanedLease: McpMaintenanceLease) {
        serverId = cleanedLease.serverId
    }
}

package struct McpServerDeletionRetryReceipt: Sendable, Equatable {
    package let serverId: String

    init(cleanedRollback: McpPendingRollbackCleanup) {
        serverId = cleanedRollback.serverId
    }
}

package struct McpPendingRollbackCleanup: Sendable, Equatable {
    package let serverId: String
    let traceScope: FailureTraceScope
    let lease: McpMaintenanceLease

    init(lease: McpMaintenanceLease, traceScope: FailureTraceScope) {
        serverId = lease.serverId
        self.traceScope = traceScope
        self.lease = lease
    }
}

package struct McpPendingDeletedServerCleanup: Sendable, Equatable {
    package let serverId: String
    let traceScope: FailureTraceScope
    let lease: McpMaintenanceLease

    init(lease: McpMaintenanceLease, traceScope: FailureTraceScope) {
        serverId = lease.serverId
        self.traceScope = traceScope
        self.lease = lease
    }
}

package enum McpPendingServerCleanup: Sendable, Equatable {
    case rollback(McpPendingRollbackCleanup)
    case deleted(McpPendingDeletedServerCleanup)

    package var serverId: String {
        switch self {
        case .rollback(let value): value.serverId
        case .deleted(let value): value.serverId
        }
    }

    var traceScope: FailureTraceScope {
        switch self {
        case .rollback(let value): value.traceScope
        case .deleted(let value): value.traceScope
        }
    }
}

package enum McpServerDeletionPortResult: Sendable, Equatable {
    case notCommitted(McpServerDeletionFailure)
    case notCommittedCleanupPending(
        primary: McpCredentialDeletionError,
        cleanup: McpMaintenanceCleanupError,
        pending: McpPendingRollbackCleanup
    )
    case committed(McpServerDeletionReceipt)
    case committedCleanupPending(
        cleanup: McpMaintenanceCleanupError,
        pending: McpPendingDeletedServerCleanup
    )
}

package enum McpServerDeletionOutcome: Sendable, Equatable {
    case notCommitted(UserVisibleFailure)
    case notCommittedCleanupPending(
        pending: McpPendingRollbackCleanup,
        failure: UserVisibleFailure
    )
    case committed(McpServerDeletionReceipt)
    case committedCleanupPending(
        pending: McpPendingDeletedServerCleanup,
        failure: UserVisibleFailure
    )
}

package enum McpServerCleanupOutcome: Sendable, Equatable {
    case deletionRetryReady(McpServerDeletionRetryReceipt)
    case deletionCommitted(McpServerDeletionReceipt)
    case pending(
        McpPendingServerCleanup,
        failure: UserVisibleFailure
    )
}

package enum McpCleanupApplyGuard {
    package static func mayApply(
        currentPending: McpPendingServerCleanup?,
        capturedPending: McpPendingServerCleanup,
        currentAttempt: UUID?,
        capturedAttempt: UUID
    ) -> Bool {
        currentPending == capturedPending
            && currentAttempt == capturedAttempt
    }
}

package struct McpWorkflowReads: Sendable {
    package let registry: @Sendable () async throws -> McpRegistrySnapshot
    package let enabled: @Sendable (String) throws -> Set<String>
    package let tools: @Sendable (String) async throws
        -> [McpServerManager.AssembledTool]
    package let secret: @Sendable (
        McpCredentialAccount,
        KeychainInteractionPolicy
    ) throws -> Bool
    package let companionEditor:
        @Sendable (String) throws -> CompanionEditorSnapshot

    package init(
        registry: @escaping @Sendable () async throws
            -> McpRegistrySnapshot,
        enabled: @escaping @Sendable (String) throws -> Set<String>,
        tools: @escaping @Sendable (String) async throws
            -> [McpServerManager.AssembledTool],
        secret: @escaping @Sendable (
            McpCredentialAccount,
            KeychainInteractionPolicy
        ) throws -> Bool,
        companionEditor: @escaping @Sendable (String) throws
            -> CompanionEditorSnapshot
    ) {
        self.registry = registry
        self.enabled = enabled
        self.tools = tools
        self.secret = secret
        self.companionEditor = companionEditor
    }

    package static func live(
        database: AppDatabase,
        manager: McpServerManager,
        access: SynchronizedCredentialAccess,
        defaults: ProfileScopedDefaults
    ) -> Self {
        Self(
            registry: {
                let servers = try database.mcpServers()
                let statuses = await manager.statuses()
                let summaries = Dictionary(uniqueKeysWithValues:
                    servers.map { server in
                        let summary: McpServerStatusSummary
                        switch statuses[server.id] ?? .stopped {
                        case .stopped:
                            summary = .stopped
                        case .starting:
                            summary = .starting
                        case .running(let count):
                            summary = .running(toolCount: count)
                        case .down:
                            summary = .down
                        }
                        return (server.id, summary)
                    }
                )
                return McpRegistrySnapshot(
                    servers: servers,
                    statuses: summaries
                )
            },
            enabled: { try database.enabledMcpServerIds(campId: $0) },
            tools: { try await manager.assembledTools(serverId: $0) },
            secret: { account, policy in
                try access.read(
                    account: account.rawValue,
                    interactionPolicy: policy
                ) != nil
            },
            companionEditor: { companionId in
                guard let companion = try database.companion(id: companionId)
                else {
                    throw RecordNotFoundError(
                        table: CompanionRecord.databaseTableName,
                        id: companionId
                    )
                }
                let toolAccess = ToolAccess.parse(
                    toolsJson: companion.toolsJson
                )
                guard !toolAccess.parseFailed else {
                    throw ProjectionContractError.invalidPayload
                }
                let profile: RuntimeProfileRecord
                if let profileId = companion.runtimeProfileId {
                    guard let selected = try database.runtimeProfile(
                        id: profileId
                    ) else {
                        throw RuntimeProfileStoreError.profileNotFound(
                            profileId
                        )
                    }
                    profile = selected
                } else {
                    guard let selected = try database.defaultProfile() else {
                        throw RuntimeProfileStoreError.defaultProfileNotFound
                    }
                    profile = selected
                }
                let models = ModelCatalogService.resolvedCatalog(
                    profile: profile,
                    defaults: defaults,
                    fallback: []
                )
                let selected = companion.model.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let selection: CompanionEditorModelSelection
                if !selected.isEmpty {
                    selection = .preserved(companion.model)
                } else if let first = models.first {
                    selection = .selectedFirstForMissingValue(first)
                } else {
                    selection = .manualEntryRequired
                }
                return CompanionEditorSnapshot(
                    companion: companion,
                    toolAccess: toolAccess,
                    selectedProfile: profile,
                    availableModels: models,
                    modelSelection: selection
                )
            }
        )
    }
}

package struct McpWorkflowPorts: Sendable {
    package let addServer:
        @Sendable (McpServerDraft) throws -> McpServerRecord
    package let startServer:
        @Sendable (String) async throws -> McpServerReady
    package let restartServer:
        @Sendable (String) async throws -> McpServerReady
    package let setEnabled:
        @Sendable (String, String, Bool) throws -> Void
    package let mutateSecret:
        @Sendable (
            String,
            String,
            McpSecretMutation,
            KeychainInteractionPolicy
        ) throws -> McpSecretMutationReceipt
    package let deleteServer:
        @Sendable (
            String,
            KeychainInteractionPolicy,
            FailureTraceScope
        ) async -> McpServerDeletionPortResult
    package let finishServerCleanup:
        @Sendable (McpPendingServerCleanup) async
            -> Result<Void, McpMaintenanceCleanupError>
    package let saveCompanion:
        @Sendable (CompanionRecord) throws -> CompanionRecord

    package init(
        addServer: @escaping @Sendable (McpServerDraft) throws
            -> McpServerRecord,
        startServer: @escaping @Sendable (String) async throws
            -> McpServerReady,
        restartServer: @escaping @Sendable (String) async throws
            -> McpServerReady,
        setEnabled: @escaping @Sendable (String, String, Bool) throws
            -> Void,
        mutateSecret: @escaping @Sendable (
            String,
            String,
            McpSecretMutation,
            KeychainInteractionPolicy
        ) throws -> McpSecretMutationReceipt,
        deleteServer: @escaping @Sendable (
            String,
            KeychainInteractionPolicy,
            FailureTraceScope
        ) async -> McpServerDeletionPortResult,
        finishServerCleanup: @escaping @Sendable (
            McpPendingServerCleanup
        ) async -> Result<Void, McpMaintenanceCleanupError>,
        saveCompanion: @escaping @Sendable (CompanionRecord) throws
            -> CompanionRecord
    ) {
        self.addServer = addServer
        self.startServer = startServer
        self.restartServer = restartServer
        self.setEnabled = setEnabled
        self.mutateSecret = mutateSecret
        self.deleteServer = deleteServer
        self.finishServerCleanup = finishServerCleanup
        self.saveCompanion = saveCompanion
    }

    package static func live(
        database: AppDatabase,
        manager: McpServerManager,
        credentialCoordinator: CredentialBundleCoordinator,
        reads: McpWorkflowReads
    ) -> Self {
        _ = reads
        return Self(
            addServer: { draft in
                let record = try Self.record(from: draft)
                try database.addMcpServer(record)
                return record
            },
            startServer: { serverId in
                let results = await manager.ensureRunning(
                    serverIds: [serverId]
                )
                guard results.count == 1,
                      results[0].serverId == serverId
                else {
                    throw ProjectionContractError.invalidPayload
                }
                return try results[0].result.get()
            },
            restartServer: { serverId in
                try await manager.restart(serverId: serverId).get()
            },
            setEnabled: { campId, serverId, enabled in
                try database.setMcpServerEnabled(
                    campId: campId,
                    serverId: serverId,
                    enabled: enabled
                )
            },
            mutateSecret: { serverId, key, mutation, _ in
                guard let server = try database.mcpServer(id: serverId)
                else {
                    throw McpOperationError.serverMissing(
                        serverId: serverId
                    )
                }
                let account = try McpCredentialAccount(
                    server: server,
                    secretEnvironmentKey: key
                )
                switch mutation {
                case .set(let value):
                    try credentialCoordinator.setMcpCredential(
                        value,
                        account: account
                    )
                    return McpSecretMutationReceipt(
                        serverId: serverId,
                        present: true
                    )
                case .delete:
                    try credentialCoordinator.deleteMcpCredential(
                        account: account
                    )
                    return McpSecretMutationReceipt(
                        serverId: serverId,
                        present: false
                    )
                }
            },
            deleteServer: { serverId, policy, traceScope in
                let server: McpServerRecord
                let serverResult: Result<McpServerRecord?, any Error> =
                    await Task {
                    try database.mcpServer(id: serverId)
                }.result
                switch serverResult {
                case .success(let loaded?):
                    server = loaded
                case .success(nil):
                    return .notCommitted(.maintenance(
                        .serverMissing(serverId: serverId)
                    ))
                case .failure:
                    return .notCommitted(.maintenance(
                        .registryRead(serverId: serverId)
                    ))
                }
                let keys: [String]
                let keysResult: Result<[String], any Error> = await Task {
                    try JSONDecoder().decode(
                        [String].self,
                        from: Data(server.secretEnvKeysJson.utf8)
                    )
                }.result
                switch keysResult {
                case .success(let decoded):
                    keys = decoded
                case .failure:
                    return .notCommitted(.maintenance(
                        .invalidConfig(
                            serverId: serverId,
                            field: .secretEnvKeys
                        )
                    ))
                }
                let accounts: [McpCredentialAccount]
                let accountsResult:
                    Result<[McpCredentialAccount], any Error> = await Task {
                    try keys.map {
                        try McpCredentialAccount(
                            server: server,
                            secretEnvironmentKey: $0
                        )
                    }
                }.result
                switch accountsResult {
                case .success(let validated):
                    accounts = validated
                case .failure(let error as McpOperationError):
                    return .notCommitted(.maintenance(error))
                case .failure:
                    return .notCommitted(.maintenance(
                        .invalidConfig(
                            serverId: serverId,
                            field: .secretEnvKeys
                        )
                    ))
                }
                let acquired = await manager.acquireMaintenance(
                    serverId: serverId
                )
                let lease: McpMaintenanceLease
                switch acquired {
                case .success(let value):
                    lease = value
                case .failure(let error):
                    return .notCommitted(.maintenance(error))
                }
                let deletion = await credentialCoordinator
                    .commitMcpServerDeletion(
                        secretAccounts: accounts,
                        interactionPolicy: policy,
                        deleteDatabaseRow: {
                            try database.deleteMcpServer(id: serverId)
                        }
                    )
                switch deletion {
                case .failure(let primary):
                    let cleanup = await manager.finishMaintenance(
                        lease,
                        completion: .keepStopped
                    )
                    switch cleanup {
                    case .success:
                        return .notCommitted(.credential(primary))
                    case .failure(let cleanupError):
                        return .notCommittedCleanupPending(
                            primary: primary,
                            cleanup: cleanupError,
                            pending: McpPendingRollbackCleanup(
                                lease: lease,
                                traceScope: traceScope
                            )
                        )
                    }
                case .success:
                    let cleanup = await manager.finishMaintenance(
                        lease,
                        completion: .removeHandle
                    )
                    switch cleanup {
                    case .success:
                        return .committed(McpServerDeletionReceipt(
                            cleanedLease: lease
                        ))
                    case .failure(let cleanupError):
                        return .committedCleanupPending(
                            cleanup: cleanupError,
                            pending: McpPendingDeletedServerCleanup(
                                lease: lease,
                                traceScope: traceScope
                            )
                        )
                    }
                }
            },
            finishServerCleanup: { pending in
                switch pending {
                case .rollback(let value):
                    return await manager.finishMaintenance(
                        value.lease,
                        completion: .keepStopped
                    )
                case .deleted(let value):
                    return await manager.finishMaintenance(
                        value.lease,
                        completion: .removeHandle
                    )
                }
            },
            saveCompanion: { companion in
                try database.saveCompanion(companion)
                return companion
            }
        )
    }

    private static func record(
        from draft: McpServerDraft
    ) throws -> McpServerRecord {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = draft.command.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty, !command.isEmpty else {
            throw McpOperationError.invalidConfig(
                serverId: "draft",
                field: .args
            )
        }
        let args: [String]
        let env: [String: String]
        let secretKeys: [String]
        switch draft.configuration {
        case .template(let templateArgs, let templateEnv, let templateKeys):
            args = templateArgs
            env = templateEnv
            secretKeys = templateKeys
        case .custom(let argsLine, let envLines, let secretKeysLine):
            args = argsLine.split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            var parsedEnv: [String: String] = [:]
            for rawLine in envLines.split(
                whereSeparator: { $0.isNewline }
            ) {
                let line = String(rawLine).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !line.isEmpty,
                      line.filter({ $0 == "=" }).count == 1,
                      let separator = line.firstIndex(of: "=")
                else {
                    throw McpOperationError.invalidConfig(
                        serverId: "draft",
                        field: .env
                    )
                }
                let key = String(line[..<separator]).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let value = String(line[line.index(after: separator)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !value.isEmpty,
                      parsedEnv.updateValue(value, forKey: key) == nil
                else {
                    throw McpOperationError.invalidConfig(
                        serverId: "draft",
                        field: .env
                    )
                }
            }
            env = parsedEnv
            secretKeys = secretKeysLine.split(whereSeparator: {
                $0 == "," || $0.isWhitespace
            }).map(String.init)
        }
        guard env.keys.allSatisfy({ !$0.isEmpty }),
              env.values.allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }),
              Set(secretKeys).count == secretKeys.count
        else {
            throw McpOperationError.invalidConfig(
                serverId: "draft",
                field: .env
            )
        }
        return McpServerRecord.new(
            name: name,
            command: command,
            args: args,
            env: env,
            secretEnvKeys: secretKeys,
            experimental: draft.experimental
        )
    }
}

private struct McpCleanupFlight: Sendable {
    let attemptId: UUID
    let pending: McpPendingServerCleanup
    let task: Task<Result<Void, McpMaintenanceCleanupError>, Never>
}

package actor McpWorkflowController {
    private let reporter: FailureReporter
    private let reads: McpWorkflowReads
    private let ports: McpWorkflowPorts
    private let traceFactory: OperationTraceFactory
    private var cleanupFlightByServerId: [String: McpCleanupFlight] = [:]

    package init(
        database: AppDatabase,
        manager: McpServerManager,
        credentialCoordinator: CredentialBundleCoordinator,
        reporter: FailureReporter,
        reads: McpWorkflowReads? = nil,
        ports: McpWorkflowPorts? = nil,
        traceFactory: OperationTraceFactory = .live
    ) {
        let selectedReads = reads ?? .live(
            database: database,
            manager: manager,
            access: credentialCoordinator.synchronizedAccess,
            defaults: ProfileScopedDefaults()
        )
        self.reporter = reporter
        self.reads = selectedReads
        self.ports = ports ?? .live(
            database: database,
            manager: manager,
            credentialCoordinator: credentialCoordinator,
            reads: selectedReads
        )
        self.traceFactory = traceFactory
    }

    package func loadRegistry(
        trace: OperationTrace
    ) async -> WorkflowLoadState<McpRegistrySnapshot> {
        let read = reads.registry
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try await read()
        }
    }

    package func loadCamp(
        campId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<McpCampSnapshot> {
        let read = reads.enabled
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            McpCampSnapshot(
                campId: campId,
                enabledServerIds: try read(campId)
            )
        }
    }

    package func loadTools(
        serverId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<McpToolSnapshot> {
        let read = reads.tools
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            McpToolSnapshot(
                serverId: serverId,
                tools: try await read(serverId)
            )
        }
    }

    package func secretPresence(
        serverId: String,
        key: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<Bool> {
        let registryRead = reads.registry
        let read = reads.secret
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let registry = try await registryRead()
            guard let server = registry.servers.first(where: {
                $0.id == serverId
            }) else {
                throw McpOperationError.serverMissing(serverId: serverId)
            }
            return try read(
                McpCredentialAccount(
                    server: server,
                    secretEnvironmentKey: key
                ),
                .failIfInteractionRequired
            )
        }
    }

    package func loadCompanionEditor(
        companionId: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<CompanionEditorSnapshot> {
        let read = reads.companionEditor
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            try read(companionId)
        }
    }

    package func setEnabled(
        campId: String,
        serverId: String,
        enabled: Bool,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        let port = ports.setEnabled
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            try port(campId, serverId, enabled)
            return .committed(())
        }
    }

    package func saveSecret(
        serverId: String,
        key: String,
        mutation: McpSecretMutation,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<McpSecretMutationReceipt> {
        let port = ports.mutateSecret
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try port(
                serverId,
                key,
                mutation,
                .allow
            ))
        }
    }

    package func deleteServer(
        serverId: String,
        trace: OperationTrace
    ) async -> McpServerDeletionOutcome {
        guard trace.operation == .mcpServerDelete,
              trace.scope.type == .mcpServer,
              trace.scope.id == serverId
        else {
            return .notCommitted(reporter.capture(
                TraceIdentityConflictError(),
                trace: trace
            ))
        }
        let port = ports.deleteServer
        switch await port(
            serverId,
            .allow,
            trace.traceScope
        ) {
        case .notCommitted(let error):
            return .notCommitted(reporter.capture(error, trace: trace))
        case .notCommittedCleanupPending(
            let primary,
            let cleanup,
            let pending
        ):
            return .notCommittedCleanupPending(
                pending: pending,
                failure: reporter.capture(
                    McpDeletionCleanupCompositeError(
                        primary: primary,
                        cleanup: cleanup
                    ),
                    trace: trace
                )
            )
        case .committed(let receipt):
            return .committed(receipt)
        case .committedCleanupPending(let cleanup, let pending):
            return .committedCleanupPending(
                pending: pending,
                failure: reporter.capture(cleanup, trace: trace)
            )
        }
    }

    // P1-B-SEAM mcpFinishServerCleanup
    package func finishServerCleanup(
        _ pending: McpPendingServerCleanup
    ) async -> McpServerCleanupOutcome {
        if let existing = cleanupFlightByServerId[pending.serverId] {
            guard existing.pending == pending else {
                let trace = traceFactory.generated(
                    operation: .mcpServerDelete,
                    scope: pending.traceScope
                )
                return .pending(
                    pending,
                    failure: reporter.capture(
                        McpMaintenanceCleanupError.invalidLease(
                            serverId: pending.serverId
                        ),
                        trace: trace
                    )
                )
            }
            return await cleanupOutcome(
                pending: pending,
                result: existing.task.value,
                trace: traceFactory.generated(
                    operation: .mcpServerDelete,
                    scope: pending.traceScope
                )
            )
        }
        let trace = traceFactory.generated(
            operation: .mcpServerDelete,
            scope: pending.traceScope
        )
        let finish = ports.finishServerCleanup
        let attempt = UUID()
        let task = Task { await finish(pending) }
        cleanupFlightByServerId[pending.serverId] = McpCleanupFlight(
            attemptId: attempt,
            pending: pending,
            task: task
        )
        let result = await task.value
        if cleanupFlightByServerId[pending.serverId]?.attemptId == attempt {
            cleanupFlightByServerId[pending.serverId] = nil
        }
        return cleanupOutcome(
            pending: pending,
            result: result,
            trace: trace
        )
    }

    package func restart(
        serverId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<McpServerReady> {
        let port = ports.restartServer
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try await port(serverId))
        }
    }

    package func saveCompanion(
        _ companion: CompanionRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<CompanionRecord> {
        let port = ports.saveCompanion
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try port(companion))
        }
    }

    package func addServer(
        _ draft: McpServerDraft,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<McpServerRecord> {
        let port = ports.addServer
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try port(draft))
        }
    }

    package func start(
        serverId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<McpServerReady> {
        let port = ports.startServer
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try await port(serverId))
        }
    }

    private func cleanupOutcome(
        pending: McpPendingServerCleanup,
        result: Result<Void, McpMaintenanceCleanupError>,
        trace: OperationTrace
    ) -> McpServerCleanupOutcome {
        switch result {
        case .success:
            switch pending {
            case .rollback(let rollback):
                return .deletionRetryReady(
                    McpServerDeletionRetryReceipt(
                        cleanedRollback: rollback
                    )
                )
            case .deleted(let deleted):
                return .deletionCommitted(McpServerDeletionReceipt(
                    cleanedLease: deleted.lease
                ))
            }
        case .failure(let error):
            return .pending(
                pending,
                failure: reporter.capture(error, trace: trace)
            )
        }
    }

}
