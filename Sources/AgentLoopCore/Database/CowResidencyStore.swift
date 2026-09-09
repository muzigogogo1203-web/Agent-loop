import Foundation
import GRDB

package struct CowResidencyStore: Sendable {
    private let database: AppDatabase
    private let eventStore: DomainEventStore
    private let lifecycleStore: CampLifecycleStore

    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.database = database
        eventStore = DomainEventStore(database: database, clock: clock)
        lifecycleStore = CampLifecycleStore(database: database)
    }

    package func synchronizeCompanion(
        _ companion: CompanionRecord,
        provisionActiveResidency: Bool
    ) throws -> CowIdentitySnapshotV1 {
        try database.pool.write { db in
            try Self.synchronizeCompanion(
                companion,
                provisionActiveResidency: provisionActiveResidency,
                database: db
            )
        }
    }

    package static func synchronizeCompanion(
        _ companion: CompanionRecord,
        provisionActiveResidency: Bool,
        database db: Database
    ) throws -> CowIdentitySnapshotV1 {
        guard try CompanionRecord.fetchOne(db, key: companion.id) != nil else {
            throw RecordNotFoundError(table: "companion", id: companion.id)
        }
        let existing = try cowIdentity(cowId: companion.id, database: db)
        if let existing {
            let changed = existing.displayName != companion.name
                || existing.appearanceRef != companion.color
                || existing.personality != companion.rolePrompt
                || existing.baseRole != companion.kind.rawValue
            if changed {
                let nextVersion = try CanonicalContractCodingV1
                    .checkedIncrement(existing.aggregateVersion)
                try db.execute(
                    sql: """
                        UPDATE cow_identity
                        SET displayName=?,appearanceRef=?,personality=?,baseRole=?,
                            aggregateVersion=?,updatedAt=?
                        WHERE id=? AND aggregateVersion=?
                        """,
                    arguments: [
                        companion.name, companion.color, companion.rolePrompt,
                        companion.kind.rawValue, nextVersion, companion.createdAt,
                        companion.id, existing.aggregateVersion,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw CampResidencyReferenceMismatchError()
                }
            }
        } else {
            try db.execute(
                sql: """
                    INSERT INTO cow_identity(
                      id,displayName,appearanceRef,personality,baseRole,
                      defaultEnginePolicyJson,status,aggregateVersion,
                      createdAt,updatedAt
                    ) VALUES (?,?,?,?,?,'{}','active',1,?,?)
                    """,
                arguments: [
                    companion.id, companion.name, companion.color,
                    companion.rolePrompt, companion.kind.rawValue,
                    companion.createdAt, companion.createdAt,
                ]
            )
        }

        if provisionActiveResidency, let campId = companion.campId {
            guard let lifecycleRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT l.state,l.version,c.archived
                    FROM camp_lifecycle l JOIN camp c ON c.id=l.campId
                    WHERE l.campId=?
                    """,
                arguments: [campId]
            ), lifecycleRow["state"] as String == "active",
               lifecycleRow["archived"] as Int == 0
            else {
                throw CampLifecycleWriteAuthorizationError.missing
            }
            let liveCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM camp_residency
                    WHERE cowId=? AND campId=?
                      AND status IN ('requested','authorized','active','paused')
                    """,
                arguments: [companion.id, campId]
            ) ?? 0
            if liveCount == 0 {
                let historyCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM camp_residency
                        WHERE cowId=? AND campId=?
                    """,
                    arguments: [companion.id, campId]
                ) ?? 0
                guard historyCount == 0 else {
                    throw InvalidCampResidencyTransitionError()
                }
                try db.execute(
                    sql: """
                        INSERT INTO camp_residency(
                          id,cowId,campId,role,status,idempotencyKey,joinedAt,
                          pausedAt,leftAt,revokedAt,aggregateVersion,
                          createdAt,updatedAt
                        ) VALUES (?,?,?,?, 'active',?,?,NULL,NULL,NULL,1,?,?)
                        """,
                    arguments: [
                        "companion-residency:\(companion.id):\(campId)",
                        companion.id, campId, companion.kind.rawValue,
                        "companion:\(companion.id):\(campId)",
                        companion.createdAt, companion.createdAt,
                        companion.createdAt,
                    ]
                )
            }
        }
        guard let result = try cowIdentity(
            cowId: companion.id,
            database: db
        ) else {
            throw CampResidencyReferenceMismatchError()
        }
        return result
    }

    package func request(
        _ command: RequestCampResidencyCommandV1
    ) throws -> CampResidencySnapshotV1 {
        try Self.validateMutationActor(command.envelope)
        let payload = RequestPayload(
            residencyId: command.residencyId,
            cowId: command.cowId,
            campId: command.campId,
            role: command.role,
            expectedCampLifecycleVersion:
                command.expectedCampLifecycleVersion
        )
        let prepared = try P1DPreparedCommandV1.make(
            commandType: "camp-residency.request.v1",
            envelope: command.envelope,
            payload: payload,
            events: []
        )
        return try database.pool.write { db in
            try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: command.campId,
                        expectedLifecycleVersion:
                            command.expectedCampLifecycleVersion,
                        database: transaction
                    )
                    guard let cow = try Self.cowIdentity(
                        cowId: command.cowId,
                        database: transaction
                    ), cow.status == .active else {
                        throw ResidencyAuthorizationError.missing
                    }
                    guard try Self.residency(
                        id: command.residencyId,
                        database: transaction
                    ) == nil else {
                        throw CampResidencyReferenceMismatchError()
                    }
                    let live = try Int.fetchOne(
                        transaction,
                        sql: """
                            SELECT COUNT(*) FROM camp_residency
                            WHERE cowId=? AND campId=? AND status IN
                              ('requested','authorized','active','paused')
                            """,
                        arguments: [command.cowId, command.campId]
                    ) ?? 0
                    guard live == 0 else {
                        throw InvalidCampResidencyTransitionError()
                    }
                    return try CampResidencySnapshotV1(
                        id: command.residencyId,
                        cowId: command.cowId,
                        campId: command.campId,
                        role: command.role,
                        status: .requested,
                        idempotencyKey: command.envelope.idempotencyKey,
                        joinedAt: nil,
                        pausedAt: nil,
                        leftAt: nil,
                        revokedAt: nil,
                        aggregateVersion: 1,
                        createdAt: command.envelope.occurredAt,
                        updatedAt: command.envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    try Self.insert(result, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    guard try Self.residency(
                        id: result.id,
                        database: transaction
                    ) == result else {
                        throw CampResidencyReferenceMismatchError()
                    }
                }
            )
        }
    }

    package func transition(
        _ command: ChangeCampResidencyCommandV1
    ) throws -> CampResidencySnapshotV1 {
        try Self.validateMutationActor(command.envelope)
        let payload = TransitionPayload(
            residencyId: command.residencyId,
            expectedAggregateVersion: command.expectedAggregateVersion,
            transition: command.transition,
            expectedCampLifecycleVersion:
                command.expectedCampLifecycleVersion
        )
        let prepared = try P1DPreparedCommandV1.make(
            commandType: "camp-residency.transition.v1",
            envelope: command.envelope,
            payload: payload,
            events: []
        )
        return try database.pool.write { db in
            try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    guard let current = try Self.residency(
                        id: command.residencyId,
                        database: transaction
                    ), current.aggregateVersion
                        == command.expectedAggregateVersion
                    else {
                        throw CampResidencyReferenceMismatchError()
                    }
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: current.campId,
                        expectedLifecycleVersion:
                            command.expectedCampLifecycleVersion,
                        database: transaction
                    )
                    return try Self.reduced(
                        current,
                        transition: command.transition,
                        at: command.envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    try transaction.execute(
                        sql: """
                            UPDATE camp_residency
                            SET status=?,joinedAt=?,pausedAt=?,leftAt=?,
                                revokedAt=?,aggregateVersion=?,updatedAt=?
                            WHERE id=? AND aggregateVersion=?
                            """,
                        arguments: [
                            result.status.rawValue, result.joinedAt,
                            result.pausedAt, result.leftAt, result.revokedAt,
                            result.aggregateVersion, result.updatedAt,
                            result.id, command.expectedAggregateVersion,
                        ]
                    )
                    guard transaction.changesCount == 1 else {
                        throw CampResidencyReferenceMismatchError()
                    }
                },
                validateProjection: { transaction, _, result in
                    guard try Self.residency(
                        id: result.id,
                        database: transaction
                    ) == result else {
                        throw CampResidencyReferenceMismatchError()
                    }
                }
            )
        }
    }

    package func requireActiveResidency(
        cowId: String,
        campId: String
    ) throws -> CampResidencySnapshotV1 {
        try CanonicalContractCodingV1.validateNonempty(cowId)
        try CanonicalContractCodingV1.validateCampID(campId)
        return try database.pool.read { db in
            try Self.requireActiveResidency(
                cowId: cowId,
                campId: campId,
                database: db
            )
        }
    }

    package static func requireActiveResidency(
        cowId: String,
        campId: String,
        database: Database
    ) throws -> CampResidencySnapshotV1 {
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT * FROM camp_residency
                WHERE cowId=? AND campId=?
                ORDER BY createdAt DESC,rowid DESC
                """,
            arguments: [cowId, campId]
        )
        guard let row = rows.first else {
            throw ResidencyAuthorizationError.missing
        }
        let result = try residency(row: row)
        guard result.status == .active else {
            throw ResidencyAuthorizationError.inactive(result.status)
        }
        return result
    }

    package func residentCows(
        campId: String
    ) throws -> [CowIdentitySnapshotV1] {
        try CanonicalContractCodingV1.validateCampID(campId)
        return try database.pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT c.* FROM cow_identity c
                    JOIN camp_residency r ON r.cowId=c.id
                    WHERE r.campId=? AND r.status='active'
                      AND c.status='active'
                    ORDER BY c.id
                    """,
                arguments: [campId]
            )
            return try rows.map(Self.cowIdentity(row:))
        }
    }

    package func retireCow(
        cowId: String,
        at: Date = Date()
    ) throws -> CowRetirementReceiptV1 {
        try CanonicalContractCodingV1.validateNonempty(cowId)
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.write { db in
            guard let companion = try CompanionRecord.fetchOne(
                db,
                key: cowId
            ) else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: cowId
                )
            }
            guard companion.kind == .regular else {
                throw CowRetirementBlockedError.unsupportedCompanionKind
            }
            guard cowId != CowTemplate.baseCowId,
                  cowId != CowTemplate.testCowId
            else {
                throw CowRetirementBlockedError.protectedCow
            }
            guard let current = try Self.cowIdentity(
                cowId: cowId,
                database: db
            ) else {
                throw CampResidencyReferenceMismatchError()
            }

            let liveResidencies = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM camp_residency
                    WHERE cowId=? AND status IN (
                      'requested','authorized','active','paused'
                    )
                    ORDER BY id
                    """,
                arguments: [cowId]
            ).map(Self.residency(row:))
            if current.status == .retired {
                guard liveResidencies.isEmpty else {
                    throw CampResidencyReferenceMismatchError()
                }
                return CowRetirementReceiptV1(
                    identity: current,
                    revokedResidencyIds: []
                )
            }

            let activeMissionSquads = try Row.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT s.memberIdsJson
                    FROM squad s
                    JOIN mission m ON m.squadId = s.id
                    WHERE m.status IN (
                      'planning','executing','delivering'
                    )
                    """
            )
            for row in activeMissionSquads {
                let raw: String = row["memberIdsJson"]
                let memberIds = try JSONDecoder().decode(
                    [String].self,
                    from: Data(raw.utf8)
                )
                if memberIds.contains(cowId) {
                    throw CowRetirementBlockedError.activeMission
                }
            }
            let assignedActiveCardCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*)
                    FROM card c
                    JOIN mission m ON m.id = c.missionId
                    WHERE c.assigneeId = ?
                      AND m.status IN (
                        'planning','executing','delivering'
                      )
                    """,
                arguments: [cowId]
            ) ?? 0
            guard assignedActiveCardCount == 0 else {
                throw CowRetirementBlockedError.activeMission
            }

            let enabledTemplateRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT t.companionIdsJson
                    FROM mission_template t
                    JOIN schedule s ON s.templateId = t.id
                    WHERE s.enabled = 1
                    """
            )
            for row in enabledTemplateRows {
                let raw: String = row["companionIdsJson"]
                let companionIds = try JSONDecoder().decode(
                    [String].self,
                    from: Data(raw.utf8)
                )
                if companionIds.contains(cowId) {
                    throw CowRetirementBlockedError.enabledSchedule
                }
            }

            guard !liveResidencies.contains(where: {
                $0.status == .requested || $0.status == .authorized
            }) else {
                throw CowRetirementBlockedError.pendingResidency
            }
            guard at >= current.updatedAt,
                  liveResidencies.allSatisfy({ at >= $0.updatedAt })
            else {
                throw P1ContractValidationError.invalidTime
            }

            var revokedResidencyIds: [String] = []
            for residency in liveResidencies {
                let revoked = try Self.reduced(
                    residency,
                    transition: .revoke,
                    at: at
                )
                try db.execute(
                    sql: """
                        UPDATE camp_residency
                        SET status=?,joinedAt=?,pausedAt=?,leftAt=?,
                            revokedAt=?,aggregateVersion=?,updatedAt=?
                        WHERE id=? AND aggregateVersion=?
                        """,
                    arguments: [
                        revoked.status.rawValue, revoked.joinedAt,
                        revoked.pausedAt, revoked.leftAt,
                        revoked.revokedAt, revoked.aggregateVersion,
                        revoked.updatedAt, revoked.id,
                        residency.aggregateVersion,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw CampResidencyReferenceMismatchError()
                }
                revokedResidencyIds.append(revoked.id)
            }

            let retired = try CowIdentitySnapshotV1(
                id: current.id,
                displayName: current.displayName,
                appearanceRef: current.appearanceRef,
                personality: current.personality,
                baseRole: current.baseRole,
                defaultEnginePolicyJson:
                    current.defaultEnginePolicyJson,
                status: .retired,
                aggregateVersion: try CanonicalContractCodingV1
                    .checkedIncrement(current.aggregateVersion),
                createdAt: current.createdAt,
                updatedAt: at
            )
            try db.execute(
                sql: """
                    UPDATE cow_identity
                    SET status='retired',aggregateVersion=?,updatedAt=?
                    WHERE id=? AND status='active' AND aggregateVersion=?
                    """,
                arguments: [
                    retired.aggregateVersion, retired.updatedAt,
                    retired.id, current.aggregateVersion,
                ]
            )
            guard db.changesCount == 1,
                  let persisted = try Self.cowIdentity(
                      cowId: cowId,
                      database: db
                  ),
                  persisted.status == .retired,
                  persisted.aggregateVersion == retired.aggregateVersion
            else {
                throw CampResidencyReferenceMismatchError()
            }
            return CowRetirementReceiptV1(
                identity: persisted,
                revokedResidencyIds: revokedResidencyIds
            )
        }
    }

    package func createBridge(
        _ command: CreateCampBridgeCommandV1
    ) throws -> CampBridgeSnapshotV1 {
        try Self.validateMutationActor(command.envelope)
        let payload = CreateBridgePayload(
            bridgeId: command.bridgeId,
            sourceCampId: command.sourceCampId,
            targetCampId: command.targetCampId,
            mode: command.mode,
            contentScope: command.contentScope,
            grantedByActorId: command.grantedByActorId,
            validUntil: command.validUntil,
            expectedSourceLifecycleVersion:
                command.expectedSourceLifecycleVersion,
            expectedTargetLifecycleVersion:
                command.expectedTargetLifecycleVersion
        )
        let prepared = try P1DPreparedCommandV1.make(
            commandType: "camp-bridge.create.v1",
            envelope: command.envelope,
            payload: payload,
            events: []
        )
        return try database.pool.write { db in
            try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: command.sourceCampId,
                        expectedLifecycleVersion:
                            command.expectedSourceLifecycleVersion,
                        database: transaction
                    )
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: command.targetCampId,
                        expectedLifecycleVersion:
                            command.expectedTargetLifecycleVersion,
                        database: transaction
                    )
                    guard try Self.bridge(
                        id: command.bridgeId,
                        database: transaction
                    ) == nil else {
                        throw CampBridgeReferenceMismatchError()
                    }
                    return try CampBridgeSnapshotV1(
                        id: command.bridgeId,
                        sourceCampId: command.sourceCampId,
                        targetCampId: command.targetCampId,
                        mode: command.mode,
                        contentScope: command.contentScope,
                        grantedByActorId: command.grantedByActorId,
                        validUntil: command.validUntil,
                        status: .active,
                        revokedAt: nil,
                        aggregateVersion: 1,
                        createdAt: command.envelope.occurredAt,
                        updatedAt: command.envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    let scope = try CanonicalContractCodingV1.string(
                        result.contentScope
                    )
                    try transaction.execute(
                        sql: """
                            INSERT INTO camp_bridge(
                              id,sourceCampId,targetCampId,mode,
                              contentScopeJson,grantedByActorId,validUntil,
                              status,revokedAt,aggregateVersion,createdAt,updatedAt
                            ) VALUES (?,?,?,?,?,?,?,'active',NULL,1,?,?)
                            """,
                        arguments: [
                            result.id, result.sourceCampId,
                            result.targetCampId, result.mode.rawValue, scope,
                            result.grantedByActorId, result.validUntil,
                            result.createdAt, result.updatedAt,
                        ]
                    )
                },
                validateProjection: { transaction, _, result in
                    guard try Self.bridge(
                        id: result.id,
                        database: transaction
                    ) == result else {
                        throw CampBridgeReferenceMismatchError()
                    }
                }
            )
        }
    }

    package func revokeBridge(
        _ command: RevokeCampBridgeCommandV1
    ) throws -> CampBridgeSnapshotV1 {
        try Self.validateMutationActor(command.envelope)
        let payload = RevokeBridgePayload(
            bridgeId: command.bridgeId,
            expectedAggregateVersion: command.expectedAggregateVersion,
            expectedSourceLifecycleVersion:
                command.expectedSourceLifecycleVersion,
            expectedTargetLifecycleVersion:
                command.expectedTargetLifecycleVersion
        )
        let prepared = try P1DPreparedCommandV1.make(
            commandType: "camp-bridge.revoke.v1",
            envelope: command.envelope,
            payload: payload,
            events: []
        )
        return try database.pool.write { db in
            try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    guard let current = try Self.bridge(
                        id: command.bridgeId,
                        database: transaction
                    ), current.aggregateVersion
                        == command.expectedAggregateVersion,
                          current.status == .active
                    else {
                        throw CampBridgeReferenceMismatchError()
                    }
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: current.sourceCampId,
                        expectedLifecycleVersion:
                            command.expectedSourceLifecycleVersion,
                        database: transaction
                    )
                    _ = try lifecycleStore.requireActiveCampWrite(
                        campId: current.targetCampId,
                        expectedLifecycleVersion:
                            command.expectedTargetLifecycleVersion,
                        database: transaction
                    )
                    return try CampBridgeSnapshotV1(
                        id: current.id,
                        sourceCampId: current.sourceCampId,
                        targetCampId: current.targetCampId,
                        mode: current.mode,
                        contentScope: current.contentScope,
                        grantedByActorId: current.grantedByActorId,
                        validUntil: current.validUntil,
                        status: .revoked,
                        revokedAt: command.envelope.occurredAt,
                        aggregateVersion: try CanonicalContractCodingV1
                            .checkedIncrement(current.aggregateVersion),
                        createdAt: current.createdAt,
                        updatedAt: command.envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    try transaction.execute(
                        sql: """
                            UPDATE camp_bridge
                            SET status='revoked',revokedAt=?,aggregateVersion=?,
                                updatedAt=?
                            WHERE id=? AND status='active' AND aggregateVersion=?
                            """,
                        arguments: [
                            result.revokedAt, result.aggregateVersion,
                            result.updatedAt, result.id,
                            command.expectedAggregateVersion,
                        ]
                    )
                    guard transaction.changesCount == 1 else {
                        throw CampBridgeReferenceMismatchError()
                    }
                },
                validateProjection: { transaction, _, result in
                    guard try Self.bridge(
                        id: result.id,
                        database: transaction
                    ) == result else {
                        throw CampBridgeReferenceMismatchError()
                    }
                }
            )
        }
    }

    package func authorizedMemory(
        cowId: String,
        campId: String,
        bridges: [CampBridgeReadV1],
        at now: Date
    ) throws -> [MemoryRecordVersionV1] {
        try CanonicalContractCodingV1.validateNonempty(cowId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateFinite(now)
        return try database.pool.read { db in
            _ = try Self.requireActiveResidency(
                cowId: cowId,
                campId: campId,
                database: db
            )
            var records = try MemoryRecordStore.authorizedLocalRows(
                cowId: cowId,
                campId: campId,
                database: db
            )
            for request in bridges {
                try CanonicalContractCodingV1.validateCampID(
                    request.sourceCampId
                )
                guard !request.memoryIds.isEmpty,
                      request.memoryIds == request.memoryIds.sorted(),
                      Set(request.memoryIds).count
                        == request.memoryIds.count
                else {
                    throw CampBridgeAuthorizationError()
                }
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT * FROM camp_bridge
                        WHERE sourceCampId=? AND targetCampId=?
                          AND status='active'
                          AND (validUntil IS NULL OR validUntil>?)
                        ORDER BY id
                        """,
                    arguments: [request.sourceCampId, campId, now]
                )
                let candidates = try rows.map(Self.bridge(row:))
                guard candidates.contains(where: { bridge in
                    Set(request.memoryIds).isSubset(
                        of: Set(bridge.contentScope.memoryIds)
                    )
                }) else {
                    throw CampBridgeAuthorizationError()
                }
                let bridged = try MemoryRecordStore.activeCampRows(
                    campId: request.sourceCampId,
                    memoryIds: request.memoryIds,
                    database: db
                )
                guard Set(bridged.map(\.id)) == Set(request.memoryIds) else {
                    throw CampBridgeAuthorizationError()
                }
                records.append(contentsOf: bridged)
            }
            return Dictionary(
                records.map { ("\($0.id):\($0.version)", $0) },
                uniquingKeysWith: { first, _ in first }
            ).values.sorted {
                ($0.id, $0.version) < ($1.id, $1.version)
            }
        }
    }
}

