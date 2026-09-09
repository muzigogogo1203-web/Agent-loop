import Foundation
import GRDB
import os

private struct EngineStrictCommandV1: Sendable {
    let prepared: PreparedDomainCommandV1
    let replayPlan: DomainCommandReplayPlanV1
}

private struct EngineDispatchCommandPayloadV1: Codable, Sendable, Equatable {
    let executionId: String
    let requestHash: String
    let commandIdempotencyKey: String
}

private struct EngineCancellationCommandPayloadV1:
    Codable, Sendable, Equatable
{
    let executionId: String
    let reason: String
}

private struct EngineEventCommandPayloadV1: Codable, Sendable, Equatable {
    let executionId: String
    let sequence: Int
    let event: EngineExecutionEvent
}

private struct EngineTerminalCommandPayloadV1:
    Encodable, Sendable, Equatable
{
    let executionId: String
    let proposalId: String?
    let proposalHash: String?
    let disposition: EngineTerminalCommitDispositionV1
    let terminalKind: EngineTerminalKindV1
    let terminalSubtype: EngineTerminalSubtypeV1?
    let reasonCode: String?
    let detail: String
    let checkedUsage: EngineUsageV1
    let artifactIds: [String]

    private enum CodingKeys: String, CodingKey {
        case executionId
        case proposalId
        case proposalHash
        case disposition
        case terminalKind
        case terminalSubtype
        case reasonCode
        case detail
        case checkedUsage
        case artifactIds
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(executionId, forKey: .executionId)
        try container.encodeIfPresent(proposalId, forKey: .proposalId)
        try container.encodeIfPresent(proposalHash, forKey: .proposalHash)
        try container.encode(disposition, forKey: .disposition)
        try container.encode(terminalKind, forKey: .terminalKind)
        try container.encodeIfPresent(
            terminalSubtype,
            forKey: .terminalSubtype
        )
        try container.encodeIfPresent(reasonCode, forKey: .reasonCode)
        try container.encode(detail, forKey: .detail)
        try container.encode(checkedUsage, forKey: .checkedUsage)
        if !artifactIds.isEmpty {
            try container.encode(artifactIds, forKey: .artifactIds)
        }
    }
}

package enum EngineCancellationRequestDispositionV1: Sendable, Equatable {
    case requested(EngineExecutionRecord)
    case terminalWon(EngineTerminalCommitReceiptV1)
}

package enum EngineRecoveryProcessingResultV1: Sendable, Equatable {
    case receipt(EngineTerminalCommitReceiptV1)
    case directive(EngineRecoveryDirectiveV1)
    case noLongerActive
}

private enum EngineRecoveryAuthorityV1 {
    case exactExecutionAfterCleanup
    case missionWide
}

private struct EngineCancellationCASLostV1: Error {}

