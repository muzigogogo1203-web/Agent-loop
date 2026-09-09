import Foundation
import GRDB

package enum EngineSessionDispositionV1: Sendable, Equatable {
    case closed
    case invalid
}

package struct EngineSessionStore: Sendable {
    private let sessionIdFactory: @Sendable () -> String

    package init(
        sessionIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    ) {
        self.sessionIdFactory = sessionIdFactory
    }

    package func bindOrReplay(
        execution: EngineExecutionRecord,
        externalSessionId: String,
        database: Database,
        now: Date
    ) throws -> EngineSessionRecord {
        try Self.validateBindableExecution(execution)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        try CanonicalContractCodingV1.validateFinite(now)
        let request = try Self.validatedRequest(
            for: execution
        )
        let workspaceHash = request.workspace.hash
        try Self.validateExecutionScope(
            execution,
            request: request
        )

        if let boundSessionId = execution.sessionId {
            guard let session = try EngineSessionRecord.fetchOne(
                database,
                key: boundSessionId
            ) else {
                throw EngineSessionScopeMismatchError()
            }
            try Self.requireExactSession(
                session,
                execution: execution,
                workspaceHash: workspaceHash,
                externalSessionId: externalSessionId
            )
            return session
        }

        let session: EngineSessionRecord
        if let existing = try EngineSessionRecord
            .filter(Column("adapterId") == execution.adapterId)
            .filter(Column("profileId") == execution.profileId)
            .filter(Column("externalSessionId") == externalSessionId)
            .fetchOne(database)
        {
            try Self.requireExactSession(
                existing,
                execution: execution,
                workspaceHash: workspaceHash,
                externalSessionId: externalSessionId
            )
            session = existing
        } else {
            let sessionId = sessionIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
            session = EngineSessionRecord(
                id: sessionId,
                campId: execution.campId,
                adapterId: execution.adapterId,
                adapterVersion: execution.adapterVersion,
                profileId: execution.profileId,
                externalSessionId: externalSessionId,
                workspaceHash: workspaceHash,
                sessionScopeJson: execution.sessionScopeJson,
                sessionScopeHash: execution.sessionScopeHash,
                state: .active,
                version: 1,
                createdAt: now,
                updatedAt: now,
                redactedAt: nil
            )
            try session.insert(database)
        }

        try Self.bind(
            execution: execution,
            sessionId: session.id,
            updatedAt: now,
            database: database
        )
        return session
    }

    package func requireExactResume(
        execution: EngineExecutionRecord,
        sessionId: String,
        externalSessionId: String,
        descriptor: ExecutionEngineDescriptor,
        database: Database,
        now: Date
    ) throws -> EngineSessionRecord {
        try Self.validateBindableExecution(execution)
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        try CanonicalContractCodingV1.validateFinite(now)
        guard descriptor.adapterId == execution.adapterId,
              descriptor.adapterVersion == execution.adapterVersion,
              descriptor.sessionResume == .supported,
              let profile = try RuntimeProfileRecord.fetchOne(
                  database,
                  key: execution.profileId
              ),
              profile.kind == descriptor.profileKind,
              let session = try EngineSessionRecord.fetchOne(
                  database,
                  key: sessionId
              ),
              session.externalSessionId == externalSessionId
        else {
            throw EngineSessionScopeMismatchError()
        }

        let request = try Self.validatedRequest(
            for: execution
        )
        let workspaceHash = request.workspace.hash
        try Self.validateExecutionScope(
            execution,
            request: request
        )
        try Self.requireExactSession(
            session,
            execution: execution,
            workspaceHash: workspaceHash,
            externalSessionId: externalSessionId
        )
        if let resolvedReference = request.sessionRef {
            guard resolvedReference.sessionId == session.id,
                  resolvedReference.externalSessionId == externalSessionId
            else {
                throw EngineSessionScopeMismatchError()
            }
        }

        if let boundSessionId = execution.sessionId {
            guard boundSessionId == session.id,
                  execution.dispatchState == .sessionBound
            else {
                throw EngineSessionScopeMismatchError()
            }
            return session
        }
        guard let resolvedReference = request.sessionRef,
              resolvedReference.sessionId == session.id,
              resolvedReference.externalSessionId == externalSessionId,
              execution.dispatchState == .started
        else {
            throw EngineSessionScopeMismatchError()
        }

        try Self.bind(
            execution: execution,
            sessionId: session.id,
            updatedAt: now,
            database: database
        )
        return session
    }

    package func closeOrInvalidate(
        sessionId: String,
        expectedVersion: Int,
        disposition: EngineSessionDispositionV1,
        database: Database,
        now: Date
    ) throws -> EngineSessionRecord {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try CanonicalContractCodingV1.validatePositive(expectedVersion)
        try CanonicalContractCodingV1.validateFinite(now)
        let nextVersion = try CanonicalContractCodingV1.checkedIncrement(
            expectedVersion
        )
        let targetState: EngineSessionStateV1 = switch disposition {
        case .closed:
            .closed
        case .invalid:
            .invalid
        }
        guard let current = try EngineSessionRecord.fetchOne(
            database,
            key: sessionId
        ) else {
            throw EngineSessionScopeMismatchError()
        }
        if current.state == targetState,
           current.version == nextVersion,
           current.redactedAt == nil
        {
            return current
        }
        guard current.state == .active,
              current.version == expectedVersion,
              current.redactedAt == nil
        else {
            throw EngineSessionScopeMismatchError()
        }
        try database.execute(
            sql: """
                UPDATE engine_session
                SET state=?,updatedAt=?,version=?
                WHERE id=? AND state='active' AND version=?
                  AND redactedAt IS NULL
                """,
            arguments: [
                targetState.rawValue,
                now,
                nextVersion,
                sessionId,
                expectedVersion,
            ]
        )
        guard database.changesCount == 1,
              let updated = try EngineSessionRecord.fetchOne(
                  database,
                  key: sessionId
              ),
              updated.state == targetState,
              updated.version == nextVersion,
              updated.redactedAt == nil
        else {
            throw EngineSessionScopeMismatchError()
        }
        return updated
    }

    private static func validateBindableExecution(
        _ execution: EngineExecutionRecord
    ) throws {
        guard execution.state == .running,
              execution.redactedAt == nil,
              execution.terminalReceiptIdempotencyKey == nil,
              execution.terminalReceiptHash == nil,
              execution.finishedAt == nil,
              execution.dispatchState == .started
                || execution.dispatchState == .sessionBound
        else {
            throw EngineSessionScopeMismatchError()
        }
    }

    private static func validatedRequest(
        for execution: EngineExecutionRecord
    ) throws -> EngineExecutionRequest {
        do {
            let bytes = Data(execution.requestJson.utf8)
            let request = try CanonicalContractCodingV1.decode(
                EngineExecutionRequest.self,
                from: bytes
            )
            try request.validateCanonicalIdentity()
            guard request.requestJson == execution.requestJson,
                  request.requestHash == execution.requestHash,
                  CanonicalJSONV1.sha256Hex(bytes) == execution.requestHash,
                  request.executionId == execution.id,
                  request.idempotencyKey == execution.idempotencyKey,
                  request.campId == execution.campId,
                  request.campLifecycleVersion
                    == execution.campLifecycleVersion,
                  request.runId == execution.runId,
                  request.cardId == execution.cardId,
                  request.adapterId == execution.adapterId,
                  request.adapterVersion == execution.adapterVersion,
                  request.profileId == execution.profileId,
                  request.engineKind == execution.engineKind,
                  request.model == execution.model,
                  request.replayClass == execution.replayClass,
                  request.contextJson == execution.contextJson,
                  request.contextHash == execution.contextHash,
                  request.sessionScopeJson == execution.sessionScopeJson,
                  request.sessionScopeHash == execution.sessionScopeHash
            else {
                throw EngineSessionScopeMismatchError()
            }
            return request
        } catch is EngineSessionScopeMismatchError {
            throw EngineSessionScopeMismatchError()
        } catch {
            throw EngineSessionScopeMismatchError()
        }
    }

    private static func validateExecutionScope(
        _ execution: EngineExecutionRecord,
        request: EngineExecutionRequest
    ) throws {
        do {
            let bytes = Data(execution.sessionScopeJson.utf8)
            let scope = try CanonicalContractCodingV1.decode(
                EngineSessionScopeV1.self,
                from: bytes
            )
            guard CanonicalJSONV1.sha256Hex(bytes)
                    == execution.sessionScopeHash,
                  scope.campId == execution.campId,
                  scope.profileId == execution.profileId,
                  scope.adapterId == execution.adapterId,
                  scope.adapterVersion == execution.adapterVersion,
                  scope.engineKind == execution.engineKind,
                  scope.model == execution.model,
                  scope.workspaceHash == request.workspace.hash,
                  scope.contractId == request.contract.id,
                  scope.contractVersion == request.contract.version,
                  scope.contractHash == request.contract.hash,
                  scope.campId == request.campId,
                  scope.profileId == request.profileId,
                  scope.adapterId == request.adapterId,
                  scope.adapterVersion == request.adapterVersion,
                  scope.engineKind == request.engineKind,
                  scope.model == request.model,
                  request.sessionScopeJson == execution.sessionScopeJson,
                  request.sessionScopeHash == execution.sessionScopeHash
            else {
                throw EngineSessionScopeMismatchError()
            }
        } catch is EngineSessionScopeMismatchError {
            throw EngineSessionScopeMismatchError()
        } catch {
            throw EngineSessionScopeMismatchError()
        }
    }

    private static func requireExactSession(
        _ session: EngineSessionRecord,
        execution: EngineExecutionRecord,
        workspaceHash: String,
        externalSessionId: String
    ) throws {
        guard session.state == .active,
              session.redactedAt == nil,
              session.externalSessionId == externalSessionId,
              session.campId == execution.campId,
              session.profileId == execution.profileId,
              session.adapterId == execution.adapterId,
              session.adapterVersion == execution.adapterVersion,
              session.workspaceHash == workspaceHash,
              session.sessionScopeJson == execution.sessionScopeJson,
              session.sessionScopeHash == execution.sessionScopeHash
        else {
            throw EngineSessionScopeMismatchError()
        }
    }

    private static func bind(
        execution: EngineExecutionRecord,
        sessionId: String,
        updatedAt: Date,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE engine_execution
                SET sessionId=?, dispatchState='sessionBound',
                    updatedAt=?, version=version+1
                WHERE id=? AND version=? AND state='running'
                  AND dispatchState='started' AND sessionId IS NULL
                  AND redactedAt IS NULL
                """,
            arguments: [
                sessionId,
                updatedAt,
                execution.id,
                execution.version,
            ]
        )
        guard database.changesCount == 1 else {
            throw EngineSessionScopeMismatchError()
        }
    }
}