extension CowResidencyStore {
    private static func validateMutationActor(
        _ envelope: CommandEnvelopeV1
    ) throws {
        guard envelope.actorType == .user || envelope.actorType == .system else {
            throw P1CommandAuthorizationError.forbiddenActor
        }
        try P1DTimestampV1.validateCanonical(envelope.occurredAt)
    }

    private static func reduced(
        _ current: CampResidencySnapshotV1,
        transition: CampResidencyTransitionV1,
        at: Date
    ) throws -> CampResidencySnapshotV1 {
        let target: CampResidencyStatusV1
        switch (current.status, transition) {
        case (.requested, .authorize): target = .authorized
        case (.authorized, .activate): target = .active
        case (.active, .pause): target = .paused
        case (.paused, .resume): target = .active
        case (.authorized, .leave), (.active, .leave), (.paused, .leave):
            target = .left
        case (.authorized, .revoke), (.active, .revoke), (.paused, .revoke):
            target = .revoked
        default:
            throw InvalidCampResidencyTransitionError()
        }
        return try CampResidencySnapshotV1(
            id: current.id,
            cowId: current.cowId,
            campId: current.campId,
            role: current.role,
            status: target,
            idempotencyKey: current.idempotencyKey,
            joinedAt: target == .active && current.joinedAt == nil
                ? at : current.joinedAt,
            pausedAt: target == .paused ? at : nil,
            leftAt: target == .left ? at : nil,
            revokedAt: target == .revoked ? at : nil,
            aggregateVersion: try CanonicalContractCodingV1
                .checkedIncrement(current.aggregateVersion),
            createdAt: current.createdAt,
            updatedAt: at
        )
    }

