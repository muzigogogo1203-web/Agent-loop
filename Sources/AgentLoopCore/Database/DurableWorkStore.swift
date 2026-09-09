import Foundation
import GRDB
import os

package struct LegacyPlanningHasCardsError:
    Error, Sendable, Equatable
{
    package let code = "legacy_planning_has_cards"

    package init() {}
}

public struct DurableWorkStore: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func enqueue(
        campId: String,
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String,
        inputJson: String,
        claimedInputHash: String,
        idempotencyKey: String,
        maxAttempts: Int,
        traceId: String,
        now: Date
    ) throws -> DurableWorkEnqueueResult {
        try Self.requireGenericKind(kind)
        try Self.validateNow(now)
        let inputHash = try Self.validateCanonicalInput(
            inputJson,
            claimedInputHash: claimedInputHash
        )
        return try database.pool.write { db in
            try Self.enqueue(
                campId: campId,
                kind: kind,
                aggregateType: aggregateType,
                aggregateId: aggregateId,
                inputJson: inputJson,
                claimedInputHash: inputHash,
                idempotencyKey: idempotencyKey,
                maxAttempts: maxAttempts,
                traceId: traceId,
                now: now,
                in: db
            )
        }
    }

    static func enqueue(
        campId: String,
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String,
        inputJson: String,
        claimedInputHash: String,
        idempotencyKey: String,
        maxAttempts: Int,
        traceId: String,
        now: Date,
        in db: Database
    ) throws -> DurableWorkEnqueueResult {
        try requireGenericKind(kind)
        try validateNow(now)
        let inputHash = try validateCanonicalInput(
            inputJson,
            claimedInputHash: claimedInputHash
        )
        guard let camp = try CampRecord.fetchOne(db, key: campId) else {
            throw RecordNotFoundError(table: "camp", id: campId)
        }
        guard !camp.archived else {
            throw CampArchivedError(campId: campId)
        }
        guard let lifecycle = try Row.fetchOne(
            db,
            sql: "SELECT state,version FROM camp_lifecycle WHERE campId=?",
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let lifecycleVersion: Int = lifecycle["version"]
        guard let lifecycleState = CampLifecycleStateV1(
            rawValue: lifecycle["state"] as String
        ), lifecycleState == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: lifecycle["state"] as String
                ) ?? .deletedTombstone
            )
        }

        if let existing = try DurableWorkRecord
            .filter(
                Column("kind") == kind.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(db)
        {
            let storedLifecycleVersion = try Int.fetchOne(
                db,
                sql: "SELECT campLifecycleVersion FROM durable_work WHERE id=?",
                arguments: [existing.id]
            )
            guard existing.campId == campId,
                  existing.aggregateType == aggregateType,
                  existing.aggregateId == aggregateId,
                  existing.inputJson == inputJson,
                  existing.inputHash == inputHash,
                  existing.maxAttempts == maxAttempts,
                  storedLifecycleVersion == lifecycleVersion
            else {
                throw DurableWorkReplayConflictError()
            }
            return DurableWorkEnqueueResult(
                work: existing,
                disposition: .replayed
            )
        }

        let work = DurableWorkRecord(
            id: UUID().uuidString,
            campId: campId,
            kind: kind,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            idempotencyKey: idempotencyKey,
            state: .queued,
            attempt: 0,
            maxAttempts: maxAttempts,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: inputJson,
            inputHash: inputHash,
            outputJson: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: nil
        )
        try db.execute(
            sql: """
                INSERT INTO durable_work(
                  id,campId,campLifecycleVersion,kind,aggregateType,aggregateId,
                  idempotencyKey,state,attempt,maxAttempts,notBefore,leaseOwner,
                  leaseExpiresAt,inputJson,inputHash,outputJson,errorCode,
                  errorMessage,traceId,version,createdAt,updatedAt,finishedAt
                ) VALUES (?,?,?,?,?,?,?,'queued',0,?,NULL,NULL,NULL,?,?,NULL,NULL,
                          NULL,?,1,?,?,NULL)
                """,
            arguments: [
                work.id, work.campId, lifecycleVersion, work.kind.rawValue,
                work.aggregateType, work.aggregateId, work.idempotencyKey,
                work.maxAttempts, work.inputJson, work.inputHash, work.traceId,
                work.createdAt, work.updatedAt,
            ]
        )
        return DurableWorkEnqueueResult(
            work: work,
            disposition: .inserted
        )
    }

    /// DurableWorkRecord predates the P1-E lifecycle fence column. All runtime
    /// insert owners use this carrier so the persisted row binds the current
    /// active Camp lifecycle version instead of relying on a missing/default
    /// model field.
    package static func insertCurrentSchemaRecord(
        _ work: DurableWorkRecord,
        in database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [work.campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let lifecycleVersion: Int = row["version"]
        guard let lifecycleState = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), lifecycleState == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["state"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        try database.execute(
            sql: """
                INSERT INTO durable_work(
                  id,campId,campLifecycleVersion,kind,aggregateType,aggregateId,
                  idempotencyKey,state,attempt,maxAttempts,notBefore,leaseOwner,
                  leaseExpiresAt,inputJson,inputHash,outputJson,errorCode,
                  errorMessage,traceId,version,createdAt,updatedAt,finishedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                work.id, work.campId, lifecycleVersion, work.kind.rawValue,
                work.aggregateType, work.aggregateId, work.idempotencyKey,
                work.state.rawValue, work.attempt, work.maxAttempts,
                work.notBefore, work.leaseOwner, work.leaseExpiresAt,
                work.inputJson, work.inputHash, work.outputJson,
                work.errorCode, work.errorMessage, work.traceId, work.version,
                work.createdAt, work.updatedAt, work.finishedAt,
            ]
        )
    }

    public func claimNext(
        kinds: [DurableWorkKind],
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim? {
        _ = try Self.validateLease(
            now: now,
            duration: leaseDuration
        )
        let kinds = try Self.validatedKinds(kinds)
        guard !kinds.isEmpty else { return nil }
        return try database.pool.write { db in
            try Self.claimNext(
                kinds: kinds,
                workerId: workerId,
                now: now,
                leaseDuration: leaseDuration,
                in: db
            )
        }
    }

    /// Claims one exact generic work item. Interactive Camp flows use this
    /// instead of a kind-wide claim so a newly opened stream can never execute
    /// another request's queued work.
    package func claim(
        workId: String,
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim {
        _ = try Self.validateLease(now: now, duration: leaseDuration)
        try CanonicalContractCodingV1.validateNonempty(workId)
        try CanonicalContractCodingV1.validateNonempty(workerId)
        return try database.pool.write { database in
            try Self.claim(
                workId: workId,
                workerId: workerId,
                now: now,
                leaseDuration: leaseDuration,
                in: database
            )
        }
    }

    package static func claim(
        workId: String,
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval,
        in database: Database
    ) throws -> DurableWorkClaim {
        let expiration = try validateLease(
            now: now,
            duration: leaseDuration
        )
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT work.*,lifecycle.state AS lifecycleState,
                       lifecycle.version AS currentLifecycleVersion,
                       camp.archived AS campArchived
                FROM durable_work AS work
                JOIN camp ON camp.id=work.campId
                JOIN camp_lifecycle AS lifecycle
                  ON lifecycle.campId=work.campId
                WHERE work.id=?
                """,
            arguments: [workId]
        ), let work = try DurableWorkRecord.fetchOne(
            database,
            key: workId
        ) else {
            throw DurableWorkNotFoundError(workId: workId)
        }
        try requireGenericMutationCapability(work)
        let expectedLifecycleVersion: Int = row["campLifecycleVersion"]
        let currentLifecycleVersion: Int = row["currentLifecycleVersion"]
        guard expectedLifecycleVersion == currentLifecycleVersion else {
            throw CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(
                    expected: expectedLifecycleVersion,
                    actual: currentLifecycleVersion
                )
        }
        guard let lifecycleState = CampLifecycleStateV1(
            rawValue: row["lifecycleState"] as String
        ), lifecycleState == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["lifecycleState"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["campArchived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        guard work.state == .queued
                || (work.state == .retryScheduled
                    && work.notBefore.map { $0 <= now } == true)
        else {
            throw InvalidDurableWorkStateError()
        }

        let attempt = try checkedIncrement(work.attempt)
        let version = try checkedIncrement(work.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET state='running',attempt=?,notBefore=NULL,leaseOwner=?,
                    leaseExpiresAt=?,outputJson=NULL,errorCode=NULL,
                    errorMessage=NULL,version=?,updatedAt=?,finishedAt=NULL
                WHERE id=? AND version=? AND (
                  state='queued'
                  OR (state='retryScheduled' AND notBefore<=?)
                )
                """,
            arguments: [
                attempt, workerId, expiration, version, now, work.id,
                work.version, now,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try DurableWorkAttemptRecord(
            workId: work.id,
            attempt: attempt,
            id: UUID().uuidString,
            workerId: workerId,
            startedAt: now,
            endedAt: nil,
            outcome: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: work.traceId,
            terminalWorkVersion: nil
        ).insert(database)
        guard let persisted = try DurableWorkRecord.fetchOne(
            database,
            key: work.id
        ), persisted.state == .running,
           persisted.attempt == attempt,
           persisted.version == version,
           persisted.leaseOwner == workerId,
           let persistedExpiration = persisted.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let claim = DurableWorkClaim(
            workId: work.id,
            attempt: attempt,
            workerId: workerId,
            version: version,
            leaseExpiresAt: persistedExpiration
        )
        try insertEvent(
            database,
            workId: claim.workId,
            attempt: claim.attempt,
            sequence: 0,
            kind: .claimed,
            workerId: claim.workerId,
            workVersion: claim.version,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return claim
    }

    static func claimNext(
        kinds: [DurableWorkKind],
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval,
        in db: Database
    ) throws -> DurableWorkClaim? {
        let expiration = try validateLease(
            now: now,
            duration: leaseDuration
        )
        let kinds = try validatedKinds(kinds)
        guard !kinds.isEmpty else { return nil }

        let placeholders = Array(repeating: "?", count: kinds.count)
            .joined(separator: ",")
        var arguments = StatementArguments(kinds.map(\.rawValue))
        arguments += StatementArguments([now])
        guard let work = try DurableWorkRecord.fetchOne(
            db,
            sql: """
                SELECT durable_work.*
                FROM durable_work
                JOIN camp ON camp.id = durable_work.campId
                WHERE durable_work.kind IN (\(placeholders))
                  AND camp.archived = 0
                  AND (
                    durable_work.state = 'queued'
                    OR (
                      durable_work.state = 'retryScheduled'
                      AND durable_work.notBefore <= ?
                    )
                  )
                ORDER BY durable_work.createdAt, durable_work.rowid
                LIMIT 1
                """,
            arguments: arguments
        ) else {
            return nil
        }

        let attempt = try checkedIncrement(work.attempt)
        let version = try checkedIncrement(work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'running',
                    attempt = ?,
                    notBefore = NULL,
                    leaseOwner = ?,
                    leaseExpiresAt = ?,
                    outputJson = NULL,
                    errorCode = NULL,
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = NULL
                WHERE id = ?
                  AND version = ?
                  AND (
                    state = 'queued'
                    OR (state = 'retryScheduled' AND notBefore <= ?)
                  )
                """,
            arguments: [
                attempt, workerId, expiration, version, now, work.id,
                work.version, now,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }

        try DurableWorkAttemptRecord(
            workId: work.id,
            attempt: attempt,
            id: UUID().uuidString,
            workerId: workerId,
            startedAt: now,
            endedAt: nil,
            outcome: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: work.traceId,
            terminalWorkVersion: nil
        ).insert(db)
        guard let persistedWork = try DurableWorkRecord.fetchOne(
            db,
            key: work.id
        ), persistedWork.state == .running,
           persistedWork.attempt == attempt,
           persistedWork.version == version,
           persistedWork.leaseOwner == workerId,
           let persistedLeaseExpiresAt = persistedWork.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let persistedClaim = DurableWorkClaim(
            workId: work.id,
            attempt: attempt,
            workerId: workerId,
            version: version,
            leaseExpiresAt: persistedLeaseExpiresAt
        )
        try insertEvent(
            db,
            workId: persistedClaim.workId,
            attempt: persistedClaim.attempt,
            sequence: 0,
            kind: .claimed,
            workerId: persistedClaim.workerId,
            workVersion: persistedClaim.version,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return persistedClaim
    }

    public func renewLease(
        claim: DurableWorkClaim,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim {
        _ = try Self.validateLease(now: now, duration: leaseDuration)
        return try database.pool.write { db in
            try Self.renewLease(
                claim: claim,
                now: now,
                leaseDuration: leaseDuration,
                in: db
            )
        }
    }

    static func renewLease(
        claim: DurableWorkClaim,
        now: Date,
        leaseDuration: TimeInterval,
        in db: Database
    ) throws -> DurableWorkClaim {
        let expiration = try validateLease(
            now: now,
            duration: leaseDuration
        )
        let work = try requireWork(db, id: claim.workId)
        try requireGenericMutationCapability(work)
        let version = try checkedIncrement(claim.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET leaseExpiresAt = ?, version = ?, updatedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                expiration, version, now, claim.workId, claim.attempt,
                claim.version, claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        guard let persistedWork = try DurableWorkRecord.fetchOne(
            db,
            key: claim.workId
        ), persistedWork.state == .running,
           persistedWork.attempt == claim.attempt,
           persistedWork.version == version,
           persistedWork.leaseOwner == claim.workerId,
           let persistedLeaseExpiresAt = persistedWork.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let persistedClaim = DurableWorkClaim(
            workId: claim.workId,
            attempt: claim.attempt,
            workerId: claim.workerId,
            version: version,
            leaseExpiresAt: persistedLeaseExpiresAt
        )
        try insertEvent(
            db,
            workId: persistedClaim.workId,
            attempt: persistedClaim.attempt,
            sequence: try nextSequence(
                db,
                workId: persistedClaim.workId,
                attempt: persistedClaim.attempt
            ),
            kind: .leaseRenewed,
            workerId: persistedClaim.workerId,
            workVersion: persistedClaim.version,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return persistedClaim
    }

    public func complete(
        claim: DurableWorkClaim,
        outputJson: String?,
        now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkRecord {
        try Self.validateNow(now)
        try Self.validateOutput(outputJson)
        return try database.pool.write { db in
            try Self.complete(
                claim: claim,
                outputJson: outputJson,
                now: now,
                businessMutation: businessMutation,
                in: db
            )
        }
    }

    static func complete(
        claim: DurableWorkClaim,
        outputJson: String?,
        now: Date,
        businessMutation: DurableWorkBusinessMutation,
        in db: Database
    ) throws -> DurableWorkRecord {
        try validateNow(now)
        try validateOutput(outputJson)
        let work = try requireWork(db, id: claim.workId)
        try requireGenericMutationCapability(work)
        let version = try checkedIncrement(claim.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'succeeded',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = ?,
                    errorCode = NULL,
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                outputJson, version, now, now, claim.workId, claim.attempt,
                claim.version, claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            db,
            claim: claim,
            outcome: .succeeded,
            errorCode: nil,
            errorMessage: nil,
            terminalVersion: version,
            now: now
        )
        try insertEvent(
            db,
            workId: claim.workId,
            attempt: claim.attempt,
            sequence: try nextSequence(
                db,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .succeeded,
            workerId: claim.workerId,
            workVersion: version,
            resultingState: .succeeded,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        let resultingWork = try requireWork(db, id: claim.workId)
        try businessMutation(db, resultingWork)
        return resultingWork
    }

    public func retryOrFail(
        claim: DurableWorkClaim,
        failure: DurableWorkFailure,
        now: Date,
        terminalBusinessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkFailureResolution {
        try Self.validateNow(now)
        return try database.pool.write { db in
            try Self.retryOrFail(
                claim: claim,
                failure: failure,
                now: now,
                terminalBusinessMutation: terminalBusinessMutation,
                in: db
            )
        }
    }

    static func retryOrFail(
        claim: DurableWorkClaim,
        failure: DurableWorkFailure,
        now: Date,
        terminalBusinessMutation: DurableWorkBusinessMutation,
        in db: Database
    ) throws -> DurableWorkFailureResolution {
        try validateNow(now)
        let work = try requireWork(db, id: claim.workId)
        try requireGenericMutationCapability(work)
        guard claim.attempt >= 1 else {
            throw InvalidDurableWorkStateError()
        }

        let shouldRetry =
            failure.disposition == .transient
            && claim.attempt < 4
            && claim.attempt < work.maxAttempts
        let resultingState: DurableWorkState
        let notBefore: Date?
        if shouldRetry {
            let delays: [TimeInterval] = [5, 30, 120]
            let delayIndex = claim.attempt - 1
            guard delays.indices.contains(delayIndex) else {
                throw InvalidDurableWorkStateError()
            }
            let candidate = now.addingTimeInterval(delays[delayIndex])
            guard candidate.timeIntervalSinceReferenceDate.isFinite,
                  candidate > now
            else {
                throw BackoffOverflowError()
            }
            resultingState = .retryScheduled
            notBefore = candidate
        } else {
            resultingState = .failed
            notBefore = nil
        }

        let version = try checkedIncrement(claim.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = ?,
                    notBefore = ?,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = ?,
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                resultingState.rawValue, notBefore, failure.code,
                failure.message, version, now,
                resultingState == .failed ? now : nil,
                claim.workId, claim.attempt, claim.version, claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            db,
            claim: claim,
            outcome: .failed,
            errorCode: failure.code,
            errorMessage: failure.message,
            terminalVersion: version,
            now: now
        )
        try insertEvent(
            db,
            workId: claim.workId,
            attempt: claim.attempt,
            sequence: try nextSequence(
                db,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .failed,
            workerId: claim.workerId,
            workVersion: version,
            resultingState: resultingState,
            errorCode: failure.code,
            errorMessage: failure.message,
            now: now
        )
        let resultingWork = try requireWork(db, id: claim.workId)
        if resultingState == .failed {
            try terminalBusinessMutation(db, resultingWork)
            return .failed(work: resultingWork)
        }
        guard let notBefore else {
            throw InvalidDurableWorkStateError()
        }
        return .retryScheduled(
            work: resultingWork,
            notBefore: notBefore
        )
    }

    public func cancel(
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkCancelResult {
        try Self.validateNow(now)
        try Self.validateCancellationReason(reason)
        return try database.pool.write { db in
            try Self.cancel(
                workId: workId,
                expectedVersion: expectedVersion,
                reason: reason,
                now: now,
                businessMutation: businessMutation,
                in: db
            )
        }
    }

    static func cancel(
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date,
        businessMutation: DurableWorkBusinessMutation,
        in db: Database
    ) throws -> DurableWorkCancelResult {
        try validateNow(now)
        try validateCancellationReason(reason)
        let work = try requireWork(db, id: workId)
        try requireGenericMutationCapability(work)
        if work.state == .canceled,
           work.errorCode == "work_canceled",
           work.errorMessage == reason
        {
            return .alreadyCanceled(work: work)
        }
        guard [.queued, .running, .retryScheduled].contains(work.state) else {
            throw InvalidDurableWorkStateError()
        }
        guard work.version == expectedVersion else {
            throw StaleDurableWorkClaimError()
        }
        let version = try checkedIncrement(work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'canceled',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = 'work_canceled',
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND version = ?
                  AND state IN ('queued','running','retryScheduled')
                """,
            arguments: [
                reason, version, now, now, work.id, expectedVersion,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }

        if work.state == .running {
            guard let workerId = work.leaseOwner else {
                throw InvalidDurableWorkStateError()
            }
            let claim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: work.leaseExpiresAt ?? now
            )
            try closeAttempt(
                db,
                claim: claim,
                outcome: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                terminalVersion: version,
                now: now
            )
            try insertEvent(
                db,
                workId: work.id,
                attempt: work.attempt,
                sequence: try nextSequence(
                    db,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .canceled,
                workerId: workerId,
                workVersion: version,
                resultingState: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                now: now
            )
        }
        let resultingWork = try requireWork(db, id: work.id)
        try businessMutation(db, resultingWork)
        return .canceled(work: resultingWork)
    }

    public func cancelActive(
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String,
        reason: String,
        now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkCancelActiveResult {
        try Self.requireGenericKind(kind)
        try Self.validateNow(now)
        try Self.validateCancellationReason(reason)
        return try database.pool.write { db in
            try Self.cancelActive(
                kind: kind,
                aggregateType: aggregateType,
                aggregateId: aggregateId,
                reason: reason,
                now: now,
                businessMutation: businessMutation,
                in: db
            )
        }
    }

    static func cancelActive(
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String,
        reason: String,
        now: Date,
        businessMutation: DurableWorkBusinessMutation,
        in db: Database
    ) throws -> DurableWorkCancelActiveResult {
        try requireGenericKind(kind)
        try validateNow(now)
        try validateCancellationReason(reason)
        guard let work = try DurableWorkRecord
            .filter(
                Column("kind") == kind.rawValue
                    && Column("aggregateType") == aggregateType
                    && Column("aggregateId") == aggregateId
                    && ["queued", "running", "retryScheduled"].contains(
                        Column("state")
                    )
            )
            .fetchOne(db)
        else {
            return .noActiveWork
        }
        let result = try cancel(
            workId: work.id,
            expectedVersion: work.version,
            reason: reason,
            now: now,
            businessMutation: businessMutation,
            in: db
        )
        switch result {
        case let .canceled(work):
            return .canceled(work: work)
        case .alreadyCanceled:
            throw InvalidDurableWorkStateError()
        }
    }

    public func adoptInterrupted(
        kinds: [DurableWorkKind],
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        try Self.validateNow(now)
        let kinds = try Self.validatedKinds(kinds)
        guard !kinds.isEmpty else { return [] }
        return try database.pool.write { db in
            try Self.adoptInterrupted(
                kinds: kinds,
                currentWorkerId: currentWorkerId,
                now: now,
                in: db
            )
        }
    }

    static func adoptInterrupted(
        kinds: [DurableWorkKind],
        currentWorkerId: String,
        now: Date,
        in db: Database
    ) throws -> [DurableWorkRecord] {
        try validateNow(now)
        let kinds = try validatedKinds(kinds)
        guard !kinds.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: kinds.count)
            .joined(separator: ",")
        var arguments = StatementArguments(kinds.map(\.rawValue))
        arguments += StatementArguments([currentWorkerId])
        let running = try DurableWorkRecord.fetchAll(
            db,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind IN (\(placeholders))
                  AND state = 'running'
                  AND leaseOwner <> ?
                ORDER BY createdAt, rowid
                """,
            arguments: arguments
        )
        var adopted: [DurableWorkRecord] = []
        adopted.reserveCapacity(running.count)
        for work in running {
            guard let workerId = work.leaseOwner else {
                throw InvalidDurableWorkStateError()
            }
            let version = try checkedIncrement(work.version)
            try db.execute(
                sql: """
                    UPDATE durable_work
                    SET state = 'queued',
                        notBefore = NULL,
                        leaseOwner = NULL,
                        leaseExpiresAt = NULL,
                        outputJson = NULL,
                        errorCode = 'worker_interrupted',
                        errorMessage = NULL,
                        version = ?,
                        updatedAt = ?,
                        finishedAt = NULL
                    WHERE id = ? AND state = 'running' AND version = ?
                    """,
                arguments: [version, now, work.id, work.version]
            )
            guard db.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            let claim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: work.leaseExpiresAt ?? now
            )
            try closeAttempt(
                db,
                claim: claim,
                outcome: .interrupted,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                terminalVersion: version,
                now: now
            )
            try insertEvent(
                db,
                workId: work.id,
                attempt: work.attempt,
                sequence: try nextSequence(
                    db,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .interrupted,
                workerId: workerId,
                workVersion: version,
                resultingState: .queued,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                now: now
            )
            adopted.append(try requireWork(db, id: work.id))
        }
        return adopted
    }

    public func activeWork(
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String
    ) throws -> DurableWorkRecord? {
        try database.pool.read { db in
            try DurableWorkRecord
                .filter(
                    Column("kind") == kind.rawValue
                        && Column("aggregateType") == aggregateType
                        && Column("aggregateId") == aggregateId
                        && ["queued", "running", "retryScheduled"].contains(
                            Column("state")
                        )
                )
                .fetchOne(db)
        }
    }

    public func latestWork(
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String
    ) throws -> DurableWorkRecord? {
        try database.pool.read { db in
            try DurableWorkRecord
                .filter(
                    Column("kind") == kind.rawValue
                        && Column("aggregateType") == aggregateType
                        && Column("aggregateId") == aggregateId
                )
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchOne(db)
        }
    }

    public func work(id: String) throws -> DurableWorkRecord? {
        try database.pool.read { db in
            try DurableWorkRecord.fetchOne(db, key: id)
        }
    }

    public func nextClaimableDate(
        kinds: [DurableWorkKind],
        now: Date
    ) throws -> Date? {
        try Self.validateNow(now)
        let kinds = try Self.validatedKinds(kinds)
        guard !kinds.isEmpty else { return nil }
        return try database.pool.read { db in
            try Self.nextClaimableDate(kinds: kinds, now: now, in: db)
        }
    }

    private static func nextClaimableDate(
        kinds: [DurableWorkKind],
        now: Date,
        in db: Database
    ) throws -> Date? {
        try validateNow(now)
        let kinds = try validatedKinds(kinds)
        guard !kinds.isEmpty else { return nil }
        let placeholders = Array(repeating: "?", count: kinds.count)
            .joined(separator: ",")
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT durable_work.state, durable_work.notBefore
                FROM durable_work
                JOIN camp ON camp.id = durable_work.campId
                WHERE durable_work.kind IN (\(placeholders))
                  AND camp.archived = 0
                  AND durable_work.state IN ('queued','retryScheduled')
                """,
            arguments: StatementArguments(kinds.map(\.rawValue))
        )
        var earliest: Date?
        for row in rows {
            let state: String = row["state"]
            if state == DurableWorkState.queued.rawValue {
                return now
            }
            guard let notBefore: Date = row["notBefore"] else {
                throw InvalidDurableWorkStateError()
            }
            if notBefore <= now {
                return now
            }
            if earliest == nil || notBefore < earliest! {
                earliest = notBefore
            }
        }
        return earliest
    }

    private static func requireWork(
        _ db: Database,
        id: String
    ) throws -> DurableWorkRecord {
        guard let work = try DurableWorkRecord.fetchOne(db, key: id) else {
            throw DurableWorkNotFoundError(workId: id)
        }
        return work
    }

    private static func requireGenericMutationCapability(
        _ work: DurableWorkRecord
    ) throws {
        switch work.kind {
        case .planning:
            throw PlanningRequiresDurablePlanningCapabilityError()
        case .rumination:
            throw RuminationRequiresDurableRuminationCapabilityError()
        case .campDeletion:
            throw CampDeletionRequiresRetirementCapabilityError()
        default:
            return
        }
    }

    private static func requireGenericKind(
        _ kind: DurableWorkKind
    ) throws {
        switch kind {
        case .planning:
            throw PlanningRequiresDurablePlanningCapabilityError()
        case .rumination:
            throw RuminationRequiresDurableRuminationCapabilityError()
        case .campDeletion:
            throw CampDeletionRequiresRetirementCapabilityError()
        default:
            return
        }
    }

    private static func validatedKinds(
        _ kinds: [DurableWorkKind]
    ) throws -> [DurableWorkKind] {
        for kind in kinds {
            try requireGenericKind(kind)
        }

        var seen = Set<DurableWorkKind>()
        var unique: [DurableWorkKind] = []
        for kind in kinds {
            if seen.insert(kind).inserted {
                unique.append(kind)
            }
        }
        return unique
    }

    private static func validateNow(_ now: Date) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteNow
        }
    }

    private static func validateLease(
        now: Date,
        duration: TimeInterval
    ) throws -> Date {
        try validateNow(now)
        guard duration.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseDuration
        }
        guard duration > 0 else {
            throw InvalidDurableWorkTimeError.nonPositiveLeaseDuration
        }
        let expiration = now.addingTimeInterval(duration)
        guard expiration.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
        }
        guard expiration > now else {
            throw InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
        }
        return expiration
    }

    private static func validateCanonicalInput(
        _ inputJson: String,
        claimedInputHash: String
    ) throws -> String {
        let raw = Data(inputJson.utf8)
        do {
            let canonical = try CanonicalJSONV1.canonicalizeWithRootKind(
                rawUTF8: raw
            )
            guard canonical.rootKind == .object,
                  canonical.data == raw
            else {
                throw DurableWorkInvalidCanonicalJSONError()
            }
        } catch is DurableWorkInvalidCanonicalJSONError {
            throw DurableWorkInvalidCanonicalJSONError()
        } catch {
            throw DurableWorkInvalidCanonicalJSONError()
        }
        let recomputed = CanonicalJSONV1.sha256Hex(raw)
        guard DurableWorkFailure.isValidErrorCodeHash(claimedInputHash),
              claimedInputHash == recomputed
        else {
            throw DurableWorkInputHashMismatchError()
        }
        return recomputed
    }

    private static func validateOutput(_ outputJson: String?) throws {
        guard let outputJson else { return }
        let raw = Data(outputJson.utf8)
        let canonical: (data: Data, rootKind: CanonicalJSONRootKind)
        do {
            canonical = try CanonicalJSONV1.canonicalizeWithRootKind(
                rawUTF8: raw
            )
        } catch {
            throw InvalidDurableWorkOutputJSONError.invalidJSON
        }
        guard canonical.rootKind == .object else {
            throw InvalidDurableWorkOutputJSONError.rootMustBeObject
        }
        guard canonical.data == raw else {
            throw InvalidDurableWorkOutputJSONError.notCanonical
        }
    }

    private static func validateCancellationReason(
        _ reason: String
    ) throws {
        guard !reason.isEmpty else {
            throw InvalidDurableWorkCancellationReasonError.empty
        }
        guard reason.unicodeScalars.count <= 1_000 else {
            throw InvalidDurableWorkCancellationReasonError.tooLong
        }
        guard !DurableWorkFailure.containsControlScalar(reason) else {
            throw InvalidDurableWorkCancellationReasonError
                .containsControlScalar
        }
    }

    private static func checkedIncrement(_ value: Int) throws -> Int {
        let (incremented, overflow) = value.addingReportingOverflow(1)
        guard !overflow else {
            throw InvalidDurableWorkStateError()
        }
        return incremented
    }

    private static func nextSequence(
        _ db: Database,
        workId: String,
        attempt: Int
    ) throws -> Int {
        guard let maximum = try Int.fetchOne(
            db,
            sql: """
                SELECT MAX(sequence)
                FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [workId, attempt]
        ) else {
            throw InvalidDurableWorkStateError()
        }
        return try checkedIncrement(maximum)
    }

    private static func closeAttempt(
        _ db: Database,
        claim: DurableWorkClaim,
        outcome: DurableWorkAttemptOutcome,
        errorCode: String?,
        errorMessage: String?,
        terminalVersion: Int,
        now: Date
    ) throws {
        try db.execute(
            sql: """
                UPDATE durable_work_attempt
                SET endedAt = ?,
                    outcome = ?,
                    errorCode = ?,
                    errorMessage = ?,
                    terminalWorkVersion = ?
                WHERE workId = ?
                  AND attempt = ?
                  AND workerId = ?
                  AND endedAt IS NULL
                """,
            arguments: [
                now, outcome.rawValue, errorCode, errorMessage,
                terminalVersion, claim.workId, claim.attempt,
                claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw AttemptAlreadyClosedError()
        }
    }

    private static func insertEvent(
        _ db: Database,
        workId: String,
        attempt: Int,
        sequence: Int,
        kind: DurableWorkAttemptEventKind,
        workerId: String,
        workVersion: Int,
        resultingState: DurableWorkState,
        errorCode: String?,
        errorMessage: String?,
        now: Date
    ) throws {
        try DurableWorkAttemptEventRecord(
            id: UUID().uuidString,
            workId: workId,
            attempt: attempt,
            sequence: sequence,
            eventKind: kind,
            workerId: workerId,
            workVersion: workVersion,
            resultingWorkState: resultingState,
            errorCode: errorCode,
            errorMessage: errorMessage,
            occurredAt: now
        ).insert(db)
    }
}

package enum PlanningSuccessCommitResult: Sendable, Equatable {
    case succeeded(work: DurableWorkRecord)
    case usageOverflow(work: DurableWorkRecord)
}

package enum PlanningFailureCommitResult: Sendable, Equatable {
    case retryScheduled(work: DurableWorkRecord, notBefore: Date)
    case failed(work: DurableWorkRecord)
    case usageOverflow(work: DurableWorkRecord)
}

package enum PlanningTerminalProposal: Sendable, Equatable {
    case success(PlanResult)
    case failure(PlanningAttemptFailure)
    case usageOverflow(PlanningUsageOverflowEvidenceV1)
}

package struct UnexpectedPlanningFallbackError: Error, Sendable, Equatable {
    package init() {}
}

package struct PlanningDurableDispatchNotRunningError:
    Error, Sendable, Equatable
{
    package let actualMode: DispatchMode

    package init(actualMode: DispatchMode) {
        self.actualMode = actualMode
    }
}

extension AppDatabase {
    public func enqueueMissionPlanning(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput,
        idempotencyKey: String,
        traceId: String,
        planningProviderResolver: any PlanningProviderResolver
    ) throws -> (missionId: String, workId: String) {
        let snapshot = try pool.read { db in
            try PlanningDurableWorkLedgerOwner.startReadSnapshot(
                db,
                goal: goal,
                companionIds: companionIds,
                workspacePath: workspacePath,
                budgetTokens: budgetTokens,
                campId: campId,
                autonomy: autonomy,
                planningInput: planningInput,
                idempotencyKey: idempotencyKey
            )
        }
        switch snapshot {
        case let .replay(missionId, workId):
            return (missionId, workId)
        case let .absent(profileSnapshot):
            _ = try planningProviderResolver.resolvePlanningProvider(
                profileId: planningInput.runtimeProfileId,
                model: planningInput.plannerModel
            )
            guard let profileSnapshot,
                  !profileSnapshot.kind.isCLI
            else {
                throw InvalidDurableWorkStateError()
            }
            return try pool.write { db in
                try PlanningDurableWorkLedgerOwner.enqueueMissionPlanning(
                    db,
                    goal: goal,
                    companionIds: companionIds,
                    workspacePath: workspacePath,
                    budgetTokens: budgetTokens,
                    campId: campId,
                    autonomy: autonomy,
                    planningInput: planningInput,
                    idempotencyKey: idempotencyKey,
                    traceId: traceId,
                    profileSnapshot: profileSnapshot
                )
            }
        }
    }

    package func convertCandidateAndEnqueuePlanning(
        _ command: CandidatePlanningStartCommand,
        planningProviderResolver: any PlanningProviderResolver
    ) throws -> CandidatePlanningStartResult {
        let snapshot = try pool.read { db in
            try PlanningDurableWorkLedgerOwner
                .candidateStartReadSnapshot(
                    db,
                    command: command
                )
        }
        switch snapshot {
        case let .replay(result):
            return result
        case let .absent(profileSnapshot):
            _ = try planningProviderResolver.resolvePlanningProvider(
                profileId: command.planningInput.runtimeProfileId,
                model: command.planningInput.plannerModel
            )
            return try pool.write { db in
                try PlanningDurableWorkLedgerOwner
                    .convertCandidateAndEnqueuePlanning(
                        db,
                        command: command,
                        profileSnapshot: profileSnapshot
                    )
            }
        }
    }

    package func startScheduledMission(
        _ command: SchedulePlanningStartCommand,
        planningProviderResolver: any PlanningProviderResolver
    ) throws -> ScheduleFireCommitResult {
        let snapshot = try pool.read { database in
            try PlanningDurableWorkLedgerOwner
                .ScheduleDurablePlanningLedgerOwner
                .originalReadSnapshot(database, command: command)
        }
        switch snapshot {
        case .replay(let result):
            return result
        case .absent(let preparation):
            let providerOutcome = try PlanningDurableWorkLedgerOwner
                .ScheduleDurablePlanningLedgerOwner.resolveProvider(
                    preparation,
                    resolver: planningProviderResolver,
                    traceId: command.traceId,
                    operation: "schedule-original-provider"
                )
            return try pool.write { database in
                try PlanningDurableWorkLedgerOwner
                    .ScheduleDurablePlanningLedgerOwner.commitOriginal(
                        database,
                        command: command,
                        preparation: preparation,
                        providerOutcome: providerOutcome
                    )
            }
        }
    }

    package func replayMissedScheduleFire(
        _ command: ScheduleReplayStartCommand,
        planningProviderResolver: any PlanningProviderResolver
    ) throws -> ScheduleFireCommitResult {
        let snapshot = try pool.read { database in
            try PlanningDurableWorkLedgerOwner
                .ScheduleDurablePlanningLedgerOwner
                .replayReadSnapshot(database, command: command)
        }
        switch snapshot {
        case .replay(let result):
            return result
        case .absent(let preparation):
            let providerOutcome = try PlanningDurableWorkLedgerOwner
                .ScheduleDurablePlanningLedgerOwner.resolveProvider(
                    preparation,
                    resolver: planningProviderResolver,
                    traceId: command.traceId,
                    operation: "schedule-replay-provider"
                )
            return try pool.write { database in
                try PlanningDurableWorkLedgerOwner
                    .ScheduleDurablePlanningLedgerOwner.commitReplay(
                        database,
                        command: command,
                        preparation: preparation,
                        providerOutcome: providerOutcome
                    )
            }
        }
    }

    package func claimNextPlanning(
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim? {
        let expiration = try PlanningDurableWorkLedgerOwner.validateLease(
            now: now,
            duration: leaseDuration
        )
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.claimNextPlanning(
                db,
                workerId: workerId,
                now: now,
                expiration: expiration
            )
        }
    }

    package func renewPlanningLease(
        claim: DurableWorkClaim,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim {
        let expiration = try PlanningDurableWorkLedgerOwner.validateLease(
            now: now,
            duration: leaseDuration
        )
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.renewPlanningLease(
                db,
                claim: claim,
                now: now,
                expiration: expiration
            )
        }
    }

    package func nextClaimablePlanningDate(now: Date) throws -> Date? {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        return try pool.read { db in
            try PlanningDurableWorkLedgerOwner.nextClaimablePlanningDate(
                db,
                now: now
            )
        }
    }

    package func commitPlanningSuccess(
        claim: DurableWorkClaim,
        result: PlanResult,
        now: Date
    ) throws -> PlanningSuccessCommitResult {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        guard result.fallbackReason == nil else {
            throw UnexpectedPlanningFallbackError()
        }
        let usage = try PlanningUsageCountersV1(usage: result.usage)
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.commitPlanningSuccess(
                db,
                claim: claim,
                result: result,
                usage: usage,
                now: now
            )
        }
    }

    package func recordPlanningAttemptFailure(
        claim: DurableWorkClaim,
        failure: PlanningAttemptFailure,
        now: Date
    ) throws -> PlanningFailureCommitResult {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        let usage = try failure.usage.map(PlanningUsageCountersV1.init)
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.recordPlanningAttemptFailure(
                db,
                claim: claim,
                failure: failure,
                usage: usage,
                now: now
            )
        }
    }

    package func recordPlanningUsageOverflow(
        claim: DurableWorkClaim,
        evidence: PlanningUsageOverflowEvidenceV1,
        now: Date
    ) throws -> DurableWorkRecord {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        let evidenceBytes = try CanonicalJSONV1.encode(evidence)
        return try pool.write { db in
            let graph = try PlanningDurableWorkLedgerOwner
                .requireProviderTransaction(
                    db,
                    claim: claim,
                    now: now
                )
            return try PlanningDurableWorkLedgerOwner
                .terminalizeUsageOverflow(
                    db,
                    graph: graph,
                    claim: claim,
                    evidenceBytes: evidenceBytes,
                    now: now
                )
        }
    }

    package func cancelPlanning(
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date
    ) throws -> DurableWorkCancelResult {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        try PlanningDurableWorkLedgerOwner.validateCancellationReason(reason)
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.cancelPlanning(
                db,
                workId: workId,
                expectedVersion: expectedVersion,
                reason: reason,
                now: now
            )
        }
    }

    package func cancelAllPlanningForEmergencyHalt(
        reason: String,
        now: Date
    ) throws -> [String] {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        try PlanningDurableWorkLedgerOwner.validateCancellationReason(reason)
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner
                .cancelAllPlanningForEmergencyHalt(
                    db,
                    reason: reason,
                    now: now
                )
        }
    }

    package func adoptInterruptedPlanning(
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        return try pool.write { db in
            try PlanningDurableWorkLedgerOwner.adoptInterruptedPlanning(
                db,
                currentWorkerId: currentWorkerId,
                now: now
            )
        }
    }

    package func repairLegacyPlanningMissions(
        profileModels: [String: String],
        now: Date
    ) throws {
        try PlanningDurableWorkLedgerOwner.validateNow(now)
        let missionIds = try pool.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT id
                    FROM mission
                    WHERE status = 'planning'
                    ORDER BY id
                    """
            )
        }
        for missionId in missionIds {
            try pool.write { db in
                try PlanningDurableWorkLedgerOwner
                    .repairLegacyPlanningMission(
                        db,
                        missionId: missionId,
                        profileModels: profileModels,
                        now: now
                    )
            }
        }
    }
}

fileprivate enum PlanningDurableWorkLedgerOwner {
    enum StartReadSnapshot {
        case replay(missionId: String, workId: String)
        case absent(profileSnapshot: RuntimeProfileRecord?)
    }

    struct Graph {
        var work: DurableWorkRecord
        var mission: MissionRecord
        let squad: SquadRecord
        let memberIds: [String]
    }

    private struct EmptyPayload: Codable {}

    private struct PlanCompletedPayload: Codable {
        let goalRefined: String
        let cardIds: [String]
        let titles: [String]
    }

    private struct MissionFailurePayload: Codable {
        let reason: String
    }

    private struct MissionStatusPayload: Codable {
        let from: String
        let to: String
    }

    static func validateNow(_ now: Date) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteNow
        }
    }

    static func validateLease(
        now: Date,
        duration: TimeInterval
    ) throws -> Date {
        try validateNow(now)
        guard duration.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseDuration
        }
        guard duration > 0 else {
            throw InvalidDurableWorkTimeError.nonPositiveLeaseDuration
        }
        let expiration = now.addingTimeInterval(duration)
        guard expiration.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
        }
        guard expiration > now else {
            throw InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
        }
        return expiration
    }

    static func validateCancellationReason(_ reason: String) throws {
        guard !reason.isEmpty else {
            throw InvalidDurableWorkCancellationReasonError.empty
        }
        guard reason.unicodeScalars.count <= 1_000 else {
            throw InvalidDurableWorkCancellationReasonError.tooLong
        }
        guard !DurableWorkFailure.containsControlScalar(reason) else {
            throw InvalidDurableWorkCancellationReasonError
                .containsControlScalar
        }
    }

    private static func requireNonBlank(_ value: String) throws {
        guard !value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw InvalidDurableWorkStateError()
        }
    }

    private static func requireDispatchMode(
        _ db: Database,
        runningRequired: Bool
    ) throws -> DispatchMode {
        guard let control = try KernelControlRecord.fetchOne(
            db,
            key: "global"
        ) else {
            throw RecordNotFoundError(
                table: KernelControlRecord.databaseTableName,
                id: "global"
            )
        }
        if runningRequired, control.dispatchMode != .running {
            throw PlanningDurableDispatchNotRunningError(
                actualMode: control.dispatchMode
            )
        }
        return control.dispatchMode
    }

    private static func canonicalString<T: Encodable>(
        _ value: T
    ) throws -> String {
        String(decoding: try CanonicalJSONV1.encode(value), as: UTF8.self)
    }

    private static func insertMissionEvent<T: Encodable>(
        _ db: Database,
        missionId: String,
        kind: String,
        payload: T,
        now: Date
    ) throws {
        let payloadJSON = try canonicalString(payload)
        _ = try AppDatabase.appendLegacyEventAndScope(
            db,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: kind,
            payloadJSON: payloadJSON,
            createdAt: now
        )
    }

    private static func checkedIncrement(_ value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(1)
        guard !overflow else {
            throw InvalidDurableWorkStateError()
        }
        return result
    }

    private static func requireWork(
        _ db: Database,
        id: String
    ) throws -> DurableWorkRecord {
        guard let work = try DurableWorkRecord.fetchOne(db, key: id) else {
            throw DurableWorkNotFoundError(workId: id)
        }
        return work
    }

    private static func requirePlanningGraph(
        _ db: Database,
        work: DurableWorkRecord,
        requirePlanningMission: Bool,
        requireUnarchivedCamp: Bool
    ) throws -> Graph {
        guard work.kind == .planning,
              work.aggregateType == "mission"
        else {
            throw InvalidDurableWorkStateError()
        }
        guard let mission = try MissionRecord.fetchOne(
            db,
            key: work.aggregateId
        ) else {
            throw RecordNotFoundError(
                table: MissionRecord.databaseTableName,
                id: work.aggregateId
            )
        }
        guard let squad = try SquadRecord.fetchOne(
            db,
            key: mission.squadId
        ) else {
            throw RecordNotFoundError(
                table: SquadRecord.databaseTableName,
                id: mission.squadId
            )
        }
        guard squad.campId == work.campId,
              let camp = try CampRecord.fetchOne(db, key: work.campId)
        else {
            throw InvalidDurableWorkStateError()
        }
        if requireUnarchivedCamp, camp.archived {
            throw CampArchivedError(campId: camp.id)
        }
        if requirePlanningMission, mission.status != .planning {
            throw InvalidDurableWorkStateError()
        }
        let memberIds = try JSONDecoder().decode(
            [String].self,
            from: Data(squad.memberIdsJson.utf8)
        )
        return Graph(
            work: work,
            mission: mission,
            squad: squad,
            memberIds: memberIds
        )
    }

    static func startReadSnapshot(
        _ db: Database,
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput,
        idempotencyKey: String
    ) throws -> StartReadSnapshot {
        try requireNonBlank(idempotencyKey)
        _ = try requireDispatchMode(db, runningRequired: true)
        if let existing = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(db)
        {
            let ids = try validateReplay(
                db,
                work: existing,
                goal: goal,
                companionIds: companionIds,
                workspacePath: workspacePath,
                budgetTokens: budgetTokens,
                campId: campId,
                autonomy: autonomy,
                planningInput: planningInput
            )
            return .replay(missionId: ids.missionId, workId: ids.workId)
        }
        let profile = try RuntimeProfileRecord.fetchOne(
            db,
            key: planningInput.runtimeProfileId
        )
        return .absent(profileSnapshot: profile)
    }

    private static func validateReplay(
        _ db: Database,
        work: DurableWorkRecord,
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput
    ) throws -> (missionId: String, workId: String) {
        do {
            guard work.kind == .planning,
                  work.aggregateType == "mission",
                  work.maxAttempts == 4
            else {
                throw DurableWorkReplayConflictError()
            }
            let graph = try requirePlanningGraph(
                db,
                work: work,
                requirePlanningMission: false,
                requireUnarchivedCamp: false
            )
            let inputBytes = Data(work.inputJson.utf8)
            let decodedInput = try JSONDecoder().decode(
                PlanningWorkInput.self,
                from: inputBytes
            )
            guard try CanonicalJSONV1.encode(decodedInput) == inputBytes,
                  CanonicalJSONV1.sha256Hex(inputBytes) == work.inputHash,
                  decodedInput == planningInput
            else {
                throw DurableWorkReplayConflictError()
            }
            let createdEvents = try EventRecord
                .filter(
                    Column("missionId") == graph.mission.id
                        && Column("kind") == EventKind.missionCreated
                )
                .fetchAll(db)
            guard createdEvents.count == 1 else {
                throw DurableWorkReplayConflictError()
            }
            let identityBytes = Data(createdEvents[0].payloadJson.utf8)
            let persistedIdentity = try JSONDecoder().decode(
                MissionPlanningStartIdentityV1.self,
                from: identityBytes
            )
            guard try CanonicalJSONV1.encode(persistedIdentity)
                    == identityBytes
            else {
                throw DurableWorkReplayConflictError()
            }
            if let campId, campId != persistedIdentity.campId {
                throw DurableWorkReplayConflictError()
            }
            let incomingIdentity = try MissionPlanningStartIdentityV1(
                goal: goal,
                companionIds: companionIds,
                workspacePath: workspacePath,
                budgetTokens: budgetTokens,
                campId: persistedIdentity.campId,
                autonomy: autonomy,
                planningInput: planningInput
            )
            guard incomingIdentity == persistedIdentity,
                  graph.memberIds == persistedIdentity.companionIds,
                  graph.squad.workspacePath
                    == persistedIdentity.workspacePath,
                  graph.squad.campId == persistedIdentity.campId,
                  graph.mission.goalRaw == persistedIdentity.goal,
                  work.campId == persistedIdentity.campId
            else {
                throw DurableWorkReplayConflictError()
            }
            let planStartedCount = try EventRecord
                .filter(
                    Column("missionId") == graph.mission.id
                        && Column("kind") == EventKind.planStarted
                )
                .fetchCount(db)
            guard planStartedCount == 1 else {
                throw DurableWorkReplayConflictError()
            }
            return (graph.mission.id, work.id)
        } catch is DurableWorkReplayConflictError {
            throw DurableWorkReplayConflictError()
        } catch {
            throw DurableWorkReplayConflictError()
        }
    }

    static func enqueueMissionPlanning(
        _ db: Database,
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput,
        idempotencyKey: String,
        traceId: String,
        profileSnapshot: RuntimeProfileRecord
    ) throws -> (missionId: String, workId: String) {
        try requireNonBlank(idempotencyKey)
        try requireNonBlank(traceId)
        _ = try requireDispatchMode(db, runningRequired: true)
        if let winner = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(db)
        {
            return try validateReplay(
                db,
                work: winner,
                goal: goal,
                companionIds: companionIds,
                workspacePath: workspacePath,
                budgetTokens: budgetTokens,
                campId: campId,
                autonomy: autonomy,
                planningInput: planningInput
            )
        }
        guard let currentProfile = try RuntimeProfileRecord.fetchOne(
            db,
            key: planningInput.runtimeProfileId
        ), currentProfile.kind == profileSnapshot.kind,
           !currentProfile.kind.isCLI
        else {
            throw InvalidDurableWorkStateError()
        }
        for companionId in companionIds {
            try requireNonBlank(companionId)
            guard try CompanionRecord.fetchOne(db, key: companionId) != nil
            else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: companionId
                )
            }
        }

        let camp: CampRecord
        if let campId {
            guard let requested = try CampRecord.fetchOne(db, key: campId)
            else {
                throw RecordNotFoundError(
                    table: CampRecord.databaseTableName,
                    id: campId
                )
            }
            guard !requested.archived else {
                throw CampArchivedError(campId: requested.id)
            }
            camp = requested
        } else if let existing = try CampRecord.fetchOne(db) {
            guard !existing.archived else {
                throw CampArchivedError(campId: existing.id)
            }
            camp = existing
        } else {
            camp = try AppDatabase.ensureDefaultCamp(db)
        }

        let identity = try MissionPlanningStartIdentityV1(
            goal: goal,
            companionIds: companionIds,
            workspacePath: workspacePath,
            budgetTokens: budgetTokens,
            campId: camp.id,
            autonomy: autonomy,
            planningInput: planningInput
        )
        let identityJson = try canonicalString(identity)
        let inputBytes = try CanonicalJSONV1.encode(planningInput)
        let inputJson = String(decoding: inputBytes, as: UTF8.self)
        let inputHash = CanonicalJSONV1.sha256Hex(inputBytes)
        let memberIdsJson = try canonicalString(companionIds)
        let now = Date()
        let squadId = UUID().uuidString
        let missionId = UUID().uuidString
        let workId = UUID().uuidString

        try SquadRecord(
            id: squadId,
            campId: camp.id,
            name: AppDatabase.truncatedFirstLine(goal, max: 30),
            memberIdsJson: memberIdsJson,
            workspacePath: workspacePath,
            workspaceBookmark: WorkspaceScopedAccess.captureBookmark(
                forPath: workspacePath
            ),
            createdAt: now
        ).insert(db)
        try MissionRecord(
            id: missionId,
            squadId: squadId,
            goalRaw: goal,
            goalRefined: "",
            status: .planning,
            budgetTokens: identity.budgetTokens,
            spentTokens: 0,
            revision: 1,
            autonomy: autonomy,
            createdAt: now
        ).insert(db)
        _ = try AppDatabase.appendLegacyEventAndScope(
            db,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.missionCreated,
            payloadJSON: identityJson,
            createdAt: now
        )
        try insertMissionEvent(
            db,
            missionId: missionId,
            kind: EventKind.planStarted,
            payload: EmptyPayload(),
            now: now
        )
        let planningWork = DurableWorkRecord(
            id: workId,
            campId: camp.id,
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId,
            idempotencyKey: idempotencyKey,
            state: .queued,
            attempt: 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: inputJson,
            inputHash: inputHash,
            outputJson: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: nil
        )
        try DurableWorkStore.insertCurrentSchemaRecord(
            planningWork,
            in: db
        )
        return (missionId, workId)
    }

    fileprivate enum ScheduleDurablePlanningLedgerOwner {
        enum OriginalReadSnapshot {
            case replay(ScheduleFireCommitResult)
            case absent(PreparationSnapshot)
        }

        enum ReplayReadSnapshot {
            case replay(ScheduleFireCommitResult)
            case absent(PreparationSnapshot)
        }

        enum PreparationSnapshot {
            case selected(
                runtimeProfileId: String,
                plannerModel: String,
                profile: RuntimeProfileRecord
            )
            case runtimeUnavailable
            case forcedFailure
        }

        enum ProviderOutcome {
            case available
            case typedUnavailable
            case notRequested
        }

        private struct FixedFailure {
            let code: String
            let message: String

            static func isCanonical(code: String, message: String) -> Bool {
                [
                    disabled,
                    configuration,
                    campArchived,
                    template,
                    companionMissing,
                    companionWrongCamp,
                    runtimeUnavailable,
                    providerUnavailable,
                    missedWhileOffline,
                ].contains {
                    $0.code == code && $0.message == message
                }
            }

            static let disabled = FixedFailure(
                code: "schedule_disabled",
                message: "定时行动已停用。"
            )
            static let configuration = FixedFailure(
                code: "schedule_configuration_invalid",
                message: "定时行动配置无效。"
            )
            static let campArchived = FixedFailure(
                code: "schedule_camp_archived",
                message: "定时行动所属营地已归档。"
            )
            static let template = FixedFailure(
                code: "schedule_template_invalid",
                message: "定时行动模板配置无效。"
            )
            static let companionMissing = FixedFailure(
                code: "schedule_companion_missing",
                message: "定时行动模板引用的伙伴不存在。"
            )
            static let companionWrongCamp = FixedFailure(
                code: "schedule_companion_wrong_camp",
                message: "定时行动模板中的伙伴不属于该营地。"
            )
            static let runtimeUnavailable = FixedFailure(
                code: "schedule_runtime_unavailable",
                message: "定时行动的运行配置不可用。"
            )
            static let providerUnavailable = FixedFailure(
                code: "schedule_provider_unavailable",
                message: "定时行动的规划服务暂不可用。"
            )
            static let missedWhileOffline = FixedFailure(
                code: "schedule_missed_while_offline",
                message: "定时行动在应用离线期间错过了触发时间。"
            )
        }

        private struct RequiredScope {
            let schedule: ScheduleRecord
            let template: MissionTemplateRecord
            let camp: CampRecord
        }

        private struct StartedScope {
            let schedule: ScheduleRecord
            let template: MissionTemplateRecord
            let camp: CampRecord
            let companionIds: [String]
            let budgetTokens: Int
            let planningInput: PlanningWorkInput
        }

        private enum BusinessEvaluation {
            case failed(FixedFailure)
            case started(StartedScope)
        }

        private enum CommittedFirePlanningExpectation {
            case original
            case replaySelected(PlanningWorkInput)
            case replayUnavailable
        }

        private static let logger = Logger(
            subsystem: "com.muzi.agentloop",
            category: "schedule-durable-planning-ledger"
        )

        static func originalReadSnapshot(
            _ db: Database,
            command: SchedulePlanningStartCommand
        ) throws -> OriginalReadSnapshot {
            _ = try requireDispatchMode(db, runningRequired: true)
            if let winner = try originalFire(
                db,
                scheduleId: command.scheduleId,
                slotKey: command.context.slotKey
            ) {
                guard try contextIsSelfConsistent(command.context),
                      winner.scheduleId == command.scheduleId,
                      winner.slotKey == command.context.slotKey,
                      instantBits(winner.scheduledAt)
                        == command.context.scheduledAtInstantBits,
                      winner.replayOfFireId == nil,
                      winner.replayIdempotencyKey == nil,
                      winner.replayPayloadHash == nil
                else {
                    throw ScheduleFireReplayIntegrityError(
                        fireId: winner.id
                    )
                }
                return .replay(
                    try validateCommittedFire(
                        db,
                        fire: winner,
                        expectedWorkIdempotencyKey:
                            originalWorkIdempotencyKey(
                                scheduleId: command.scheduleId,
                                slotKey: command.context.slotKey
                            ),
                        planningExpectation: .original
                    )
                )
            }

            guard try contextIsSelfConsistent(command.context) else {
                throw StaleScheduleConfigurationError(
                    scheduleId: command.scheduleId
                )
            }
            _ = try requiredOriginalScope(
                db,
                scheduleId: command.scheduleId
            )
            return .absent(
                try capturePreparation(
                    db,
                    preparation: command.preparation
                )
            )
        }

        static func replayReadSnapshot(
            _ db: Database,
            command: ScheduleReplayStartCommand
        ) throws -> ReplayReadSnapshot {
            _ = try requireDispatchMode(db, runningRequired: true)
            try validateReplayCommandIdentity(command)
            if let winner = try replayFire(
                db,
                replayIdempotencyKey: command.replayIdempotencyKey
            ) {
                return .replay(
                    try validateReplayWinner(
                        db,
                        fire: winner,
                        command: command
                    )
                )
            }

            let original = try requireReplaySource(
                db,
                originalFireId: command.originalFireId
            )
            let scope = try requiredOriginalScope(
                db,
                scheduleId: original.scheduleId
            )
            try validateReplayPayload(
                command,
                original: original,
                actualTemplateId: scope.schedule.templateId
            )
            return .absent(
                try capturePreparation(
                    db,
                    preparation: try preparation(from: command.payload)
                )
            )
        }

        static func resolveProvider(
            _ preparation: PreparationSnapshot,
            resolver: any PlanningProviderResolver,
            traceId: String,
            operation: String
        ) throws -> ProviderOutcome {
            switch preparation {
            case .runtimeUnavailable, .forcedFailure:
                return .notRequested
            case let .selected(runtimeProfileId, plannerModel, _):
                do {
                    _ = try resolver.resolvePlanningProvider(
                        profileId: runtimeProfileId,
                        model: plannerModel
                    )
                    return .available
                } catch is PlanningProviderResolutionError {
                    return .typedUnavailable
                } catch {
                    logger.error(
                        "unknown provider resolver failure operation=\(operation, privacy: .public) trace=\(traceId, privacy: .private(mask: .hash)) type=\(String(reflecting: type(of: error)), privacy: .public)"
                    )
                    throw error
                }
            }
        }

        static func commitOriginal(
            _ db: Database,
            command: SchedulePlanningStartCommand,
            preparation: PreparationSnapshot,
            providerOutcome: ProviderOutcome
        ) throws -> ScheduleFireCommitResult {
            _ = try requireDispatchMode(db, runningRequired: true)
            if let winner = try originalFire(
                db,
                scheduleId: command.scheduleId,
                slotKey: command.context.slotKey
            ) {
                guard try contextIsSelfConsistent(command.context),
                      winner.scheduleId == command.scheduleId,
                      winner.slotKey == command.context.slotKey,
                      instantBits(winner.scheduledAt)
                        == command.context.scheduledAtInstantBits,
                      winner.replayOfFireId == nil,
                      winner.replayIdempotencyKey == nil,
                      winner.replayPayloadHash == nil
                else {
                    throw ScheduleFireReplayIntegrityError(
                        fireId: winner.id
                    )
                }
                return try validateCommittedFire(
                    db,
                    fire: winner,
                    expectedWorkIdempotencyKey:
                        originalWorkIdempotencyKey(
                            scheduleId: command.scheduleId,
                            slotKey: command.context.slotKey
                        ),
                    planningExpectation: .original
                )
            }

            guard try contextIsSelfConsistent(command.context) else {
                throw StaleScheduleConfigurationError(
                    scheduleId: command.scheduleId
                )
            }
            let schedule = try requireSchedule(
                db,
                scheduleId: command.scheduleId
            )
            guard schedule.frequency == command.context.frequency,
                  schedule.hour == command.context.hour,
                  schedule.minute == command.context.minute,
                  schedule.weekday == command.context.weekday
            else {
                throw StaleScheduleConfigurationError(
                    scheduleId: command.scheduleId
                )
            }
            try validateCursorForOriginal(
                db,
                scheduleId: command.scheduleId,
                scheduleCreatedAt: schedule.createdAt,
                context: command.context
            )
            let scope = try requiredOriginalScope(db, schedule: schedule)
            let evaluation = try evaluateBusiness(
                db,
                scope: scope,
                preparation: preparation,
                providerOutcome: providerOutcome
            )
            try requireNonBlank(command.traceId)
            switch evaluation {
            case let .failed(failure):
                return try insertFailedFire(
                    db,
                    scheduleId: command.scheduleId,
                    templateId: scope.template.id,
                    slotKey: command.context.slotKey,
                    scheduledAt: command.context.scheduledAt,
                    replayOfFireId: nil,
                    replayIdempotencyKey: nil,
                    replayPayloadHash: nil,
                    traceId: command.traceId,
                    failure: failure,
                    advanceCursor: true
                )
            case let .started(startedScope):
                return try insertStartedFire(
                    db,
                    scope: startedScope,
                    slotKey: command.context.slotKey,
                    scheduledAt: command.context.scheduledAt,
                    replayOfFireId: nil,
                    replayIdempotencyKey: nil,
                    replayPayloadHash: nil,
                    traceId: command.traceId,
                    workIdempotencyKey: originalWorkIdempotencyKey(
                        scheduleId: command.scheduleId,
                        slotKey: command.context.slotKey
                    ),
                    advanceCursor: true,
                    updateLastFiredAt: true
                )
            }
        }

        static func commitReplay(
            _ db: Database,
            command: ScheduleReplayStartCommand,
            preparation: PreparationSnapshot,
            providerOutcome: ProviderOutcome
        ) throws -> ScheduleFireCommitResult {
            _ = try requireDispatchMode(db, runningRequired: true)
            try validateReplayCommandIdentity(command)
            if let winner = try replayFire(
                db,
                replayIdempotencyKey: command.replayIdempotencyKey
            ) {
                return try validateReplayWinner(
                    db,
                    fire: winner,
                    command: command
                )
            }

            let original = try requireReplaySource(
                db,
                originalFireId: command.originalFireId
            )
            let scope = try requiredOriginalScope(
                db,
                scheduleId: original.scheduleId
            )
            try validateReplayPayload(
                command,
                original: original,
                actualTemplateId: scope.schedule.templateId
            )
            let evaluation = try evaluateBusiness(
                db,
                scope: scope,
                preparation: preparation,
                providerOutcome: providerOutcome
            )
            try requireNonBlank(command.traceId)
            switch evaluation {
            case let .failed(failure):
                return try insertFailedFire(
                    db,
                    scheduleId: original.scheduleId,
                    templateId: scope.template.id,
                    slotKey: original.slotKey,
                    scheduledAt: original.scheduledAt,
                    replayOfFireId: original.id,
                    replayIdempotencyKey: command.replayIdempotencyKey,
                    replayPayloadHash: command.replayPayloadHash,
                    traceId: command.traceId,
                    failure: failure,
                    advanceCursor: false
                )
            case let .started(startedScope):
                return try insertStartedFire(
                    db,
                    scope: startedScope,
                    slotKey: original.slotKey,
                    scheduledAt: original.scheduledAt,
                    replayOfFireId: original.id,
                    replayIdempotencyKey: command.replayIdempotencyKey,
                    replayPayloadHash: command.replayPayloadHash,
                    traceId: command.traceId,
                    workIdempotencyKey: replayWorkIdempotencyKey(
                        command.replayIdempotencyKey
                    ),
                    advanceCursor: false,
                    updateLastFiredAt: false
                )
            }
        }

        private static func capturePreparation(
            _ db: Database,
            preparation: ScheduleFirePreparation
        ) throws -> PreparationSnapshot {
            switch preparation {
            case .forcedFailure:
                return .forcedFailure
            case .unavailable:
                return .runtimeUnavailable
            case let .selected(runtimeProfileId, plannerModel):
                guard isNonBlank(runtimeProfileId),
                      isNonBlank(plannerModel),
                      let profile = try RuntimeProfileRecord.fetchOne(
                          db,
                          key: runtimeProfileId
                      ),
                      !profile.kind.isCLI
                else {
                    return .runtimeUnavailable
                }
                return .selected(
                    runtimeProfileId: runtimeProfileId,
                    plannerModel: plannerModel,
                    profile: profile
                )
            }
        }

        private static func preparation(
            from payload: ScheduleReplayPayloadV1
        ) throws -> ScheduleFirePreparation {
            switch payload.runtimeState {
            case "selected":
                guard let runtimeProfileId = payload.runtimeProfileId,
                      let plannerModel = payload.plannerModel,
                      payload.preflightFailureCode == nil
                else {
                    throw DurableWorkReplayConflictError()
                }
                return .selected(
                    runtimeProfileId: runtimeProfileId,
                    plannerModel: plannerModel
                )
            case "unavailable":
                guard payload.runtimeProfileId == nil,
                      payload.plannerModel == nil,
                      payload.preflightFailureCode
                        == "schedule_runtime_unavailable"
                else {
                    throw DurableWorkReplayConflictError()
                }
                return .unavailable
            default:
                throw DurableWorkReplayConflictError()
            }
        }

        private static func evaluateBusiness(
            _ db: Database,
            scope: RequiredScope,
            preparation: PreparationSnapshot,
            providerOutcome: ProviderOutcome
        ) throws -> BusinessEvaluation {
            if !scope.schedule.enabled {
                return .failed(.disabled)
            }
            do {
                try scope.schedule.validate()
            } catch is ScheduleValidationError {
                return .failed(.configuration)
            }
            if scope.camp.archived {
                return .failed(.campArchived)
            }

            let budgetTokens: Int
            let companionIds: [String]
            do {
                budgetTokens = try scope.template
                    .validateForScheduledMission()
                companionIds = try scope.template.companionIds()
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }
            } catch is MissionTemplateValidationError {
                return .failed(.template)
            } catch is DecodingError {
                return .failed(.template)
            }

            var companions: [CompanionRecord] = []
            companions.reserveCapacity(companionIds.count)
            for companionId in companionIds {
                guard let companion = try CompanionRecord.fetchOne(
                    db,
                    key: companionId
                ) else {
                    return .failed(.companionMissing)
                }
                companions.append(companion)
            }
            for companion in companions {
                guard companion.campId == scope.camp.id else {
                    return .failed(.companionWrongCamp)
                }
            }

            switch preparation {
            case .forcedFailure:
                guard providerOutcome == .notRequested else {
                    throw InvalidDurableWorkStateError()
                }
                return .failed(.missedWhileOffline)
            case .runtimeUnavailable:
                guard providerOutcome == .notRequested else {
                    throw InvalidDurableWorkStateError()
                }
                return .failed(.runtimeUnavailable)
            case let .selected(
                runtimeProfileId,
                plannerModel,
                profileSnapshot
            ):
                guard let currentProfile = try RuntimeProfileRecord.fetchOne(
                    db,
                    key: runtimeProfileId
                ), currentProfile.id == profileSnapshot.id,
                   currentProfile.kind == profileSnapshot.kind,
                   currentProfile.baseURL == profileSnapshot.baseURL,
                   currentProfile.credentialAccount
                    == profileSnapshot.credentialAccount,
                   !currentProfile.kind.isCLI
                else {
                    return .failed(.runtimeUnavailable)
                }
                switch providerOutcome {
                case .typedUnavailable:
                    return .failed(.providerUnavailable)
                case .notRequested:
                    throw InvalidDurableWorkStateError()
                case .available:
                    let planningInput = try PlanningWorkInput(
                        plannerModel: plannerModel,
                        runtimeProfileId: runtimeProfileId
                    )
                    return .started(
                        StartedScope(
                            schedule: scope.schedule,
                            template: scope.template,
                            camp: scope.camp,
                            companionIds: companionIds,
                            budgetTokens: budgetTokens,
                            planningInput: planningInput
                        )
                    )
                }
            }
        }

        private static func requiredOriginalScope(
            _ db: Database,
            scheduleId: String
        ) throws -> RequiredScope {
            try requiredOriginalScope(
                db,
                schedule: requireSchedule(db, scheduleId: scheduleId)
            )
        }

        private static func requireSchedule(
            _ db: Database,
            scheduleId: String
        ) throws -> ScheduleRecord {
            guard let schedule = try ScheduleRecord.fetchOne(
                db,
                key: scheduleId
            ) else {
                throw RecordNotFoundError(
                    table: ScheduleRecord.databaseTableName,
                    id: scheduleId
                )
            }
            return schedule
        }

        private static func requiredOriginalScope(
            _ db: Database,
            schedule: ScheduleRecord
        ) throws -> RequiredScope {
            guard let template = try MissionTemplateRecord.fetchOne(
                db,
                key: schedule.templateId
            ) else {
                throw RecordNotFoundError(
                    table: MissionTemplateRecord.databaseTableName,
                    id: schedule.templateId
                )
            }
            guard template.id == schedule.templateId else {
                throw ScheduleFireScopeIntegrityError(
                    scheduleId: schedule.id
                )
            }
            guard let camp = try CampRecord.fetchOne(
                db,
                key: template.campId
            ) else {
                throw RecordNotFoundError(
                    table: CampRecord.databaseTableName,
                    id: template.campId
                )
            }
            return RequiredScope(
                schedule: schedule,
                template: template,
                camp: camp
            )
        }

        private static func validateCursorForOriginal(
            _ db: Database,
            scheduleId: String,
            scheduleCreatedAt: Date,
            context: ScheduleSlotContextV1
        ) throws {
            guard let cursor = try ScheduleEvaluationCursorRecord.fetchOne(
                db,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: [scheduleId]
            ) else {
                guard context.scheduledAt > scheduleCreatedAt else {
                    throw StaleScheduleEvaluationError(
                        scheduleId: scheduleId,
                        slotKey: context.slotKey
                    )
                }
                return
            }
            let incoming = context.scheduledAt.timeIntervalSince1970
            let persisted = cursor.lastEvaluatedScheduledAt
                .timeIntervalSince1970
            if incoming < persisted
                || (incoming == persisted
                    && context.slotKey.utf8.lexicographicallyPrecedes(
                        cursor.lastEvaluatedSlotKey.utf8
                    ))
            {
                throw StaleScheduleEvaluationError(
                    scheduleId: scheduleId,
                    slotKey: context.slotKey
                )
            }
            if incoming == persisted,
               context.slotKey == cursor.lastEvaluatedSlotKey {
                throw ScheduleEvaluationIntegrityError(
                    scheduleId: scheduleId,
                    slotKey: context.slotKey
                )
            }
        }

        private static func advanceCursor(
            _ db: Database,
            scheduleId: String,
            slotKey: String,
            scheduledAt: Date,
            now: Date
        ) throws {
            let scheduledSeconds = normalizedSeconds(scheduledAt)
            let nowSeconds = normalizedSeconds(now)
            if let cursor = try ScheduleEvaluationCursorRecord.fetchOne(
                db,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: [scheduleId]
            ) {
                let (nextVersion, overflow) = cursor.version
                    .addingReportingOverflow(1)
                guard !overflow else {
                    throw ScheduleEvaluationVersionOverflowError(
                        scheduleId: scheduleId,
                        version: cursor.version
                    )
                }
                try db.execute(
                    sql: """
                        UPDATE schedule_evaluation_cursor
                        SET lastEvaluatedSlotKey = ?,
                            lastEvaluatedScheduledAt = ?,
                            version = ?, updatedAt = ?
                        WHERE scheduleId = ? AND version = ?
                        """,
                    arguments: [
                        slotKey,
                        scheduledSeconds,
                        nextVersion,
                        nowSeconds,
                        scheduleId,
                        cursor.version,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw ScheduleEvaluationIntegrityError(
                        scheduleId: scheduleId,
                        slotKey: slotKey
                    )
                }
            } else {
                try db.execute(
                    sql: """
                        INSERT INTO schedule_evaluation_cursor (
                          scheduleId, lastEvaluatedSlotKey,
                          lastEvaluatedScheduledAt, version, updatedAt
                        ) VALUES (?, ?, ?, 1, ?)
                        """,
                    arguments: [
                        scheduleId,
                        slotKey,
                        scheduledSeconds,
                        nowSeconds,
                    ]
                )
            }
        }

        private static func insertStartedFire(
            _ db: Database,
            scope: StartedScope,
            slotKey: String,
            scheduledAt: Date,
            replayOfFireId: String?,
            replayIdempotencyKey: String?,
            replayPayloadHash: String?,
            traceId: String,
            workIdempotencyKey: String,
            advanceCursor shouldAdvanceCursor: Bool,
            updateLastFiredAt: Bool
        ) throws -> ScheduleFireCommitResult {
            let identity = try MissionPlanningStartIdentityV1(
                goal: scope.template.goal,
                companionIds: scope.companionIds,
                workspacePath: scope.template.workspacePath,
                budgetTokens: scope.budgetTokens,
                campId: scope.camp.id,
                autonomy: scope.template.autonomy,
                planningInput: scope.planningInput
            )
            let identityJson = try canonicalString(identity)
            let inputBytes = try CanonicalJSONV1.encode(
                scope.planningInput
            )
            let inputJson = String(decoding: inputBytes, as: UTF8.self)
            let inputHash = CanonicalJSONV1.sha256Hex(inputBytes)
            let memberIdsJson = try canonicalString(scope.companionIds)
            let now = Date()
            let squadId = UUID().uuidString
            let missionId = UUID().uuidString
            let workId = UUID().uuidString
            let fireId = UUID().uuidString

            try SquadRecord(
                id: squadId,
                campId: scope.camp.id,
                name: AppDatabase.truncatedFirstLine(
                    scope.template.goal,
                    max: 30
                ),
                memberIdsJson: memberIdsJson,
                workspacePath: scope.template.workspacePath,
                workspaceBookmark: WorkspaceScopedAccess.captureBookmark(
                    forPath: scope.template.workspacePath
                ),
                createdAt: now
            ).insert(db)
            try MissionRecord(
                id: missionId,
                squadId: squadId,
                goalRaw: scope.template.goal,
                goalRefined: "",
                status: .planning,
                budgetTokens: identity.budgetTokens,
                spentTokens: 0,
                revision: 1,
                autonomy: scope.template.autonomy,
                createdAt: now
            ).insert(db)
            _ = try AppDatabase.appendLegacyEventAndScope(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionCreated,
                payloadJSON: identityJson,
                createdAt: now
            )
            try insertMissionEvent(
                db,
                missionId: missionId,
                kind: EventKind.planStarted,
                payload: EmptyPayload(),
                now: now
            )
            let planningWork = DurableWorkRecord(
                id: workId,
                campId: scope.camp.id,
                kind: .planning,
                aggregateType: "mission",
                aggregateId: missionId,
                idempotencyKey: workIdempotencyKey,
                state: .queued,
                attempt: 0,
                maxAttempts: 4,
                notBefore: nil,
                leaseOwner: nil,
                leaseExpiresAt: nil,
                inputJson: inputJson,
                inputHash: inputHash,
                outputJson: nil,
                errorCode: nil,
                errorMessage: nil,
                traceId: traceId,
                version: 1,
                createdAt: now,
                updatedAt: now,
                finishedAt: nil
            )
            try DurableWorkStore.insertCurrentSchemaRecord(
                planningWork,
                in: db
            )
            try insertFireRow(
                db,
                id: fireId,
                scheduleId: scope.schedule.id,
                templateId: scope.template.id,
                slotKey: slotKey,
                scheduledAt: scheduledAt,
                replayOfFireId: replayOfFireId,
                replayIdempotencyKey: replayIdempotencyKey,
                replayPayloadHash: replayPayloadHash,
                state: .started,
                missionId: missionId,
                traceId: traceId,
                failure: nil,
                now: now
            )
            let firedPayload = ScheduleFiredPayloadV1(
                fireId: fireId,
                scheduleId: scope.schedule.id,
                templateId: scope.template.id,
                slotKey: slotKey,
                scheduledAt: normalizedSeconds(scheduledAt),
                replayOfFireId: replayOfFireId,
                traceId: traceId
            )
            try insertScheduleEvent(
                db,
                missionId: missionId,
                kind: EventKind.scheduleFired,
                payloadJson: try canonicalString(firedPayload),
                now: now
            )
            if shouldAdvanceCursor {
                try advanceCursor(
                    db,
                    scheduleId: scope.schedule.id,
                    slotKey: slotKey,
                    scheduledAt: scheduledAt,
                    now: now
                )
            }
            if updateLastFiredAt {
                try db.execute(
                    sql: """
                        UPDATE schedule SET lastFiredAt = ? WHERE id = ?
                        """,
                    arguments: [
                        normalizedSeconds(scheduledAt),
                        scope.schedule.id,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw ScheduleFireScopeIntegrityError(
                        scheduleId: scope.schedule.id
                    )
                }
            }
            let fire = try requireFire(db, id: fireId)
            return ScheduleFireCommitResult(
                fire: fire,
                disposition: .inserted,
                missionId: missionId,
                workId: workId
            )
        }

        private static func insertFailedFire(
            _ db: Database,
            scheduleId: String,
            templateId: String,
            slotKey: String,
            scheduledAt: Date,
            replayOfFireId: String?,
            replayIdempotencyKey: String?,
            replayPayloadHash: String?,
            traceId: String,
            failure: FixedFailure,
            advanceCursor shouldAdvanceCursor: Bool
        ) throws -> ScheduleFireCommitResult {
            let now = Date()
            let fireId = UUID().uuidString
            try insertFireRow(
                db,
                id: fireId,
                scheduleId: scheduleId,
                templateId: templateId,
                slotKey: slotKey,
                scheduledAt: scheduledAt,
                replayOfFireId: replayOfFireId,
                replayIdempotencyKey: replayIdempotencyKey,
                replayPayloadHash: replayPayloadHash,
                state: .failed,
                missionId: nil,
                traceId: traceId,
                failure: failure,
                now: now
            )
            let missedPayload = ScheduleMissedPayloadV1(
                fireId: fireId,
                scheduleId: scheduleId,
                templateId: templateId,
                slotKey: slotKey,
                scheduledAt: normalizedSeconds(scheduledAt),
                replayOfFireId: replayOfFireId,
                traceId: traceId,
                errorCode: failure.code,
                errorMessage: failure.message
            )
            try insertScheduleEvent(
                db,
                missionId: nil,
                kind: EventKind.scheduleMissed,
                payloadJson: try canonicalString(missedPayload),
                now: now
            )
            if shouldAdvanceCursor {
                try advanceCursor(
                    db,
                    scheduleId: scheduleId,
                    slotKey: slotKey,
                    scheduledAt: scheduledAt,
                    now: now
                )
            }
            let fire = try requireFire(db, id: fireId)
            return ScheduleFireCommitResult(
                fire: fire,
                disposition: .inserted,
                missionId: nil,
                workId: nil
            )
        }

        private static func insertFireRow(
            _ db: Database,
            id: String,
            scheduleId: String,
            templateId: String,
            slotKey: String,
            scheduledAt: Date,
            replayOfFireId: String?,
            replayIdempotencyKey: String?,
            replayPayloadHash: String?,
            state: ScheduleFireState,
            missionId: String?,
            traceId: String,
            failure: FixedFailure?,
            now: Date
        ) throws {
            try db.execute(
                sql: """
                    INSERT INTO schedule_fire (
                      id, scheduleId, templateId, slotKey, scheduledAt,
                      replayOfFireId, replayIdempotencyKey,
                      replayPayloadHash, state, missionId, traceId,
                      errorCode, errorMessage, createdAt, redactedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                    """,
                arguments: [
                    id,
                    scheduleId,
                    templateId,
                    slotKey,
                    normalizedSeconds(scheduledAt),
                    replayOfFireId,
                    replayIdempotencyKey,
                    replayPayloadHash,
                    state.rawValue,
                    missionId,
                    traceId,
                    failure?.code,
                    failure?.message,
                    normalizedSeconds(now),
                ]
            )
        }

        private static func insertScheduleEvent(
            _ db: Database,
            missionId: String?,
            kind: String,
            payloadJson: String,
            now: Date
        ) throws {
            _ = try AppDatabase.appendLegacyEventAndScope(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: kind,
                payloadJSON: payloadJson,
                createdAt: now
            )
        }

        private static func validateReplayCommandIdentity(
            _ command: ScheduleReplayStartCommand
        ) throws {
            guard command.originalFireId == command.payload.originalFireId,
                  isValidReplayKey(command.replayIdempotencyKey),
                  command.replayPayloadHash
                    == (try command.payload.canonicalHash())
            else {
                throw DurableWorkReplayConflictError()
            }
        }

        private static func validateReplayPayload(
            _ command: ScheduleReplayStartCommand,
            original: ScheduleFireRecord,
            actualTemplateId: String
        ) throws {
            guard command.payload.effectiveTemplateId == actualTemplateId
            else {
                throw StaleScheduleReplayPreparationError(
                    originalFireId: original.id,
                    expectedTemplateId: command.payload.effectiveTemplateId,
                    actualTemplateId: actualTemplateId
                )
            }
            let rebuilt = try ScheduleReplayPayloadV1(
                originalFire: original,
                effectiveTemplateId: actualTemplateId,
                preparation: try preparation(from: command.payload)
            )
            guard rebuilt == command.payload,
                  try rebuilt.canonicalData()
                    == command.payload.canonicalData(),
                  command.replayPayloadHash
                    == (try rebuilt.canonicalHash())
            else {
                throw DurableWorkReplayConflictError()
            }
        }

        private static func requireReplaySource(
            _ db: Database,
            originalFireId: String
        ) throws -> ScheduleFireRecord {
            guard let original = try ScheduleFireRecord.fetchOne(
                db,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: [originalFireId]
            ) else {
                throw RecordNotFoundError(
                    table: ScheduleFireRecord.databaseTableName,
                    id: originalFireId
                )
            }
            guard original.state == .failed,
                  original.replayOfFireId == nil,
                  original.replayIdempotencyKey == nil,
                  original.replayPayloadHash == nil
            else {
                throw InvalidScheduleReplaySourceError(
                    originalFireId: originalFireId
                )
            }
            _ = try validateCommittedFire(
                db,
                fire: original,
                expectedWorkIdempotencyKey: originalWorkIdempotencyKey(
                    scheduleId: original.scheduleId,
                    slotKey: original.slotKey
                ),
                planningExpectation: .original
            )
            return original
        }

        private static func validateReplayWinner(
            _ db: Database,
            fire: ScheduleFireRecord,
            command: ScheduleReplayStartCommand
        ) throws -> ScheduleFireCommitResult {
            guard fire.replayOfFireId == command.originalFireId,
                  fire.replayIdempotencyKey
                    == command.replayIdempotencyKey,
                  fire.replayPayloadHash == command.replayPayloadHash,
                  fire.scheduleId == command.payload.scheduleId,
                  fire.templateId == command.payload.effectiveTemplateId,
                  fire.slotKey == command.payload.slotKey,
                  instantBits(fire.scheduledAt)
                    == command.payload.scheduledAtInstantBits
            else {
                throw DurableWorkReplayConflictError()
            }

            let original = try requireReplaySource(
                db,
                originalFireId: command.originalFireId
            )
            try validateReplayPayload(
                command,
                original: original,
                actualTemplateId: command.payload.effectiveTemplateId
            )

            let planningExpectation: CommittedFirePlanningExpectation
            switch try preparation(from: command.payload) {
            case let .selected(runtimeProfileId, plannerModel):
                planningExpectation = .replaySelected(
                    try PlanningWorkInput(
                        plannerModel: plannerModel,
                        runtimeProfileId: runtimeProfileId
                    )
                )
            case .unavailable:
                planningExpectation = .replayUnavailable
            case .forcedFailure:
                throw DurableWorkReplayConflictError()
            }
            return try validateCommittedFire(
                db,
                fire: fire,
                expectedWorkIdempotencyKey: replayWorkIdempotencyKey(
                    command.replayIdempotencyKey
                ),
                planningExpectation: planningExpectation
            )
        }

        private static func validateCommittedFire(
            _ db: Database,
            fire: ScheduleFireRecord,
            expectedWorkIdempotencyKey: String,
            planningExpectation: CommittedFirePlanningExpectation
        ) throws -> ScheduleFireCommitResult {
            guard isNonBlank(fire.traceId) else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let events = try EventRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM event
                    WHERE kind IN (?, ?)
                      AND json_extract(payloadJson, '$.fireId') = ?
                    ORDER BY rowid
                    """,
                arguments: [
                    EventKind.scheduleFired,
                    EventKind.scheduleMissed,
                    fire.id,
                ]
            )
            guard events.count == 1 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let scheduleEvent = events[0]
            guard scheduleEvent.cardId == nil,
                  scheduleEvent.runId == nil,
                  try numericEventCreatedAtBits(
                    db,
                    eventId: scheduleEvent.id
                  ) == instantBits(fire.createdAt)
            else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }

            switch fire.state {
            case .started:
                guard let missionId = fire.missionId,
                      fire.errorCode == nil,
                      fire.errorMessage == nil,
                      scheduleEvent.kind == EventKind.scheduleFired,
                      scheduleEvent.missionId == missionId
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                let expectedPayload: String
                do {
                    expectedPayload = try canonicalString(
                        ScheduleFiredPayloadV1(
                            fireId: fire.id,
                            scheduleId: fire.scheduleId,
                            templateId: fire.templateId,
                            slotKey: fire.slotKey,
                            scheduledAt: normalizedSeconds(
                                fire.scheduledAt
                            ),
                            replayOfFireId: fire.replayOfFireId,
                            traceId: fire.traceId
                        )
                    )
                } catch is EncodingError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                guard scheduleEvent.payloadJson == expectedPayload else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }

                let works = try DurableWorkRecord.fetchAll(
                    db,
                    sql: """
                        SELECT * FROM durable_work
                        WHERE kind = 'planning'
                          AND aggregateType = 'mission'
                          AND aggregateId = ?
                        ORDER BY rowid
                        """,
                    arguments: [missionId]
                )
                guard works.count == 1 else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                let work = works[0]
                guard work.kind == .planning,
                      work.aggregateType == "mission",
                      work.aggregateId == missionId,
                      work.idempotencyKey == expectedWorkIdempotencyKey,
                      work.traceId == fire.traceId,
                      work.maxAttempts == 4
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }

                let inputBytes = Data(work.inputJson.utf8)
                let input: PlanningWorkInput
                do {
                    input = try JSONDecoder().decode(
                        PlanningWorkInput.self,
                        from: inputBytes
                    )
                } catch is DecodingError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                } catch is InvalidPlanningPayloadError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                guard try CanonicalJSONV1.encode(input) == inputBytes,
                      CanonicalJSONV1.sha256Hex(inputBytes) == work.inputHash
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                switch planningExpectation {
                case .original:
                    break
                case let .replaySelected(expectedPlanningInput):
                    guard input == expectedPlanningInput else {
                        throw ScheduleFireReplayIntegrityError(
                            fireId: fire.id
                        )
                    }
                case .replayUnavailable:
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }

                let graph: Graph
                do {
                    graph = try requirePlanningGraph(
                        db,
                        work: work,
                        requirePlanningMission: false,
                        requireUnarchivedCamp: false
                    )
                } catch is RecordNotFoundError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                } catch is InvalidDurableWorkStateError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                } catch is DecodingError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }

                let created = try EventRecord
                    .filter(
                        Column("missionId") == missionId
                            && Column("kind") == EventKind.missionCreated
                    )
                    .fetchAll(db)
                guard created.count == 1,
                      created[0].missionId == missionId,
                      created[0].cardId == nil,
                      created[0].runId == nil
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                let identityBytes = Data(created[0].payloadJson.utf8)
                let identity: MissionPlanningStartIdentityV1
                do {
                    identity = try JSONDecoder().decode(
                        MissionPlanningStartIdentityV1.self,
                        from: identityBytes
                    )
                } catch is DecodingError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                } catch is InvalidPlanningPayloadError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                guard try CanonicalJSONV1.encode(identity) == identityBytes,
                      identity.planningInput == input,
                      identity.campId == work.campId,
                      identity.campId == graph.squad.campId,
                      identity.goal == graph.mission.goalRaw,
                      identity.companionIds == graph.memberIds,
                      identity.workspacePath == graph.squad.workspacePath,
                      identity.budgetTokens == graph.mission.budgetTokens,
                      identity.autonomy == graph.mission.autonomy
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }

                let planStarted = try EventRecord
                    .filter(
                        Column("missionId") == missionId
                            && Column("kind") == EventKind.planStarted
                    )
                    .fetchAll(db)
                guard planStarted.count == 1,
                      planStarted[0].missionId == missionId,
                      planStarted[0].cardId == nil,
                      planStarted[0].runId == nil,
                      planStarted[0].payloadJson == "{}"
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                return ScheduleFireCommitResult(
                    fire: fire,
                    disposition: .replayed,
                    missionId: missionId,
                    workId: work.id
                )

            case .failed:
                guard fire.missionId == nil,
                      let errorCode = fire.errorCode,
                      let errorMessage = fire.errorMessage,
                      FixedFailure.isCanonical(
                        code: errorCode,
                        message: errorMessage
                      ),
                      scheduleEvent.kind == EventKind.scheduleMissed,
                      scheduleEvent.missionId == nil
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                let expectedPayload: String
                do {
                    expectedPayload = try canonicalString(
                        ScheduleMissedPayloadV1(
                            fireId: fire.id,
                            scheduleId: fire.scheduleId,
                            templateId: fire.templateId,
                            slotKey: fire.slotKey,
                            scheduledAt: normalizedSeconds(
                                fire.scheduledAt
                            ),
                            replayOfFireId: fire.replayOfFireId,
                            traceId: fire.traceId,
                            errorCode: errorCode,
                            errorMessage: errorMessage
                        )
                    )
                } catch is EncodingError {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                guard scheduleEvent.payloadJson == expectedPayload,
                      try DurableWorkRecord
                        .filter(
                            Column("kind")
                                == DurableWorkKind.planning.rawValue
                                && Column("idempotencyKey")
                                    == expectedWorkIdempotencyKey
                        )
                        .fetchCount(db) == 0
                else {
                    throw ScheduleFireReplayIntegrityError(fireId: fire.id)
                }
                return ScheduleFireCommitResult(
                    fire: fire,
                    disposition: .replayed,
                    missionId: nil,
                    workId: nil
                )
            }
        }

        private static func numericEventCreatedAtBits(
            _ db: Database,
            eventId: String
        ) throws -> String? {
            guard let storageType = try String.fetchOne(
                db,
                sql: "SELECT typeof(createdAt) FROM event WHERE id = ?",
                arguments: [eventId]
            ) else {
                return nil
            }
            let seconds: Double
            switch storageType {
            case "real":
                guard let value = try Double.fetchOne(
                    db,
                    sql: "SELECT createdAt FROM event WHERE id = ?",
                    arguments: [eventId]
                ) else {
                    return nil
                }
                seconds = value
            case "integer":
                guard let integer = try Int64.fetchOne(
                    db,
                    sql: "SELECT createdAt FROM event WHERE id = ?",
                    arguments: [eventId]
                ) else {
                    return nil
                }
                let value = Double(integer)
                guard Int64(exactly: value) == integer else {
                    return nil
                }
                seconds = value
            default:
                return nil
            }
            guard seconds.isFinite,
                  seconds >= -62_135_596_800,
                  seconds < 253_402_300_800
            else {
                return nil
            }
            let date = Date(timeIntervalSince1970: seconds)
            guard date.timeIntervalSince1970.bitPattern == seconds.bitPattern
            else {
                return nil
            }
            return instantBits(date)
        }

        private static func originalFire(
            _ db: Database,
            scheduleId: String,
            slotKey: String
        ) throws -> ScheduleFireRecord? {
            try ScheduleFireRecord.fetchOne(
                db,
                sql: """
                    SELECT * FROM schedule_fire
                    WHERE scheduleId = ? AND slotKey = ?
                      AND replayOfFireId IS NULL
                    """,
                arguments: [scheduleId, slotKey]
            )
        }

        private static func replayFire(
            _ db: Database,
            replayIdempotencyKey: String
        ) throws -> ScheduleFireRecord? {
            try ScheduleFireRecord.fetchOne(
                db,
                sql: """
                    SELECT * FROM schedule_fire
                    WHERE replayIdempotencyKey = ?
                    """,
                arguments: [replayIdempotencyKey]
            )
        }

        private static func requireFire(
            _ db: Database,
            id: String
        ) throws -> ScheduleFireRecord {
            guard let fire = try ScheduleFireRecord.fetchOne(
                db,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: [id]
            )
            else {
                throw RecordNotFoundError(
                    table: ScheduleFireRecord.databaseTableName,
                    id: id
                )
            }
            return fire
        }

        private static func contextIsSelfConsistent(
            _ context: ScheduleSlotContextV1
        ) throws -> Bool {
            guard context.contractVersion == 1,
                  context.calendarId == "gregorian",
                  let timeZone = TimeZone(
                      identifier: context.timeZoneId
                  )
            else {
                return false
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.timeZone = timeZone
            return try ScheduleMath.slotContext(
                for: context.scheduledAt,
                frequency: context.frequency,
                hour: context.hour,
                minute: context.minute,
                weekday: context.weekday,
                calendar: calendar,
                timeZone: timeZone
            ) == context
        }

        private static func originalWorkIdempotencyKey(
            scheduleId: String,
            slotKey: String
        ) -> String {
            "mission-start:schedule:\(scheduleId):"
                + CanonicalJSONV1.sha256Hex(Data(slotKey.utf8))
                + ":v1"
        }

        private static func replayWorkIdempotencyKey(
            _ replayKey: String
        ) -> String {
            "mission-start:schedule-replay:"
                + CanonicalJSONV1.sha256Hex(Data(replayKey.utf8))
                + ":v1"
        }

        private static func isValidReplayKey(_ value: String) -> Bool {
            let prefix = "schedule-replay:"
            guard value.hasPrefix(prefix) else { return false }
            let suffix = String(value.dropFirst(prefix.count))
            return suffix.utf8.count == 36
                && suffix == suffix.lowercased()
                && UUID(uuidString: suffix) != nil
        }

        private static func isNonBlank(_ value: String) -> Bool {
            !value.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }

        private static func normalizedSeconds(_ date: Date) -> Double {
            let seconds = date.timeIntervalSince1970
            return seconds == 0 ? 0 : seconds
        }

        private static func instantBits(_ date: Date) -> String {
            let digits = String(
                normalizedSeconds(date).bitPattern,
                radix: 16,
                uppercase: false
            )
            return String(repeating: "0", count: 16 - digits.count)
                + digits
        }
    }
}

fileprivate extension PlanningDurableWorkLedgerOwner {
    enum CandidateStartReadSnapshot {
        case replay(CandidatePlanningStartResult)
        case absent(profileSnapshot: RuntimeProfileRecord)
    }

    struct CandidateMissionDetail: Decodable, Equatable {
        let goal: String
        let why: String
        let acceptance: [String]
    }

    struct CandidateConvertedPayload: Codable, Equatable {
        let candidateId: String
        let ingestionId: String
    }

    static func candidateStartReadSnapshot(
        _ db: Database,
        command: CandidatePlanningStartCommand
    ) throws -> CandidateStartReadSnapshot {
        try requireNonBlank(command.idempotencyKey)
        _ = try requireDispatchMode(db, runningRequired: true)
        if let winner = try candidatePlanningWork(
            db,
            idempotencyKey: command.idempotencyKey
        ) {
            return .replay(
                try validateCandidateReplay(
                    db,
                    work: winner,
                    command: command
                )
            )
        }
        guard command.idempotencyKey
                == "mission-start:candidate:\(command.draft.candidateId):v1"
        else {
            throw InvalidDurableWorkStateError()
        }
        guard let profile = try RuntimeProfileRecord.fetchOne(
            db,
            key: command.planningInput.runtimeProfileId
        ), !profile.kind.isCLI else {
            throw InvalidDurableWorkStateError()
        }
        return .absent(profileSnapshot: profile)
    }

    static func convertCandidateAndEnqueuePlanning(
        _ db: Database,
        command: CandidatePlanningStartCommand,
        profileSnapshot: RuntimeProfileRecord
    ) throws -> CandidatePlanningStartResult {
        _ = try requireDispatchMode(db, runningRequired: true)
        if let winner = try candidatePlanningWork(
            db,
            idempotencyKey: command.idempotencyKey
        ) {
            return try validateCandidateReplay(
                db,
                work: winner,
                command: command
            )
        }
        guard command.idempotencyKey
                == "mission-start:candidate:\(command.draft.candidateId):v1"
        else {
            throw InvalidDurableWorkStateError()
        }
        guard profileSnapshot.id
                == command.planningInput.runtimeProfileId,
              let currentProfile = try RuntimeProfileRecord.fetchOne(
                  db,
                  key: command.planningInput.runtimeProfileId
              ),
              currentProfile.kind == profileSnapshot.kind,
              !currentProfile.kind.isCLI
        else {
            throw InvalidDurableWorkStateError()
        }

        let draft = command.draft
        guard let candidate = try ActionCandidateRecord.fetchOne(
            db,
            key: draft.candidateId
        ) else {
            throw RecordNotFoundError(
                table: ActionCandidateRecord.databaseTableName,
                id: draft.candidateId
            )
        }
        guard candidate.id == draft.candidateId else {
            throw InvalidDurableWorkStateError()
        }
        guard candidate.type == .mission else {
            throw InvalidDurableWorkStateError()
        }
        guard candidate.status == .accepted,
              candidate.missionId == nil
        else {
            throw InvalidDurableWorkStateError()
        }
        guard candidate.ingestionId == draft.ingestionId else {
            throw InvalidDurableWorkStateError()
        }
        guard let ingestion = try IngestionItemRecord.fetchOne(
            db,
            key: draft.ingestionId
        ) else {
            throw RecordNotFoundError(
                table: IngestionItemRecord.databaseTableName,
                id: draft.ingestionId
            )
        }
        guard ingestion.campId == candidate.campId else {
            throw InvalidDurableWorkStateError()
        }
        let sourceLinks = try KnowledgeSourceLinkRecord
            .filter(Column("ingestionId") == draft.ingestionId)
            .fetchAll(db)
        guard !sourceLinks.isEmpty else {
            throw RecordNotFoundError(
                table: KnowledgeSourceLinkRecord.databaseTableName,
                id: draft.ingestionId
            )
        }
        guard sourceLinks.count == 1,
              sourceLinks[0].campNoteId == draft.noteId
        else {
            throw InvalidDurableWorkStateError()
        }
        guard let note = try CampNoteRecord.fetchOne(
            db,
            key: draft.noteId
        ) else {
            throw RecordNotFoundError(
                table: CampNoteRecord.databaseTableName,
                id: draft.noteId
            )
        }
        guard note.campId == candidate.campId,
              candidate.campId == draft.campId
        else {
            throw InvalidDurableWorkStateError()
        }
        guard let camp = try CampRecord.fetchOne(
            db,
            key: draft.campId
        ) else {
            throw RecordNotFoundError(
                table: CampRecord.databaseTableName,
                id: draft.campId
            )
        }
        guard !camp.archived else {
            throw CampArchivedError(campId: camp.id)
        }
        guard let companion = try CompanionRecord.fetchOne(
            db,
            key: command.companionId
        ) else {
            throw RecordNotFoundError(
                table: CompanionRecord.databaseTableName,
                id: command.companionId
            )
        }
        guard let companionCampId = companion.campId,
              companionCampId == candidate.campId
        else {
            throw InvalidDurableWorkStateError()
        }

        try requireCandidateDetailMatches(
            candidate.detailJson,
            draft: draft
        )
        try requireNonBlank(command.traceId)

        let identity = try MissionPlanningStartIdentityV1(
            goal: command.goal,
            companionIds: [command.companionId],
            workspacePath: command.workspacePath,
            budgetTokens: command.budgetTokens,
            campId: draft.campId,
            autonomy: command.autonomy,
            planningInput: command.planningInput
        )
        let identityJson = try canonicalString(identity)
        let inputBytes = try CanonicalJSONV1.encode(
            command.planningInput
        )
        let inputJson = String(decoding: inputBytes, as: UTF8.self)
        let inputHash = CanonicalJSONV1.sha256Hex(inputBytes)
        let memberIdsJson = try canonicalString([command.companionId])
        let convertedPayload = CandidateConvertedPayload(
            candidateId: draft.candidateId,
            ingestionId: draft.ingestionId
        )
        let now = Date()
        let squadId = UUID().uuidString
        let missionId = UUID().uuidString
        let workId = UUID().uuidString

        try SquadRecord(
            id: squadId,
            campId: draft.campId,
            name: AppDatabase.truncatedFirstLine(
                command.goal,
                max: 30
            ),
            memberIdsJson: memberIdsJson,
            workspacePath: command.workspacePath,
            workspaceBookmark: WorkspaceScopedAccess.captureBookmark(
                forPath: command.workspacePath
            ),
            createdAt: now
        ).insert(db)
        try MissionRecord(
            id: missionId,
            squadId: squadId,
            goalRaw: command.goal,
            goalRefined: "",
            status: .planning,
            budgetTokens: identity.budgetTokens,
            spentTokens: 0,
            revision: 1,
            autonomy: command.autonomy,
            createdAt: now
        ).insert(db)
        _ = try AppDatabase.appendLegacyEventAndScope(
            db,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.missionCreated,
            payloadJSON: identityJson,
            createdAt: now
        )
        try insertMissionEvent(
            db,
            missionId: missionId,
            kind: EventKind.planStarted,
            payload: EmptyPayload(),
            now: now
        )
        let planningWork = DurableWorkRecord(
            id: workId,
            campId: draft.campId,
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId,
            idempotencyKey: command.idempotencyKey,
            state: .queued,
            attempt: 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: inputJson,
            inputHash: inputHash,
            outputJson: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: command.traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: nil
        )
        try DurableWorkStore.insertCurrentSchemaRecord(
            planningWork,
            in: db
        )
        var convertedCandidate = candidate
        convertedCandidate.status = .converted
        convertedCandidate.missionId = missionId
        convertedCandidate.updatedAt = now
        try convertedCandidate.update(db)
        try insertMissionEvent(
            db,
            missionId: missionId,
            kind: EventKind.actionCandidateConverted,
            payload: convertedPayload,
            now: now
        )
        return CandidatePlanningStartResult(
            missionId: missionId,
            workId: workId,
            disposition: .inserted
        )
    }

    private static func candidatePlanningWork(
        _ db: Database,
        idempotencyKey: String
    ) throws -> DurableWorkRecord? {
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(db)
    }

    private static func validateCandidateReplay(
        _ db: Database,
        work: DurableWorkRecord,
        command: CandidatePlanningStartCommand
    ) throws -> CandidatePlanningStartResult {
        do {
            guard work.kind == .planning,
                  work.aggregateType == "mission",
                  work.idempotencyKey == command.idempotencyKey,
                  work.maxAttempts == 4,
                  !work.traceId.trimmingCharacters(
                      in: .whitespacesAndNewlines
                  ).isEmpty
            else {
                throw DurableWorkReplayConflictError()
            }
            let graph = try requirePlanningGraph(
                db,
                work: work,
                requirePlanningMission: false,
                requireUnarchivedCamp: false
            )
            let inputBytes = Data(work.inputJson.utf8)
            let persistedInput = try JSONDecoder().decode(
                PlanningWorkInput.self,
                from: inputBytes
            )
            guard try CanonicalJSONV1.encode(persistedInput)
                    == inputBytes,
                  CanonicalJSONV1.sha256Hex(inputBytes)
                    == work.inputHash,
                  persistedInput == command.planningInput
            else {
                throw DurableWorkReplayConflictError()
            }

            let missionCreated = try exactCandidateStartEvent(
                db,
                missionId: graph.mission.id,
                kind: EventKind.missionCreated
            )
            let identityBytes = Data(missionCreated.payloadJson.utf8)
            let persistedIdentity = try JSONDecoder().decode(
                MissionPlanningStartIdentityV1.self,
                from: identityBytes
            )
            guard try CanonicalJSONV1.encode(persistedIdentity)
                    == identityBytes
            else {
                throw DurableWorkReplayConflictError()
            }
            let incomingIdentity = try MissionPlanningStartIdentityV1(
                goal: command.goal,
                companionIds: [command.companionId],
                workspacePath: command.workspacePath,
                budgetTokens: command.budgetTokens,
                campId: command.draft.campId,
                autonomy: command.autonomy,
                planningInput: command.planningInput
            )
            guard persistedIdentity == incomingIdentity,
                  graph.memberIds == [command.companionId],
                  graph.squad.campId == command.draft.campId,
                  graph.squad.workspacePath == command.workspacePath,
                  graph.mission.goalRaw == command.goal,
                  graph.mission.budgetTokens
                    == persistedIdentity.budgetTokens,
                  graph.mission.autonomy == command.autonomy,
                  work.campId == command.draft.campId
            else {
                throw DurableWorkReplayConflictError()
            }

            let draft = command.draft
            guard let candidate = try ActionCandidateRecord.fetchOne(
                db,
                key: draft.candidateId
            ),
                  candidate.id == draft.candidateId,
                  candidate.type == .mission,
                  candidate.status == .converted,
                  candidate.missionId == graph.mission.id,
                  candidate.ingestionId == draft.ingestionId,
                  candidate.campId == draft.campId
            else {
                throw DurableWorkReplayConflictError()
            }
            try requireCandidateDetailMatches(
                candidate.detailJson,
                draft: draft
            )
            guard let ingestion = try IngestionItemRecord.fetchOne(
                db,
                key: draft.ingestionId
            ), ingestion.campId == draft.campId else {
                throw DurableWorkReplayConflictError()
            }
            let sourceLinks = try KnowledgeSourceLinkRecord
                .filter(Column("ingestionId") == draft.ingestionId)
                .fetchAll(db)
            guard sourceLinks.count == 1,
                  sourceLinks[0].campNoteId == draft.noteId,
                  let note = try CampNoteRecord.fetchOne(
                      db,
                      key: draft.noteId
                  ),
                  note.campId == draft.campId
            else {
                throw DurableWorkReplayConflictError()
            }

            let planStarted = try exactCandidateStartEvent(
                db,
                missionId: graph.mission.id,
                kind: EventKind.planStarted
            )
            guard planStarted.payloadJson == "{}" else {
                throw DurableWorkReplayConflictError()
            }
            let converted = try exactCandidateStartEvent(
                db,
                missionId: graph.mission.id,
                kind: EventKind.actionCandidateConverted
            )
            let convertedBytes = Data(converted.payloadJson.utf8)
            let convertedPayload = try JSONDecoder().decode(
                CandidateConvertedPayload.self,
                from: convertedBytes
            )
            guard try CanonicalJSONV1.encode(convertedPayload)
                    == convertedBytes,
                  convertedPayload == CandidateConvertedPayload(
                      candidateId: draft.candidateId,
                      ingestionId: draft.ingestionId
                  )
            else {
                throw DurableWorkReplayConflictError()
            }
            return CandidatePlanningStartResult(
                missionId: graph.mission.id,
                workId: work.id,
                disposition: .replayed
            )
        } catch is DurableWorkReplayConflictError {
            throw DurableWorkReplayConflictError()
        } catch {
            throw DurableWorkReplayConflictError()
        }
    }

    private static func requireCandidateDetailMatches(
        _ detailJson: String,
        draft: CodingRanchMissionDraft
    ) throws {
        let detail = try JSONDecoder().decode(
            CandidateMissionDetail.self,
            from: Data(detailJson.utf8)
        )
        guard detail.goal == draft.goal,
              detail.acceptance == draft.acceptance,
              detail.why == draft.why
        else {
            throw InvalidDurableWorkStateError()
        }
    }

    private static func exactCandidateStartEvent(
        _ db: Database,
        missionId: String,
        kind: String
    ) throws -> EventRecord {
        let events = try EventRecord
            .filter(
                Column("missionId") == missionId
                    && Column("kind") == kind
            )
            .fetchAll(db)
        guard events.count == 1 else {
            throw DurableWorkReplayConflictError()
        }
        return events[0]
    }
}

fileprivate extension PlanningDurableWorkLedgerOwner {
    static func claimNextPlanning(
        _ db: Database,
        workerId: String,
        now: Date,
        expiration: Date
    ) throws -> DurableWorkClaim? {
        _ = try requireDispatchMode(db, runningRequired: true)
        guard let work = try DurableWorkRecord.fetchOne(
            db,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'planning'
                  AND (
                    state = 'queued'
                    OR (
                      state = 'retryScheduled'
                      AND notBefore <= ?
                    )
                  )
                ORDER BY createdAt, rowid
                LIMIT 1
                """,
            arguments: [now]
        ) else {
            return nil
        }
        _ = try requirePlanningGraph(
            db,
            work: work,
            requirePlanningMission: true,
            requireUnarchivedCamp: true
        )
        let attempt = try checkedIncrement(work.attempt)
        let version = try checkedIncrement(work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'running',
                    attempt = ?,
                    notBefore = NULL,
                    leaseOwner = ?,
                    leaseExpiresAt = ?,
                    outputJson = NULL,
                    errorCode = NULL,
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = NULL
                WHERE id = ?
                  AND version = ?
                  AND (
                    state = 'queued'
                    OR (state = 'retryScheduled' AND notBefore <= ?)
                  )
                """,
            arguments: [
                attempt,
                workerId,
                expiration,
                version,
                now,
                work.id,
                work.version,
                now,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try DurableWorkAttemptRecord(
            workId: work.id,
            attempt: attempt,
            id: UUID().uuidString,
            workerId: workerId,
            startedAt: now,
            endedAt: nil,
            outcome: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: work.traceId,
            terminalWorkVersion: nil
        ).insert(db)
        guard let persistedWork = try DurableWorkRecord.fetchOne(
            db,
            key: work.id
        ), persistedWork.state == .running,
           persistedWork.attempt == attempt,
           persistedWork.version == version,
           persistedWork.leaseOwner == workerId,
           let persistedLeaseExpiresAt = persistedWork.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let persistedClaim = DurableWorkClaim(
            workId: work.id,
            attempt: attempt,
            workerId: workerId,
            version: version,
            leaseExpiresAt: persistedLeaseExpiresAt
        )
        try insertAttemptEvent(
            db,
            claim: persistedClaim,
            sequence: 0,
            kind: .claimed,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return persistedClaim
    }

    static func nextClaimablePlanningDate(
        _ db: Database,
        now: Date
    ) throws -> Date? {
        _ = try requireDispatchMode(db, runningRequired: true)
        let workRows = try DurableWorkRecord.fetchAll(
            db,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'planning'
                  AND state IN ('queued','retryScheduled')
                ORDER BY createdAt, rowid
                """
        )
        var earliest: Date?
        for work in workRows {
            _ = try requirePlanningGraph(
                db,
                work: work,
                requirePlanningMission: true,
                requireUnarchivedCamp: false
            )
            guard let camp = try CampRecord.fetchOne(db, key: work.campId)
            else {
                throw InvalidDurableWorkStateError()
            }
            if camp.archived {
                continue
            }
            switch work.state {
            case .queued:
                return now
            case .retryScheduled:
                guard let notBefore = work.notBefore else {
                    throw InvalidDurableWorkStateError()
                }
                if notBefore <= now {
                    return now
                }
                if earliest == nil || notBefore < earliest! {
                    earliest = notBefore
                }
            default:
                throw InvalidDurableWorkStateError()
            }
        }
        return earliest
    }

    static func renewPlanningLease(
        _ db: Database,
        claim: DurableWorkClaim,
        now: Date,
        expiration: Date
    ) throws -> DurableWorkClaim {
        let graph = try requireProviderTransaction(
            db,
            claim: claim,
            now: now
        )
        let version = try checkedIncrement(graph.work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET leaseExpiresAt = ?,
                    version = ?,
                    updatedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                expiration,
                version,
                now,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        guard let persistedWork = try DurableWorkRecord.fetchOne(
            db,
            key: claim.workId
        ), persistedWork.state == .running,
           persistedWork.attempt == claim.attempt,
           persistedWork.version == version,
           persistedWork.leaseOwner == claim.workerId,
           let persistedLeaseExpiresAt = persistedWork.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let renewed = DurableWorkClaim(
            workId: claim.workId,
            attempt: claim.attempt,
            workerId: claim.workerId,
            version: version,
            leaseExpiresAt: persistedLeaseExpiresAt
        )
        try insertAttemptEvent(
            db,
            claim: renewed,
            sequence: try nextAttemptSequence(
                db,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .leaseRenewed,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return renewed
    }

    static func requireProviderTransaction(
        _ db: Database,
        claim: DurableWorkClaim,
        now: Date
    ) throws -> Graph {
        _ = try requireDispatchMode(db, runningRequired: true)
        let work = try requireWork(db, id: claim.workId)
        let graph = try requirePlanningGraph(
            db,
            work: work,
            requirePlanningMission: true,
            requireUnarchivedCamp: true
        )
        guard work.state == .running,
              work.attempt == claim.attempt,
              work.version == claim.version,
              work.leaseOwner == claim.workerId,
              work.leaseExpiresAt == claim.leaseExpiresAt,
              let leaseExpiresAt = work.leaseExpiresAt,
              leaseExpiresAt > now
        else {
            throw StaleDurableWorkClaimError()
        }
        guard let attempt = try DurableWorkAttemptRecord.fetchOne(
            db,
            key: ["workId": claim.workId, "attempt": claim.attempt]
        ), attempt.workerId == claim.workerId,
           attempt.endedAt == nil,
           attempt.outcome == nil,
           attempt.terminalWorkVersion == nil
        else {
            throw StaleDurableWorkClaimError()
        }
        return graph
    }

    static func adoptInterruptedPlanning(
        _ db: Database,
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        let running = try DurableWorkRecord.fetchAll(
            db,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'planning'
                  AND state = 'running'
                  AND leaseOwner <> ?
                ORDER BY createdAt, rowid
                """,
            arguments: [currentWorkerId]
        )
        var adopted: [DurableWorkRecord] = []
        adopted.reserveCapacity(running.count)
        for work in running {
            _ = try requirePlanningGraph(
                db,
                work: work,
                requirePlanningMission: true,
                requireUnarchivedCamp: false
            )
            guard let workerId = work.leaseOwner else {
                throw InvalidDurableWorkStateError()
            }
            let version = try checkedIncrement(work.version)
            let claim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: work.leaseExpiresAt ?? now
            )
            try db.execute(
                sql: """
                    UPDATE durable_work
                    SET state = 'queued',
                        notBefore = NULL,
                        leaseOwner = NULL,
                        leaseExpiresAt = NULL,
                        outputJson = NULL,
                        errorCode = 'worker_interrupted',
                        errorMessage = NULL,
                        version = ?,
                        updatedAt = ?,
                        finishedAt = NULL
                    WHERE id = ?
                      AND state = 'running'
                      AND version = ?
                    """,
                arguments: [version, now, work.id, work.version]
            )
            guard db.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            try closeAttempt(
                db,
                claim: claim,
                outcome: .interrupted,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                terminalVersion: version,
                now: now
            )
            try insertAttemptEvent(
                db,
                claim: DurableWorkClaim(
                    workId: work.id,
                    attempt: work.attempt,
                    workerId: workerId,
                    version: version,
                    leaseExpiresAt: work.leaseExpiresAt ?? now
                ),
                sequence: try nextAttemptSequence(
                    db,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .interrupted,
                resultingState: .queued,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                now: now
            )
            adopted.append(try requireWork(db, id: work.id))
        }
        return adopted
    }

    private static func nextAttemptSequence(
        _ db: Database,
        workId: String,
        attempt: Int
    ) throws -> Int {
        guard let maximum = try Int.fetchOne(
            db,
            sql: """
                SELECT MAX(sequence)
                FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [workId, attempt]
        ) else {
            throw InvalidDurableWorkStateError()
        }
        return try checkedIncrement(maximum)
    }

    private static func closeAttempt(
        _ db: Database,
        claim: DurableWorkClaim,
        outcome: DurableWorkAttemptOutcome,
        errorCode: String?,
        errorMessage: String?,
        terminalVersion: Int,
        now: Date
    ) throws {
        try db.execute(
            sql: """
                UPDATE durable_work_attempt
                SET endedAt = ?,
                    outcome = ?,
                    errorCode = ?,
                    errorMessage = ?,
                    terminalWorkVersion = ?
                WHERE workId = ?
                  AND attempt = ?
                  AND workerId = ?
                  AND endedAt IS NULL
                """,
            arguments: [
                now,
                outcome.rawValue,
                errorCode,
                errorMessage,
                terminalVersion,
                claim.workId,
                claim.attempt,
                claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw AttemptAlreadyClosedError()
        }
    }

    private static func insertAttemptEvent(
        _ db: Database,
        claim: DurableWorkClaim,
        sequence: Int,
        kind: DurableWorkAttemptEventKind,
        resultingState: DurableWorkState,
        errorCode: String?,
        errorMessage: String?,
        now: Date
    ) throws {
        try DurableWorkAttemptEventRecord(
            id: UUID().uuidString,
            workId: claim.workId,
            attempt: claim.attempt,
            sequence: sequence,
            eventKind: kind,
            workerId: claim.workerId,
            workVersion: claim.version,
            resultingWorkState: resultingState,
            errorCode: errorCode,
            errorMessage: errorMessage,
            occurredAt: now
        ).insert(db)
    }
}

fileprivate extension PlanningDurableWorkLedgerOwner {
    private enum SpentProjection {
        case exact(Int64)
        case overflow(PlanningUsageOverflowEvidenceV1)
    }

    static func commitPlanningSuccess(
        _ db: Database,
        claim: DurableWorkClaim,
        result: PlanResult,
        usage: PlanningUsageCountersV1,
        now: Date
    ) throws -> PlanningSuccessCommitResult {
        let graph = try requireProviderTransaction(
            db,
            claim: claim,
            now: now
        )
        guard result.fallbackReason == nil else {
            throw UnexpectedPlanningFallbackError()
        }
        let proposal: PlanProposal
        switch result.proposal.validate(rosterCount: graph.memberIds.count) {
        case let .success(validated):
            proposal = validated
        case .failure:
            throw InvalidDurableWorkStateError()
        }
        guard try CardRecord
            .filter(Column("missionId") == graph.mission.id)
            .fetchCount(db) == 0
        else {
            throw InvalidDurableWorkStateError()
        }

        switch try projectSpent(
            existingSpentTokens: graph.mission.spentTokens,
            usage: usage
        ) {
        case let .overflow(evidence):
            let bytes = try CanonicalJSONV1.encode(evidence)
            let work = try terminalizeUsageOverflow(
                db,
                graph: graph,
                claim: claim,
                evidenceBytes: bytes,
                now: now
            )
            return .usageOverflow(work: work)
        case let .exact(newSpent):
            try insertMissionEvent(
                db,
                missionId: graph.mission.id,
                kind: EventKind.planningTokens,
                payload: usage,
                now: now
            )

            let cardIds = proposal.cards.map { _ in UUID().uuidString }
            for (index, draft) in proposal.cards.enumerated() {
                let dependencyIds = draft.dependsOn.map { cardIds[$0] }
                try CardRecord(
                    id: cardIds[index],
                    missionId: graph.mission.id,
                    idemKey: "mission:\(graph.mission.id):stage-\(index + 1)",
                    title: draft.title,
                    descriptionText: draft.description,
                    expectedOutput: draft.expectedOutput,
                    assigneeId: graph.memberIds[draft.assignee],
                    status: .todo,
                    blockedReasonJson: nil,
                    dependsOnJson: try canonicalString(dependencyIds),
                    handoffJson: nil,
                    stage: index + 1,
                    maxTurns: KernelDefaults.maxTurns,
                    tokenBudget: KernelDefaults.cardTokenBudget,
                    createdAt: now
                ).insert(db)
            }

            guard let spentTokens = Int(exactly: newSpent) else {
                throw InvalidDurableWorkStateError()
            }
            var mission = graph.mission
            let previousStatus = mission.status
            mission.goalRefined = proposal.goalRefined
            mission.spentTokens = spentTokens
            mission.status = MissionStatus.rollup(
                current: mission.status,
                cards: proposal.cards.map { _ in CardStatus.todo }
            )
            try mission.update(db)
            try insertMissionEvent(
                db,
                missionId: mission.id,
                kind: EventKind.planCompleted,
                payload: PlanCompletedPayload(
                    goalRefined: proposal.goalRefined,
                    cardIds: cardIds,
                    titles: proposal.cards.map(\.title)
                ),
                now: now
            )
            if mission.status != previousStatus {
                try insertMissionEvent(
                    db,
                    missionId: mission.id,
                    kind: EventKind.missionStatusChanged,
                    payload: MissionStatusPayload(
                        from: previousStatus.rawValue,
                        to: mission.status.rawValue
                    ),
                    now: now
                )
            }

            let version = try checkedIncrement(graph.work.version)
            try db.execute(
                sql: """
                    UPDATE durable_work
                    SET state = 'succeeded',
                        notBefore = NULL,
                        leaseOwner = NULL,
                        leaseExpiresAt = NULL,
                        outputJson = NULL,
                        errorCode = NULL,
                        errorMessage = NULL,
                        version = ?,
                        updatedAt = ?,
                        finishedAt = ?
                    WHERE id = ?
                      AND state = 'running'
                      AND attempt = ?
                      AND version = ?
                      AND leaseOwner = ?
                    """,
                arguments: [
                    version,
                    now,
                    now,
                    claim.workId,
                    claim.attempt,
                    claim.version,
                    claim.workerId,
                ]
            )
            guard db.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            try closeAttempt(
                db,
                claim: claim,
                outcome: .succeeded,
                errorCode: nil,
                errorMessage: nil,
                terminalVersion: version,
                now: now
            )
            try insertAttemptEvent(
                db,
                claim: DurableWorkClaim(
                    workId: claim.workId,
                    attempt: claim.attempt,
                    workerId: claim.workerId,
                    version: version,
                    leaseExpiresAt: claim.leaseExpiresAt
                ),
                sequence: try nextAttemptSequence(
                    db,
                    workId: claim.workId,
                    attempt: claim.attempt
                ),
                kind: .succeeded,
                resultingState: .succeeded,
                errorCode: nil,
                errorMessage: nil,
                now: now
            )
            return .succeeded(work: try requireWork(db, id: claim.workId))
        }
    }

    static func recordPlanningAttemptFailure(
        _ db: Database,
        claim: DurableWorkClaim,
        failure: PlanningAttemptFailure,
        usage: PlanningUsageCountersV1?,
        now: Date
    ) throws -> PlanningFailureCommitResult {
        let graph = try requireProviderTransaction(
            db,
            claim: claim,
            now: now
        )
        var mission = graph.mission
        if let usage {
            switch try projectSpent(
                existingSpentTokens: mission.spentTokens,
                usage: usage
            ) {
            case let .overflow(evidence):
                let bytes = try CanonicalJSONV1.encode(evidence)
                let work = try terminalizeUsageOverflow(
                    db,
                    graph: graph,
                    claim: claim,
                    evidenceBytes: bytes,
                    now: now
                )
                return .usageOverflow(work: work)
            case let .exact(newSpent):
                try insertMissionEvent(
                    db,
                    missionId: mission.id,
                    kind: EventKind.planningTokens,
                    payload: usage,
                    now: now
                )
                guard let spentTokens = Int(exactly: newSpent) else {
                    throw InvalidDurableWorkStateError()
                }
                mission.spentTokens = spentTokens
            }
        }

        let shouldRetry =
            failure.failure.disposition == .transient
            && claim.attempt < graph.work.maxAttempts
        let resultingState: DurableWorkState
        let notBefore: Date?
        if shouldRetry {
            let delays: [TimeInterval] = [5, 30, 120]
            let index = claim.attempt - 1
            guard delays.indices.contains(index) else {
                throw InvalidDurableWorkStateError()
            }
            let candidate = now.addingTimeInterval(delays[index])
            guard candidate.timeIntervalSinceReferenceDate.isFinite,
                  candidate > now
            else {
                throw BackoffOverflowError()
            }
            resultingState = .retryScheduled
            notBefore = candidate
        } else {
            resultingState = .failed
            notBefore = nil
            mission.status = .failed
        }
        try mission.update(db)
        if resultingState == .failed {
            try insertMissionEvent(
                db,
                missionId: mission.id,
                kind: EventKind.missionFailed,
                payload: MissionFailurePayload(
                    reason: failure.failure.code
                ),
                now: now
            )
        }

        let version = try checkedIncrement(graph.work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = ?,
                    notBefore = ?,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = ?,
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                resultingState.rawValue,
                notBefore,
                failure.failure.code,
                failure.failure.message,
                version,
                now,
                resultingState == .failed ? now : nil,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            db,
            claim: claim,
            outcome: .failed,
            errorCode: failure.failure.code,
            errorMessage: failure.failure.message,
            terminalVersion: version,
            now: now
        )
        try insertAttemptEvent(
            db,
            claim: DurableWorkClaim(
                workId: claim.workId,
                attempt: claim.attempt,
                workerId: claim.workerId,
                version: version,
                leaseExpiresAt: claim.leaseExpiresAt
            ),
            sequence: try nextAttemptSequence(
                db,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .failed,
            resultingState: resultingState,
            errorCode: failure.failure.code,
            errorMessage: failure.failure.message,
            now: now
        )
        let work = try requireWork(db, id: claim.workId)
        if let notBefore {
            return .retryScheduled(work: work, notBefore: notBefore)
        }
        return .failed(work: work)
    }

    static func terminalizeUsageOverflow(
        _ db: Database,
        graph: Graph,
        claim: DurableWorkClaim,
        evidenceBytes: Data,
        now: Date
    ) throws -> DurableWorkRecord {
        _ = try AppDatabase.appendLegacyEventAndScope(
            db,
            missionId: graph.mission.id,
            cardId: nil,
            runId: nil,
            kind: EventKind.planningUsageOverflow,
            payloadJSON: String(decoding: evidenceBytes, as: UTF8.self),
            createdAt: now
        )
        var mission = graph.mission
        mission.status = .failed
        try mission.update(db)
        try insertMissionEvent(
            db,
            missionId: mission.id,
            kind: EventKind.missionFailed,
            payload: MissionFailurePayload(reason: "usage_overflow"),
            now: now
        )
        let version = try checkedIncrement(graph.work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'failed',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = 'usage_overflow',
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                version,
                now,
                now,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            db,
            claim: claim,
            outcome: .failed,
            errorCode: "usage_overflow",
            errorMessage: nil,
            terminalVersion: version,
            now: now
        )
        try insertAttemptEvent(
            db,
            claim: DurableWorkClaim(
                workId: claim.workId,
                attempt: claim.attempt,
                workerId: claim.workerId,
                version: version,
                leaseExpiresAt: claim.leaseExpiresAt
            ),
            sequence: try nextAttemptSequence(
                db,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .failed,
            resultingState: .failed,
            errorCode: "usage_overflow",
            errorMessage: nil,
            now: now
        )
        return try requireWork(db, id: claim.workId)
    }

    private static func projectSpent(
        existingSpentTokens: Int,
        usage: PlanningUsageCountersV1
    ) throws -> SpentProjection {
        guard existingSpentTokens >= 0,
              let existing = Int64(exactly: existingSpentTokens)
        else {
            throw InvalidDurableWorkStateError()
        }
        let (attemptBillable, attemptOverflow) =
            usage.inputTokens.addingReportingOverflow(usage.outputTokens)
        if attemptOverflow {
            return .overflow(
                .missionProjection(
                    existingSpentTokens: existing,
                    attemptUsage: usage,
                    overflowFields: [.attemptBillableTokens]
                )
            )
        }
        let (newSpent, spentOverflow) =
            existing.addingReportingOverflow(attemptBillable)
        if spentOverflow {
            return .overflow(
                .missionProjection(
                    existingSpentTokens: existing,
                    attemptUsage: usage,
                    overflowFields: [.spentTokens]
                )
            )
        }
        return .exact(newSpent)
    }
}

fileprivate extension PlanningDurableWorkLedgerOwner {
    static func cancelPlanning(
        _ db: Database,
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date
    ) throws -> DurableWorkCancelResult {
        try cancelPlanning(
            db,
            work: requireWork(db, id: workId),
            expectedVersion: expectedVersion,
            reason: reason,
            now: now
        )
    }

    private static func cancelPlanning(
        _ db: Database,
        work: DurableWorkRecord,
        expectedVersion: Int,
        reason: String,
        now: Date
    ) throws -> DurableWorkCancelResult {
        let isReplay =
            work.state == .canceled
            && work.errorCode == "work_canceled"
            && work.errorMessage == reason
        let graph = try requirePlanningGraph(
            db,
            work: work,
            requirePlanningMission: !isReplay,
            requireUnarchivedCamp: false
        )
        if isReplay {
            return .alreadyCanceled(work: work)
        }
        guard [.queued, .running, .retryScheduled].contains(work.state) else {
            throw InvalidDurableWorkStateError()
        }
        guard work.version == expectedVersion else {
            throw StaleDurableWorkClaimError()
        }
        let version = try checkedIncrement(work.version)
        try db.execute(
            sql: """
                UPDATE durable_work
                SET state = 'canceled',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = 'work_canceled',
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND version = ?
                  AND state IN ('queued','running','retryScheduled')
                """,
            arguments: [
                reason,
                version,
                now,
                now,
                work.id,
                expectedVersion,
            ]
        )
        guard db.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        if work.state == .running {
            guard let workerId = work.leaseOwner,
                  let leaseExpiresAt = work.leaseExpiresAt
            else {
                throw InvalidDurableWorkStateError()
            }
            let oldClaim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: leaseExpiresAt
            )
            try closeAttempt(
                db,
                claim: oldClaim,
                outcome: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                terminalVersion: version,
                now: now
            )
            try insertAttemptEvent(
                db,
                claim: DurableWorkClaim(
                    workId: work.id,
                    attempt: work.attempt,
                    workerId: workerId,
                    version: version,
                    leaseExpiresAt: leaseExpiresAt
                ),
                sequence: try nextAttemptSequence(
                    db,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .canceled,
                resultingState: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                now: now
            )
        }
        var mission = graph.mission
        mission.status = .failed
        try mission.update(db)
        try insertMissionEvent(
            db,
            missionId: mission.id,
            kind: EventKind.missionFailed,
            payload: MissionFailurePayload(reason: reason),
            now: now
        )
        return .canceled(work: try requireWork(db, id: work.id))
    }

    static func cancelAllPlanningForEmergencyHalt(
        _ db: Database,
        reason: String,
        now: Date
    ) throws -> [String] {
        let workRows = try DurableWorkRecord.fetchAll(
            db,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'planning'
                  AND state IN ('queued','running','retryScheduled')
                ORDER BY id
                """
        )
        var missionIds = Set<String>()
        for work in workRows {
            let graph = try requirePlanningGraph(
                db,
                work: work,
                requirePlanningMission: true,
                requireUnarchivedCamp: false
            )
            _ = try cancelPlanning(
                db,
                work: work,
                expectedVersion: work.version,
                reason: reason,
                now: now
            )
            missionIds.insert(graph.mission.id)
        }
        return missionIds.sorted()
    }
}

fileprivate extension PlanningDurableWorkLedgerOwner {
    static func repairLegacyPlanningMission(
        _ db: Database,
        missionId: String,
        profileModels: [String: String],
        now: Date
    ) throws {
        let mode = try requireDispatchMode(db, runningRequired: false)
        guard let mission = try MissionRecord.fetchOne(db, key: missionId)
        else {
            throw RecordNotFoundError(
                table: MissionRecord.databaseTableName,
                id: missionId
            )
        }
        guard mission.status == .planning else {
            return
        }
        guard let squad = try SquadRecord.fetchOne(
            db,
            key: mission.squadId
        ) else {
            throw RecordNotFoundError(
                table: SquadRecord.databaseTableName,
                id: mission.squadId
            )
        }
        guard try CampRecord.fetchOne(db, key: squad.campId) != nil else {
            throw RecordNotFoundError(
                table: CampRecord.databaseTableName,
                id: squad.campId
            )
        }
        let idempotencyKey = "legacy-planning:\(missionId):v1"
        let traceId = "legacy-planning:\(missionId):trace:v1"
        if let existing = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(db)
        {
            try validateLegacyReplay(
                work: existing,
                missionId: missionId,
                campId: squad.campId,
                traceId: traceId
            )
            if mode == .halted,
               [.queued, .running, .retryScheduled].contains(existing.state)
            {
                _ = try cancelPlanning(
                    db,
                    work: existing,
                    expectedVersion: existing.version,
                    reason: "emergency_halt_during_planning",
                    now: now
                )
            }
            return
        }
        let anyPlanningWork = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateType") == "mission"
                    && Column("aggregateId") == missionId
            )
            .fetchCount(db)
        guard anyPlanningWork == 0 else {
            return
        }

        if mode == .halted {
            let input = try LegacyPlanningTerminalInputV1(
                terminalCode: "emergency_halt_during_planning"
            )
            let work = try insertLegacyWork(
                db,
                mission: mission,
                squad: squad,
                inputBytes: CanonicalJSONV1.encode(input),
                idempotencyKey: idempotencyKey,
                traceId: traceId,
                state: .queued,
                terminalCode: nil,
                now: now
            )
            _ = try cancelPlanning(
                db,
                work: work,
                expectedVersion: work.version,
                reason: "emergency_halt_during_planning",
                now: now
            )
            return
        }

        guard try CardRecord
            .filter(Column("missionId") == missionId)
            .fetchCount(db) == 0
        else {
            throw LegacyPlanningHasCardsError()
        }
        let memberIds = try JSONDecoder().decode(
            [String].self,
            from: Data(squad.memberIdsJson.utf8)
        )
        var memberProfileIds: [String] = []
        var allMembersResolve = true
        for memberId in memberIds {
            guard let companion = try CompanionRecord.fetchOne(
                db,
                key: memberId
            ), let profileId = companion.runtimeProfileId,
               !profileId.trimmingCharacters(
                in: .whitespacesAndNewlines
               ).isEmpty
            else {
                allMembersResolve = false
                break
            }
            memberProfileIds.append(profileId)
        }
        let memberProfileSet = Set(memberProfileIds)
        let selectedProfileId: String?
        if allMembersResolve, memberProfileSet.count == 1 {
            selectedProfileId = memberProfileSet.first
        } else {
            let defaults = try RuntimeProfileRecord
                .filter(Column("isDefault") == true)
                .fetchAll(db)
            selectedProfileId = defaults.count == 1 ? defaults[0].id : nil
        }

        let terminalCode: String?
        let selectedProfile: RuntimeProfileRecord?
        if let selectedProfileId,
           let profile = try RuntimeProfileRecord.fetchOne(
               db,
               key: selectedProfileId
           )
        {
            selectedProfile = profile
            if profile.kind.isCLI {
                terminalCode =
                    "legacy_planning_profile_cli_unsupported"
            } else if let model = profileModels[profile.id],
                      !model.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty
            {
                terminalCode = nil
            } else {
                terminalCode = "legacy_planning_model_unavailable"
            }
        } else {
            selectedProfile = nil
            terminalCode = "legacy_planning_profile_unresolved"
        }

        if let terminalCode {
            let input = try LegacyPlanningTerminalInputV1(
                terminalCode: terminalCode
            )
            _ = try insertLegacyWork(
                db,
                mission: mission,
                squad: squad,
                inputBytes: CanonicalJSONV1.encode(input),
                idempotencyKey: idempotencyKey,
                traceId: traceId,
                state: .failed,
                terminalCode: terminalCode,
                now: now
            )
            var failedMission = mission
            failedMission.status = .failed
            try failedMission.update(db)
            try insertMissionEvent(
                db,
                missionId: mission.id,
                kind: EventKind.missionFailed,
                payload: MissionFailurePayload(reason: terminalCode),
                now: now
            )
            return
        }

        guard let selectedProfile,
              let model = profileModels[selectedProfile.id]
        else {
            throw InvalidDurableWorkStateError()
        }
        let input = try PlanningWorkInput(
            plannerModel: model,
            runtimeProfileId: selectedProfile.id
        )
        _ = try insertLegacyWork(
            db,
            mission: mission,
            squad: squad,
            inputBytes: CanonicalJSONV1.encode(input),
            idempotencyKey: idempotencyKey,
            traceId: traceId,
            state: .queued,
            terminalCode: nil,
            now: now
        )
    }

    private static func insertLegacyWork(
        _ db: Database,
        mission: MissionRecord,
        squad: SquadRecord,
        inputBytes: Data,
        idempotencyKey: String,
        traceId: String,
        state: DurableWorkState,
        terminalCode: String?,
        now: Date
    ) throws -> DurableWorkRecord {
        let work = DurableWorkRecord(
            id: UUID().uuidString,
            campId: squad.campId,
            kind: .planning,
            aggregateType: "mission",
            aggregateId: mission.id,
            idempotencyKey: idempotencyKey,
            state: state,
            attempt: 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: String(decoding: inputBytes, as: UTF8.self),
            inputHash: CanonicalJSONV1.sha256Hex(inputBytes),
            outputJson: nil,
            errorCode: terminalCode,
            errorMessage: nil,
            traceId: traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: state == .failed ? now : nil
        )
        try DurableWorkStore.insertCurrentSchemaRecord(work, in: db)
        return work
    }

    private static func validateLegacyReplay(
        work: DurableWorkRecord,
        missionId: String,
        campId: String,
        traceId: String
    ) throws {
        let inputBytes = Data(work.inputJson.utf8)
        guard work.kind == .planning,
              work.aggregateType == "mission",
              work.aggregateId == missionId,
              work.campId == campId,
              work.maxAttempts == 4,
              work.traceId == traceId,
              CanonicalJSONV1.sha256Hex(inputBytes) == work.inputHash
        else {
            throw DurableWorkReplayConflictError()
        }
        do {
            if let input = try? JSONDecoder().decode(
                PlanningWorkInput.self,
                from: inputBytes
            ) {
                guard try CanonicalJSONV1.encode(input) == inputBytes else {
                    throw DurableWorkReplayConflictError()
                }
                return
            }
            let terminal = try JSONDecoder().decode(
                LegacyPlanningTerminalInputV1.self,
                from: inputBytes
            )
            guard try CanonicalJSONV1.encode(terminal) == inputBytes,
                  work.attempt == 0,
                  work.notBefore == nil,
                  work.leaseOwner == nil,
                  work.leaseExpiresAt == nil,
                  work.outputJson == nil,
                  work.finishedAt != nil
            else {
                throw DurableWorkReplayConflictError()
            }
            switch terminal.terminalCode {
            case "emergency_halt_during_planning":
                guard work.state == .canceled,
                      work.errorCode == "work_canceled",
                      work.errorMessage == terminal.terminalCode
                else {
                    throw DurableWorkReplayConflictError()
                }
            case "legacy_planning_profile_unresolved",
                 "legacy_planning_model_unavailable",
                 "legacy_planning_profile_cli_unsupported":
                guard work.state == .failed,
                      work.errorCode == terminal.terminalCode,
                      work.errorMessage == nil
                else {
                    throw DurableWorkReplayConflictError()
                }
            default:
                throw DurableWorkReplayConflictError()
            }
        } catch is DurableWorkReplayConflictError {
            throw DurableWorkReplayConflictError()
        } catch {
            throw DurableWorkReplayConflictError()
        }
    }
}

package struct RuminationExecutionContext: Sendable, Equatable {
    package let claim: DurableWorkClaim
    package let ingestion: IngestionItemRecord
    package let ingestionVersion: Int
    package let lifecycleVersion: Int
    package let input: RuminationWorkInput
}

package enum RuminationFailureCommitResult: Sendable, Equatable {
    case retryScheduled(work: DurableWorkRecord, notBefore: Date)
    case failed(work: DurableWorkRecord)
}

package enum RuminationTerminalProposal: Sendable, Equatable {
    case success(RuminationProduction)
    case failure(RuminationAttemptFailure)
}

package struct RuminationDurableDispatchNotRunningError:
    Error, Sendable, Equatable
{
    package let actualMode: DispatchMode
}

extension AppDatabase {
    package func ruminationStartReplay(
        command: RuminationStartCommand
    ) throws -> DurableWorkRecord? {
        try pool.read { database in
            try RuminationDurableWorkLedgerOwner.startReplay(
                database,
                command: command
            )
        }
    }

    package func startRumination(
        command: RuminationStartCommand,
        now: Date
    ) throws -> DurableWorkEnqueueResult {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.start(
                database,
                command: command,
                now: now
            )
        }
    }

    package func claimNextSupervisedWork(
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim? {
        let expiration = try RuminationDurableWorkLedgerOwner
            .validateLease(now: now, duration: leaseDuration)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.claimNextSupervised(
                database,
                workerId: workerId,
                now: now,
                expiration: expiration
            )
        }
    }

    package func nextClaimableSupervisedWorkDate(
        now: Date
    ) throws -> Date? {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.read { database in
            try RuminationDurableWorkLedgerOwner
                .nextClaimableSupervisedDate(database, now: now)
        }
    }

    package func ruminationExecutionContext(
        claim: DurableWorkClaim,
        now: Date
    ) throws -> RuminationExecutionContext {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.read { database in
            try RuminationDurableWorkLedgerOwner.executionContext(
                database,
                claim: claim,
                now: now
            )
        }
    }

    package func validateRuminationPhaseOwnership(
        claim: DurableWorkClaim,
        ingestionId: String,
        now: Date
    ) throws {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        try pool.read { database in
            _ = try RuminationDurableWorkLedgerOwner
                .executionContext(
                    database,
                    claim: claim,
                    expectedIngestionId: ingestionId,
                    now: now
                )
        }
    }

    package func renewRuminationLease(
        claim: DurableWorkClaim,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim {
        let expiration = try RuminationDurableWorkLedgerOwner
            .validateLease(now: now, duration: leaseDuration)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.renewLease(
                database,
                claim: claim,
                now: now,
                expiration: expiration
            )
        }
    }

    package func commitRuminationSuccess(
        claim: DurableWorkClaim,
        production: RuminationProduction,
        now: Date
    ) throws -> DurableWorkRecord {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.commitSuccess(
                database,
                claim: claim,
                production: production,
                now: now
            )
        }
    }

    package func recordRuminationAttemptFailure(
        claim: DurableWorkClaim,
        failure: RuminationAttemptFailure,
        now: Date
    ) throws -> RuminationFailureCommitResult {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.recordFailure(
                database,
                claim: claim,
                failure: failure,
                now: now
            )
        }
    }

    package func cancelRumination(
        ingestionId: String,
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date
    ) throws -> DurableWorkRecord? {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        try RuminationDurableWorkLedgerOwner
            .validateCancellationReason(reason)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.cancelActive(
                database,
                ingestionId: ingestionId,
                workId: workId,
                expectedVersion: expectedVersion,
                reason: reason,
                now: now
            )
        }
    }

    package func cancelAllRuminationForEmergencyHalt(
        reason: String,
        now: Date
    ) throws -> [RuminationProjectionCommitIdentity] {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        try RuminationDurableWorkLedgerOwner
            .validateCancellationReason(reason)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.cancelAllForHalt(
                database,
                reason: reason,
                now: now
            )
        }
    }

    package func adoptInterruptedRumination(
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        return try pool.write { database in
            try RuminationDurableWorkLedgerOwner.adoptInterrupted(
                database,
                currentWorkerId: currentWorkerId,
                now: now
            )
        }
    }

    package func repairLegacyRumination(
        snapshot: LegacyRuminationStartupSnapshot,
        now: Date
    ) throws {
        try RuminationDurableWorkLedgerOwner.validateNow(now)
        let ingestionIds = try pool.read { database in
            try String.fetchAll(
                database,
                sql: """
                    SELECT id
                    FROM ingestion_item
                    WHERE status = 'ruminating'
                    ORDER BY id
                    """
            )
        }
        for ingestionId in ingestionIds {
            try pool.write { database in
                try RuminationDurableWorkLedgerOwner.repairLegacy(
                    database,
                    ingestionId: ingestionId,
                    snapshot: snapshot,
                    now: now
                )
            }
        }
    }

    package func hasActiveRuminationWork() throws -> Bool {
        try pool.read { database in
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*)
                    FROM durable_work
                    WHERE kind = 'rumination'
                      AND state IN (
                        'queued','running','retryScheduled'
                      )
                    """
            ) ?? 0 > 0
        }
    }
}

fileprivate enum RuminationDurableWorkLedgerOwner {
    private struct IngestionWriteFence {
        let version: Int
        let terminalReason: String?
        let redactedAt: Date?
    }

    private struct Graph {
        var work: DurableWorkRecord
        var ingestion: IngestionItemRecord
        let input: RuminationWorkInput
    }

    static func validateNow(_ now: Date) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteNow
        }
    }

    static func validateLease(
        now: Date,
        duration: TimeInterval
    ) throws -> Date {
        try validateNow(now)
        guard duration.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseDuration
        }
        guard duration > 0 else {
            throw InvalidDurableWorkTimeError.nonPositiveLeaseDuration
        }
        let expiration = now.addingTimeInterval(duration)
        guard expiration.timeIntervalSinceReferenceDate.isFinite else {
            throw InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
        }
        guard expiration > now else {
            throw InvalidDurableWorkTimeError
                .nonAdvancingLeaseExpiration
        }
        return expiration
    }

    static func validateCancellationReason(
        _ reason: String
    ) throws {
        guard !reason.isEmpty else {
            throw InvalidDurableWorkCancellationReasonError.empty
        }
        guard reason.unicodeScalars.count <= 1_000 else {
            throw InvalidDurableWorkCancellationReasonError.tooLong
        }
        guard !DurableWorkFailure.containsControlScalar(reason) else {
            throw InvalidDurableWorkCancellationReasonError
                .containsControlScalar
        }
    }

    private static func requireDispatchMode(
        _ database: Database,
        runningRequired: Bool
    ) throws -> DispatchMode {
        guard let control = try KernelControlRecord.fetchOne(
            database,
            key: "global"
        ) else {
            throw RecordNotFoundError(
                table: KernelControlRecord.databaseTableName,
                id: "global"
            )
        }
        if runningRequired, control.dispatchMode != .running {
            throw RuminationDurableDispatchNotRunningError(
                actualMode: control.dispatchMode
            )
        }
        return control.dispatchMode
    }

    private static func checkedIncrement(_ value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(1)
        guard !overflow else {
            throw InvalidDurableWorkStateError()
        }
        return result
    }

    private static func requireWork(
        _ database: Database,
        id: String
    ) throws -> DurableWorkRecord {
        guard let work = try DurableWorkRecord.fetchOne(
            database,
            key: id
        ) else {
            throw DurableWorkNotFoundError(workId: id)
        }
        return work
    }

    private static func requireIngestionWriteFence(
        _ database: Database,
        ingestionId: String
    ) throws -> IngestionWriteFence {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT version,terminalReason,redactedAt FROM ingestion_item WHERE id=?",
            arguments: [ingestionId]
        ) else {
            throw FeedServiceError.ingestionNotFound(ingestionId)
        }
        return IngestionWriteFence(
            version: row["version"],
            terminalReason: row["terminalReason"],
            redactedAt: row["redactedAt"]
        )
    }

    @discardableResult
    private static func requireActiveLifecycle(
        _ database: Database,
        campId: String,
        workId: String? = nil
    ) throws -> Int {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let lifecycleVersion: Int = row["version"]
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), state == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["state"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        if let workId {
            guard let storedVersion = try Int.fetchOne(
                database,
                sql: "SELECT campLifecycleVersion FROM durable_work WHERE id=?",
                arguments: [workId]
            ) else {
                throw DurableWorkNotFoundError(workId: workId)
            }
            guard storedVersion == lifecycleVersion else {
                throw CampLifecycleWriteAuthorizationError
                    .lifecycleVersionMismatch(
                        expected: storedVersion,
                        actual: lifecycleVersion
                    )
            }
        }
        return lifecycleVersion
    }

    private static func canonicalString<T: Encodable>(
        _ value: T
    ) throws -> String {
        String(
            decoding: try CanonicalJSONV1.encode(value),
            as: UTF8.self
        )
    }

    private static func decodeInput(
        _ work: DurableWorkRecord
    ) throws -> RuminationWorkInput {
        let bytes = Data(work.inputJson.utf8)
        do {
            let input = try JSONDecoder().decode(
                RuminationWorkInput.self,
                from: bytes
            )
            guard try CanonicalJSONV1.encode(input) == bytes,
                  CanonicalJSONV1.sha256Hex(bytes) == work.inputHash
            else {
                throw InvalidDurableWorkStateError()
            }
            return input
        } catch is InvalidDurableWorkStateError {
            throw InvalidDurableWorkStateError()
        } catch {
            throw InvalidDurableWorkStateError()
        }
    }

    private static func requireRuminationGraph(
        _ database: Database,
        work: DurableWorkRecord,
        requireRuminatingItem: Bool,
        requireUnarchivedCamp: Bool
    ) throws -> Graph {
        guard work.kind == .rumination,
              work.aggregateType == "ingestion",
              work.maxAttempts == 4
        else {
            throw InvalidDurableWorkStateError()
        }
        guard let ingestion = try IngestionItemRecord.fetchOne(
            database,
            key: work.aggregateId
        ) else {
            throw RecordNotFoundError(
                table: IngestionItemRecord.databaseTableName,
                id: work.aggregateId
            )
        }
        guard ingestion.campId == work.campId else {
            throw InvalidDurableWorkStateError()
        }
        if requireUnarchivedCamp {
            _ = try requireActiveLifecycle(
                database,
                campId: work.campId,
                workId: work.id
            )
        }
        if requireRuminatingItem,
           ingestion.status != .ruminating
        {
            throw StaleDurableWorkClaimError()
        }
        return Graph(
            work: work,
            ingestion: ingestion,
            input: try decodeInput(work)
        )
    }

    static func startReplay(
        _ database: Database,
        command: RuminationStartCommand
    ) throws -> DurableWorkRecord? {
        _ = try requireDispatchMode(database, runningRequired: true)
        let sameKey = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.rumination.rawValue
                    && Column("idempotencyKey")
                        == command.idempotencyKey
            )
            .fetchAll(database)
        guard sameKey.count <= 1 else {
            throw DurableWorkReplayConflictError()
        }
        if let existing = sameKey.first {
            return try validateStartReplay(
                database,
                work: existing,
                command: command
            )
        }
        let active = try activeRuminationRows(
            database,
            ingestionId: command.ingestionId
        )
        guard active.isEmpty else {
            throw DurableWorkReplayConflictError()
        }
        return nil
    }

    static func start(
        _ database: Database,
        command: RuminationStartCommand,
        now: Date
    ) throws -> DurableWorkEnqueueResult {
        _ = try requireDispatchMode(database, runningRequired: true)
        if let replay = try startReplay(database, command: command) {
            return DurableWorkEnqueueResult(
                work: replay,
                disposition: .replayed
            )
        }
        guard let profile = try RuntimeProfileRecord.fetchOne(
            database,
            key: command.input.runtimeProfileId
        ), !profile.kind.isCLI else {
            throw InvalidDurableWorkStateError()
        }
        guard let ingestion = try IngestionItemRecord.fetchOne(
            database,
            key: command.ingestionId
        ) else {
            throw FeedServiceError.ingestionNotFound(
                command.ingestionId
            )
        }
        _ = try requireActiveLifecycle(
            database,
            campId: ingestion.campId
        )
        let ingestionFence = try requireIngestionWriteFence(
            database,
            ingestionId: ingestion.id
        )
        let expectedKey =
            "rumination-start:\(ingestion.id):\(command.generation):v1"
        let (expectedGeneration, overflow) =
            command.expectedPreviousAttempt.addingReportingOverflow(1)
        guard !overflow,
              expectedGeneration == command.generation,
              command.idempotencyKey == expectedKey,
              ingestion.attempt == command.expectedPreviousAttempt,
              [.queued, .failed].contains(ingestion.status),
              ingestionFence.terminalReason == nil,
              ingestionFence.redactedAt == nil,
              try activeRuminationRows(
                  database,
                  ingestionId: ingestion.id
              ).isEmpty
        else {
            throw DurableWorkReplayConflictError()
        }

        let inputBytes = try CanonicalJSONV1.encode(command.input)
        let work = DurableWorkRecord(
            id: UUID().uuidString,
            campId: ingestion.campId,
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: ingestion.id,
            idempotencyKey: command.idempotencyKey,
            state: .queued,
            attempt: 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: String(
                decoding: inputBytes,
                as: UTF8.self
            ),
            inputHash: CanonicalJSONV1.sha256Hex(inputBytes),
            outputJson: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: command.traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: nil
        )
        try DurableWorkStore.insertCurrentSchemaRecord(work, in: database)
        let nextIngestionVersion = try checkedIncrement(
            ingestionFence.version
        )
        try database.execute(
            sql: """
                UPDATE ingestion_item
                SET status='ruminating',attempt=?,errorText=NULL,updatedAt=?,
                    version=?
                WHERE id=? AND campId=? AND version=? AND status=? AND attempt=?
                  AND terminalReason IS NULL AND redactedAt IS NULL
                """,
            arguments: [
                command.generation,
                now,
                nextIngestionVersion,
                ingestion.id,
                ingestion.campId,
                ingestionFence.version,
                ingestion.status.rawValue,
                command.expectedPreviousAttempt,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        return DurableWorkEnqueueResult(
            work: work,
            disposition: .inserted
        )
    }

    private static func validateStartReplay(
        _ database: Database,
        work: DurableWorkRecord,
        command: RuminationStartCommand
    ) throws -> DurableWorkRecord {
        do {
            let graph = try requireRuminationGraph(
                database,
                work: work,
                requireRuminatingItem: true,
                requireUnarchivedCamp: true
            )
            let active = try activeRuminationRows(
                database,
                ingestionId: command.ingestionId
            )
            guard active.count == 1,
                  active[0].id == work.id,
                  [.queued, .running, .retryScheduled]
                    .contains(work.state),
                  work.aggregateId == command.ingestionId,
                  work.idempotencyKey == command.idempotencyKey,
                  graph.input == command.input,
                  graph.ingestion.attempt == command.generation
            else {
                throw DurableWorkReplayConflictError()
            }
            return work
        } catch is DurableWorkReplayConflictError {
            throw DurableWorkReplayConflictError()
        } catch {
            throw DurableWorkReplayConflictError()
        }
    }

    private static func activeRuminationRows(
        _ database: Database,
        ingestionId: String
    ) throws -> [DurableWorkRecord] {
        try DurableWorkRecord.fetchAll(
            database,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'rumination'
                  AND aggregateType = 'ingestion'
                  AND aggregateId = ?
                  AND state IN ('queued','running','retryScheduled')
                ORDER BY createdAt, rowid
                """,
            arguments: [ingestionId]
        )
    }

    static func claimNextSupervised(
        _ database: Database,
        workerId: String,
        now: Date,
        expiration: Date
    ) throws -> DurableWorkClaim? {
        _ = try requireDispatchMode(database, runningRequired: true)
        guard let work = try DurableWorkRecord.fetchOne(
            database,
            sql: """
                SELECT durable_work.*
                FROM durable_work
                JOIN camp ON camp.id = durable_work.campId
                WHERE durable_work.kind IN ('planning','rumination')
                  AND camp.archived = 0
                  AND (
                    durable_work.state = 'queued'
                    OR (
                      durable_work.state = 'retryScheduled'
                      AND durable_work.notBefore <= ?
                    )
                  )
                ORDER BY durable_work.createdAt, durable_work.rowid
                LIMIT 1
                """,
            arguments: [now]
        ) else {
            return nil
        }
        try validateSupervisedHead(database, work: work)
        let attempt = try checkedIncrement(work.attempt)
        let version = try checkedIncrement(work.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET state = 'running',
                    attempt = ?,
                    notBefore = NULL,
                    leaseOwner = ?,
                    leaseExpiresAt = ?,
                    outputJson = NULL,
                    errorCode = NULL,
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = NULL
                WHERE id = ?
                  AND version = ?
                  AND (
                    state = 'queued'
                    OR (
                      state = 'retryScheduled'
                      AND notBefore <= ?
                    )
                  )
                """,
            arguments: [
                attempt,
                workerId,
                expiration,
                version,
                now,
                work.id,
                work.version,
                now,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try DurableWorkAttemptRecord(
            workId: work.id,
            attempt: attempt,
            id: UUID().uuidString,
            workerId: workerId,
            startedAt: now,
            endedAt: nil,
            outcome: nil,
            errorCode: nil,
            errorMessage: nil,
            traceId: work.traceId,
            terminalWorkVersion: nil
        ).insert(database)
        let persisted = try requireWork(database, id: work.id)
        guard persisted.state == .running,
              persisted.attempt == attempt,
              persisted.version == version,
              persisted.leaseOwner == workerId,
              let leaseExpiresAt = persisted.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let claim = DurableWorkClaim(
            workId: work.id,
            attempt: attempt,
            workerId: workerId,
            version: version,
            leaseExpiresAt: leaseExpiresAt
        )
        try insertAttemptEvent(
            database,
            claim: claim,
            sequence: 0,
            kind: .claimed,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return claim
    }

    static func nextClaimableSupervisedDate(
        _ database: Database,
        now: Date
    ) throws -> Date? {
        _ = try requireDispatchMode(database, runningRequired: true)
        let rows = try DurableWorkRecord.fetchAll(
            database,
            sql: """
                SELECT durable_work.*
                FROM durable_work
                JOIN camp ON camp.id = durable_work.campId
                WHERE durable_work.kind IN ('planning','rumination')
                  AND camp.archived = 0
                  AND durable_work.state IN (
                    'queued','retryScheduled'
                  )
                ORDER BY durable_work.createdAt, durable_work.rowid
                """
        )
        var earliest: Date?
        for work in rows {
            try validateSupervisedHead(database, work: work)
            switch work.state {
            case .queued:
                return now
            case .retryScheduled:
                guard let notBefore = work.notBefore else {
                    throw InvalidDurableWorkStateError()
                }
                if notBefore <= now {
                    return now
                }
                if earliest == nil || notBefore < earliest! {
                    earliest = notBefore
                }
            default:
                throw InvalidDurableWorkStateError()
            }
        }
        return earliest
    }

    private static func validateSupervisedHead(
        _ database: Database,
        work: DurableWorkRecord
    ) throws {
        switch work.kind {
        case .planning:
            guard work.aggregateType == "mission",
                  work.maxAttempts == 4,
                  let mission = try MissionRecord.fetchOne(
                      database,
                      key: work.aggregateId
                  ),
                  mission.status == .planning,
                  let squad = try SquadRecord.fetchOne(
                      database,
                      key: mission.squadId
                  ),
                  squad.campId == work.campId
            else {
                throw InvalidDurableWorkStateError()
            }
            let bytes = Data(work.inputJson.utf8)
            let input = try JSONDecoder().decode(
                PlanningWorkInput.self,
                from: bytes
            )
            guard try CanonicalJSONV1.encode(input) == bytes,
                  CanonicalJSONV1.sha256Hex(bytes) == work.inputHash
            else {
                throw InvalidDurableWorkStateError()
            }
        case .rumination:
            _ = try requireRuminationGraph(
                database,
                work: work,
                requireRuminatingItem: true,
                requireUnarchivedCamp: true
            )
        default:
            throw InvalidDurableWorkStateError()
        }
    }

    static func executionContext(
        _ database: Database,
        claim: DurableWorkClaim,
        expectedIngestionId: String? = nil,
        now: Date
    ) throws -> RuminationExecutionContext {
        _ = try requireDispatchMode(database, runningRequired: true)
        let work = try requireWork(database, id: claim.workId)
        guard work.state == .running else {
            throw StaleDurableWorkClaimError()
        }
        guard work.kind == .rumination else {
            throw InvalidDurableWorkStateError()
        }
        guard work.aggregateType == "ingestion" else {
            throw InvalidDurableWorkStateError()
        }
        if let expectedIngestionId,
           work.aggregateId != expectedIngestionId
        {
            throw InvalidDurableWorkStateError()
        }
        let lifecycleVersion = try requireActiveLifecycle(
            database,
            campId: work.campId,
            workId: work.id
        )
        guard let ingestion = try IngestionItemRecord.fetchOne(
            database,
            key: work.aggregateId
        ), ingestion.campId == work.campId else {
            throw InvalidDurableWorkStateError()
        }
        guard ingestion.status == .ruminating else {
            throw StaleDurableWorkClaimError()
        }
        let ingestionFence = try requireIngestionWriteFence(
            database,
            ingestionId: ingestion.id
        )
        guard ingestionFence.terminalReason == nil,
              ingestionFence.redactedAt == nil
        else {
            throw StaleDurableWorkClaimError()
        }
        guard work.attempt == claim.attempt else {
            throw StaleDurableWorkClaimError()
        }
        guard let attempt = try DurableWorkAttemptRecord.fetchOne(
            database,
            key: [
                "workId": claim.workId,
                "attempt": claim.attempt,
            ]
        ), attempt.workerId == claim.workerId,
           attempt.endedAt == nil,
           attempt.outcome == nil,
           attempt.terminalWorkVersion == nil
        else {
            throw StaleDurableWorkClaimError()
        }
        guard work.version == claim.version else {
            throw StaleDurableWorkClaimError()
        }
        guard work.leaseOwner == claim.workerId else {
            throw StaleDurableWorkClaimError()
        }
        guard work.leaseExpiresAt == claim.leaseExpiresAt,
              let leaseExpiresAt = work.leaseExpiresAt,
              leaseExpiresAt > now
        else {
            throw StaleDurableWorkClaimError()
        }
        return RuminationExecutionContext(
            claim: claim,
            ingestion: ingestion,
            ingestionVersion: ingestionFence.version,
            lifecycleVersion: lifecycleVersion,
            input: try decodeInput(work)
        )
    }

    static func renewLease(
        _ database: Database,
        claim: DurableWorkClaim,
        now: Date,
        expiration: Date
    ) throws -> DurableWorkClaim {
        _ = try executionContext(
            database,
            claim: claim,
            now: now
        )
        let version = try checkedIncrement(claim.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET leaseExpiresAt = ?,
                    version = ?,
                    updatedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                expiration,
                version,
                now,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        let persisted = try requireWork(database, id: claim.workId)
        guard persisted.state == .running,
              persisted.attempt == claim.attempt,
              persisted.version == version,
              persisted.leaseOwner == claim.workerId,
              let leaseExpiresAt = persisted.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }
        let renewed = DurableWorkClaim(
            workId: claim.workId,
            attempt: claim.attempt,
            workerId: claim.workerId,
            version: version,
            leaseExpiresAt: leaseExpiresAt
        )
        try insertAttemptEvent(
            database,
            claim: renewed,
            sequence: try nextAttemptSequence(
                database,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .leaseRenewed,
            resultingState: .running,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )
        return renewed
    }

    static func adoptInterrupted(
        _ database: Database,
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        let running = try DurableWorkRecord.fetchAll(
            database,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'rumination'
                  AND state = 'running'
                  AND (
                    leaseOwner IS NULL
                    OR leaseOwner <> ?
                  )
                ORDER BY createdAt, rowid
                """,
            arguments: [currentWorkerId]
        )
        var adopted: [DurableWorkRecord] = []
        for work in running {
            _ = try requireRuminationGraph(
                database,
                work: work,
                requireRuminatingItem: true,
                requireUnarchivedCamp: true
            )
            guard let workerId = work.leaseOwner,
                  let leaseExpiresAt = work.leaseExpiresAt,
                  work.attempt >= 1
            else {
                throw InvalidDurableWorkStateError()
            }
            let version = try checkedIncrement(work.version)
            try database.execute(
                sql: """
                    UPDATE durable_work
                    SET state = 'queued',
                        notBefore = NULL,
                        leaseOwner = NULL,
                        leaseExpiresAt = NULL,
                        outputJson = NULL,
                        errorCode = 'worker_interrupted',
                        errorMessage = NULL,
                        version = ?,
                        updatedAt = ?,
                        finishedAt = NULL
                    WHERE id = ?
                      AND state = 'running'
                      AND version = ?
                    """,
                arguments: [version, now, work.id, work.version]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            let claim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: leaseExpiresAt
            )
            try closeAttempt(
                database,
                claim: claim,
                outcome: .interrupted,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                terminalVersion: version,
                now: now
            )
            try insertAttemptEvent(
                database,
                claim: DurableWorkClaim(
                    workId: work.id,
                    attempt: work.attempt,
                    workerId: workerId,
                    version: version,
                    leaseExpiresAt: leaseExpiresAt
                ),
                sequence: try nextAttemptSequence(
                    database,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .interrupted,
                resultingState: .queued,
                errorCode: "worker_interrupted",
                errorMessage: nil,
                now: now
            )
            adopted.append(try requireWork(database, id: work.id))
        }
        return adopted
    }

    private struct RuminationCompletedPayload: Encodable {
        let workId: String
        let ingestionId: String
        let attempt: Int
        let pipelineVersion: String
        let traceId: String
        let usage: RuminationUsageCountersV1
    }

    private struct RuminationFailedPayload: Encodable {
        let workId: String
        let ingestionId: String
        let attempt: Int
        let traceId: String
        let code: String
        let terminal: Bool
        let usage: RuminationUsageCountersV1?

        private enum CodingKeys: String, CodingKey {
            case workId
            case ingestionId
            case attempt
            case traceId
            case code
            case terminal
            case usage
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(workId, forKey: .workId)
            try container.encode(ingestionId, forKey: .ingestionId)
            try container.encode(attempt, forKey: .attempt)
            try container.encode(traceId, forKey: .traceId)
            try container.encode(code, forKey: .code)
            try container.encode(terminal, forKey: .terminal)
            if let usage {
                try container.encode(usage, forKey: .usage)
            } else {
                try container.encodeNil(forKey: .usage)
            }
        }
    }

    static func commitSuccess(
        _ database: Database,
        claim: DurableWorkClaim,
        production: RuminationProduction,
        now: Date
    ) throws -> DurableWorkRecord {
        let context = try executionContext(
            database,
            claim: claim,
            now: now
        )
        let work = try requireWork(database, id: claim.workId)
        let version = try checkedIncrement(work.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET state = 'succeeded',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = NULL,
                    errorMessage = NULL,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                version,
                now,
                now,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            database,
            claim: claim,
            outcome: .succeeded,
            errorCode: nil,
            errorMessage: nil,
            terminalVersion: version,
            now: now
        )
        try insertAttemptEvent(
            database,
            claim: DurableWorkClaim(
                workId: claim.workId,
                attempt: claim.attempt,
                workerId: claim.workerId,
                version: version,
                leaseExpiresAt: claim.leaseExpiresAt
            ),
            sequence: try nextAttemptSequence(
                database,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .succeeded,
            resultingState: .succeeded,
            errorCode: nil,
            errorMessage: nil,
            now: now
        )

        let resultJSON = try RuminationCoding.encode(
            production.result
        )
        if let resultRow = try Row.fetchOne(
            database,
            sql: """
                SELECT id,version,materializedAt,redactedAt
                FROM rumination_result WHERE ingestionId=?
                """,
            arguments: [context.ingestion.id]
        ) {
            let resultVersion: Int = resultRow["version"]
            let materializedAt: Date? = resultRow["materializedAt"]
            let redactedAt: Date? = resultRow["redactedAt"]
            guard materializedAt == nil, redactedAt == nil else {
                throw StaleDurableWorkClaimError()
            }
            let nextResultVersion = try checkedIncrement(resultVersion)
            try database.execute(
                sql: """
                    UPDATE rumination_result
                    SET pipelineVersion=?,resultJson=?,userEditedJson=NULL,
                        materializedAt=NULL,updatedAt=?,version=?
                    WHERE id=? AND ingestionId=? AND version=?
                      AND materializedAt IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    RuminationWorkInput.pipelineVersion,
                    resultJSON,
                    now,
                    nextResultVersion,
                    resultRow["id"] as String,
                    context.ingestion.id,
                    resultVersion,
                ]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
        } else {
            try database.execute(
                sql: """
                    INSERT INTO rumination_result(
                      id,ingestionId,pipelineVersion,resultJson,userEditedJson,
                      materializedAt,createdAt,updatedAt,version,redactedAt
                    ) VALUES (?,?,?,?,NULL,NULL,?,?,1,NULL)
                    """,
                arguments: [
                    UUID().uuidString,
                    context.ingestion.id,
                    RuminationWorkInput.pipelineVersion,
                    resultJSON,
                    now,
                    now,
                ]
            )
        }

        let nextIngestionVersion = try checkedIncrement(
            context.ingestionVersion
        )
        try database.execute(
            sql: """
                UPDATE ingestion_item
                SET title=?,status='needsReview',errorText=NULL,updatedAt=?,
                    version=?
                WHERE id=? AND campId=? AND version=? AND status='ruminating'
                  AND attempt=? AND terminalReason IS NULL
                  AND redactedAt IS NULL
                """,
            arguments: [
                context.ingestion.title
                    ?? production.result.suggestedTitle,
                now,
                nextIngestionVersion,
                context.ingestion.id,
                context.ingestion.campId,
                context.ingestionVersion,
                context.ingestion.attempt,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }

        try insertDomainEvent(
            database,
            kind: EventKind.ruminationCompleted,
            payload: RuminationCompletedPayload(
                workId: work.id,
                ingestionId: context.ingestion.id,
                attempt: claim.attempt,
                pipelineVersion: RuminationWorkInput.pipelineVersion,
                traceId: work.traceId,
                usage: production.usage
            ),
            now: now
        )
        return try requireWork(database, id: claim.workId)
    }

    static func recordFailure(
        _ database: Database,
        claim: DurableWorkClaim,
        failure: RuminationAttemptFailure,
        now: Date
    ) throws -> RuminationFailureCommitResult {
        let context = try executionContext(
            database,
            claim: claim,
            now: now
        )
        let work = try requireWork(database, id: claim.workId)
        guard claim.attempt >= 1 else {
            throw InvalidDurableWorkStateError()
        }
        let shouldRetry =
            failure.failure.disposition == .transient
            && claim.attempt < 4
            && claim.attempt < work.maxAttempts
        let state: DurableWorkState
        let notBefore: Date?
        if shouldRetry {
            let delays: [TimeInterval] = [5, 30, 120]
            let index = claim.attempt - 1
            guard delays.indices.contains(index) else {
                throw InvalidDurableWorkStateError()
            }
            let candidate = now.addingTimeInterval(delays[index])
            guard candidate.timeIntervalSinceReferenceDate.isFinite,
                  candidate > now
            else {
                throw BackoffOverflowError()
            }
            state = .retryScheduled
            notBefore = candidate
        } else {
            state = .failed
            notBefore = nil
        }
        let version = try checkedIncrement(work.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET state = ?,
                    notBefore = ?,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = ?,
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND state = 'running'
                  AND attempt = ?
                  AND version = ?
                  AND leaseOwner = ?
                """,
            arguments: [
                state.rawValue,
                notBefore,
                failure.failure.code,
                failure.failure.message,
                version,
                now,
                state == .failed ? now : nil,
                claim.workId,
                claim.attempt,
                claim.version,
                claim.workerId,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        try closeAttempt(
            database,
            claim: claim,
            outcome: .failed,
            errorCode: failure.failure.code,
            errorMessage: failure.failure.message,
            terminalVersion: version,
            now: now
        )
        try insertAttemptEvent(
            database,
            claim: DurableWorkClaim(
                workId: claim.workId,
                attempt: claim.attempt,
                workerId: claim.workerId,
                version: version,
                leaseExpiresAt: claim.leaseExpiresAt
            ),
            sequence: try nextAttemptSequence(
                database,
                workId: claim.workId,
                attempt: claim.attempt
            ),
            kind: .failed,
            resultingState: state,
            errorCode: failure.failure.code,
            errorMessage: failure.failure.message,
            now: now
        )

        let nextIngestionVersion = try checkedIncrement(
            context.ingestionVersion
        )
        try database.execute(
            sql: """
                UPDATE ingestion_item
                SET status=?,errorText=?,updatedAt=?,version=?
                WHERE id=? AND campId=? AND version=? AND status='ruminating'
                  AND attempt=? AND terminalReason IS NULL
                  AND redactedAt IS NULL
                """,
            arguments: [
                state == .failed
                    ? IngestionStatus.failed.rawValue
                    : IngestionStatus.ruminating.rawValue,
                state == .failed ? failure.failure.message : nil,
                now,
                nextIngestionVersion,
                context.ingestion.id,
                context.ingestion.campId,
                context.ingestionVersion,
                context.ingestion.attempt,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }

        try insertDomainEvent(
            database,
            kind: EventKind.ruminationFailed,
            payload: RuminationFailedPayload(
                workId: work.id,
                ingestionId: context.ingestion.id,
                attempt: claim.attempt,
                traceId: work.traceId,
                code: failure.failure.code,
                terminal: state == .failed,
                usage: failure.usage
            ),
            now: now
        )
        let resulting = try requireWork(database, id: work.id)
        if let notBefore {
            return .retryScheduled(
                work: resulting,
                notBefore: notBefore
            )
        }
        return .failed(work: resulting)
    }

    static func cancelActive(
        _ database: Database,
        ingestionId: String,
        workId: String,
        expectedVersion: Int,
        reason: String,
        now: Date
    ) throws -> DurableWorkRecord? {
        guard let target = try DurableWorkRecord.fetchOne(
            database,
            key: workId
        ) else {
            return nil
        }
        guard target.kind == .rumination,
              target.aggregateType == "ingestion",
              target.aggregateId == ingestionId
        else {
            throw StaleDurableWorkClaimError()
        }
        guard target.version == expectedVersion else {
            throw StaleDurableWorkClaimError()
        }
        guard [
            DurableWorkState.queued,
            .running,
            .retryScheduled,
        ].contains(target.state)
        else {
            return nil
        }
        let active = try activeRuminationRows(
            database,
            ingestionId: ingestionId
        )
        guard active.count <= 1 else {
            throw InvalidDurableWorkStateError()
        }
        guard let work = active.first else {
            return nil
        }
        guard work.id == workId,
              work.version == expectedVersion
        else {
            throw StaleDurableWorkClaimError()
        }
        return try cancel(
            database,
            work: work,
            reason: reason,
            now: now
        )
    }

    static func cancelAllForHalt(
        _ database: Database,
        reason: String,
        now: Date
    ) throws -> [RuminationProjectionCommitIdentity] {
        guard try requireDispatchMode(
            database,
            runningRequired: false
        ) == .halted else {
            throw InvalidDurableWorkStateError()
        }
        let active = try DurableWorkRecord.fetchAll(
            database,
            sql: """
                SELECT *
                FROM durable_work
                WHERE kind = 'rumination'
                  AND state IN ('queued','running','retryScheduled')
                ORDER BY id
                """
        )
        var commits: [RuminationProjectionCommitIdentity] = []
        for work in active {
            let resulting = try cancel(
                database,
                work: work,
                reason: reason,
                now: now
            )
            commits.append(
                try projectionCommitIdentity(for: resulting)
            )
        }
        return commits
    }

    private static func cancel(
        _ database: Database,
        work: DurableWorkRecord,
        reason: String,
        now: Date
    ) throws -> DurableWorkRecord {
        guard work.kind == .rumination,
              work.aggregateType == "ingestion",
              work.maxAttempts == 4,
              let ingestion = try IngestionItemRecord.fetchOne(
                  database,
                  key: work.aggregateId
              ),
              ingestion.campId == work.campId,
              ingestion.status == .ruminating
        else {
            throw InvalidDurableWorkStateError()
        }
        _ = try requireActiveLifecycle(
            database,
            campId: work.campId,
            workId: work.id
        )
        let ingestionFence = try requireIngestionWriteFence(
            database,
            ingestionId: ingestion.id
        )
        guard ingestionFence.terminalReason == nil,
              ingestionFence.redactedAt == nil
        else {
            throw StaleDurableWorkClaimError()
        }
        try validateAnyRuminationInput(work)
        guard [.queued, .running, .retryScheduled]
            .contains(work.state)
        else {
            throw InvalidDurableWorkStateError()
        }
        let version = try checkedIncrement(work.version)
        try database.execute(
            sql: """
                UPDATE durable_work
                SET state = 'canceled',
                    notBefore = NULL,
                    leaseOwner = NULL,
                    leaseExpiresAt = NULL,
                    outputJson = NULL,
                    errorCode = 'work_canceled',
                    errorMessage = ?,
                    version = ?,
                    updatedAt = ?,
                    finishedAt = ?
                WHERE id = ?
                  AND version = ?
                  AND state IN ('queued','running','retryScheduled')
                """,
            arguments: [
                reason,
                version,
                now,
                now,
                work.id,
                work.version,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        if work.state == .running {
            guard work.attempt >= 1,
                  let workerId = work.leaseOwner,
                  let leaseExpiresAt = work.leaseExpiresAt
            else {
                throw InvalidDurableWorkStateError()
            }
            let claim = DurableWorkClaim(
                workId: work.id,
                attempt: work.attempt,
                workerId: workerId,
                version: work.version,
                leaseExpiresAt: leaseExpiresAt
            )
            try closeAttempt(
                database,
                claim: claim,
                outcome: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                terminalVersion: version,
                now: now
            )
            try insertAttemptEvent(
                database,
                claim: DurableWorkClaim(
                    workId: work.id,
                    attempt: work.attempt,
                    workerId: workerId,
                    version: version,
                    leaseExpiresAt: leaseExpiresAt
                ),
                sequence: try nextAttemptSequence(
                    database,
                    workId: work.id,
                    attempt: work.attempt
                ),
                kind: .canceled,
                resultingState: .canceled,
                errorCode: "work_canceled",
                errorMessage: reason,
                now: now
            )
        }
        let nextIngestionVersion = try checkedIncrement(
            ingestionFence.version
        )
        try database.execute(
            sql: """
                UPDATE ingestion_item
                SET status='queued',errorText=NULL,updatedAt=?,version=?
                WHERE id=? AND campId=? AND version=? AND status='ruminating'
                  AND attempt=? AND terminalReason IS NULL
                  AND redactedAt IS NULL
                """,
            arguments: [
                now,
                nextIngestionVersion,
                ingestion.id,
                ingestion.campId,
                ingestionFence.version,
                ingestion.attempt,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        return try requireWork(database, id: work.id)
    }

    private static func validateAnyRuminationInput(
        _ work: DurableWorkRecord
    ) throws {
        let bytes = Data(work.inputJson.utf8)
        guard CanonicalJSONV1.sha256Hex(bytes) == work.inputHash else {
            throw InvalidDurableWorkStateError()
        }
        do {
            guard let object = try JSONSerialization.jsonObject(
                with: bytes
            ) as? [String: Any] else {
                throw InvalidDurableWorkStateError()
            }
            switch Set(object.keys) {
            case Set([
                "model",
                "runtimeProfileId",
                "pipelineVersion",
            ]):
                let input = try JSONDecoder().decode(
                    RuminationWorkInput.self,
                    from: bytes
                )
                guard try CanonicalJSONV1.encode(input) == bytes else {
                    throw InvalidDurableWorkStateError()
                }
            case Set(["contractVersion", "terminalCode"]):
                let input = try JSONDecoder().decode(
                    LegacyRuminationTerminalInputV1.self,
                    from: bytes
                )
                guard try CanonicalJSONV1.encode(input) == bytes else {
                    throw InvalidDurableWorkStateError()
                }
            default:
                throw InvalidDurableWorkStateError()
            }
        } catch is InvalidDurableWorkStateError {
            throw InvalidDurableWorkStateError()
        } catch {
            throw InvalidDurableWorkStateError()
        }
    }

    private static func projectionCommitIdentity(
        for work: DurableWorkRecord
    ) throws -> RuminationProjectionCommitIdentity {
        try RuminationProjectionCommitIdentity(
            phaseIdentity: RuminationPhaseIdentity(
                ingestionId: work.aggregateId,
                workId: work.id,
                attempt: work.attempt
            ),
            workVersion: work.version
        )
    }

    static func repairLegacy(
        _ database: Database,
        ingestionId: String,
        snapshot: LegacyRuminationStartupSnapshot,
        now: Date
    ) throws {
        guard let ingestion = try IngestionItemRecord.fetchOne(
            database,
            key: ingestionId
        ) else {
            throw FeedServiceError.ingestionNotFound(ingestionId)
        }
        guard ingestion.status == .ruminating else {
            return
        }
        _ = try requireActiveLifecycle(
            database,
            campId: ingestion.campId
        )
        let ingestionFence = try requireIngestionWriteFence(
            database,
            ingestionId: ingestion.id
        )
        guard ingestionFence.terminalReason == nil,
              ingestionFence.redactedAt == nil
        else {
            throw StaleDurableWorkClaimError()
        }
        let historyCount = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.rumination.rawValue
                    && Column("aggregateType") == "ingestion"
                    && Column("aggregateId") == ingestion.id
            )
            .fetchCount(database)
        guard historyCount == 0 else {
            return
        }
        let mode = try requireDispatchMode(
            database,
            runningRequired: false
        )
        let key = "legacy-rumination:\(ingestion.id)"
        let trace = "legacy-rumination:\(ingestion.id):trace:v1"

        if mode == .halted {
            let input = try LegacyRuminationTerminalInputV1(
                terminalCode: "emergency_halt_during_rumination"
            )
            let work = try insertLegacyWork(
                database,
                ingestion: ingestion,
                inputBytes: CanonicalJSONV1.encode(input),
                idempotencyKey: key,
                traceId: trace,
                state: .queued,
                terminalCode: nil,
                now: now
            )
            _ = try cancel(
                database,
                work: work,
                reason: "emergency_halt_during_rumination",
                now: now
            )
            return
        }

        let terminal: (code: String, message: String)?
        let inputBytes: Data
        switch snapshot {
        case let .valid(runtimeProfileId, model):
            inputBytes = try CanonicalJSONV1.encode(
                RuminationWorkInput(
                    model: model,
                    runtimeProfileId: runtimeProfileId
                )
            )
            terminal = nil
        case .legacyProfileUnresolved:
            terminal = (
                "legacy_rumination_profile_unresolved",
                "旧反刍任务缺少可恢复的运行配置。"
            )
            inputBytes = try CanonicalJSONV1.encode(
                LegacyRuminationTerminalInputV1(
                    terminalCode: terminal!.code
                )
            )
        case .legacyModelUnavailable:
            terminal = (
                "legacy_rumination_model_unavailable",
                "旧反刍任务缺少可恢复的模型。"
            )
            inputBytes = try CanonicalJSONV1.encode(
                LegacyRuminationTerminalInputV1(
                    terminalCode: terminal!.code
                )
            )
        case .legacyProfileCLIUnsupported:
            terminal = (
                "legacy_rumination_profile_cli_unsupported",
                "旧反刍任务的 CLI 运行配置不受支持。"
            )
            inputBytes = try CanonicalJSONV1.encode(
                LegacyRuminationTerminalInputV1(
                    terminalCode: terminal!.code
                )
            )
        }
        let work = try insertLegacyWork(
            database,
            ingestion: ingestion,
            inputBytes: inputBytes,
            idempotencyKey: key,
            traceId: trace,
            state: terminal == nil ? .queued : .failed,
            terminalCode: terminal?.code,
            now: now
        )
        let nextIngestionVersion = try checkedIncrement(
            ingestionFence.version
        )
        try database.execute(
            sql: """
                UPDATE ingestion_item
                SET errorText=?,status=?,updatedAt=?,version=?
                WHERE id=? AND campId=? AND version=? AND status='ruminating'
                  AND terminalReason IS NULL AND redactedAt IS NULL
                """,
            arguments: [
                terminal?.message,
                terminal == nil
                    ? IngestionStatus.ruminating.rawValue
                    : IngestionStatus.failed.rawValue,
                now,
                nextIngestionVersion,
                ingestion.id,
                ingestion.campId,
                ingestionFence.version,
            ]
        )
        guard database.changesCount == 1 else {
            throw StaleDurableWorkClaimError()
        }
        if let terminal {
            try insertDomainEvent(
                database,
                kind: EventKind.ruminationFailed,
                payload: RuminationFailedPayload(
                    workId: work.id,
                    ingestionId: ingestion.id,
                    attempt: 0,
                    traceId: work.traceId,
                    code: terminal.code,
                    terminal: true,
                    usage: nil
                ),
                now: now
            )
        }
    }

    private static func insertLegacyWork(
        _ database: Database,
        ingestion: IngestionItemRecord,
        inputBytes: Data,
        idempotencyKey: String,
        traceId: String,
        state: DurableWorkState,
        terminalCode: String?,
        now: Date
    ) throws -> DurableWorkRecord {
        let work = DurableWorkRecord(
            id: UUID().uuidString,
            campId: ingestion.campId,
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: ingestion.id,
            idempotencyKey: idempotencyKey,
            state: state,
            attempt: 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: nil,
            leaseExpiresAt: nil,
            inputJson: String(
                decoding: inputBytes,
                as: UTF8.self
            ),
            inputHash: CanonicalJSONV1.sha256Hex(inputBytes),
            outputJson: nil,
            errorCode: terminalCode,
            errorMessage: nil,
            traceId: traceId,
            version: 1,
            createdAt: now,
            updatedAt: now,
            finishedAt: state == .failed ? now : nil
        )
        try DurableWorkStore.insertCurrentSchemaRecord(work, in: database)
        return work
    }

    private static func insertDomainEvent<T: Encodable>(
        _ database: Database,
        kind: String,
        payload: T,
        now: Date
    ) throws {
        _ = try AppDatabase.appendLegacyEventAndScope(
            database,
            missionId: nil,
            cardId: nil,
            runId: nil,
            kind: kind,
            payloadJSON: try canonicalString(payload),
            createdAt: now
        )
    }

    private static func nextAttemptSequence(
        _ database: Database,
        workId: String,
        attempt: Int
    ) throws -> Int {
        guard let maximum = try Int.fetchOne(
            database,
            sql: """
                SELECT MAX(sequence)
                FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [workId, attempt]
        ) else {
            throw InvalidDurableWorkStateError()
        }
        return try checkedIncrement(maximum)
    }

    private static func closeAttempt(
        _ database: Database,
        claim: DurableWorkClaim,
        outcome: DurableWorkAttemptOutcome,
        errorCode: String?,
        errorMessage: String?,
        terminalVersion: Int,
        now: Date
    ) throws {
        try database.execute(
            sql: """
                UPDATE durable_work_attempt
                SET endedAt = ?,
                    outcome = ?,
                    errorCode = ?,
                    errorMessage = ?,
                    terminalWorkVersion = ?
                WHERE workId = ?
                  AND attempt = ?
                  AND workerId = ?
                  AND endedAt IS NULL
                """,
            arguments: [
                now,
                outcome.rawValue,
                errorCode,
                errorMessage,
                terminalVersion,
                claim.workId,
                claim.attempt,
                claim.workerId,
            ]
        )
        guard database.changesCount == 1 else {
            throw AttemptAlreadyClosedError()
        }
    }

    private static func insertAttemptEvent(
        _ database: Database,
        claim: DurableWorkClaim,
        sequence: Int,
        kind: DurableWorkAttemptEventKind,
        resultingState: DurableWorkState,
        errorCode: String?,
        errorMessage: String?,
        now: Date
    ) throws {
        try DurableWorkAttemptEventRecord(
            id: UUID().uuidString,
            workId: claim.workId,
            attempt: claim.attempt,
            sequence: sequence,
            eventKind: kind,
            workerId: claim.workerId,
            workVersion: claim.version,
            resultingWorkState: resultingState,
            errorCode: errorCode,
            errorMessage: errorMessage,
            occurredAt: now
        ).insert(database)
    }
}

private extension DurableWorkFailure {
    static func isValidErrorCodeHash(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
    }
}
// P1-C-BEGIN ExpiredControlWorkAdoption
extension DurableWorkStore {
    package func adoptExpiredControlWork(
        kind: DurableWorkKind,
        currentWorkerId: String,
        now: Date
    ) throws -> [DurableWorkRecord] {
        guard kind == .inputParsing || kind == .coach else {
            throw InvalidDurableWorkStateError()
        }
        try CanonicalContractCodingV1.validateNonempty(currentWorkerId)
        try Self.validateNow(now)
        return try database.pool.write { db in
            let running = try DurableWorkRecord.fetchAll(
                db,
                sql: """
                    SELECT *
                    FROM durable_work
                    WHERE kind = ?
                      AND state = 'running'
                      AND leaseExpiresAt IS NOT NULL
                      AND leaseExpiresAt <= ?
                    ORDER BY createdAt, rowid
                    """,
                arguments: [kind.rawValue, now]
            )
            var adopted: [DurableWorkRecord] = []
            adopted.reserveCapacity(running.count)
            for work in running {
                guard work.kind == kind,
                      work.state == .running,
                      work.attempt > 0,
                      work.version > 0,
                      let workerId = work.leaseOwner,
                      let leaseExpiresAt = work.leaseExpiresAt,
                      leaseExpiresAt.timeIntervalSinceReferenceDate.isFinite,
                      leaseExpiresAt <= now
                else {
                    throw InvalidDurableWorkStateError()
                }
                let version = try Self.checkedIncrement(work.version)
                try db.execute(
                    sql: """
                        UPDATE durable_work
                        SET state = 'queued',
                            notBefore = NULL,
                            leaseOwner = NULL,
                            leaseExpiresAt = NULL,
                            outputJson = NULL,
                            errorCode = 'worker_interrupted',
                            errorMessage = NULL,
                            version = ?,
                            updatedAt = ?,
                            finishedAt = NULL
                        WHERE id = ?
                          AND kind = ?
                          AND state = 'running'
                          AND version = ?
                          AND leaseExpiresAt = ?
                        """,
                    arguments: [
                        version, now, work.id, kind.rawValue,
                        work.version, leaseExpiresAt,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw StaleDurableWorkClaimError()
                }
                let claim = DurableWorkClaim(
                    workId: work.id,
                    attempt: work.attempt,
                    workerId: workerId,
                    version: work.version,
                    leaseExpiresAt: leaseExpiresAt
                )
                try Self.closeAttempt(
                    db,
                    claim: claim,
                    outcome: .interrupted,
                    errorCode: "worker_interrupted",
                    errorMessage: nil,
                    terminalVersion: version,
                    now: now
                )
                try Self.insertEvent(
                    db,
                    workId: work.id,
                    attempt: work.attempt,
                    sequence: try Self.nextSequence(
                        db,
                        workId: work.id,
                        attempt: work.attempt
                    ),
                    kind: .interrupted,
                    workerId: workerId,
                    workVersion: version,
                    resultingState: .queued,
                    errorCode: "worker_interrupted",
                    errorMessage: nil,
                    now: now
                )
                adopted.append(try Self.requireWork(db, id: work.id))
            }
            return adopted
        }
    }
}
// P1-C-END ExpiredControlWorkAdoption