package struct EngineExecutionStore: Sendable {
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop",
        category: "engine-execution-store"
    )

    private let database: AppDatabase
    private let descriptorResolver:
        @Sendable (
            RuntimeProfileRecord,
            [EngineCapabilityV1]
        ) throws -> ExecutionEngineDescriptor
    private let clock: @Sendable () -> Date
    private let executionIdFactory: @Sendable () -> String
    private let runIdFactory: @Sendable () -> String
    private let proposalIdFactory: @Sendable () -> String
    private let artifactIdFactory: @Sendable () -> String
    private let eventIdFactory: @Sendable () -> String
    private let userRequestIdFactory: @Sendable () -> String
    private let sessionStore: EngineSessionStore
    private let domainEventStore: DomainEventStore
    private let artifactBlobStore: ArtifactBlobStore?
    private let artifactStorageOriginStore: ArtifactStorageOriginStore?

    package init(
        database: AppDatabase,
        descriptorResolver: @escaping @Sendable (
            RuntimeProfileRecord,
            [EngineCapabilityV1]
        ) throws -> ExecutionEngineDescriptor,
        clock: @escaping @Sendable () -> Date = { Date() },
        artifactBlobStore: ArtifactBlobStore? = nil,
        artifactStorageOriginStore: ArtifactStorageOriginStore? = nil,
        executionIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        runIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        proposalIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        artifactIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        eventIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        userRequestIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        sessionIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    ) {
        self.database = database
        self.descriptorResolver = descriptorResolver
        self.clock = clock
        self.executionIdFactory = executionIdFactory
        self.runIdFactory = runIdFactory
        self.proposalIdFactory = proposalIdFactory
        self.artifactIdFactory = artifactIdFactory
        self.eventIdFactory = eventIdFactory
        self.userRequestIdFactory = userRequestIdFactory
        self.artifactBlobStore = artifactBlobStore
        self.artifactStorageOriginStore = artifactStorageOriginStore
        self.sessionStore = EngineSessionStore(
            sessionIdFactory: sessionIdFactory
        )
        self.domainEventStore = DomainEventStore(
            database: database,
            clock: clock,
            eventIdFactory: eventIdFactory
        )
    }

    package static func activeRecoveryProfileKinds(
        database: Database
    ) throws -> [RuntimeProfileKind] {
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT execution.profileId AS executionProfileId,
                       profile.id AS persistedProfileId,
                       profile.kind AS persistedProfileKind
                FROM engine_execution AS execution
                LEFT JOIN runtime_profile AS profile
                  ON profile.id=execution.profileId
                WHERE execution.state='running'
                  AND execution.redactedAt IS NULL
                ORDER BY execution.profileId
                """
        )
        var kinds = Set<RuntimeProfileKind>()
        for row in rows {
            let executionProfileID: String = row["executionProfileId"]
            guard let persistedProfileID: String = row["persistedProfileId"],
                  persistedProfileID == executionProfileID,
                  let rawKind: String = row["persistedProfileKind"],
                  let kind = RuntimeProfileKind(rawValue: rawKind)
            else {
                throw EngineDescriptorMismatchErrorV1()
            }
            kinds.insert(kind)
        }
        return kinds.sorted { $0.rawValue < $1.rawValue }
    }

    package func beginEngineExecution(
        requestFields: EngineExecutionRequestFieldsV1,
        idempotencyKey: String
    ) throws -> EngineExecutionRequest {
        try validateBoundedIdentity(idempotencyKey)
        return try database.pool.write { transactionDatabase in
            if let raced = try EngineExecutionRecord
                .filter(Column("idempotencyKey") == idempotencyKey)
                .fetchOne(transactionDatabase)
            {
                let request = try rehydrateRequest(raced)
                guard requestMatches(request, fields: requestFields),
                      claimedScopeMatches(
                          fields: requestFields,
                          canonicalJSON: request.sessionScopeJson,
                          hash: request.sessionScopeHash
                      )
                else {
                    throw EngineExecutionReplayConflictError()
                }
                _ = try validatedContext(requestFields)
                _ = try exactDescriptor(
                    for: raced,
                    requiredCapabilities: request.requiredCapabilities,
                    database: transactionDatabase
                )
                let metadata = try executeStrictEngineCommand(
                    branch: .beginEngineExecution,
                    commandType: .engineExecutionBegin,
                    idempotencyKey: idempotencyKey,
                    payload: request,
                    execution: raced,
                    occurredAt: clock(),
                    database: transactionDatabase,
                    conflict: { EngineExecutionReplayConflictError() },
                    apply: { _ in
                        throw DomainCommandGraphIntegrityError()
                    }
                )
                guard metadata.wasReplay else {
                    throw DomainCommandGraphIntegrityError()
                }
                try validateStrictEngineMetadata(
                    metadata,
                    executionId: raced.id,
                    requestHash: raced.requestHash
                )
                return request
            }
            if try commandReceiptExists(
                idempotencyKey,
                database: transactionDatabase
            ) {
                throw DomainCommandGraphIntegrityError()
            }

            let envelope = try validatedContext(requestFields)

            guard let profile = try RuntimeProfileRecord.fetchOne(
                transactionDatabase,
                key: requestFields.profileId
            ) else {
                throw EngineDescriptorMismatchErrorV1()
            }
            let descriptor = try descriptorResolver(
                profile,
                requestFields.requiredCapabilities
            )
            try validateDescriptor(
                descriptor,
                profile: profile,
                requiredCapabilities: requestFields.requiredCapabilities
            )
            let scope = try EngineSessionScopeV1.derived(
                campId: requestFields.campId,
                profileId: requestFields.profileId,
                descriptor: descriptor,
                engineKind: requestFields.engineKind,
                model: requestFields.model,
                workspaceHash: requestFields.workspace.hash,
                contract: requestFields.contract
            )
            let scopeBytes = try CanonicalJSONV1.encode(scope)
            let scopeJSON = String(decoding: scopeBytes, as: UTF8.self)
            let scopeHash = CanonicalJSONV1.sha256Hex(scopeBytes)
            guard claimedScopeMatches(
                fields: requestFields,
                canonicalJSON: scopeJSON,
                hash: scopeHash
            ) else {
                throw EngineSessionScopeMismatchError()
            }
            let replayClass = descriptor.executionReplayClass(for: scope)

            guard let card = try CardRecord.fetchOne(
                transactionDatabase,
                key: requestFields.cardId
            ), card.status == .ready,
                  let mission = try MissionRecord.fetchOne(
                      transactionDatabase,
                      key: card.missionId
                  ),
                  let squad = try SquadRecord.fetchOne(
                      transactionDatabase,
                      key: mission.squadId
                  ),
                  squad.campId == requestFields.campId,
                  envelope.missionId == mission.id,
                  envelope.cardId == card.id
            else {
                throw EngineExecutionReplayConflictError()
            }
            guard let lifecycle = try CampLifecycleStore(
                database: database
            ).lifecycle(
                campId: requestFields.campId,
                database: transactionDatabase
            ) else {
                throw CampLifecycleWriteAuthorizationError.missing
            }
            _ = try CampLifecycleStore(database: database)
                .requireActiveCampWrite(
                    campId: requestFields.campId,
                    expectedLifecycleVersion: lifecycle.version,
                    database: transactionDatabase
                )
            let lifecycleVersion = lifecycle.version
            let resolvedSession = try resolveSessionReference(
                requestFields.sessionSelection,
                predecessorExecutionId:
                    requestFields.predecessorExecutionId,
                cardId: requestFields.cardId,
                campId: requestFields.campId,
                profileId: requestFields.profileId,
                descriptor: descriptor,
                workspaceHash: requestFields.workspace.hash,
                scopeJSON: scopeJSON,
                scopeHash: scopeHash,
                database: transactionDatabase
            )
            let executionID = executionIdFactory()
            let runID = runIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(executionID)
            try CanonicalContractCodingV1.validateCanonicalUUID(runID)
            let request = try EngineExecutionRequest.makeCanonical(
                executionId: executionID,
                idempotencyKey: idempotencyKey,
                campId: requestFields.campId,
                campLifecycleVersion: lifecycleVersion,
                runId: runID,
                cardId: requestFields.cardId,
                contract: requestFields.contract,
                adapterId: descriptor.adapterId,
                adapterVersion: descriptor.adapterVersion,
                profileId: requestFields.profileId,
                engineKind: requestFields.engineKind,
                model: requestFields.model,
                replayClass: replayClass,
                contextJson: requestFields.contextJson,
                contextHash: requestFields.contextHash,
                sessionScopeJson: scopeJSON,
                sessionScopeHash: scopeHash,
                requiredCapabilities: requestFields.requiredCapabilities,
                approvalGrantIds: requestFields.approvalGrantIds,
                budget: requestFields.budget,
                workspace: requestFields.workspace,
                predecessorExecutionId:
                    requestFields.predecessorExecutionId,
                sessionRef: resolvedSession
            )
            let now = clock()
            try CanonicalContractCodingV1.validateFinite(now)
            let execution = EngineExecutionRecord(
                id: request.executionId,
                campId: request.campId,
                campLifecycleVersion: request.campLifecycleVersion,
                idempotencyKey: request.idempotencyKey,
                runId: request.runId,
                cardId: request.cardId,
                adapterId: request.adapterId,
                adapterVersion: request.adapterVersion,
                profileId: request.profileId,
                engineKind: request.engineKind,
                model: request.model,
                requestJson: request.requestJson,
                requestHash: request.requestHash,
                contextJson: request.contextJson,
                contextHash: request.contextHash,
                sessionScopeJson: request.sessionScopeJson,
                sessionScopeHash: request.sessionScopeHash,
                sessionId: nil,
                replayClass: request.replayClass,
                dispatchState: .prepared,
                state: .running,
                terminalSubtype: nil,
                nextSequence: 0,
                terminalReceiptIdempotencyKey: nil,
                terminalReceiptHash: nil,
                inputTokens: 0,
                outputTokens: 0,
                cacheReadTokens: 0,
                costMicros: 0,
                version: 1,
                createdAt: now,
                updatedAt: now,
                dispatchStartedAt: nil,
                cancellationRequestedAt: nil,
                cancellationReason: nil,
                finishedAt: nil,
                redactedAt: nil
            )
            let metadata = try executeStrictEngineCommand(
                branch: .beginEngineExecution,
                commandType: .engineExecutionBegin,
                idempotencyKey: idempotencyKey,
                payload: request,
                execution: execution,
                occurredAt: now,
                database: transactionDatabase,
                conflict: { EngineExecutionReplayConflictError() },
                apply: { database in
                    let attempt = try (
                        Int.fetchOne(
                            database,
                            sql: "SELECT MAX(attempt) FROM run WHERE cardId=?",
                            arguments: [request.cardId]
                        ) ?? 0
                    ).addingEngineChecked(1)
                    try RunRecord(
                        id: request.runId,
                        cardId: request.cardId,
                        attempt: attempt,
                        outcome: nil,
                        turns: 0,
                        tokensIn: 0,
                        tokensOut: 0,
                        startedAt: now,
                        endedAt: nil
                    ).insert(database)
                    try execution.insert(database)
                    try database.execute(
                        sql: """
                            UPDATE card SET status='running',
                              blockedReasonJson=NULL
                            WHERE id=? AND status='ready'
                        """,
                        arguments: [request.cardId]
                    )
                    guard database.changesCount == 1 else {
                        throw EngineExecutionReplayConflictError()
                    }
                    try appendLegacy(
                        database: database,
                        missionId: mission.id,
                        cardId: request.cardId,
                        runId: request.runId,
                        kind: EventKind.cardStarted,
                        payload: [
                            "executionId": .string(request.executionId),
                            "requestHash": .string(request.requestHash),
                        ],
                        at: now
                    )
                }
            )
            guard !metadata.wasReplay else {
                throw DomainCommandGraphIntegrityError()
            }
            try validateStrictEngineMetadata(
                metadata,
                executionId: execution.id,
                requestHash: execution.requestHash
            )
            return try rehydrateRequest(
                requireExecution(execution.id, database: transactionDatabase)
            )
        }
    }

    package func markEngineDispatchStarted(
        executionId: String,
        expectedVersion: Int,
        requestHash: String,
        commandIdempotencyKey: String,
        now: Date
    ) throws -> EngineDispatchStartResultV1 {
        try database.pool.write { transactionDatabase in
            guard let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: executionId
            ) else {
                throw EngineDispatchConflictErrorV1()
            }
            let request = try rehydrateRequest(execution)
            let payload = EngineDispatchCommandPayloadV1(
                executionId: executionId,
                requestHash: requestHash,
                commandIdempotencyKey: commandIdempotencyKey
            )
            let isReplay = try commandReceiptExists(
                commandIdempotencyKey,
                database: transactionDatabase
            )
            if !isReplay {
                guard execution.state == .running,
                      execution.dispatchState == .prepared,
                      execution.version == expectedVersion,
                      execution.requestHash == requestHash
                else {
                    throw EngineDispatchConflictErrorV1()
                }
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
            }
            let metadata = try executeStrictEngineCommand(
                branch: .startEngineDispatch,
                commandType: .engineDispatchStart,
                idempotencyKey: commandIdempotencyKey,
                payload: payload,
                execution: execution,
                occurredAt: now,
                database: transactionDatabase,
                conflict: { EngineDispatchConflictErrorV1() },
                apply: { database in
                    try database.execute(
                        sql: """
                            UPDATE engine_execution
                            SET dispatchState='started',dispatchStartedAt=?,
                                updatedAt=?,version=version+1
                            WHERE id=? AND version=? AND state='running'
                              AND dispatchState='prepared' AND requestHash=?
                            """,
                        arguments: [
                            now,
                            now,
                            execution.id,
                            expectedVersion,
                            requestHash,
                        ]
                    )
                    guard database.changesCount == 1 else {
                        throw EngineDispatchConflictErrorV1()
                    }
                    try appendLegacy(
                        database: database,
                        missionId: try missionID(
                            forCard: execution.cardId,
                            database: database
                        ),
                        cardId: execution.cardId,
                        runId: execution.runId,
                        kind: EventKind.progressNote,
                        payload: [
                            "detail": "engine dispatch started",
                            "executionId": .string(execution.id),
                        ],
                        at: now
                    )
                }
            )
            try validateStrictEngineMetadata(
                metadata,
                executionId: execution.id,
                requestHash: execution.requestHash
            )
            return metadata.wasReplay ? .alreadyStarted : .startNow(request)
        }
    }

    package func requestCancellation(
        executionId: String,
        reason: String,
        now: Date
    ) throws -> EngineCancellationRequestDispositionV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
            try CanonicalContractCodingV1.validateFinite(now)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        try validateReasonCode(reason)
        let commandKey = "engine.cancellation.v1:\(executionId)"
        return try database.pool.write { transactionDatabase in
            guard let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: executionId
            ), execution.id == executionId,
               execution.redactedAt == nil
            else {
                throw EngineDispatchConflictErrorV1()
            }
            if execution.state != .running {
                return .terminalWon(
                    try reconstructTerminalReceipt(
                        execution: execution,
                        database: transactionDatabase
                    )
                )
            }
            let payload = EngineCancellationCommandPayloadV1(
                executionId: executionId,
                reason: reason
            )
            let isReplay = try commandReceiptExists(
                commandKey,
                database: transactionDatabase
            )
            if isReplay {
                guard execution.cancellationRequestedAt != nil,
                      execution.cancellationReason == reason
                else {
                    throw EngineDispatchConflictErrorV1()
                }
            } else {
                guard execution.cancellationRequestedAt == nil,
                      execution.cancellationReason == nil
                else {
                    throw EngineDispatchConflictErrorV1()
                }
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
            }
            let metadata: DomainCommandExecutionMetadataV1
            do {
                metadata = try executeStrictEngineCommand(
                    branch: .requestEngineCancellation,
                    commandType: .engineCancellationRequest,
                    idempotencyKey: commandKey,
                    payload: payload,
                    execution: execution,
                    occurredAt: now,
                    database: transactionDatabase,
                    conflict: { EngineDispatchConflictErrorV1() },
                    apply: { database in
                        try database.execute(
                            sql: """
                                UPDATE engine_execution
                                SET cancellationRequestedAt=?,
                                    cancellationReason=?,updatedAt=?,
                                    version=version+1
                                WHERE id=? AND version=? AND state='running'
                                  AND cancellationRequestedAt IS NULL
                                """,
                            arguments: [
                                now,
                                reason,
                                now,
                                execution.id,
                                execution.version,
                            ]
                        )
                        guard database.changesCount == 1 else {
                            throw EngineCancellationCASLostV1()
                        }
                        try appendLegacy(
                            database: database,
                            missionId: try missionID(
                                forCard: execution.cardId,
                                database: database
                            ),
                            cardId: execution.cardId,
                            runId: execution.runId,
                            kind: EventKind.progressNote,
                            payload: [
                                "detail": "engine cancellation requested",
                                "executionId": .string(execution.id),
                                "reason": .string(reason),
                            ],
                            at: now
                        )
                    }
                )
            } catch is EngineCancellationCASLostV1 {
                guard let winner = try EngineExecutionRecord.fetchOne(
                    transactionDatabase,
                    key: execution.id
                ), winner.id == execution.id,
                   winner.redactedAt == nil,
                   winner.state != .running
                else {
                    throw EngineDispatchConflictErrorV1()
                }
                return .terminalWon(
                    try reconstructTerminalReceipt(
                        execution: winner,
                        database: transactionDatabase
                    )
                )
            }
            try validateStrictEngineMetadata(
                metadata,
                executionId: execution.id,
                requestHash: execution.requestHash
            )
            let requested = try requireExecution(
                execution.id,
                database: transactionDatabase
            )
            guard requested.state == .running,
                  requested.redactedAt == nil,
                  requested.cancellationRequestedAt != nil,
                  requested.cancellationReason == reason
            else {
                throw EngineDispatchConflictErrorV1()
            }
            return .requested(requested)
        }
    }

    package func activeRecoverySnapshots(
        missionId: String?
    ) throws
        -> [EngineExecutionRecoverySnapshotV1]
    {
        try validateRecoveryMissionID(missionId)
        return try database.pool.read { transactionDatabase in
            let executions = try selectedRecoveryExecutions(
                missionId: missionId,
                database: transactionDatabase
            )
            return try executions.map { execution in
                guard let lifecycle = try CampLifecycleStore(
                    database: database
                ).lifecycle(
                    campId: execution.campId,
                    database: transactionDatabase
                ) else {
                    throw CampLifecycleWriteAuthorizationError.missing
                }
                _ = try CampLifecycleStore(database: database)
                    .requireActiveCampWrite(
                        campId: execution.campId,
                        expectedLifecycleVersion:
                            execution.campLifecycleVersion,
                        database: transactionDatabase
                    )
                let snapshot = try recoverySnapshot(
                    for: execution,
                    lifecycle: lifecycle,
                    database: transactionDatabase
                )
                if let proposal = snapshot.proposal {
                    _ = try validatedRecoveryProposal(
                        proposal,
                        execution: execution
                    )
                }
                return snapshot
            }
        }
    }

    package func recoverInterruptedEngineExecutions(
        missionId: String?,
        now: Date
    ) throws -> EngineRecoverySummaryV1 {
        try validateRecoveryMissionID(missionId)
        do {
            try CanonicalContractCodingV1.validateFinite(now)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        return try database.pool.write { transactionDatabase in
            let executions = try selectedRecoveryExecutions(
                missionId: missionId,
                database: transactionDatabase
            )
            var receipts: [EngineTerminalCommitReceiptV1] = []
            var directives: [EngineRecoveryDirectiveV1] = []
            for execution in executions {
                let result = try recoverInterruptedEngineExecutionInTransaction(
                    execution,
                    now: now,
                    authority: .missionWide,
                    database: transactionDatabase
                )
                try validateRecoveryResult(
                    result,
                    execution: execution,
                    database: transactionDatabase
                )
                switch result {
                case let .receipt(receipt):
                    receipts.append(receipt)
                case let .directive(directive):
                    directives.append(directive)
                case .noLongerActive:
                    break
                }
            }
            return EngineRecoverySummaryV1(
                scannedCount: executions.count,
                terminalReceipts: receipts,
                directives: directives
            )
        }
    }

    package func recoverInterruptedEngineExecution(
        executionId: String,
        now: Date
    ) throws -> EngineRecoveryProcessingResultV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
            try CanonicalContractCodingV1.validateFinite(now)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        return try database.pool.write { transactionDatabase in
            guard let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: executionId
            ), execution.id == executionId,
               execution.redactedAt == nil
            else {
                throw EngineDispatchConflictErrorV1()
            }
            if execution.state != .running {
                return .receipt(
                    try reconstructTerminalReceipt(
                        execution: execution,
                        database: transactionDatabase
                    )
                )
            }
            let result: EngineRecoveryProcessingResultV1
            do {
                result = try recoverInterruptedEngineExecutionInTransaction(
                    execution,
                    now: now,
                    authority: .exactExecutionAfterCleanup,
                    database: transactionDatabase
                )
            } catch {
                Self.logRecoveryFailure(
                    stage: "resolve",
                    executionId: execution.id,
                    error: error
                )
                throw error
            }
            do {
                try validateRecoveryResult(
                    result,
                    execution: execution,
                    database: transactionDatabase
                )
            } catch {
                Self.logRecoveryFailure(
                    stage: "validate",
                    executionId: execution.id,
                    error: error
                )
                throw error
            }
            return result
        }
    }

    private static func logRecoveryFailure(
        stage: String,
        executionId: String,
        error: any Error
    ) {
        let errorType = String(reflecting: type(of: error))
        logger.error(
            "Engine recovery failed stage=\(stage, privacy: .public) execution=\(executionId, privacy: .public) error=\(errorType, privacy: .public)"
        )
    }

    package func resolveRecoverySessionReference(
        executionId: String,
        requestHash: String,
        sessionId: String,
        externalSessionId: String
    ) throws -> EngineSessionReferenceV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        try CanonicalContractCodingV1.validateLowercaseHash(requestHash)
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        return try database.pool.read { transactionDatabase in
            guard let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: executionId
            ), execution.id == executionId,
               execution.requestHash == requestHash,
               execution.state == .running,
               execution.dispatchState == .sessionBound,
               execution.sessionId == sessionId,
               execution.redactedAt == nil
            else {
                throw EngineSessionScopeMismatchError()
            }
            let request: EngineExecutionRequest
            do {
                request = try rehydrateRequest(execution)
            } catch {
                throw EngineSessionScopeMismatchError()
            }
            let reference = try requireExactBoundSessionReference(
                execution: execution,
                request: request,
                sessionId: sessionId,
                externalSessionId: externalSessionId,
                database: transactionDatabase
            )
            var requiredCapabilities = Set(request.requiredCapabilities)
            requiredCapabilities.insert(.sessionResume)
            let descriptor = try exactDescriptor(
                for: execution,
                requiredCapabilities: requiredCapabilities.sorted {
                    $0.rawValue < $1.rawValue
                },
                database: transactionDatabase
            )
            guard descriptor.profileKind == .cliCodex
                    || descriptor.profileKind == .cliClaude,
                  descriptor.sessionResume == .supported
            else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return reference
        }
    }

    package func acceptEngineEvent(
        executionId: String,
        sequence: Int,
        event: EngineExecutionEvent
    ) throws {
        let overflowed = try database.pool.write { transactionDatabase in
            try acceptEngineEventInTransaction(
                executionId: executionId,
                sequence: sequence,
                event: event,
                usageDelta: nil,
                terminalizeUsageOverflow: true,
                database: transactionDatabase
            )
        }
        if overflowed {
            throw EngineUsageV1.UsageOverflowError()
        }
    }

    package func acceptRoutedEngineEvent(
        executionId: String,
        sequence: Int,
        event: EngineExecutionEvent
    ) throws {
        try database.pool.write { transactionDatabase in
            let usageDelta: EngineUsageV1?
            if case let .usage(cumulative) = event.payload {
                guard let execution = try EngineExecutionRecord.fetchOne(
                    transactionDatabase,
                    key: executionId
                ), execution.state == .running,
                   execution.dispatchState == .started
                    || execution.dispatchState == .sessionBound,
                   event.executionId == executionId,
                   event.sequence == sequence,
                   execution.nextSequence == sequence
                else {
                    throw EngineEventSequenceErrorV1()
                }
                usageDelta = try routedUsageDelta(
                    cumulative: cumulative,
                    durable: EngineUsageV1(
                        inputTokens: execution.inputTokens,
                        outputTokens: execution.outputTokens,
                        cacheReadTokens: execution.cacheReadTokens,
                        costMicros: execution.costMicros
                    )
                )
            } else {
                usageDelta = nil
            }
            let overflowed = try acceptEngineEventInTransaction(
                executionId: executionId,
                sequence: sequence,
                event: event,
                usageDelta: usageDelta,
                terminalizeUsageOverflow: false,
                database: transactionDatabase
            )
            guard !overflowed else {
                throw EngineUsageV1.UsageOverflowError()
            }
        }
    }

    private func acceptEngineEventInTransaction(
        executionId: String,
        sequence: Int,
        event: EngineExecutionEvent,
        usageDelta: EngineUsageV1?,
        terminalizeUsageOverflow: Bool,
        database transactionDatabase: Database
    ) throws -> Bool {
            guard let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: executionId
            ), execution.state == .running,
               execution.dispatchState == .started
                || execution.dispatchState == .sessionBound,
               event.executionId == executionId,
               event.sequence == sequence,
               execution.nextSequence == sequence,
               sequence >= 0,
               sequence < Int.max
            else {
                throw EngineEventSequenceErrorV1()
            }
            let request = try rehydrateRequest(execution)
            let now = clock()
            try CanonicalContractCodingV1.validateFinite(now)

            if case let .terminal(content) = event.payload {
                guard content.executionId == execution.id,
                      content.runId == execution.runId,
                      content.cardId == execution.cardId,
                      content.sequence == sequence
                else {
                    throw EngineEventSequenceErrorV1()
                }
                _ = try recordEngineTerminalProposal(
                    content,
                    consumeSequence: true,
                    database: transactionDatabase
                )
                return false
            }

            let commandKey = "engine.event.v1:\(executionId):\(sequence)"
            let payload = EngineEventCommandPayloadV1(
                executionId: executionId,
                sequence: sequence,
                event: event
            )
            let eventJSON = try engineEventPayloadJSON(event.payload)
            try requireActiveCampWriteFence(
                execution,
                database: transactionDatabase
            )

            let needsSessionBinding: Bool
            if case let .sessionBound(externalSessionId) = event.payload {
                switch (execution.dispatchState, execution.sessionId) {
                case (.started, nil):
                    needsSessionBinding = true
                case let (.sessionBound, sessionId?):
                    _ = try requireExactBoundSessionReference(
                        execution: execution,
                        request: request,
                        sessionId: sessionId,
                        externalSessionId: externalSessionId,
                        database: transactionDatabase
                    )
                    needsSessionBinding = false
                default:
                    throw EngineSessionScopeMismatchError()
                }
            } else {
                needsSessionBinding = false
            }

            if case let .usage(eventUsage) = event.payload {
                let delta = usageDelta ?? eventUsage
                guard delta.inputTokens >= 0,
                      delta.outputTokens >= 0,
                      delta.cacheReadTokens >= 0,
                      delta.costMicros >= 0
                else {
                    throw EngineEventSequenceErrorV1()
                }
                do {
                    let current = EngineUsageV1(
                        inputTokens: execution.inputTokens,
                        outputTokens: execution.outputTokens,
                        cacheReadTokens: execution.cacheReadTokens,
                        costMicros: execution.costMicros
                    )
                    let total = try current.adding(delta)
                    guard var run = try RunRecord.fetchOne(
                        transactionDatabase,
                        key: execution.runId
                    ), var mission = try MissionRecord.fetchOne(
                        transactionDatabase,
                        key: try missionID(
                            forCard: execution.cardId,
                            database: transactionDatabase
                        )
                    ) else {
                        throw EngineEventSequenceErrorV1()
                    }
                    run.tokensIn = try run.tokensIn.addingEngineChecked(
                        delta.inputTokens
                    )
                    run.tokensOut = try run.tokensOut.addingEngineChecked(
                        delta.outputTokens
                    )
                    let billed = try delta.inputTokens.addingEngineChecked(
                        delta.outputTokens
                    )
                    mission.spentTokens = try mission.spentTokens
                        .addingEngineChecked(billed)
                    let metadata = try executeStrictEngineCommand(
                        branch: .acceptEngineEvent,
                        commandType: .engineEventAccept,
                        idempotencyKey: commandKey,
                        payload: payload,
                        execution: execution,
                        occurredAt: now,
                        database: transactionDatabase,
                        conflict: { EngineEventSequenceErrorV1() },
                        apply: { database in
                            try database.execute(
                                sql: """
                                    UPDATE engine_execution
                                    SET inputTokens=?,outputTokens=?,
                                        cacheReadTokens=?,costMicros=?,
                                        nextSequence=nextSequence+1,
                                        updatedAt=?,version=version+1
                                    WHERE id=? AND version=? AND state='running'
                                      AND nextSequence=?
                                    """,
                                arguments: [
                                    total.inputTokens,
                                    total.outputTokens,
                                    total.cacheReadTokens,
                                    total.costMicros,
                                    now,
                                    execution.id,
                                    execution.version,
                                    sequence,
                                ]
                            )
                            guard database.changesCount == 1 else {
                                throw EngineEventSequenceErrorV1()
                            }
                            try run.update(database)
                            try mission.update(database)
                            try appendLegacy(
                                database: database,
                                missionId: mission.id,
                                cardId: execution.cardId,
                                runId: execution.runId,
                                kind: EventKind.progressNote,
                                payload: eventJSON,
                                at: now
                            )
                        }
                    )
                    try validateStrictEngineMetadata(
                        metadata,
                        executionId: execution.id,
                        requestHash: execution.requestHash
                    )
                    return false
                } catch is EngineUsageV1.UsageOverflowError {
                    guard terminalizeUsageOverflow else {
                        throw EngineUsageV1.UsageOverflowError()
                    }
                    _ = try commitSyntheticTerminalInTransaction(
                        execution: execution,
                        terminalKind: .failed,
                        terminalSubtype: nil,
                        reasonCode: "usage_overflow",
                        detail: "engine usage counter overflow",
                        terminalIdempotencyKey:
                            "engine.usage-overflow.v1:\(execution.id)",
                        attention: false,
                        now: now,
                        database: transactionDatabase
                    )
                    return true
                }
            }

            let metadata = try executeStrictEngineCommand(
                branch: .acceptEngineEvent,
                commandType: .engineEventAccept,
                idempotencyKey: commandKey,
                payload: payload,
                execution: execution,
                occurredAt: now,
                database: transactionDatabase,
                conflict: { EngineEventSequenceErrorV1() },
                apply: { database in
                    var effective = execution
                    if needsSessionBinding,
                       case let .sessionBound(externalSessionId) = event.payload
                    {
                        guard execution.sessionId == nil,
                              execution.dispatchState == .started
                        else {
                            throw EngineSessionScopeMismatchError()
                        }
                        let descriptor = try exactDescriptor(
                            for: execution,
                            requiredCapabilities:
                                request.requiredCapabilities,
                            database: database
                        )
                        if let sessionReference = request.sessionRef {
                            _ = try sessionStore.requireExactResume(
                                execution: execution,
                                sessionId: sessionReference.sessionId,
                                externalSessionId: externalSessionId,
                                descriptor: descriptor,
                                database: database,
                                now: now
                            )
                        } else {
                            _ = try sessionStore.bindOrReplay(
                                execution: execution,
                                externalSessionId: externalSessionId,
                                database: database,
                                now: now
                            )
                        }
                        effective = try requireExecution(
                            execution.id,
                            database: database
                        )
                    }
                    try database.execute(
                        sql: """
                            UPDATE engine_execution
                            SET nextSequence=nextSequence+1,
                                updatedAt=?,version=version+1
                            WHERE id=? AND version=? AND state='running'
                              AND nextSequence=?
                              AND dispatchState IN ('started','sessionBound')
                            """,
                        arguments: [
                            now,
                            effective.id,
                            effective.version,
                            sequence,
                        ]
                    )
                    guard database.changesCount == 1 else {
                        throw EngineEventSequenceErrorV1()
                    }
                    try appendLegacy(
                        database: database,
                        missionId: try missionID(
                            forCard: execution.cardId,
                            database: database
                        ),
                        cardId: execution.cardId,
                        runId: execution.runId,
                        kind: EventKind.progressNote,
                        payload: eventJSON,
                        at: now
                    )
                }
            )
            try validateStrictEngineMetadata(
                metadata,
                executionId: execution.id,
                requestHash: execution.requestHash
            )
            return false
    }

    private func routedUsageDelta(
        cumulative: EngineUsageV1,
        durable: EngineUsageV1
    ) throws -> EngineUsageV1 {
        try cumulative.validateNonnegative()
        try durable.validateNonnegative()
        func subtract(_ total: Int, _ current: Int) throws -> Int {
            let (delta, overflow) = total.subtractingReportingOverflow(current)
            guard !overflow, delta >= 0 else {
                throw EngineEventSequenceErrorV1()
            }
            return delta
        }
        return try EngineUsageV1(
            inputTokens: subtract(
                cumulative.inputTokens,
                durable.inputTokens
            ),
            outputTokens: subtract(
                cumulative.outputTokens,
                durable.outputTokens
            ),
            cacheReadTokens: subtract(
                cumulative.cacheReadTokens,
                durable.cacheReadTokens
            ),
            costMicros: subtract(
                cumulative.costMicros,
                durable.costMicros
            )
        )
    }

    package func recordEngineTerminalProposal(
        _ content: EngineTerminalProposalContentV1
    ) throws -> EngineTerminalProposalSnapshotV1 {
        try database.pool.write { transactionDatabase in
            try recordEngineTerminalProposal(
                content,
                consumeSequence: true,
                database: transactionDatabase
            )
        }
    }

    private func recordEngineTerminalProposal(
        _ content: EngineTerminalProposalContentV1,
        consumeSequence: Bool,
        database transactionDatabase: Database
    ) throws -> EngineTerminalProposalSnapshotV1 {
        try content.validateCompletedHandoffManifest()
        try validateBoundedIdentity(content.terminalIdempotencyKey)
        let proposalBytes = try CanonicalJSONV1.encode(content)
        let proposalJSON = String(decoding: proposalBytes, as: UTF8.self)
        let proposalHash = CanonicalJSONV1.sha256Hex(proposalBytes)
        let payloadBytes = try CanonicalJSONV1.encode(content.payload)
        let payloadJSON = String(decoding: payloadBytes, as: UTF8.self)
        let payloadHash = CanonicalJSONV1.sha256Hex(payloadBytes)
        let manifestBytes = try CanonicalJSONV1.encode(content.artifacts)
        let manifestJSON = String(decoding: manifestBytes, as: UTF8.self)
        let manifestHash = CanonicalJSONV1.sha256Hex(manifestBytes)
        let commandKey =
            "engine.terminal-proposal.v1:\(content.terminalIdempotencyKey)"
        let existing = try EngineTerminalProposalRecord.fetchOne(
            transactionDatabase,
            sql: """
                SELECT * FROM engine_terminal_proposal
                WHERE terminalIdempotencyKey=?
                """,
            arguments: [content.terminalIdempotencyKey]
        )
        let hasReceipt = try commandReceiptExists(
            commandKey,
            database: transactionDatabase
        )
        if (existing == nil) != !hasReceipt {
            throw DomainCommandGraphIntegrityError()
        }
        if let existing {
            guard existing.executionId == content.executionId,
                  existing.terminalIdempotencyKey
                    == content.terminalIdempotencyKey,
                  existing.proposalHash == proposalHash,
                  existing.proposalJson == proposalJSON,
                  let execution = try EngineExecutionRecord.fetchOne(
                    transactionDatabase,
                    key: content.executionId
                  )
            else {
                throw EngineTerminalConflictErrorV1()
            }
            let metadata = try executeStrictEngineCommand(
                branch: .recordEngineTerminalProposal,
                commandType: .engineTerminalProposalRecord,
                idempotencyKey: commandKey,
                payload: content,
                execution: execution,
                proposalId: existing.id,
                occurredAt: clock(),
                database: transactionDatabase,
                conflict: { EngineTerminalConflictErrorV1() },
                apply: { _ in
                    throw DomainCommandGraphIntegrityError()
                }
            )
            guard metadata.wasReplay else {
                throw DomainCommandGraphIntegrityError()
            }
            try validateStrictEngineMetadata(
                metadata,
                executionId: execution.id,
                requestHash: execution.requestHash,
                proposalId: existing.id,
                proposalHash: existing.proposalHash
            )
            return try proposalSnapshot(
                proposal: existing,
                database: transactionDatabase
            )
        }

        if try EngineTerminalProposalRecord
            .filter(Column("executionId") == content.executionId)
            .fetchOne(transactionDatabase) != nil
        {
            throw EngineTerminalConflictErrorV1()
        }

        guard let execution = try EngineExecutionRecord.fetchOne(
            transactionDatabase,
            key: content.executionId
        ), execution.state == .running,
           execution.dispatchState == .started
            || execution.dispatchState == .sessionBound
            || !consumeSequence && execution.dispatchState == .prepared,
           execution.nextSequence == content.sequence,
           execution.runId == content.runId,
           execution.cardId == content.cardId
        else {
            throw EngineTerminalConflictErrorV1()
        }
        try requireActiveCampWriteFence(
            execution,
            database: transactionDatabase
        )
        let proposalID = proposalIdFactory()
        try CanonicalContractCodingV1.validateCanonicalUUID(proposalID)
        let now = clock()
        try CanonicalContractCodingV1.validateFinite(now)
        let proposal = EngineTerminalProposalRecord(
            id: proposalID,
            executionId: content.executionId,
            terminalIdempotencyKey: content.terminalIdempotencyKey,
            sequence: content.sequence,
            terminalKind: content.terminalKind,
            terminalSubtype: content.terminalSubtype,
            proposalJson: proposalJSON,
            proposalHash: proposalHash,
            payloadJson: payloadJSON,
            payloadHash: payloadHash,
            artifactManifestJson: manifestJSON,
            artifactManifestHash: manifestHash,
            state: .pending,
            version: 1,
            createdAt: now,
            committedAt: nil,
            invalidReason: nil,
            invalidatedAt: nil,
            redactedAt: nil
        )
        var artifactRows: [EngineProposalArtifactRecord] = []
        for declaration in content.artifacts {
            let artifactID = artifactIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(artifactID)
            artifactRows.append(
                EngineProposalArtifactRecord(
                    id: artifactID,
                    proposalId: proposal.id,
                    artifactId: artifactID,
                    ordinal: declaration.ordinal,
                    sourceRelativePath: declaration.sourceRelativePath,
                    kind: declaration.kind,
                    label: declaration.label,
                    byteCount: declaration.byteCount,
                    contentHash: declaration.contentHash,
                    state: .declared,
                    preparedAt: nil,
                    version: 1,
                    redactedAt: nil
                )
            )
        }
        let metadata = try executeStrictEngineCommand(
            branch: .recordEngineTerminalProposal,
            commandType: .engineTerminalProposalRecord,
            idempotencyKey: commandKey,
            payload: content,
            execution: execution,
            proposalId: proposal.id,
            occurredAt: now,
            database: transactionDatabase,
            conflict: { EngineTerminalConflictErrorV1() },
            apply: { database in
                try proposal.insert(database)
                for row in artifactRows {
                    try row.insert(database)
                }
                if execution.dispatchState == .prepared {
                    try database.execute(
                        sql: """
                            UPDATE engine_execution
                            SET dispatchState='terminalProposed',
                                dispatchStartedAt=?,updatedAt=?,
                                version=version+1
                            WHERE id=? AND version=? AND state='running'
                              AND dispatchState='prepared'
                              AND dispatchStartedAt IS NULL
                              AND nextSequence=?
                            """,
                        arguments: [
                            now,
                            now,
                            execution.id,
                            execution.version,
                            content.sequence,
                        ]
                    )
                } else {
                    try database.execute(
                        sql: """
                            UPDATE engine_execution
                            SET dispatchState='terminalProposed',
                                nextSequence=nextSequence+?,updatedAt=?,
                                version=version+1
                            WHERE id=? AND version=? AND state='running'
                              AND dispatchState IN ('started','sessionBound')
                              AND nextSequence=?
                            """,
                        arguments: [
                            consumeSequence ? 1 : 0,
                            now,
                            execution.id,
                            execution.version,
                            content.sequence,
                        ]
                    )
                }
                guard database.changesCount == 1 else {
                    throw EngineTerminalConflictErrorV1()
                }
            }
        )
        guard !metadata.wasReplay else {
            throw DomainCommandGraphIntegrityError()
        }
        try validateStrictEngineMetadata(
            metadata,
            executionId: execution.id,
            requestHash: execution.requestHash,
            proposalId: proposal.id,
            proposalHash: proposal.proposalHash
        )
        return try proposalSnapshot(
            proposal: proposal,
            database: transactionDatabase
        )
    }

    package func commitEnginePreDispatchFailure(
        executionId: String,
        expectedVersion: Int,
        failure: EnginePreDispatchFailureV1,
        commandIdempotencyKey: String,
        now: Date
    ) throws -> EngineTerminalCommitReceiptV1 {
        try database.pool.write { transactionDatabase in
            let execution = try requireExecution(
                executionId,
                database: transactionDatabase
            )
            let terminalKey =
                "engine.pre-dispatch-failure.v1:\(execution.id)"
            guard commandIdempotencyKey == "engine.terminal.v1:\(terminalKey)"
            else {
                throw EngineTerminalConflictErrorV1()
            }
            let isReplay = try commandReceiptExists(
                commandIdempotencyKey,
                database: transactionDatabase
            ) || commandReceiptExists(
                "engine.terminal-proposal.v1:\(terminalKey)",
                database: transactionDatabase
            )
            if !isReplay {
                let validTaxonomy = failure.terminalKind == .failed
                    && failure.terminalSubtype == nil
                    || failure.terminalKind == .blocked
                    && failure.terminalSubtype == .engineProtocolError
                guard validTaxonomy,
                      execution.state == .running,
                      execution.dispatchState == .prepared,
                      execution.version == expectedVersion,
                      execution.dispatchStartedAt == nil
                else {
                    throw EngineTerminalConflictErrorV1()
                }
            }
            return try commitSyntheticTerminalInTransaction(
                execution: execution,
                terminalKind: failure.terminalKind,
                terminalSubtype: failure.terminalSubtype,
                reasonCode: failure.reasonCode,
                detail: failure.detail,
                terminalIdempotencyKey: terminalKey,
                attention: false,
                now: now,
                database: transactionDatabase
            )
        }
    }

    package func commitEngineTerminal(
        proposalId: String,
        checkedUsage: EngineUsageV1,
        now: Date
    ) throws -> EngineTerminalCommitReceiptV1 {
        try database.pool.write { transactionDatabase in
            guard let proposal = try EngineTerminalProposalRecord.fetchOne(
                transactionDatabase,
                key: proposalId
            ), let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: proposal.executionId
            ) else {
                throw EngineTerminalConflictErrorV1()
            }
            let content = try decodeProposal(proposal)
            try content.validateCompletedHandoffManifest()
            guard content.terminalSubtype != .needsHumanInput else {
                throw EngineTerminalConflictErrorV1()
            }
            let commandKey = "engine.terminal.v1:\(proposal.terminalIdempotencyKey)"
            let isReplay = try commandReceiptExists(
                commandKey,
                database: transactionDatabase
            )
            var terminalArtifactIds: [String] = []
            if !isReplay {
                let expectedNextSequence = try proposal.sequence
                    .addingEngineChecked(1)
                guard proposal.state == .pending,
                      execution.state == .running,
                      execution.dispatchState == .terminalProposed,
                      execution.nextSequence == expectedNextSequence
                else {
                    throw EngineTerminalConflictErrorV1()
                }
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
                if content.artifacts.isEmpty {
                    let artifactCount = try Int.fetchOne(
                        transactionDatabase,
                        sql: """
                            SELECT COUNT(*) FROM engine_proposal_artifact
                            WHERE proposalId=?
                            """,
                        arguments: [proposal.id]
                    ) ?? -1
                    guard artifactCount == 0 else {
                        throw EngineTerminalConflictErrorV1()
                    }
                } else {
                    guard let artifactBlobStore,
                          let artifactStorageOriginStore
                    else {
                        throw EngineTerminalConflictErrorV1()
                    }
                    let prepared = try artifactBlobStore
                        .validatePreparedArtifacts(
                            proposalId: proposal.id,
                            database: transactionDatabase
                        )
                    try validatePreparedArtifactsForTerminalCommit(
                        prepared,
                        proposal: proposal,
                        content: content,
                        execution: execution,
                        database: transactionDatabase
                    )
                    let inserted = try artifactStorageOriginStore
                        .insertPreparedArtifacts(
                            prepared,
                            proposalId: proposal.id,
                            database: transactionDatabase
                        )
                    terminalArtifactIds = inserted.map(\.id)
                    guard terminalArtifactIds
                        == prepared.map(\.artifactId)
                    else {
                        throw DomainCommandGraphIntegrityError()
                    }
                }
            } else if !content.artifacts.isEmpty {
                terminalArtifactIds = try validateCommittedArtifactGraph(
                    proposal: proposal,
                    content: content,
                    execution: execution,
                    database: transactionDatabase
                )
            }
            return try executeTerminalCommitCommand(
                execution: execution,
                terminalKind: content.terminalKind,
                terminalSubtype: content.terminalSubtype,
                reasonCode: content.payload.reasonCode,
                detail: content.payload.detail ?? "",
                disposition: .committedProposal,
                commandIdempotencyKey: commandKey,
                proposal: proposal,
                proposalContent: content,
                artifactIds: terminalArtifactIds,
                checkedUsage: checkedUsage,
                consumeSequence: false,
                attention:
                    content.terminalSubtype == .externalEffectUnknown,
                now: now,
                database: transactionDatabase
            )
        }
    }

    package func commitEngineAskUser(
        proposalId: String,
        checkedUsage: EngineUsageV1,
        now: Date
    ) throws -> EngineTerminalCommitReceiptV1 {
        try database.pool.write { transactionDatabase in
            guard let proposal = try EngineTerminalProposalRecord.fetchOne(
                transactionDatabase,
                key: proposalId
            ), let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: proposal.executionId
            ) else {
                throw EngineTerminalConflictErrorV1()
            }
            let content = try decodeProposal(proposal)
            guard content.terminalKind == .blocked,
                  content.terminalSubtype == .needsHumanInput,
                  content.payload.humanInput != nil
            else {
                throw EngineTerminalConflictErrorV1()
            }
            let commandKey = "engine.terminal.v1:\(proposal.terminalIdempotencyKey)"
            let isReplay = try commandReceiptExists(
                commandKey,
                database: transactionDatabase
            )
            if !isReplay {
                let expectedNextSequence = try proposal.sequence
                    .addingEngineChecked(1)
                guard proposal.state == .pending,
                      execution.state == .running,
                      execution.dispatchState == .terminalProposed,
                      execution.nextSequence == expectedNextSequence
                else {
                    throw EngineTerminalConflictErrorV1()
                }
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
            }
            return try executeTerminalCommitCommand(
                execution: execution,
                terminalKind: .blocked,
                terminalSubtype: .needsHumanInput,
                reasonCode: "needs_human_input",
                detail: content.payload.humanInput?.prompt ?? "",
                disposition: .committedProposal,
                commandIdempotencyKey: commandKey,
                proposal: proposal,
                proposalContent: content,
                checkedUsage: checkedUsage,
                askUser: true,
                consumeSequence: false,
                attention: false,
                now: now,
                database: transactionDatabase
            )
        }
    }

    package func invalidateProposalAndCommitProtocolError(
        proposalId: String,
        expectedVersion: Int,
        failure: EngineTerminalPreparationFailure,
        commandIdempotencyKey: String,
        now: Date
    ) throws -> EngineTerminalCommitReceiptV1 {
        try database.pool.write { transactionDatabase in
            guard let proposal = try EngineTerminalProposalRecord.fetchOne(
                transactionDatabase,
                key: proposalId
            ), let execution = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: proposal.executionId
            ) else {
                throw EngineTerminalConflictErrorV1()
            }
            let isReplay = try commandReceiptExists(
                commandIdempotencyKey,
                database: transactionDatabase
            )
            if !isReplay {
                try validateReasonCode(failure.reasonCode)
                try validateDetail(failure.detail)
                let expectedNextSequence = try proposal.sequence
                    .addingEngineChecked(1)
                guard proposal.state == .pending,
                      proposal.version == expectedVersion,
                      execution.state == .running,
                      execution.dispatchState == .terminalProposed,
                      execution.nextSequence == expectedNextSequence
                else {
                    throw EngineTerminalConflictErrorV1()
                }
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
            }
            return try executeTerminalCommitCommand(
                execution: execution,
                terminalKind: .blocked,
                terminalSubtype: .engineProtocolError,
                reasonCode: failure.reasonCode,
                detail: failure.detail,
                disposition: .invalidProtocolError,
                commandIdempotencyKey: commandIdempotencyKey,
                proposal: proposal,
                checkedUsage: .zero,
                invalidateProposal: true,
                consumeSequence: false,
                attention: true,
                now: now,
                database: transactionDatabase
            )
        }
    }

    private func commitSyntheticTerminalInTransaction(
        execution: EngineExecutionRecord,
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        reasonCode: String,
        detail: String,
        terminalIdempotencyKey: String,
        attention: Bool,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        try validateBoundedIdentity(terminalIdempotencyKey)
        try validateReasonCode(reasonCode)
        try validateDetail(detail)
        let proposalKey =
            "engine.terminal-proposal.v1:\(terminalIdempotencyKey)"
        let commitKey = "engine.terminal.v1:\(terminalIdempotencyKey)"
        let hasProposalReceipt = try commandReceiptExists(
            proposalKey,
            database: transactionDatabase
        )
        let hasCommitReceipt = try commandReceiptExists(
            commitKey,
            database: transactionDatabase
        )
        guard hasProposalReceipt == hasCommitReceipt else {
            throw DomainCommandGraphIntegrityError()
        }
        let existingProposal = try EngineTerminalProposalRecord.fetchOne(
            transactionDatabase,
            sql: """
                SELECT * FROM engine_terminal_proposal
                WHERE terminalIdempotencyKey=? OR executionId=?
                ORDER BY CASE WHEN terminalIdempotencyKey=? THEN 0 ELSE 1 END
                LIMIT 1
                """,
            arguments: [
                terminalIdempotencyKey,
                execution.id,
                terminalIdempotencyKey,
            ]
        )
        if hasProposalReceipt != (existingProposal != nil) {
            throw DomainCommandGraphIntegrityError()
        }
        let payload: EngineTerminalPayloadV1
        switch terminalKind {
        case .completed:
            throw EngineTerminalConflictErrorV1()
        case .blocked:
            payload = .blocked(reasonCode: reasonCode, detail: detail)
        case .failed:
            payload = .failed(code: reasonCode, detail: detail)
        case .canceled:
            payload = .canceled(reasonCode: reasonCode, detail: detail)
        }
        let content = try EngineTerminalProposalContentV1(
            protocolVersion: engineExecutionProtocolVersionV1,
            executionId: execution.id,
            runId: execution.runId,
            cardId: execution.cardId,
            sequence: execution.nextSequence,
            terminalIdempotencyKey: terminalIdempotencyKey,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            payload: payload,
            artifacts: []
        )
        let proposalSnapshot: EngineTerminalProposalSnapshotV1
        let clearSyntheticDispatchStart = execution.dispatchState == .prepared
        do {
            if let existingProposal {
                guard hasProposalReceipt,
                      existingProposal.executionId == execution.id
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                proposalSnapshot = try recordEngineTerminalProposal(
                    content,
                    consumeSequence: false,
                    database: transactionDatabase
                )
            } else {
                try requireActiveCampWriteFence(
                    execution,
                    database: transactionDatabase
                )
                proposalSnapshot = try recordEngineTerminalProposal(
                    content,
                    consumeSequence: false,
                    database: transactionDatabase
                )
            }
        } catch {
            Self.logRecoveryFailure(
                stage: "synthetic-proposal",
                executionId: execution.id,
                error: error
            )
            throw error
        }
        let currentExecution = try requireExecution(
            execution.id,
            database: transactionDatabase
        )
        do {
            return try executeTerminalCommitCommand(
                execution: currentExecution,
                terminalKind: terminalKind,
                terminalSubtype: terminalSubtype,
                reasonCode: reasonCode,
                detail: detail,
                disposition: .committedProposal,
                commandIdempotencyKey: commitKey,
                proposal: proposalSnapshot.proposal,
                proposalContent: content,
                checkedUsage: .zero,
                askUser: false,
                invalidateProposal: false,
                consumeSequence: false,
                clearSyntheticDispatchStart: clearSyntheticDispatchStart,
                attention: attention,
                now: now,
                database: transactionDatabase
            )
        } catch {
            Self.logRecoveryFailure(
                stage: "synthetic-commit",
                executionId: execution.id,
                error: error
            )
            throw error
        }
    }

    private func executeTerminalCommitCommand(
        execution: EngineExecutionRecord,
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        reasonCode: String?,
        detail: String,
        disposition: EngineTerminalCommitDispositionV1,
        commandIdempotencyKey: String,
        proposal: EngineTerminalProposalRecord,
        proposalContent: EngineTerminalProposalContentV1? = nil,
        artifactIds: [String] = [],
        checkedUsage: EngineUsageV1 = .zero,
        askUser: Bool = false,
        invalidateProposal: Bool = false,
        consumeSequence: Bool = false,
        clearSyntheticDispatchStart: Bool = false,
        attention: Bool,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        guard checkedUsage.inputTokens >= 0,
              checkedUsage.outputTokens >= 0,
              checkedUsage.cacheReadTokens >= 0,
              checkedUsage.costMicros >= 0
        else {
            throw EngineTerminalConflictErrorV1()
        }
        let payload = EngineTerminalCommandPayloadV1(
            executionId: execution.id,
            proposalId: proposal.id,
            proposalHash: proposal.proposalHash,
            disposition: disposition,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            reasonCode: reasonCode,
            detail: detail,
            checkedUsage: checkedUsage,
            artifactIds: artifactIds
        )
        let branch: P1ResultBranchV1 = attention
            ? .commitEngineTerminalWithAttention : .commitEngineTerminal
        let strict = try prepareStrictEngineCommand(
            branch: branch,
            commandType: .engineTerminalCommit,
            idempotencyKey: commandIdempotencyKey,
            payload: payload,
            execution: execution,
            occurredAt: now,
            database: transactionDatabase
        )
        if try !commandReceiptExists(
            commandIdempotencyKey,
            database: transactionDatabase
        ) {
            try transactionDatabase.execute(
                sql: "PRAGMA defer_foreign_keys = ON"
            )
        }
        let metadata: DomainCommandExecutionMetadataV1
        do {
            metadata = try domainEventStore.executeCommand(
                command: strict.prepared,
                replayPlan: strict.replayPlan,
                recordedAt: now,
                database: transactionDatabase
            ) { database in
                let executionVersion = try execution.version
                    .addingEngineChecked(1)
                let proposalVersion = try proposal.version
                    .addingEngineChecked(1)
                guard let eventVersion = try strict.replayPlan.shapes
                    .last?.aggregateVersion
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                let result = try CampSafeCommandResultV1.make(
                    branch: branch,
                    values: CampSafeResultValuesV1(
                        commandPayloadHash: strict.prepared.commandPayloadHash,
                        domainEventCount: strict.replayPlan.shapes.count,
                        outboxCount: strict.replayPlan.shapes.count,
                        occurredAt: now,
                        engineExecutionId: execution.id,
                        engineTerminalProposalId: proposal.id,
                        engineRequestHash: execution.requestHash,
                        engineTerminalProposalHash: proposal.proposalHash,
                        engineExecutionProjectionVersion: executionVersion,
                        engineTerminalProposalProjectionVersion:
                            proposalVersion,
                        engineExecutionEventVersion: eventVersion
                    )
                )
                let resultHash = CanonicalJSONV1.sha256Hex(
                    try CanonicalContractCodingV1.encode(result)
                )
                if invalidateProposal {
                    try database.execute(
                            sql: """
                                UPDATE engine_terminal_proposal
                                SET state='invalid',version=version+1,
                                    invalidReason=?,invalidatedAt=?
                                WHERE id=? AND version=? AND state='pending'
                                """,
                            arguments: [
                                reasonCode, now, proposal.id, proposal.version,
                            ]
                        )
                } else {
                    try database.execute(
                            sql: """
                                UPDATE engine_terminal_proposal
                                SET state='committed',version=version+1,
                                    committedAt=?
                                WHERE id=? AND version=? AND state='pending'
                                """,
                            arguments: [now, proposal.id, proposal.version]
                        )
                }
                guard database.changesCount == 1 else {
                    throw EngineTerminalConflictErrorV1()
                }
                try applyTerminalProjection(
                    execution: execution,
                    terminalKind: terminalKind,
                    terminalSubtype: terminalSubtype,
                    reasonCode: reasonCode,
                    detail: detail,
                    proposalContent: proposalContent,
                    checkedUsage: checkedUsage,
                    receiptIdempotencyKey: commandIdempotencyKey,
                    terminalReceiptHash: resultHash,
                    askUser: askUser,
                    consumeSequence: consumeSequence,
                    clearSyntheticDispatchStart: clearSyntheticDispatchStart,
                    now: now,
                    database: database
                )
                return try NewDomainCommandV1.make(
                    result: result,
                    replayPlan: strict.replayPlan
                )
            }
        } catch is DomainCommandReplayConflictError {
            throw EngineTerminalConflictErrorV1()
        }
        try validateStrictEngineMetadata(
            metadata,
            executionId: execution.id,
            requestHash: execution.requestHash,
            proposalId: proposal.id,
            proposalHash: proposal.proposalHash
        )
        guard let committedExecution = try EngineExecutionRecord.fetchOne(
            transactionDatabase,
            key: execution.id
        ), let finishedAt = committedExecution.finishedAt,
           committedExecution.dispatchState == .terminal,
           committedExecution.terminalReceiptIdempotencyKey
            == commandIdempotencyKey,
           committedExecution.terminalReceiptHash == metadata.resultHash,
           let committedProposal = try EngineTerminalProposalRecord.fetchOne(
            transactionDatabase,
            key: proposal.id
           ), committedProposal.proposalHash == proposal.proposalHash,
           invalidateProposal
            ? committedProposal.state == .invalid
            : committedProposal.state == .committed
        else {
            throw DomainCommandGraphIntegrityError()
        }
        if !artifactIds.isEmpty {
            guard !invalidateProposal,
                  disposition == .committedProposal,
                  terminalKind == .completed,
                  terminalSubtype == nil
            else {
                throw DomainCommandGraphIntegrityError()
            }
            let committedContent = try proposalContent
                ?? decodeProposal(committedProposal)
            let validatedArtifactIds = try validateCommittedArtifactGraph(
                proposal: committedProposal,
                content: committedContent,
                execution: committedExecution,
                database: transactionDatabase
            )
            guard validatedArtifactIds == artifactIds else {
                throw DomainCommandGraphIntegrityError()
            }
        }
        return try EngineTerminalCommitReceiptV1(
            receiptIdempotencyKey: commandIdempotencyKey,
            executionId: execution.id,
            proposalId: proposal.id,
            proposalHash: proposal.proposalHash,
            disposition: disposition,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            reasonCode: reasonCode,
            artifactIds: artifactIds,
            committedEventIds: metadata.eventIds,
            finishedAt: try P1DTimestampV1.restorePersisted(finishedAt),
            terminalReceiptHash: metadata.resultHash
        )
    }

    private func applyTerminalProjection(
        execution: EngineExecutionRecord,
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        reasonCode: String?,
        detail: String,
        proposalContent: EngineTerminalProposalContentV1?,
        checkedUsage: EngineUsageV1,
        receiptIdempotencyKey: String,
        terminalReceiptHash: String,
        askUser: Bool,
        consumeSequence: Bool,
        clearSyntheticDispatchStart: Bool,
        now: Date,
        database transactionDatabase: Database
    ) throws {
        let currentUsage = EngineUsageV1(
            inputTokens: execution.inputTokens,
            outputTokens: execution.outputTokens,
            cacheReadTokens: execution.cacheReadTokens,
            costMicros: execution.costMicros
        )
        let totalUsage = try currentUsage.adding(checkedUsage)
        guard var run = try RunRecord.fetchOne(
            transactionDatabase,
            key: execution.runId
        ), var card = try CardRecord.fetchOne(
            transactionDatabase,
            key: execution.cardId
        ), var mission = try MissionRecord.fetchOne(
            transactionDatabase,
            key: card.missionId
        ) else {
            throw EngineTerminalConflictErrorV1()
        }

        var userRequestID: String?
        if askUser {
            guard let humanInput = proposalContent?.payload.humanInput else {
                throw EngineTerminalConflictErrorV1()
            }
            let requestID = userRequestIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(requestID)
            let optionsJSON = String(
                decoding: try CanonicalJSONV1.encode(humanInput.options),
                as: UTF8.self
            )
            try UserRequestRecord(
                id: requestID,
                cardId: execution.cardId,
                kind: humanInput.kind,
                prompt: humanInput.prompt,
                optionsJson: optionsJSON,
                answerJson: nil,
                createdAt: now,
                answeredAt: nil,
                lifecycleState: .open,
                terminalReason: nil,
                redactedAt: nil
            ).insert(transactionDatabase)
            userRequestID = requestID
        }

        let executionState: EngineExecutionStateV1
        switch terminalKind {
        case .completed: executionState = .completed
        case .blocked: executionState = .blocked
        case .failed: executionState = .failed
        case .canceled: executionState = .canceled
        }
        try transactionDatabase.execute(
            sql: """
                UPDATE engine_execution
                SET dispatchState='terminal',state=?,terminalSubtype=?,
                    nextSequence=nextSequence+?,
                    terminalReceiptIdempotencyKey=?,terminalReceiptHash=?,
                    inputTokens=?,outputTokens=?,cacheReadTokens=?,costMicros=?,
                    dispatchStartedAt=CASE WHEN ?=1 THEN NULL
                        ELSE dispatchStartedAt END,
                    version=version+1,updatedAt=?,finishedAt=?
                WHERE id=? AND version=? AND state='running'
                """,
            arguments: [
                executionState.rawValue,
                terminalSubtype?.rawValue,
                consumeSequence ? 1 : 0,
                receiptIdempotencyKey,
                terminalReceiptHash,
                totalUsage.inputTokens,
                totalUsage.outputTokens,
                totalUsage.cacheReadTokens,
                totalUsage.costMicros,
                clearSyntheticDispatchStart ? 1 : 0,
                now,
                now,
                execution.id,
                execution.version,
            ]
        )
        guard transactionDatabase.changesCount == 1 else {
            throw EngineTerminalConflictErrorV1()
        }

        run.outcome = terminalKind.rawValue
        run.tokensIn = try run.tokensIn.addingEngineChecked(
            checkedUsage.inputTokens
        )
        run.tokensOut = try run.tokensOut.addingEngineChecked(
            checkedUsage.outputTokens
        )
        run.endedAt = now
        try run.update(transactionDatabase)

        let billedTokens = try checkedUsage.inputTokens
            .addingEngineChecked(checkedUsage.outputTokens)
        mission.spentTokens = try mission.spentTokens.addingEngineChecked(
            billedTokens
        )
        try mission.update(transactionDatabase)

        let legacyKind: String
        var legacyPayload: JSONValue = [
            "executionId": .string(execution.id),
            "reasonCode": reasonCode.map(JSONValue.string) ?? .null,
            "terminalKind": .string(terminalKind.rawValue),
        ]
        switch terminalKind {
        case .completed:
            guard let handoff = proposalContent?.payload.completedHandoff else {
                throw EngineTerminalConflictErrorV1()
            }
            card.status = .done
            card.blockedReasonJson = nil
            card.handoffJson = String(
                decoding: try CanonicalJSONV1.encode(handoff),
                as: UTF8.self
            )
            legacyKind = EventKind.cardCompleted
        case .blocked, .failed:
            card.status = .blocked
            var reasonPayload: JSONValue = [
                "detail": .string(detail),
                "reason": .string(reasonCode ?? terminalKind.rawValue),
            ]
            if let userRequestID {
                if case var .object(values) = reasonPayload {
                    values["userRequestId"] = .string(userRequestID)
                    reasonPayload = .object(values)
                }
                if case var .object(values) = legacyPayload {
                    values["userRequestId"] = .string(userRequestID)
                    legacyPayload = .object(values)
                }
            }
            card.blockedReasonJson = String(
                decoding: try CanonicalJSONV1.encode(reasonPayload),
                as: UTF8.self
            )
            card.handoffJson = nil
            legacyKind = terminalKind == .failed
                ? EventKind.runError : EventKind.cardBlocked
        case .canceled:
            card.status = .ready
            card.blockedReasonJson = nil
            card.handoffJson = nil
            legacyKind = EventKind.cardReady
        }
        try card.update(transactionDatabase)
        try database.rollupMission(
            transactionDatabase,
            missionId: mission.id
        )
        try appendLegacy(
            database: transactionDatabase,
            missionId: mission.id,
            cardId: execution.cardId,
            runId: execution.runId,
            kind: legacyKind,
            payload: legacyPayload,
            at: now
        )
        if let userRequestID, let humanInput = proposalContent?.payload.humanInput {
            try appendLegacy(
                database: transactionDatabase,
                missionId: mission.id,
                cardId: execution.cardId,
                runId: execution.runId,
                kind: EventKind.userRequestCreated,
                payload: [
                    "kind": .string(humanInput.kind.rawValue),
                    "prompt": .string(humanInput.prompt),
                    "userRequestId": .string(userRequestID),
                ],
                at: now
            )
        }
    }

    private func validateRecoveryMissionID(_ missionId: String?) throws {
        guard let missionId else { return }
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
    }

    private func selectedRecoveryExecutions(
        missionId: String?,
        database transactionDatabase: Database
    ) throws -> [EngineExecutionRecord] {
        if let missionId {
            return try EngineExecutionRecord.fetchAll(
                transactionDatabase,
                sql: """
                    SELECT execution.*
                    FROM engine_execution AS execution
                    JOIN card ON card.id=execution.cardId
                    WHERE execution.state='running'
                      AND card.missionId=?
                    ORDER BY execution.createdAt,execution.id
                    """,
                arguments: [missionId]
            )
        }
        return try EngineExecutionRecord.fetchAll(
            transactionDatabase,
            sql: """
                SELECT execution.*
                FROM engine_execution AS execution
                JOIN card ON card.id=execution.cardId
                WHERE execution.state='running'
                ORDER BY execution.createdAt,execution.id
                """
        )
    }

    private func validateRecoveryResult(
        _ result: EngineRecoveryProcessingResultV1,
        execution: EngineExecutionRecord,
        database transactionDatabase: Database
    ) throws {
        switch result {
        case let .receipt(receipt):
            guard receipt.executionId == execution.id,
                  let terminal = try EngineExecutionRecord.fetchOne(
                      transactionDatabase,
                      key: execution.id
                  )
            else {
                throw EngineDispatchConflictErrorV1()
            }
            let persisted = try reconstructTerminalReceipt(
                execution: terminal,
                database: transactionDatabase
            )
            guard persisted == receipt else {
                throw DomainCommandGraphIntegrityError()
            }
        case let .directive(directive):
            guard directive.executionId == execution.id else {
                throw EngineDispatchConflictErrorV1()
            }
            if let request = directive.request {
                guard request == (try rehydrateRequest(execution)) else {
                    throw EngineDispatchConflictErrorV1()
                }
            } else {
                guard case .deferCampDeletion = directive.action else {
                    throw EngineDispatchConflictErrorV1()
                }
            }
        case .noLongerActive:
            guard let lifecycle = try CampLifecycleStore(
                database: database
            ).lifecycle(
                campId: execution.campId,
                database: transactionDatabase
            ), lifecycle.state == .deletedTombstone
            else {
                throw EngineDispatchConflictErrorV1()
            }
        }
    }

    private func reconstructTerminalReceipt(
        execution: EngineExecutionRecord,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        var stage = "header"
        do {
            guard execution.state != .running,
                  execution.dispatchState == .terminal,
                  execution.redactedAt == nil,
                  let finishedAt = execution.finishedAt,
                  let receiptKey = execution.terminalReceiptIdempotencyKey,
                  let terminalReceiptHash = execution.terminalReceiptHash
            else {
                throw DomainCommandGraphIntegrityError()
            }
            try CanonicalContractCodingV1.validateFinite(finishedAt)
            let restoredFinishedAt = try P1DTimestampV1.restorePersisted(
                finishedAt
            )
            try EngineContractValidationV1.validateIdempotencyKey(receiptKey)
            try CanonicalContractCodingV1.validateLowercaseHash(
                terminalReceiptHash
            )
            if execution.terminalSubtype == .engineProtocolError {
                try validateQuarantinedRequestIdentity(execution)
            } else {
                _ = try rehydrateRequest(execution)
            }

            stage = "run-card"
            guard let run = try RunRecord.fetchOne(
                transactionDatabase,
                key: execution.runId
            ), run.cardId == execution.cardId,
               let runEndedAt = try P1DTimestampV1.restorePersisted(
                   run.endedAt
               ),
               let card = try CardRecord.fetchOne(
                   transactionDatabase,
                   key: execution.cardId
               ), runEndedAt == restoredFinishedAt,
               let ownedCampId = try String.fetchOne(
                   transactionDatabase,
                   sql: """
                       SELECT squad.campId
                       FROM card
                       JOIN mission ON mission.id=card.missionId
                       JOIN squad ON squad.id=mission.squadId
                       WHERE card.id=?
                       """,
                   arguments: [execution.cardId]
               ), ownedCampId == execution.campId
            else {
                throw DomainCommandGraphIntegrityError()
            }

            let terminalKind: EngineTerminalKindV1
            switch execution.state {
            case .completed: terminalKind = .completed
            case .blocked: terminalKind = .blocked
            case .failed: terminalKind = .failed
            case .canceled: terminalKind = .canceled
            case .running: throw DomainCommandGraphIntegrityError()
            }
            guard run.outcome == terminalKind.rawValue else {
                throw DomainCommandGraphIntegrityError()
            }

            stage = "proposal"
            let proposals = try EngineTerminalProposalRecord.fetchAll(
                transactionDatabase,
                sql: """
                    SELECT * FROM engine_terminal_proposal
                    WHERE executionId=? ORDER BY createdAt,id
                    """,
                arguments: [execution.id]
            )
            guard proposals.count == 1,
                  let proposal = proposals.first,
                  proposal.executionId == execution.id,
                  proposal.redactedAt == nil
            else {
                throw DomainCommandGraphIntegrityError()
            }
            try CanonicalContractCodingV1.validateCanonicalUUID(proposal.id)
            try CanonicalContractCodingV1.validateLowercaseHash(
                proposal.proposalHash
            )

            let disposition: EngineTerminalCommitDispositionV1
            let reasonCode: String?
            let artifactIds: [String]
            let committedContent: EngineTerminalProposalContentV1?
            switch proposal.state {
            case .committed:
                guard try P1DTimestampV1.restorePersisted(
                    proposal.committedAt
                ) == restoredFinishedAt,
                      proposal.invalidReason == nil,
                      proposal.invalidatedAt == nil
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                let content = try decodeProposal(proposal)
                try content.validateCompletedHandoffManifest()
                guard content.executionId == execution.id,
                      content.runId == execution.runId,
                      content.cardId == execution.cardId,
                      content.terminalKind == terminalKind,
                      content.terminalSubtype == execution.terminalSubtype
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                disposition = .committedProposal
                reasonCode = execution.terminalSubtype == .needsHumanInput
                    ? "needs_human_input" : content.payload.reasonCode
                artifactIds = content.artifacts.isEmpty
                    ? []
                    : try validateCommittedArtifactGraph(
                        proposal: proposal,
                        content: content,
                        execution: execution,
                        database: transactionDatabase
                    )
                committedContent = content
            case .invalid:
                guard proposal.committedAt == nil,
                      try P1DTimestampV1.restorePersisted(
                          proposal.invalidatedAt
                      ) == restoredFinishedAt,
                      let invalidReason = proposal.invalidReason
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                if invalidReason == "camp_deleted" {
                    guard terminalKind == .canceled,
                          execution.terminalSubtype == nil
                    else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    disposition = .invalidCampDeletion
                } else {
                    guard terminalKind == .blocked,
                          execution.terminalSubtype == .engineProtocolError
                    else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    disposition = .invalidProtocolError
                }
                reasonCode = invalidReason
                artifactIds = []
                committedContent = nil
            case .pending:
                throw DomainCommandGraphIntegrityError()
            }

            try validateTerminalProjection(
                execution: execution,
                proposalContent: committedContent,
                terminalKind: terminalKind,
                reasonCode: reasonCode,
                card: card
            )

            stage = "receipt"
            guard let commandReceipt = try DomainCommandReceiptRecordV1
                .fetchOne(transactionDatabase, key: receiptKey),
                  commandReceipt.idempotencyKey == receiptKey,
                  commandReceipt.commandType == .engineTerminalCommit,
                  commandReceipt.resultHash == terminalReceiptHash,
                  try P1DTimestampV1.restorePersisted(
                      commandReceipt.createdAt
                  ) == restoredFinishedAt
            else {
                throw DomainCommandGraphIntegrityError()
            }
            try CanonicalContractCodingV1.validateLowercaseHash(
                commandReceipt.commandPayloadHash
            )
            try CanonicalContractCodingV1.validateLowercaseHash(
                commandReceipt.resultHash
            )
            let resultBytes = Data(commandReceipt.resultJson.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: resultBytes)
            guard CanonicalJSONV1.sha256Hex(resultBytes)
                    == commandReceipt.resultHash
            else {
                throw DomainCommandGraphIntegrityError()
            }
            let result = try CanonicalContractCodingV1.decode(
                CampSafeCommandResultV1.self,
                from: resultBytes
            )
            stage = "result"
            let branch: P1ResultBranchV1
            switch commandReceipt.eventCount {
            case 1: branch = .commitEngineTerminal
            case 2: branch = .commitEngineTerminalWithAttention
            default: throw DomainCommandGraphIntegrityError()
            }
            let contract = try P1CommandContractCatalogV1.contract(for: branch)
            guard result.code == contract.resultCode,
                  result.refs.map(\.kind) == contract.refs,
                  result.hashes.map(\.kind) == contract.hashes,
                  result.versions.map(\.kind) == contract.versions,
                  result.counts.map(\.kind) == contract.counts,
                  result.times.map(\.kind) == contract.times,
                  result.refs.first(where: {
                      $0.kind == .engineExecution
                  })?.id == execution.id,
                  result.refs.first(where: {
                      $0.kind == .engineTerminalProposal
                  })?.id == proposal.id,
                  result.hashes.first(where: {
                      $0.kind == .commandPayload
                  })?.hash == commandReceipt.commandPayloadHash,
                  result.hashes.first(where: {
                      $0.kind == .engineRequest
                  })?.hash == execution.requestHash,
                  result.hashes.first(where: {
                      $0.kind == .engineTerminalProposal
                  })?.hash == proposal.proposalHash,
                  result.versions.first(where: {
                      $0.kind == .engineExecutionProjection
                  })?.value == execution.version,
                  result.versions.first(where: {
                      $0.kind == .engineTerminalProposalProjection
                  })?.value == proposal.version,
                  result.counts.first(where: {
                      $0.kind == .domainEvent
                  })?.value == commandReceipt.eventCount,
                  result.counts.first(where: {
                      $0.kind == .outbox
                  })?.value == commandReceipt.eventCount,
                  try result.times.first(where: {
                      $0.kind == .occurredAt
                  }).map({
                      try P1DTimestampV1.restorePersisted($0.value)
                  }) == restoredFinishedAt
            else {
                throw DomainCommandGraphIntegrityError()
            }

            let events = try DomainEventRecordV1
                .filter(Column("commandIdempotencyKey") == receiptKey)
                .order(Column("eventOrdinal"))
                .fetchAll(transactionDatabase)
            stage = "events"
            guard events.count == contract.events.count,
                  Set(events.map(\.id)).count == events.count,
                  result.versions.first(where: {
                      $0.kind == .engineExecutionEvent
                  })?.value == events.last?.aggregateVersion
            else {
                throw DomainCommandGraphIntegrityError()
            }
            for (event, expected) in zip(events, contract.events) {
                let payloadBytes = Data(event.payloadJson.utf8)
                try CanonicalJSONV1.validateCanonical(rawUTF8: payloadBytes)
                let audit = try CanonicalContractCodingV1.decode(
                    CampSafeAuditPayloadV1.self,
                    from: payloadBytes
                )
                let eventOccurredAt = try P1DTimestampV1.restorePersisted(
                    event.occurredAt
                )
                let eventRecordedAt = try P1DTimestampV1.restorePersisted(
                    event.recordedAt
                )
                guard event.campId == execution.campId,
                      event.aggregateType == .engineExecution,
                      event.aggregateId == execution.id,
                      event.eventOrdinal == expected.ordinal,
                      event.eventType == expected.eventType,
                      event.commandIdempotencyKey == receiptKey,
                      eventOccurredAt == restoredFinishedAt,
                      eventRecordedAt == restoredFinishedAt,
                      event.payloadHash == CanonicalJSONV1.sha256Hex(
                          payloadBytes
                      ),
                      audit.code == expected.auditCode,
                      audit.refs == result.refs,
                      audit.hashes == result.hashes,
                      audit.versions == result.versions,
                      audit.counts == result.counts,
                      audit.times == result.times,
                      try EventOutboxRecordV1.fetchOne(
                          transactionDatabase,
                          key: event.id
                      ) != nil
                else {
                    throw DomainCommandGraphIntegrityError()
                }
            }

            return try EngineTerminalCommitReceiptV1(
                receiptIdempotencyKey: receiptKey,
                executionId: execution.id,
                proposalId: proposal.id,
                proposalHash: proposal.proposalHash,
                disposition: disposition,
                terminalKind: terminalKind,
                terminalSubtype: execution.terminalSubtype,
                reasonCode: reasonCode,
                artifactIds: artifactIds,
                committedEventIds: events.map(\.id),
                finishedAt: restoredFinishedAt,
                terminalReceiptHash: terminalReceiptHash
            )
        } catch is DomainCommandGraphIntegrityError {
            Self.logRecoveryFailure(
                stage: "reconstruct-\(stage)",
                executionId: execution.id,
                error: DomainCommandGraphIntegrityError()
            )
            throw DomainCommandGraphIntegrityError()
        } catch {
            Self.logRecoveryFailure(
                stage: "reconstruct-\(stage)",
                executionId: execution.id,
                error: error
            )
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateTerminalProjection(
        execution: EngineExecutionRecord,
        proposalContent: EngineTerminalProposalContentV1?,
        terminalKind: EngineTerminalKindV1,
        reasonCode: String?,
        card: CardRecord
    ) throws {
        switch terminalKind {
        case .completed:
            guard execution.terminalSubtype == nil,
                  reasonCode == nil,
                  card.status == .done,
                  card.blockedReasonJson == nil,
                  let handoff = proposalContent?.payload.completedHandoff,
                  card.handoffJson == String(
                      decoding: try CanonicalJSONV1.encode(handoff),
                      as: UTF8.self
                  )
            else {
                throw DomainCommandGraphIntegrityError()
            }
        case .blocked, .failed:
            guard card.status == .blocked,
                  card.handoffJson == nil,
                  let reasonCode,
                  let blockedReasonJson = card.blockedReasonJson
            else {
                throw DomainCommandGraphIntegrityError()
            }
            let bytes = Data(blockedReasonJson.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
            let blockedReason = try CanonicalContractCodingV1.decode(
                JSONValue.self,
                from: bytes
            )
            guard blockedReason["reason"]?.stringValue == reasonCode else {
                throw DomainCommandGraphIntegrityError()
            }
        case .canceled:
            guard execution.terminalSubtype == nil,
                  reasonCode != nil,
                  card.status == .ready,
                  card.blockedReasonJson == nil,
                  card.handoffJson == nil
            else {
                throw DomainCommandGraphIntegrityError()
            }
        }
    }

    private func recoverInterruptedEngineExecutionInTransaction(
        _ execution: EngineExecutionRecord,
        now: Date,
        authority: EngineRecoveryAuthorityV1,
        database transactionDatabase: Database
    ) throws -> EngineRecoveryProcessingResultV1 {
        guard execution.state == .running,
              execution.redactedAt == nil
        else {
            throw EngineDispatchConflictErrorV1()
        }
        guard let lifecycle = try CampLifecycleStore(
            database: database
        ).lifecycle(campId: execution.campId, database: transactionDatabase)
        else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        switch lifecycle.state {
        case .deletionRequested, .deleting:
            let proposalId = try String.fetchOne(
                transactionDatabase,
                sql: """
                    SELECT id FROM engine_terminal_proposal
                    WHERE executionId=? AND state='pending'
                    ORDER BY createdAt,id LIMIT 1
                    """,
                arguments: [execution.id]
            )
            return .directive(
                EngineRecoveryDirectiveV1(
                    executionId: execution.id,
                    request: nil,
                    action: .deferCampDeletion(proposalId: proposalId)
                )
            )
        case .deletedTombstone:
            return .noLongerActive
        case .archived:
            throw CampLifecycleWriteAuthorizationError.inactive(.archived)
        case .active:
            break
        }
        guard lifecycle.version == execution.campLifecycleVersion else {
            throw CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(
                    expected: execution.campLifecycleVersion,
                    actual: lifecycle.version
                )
        }
        guard try Int.fetchOne(
            transactionDatabase,
            sql: "SELECT archived FROM camp WHERE id=?",
            arguments: [execution.campId]
        ) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        try requireNoSyntheticTerminalHistoryForRunningRecovery(
            executionId: execution.id,
            database: transactionDatabase
        )

        var snapshot: EngineExecutionRecoverySnapshotV1
        let descriptor: ExecutionEngineDescriptor
        do {
            snapshot = try recoverySnapshot(
                for: execution,
                lifecycle: lifecycle,
                includeSession: false,
                database: transactionDatabase
            )
            descriptor = try validatedRecoveryDescriptor(
                snapshot,
                database: transactionDatabase
            )
            let session = try recoverySession(
                execution: execution,
                request: snapshot.request,
                database: transactionDatabase
            )
            snapshot = EngineExecutionRecoverySnapshotV1(
                execution: execution,
                request: snapshot.request,
                proposal: snapshot.proposal,
                session: session,
                campLifecycleState: lifecycle.state,
                campLifecycleVersion: lifecycle.version
            )
            if let proposal = snapshot.proposal {
                _ = try validatedRecoveryProposal(
                    proposal,
                    execution: execution
                )
            }
        } catch is EngineExecutionReplayConflictError {
            return .receipt(try commitRecoveryProtocolError(
                execution: execution, now: now,
                database: transactionDatabase
            ))
        } catch is EngineTerminalConflictErrorV1 {
            return .receipt(try commitRecoveryProtocolError(
                execution: execution, now: now,
                database: transactionDatabase
            ))
        } catch is EngineSessionScopeMismatchError {
            return .receipt(try commitRecoveryProtocolError(
                execution: execution, now: now,
                database: transactionDatabase
            ))
        } catch is EngineDescriptorMismatchErrorV1 {
            return .receipt(try commitRecoveryProtocolError(
                execution: execution, now: now,
                database: transactionDatabase
            ))
        }

        if let proposal = snapshot.proposal {
            if !proposal.artifacts.isEmpty {
                return .directive(
                    EngineRecoveryDirectiveV1(
                        executionId: execution.id,
                        request: snapshot.request,
                        action: .prepareAndCommitProposal(
                            proposalId: proposal.proposal.id
                        )
                    )
                )
            }
            return .receipt(
                try commitRecoveryProposal(
                    proposal: proposal.proposal,
                    content: try validatedRecoveryProposal(
                        proposal,
                        execution: execution
                    ),
                    execution: execution,
                    now: now,
                    database: transactionDatabase
                )
            )
        }

        if execution.cancellationRequestedAt != nil {
            guard let reason = execution.cancellationReason else {
                return .receipt(try commitRecoveryProtocolError(
                    execution: execution, now: now,
                    database: transactionDatabase
                ))
            }
            switch execution.dispatchState {
            case .prepared:
                return .receipt(
                    try commitRecoveryCanceledAfterCleanup(
                        execution: execution,
                        reason: reason,
                        now: now,
                        database: transactionDatabase
                    )
                )
            case .started, .sessionBound:
                switch authority {
                case .exactExecutionAfterCleanup:
                    return .receipt(
                        try commitRecoveryCanceledAfterCleanup(
                            execution: execution,
                            reason: reason,
                            now: now,
                            database: transactionDatabase
                        )
                    )
                case .missionWide:
                    if descriptor.profileKind.isCLI {
                        return .directive(
                            EngineRecoveryDirectiveV1(
                                executionId: execution.id,
                                request: snapshot.request,
                                action: .cancelAndReconcile
                            )
                        )
                    }
                    if execution.replayClass == .nonReplayable {
                        return .receipt(
                            try commitRecoveryExternalEffectUnknown(
                                execution: execution,
                                now: now,
                                database: transactionDatabase
                            )
                        )
                    }
                }
            case .terminalProposed, .terminal:
                return .receipt(try commitRecoveryProtocolError(
                    execution: execution, now: now,
                    database: transactionDatabase
                ))
            }
        } else if execution.cancellationReason != nil {
            return .receipt(try commitRecoveryProtocolError(
                execution: execution, now: now,
                database: transactionDatabase
            ))
        }

        if execution.cancellationRequestedAt == nil,
           execution.replayClass == .nonReplayable,
           execution.dispatchState == .started
        {
            return .receipt(
                try commitRecoveryExternalEffectUnknown(
                    execution: execution,
                    now: now,
                    database: transactionDatabase
                )
            )
        }

        if execution.dispatchState == .prepared {
            return .directive(
                EngineRecoveryDirectiveV1(
                    executionId: execution.id,
                    request: snapshot.request,
                    action: .startPrepared
                )
            )
        }

        if let session = snapshot.session {
            do {
                let resumed = try sessionStore.requireExactResume(
                    execution: execution,
                    sessionId: session.id,
                    externalSessionId: try requireExternalSessionId(session),
                    descriptor: descriptor,
                    database: transactionDatabase,
                    now: now
                )
                guard let externalSessionID = resumed.externalSessionId else {
                    throw EngineSessionScopeMismatchError()
                }
                return .directive(
                    EngineRecoveryDirectiveV1(
                        executionId: execution.id,
                        request: snapshot.request,
                        action: .resumeSession(
                            sessionId: resumed.id,
                            externalSessionId: externalSessionID
                        )
                    )
                )
            } catch is EngineSessionScopeMismatchError {
                return .receipt(
                    try commitRecoveryProtocolError(
                        execution: execution,
                        now: now,
                        database: transactionDatabase
                    )
                )
            }
        }

        if execution.dispatchState == .started,
           execution.replayClass == .replaySafe
            || execution.replayClass == .idempotencyKeyed
        {
            return .directive(
                EngineRecoveryDirectiveV1(
                    executionId: execution.id,
                    request: snapshot.request,
                    action: .replayExecution
                )
            )
        }

        return .receipt(
            try commitRecoveryProtocolError(
                execution: execution,
                now: now,
                database: transactionDatabase
            )
        )
    }

    private func commitRecoveryCanceledAfterCleanup(
        execution: EngineExecutionRecord,
        reason: String,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        try commitSyntheticTerminalInTransaction(
            execution: execution,
            terminalKind: .canceled,
            terminalSubtype: nil,
            reasonCode: reason,
            detail: "engine execution canceled before dispatch",
            terminalIdempotencyKey:
                "engine.recovery.cancel-prepared.v1:\(execution.id)",
            attention: false,
            now: now,
            database: transactionDatabase
        )
    }

    private func commitRecoveryExternalEffectUnknown(
        execution: EngineExecutionRecord,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        try commitSyntheticTerminalInTransaction(
            execution: execution,
            terminalKind: .blocked,
            terminalSubtype: .externalEffectUnknown,
            reasonCode: "external_effect_unknown",
            detail: "non-replayable dispatch outcome is unknown",
            terminalIdempotencyKey:
                "engine.recovery.external-effect-unknown.v1:\(execution.id)",
            attention: true,
            now: now,
            database: transactionDatabase
        )
    }

    private func requireNoSyntheticTerminalHistoryForRunningRecovery(
        executionId: String,
        database transactionDatabase: Database
    ) throws {
        let terminalKeys = [
            "engine.pre-dispatch-failure.v1:\(executionId)",
            "engine.usage-overflow.v1:\(executionId)",
            "engine.recovery.cancel-prepared.v1:\(executionId)",
            "engine.recovery.external-effect-unknown.v1:\(executionId)",
            "engine.recovery.protocol-error.v1:\(executionId)",
        ]
        let hasProposal = try Int.fetchOne(
            transactionDatabase,
            sql: """
                SELECT EXISTS(
                  SELECT 1 FROM engine_terminal_proposal
                  WHERE terminalIdempotencyKey IN (?,?,?,?,?)
                )
                """,
            arguments: StatementArguments(terminalKeys)
        ) == 1
        let commandKeys = terminalKeys.flatMap { terminalKey in
            [
                "engine.terminal-proposal.v1:\(terminalKey)",
                "engine.terminal.v1:\(terminalKey)",
            ]
        }
        let hasReceipt = try Int.fetchOne(
            transactionDatabase,
            sql: """
                SELECT EXISTS(
                  SELECT 1 FROM domain_command_receipt
                  WHERE idempotencyKey IN (?,?,?,?,?,?,?,?,?,?)
                )
                """,
            arguments: StatementArguments(commandKeys)
        ) == 1
        guard !hasProposal, !hasReceipt else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func recoverySnapshot(
        for execution: EngineExecutionRecord,
        lifecycle: CampLifecycleSnapshotV1,
        includeSession: Bool = true,
        database transactionDatabase: Database
    ) throws -> EngineExecutionRecoverySnapshotV1 {
        let request = try rehydrateRequest(execution)

        let proposals = try EngineTerminalProposalRecord.fetchAll(
            transactionDatabase,
            sql: """
                SELECT * FROM engine_terminal_proposal
                WHERE executionId=? ORDER BY createdAt,id
                """,
            arguments: [execution.id]
        )
        guard proposals.count <= 1 else {
            throw EngineTerminalConflictErrorV1()
        }
        let proposalSnapshot: EngineTerminalProposalSnapshotV1?
        if let proposal = proposals.first {
            let expectedNextSequence = try proposal.sequence
                .addingEngineChecked(1)
            guard proposal.state == .pending,
                  execution.dispatchState == .terminalProposed,
                  proposal.executionId == execution.id,
                  execution.nextSequence == expectedNextSequence
            else {
                throw EngineTerminalConflictErrorV1()
            }
            proposalSnapshot = EngineTerminalProposalSnapshotV1(
                proposal: proposal,
                artifacts: try EngineProposalArtifactRecord.fetchAll(
                    transactionDatabase,
                    sql: """
                        SELECT * FROM engine_proposal_artifact
                        WHERE proposalId=? ORDER BY ordinal,id
                        """,
                    arguments: [proposal.id]
                )
            )
        } else {
            guard execution.dispatchState != .terminalProposed else {
                throw EngineTerminalConflictErrorV1()
            }
            proposalSnapshot = nil
        }

        let session: EngineSessionRecord? = if includeSession {
            try recoverySession(
                execution: execution,
                request: request,
                database: transactionDatabase
            )
        } else {
            nil
        }
        return EngineExecutionRecoverySnapshotV1(
            execution: execution,
            request: request,
            proposal: proposalSnapshot,
            session: session,
            campLifecycleState: lifecycle.state,
            campLifecycleVersion: lifecycle.version
        )
    }

    private func recoverySession(
        execution: EngineExecutionRecord,
        request: EngineExecutionRequest,
        database transactionDatabase: Database
    ) throws -> EngineSessionRecord? {
        if let boundID = execution.sessionId,
           let requestedID = request.sessionRef?.sessionId,
           boundID != requestedID
        {
            throw EngineSessionScopeMismatchError()
        }
        if execution.dispatchState == .sessionBound,
           execution.sessionId == nil
        {
            throw EngineSessionScopeMismatchError()
        }
        if execution.sessionId != nil,
           execution.dispatchState != .sessionBound,
           execution.dispatchState != .terminalProposed
        {
            throw EngineSessionScopeMismatchError()
        }
        guard let sessionID = execution.sessionId
                ?? request.sessionRef?.sessionId
        else {
            return nil
        }
        guard let session = try EngineSessionRecord.fetchOne(
            transactionDatabase,
            key: sessionID
        ), session.state == .active,
           session.redactedAt == nil,
           session.externalSessionId != nil,
           session.campId == execution.campId,
           session.profileId == execution.profileId,
           session.adapterId == execution.adapterId,
           session.adapterVersion == execution.adapterVersion,
           session.workspaceHash == request.workspace.hash,
           session.sessionScopeJson == execution.sessionScopeJson,
           session.sessionScopeHash == execution.sessionScopeHash
        else {
            throw EngineSessionScopeMismatchError()
        }
        if let requested = request.sessionRef {
            guard requested.sessionId == session.id,
                  requested.externalSessionId == session.externalSessionId
            else {
                throw EngineSessionScopeMismatchError()
            }
        }
        return session
    }

    private func validatedRecoveryDescriptor(
        _ snapshot: EngineExecutionRecoverySnapshotV1,
        database transactionDatabase: Database
    ) throws -> ExecutionEngineDescriptor {
        do {
            let descriptor = try exactDescriptor(
                for: snapshot.execution,
                requiredCapabilities:
                    snapshot.request.requiredCapabilities,
                database: transactionDatabase
            )
            guard let profile = try RuntimeProfileRecord.fetchOne(
                transactionDatabase,
                key: snapshot.execution.profileId
            ) else {
                throw EngineDescriptorMismatchErrorV1()
            }
            try validateDescriptor(
                descriptor,
                profile: profile,
                requiredCapabilities: snapshot.request.requiredCapabilities
            )
            let scope = try EngineSessionScopeV1.derived(
                campId: snapshot.request.campId,
                profileId: snapshot.request.profileId,
                descriptor: descriptor,
                engineKind: snapshot.request.engineKind,
                model: snapshot.request.model,
                workspaceHash: snapshot.request.workspace.hash,
                contract: snapshot.request.contract
            )
            let scopeBytes = try CanonicalJSONV1.encode(scope)
            guard String(decoding: scopeBytes, as: UTF8.self)
                    == snapshot.execution.sessionScopeJson,
                  CanonicalJSONV1.sha256Hex(scopeBytes)
                    == snapshot.execution.sessionScopeHash
            else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return descriptor
        } catch is EngineDescriptorMismatchErrorV1 {
            throw EngineDescriptorMismatchErrorV1()
        } catch {
            throw EngineDescriptorMismatchErrorV1()
        }
    }

    private func validatedRecoveryProposal(
        _ snapshot: EngineTerminalProposalSnapshotV1,
        execution: EngineExecutionRecord
    ) throws -> EngineTerminalProposalContentV1 {
        do {
            let proposal = snapshot.proposal
            let content = try decodeProposal(proposal)
            try content.validateCompletedHandoffManifest()
            let payloadBytes = try CanonicalJSONV1.encode(content.payload)
            let manifestBytes = try CanonicalJSONV1.encode(content.artifacts)
            let expectedNextSequence = try proposal.sequence
                .addingEngineChecked(1)
            guard proposal.state == .pending,
                  proposal.redactedAt == nil,
                  execution.dispatchState == .terminalProposed,
                  execution.nextSequence == expectedNextSequence,
                  content.runId == execution.runId,
                  content.cardId == execution.cardId,
                  proposal.payloadJson
                    == String(decoding: payloadBytes, as: UTF8.self),
                  proposal.payloadHash == CanonicalJSONV1.sha256Hex(payloadBytes),
                  proposal.artifactManifestJson
                    == String(decoding: manifestBytes, as: UTF8.self),
                  proposal.artifactManifestHash
                    == CanonicalJSONV1.sha256Hex(manifestBytes),
                  content.artifacts.count == snapshot.artifacts.count
            else {
                throw EngineTerminalConflictErrorV1()
            }
            for (declaration, artifact) in zip(
                content.artifacts,
                snapshot.artifacts
            ) {
                guard artifact.id == artifact.artifactId,
                      artifact.proposalId == proposal.id,
                      artifact.ordinal == declaration.ordinal,
                      artifact.sourceRelativePath
                        == declaration.sourceRelativePath,
                      artifact.kind == declaration.kind,
                      artifact.label == declaration.label,
                      artifact.byteCount == declaration.byteCount,
                      artifact.contentHash == declaration.contentHash,
                      artifact.redactedAt == nil
                else {
                    throw EngineTerminalConflictErrorV1()
                }
            }
            return content
        } catch is EngineTerminalConflictErrorV1 {
            throw EngineTerminalConflictErrorV1()
        } catch {
            throw EngineTerminalConflictErrorV1()
        }
    }

    private func commitRecoveryProposal(
        proposal: EngineTerminalProposalRecord,
        content: EngineTerminalProposalContentV1,
        execution: EngineExecutionRecord,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        let asksUser = content.terminalSubtype == .needsHumanInput
        let reasonCode = asksUser
            ? "needs_human_input" : content.payload.reasonCode
        let detail = asksUser
            ? content.payload.humanInput?.prompt ?? ""
            : content.payload.detail ?? ""
        return try executeTerminalCommitCommand(
            execution: execution,
            terminalKind: content.terminalKind,
            terminalSubtype: content.terminalSubtype,
            reasonCode: reasonCode,
            detail: detail,
            disposition: .committedProposal,
            commandIdempotencyKey:
                "engine.terminal.v1:\(proposal.terminalIdempotencyKey)",
            proposal: proposal,
            proposalContent: content,
            checkedUsage: .zero,
            askUser: asksUser,
            consumeSequence: false,
            attention:
                content.terminalSubtype == .externalEffectUnknown,
            now: now,
            database: transactionDatabase
        )
    }

    private func commitRecoveryProtocolError(
        execution: EngineExecutionRecord,
        now: Date,
        database transactionDatabase: Database
    ) throws -> EngineTerminalCommitReceiptV1 {
        let pendingProposal = try EngineTerminalProposalRecord.fetchOne(
            transactionDatabase,
            sql: """
                SELECT * FROM engine_terminal_proposal
                WHERE executionId=? AND state='pending'
                LIMIT 1
                """,
            arguments: [execution.id]
        )
        let terminalKey =
            "engine.recovery.protocol-error.v1:\(execution.id)"
        if let pendingProposal {
            return try executeTerminalCommitCommand(
                execution: execution,
                terminalKind: .blocked,
                terminalSubtype: .engineProtocolError,
                reasonCode: "engine_protocol_error",
                detail: "persisted engine recovery identity mismatch",
                disposition: .invalidProtocolError,
                commandIdempotencyKey: "engine.terminal.v1:\(terminalKey)",
                proposal: pendingProposal,
                checkedUsage: .zero,
                invalidateProposal: true,
                consumeSequence: false,
                attention: true,
                now: now,
                database: transactionDatabase
            )
        }
        return try commitSyntheticTerminalInTransaction(
            execution: execution,
            terminalKind: .blocked,
            terminalSubtype: .engineProtocolError,
            reasonCode: "engine_protocol_error",
            detail: "persisted engine recovery identity mismatch",
            terminalIdempotencyKey: terminalKey,
            attention: true,
            now: now,
            database: transactionDatabase
        )
    }

    private func decodeProposal(
        _ proposal: EngineTerminalProposalRecord
    ) throws -> EngineTerminalProposalContentV1 {
        do {
            let bytes = Data(proposal.proposalJson.utf8)
            let content = try CanonicalContractCodingV1.decode(
                EngineTerminalProposalContentV1.self,
                from: bytes
            )
            guard CanonicalJSONV1.sha256Hex(bytes) == proposal.proposalHash,
                  content.executionId == proposal.executionId,
                  content.terminalIdempotencyKey
                    == proposal.terminalIdempotencyKey,
                  content.sequence == proposal.sequence,
                  content.terminalKind == proposal.terminalKind,
                  content.terminalSubtype == proposal.terminalSubtype
            else {
                throw EngineTerminalConflictErrorV1()
            }
            return content
        } catch is EngineTerminalConflictErrorV1 {
            throw EngineTerminalConflictErrorV1()
        } catch {
            throw EngineTerminalConflictErrorV1()
        }
    }

    private func requireActiveCampWriteFence(
        _ execution: EngineExecutionRecord,
        database transactionDatabase: Database
    ) throws {
        _ = try CampLifecycleStore(database: database)
            .requireActiveCampWrite(
                campId: execution.campId,
                expectedLifecycleVersion: execution.campLifecycleVersion,
                database: transactionDatabase
            )
    }

    private func validatePreparedArtifactsForTerminalCommit(
        _ prepared: [PreparedArtifactV1],
        proposal: EngineTerminalProposalRecord,
        content: EngineTerminalProposalContentV1,
        execution: EngineExecutionRecord,
        database transactionDatabase: Database
    ) throws {
        do {
            let persisted = try EngineProposalArtifactRecord
                .filter(Column("proposalId") == proposal.id)
                .order(Column("ordinal"))
                .fetchAll(transactionDatabase)
            guard proposal.executionId == execution.id,
                  proposal.state == .pending,
                  proposal.redactedAt == nil,
                  content.executionId == execution.id,
                  content.cardId == execution.cardId,
                  content.runId == execution.runId,
                  !content.artifacts.isEmpty,
                  prepared.count == content.artifacts.count,
                  persisted.count == content.artifacts.count
            else {
                throw DomainCommandGraphIntegrityError()
            }
            for index in content.artifacts.indices {
                let declaration = content.artifacts[index]
                let row = persisted[index]
                let artifact = prepared[index]
                guard declaration.ordinal == index,
                      row.ordinal == index,
                      artifact.ordinal == index,
                      row.id == row.artifactId,
                      row.proposalId == proposal.id,
                      row.state == .prepared,
                      row.redactedAt == nil,
                      row.preparedAt != nil,
                      row.id == artifact.proposalArtifactId,
                      row.artifactId == artifact.artifactId,
                      row.sourceRelativePath
                        == declaration.sourceRelativePath,
                      row.kind == declaration.kind,
                      row.label == declaration.label,
                      row.byteCount == declaration.byteCount,
                      row.contentHash == declaration.contentHash,
                      row.version == artifact.proposalArtifactVersion,
                      row.preparedAt == artifact.preparedAt,
                      artifact.proposalId == proposal.id,
                      artifact.executionId == execution.id,
                      artifact.cardId == execution.cardId,
                      artifact.campId == execution.campId,
                      artifact.kind == declaration.kind,
                      artifact.label == declaration.label,
                      artifact.byteCount == declaration.byteCount,
                      artifact.contentHash == declaration.contentHash,
                      artifact.proposalArtifactVersion > 0,
                      artifact.blobVersion > 0
                else {
                    throw DomainCommandGraphIntegrityError()
                }
            }
        } catch is DomainCommandGraphIntegrityError {
            throw DomainCommandGraphIntegrityError()
        } catch {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateCommittedArtifactGraph(
        proposal: EngineTerminalProposalRecord,
        content: EngineTerminalProposalContentV1,
        execution: EngineExecutionRecord,
        database transactionDatabase: Database
    ) throws -> [String] {
        do {
            try content.validateCompletedHandoffManifest()
            let persisted = try EngineProposalArtifactRecord
                .filter(Column("proposalId") == proposal.id)
                .order(Column("ordinal"))
                .fetchAll(transactionDatabase)
            guard proposal.executionId == execution.id,
                  proposal.state == .committed,
                  proposal.version == 2,
                  proposal.committedAt != nil,
                  proposal.invalidReason == nil,
                  proposal.invalidatedAt == nil,
                  proposal.redactedAt == nil,
                  execution.dispatchState == .terminal,
                  execution.state == .completed,
                  execution.terminalSubtype == nil,
                  content.executionId == execution.id,
                  content.cardId == execution.cardId,
                  content.runId == execution.runId,
                  content.terminalKind == .completed,
                  content.terminalSubtype == nil,
                  !content.artifacts.isEmpty,
                  persisted.count == content.artifacts.count
            else {
                throw DomainCommandGraphIntegrityError()
            }

            var artifactIds: [String] = []
            artifactIds.reserveCapacity(persisted.count)
            for index in content.artifacts.indices {
                let declaration = content.artifacts[index]
                let proposalArtifact = persisted[index]
                guard declaration.ordinal == index,
                      proposalArtifact.ordinal == index,
                      proposalArtifact.id == proposalArtifact.artifactId,
                      proposalArtifact.proposalId == proposal.id,
                      proposalArtifact.sourceRelativePath
                        == declaration.sourceRelativePath,
                      proposalArtifact.kind == declaration.kind,
                      proposalArtifact.label == declaration.label,
                      proposalArtifact.byteCount == declaration.byteCount,
                      proposalArtifact.contentHash == declaration.contentHash,
                      proposalArtifact.state == .prepared,
                      proposalArtifact.version == 2,
                      proposalArtifact.redactedAt == nil,
                      let preparedAt = proposalArtifact.preparedAt,
                      let artifact = try ArtifactRecord.fetchOne(
                          transactionDatabase,
                          key: proposalArtifact.artifactId
                      ), artifact.id == proposalArtifact.artifactId,
                      artifact.cardId == execution.cardId,
                      artifact.kind == proposalArtifact.kind,
                      artifact.label == proposalArtifact.label,
                      artifact.createdAt == preparedAt,
                      let origin = try ArtifactStorageOriginRecord.fetchOne(
                          transactionDatabase,
                          key: proposalArtifact.artifactId
                      ), origin.artifactId == artifact.id,
                      origin.campId == execution.campId,
                      origin.state == .active,
                      origin.storageClass == .managed,
                      origin.evidenceKind == .typedPreparedArtifact,
                      origin.managedRootId != nil,
                      origin.objectId != nil,
                      origin.contentHash == proposalArtifact.contentHash,
                      origin.fileIdentityHash != nil,
                      origin.originalRefHash
                        == CanonicalJSONV1.sha256Hex(Data(artifact.path.utf8)),
                      origin.version == 1,
                      origin.classifiedAt == preparedAt,
                      origin.terminalDisposition == nil,
                      origin.terminalAuthorityHash == nil,
                      origin.redactedAt == nil,
                      let reference = try ArtifactBlobReferenceRecord.fetchOne(
                          transactionDatabase,
                          key: proposalArtifact.artifactId
                      ), reference.artifactId == artifact.id,
                      reference.proposalArtifactId == proposalArtifact.id,
                      reference.executionId == execution.id,
                      reference.campId == execution.campId,
                      reference.contentHash == proposalArtifact.contentHash,
                      reference.state == .active,
                      reference.createdAt == preparedAt,
                      reference.tombstonedAt == nil,
                      let blob = try ArtifactBlobRecord.fetchOne(
                          transactionDatabase,
                          key: proposalArtifact.contentHash
                      ), blob.contentHash == proposalArtifact.contentHash,
                      blob.byteCount == proposalArtifact.byteCount,
                      blob.relativePath == artifact.path,
                      blob.state == .available,
                      blob.version > 0,
                      blob.deletedAt == nil
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                try CanonicalContractCodingV1.validateNonempty(
                    origin.managedRootId ?? ""
                )
                try CanonicalContractCodingV1.validateNonempty(
                    origin.objectId ?? ""
                )
                try CanonicalContractCodingV1.validateLowercaseHash(
                    origin.fileIdentityHash ?? ""
                )
                try CanonicalContractCodingV1.validateLowercaseHash(
                    origin.originalRefHash
                )
                try CanonicalContractCodingV1.validateLowercaseHash(
                    origin.classificationEvidenceHash
                )
                artifactIds.append(artifact.id)
            }
            guard Set(artifactIds).count == artifactIds.count else {
                throw DomainCommandGraphIntegrityError()
            }
            return artifactIds
        } catch is DomainCommandGraphIntegrityError {
            throw DomainCommandGraphIntegrityError()
        } catch {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func resolveSessionReference(
        _ selection: EngineSessionSelectionV1?,
        predecessorExecutionId: String?,
        cardId: String,
        campId: String,
        profileId: String,
        descriptor: ExecutionEngineDescriptor,
        workspaceHash: String,
        scopeJSON: String,
        scopeHash: String,
        database transactionDatabase: Database
    ) throws -> EngineSessionReferenceV1? {
        guard selection == nil || predecessorExecutionId == nil else {
            throw EngineSessionScopeMismatchError()
        }
        if let predecessorExecutionId {
            return try resolvePredecessorSession(
                predecessorExecutionId: predecessorExecutionId,
                cardId: cardId,
                campId: campId,
                profileId: profileId,
                descriptor: descriptor,
                workspaceHash: workspaceHash,
                scopeJSON: scopeJSON,
                scopeHash: scopeHash,
                database: transactionDatabase
            )
        }
        guard let selection else { return nil }
        guard descriptor.sessionResume == .supported,
              let session = try EngineSessionRecord.fetchOne(
                transactionDatabase,
                key: selection.sessionId
              ), session.state == .active,
              session.redactedAt == nil,
              let externalSessionId = session.externalSessionId,
              session.campId == campId,
              session.profileId == profileId,
              session.adapterId == descriptor.adapterId,
              session.adapterVersion == descriptor.adapterVersion,
              session.workspaceHash == workspaceHash,
              session.sessionScopeJson == scopeJSON,
              session.sessionScopeHash == scopeHash
        else {
            throw EngineSessionScopeMismatchError()
        }
        return try EngineSessionReferenceV1(
            sessionId: session.id,
            externalSessionId: externalSessionId
        )
    }

    private func requireExactBoundSessionReference(
        execution: EngineExecutionRecord,
        request: EngineExecutionRequest,
        sessionId: String,
        externalSessionId: String,
        database transactionDatabase: Database
    ) throws -> EngineSessionReferenceV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        guard execution.state == .running,
              execution.dispatchState == .sessionBound,
              execution.sessionId == sessionId,
              execution.redactedAt == nil,
              request.executionId == execution.id,
              request.requestHash == execution.requestHash,
              request.campId == execution.campId,
              request.profileId == execution.profileId,
              request.adapterId == execution.adapterId,
              request.adapterVersion == execution.adapterVersion,
              request.sessionScopeJson == execution.sessionScopeJson,
              request.sessionScopeHash == execution.sessionScopeHash,
              let session = try EngineSessionRecord.fetchOne(
                  transactionDatabase,
                  key: sessionId
              ), session.id == sessionId,
              session.state == .active,
              session.redactedAt == nil,
              let persistedExternalSessionId = session.externalSessionId,
              persistedExternalSessionId.utf8.elementsEqual(
                  externalSessionId.utf8
              ),
              session.campId == execution.campId,
              session.campId == request.campId,
              session.profileId == execution.profileId,
              session.profileId == request.profileId,
              session.adapterId == execution.adapterId,
              session.adapterId == request.adapterId,
              session.adapterVersion == execution.adapterVersion,
              session.adapterVersion == request.adapterVersion,
              session.workspaceHash == request.workspace.hash,
              session.sessionScopeJson == execution.sessionScopeJson,
              session.sessionScopeJson == request.sessionScopeJson,
              session.sessionScopeHash == execution.sessionScopeHash,
              session.sessionScopeHash == request.sessionScopeHash
        else {
            throw EngineSessionScopeMismatchError()
        }
        if let canonicalReference = request.sessionRef {
            guard canonicalReference.sessionId == session.id,
                  canonicalReference.externalSessionId.utf8.elementsEqual(
                      externalSessionId.utf8
                  )
            else {
                throw EngineSessionScopeMismatchError()
            }
        }
        return try EngineSessionReferenceV1(
            sessionId: session.id,
            externalSessionId: externalSessionId
        )
    }

    private func resolvePredecessorSession(
        predecessorExecutionId: String,
        cardId: String,
        campId: String,
        profileId: String,
        descriptor: ExecutionEngineDescriptor,
        workspaceHash: String,
        scopeJSON: String,
        scopeHash: String,
        database transactionDatabase: Database
    ) throws -> EngineSessionReferenceV1? {
        guard descriptor.sessionResume == .supported,
              let predecessor = try EngineExecutionRecord.fetchOne(
                transactionDatabase,
                key: predecessorExecutionId
              ), predecessor.id == predecessorExecutionId,
              predecessor.state != .running,
              predecessor.dispatchState == .terminal,
              predecessor.finishedAt != nil,
              predecessor.redactedAt == nil,
              predecessor.cardId == cardId,
              predecessor.campId == campId,
              predecessor.profileId == profileId,
              predecessor.adapterId == descriptor.adapterId,
              predecessor.adapterVersion == descriptor.adapterVersion,
              predecessor.sessionScopeJson == scopeJSON,
              predecessor.sessionScopeHash == scopeHash,
              let predecessorSessionId = predecessor.sessionId,
              let session = try EngineSessionRecord.fetchOne(
                transactionDatabase,
                key: predecessorSessionId
              ), session.id == predecessorSessionId,
              session.state == .active,
              session.redactedAt == nil,
              let externalSessionId = session.externalSessionId,
              session.campId == campId,
              session.profileId == profileId,
              session.adapterId == descriptor.adapterId,
              session.adapterVersion == descriptor.adapterVersion,
              session.workspaceHash == workspaceHash,
              session.sessionScopeJson == scopeJSON,
              session.sessionScopeHash == scopeHash
        else {
            throw EngineSessionScopeMismatchError()
        }
        return try EngineSessionReferenceV1(
            sessionId: session.id,
            externalSessionId: externalSessionId
        )
    }

    private func proposalSnapshot(
        proposal: EngineTerminalProposalRecord,
        database transactionDatabase: Database
    ) throws -> EngineTerminalProposalSnapshotV1 {
        let content = try decodeProposal(proposal)
        try content.validateCompletedHandoffManifest()
        let artifacts = try EngineProposalArtifactRecord
            .filter(Column("proposalId") == proposal.id)
            .order(Column("ordinal"))
            .fetchAll(transactionDatabase)
        guard artifacts.count == content.artifacts.count else {
            throw DomainCommandGraphIntegrityError()
        }
        for (declaration, artifact) in zip(content.artifacts, artifacts) {
            guard artifact.id == artifact.artifactId,
                  artifact.proposalId == proposal.id,
                  artifact.ordinal == declaration.ordinal,
                  artifact.sourceRelativePath == declaration.sourceRelativePath,
                  artifact.kind == declaration.kind,
                  artifact.label == declaration.label,
                  artifact.byteCount == declaration.byteCount,
                  artifact.contentHash == declaration.contentHash,
                  artifact.redactedAt == nil
            else {
                throw DomainCommandGraphIntegrityError()
            }
        }
        return EngineTerminalProposalSnapshotV1(
            proposal: proposal,
            artifacts: artifacts
        )
    }

    private func validateReasonCode(_ value: String) throws {
        try EngineContractValidationV1.validateReasonCode(value)
    }

    private func validateDetail(_ value: String) throws {
        try EngineContractValidationV1.validateDetail(value)
    }

    private func requireExternalSessionId(
        _ session: EngineSessionRecord
    ) throws -> String {
        guard let externalSessionId = session.externalSessionId else {
            throw EngineSessionScopeMismatchError()
        }
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        return externalSessionId
    }

    private func validatedContext(
        _ fields: EngineExecutionRequestFieldsV1
    ) throws -> EngineContextEnvelopeV1 {
        do {
            let bytes = Data(fields.contextJson.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
            guard CanonicalJSONV1.sha256Hex(bytes) == fields.contextHash else {
                throw EngineContextValidationErrorV1()
            }
            let envelope = try CanonicalContractCodingV1.decode(
                EngineContextEnvelopeV1.self,
                from: bytes
            )
            guard envelope.campId == fields.campId,
                  envelope.cardId == fields.cardId,
                  envelope.outcomeContract == fields.contract
            else {
                throw EngineContextValidationErrorV1()
            }
            try CanonicalContractCodingV1.validateCanonicalUUID(fields.cardId)
            try CanonicalContractCodingV1.validateCanonicalUUID(fields.profileId)
            try CanonicalContractCodingV1.validateLowercaseHash(
                fields.workspace.hash
            )
            try CanonicalContractCodingV1.validateNonempty(
                fields.workspace.reference
            )
            if let sessionSelection = fields.sessionSelection {
                try CanonicalContractCodingV1.validateCanonicalUUID(
                    sessionSelection.sessionId
                )
            }
            guard fields.budget.tokenLimit >= 0,
                  fields.budget.costMicrosLimit >= 0,
                  fields.budget.wallClockSeconds >= 0
            else {
                throw EngineContextValidationErrorV1()
            }
            return envelope
        } catch is EngineContextValidationErrorV1 {
            throw EngineContextValidationErrorV1()
        } catch {
            throw EngineContextValidationErrorV1()
        }
    }

    private func validateDescriptor(
        _ descriptor: ExecutionEngineDescriptor,
        profile: RuntimeProfileRecord,
        requiredCapabilities: [EngineCapabilityV1]
    ) throws {
        do {
            try CanonicalContractCodingV1.validateNonempty(
                descriptor.adapterId
            )
            try CanonicalContractCodingV1.validateNonempty(
                descriptor.adapterVersion
            )
        } catch {
            throw EngineDescriptorMismatchErrorV1()
        }
        let capabilitiesSupported = requiredCapabilities.allSatisfy {
            descriptor.support(for: $0) == .supported
        }
        guard descriptor.profileKind == profile.kind,
              capabilitiesSupported
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
    }

    private func claimedScopeMatches(
        fields: EngineExecutionRequestFieldsV1,
        canonicalJSON: String,
        hash: String
    ) -> Bool {
        switch (
            fields.claimedSessionScopeJson,
            fields.claimedSessionScopeHash
        ) {
        case (nil, nil):
            true
        case let (.some(json), .some(claimedHash)):
            json == canonicalJSON && claimedHash == hash
        default:
            false
        }
    }

    private func requestMatches(
        _ request: EngineExecutionRequest,
        fields: EngineExecutionRequestFieldsV1
    ) -> Bool {
        request.campId == fields.campId
            && request.cardId == fields.cardId
            && request.contract == fields.contract
            && request.profileId == fields.profileId
            && request.engineKind == fields.engineKind
            && request.model == fields.model
            && request.contextJson == fields.contextJson
            && request.contextHash == fields.contextHash
            && request.requiredCapabilities
                == fields.requiredCapabilities.sorted { $0.rawValue < $1.rawValue }
            && request.approvalGrantIds == fields.approvalGrantIds.sorted()
            && request.budget == fields.budget
            && request.workspace == fields.workspace
            && request.predecessorExecutionId
                == fields.predecessorExecutionId
            && (fields.predecessorExecutionId != nil
                || request.sessionRef?.sessionId
                    == fields.sessionSelection?.sessionId)
    }

    private func rehydrateRequest(
        _ record: EngineExecutionRecord
    ) throws -> EngineExecutionRequest {
        do {
            let bytes = Data(record.requestJson.utf8)
            let request = try CanonicalContractCodingV1.decode(
                EngineExecutionRequest.self,
                from: bytes
            )
            try request.validateCanonicalIdentity()
            guard request.executionId == record.id,
                  request.idempotencyKey == record.idempotencyKey,
                  request.campId == record.campId,
                  request.campLifecycleVersion
                    == record.campLifecycleVersion,
                  request.runId == record.runId,
                  request.cardId == record.cardId,
                  request.adapterId == record.adapterId,
                  request.adapterVersion == record.adapterVersion,
                  request.profileId == record.profileId,
                  request.engineKind == record.engineKind,
                  request.model == record.model,
                  request.replayClass == record.replayClass,
                  request.contextJson == record.contextJson,
                  request.contextHash == record.contextHash,
                  request.sessionScopeJson == record.sessionScopeJson,
                  request.sessionScopeHash == record.sessionScopeHash,
                  request.requestHash == record.requestHash
            else {
                throw EngineExecutionReplayConflictError()
            }
            return request
        } catch is EngineExecutionReplayConflictError {
            throw EngineExecutionReplayConflictError()
        } catch {
            throw EngineExecutionReplayConflictError()
        }
    }

    private func validateQuarantinedRequestIdentity(
        _ record: EngineExecutionRecord
    ) throws {
        do {
            let bytes = Data(record.requestJson.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
            try CanonicalContractCodingV1.validateLowercaseHash(
                record.requestHash
            )
            let request = try CanonicalContractCodingV1.decode(
                EngineExecutionRequest.self,
                from: bytes
            )
            try request.validateCanonicalIdentity()
            guard request.requestJson == record.requestJson,
                  request.requestHash == record.requestHash,
                  CanonicalJSONV1.sha256Hex(bytes) == record.requestHash
            else {
                throw EngineExecutionReplayConflictError()
            }
        } catch is EngineExecutionReplayConflictError {
            throw EngineExecutionReplayConflictError()
        } catch {
            throw EngineExecutionReplayConflictError()
        }
    }

    private func appendLegacy(
        database: Database,
        missionId: String?,
        cardId: String?,
        runId: String?,
        kind: String,
        payload: JSONValue,
        at date: Date
    ) throws {
        let payloadJSON = String(
            decoding: try CanonicalJSONV1.encode(payload),
            as: UTF8.self
        )
        _ = try AppDatabase.appendLegacyEventAndScope(
            database,
            missionId: missionId,
            cardId: cardId,
            runId: runId,
            kind: kind,
            payloadJSON: payloadJSON,
            createdAt: date
        )
    }

    private func commandReceiptExists(
        _ idempotencyKey: String,
        database: Database
    ) throws -> Bool {
        try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM domain_command_receipt
                WHERE idempotencyKey=?
                """,
            arguments: [idempotencyKey]
        ) == 1
    }

    private func requireExecution(
        _ executionID: String,
        database: Database
    ) throws -> EngineExecutionRecord {
        guard let execution = try EngineExecutionRecord.fetchOne(
            database,
            key: executionID
        ) else {
            throw EngineExecutionReplayConflictError()
        }
        return execution
    }

    private func missionID(
        forCard cardID: String,
        database: Database
    ) throws -> String {
        guard let missionID = try String.fetchOne(
            database,
            sql: "SELECT missionId FROM card WHERE id=?",
            arguments: [cardID]
        ) else {
            throw RecordNotFoundError(table: "card", id: cardID)
        }
        return missionID
    }

    private func exactDescriptor(
        for execution: EngineExecutionRecord,
        requiredCapabilities: [EngineCapabilityV1],
        database: Database
    ) throws -> ExecutionEngineDescriptor {
        guard let profile = try RuntimeProfileRecord.fetchOne(
            database,
            key: execution.profileId
        ) else {
            throw EngineDescriptorMismatchErrorV1()
        }
        let descriptor = try descriptorResolver(
            profile,
            requiredCapabilities
        )
        try validateDescriptor(
            descriptor,
            profile: profile,
            requiredCapabilities: requiredCapabilities
        )
        guard descriptor.profileKind == profile.kind,
              descriptor.adapterId == execution.adapterId,
              descriptor.adapterVersion == execution.adapterVersion
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        let scope: EngineSessionScopeV1
        do {
            scope = try CanonicalContractCodingV1.decode(
                EngineSessionScopeV1.self,
                from: Data(execution.sessionScopeJson.utf8)
            )
        } catch {
            throw EngineDescriptorMismatchErrorV1()
        }
        guard descriptor.executionReplayClass(for: scope)
                == execution.replayClass
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        return descriptor
    }

    private func engineEventPayloadJSON(
        _ payload: EngineExecutionEventPayloadV1
    ) throws -> JSONValue {
        switch payload {
        case .accepted:
            return ["kind": "accepted"]
        case let .sessionBound(externalSessionId):
            try CanonicalContractCodingV1.validateNonempty(externalSessionId)
            return [
                "externalSessionId": .string(externalSessionId),
                "kind": "sessionBound",
            ]
        case let .progress(message):
            try EngineContractValidationV1.validateProgress(message)
            return [
                "kind": "progress",
                "message": .string(message),
            ]
        case let .toolActivity(name):
            try EngineContractValidationV1.validateToolName(name)
            return [
                "kind": "toolActivity",
                "name": .string(name),
            ]
        case let .usage(usage):
            try usage.validateNonnegative()
            return [
                "cacheReadTokens": .number(Double(usage.cacheReadTokens)),
                "costMicros": .number(Double(usage.costMicros)),
                "inputTokens": .number(Double(usage.inputTokens)),
                "kind": "usage",
                "outputTokens": .number(Double(usage.outputTokens)),
            ]
        case .terminal:
            throw EngineEventSequenceErrorV1()
        }
    }

    private func prepareStrictEngineCommand<Payload: Encodable>(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        idempotencyKey: String,
        payload: Payload,
        execution: EngineExecutionRecord,
        occurredAt: Date,
        database transactionDatabase: Database
    ) throws -> EngineStrictCommandV1 {
        try validateBoundedIdentity(idempotencyKey)
        try CanonicalContractCodingV1.validateFinite(occurredAt)
        let contract = try P1CommandContractCatalogV1.contract(for: branch)
        guard contract.events.count > 0 else {
            throw P1ContractValidationError.invalidMembership
        }

        let hasReceipt = try commandReceiptExists(
            idempotencyKey,
            database: transactionDatabase
        )
        let storedVersions = try Int.fetchAll(
            transactionDatabase,
            sql: """
                SELECT aggregateVersion FROM domain_event
                WHERE commandIdempotencyKey=? ORDER BY eventOrdinal
                """,
            arguments: [idempotencyKey]
        )
        let firstExpectedVersion: Int
        if hasReceipt, let firstStoredVersion = storedVersions.first {
            let (value, overflow) = firstStoredVersion
                .subtractingReportingOverflow(1)
            guard !overflow, value >= 0 else {
                throw DomainCommandGraphIntegrityError()
            }
            firstExpectedVersion = value
        } else {
            firstExpectedVersion = try Int.fetchOne(
                transactionDatabase,
                sql: """
                    SELECT MAX(aggregateVersion) FROM domain_event
                    WHERE aggregateType=? AND aggregateId=?
                    """,
                arguments: [
                    P1AggregateTypeV1.engineExecution.rawValue,
                    execution.id,
                ]
            ) ?? 0
        }

        var shapes: [DomainEventReplayShapeV1] = []
        for (ordinal, event) in contract.events.enumerated() {
            let expectedVersion = try firstExpectedVersion
                .addingEngineChecked(ordinal)
            shapes.append(
                DomainEventReplayShapeV1(
                    campId: execution.campId,
                    aggregateType: .engineExecution,
                    aggregateId: execution.id,
                    expectedAggregateVersion: expectedVersion,
                    eventType: event.eventType,
                    auditCode: event.auditCode
                )
            )
        }
        let replayPlan = try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: commandType,
            shapes: shapes
        )
        let envelope = try CommandEnvelopeV1(
            idempotencyKey: idempotencyKey,
            actorType: .engine,
            actorId: "engine:kernel:v1",
            deviceId: nil,
            correlationId: execution.id,
            causationId: nil,
            occurredAt: occurredAt
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: commandType,
            envelope: envelope,
            payload: payload,
            replayPlan: replayPlan
        )
        return EngineStrictCommandV1(
            prepared: prepared,
            replayPlan: replayPlan
        )
    }

    private func executeStrictEngineCommand<Payload: Encodable>(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        idempotencyKey: String,
        payload: Payload,
        execution: EngineExecutionRecord,
        proposalId: String? = nil,
        occurredAt: Date,
        database transactionDatabase: Database,
        conflict: () -> any Error,
        apply: (Database) throws -> Void
    ) throws -> DomainCommandExecutionMetadataV1 {
        let strict = try prepareStrictEngineCommand(
            branch: branch,
            commandType: commandType,
            idempotencyKey: idempotencyKey,
            payload: payload,
            execution: execution,
            occurredAt: occurredAt,
            database: transactionDatabase
        )
        do {
            return try domainEventStore.executeCommand(
                command: strict.prepared,
                replayPlan: strict.replayPlan,
                recordedAt: occurredAt,
                database: transactionDatabase
            ) { database in
                try apply(database)
                let projectedExecution = try requireExecution(
                    execution.id,
                    database: database
                )
                let projectedProposal: EngineTerminalProposalRecord?
                if let proposalId {
                    guard let value = try EngineTerminalProposalRecord.fetchOne(
                        database,
                        key: proposalId
                    ) else {
                        throw EngineTerminalConflictErrorV1()
                    }
                    projectedProposal = value
                } else {
                    projectedProposal = nil
                }
                guard let finalEventVersion = try strict.replayPlan.shapes
                    .last?.aggregateVersion
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                let result = try CampSafeCommandResultV1.make(
                    branch: branch,
                    values: CampSafeResultValuesV1(
                        commandPayloadHash: strict.prepared.commandPayloadHash,
                        domainEventCount: strict.replayPlan.shapes.count,
                        outboxCount: strict.replayPlan.shapes.count,
                        occurredAt: occurredAt,
                        engineExecutionId: projectedExecution.id,
                        engineTerminalProposalId: projectedProposal?.id,
                        engineRequestHash: projectedExecution.requestHash,
                        engineTerminalProposalHash:
                            projectedProposal?.proposalHash,
                        engineExecutionProjectionVersion:
                            projectedExecution.version,
                        engineTerminalProposalProjectionVersion:
                            projectedProposal?.version,
                        engineExecutionEventVersion: finalEventVersion
                    )
                )
                return try NewDomainCommandV1.make(
                    result: result,
                    replayPlan: strict.replayPlan
                )
            }
        } catch is DomainCommandReplayConflictError {
            throw conflict()
        }
    }

    private func validateStrictEngineMetadata(
        _ metadata: DomainCommandExecutionMetadataV1,
        executionId: String,
        requestHash: String,
        proposalId: String? = nil,
        proposalHash: String? = nil
    ) throws {
        guard metadata.result.refs.first(where: {
            $0.kind == .engineExecution
        })?.id == executionId,
        metadata.result.hashes.first(where: {
            $0.kind == .engineRequest
        })?.hash == requestHash,
        metadata.result.refs.first(where: {
            $0.kind == .engineTerminalProposal
        })?.id == proposalId,
        metadata.result.hashes.first(where: {
            $0.kind == .engineTerminalProposal
        })?.hash == proposalHash
        else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateBoundedIdentity(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == trimmed,
              !value.isEmpty,
              value.unicodeScalars.count <= 256,
              value.utf8.count <= 256
        else {
            throw P1ContractValidationError.invalidIdentifier
        }
    }

}

private extension Int {
    func addingEngineChecked(_ other: Int) throws -> Int {
        let (value, overflow) = addingReportingOverflow(other)
        guard !overflow else {
            throw EngineUsageV1.UsageOverflowError()
        }
        return value
    }
}