    private static func insert(
        _ value: CampResidencySnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO camp_residency(
                  id,cowId,campId,role,status,idempotencyKey,joinedAt,
                  pausedAt,leftAt,revokedAt,aggregateVersion,createdAt,updatedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                value.id, value.cowId, value.campId, value.role,
                value.status.rawValue, value.idempotencyKey, value.joinedAt,
                value.pausedAt, value.leftAt, value.revokedAt,
                value.aggregateVersion, value.createdAt, value.updatedAt,
            ]
        )
    }

    private static func cowIdentity(
        cowId: String,
        database: Database
    ) throws -> CowIdentitySnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM cow_identity WHERE id=?",
            arguments: [cowId]
        ) else {
            return nil
        }
        return try cowIdentity(row: row)
    }

    private static func cowIdentity(
        row: Row
    ) throws -> CowIdentitySnapshotV1 {
        guard let status = CowIdentityStatusV1(
            rawValue: row["status"] as String
        ) else {
            throw CampResidencyReferenceMismatchError()
        }
        return try CowIdentitySnapshotV1(
            id: row["id"],
            displayName: row["displayName"],
            appearanceRef: row["appearanceRef"],
            personality: row["personality"],
            baseRole: row["baseRole"],
            defaultEnginePolicyJson: row["defaultEnginePolicyJson"],
            status: status,
            aggregateVersion: row["aggregateVersion"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    private static func residency(
        id: String,
        database: Database
    ) throws -> CampResidencySnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM camp_residency WHERE id=?",
            arguments: [id]
        ) else {
            return nil
        }
        return try residency(row: row)
    }

    private static func residency(
        row: Row
    ) throws -> CampResidencySnapshotV1 {
        guard let status = CampResidencyStatusV1(
            rawValue: row["status"] as String
        ) else {
            throw CampResidencyReferenceMismatchError()
        }
        return try CampResidencySnapshotV1(
            id: row["id"],
            cowId: row["cowId"],
            campId: row["campId"],
            role: row["role"],
            status: status,
            idempotencyKey: row["idempotencyKey"],
            joinedAt: row["joinedAt"],
            pausedAt: row["pausedAt"],
            leftAt: row["leftAt"],
            revokedAt: row["revokedAt"],
            aggregateVersion: row["aggregateVersion"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    private static func bridge(
        id: String,
        database: Database
    ) throws -> CampBridgeSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM camp_bridge WHERE id=?",
            arguments: [id]
        ) else {
            return nil
        }
        return try bridge(row: row)
    }

    private static func bridge(row: Row) throws -> CampBridgeSnapshotV1 {
        let modeRaw: String = row["mode"]
        let statusRaw: String = row["status"]
        let scopeJSON: String = row["contentScopeJson"]
        guard let mode = CampBridgeModeV1(rawValue: modeRaw),
              let status = CampBridgeStatusV1(rawValue: statusRaw)
        else {
            throw CampBridgeReferenceMismatchError()
        }
        let scope = try CanonicalContractCodingV1.decode(
            CampBridgeContentScopeV1.self,
            from: Data(scopeJSON.utf8)
        )
        return try CampBridgeSnapshotV1(
            id: row["id"],
            sourceCampId: row["sourceCampId"],
            targetCampId: row["targetCampId"],
            mode: mode,
            contentScope: scope,
            grantedByActorId: row["grantedByActorId"],
            validUntil: row["validUntil"],
            status: status,
            revokedAt: row["revokedAt"],
            aggregateVersion: row["aggregateVersion"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    private struct RequestPayload: Codable {
        let residencyId: String
        let cowId: String
        let campId: String
        let role: String
        let expectedCampLifecycleVersion: Int
    }

    private struct TransitionPayload: Codable {
        let residencyId: String
        let expectedAggregateVersion: Int
        let transition: CampResidencyTransitionV1
        let expectedCampLifecycleVersion: Int
    }

    private struct CreateBridgePayload: Codable {
        let bridgeId: String
        let sourceCampId: String
        let targetCampId: String
        let mode: CampBridgeModeV1
        let contentScope: CampBridgeContentScopeV1
        let grantedByActorId: String
        let validUntil: Date?
        let expectedSourceLifecycleVersion: Int
        let expectedTargetLifecycleVersion: Int
    }

    private struct RevokeBridgePayload: Codable {
        let bridgeId: String
        let expectedAggregateVersion: Int
        let expectedSourceLifecycleVersion: Int
        let expectedTargetLifecycleVersion: Int
    }
}
