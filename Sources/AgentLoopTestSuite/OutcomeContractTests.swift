import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

let p1dEpoch = Date(timeIntervalSince1970: 2_000)
let p1dDeviceID = "10000000-0000-4000-8000-000000000001"

struct P1DContractFixture {
    let database: AppDatabase
    let store: OutcomeStore
    let camp: CampRecord
    let goal: GoalControllerRecord
    let understanding: UnderstandingCardVersionRecord
    let mission: MissionRecord
}

func p1dDatabase(_ label: String) throws -> AppDatabase {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-p1d-contract-\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return try AppDatabase(path: root.appendingPathComponent("db.sqlite").path)
}

func p1dUserEnvelope(
    _ key: String,
    at: Date = p1dEpoch
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .user,
        actorId: "user:local-owner",
        deviceId: p1dDeviceID,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

func p1dSystemEnvelope(
    _ key: String,
    actorId: String = P1DActorID.outcomeContract,
    at: Date = p1dEpoch
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .system,
        actorId: actorId,
        deviceId: nil,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

func p1dContractFixture(
    _ label: String,
    goalStatus: GoalControllerStatusV1 = .ready,
    missionStatus: MissionStatus = .executing
) throws -> P1DContractFixture {
    let database = try p1dDatabase(label)
    let camp = CampRecord(
        id: "p1d-camp-\(label)",
        name: "P1-D Camp",
        createdAt: p1dEpoch
    )
    let squad = SquadRecord(
        id: "20000000-0000-4000-8000-000000000001",
        campId: camp.id,
        name: "P1-D Squad",
        memberIdsJson: "[]",
        workspacePath: nil,
        createdAt: p1dEpoch
    )
    let mission = MissionRecord(
        id: "30000000-0000-4000-8000-000000000001",
        squadId: squad.id,
        goalRaw: "Ship verified result",
        goalRefined: "Ship verified result",
        status: missionStatus,
        budgetTokens: 10_000,
        spentTokens: 0,
        revision: 1,
        createdAt: p1dEpoch
    )
    let understandingID = "50000000-0000-4000-8000-000000000001"
    let goal = try GoalControllerRecord(
        id: "50000000-0000-4000-8000-000000000001",
        campId: camp.id,
        sourceInputId: nil,
        title: "P1-D goal",
        rawIntent: "Ship verified result",
        status: goalStatus,
        currentUnderstandingId: understandingID,
        currentUnderstandingVersion: 1,
        currentOutcomeContractId: nil,
        currentOutcomeContractVersion: nil,
        aggregateVersion: 1,
        createdByActorId: "user:local-owner",
        createdAt: p1dEpoch,
        updatedAt: p1dEpoch
    )
    let understanding = try UnderstandingCardVersionRecord(
        id: understandingID,
        version: 1,
        goalId: goal.id,
        content: UnderstandingContentV1(
            problem: "Need a verified result",
            scenario: "Coding Ranch",
            targetAudience: "Owner",
            goals: ["Ship"],
            nonGoals: ["Publish"],
            deliverables: ["Artifact"],
            constraints: ["Local only"],
            acceptanceCriteria: ["Tests pass"],
            verificationPlan: ["Run tests"],
            resourceRefs: [],
            requiredCapabilities: ["coding"],
            budgetPolicy: ["tokens": "10000"],
            assumptions: [],
            acceptedRisks: []
        ),
        status: .confirmed,
        createdByActorId: P1DActorID.coach,
        confirmedByActorId: "user:local-owner",
        confirmedAt: p1dEpoch,
        createdAt: p1dEpoch
    )
    try database.pool.write { db in
        try camp.insert(db)
        try squad.insert(db)
        try mission.insert(db)
        try goal.insert(db)
        try understanding.insert(db)
    }
    return P1DContractFixture(
        database: database,
        store: OutcomeStore(database: database, clock: { p1dEpoch }),
        camp: camp,
        goal: goal,
        understanding: understanding,
        mission: mission
    )
}

func p1dRequirement(
    id: String = "requirement-tests",
    verifierType: VerificationActorTypeV1 = .deterministic,
    method: VerificationMethodV1 = .tests
) throws -> VerificationRequirementV1 {
    try VerificationRequirementV1(
        requirementId: id,
        requirementVersion: 1,
        verifierType: verifierType,
        verifierId: verifierType == .deterministic
            ? "system:verifier:tests:v1"
            : "cow:reviewer:v1",
        method: method,
        ruleId: "rule:\(id)",
        ruleVersion: 1,
        config: ["command": .string("swift run RunTests")]
    )
}

func p1dBody(
    outcomeType: String = "coding",
    groups: [VerificationRequirementGroupV1]? = nil,
    publicRelease: Bool = false,
    requiredDependencies: [String] = []
) throws -> OutcomeContractBodyV1 {
    let resolvedGroups = try groups ?? [
        VerificationRequirementGroupV1(
            groupId: "group-tests",
            mode: .all,
            requirements: [p1dRequirement()]
        ),
    ]
    return try OutcomeContractBodyV1(
        outcomeType: outcomeType,
        deliverables: ["Artifact"],
        acceptanceCriteria: ["Tests pass"],
        verificationGroups: resolvedGroups,
        unacceptableDeviations: ["Missing artifact"],
        requiredDependencies: requiredDependencies,
        optionalDependencies: [],
        requiresSubjectiveJudgment: false,
        includesPublicRelease: publicRelease,
        includesPayment: false,
        includesDeletion: false,
        includesExternalSend: false,
        riskClass: .normal,
        acceptanceOwner: .user,
        acceptancePolicy: nil
    )
}

func p1dCreateDraft(
    _ fixture: P1DContractFixture,
    contractID: String = "60000000-0000-4000-8000-000000000001",
    key: String = "p1d:create-contract:1",
    body: OutcomeContractBodyV1? = nil
) throws -> OutcomeContractSnapshotV1 {
    try fixture.store.createDraft(
        CreateOutcomeContractDraftCommandV1(
            envelope: p1dUserEnvelope(key),
            contractId: contractID,
            goal: GoalHeadV1(
                goalId: fixture.goal.id,
                campId: fixture.goal.campId,
                expectedGoalVersion: fixture.goal.aggregateVersion
            ),
            understanding: UnderstandingVersionRefV1(
                id: fixture.understanding.id,
                version: fixture.understanding.version,
                hash: fixture.understanding.contentHash
            ),
            body: body ?? p1dBody()
        )
    )
}

func p1dActivateContract(
    _ fixture: P1DContractFixture,
    draft: OutcomeContractSnapshotV1,
    key: String = "p1d:activate-contract:1"
) throws -> OutcomeContractSnapshotV1 {
    try fixture.store.activateContract(
        ActivateOutcomeContractCommandV1(
            envelope: p1dSystemEnvelope(key),
            contract: draft.ref
        )
    )
}

private func p1dInsertAppendOnlyFixtures(
    fixture: P1DContractFixture,
    outcomeId: String,
    contract: OutcomeContractRef,
    in db: Database
) throws {
    let verificationID = "72000000-0000-4000-8000-000000000001"
    let storedRequirementHash = try String.fetchOne(
        db,
        sql: """
            SELECT requirementHash FROM verification_requirement
            WHERE contractId=? AND contractVersion=? AND requirementId='requirement-tests'
            """,
        arguments: [contract.id, contract.version]
    )
    let requirementHash = try #require(storedRequirementHash)
    let storedEventID = try String.fetchOne(
        db,
        sql: """
            SELECT id FROM domain_event WHERE commandIdempotencyKey=?
            ORDER BY eventOrdinal LIMIT 1
            """,
        arguments: ["p1d:activate-contract:1"]
    )
    let eventID = try #require(storedEventID)
    try db.execute(
        sql: """
            INSERT INTO verification_record(
              id,commandIdempotencyKey,contractId,contractVersion,contractHash,
              requirementId,requirementVersion,requirementHash,outcomeId,
              outcomeVersion,outcomeHash,verifierType,verifierId,method,ruleId,
              ruleVersion,environmentJson,commandOrRuleJson,rawResultRef,
              evidenceHash,result,supersedesVerificationId,createdAt,redactedAt
            ) VALUES (?,?,?,?,?,'requirement-tests',1,?,?,1,?,
              'deterministic','system:verifier:tests:v1','tests',
              'rule:requirement-tests',1,'{}','{}',NULL,?,'passed',NULL,?,NULL)
            """,
        arguments: [
            verificationID, "fixture:verification", contract.id,
            contract.version, contract.hash, requirementHash, outcomeId,
            String(repeating: "a", count: 64),
            String(repeating: "b", count: 64), p1dEpoch,
        ]
    )
    try db.execute(
        sql: """
            INSERT INTO verification_invalidation(
              id,verificationId,reasonCode,dependencyType,dependencyId,
              dependencyVersion,dependencyHash,eventId,createdAt
            ) VALUES (?,?, 'fixture','file','artifact',1,?,?,?)
            """,
        arguments: [
            "73000000-0000-4000-8000-000000000001", verificationID,
            String(repeating: "c", count: 64), eventID, p1dEpoch,
        ]
    )
    try db.execute(
        sql: """
            INSERT INTO acceptance_record(
              id,commandIdempotencyKey,contractId,contractVersion,contractHash,
              outcomeId,outcomeVersion,outcomeHash,subjectType,subjectId,
              policyId,policyVersion,decision,reason,supersedesAcceptanceId,
              createdAt,redactedAt
            ) VALUES (?,?,?,?,?,?,1,?,'user','user:local-owner',NULL,NULL,
              'returned','fixture',NULL,?,NULL)
            """,
        arguments: [
            "74000000-0000-4000-8000-000000000001", "fixture:acceptance",
            contract.id, contract.version, contract.hash, outcomeId,
            String(repeating: "a", count: 64), p1dEpoch,
        ]
    )
    let cardID = "75000000-0000-4000-8000-000000000001"
    try db.execute(
        sql: """
            INSERT INTO card(
              id,missionId,idemKey,title,descriptionText,expectedOutput,
              assigneeId,status,blockedReasonJson,dependsOnJson,handoffJson,
              stage,reviewFlag,maxTurns,tokenBudget,createdAt
            ) VALUES (?,?,'fixture:card','Fixture','Fixture','Fixture',NULL,
              'ready',NULL,'[]',NULL,1,NULL,1,1,?)
            """,
        arguments: [cardID, fixture.mission.id, p1dEpoch]
    )
    try db.execute(
        sql: """
            INSERT INTO approval_grant(
              id,version,scopeVersion,grantorActorType,grantorActorId,
              grantorPolicyId,grantorPolicyVersion,grantorPolicyHash,granteeType,
              granteeId,capability,campId,cardId,toolId,approvedInputHash,purpose,
              dataLevel,adapterReplayClass,validFrom,validUntil,maxUses,usedCount,
              status,revokedAt,createdAt,updatedAt,redactedAt
            ) VALUES (? ,1,1,'user','user:local-owner',NULL,NULL,NULL,'system',
              'runner','tool.execute:run_shell',?,?, 'run_shell',?,'fixture',
              'workspace','nonReplayable',?,?,1,1,'exhausted',NULL,?,?,NULL)
            """,
        arguments: [
            "76000000-0000-4000-8000-000000000001", fixture.camp.id,
            cardID, String(repeating: "d", count: 64), p1dEpoch,
            p1dEpoch.addingTimeInterval(60), p1dEpoch, p1dEpoch,
        ]
    )
    let useID = "77000000-0000-4000-8000-000000000001"
    try db.execute(
        sql: """
            INSERT INTO approval_grant_use(
              id,grantId,idempotencyKey,toolId,inputHash,adapterId,
              adapterReplayClass,state,adapterOperationId,version,reservedAt,
              dispatchIntentAt,adapterAcceptedAt,finishedAt
            ) VALUES (?,?,'fixture:use','run_shell',?,'adapter:fixture',
              'nonReplayable','dispatching',NULL,1,?,?,NULL,NULL)
            """,
        arguments: [
            useID, "76000000-0000-4000-8000-000000000001",
            String(repeating: "d", count: 64), p1dEpoch, p1dEpoch,
        ]
    )
    try db.execute(
        sql: """
            INSERT INTO external_operation_receipt(
              id,grantUseId,receiptIdempotencyKey,ordinal,phase,result,
              adapterOperationId,receiptRef,receiptJson,receiptHash,
              authorityKind,authorityId,createdAt,redactedAt
            ) VALUES (?,?,'fixture:receipt',0,'dispatchIntent','pending',
              NULL,NULL,'{}',?,'system','system:external-operation:v1',?,NULL)
            """,
        arguments: [
            "78000000-0000-4000-8000-000000000001", useID,
            String(repeating: "e", count: 64), p1dEpoch,
        ]
    )
}

private func p1dInsertAcceptedOutcomeFixture(
    fixture: P1DContractFixture,
    contract: OutcomeContractRef,
    in db: Database
) throws {
    let outcomeID = "79000000-0000-4000-8000-000000000001"
    let hash = String(repeating: "f", count: 64)
    try db.execute(
        sql: """
            INSERT INTO outcome(
              id,goalId,missionId,contractId,contractVersion,contractHash,
              currentVersion,state,aggregateVersion,createdAt,updatedAt
            ) VALUES (?,?,?,?,?,?,1,'accepted',1,?,?)
            """,
        arguments: [
            outcomeID, fixture.goal.id, fixture.mission.id, contract.id,
            contract.version, contract.hash, p1dEpoch, p1dEpoch,
        ]
    )
    try db.execute(
        sql: """
            INSERT INTO outcome_version(
              outcomeId,version,contractId,contractVersion,contractHash,
              producerActorId,runIdsJson,manifestJson,contentHash,createdAt
            ) VALUES (?,1,?,?,?,'cow:producer','[]','[]',?,?)
            """,
        arguments: [
            outcomeID, contract.id, contract.version, contract.hash,
            hash, p1dEpoch,
        ]
    )
}

@Suite(.serialized)
struct P1DOutcomeContractTests {
    @Test func outcomeContractMigrationRemainsPresentUnderV17Head() throws {
        let queue = try DatabaseQueue(path: FileManager.default.temporaryDirectory
            .appendingPathComponent("p1d-v17-checkpoint-\(UUID().uuidString).sqlite").path)
        try AppDatabase.migrator.migrate(queue, upTo: "v17-p1-engine-coordination")
        let storedMigration = try queue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid DESC LIMIT 1"
            )
        }
        let migration = try #require(storedMigration)
        #expect(migration == "v17-p1-engine-coordination")
        let names = try queue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT type || ':' || name FROM sqlite_master
                    WHERE name IN (
                      'outcome_contract_version','verification_requirement_group',
                      'verification_requirement','outcome','outcome_version',
                      'verification_record','verification_result_head',
                      'verification_invalidation','acceptance_policy_version',
                      'acceptance_record','outcome_metric_credit','approval_grant',
                      'approval_grant_use','external_operation_receipt'
                    ) ORDER BY 1
                    """
            )
        }
        #expect(names.count == 14)
        let checkpoint = try queue.read { db in
            (
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")!,
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='index'")!,
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger'")!
            )
        }
        #expect(checkpoint.0 == 79)
        #expect(checkpoint.1 == 208)
        #expect(checkpoint.2 == 84)
    }

    @Test func outcomeContractMigrationReplaysFreshAndEveryPredecessorTwice() throws {
        let predecessors: [String?] = [
            nil, "v7", "v8-coding-ranch", "v9-evercamp",
            "v10-runtime-profiles", "v11-cli-kinds",
            "v12-p1-durable-work", "v12-p1-schedule-fire",
            "v13-p1-observability", "v14-p1-control-contracts",
        ]
        for (index, predecessor) in predecessors.enumerated() {
            let queue = try DatabaseQueue(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("p1d-predecessor-\(index)-\(UUID().uuidString).sqlite").path)
            if let predecessor {
                try AppDatabase.migrator.migrate(queue, upTo: predecessor)
            }
            try AppDatabase.migrator.migrate(
                queue,
                upTo: "v15-p1-outcome-contracts"
            )
            try AppDatabase.migrator.migrate(
                queue,
                upTo: "v15-p1-outcome-contracts"
            )
            try queue.read { db -> Void in
                let latest = try String.fetchOne(
                    db,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid DESC LIMIT 1"
                )
                let foreignKeyFailures = try Row.fetchAll(
                    db,
                    sql: "PRAGMA foreign_key_check"
                )
                let integrity = try String.fetchOne(
                    db,
                    sql: "PRAGMA integrity_check"
                )
                #expect(latest == "v15-p1-outcome-contracts")
                #expect(foreignKeyFailures.isEmpty)
                #expect(integrity == "ok")
            }
        }
    }

    @Test func outcomeContractMigrationRollbackRestoresV14Snapshot() throws {
        let queue = try DatabaseQueue(path: FileManager.default.temporaryDirectory
            .appendingPathComponent("p1d-rollback-\(UUID().uuidString).sqlite").path)
        try AppDatabase.migrator.migrate(queue, upTo: "v14-p1-control-contracts")
        let before = try queue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT type || ':' || name || ':' || COALESCE(sql,'') FROM sqlite_master ORDER BY type,name"
            )
        }
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE acceptance_policy_version(id TEXT PRIMARY KEY)")
        }
        #expect(throws: (any Error).self) {
            try AppDatabase.migrator.migrate(queue)
        }
        try queue.write { db in
            try db.execute(sql: "DROP TABLE acceptance_policy_version")
        }
        let after = try queue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT type || ':' || name || ':' || COALESCE(sql,'') FROM sqlite_master ORDER BY type,name"
            )
        }
        #expect(after == before)
    }

    @Test func v15AppendOnlyCarriersRejectNoopUpdateAndDelete() throws {
        let fixture = try p1dContractFixture("append-only")
        let draft = try p1dCreateDraft(fixture)
        let active = try p1dActivateContract(fixture, draft: draft)
        try fixture.database.pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO outcome(
                      id,goalId,missionId,contractId,contractVersion,contractHash,
                      currentVersion,state,aggregateVersion,createdAt,updatedAt
                    ) VALUES (?,?,?,?,?,?,1,'produced',1,?,?)
                    """,
                arguments: [
                    "71000000-0000-4000-8000-000000000001", fixture.goal.id,
                    fixture.mission.id, active.ref.id, active.ref.version,
                    active.ref.hash, p1dEpoch, p1dEpoch,
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO outcome_version(
                      outcomeId,version,contractId,contractVersion,contractHash,
                      producerActorId,runIdsJson,manifestJson,contentHash,createdAt
                    ) VALUES (?,1,?,?,?,'cow:producer','[]','[]',?,?)
                    """,
                arguments: [
                    "71000000-0000-4000-8000-000000000001", active.ref.id,
                    active.ref.version, active.ref.hash,
                    String(repeating: "a", count: 64), p1dEpoch,
                ]
            )
            try p1dInsertAppendOnlyFixtures(
                fixture: fixture,
                outcomeId: "71000000-0000-4000-8000-000000000001",
                contract: active.ref,
                in: db
            )
            for table in [
                "verification_record", "verification_invalidation",
                "acceptance_record", "external_operation_receipt",
            ] {
                #expect(throws: (any Error).self) {
                    try db.execute(sql: "UPDATE \(table) SET rowid=rowid")
                }
                #expect(throws: (any Error).self) {
                    try db.execute(sql: "DELETE FROM \(table)")
                }
            }
        }
    }

    @Test func v15RedactionShapesAndPolicySchemaAreExact() throws {
        let fixture = try p1dContractFixture("redaction")
        try fixture.database.pool.read { db in
            let policyColumns = try Row.fetchAll(
                db,
                sql: "PRAGMA table_info(acceptance_policy_version)"
            ).map { $0["name"] as String }
            for forbidden in [
                "allowFirstOnboarding", "allowFirstOutcomeType",
                "allowSubjective", "allowPublicRelease", "allowPayment",
                "allowDeletion", "allowExternalSend",
            ] {
                #expect(!policyColumns.contains(forbidden))
            }
            for table in [
                "verification_record", "acceptance_record",
                "external_operation_receipt", "approval_grant",
            ] {
                let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
                    .map { $0["name"] as String }
                #expect(columns.contains("redactedAt"))
            }
        }
    }

    @Test func v15RawGrantAndReceiptConstraintMatricesFailClosed() throws {
        let fixture = try p1dContractFixture("raw-matrix")
        try fixture.database.pool.write { db in
            #expect(throws: (any Error).self) {
                try db.execute(
                    sql: """
                        INSERT INTO approval_grant(
                          id,version,scopeVersion,grantorActorType,grantorActorId,
                          granteeType,granteeId,capability,campId,cardId,toolId,
                          approvedInputHash,purpose,dataLevel,adapterReplayClass,
                          validFrom,validUntil,maxUses,usedCount,status,createdAt,updatedAt
                        ) VALUES (
                          'bad',1,1,'system','system:bad','system','runner','tool',?,
                          'missing-card','run_shell',?,'test','workspace','nonReplayable',
                          ?,?,2,0,'active',?,?
                        )
                        """,
                    arguments: [
                        fixture.camp.id, String(repeating: "a", count: 64),
                        p1dEpoch, p1dEpoch.addingTimeInterval(60), p1dEpoch, p1dEpoch,
                    ]
                )
            }
            let invalidTuples = [
                ("dispatchIntent", "succeeded", "system"),
                ("adapterAccepted", "pending", "user"),
                ("effectConfirmed", "unknown", "adapter"),
                ("noEffectConfirmed", "noEffect", "user"),
                ("userResolved", "noEffect", "user"),
            ]
            #expect(invalidTuples.count == 5)
        }
    }

    @Test func contractContentAndRequirementHashesUseCanonicalJSONV1() throws {
        let a = try p1dBody(groups: [
            VerificationRequirementGroupV1(
                groupId: "g",
                mode: .all,
                requirements: [
                    VerificationRequirementV1(
                        requirementId: "r",
                        requirementVersion: 1,
                        verifierType: .deterministic,
                        verifierId: "system:verifier:v1",
                        method: .tests,
                        ruleId: "rule:r",
                        ruleVersion: 1,
                        config: ["b": .number(2), "a": .number(1)]
                    ),
                ]
            ),
        ])
        let b = try p1dBody(groups: [
            VerificationRequirementGroupV1(
                groupId: "g",
                mode: .all,
                requirements: [
                    VerificationRequirementV1(
                        requirementId: "r",
                        requirementVersion: 1,
                        verifierType: .deterministic,
                        verifierId: "system:verifier:v1",
                        method: .tests,
                        ruleId: "rule:r",
                        ruleVersion: 1,
                        config: ["a": .number(1), "b": .number(2)]
                    ),
                ]
            ),
        ])
        #expect(try CanonicalContractCodingV1.hash(a) == CanonicalContractCodingV1.hash(b))
        #expect(a.verificationGroups[0].requirements[0].requirementHash
            == b.verificationGroups[0].requirements[0].requirementHash)

        let submillisecond = Date(
            timeIntervalSince1970: 1_800_000_000.123456
        )
        let canonicalTime = try P1DTimestampV1.canonical(submillisecond)
        #expect(canonicalTime < submillisecond)
        #expect(submillisecond.timeIntervalSince(canonicalTime) < 0.001)
        let repeatedCanonicalTime = try P1DTimestampV1.canonical(canonicalTime)
        #expect(canonicalTime == repeatedCanonicalTime)
        #expect(throws: P1ContractValidationError.self) {
            try P1DTimestampV1.validateCanonical(submillisecond)
        }
        try P1DTimestampV1.validateCanonical(canonicalTime)

        let textDecodeUlp = canonicalTime.addingTimeInterval(0.000_001)
        #expect(
            try P1DTimestampV1.restorePersisted(textDecodeUlp)
                == canonicalTime
        )
        #expect(throws: P1ContractValidationError.self) {
            try P1DTimestampV1.restorePersisted(
                canonicalTime.addingTimeInterval(0.000_1)
            )
        }
    }

    @Test func draftCreationIsImmutableIdempotentAndConflictDetecting() throws {
        let fixture = try p1dContractFixture("create-replay")
        let first = try p1dCreateDraft(fixture)
        let replay = try p1dCreateDraft(fixture)
        #expect(replay == first)
        #expect(try fixture.store.contractVersions(id: first.ref.id).count == 1)
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try p1dCreateDraft(
                fixture,
                body: p1dBody(publicRelease: true)
            )
        }
    }

    @Test func draftRevisionCreatesNextVersionAndCancelsOnlyPriorDraft() throws {
        let fixture = try p1dContractFixture("revise")
        let first = try p1dCreateDraft(fixture)
        let second = try fixture.store.reviseContract(
            ReviseOutcomeContractCommandV1(
                envelope: p1dUserEnvelope("p1d:revise-contract:1"),
                contract: first.ref,
                body: p1dBody(publicRelease: true)
            )
        )
        let versions = try fixture.store.contractVersions(id: first.ref.id)
        #expect(second.ref.version == 2)
        #expect(versions.map(\.status) == [.canceled, .draft])
        #expect(versions[0].contentHash == first.ref.hash)
    }

    @Test func activationRequiresExactConfirmedUnderstandingAndSnapshotRows() throws {
        let fixture = try p1dContractFixture("activation-integrity")
        let draft = try p1dCreateDraft(fixture)
        try fixture.database.pool.write { db in
            try db.execute(
                sql: "UPDATE understanding_card_version SET status='withdrawn', confirmedByActorId=NULL, confirmedAt=NULL WHERE id=?",
                arguments: [fixture.understanding.id]
            )
        }
        #expect(throws: OutcomeContractActivationError.self) {
            _ = try p1dActivateContract(fixture, draft: draft)
        }
        #expect(try fixture.store.contract(ref: draft.ref)?.status == .draft)
    }

    @Test func codingActivationRequiresDeterministicRequirement() throws {
        let fixture = try p1dContractFixture("deterministic")
        let cowOnly = try VerificationRequirementGroupV1(
            groupId: "cow-only",
            mode: .all,
            requirements: [
                p1dRequirement(
                    id: "model",
                    verifierType: .cow,
                    method: .modelSupplement
                ),
            ]
        )
        let draft = try p1dCreateDraft(
            fixture,
            body: p1dBody(groups: [cowOnly])
        )
        #expect(throws: OutcomeContractActivationError.self) {
            _ = try p1dActivateContract(fixture, draft: draft)
        }
    }

    @Test func activationSupersedesPriorActiveOnlyAfterNewVersionValidates() throws {
        let fixture = try p1dContractFixture("supersede")
        let first = try p1dCreateDraft(fixture)
        let active = try p1dActivateContract(fixture, draft: first)
        let second = try fixture.store.reviseContract(
            ReviseOutcomeContractCommandV1(
                envelope: p1dUserEnvelope("p1d:revise-active:1"),
                contract: active.ref,
                body: p1dBody(publicRelease: true)
            )
        )
        #expect(try fixture.store.contract(ref: active.ref)?.status == .active)
        let activatedSecond = try fixture.store.activateContract(
            ActivateOutcomeContractCommandV1(
                envelope: p1dSystemEnvelope("p1d:activate-contract:2"),
                contract: second.ref
            )
        )
        #expect(activatedSecond.status == .active)
        #expect(try fixture.store.contract(ref: active.ref)?.status == .superseded)
    }

    @Test func contractFulfillAndCancelAllowOnlyFrozenTransitions() throws {
        let fixture = try p1dContractFixture("contract-terminals")
        let draft = try p1dCreateDraft(fixture)
        let canceled = try fixture.store.cancelContract(
            ChangeOutcomeContractStatusCommandV1(
                envelope: p1dUserEnvelope("p1d:cancel-contract:1"),
                contract: draft.ref
            )
        )
        #expect(canceled.status == .canceled)
        #expect(throws: InvalidOutcomeContractTransitionError.self) {
            _ = try p1dActivateContract(fixture, draft: canceled)
        }

        let other = try p1dCreateDraft(
            fixture,
            contractID: "60000000-0000-4000-8000-000000000002",
            key: "p1d:create-contract:2"
        )
        let active = try p1dActivateContract(
            fixture,
            draft: other,
            key: "p1d:activate-contract:other"
        )
        let fulfilled = try fixture.store.fulfillContract(
            ChangeOutcomeContractStatusCommandV1(
                envelope: p1dSystemEnvelope("p1d:fulfill-contract:1"),
                contract: active.ref
            )
        )
        #expect(fulfilled.status == .fulfilled)
        #expect(throws: InvalidOutcomeContractTransitionError.self) {
            _ = try fixture.store.cancelContract(
                ChangeOutcomeContractStatusCommandV1(
                    envelope: p1dUserEnvelope("p1d:cancel-active:1"),
                    contract: active.ref
                )
            )
        }
    }

    @Test func goalReadyActivationRequiresActiveExactContractAndSameGoal() throws {
        let fixture = try p1dContractFixture("goal-activate")
        let draft = try p1dCreateDraft(fixture)
        #expect(throws: GoalActivationError.self) {
            _ = try fixture.store.activateGoal(
                ActivateGoalCommandV1(
                    envelope: p1dUserEnvelope("p1d:activate-goal:draft"),
                    goal: GoalHeadV1(
                        goalId: fixture.goal.id,
                        campId: fixture.goal.campId,
                        expectedGoalVersion: 1
                    ),
                    contract: draft.ref,
                    missionId: fixture.mission.id,
                    expectedLinkVersion: nil
                )
            )
        }
        let active = try p1dActivateContract(fixture, draft: draft)
        let activated = try fixture.store.activateGoal(
            ActivateGoalCommandV1(
                envelope: p1dUserEnvelope("p1d:activate-goal:active"),
                goal: GoalHeadV1(
                    goalId: fixture.goal.id,
                    campId: fixture.goal.campId,
                    expectedGoalVersion: 1
                ),
                contract: active.ref,
                missionId: fixture.mission.id,
                expectedLinkVersion: nil
            )
        )
        #expect(activated.goal.status == .active)
        #expect(activated.goal.currentOutcomeContractId == active.ref.id)
        #expect(activated.link.outcomeContractVersion == active.ref.version)
    }

    @Test func goalPauseResumeAchieveAndSystemReopenAreExhaustive() throws {
        let fixture = try p1dContractFixture("goal-transitions")
        let activeContract = try p1dActivateContract(
            fixture,
            draft: p1dCreateDraft(fixture)
        )
        var head = try fixture.store.activateGoal(
            ActivateGoalCommandV1(
                envelope: p1dUserEnvelope("p1d:goal-active"),
                goal: GoalHeadV1(
                    goalId: fixture.goal.id,
                    campId: fixture.goal.campId,
                    expectedGoalVersion: 1
                ),
                contract: activeContract.ref,
                missionId: fixture.mission.id,
                expectedLinkVersion: nil
            )
        ).goal
        head = try fixture.store.transitionGoal(
            GoalStatusCommandV1(
                envelope: p1dUserEnvelope("p1d:goal-pause"),
                goal: GoalHeadV1(
                    goalId: head.id,
                    campId: head.campId,
                    expectedGoalVersion: head.aggregateVersion
                ),
                transition: .pause
            )
        )
        #expect(head.status == .paused)
        head = try fixture.store.transitionGoal(
            GoalStatusCommandV1(
                envelope: p1dUserEnvelope("p1d:goal-resume"),
                goal: GoalHeadV1(
                    goalId: head.id,
                    campId: head.campId,
                    expectedGoalVersion: head.aggregateVersion
                ),
                transition: .resume
            )
        )
        #expect(head.status == .active)
        #expect(throws: GoalAchievementPreconditionError.self) {
            _ = try fixture.store.transitionGoal(
                GoalStatusCommandV1(
                    envelope: p1dUserEnvelope("p1d:goal-achieve-too-early"),
                    goal: GoalHeadV1(
                        goalId: head.id,
                        campId: head.campId,
                        expectedGoalVersion: head.aggregateVersion
                    ),
                    transition: .achieve
                )
            )
        }
        try fixture.database.pool.write { db in
            try p1dInsertAcceptedOutcomeFixture(
                fixture: fixture,
                contract: activeContract.ref,
                in: db
            )
        }
        head = try fixture.store.transitionGoal(
            GoalStatusCommandV1(
                envelope: p1dUserEnvelope("p1d:goal-achieve"),
                goal: GoalHeadV1(
                    goalId: head.id,
                    campId: head.campId,
                    expectedGoalVersion: head.aggregateVersion
                ),
                transition: .achieve
            )
        )
        #expect(head.status == .achieved)
        head = try fixture.store.transitionGoal(
            GoalStatusCommandV1(
                envelope: p1dSystemEnvelope(
                    "p1d:goal-reopen",
                    actorId: P1DActorID.outcomeReopen
                ),
                goal: GoalHeadV1(
                    goalId: head.id,
                    campId: head.campId,
                    expectedGoalVersion: head.aggregateVersion
                ),
                transition: .reopen
            )
        )
        #expect(head.status == .active)
    }

    @Test func goalMissionLinkIsCampExactCASAndCarriesContractRef() throws {
        let fixture = try p1dContractFixture("link-cas")
        let active = try p1dActivateContract(
            fixture,
            draft: p1dCreateDraft(fixture)
        )
        let first = try fixture.store.activateGoal(
            ActivateGoalCommandV1(
                envelope: p1dUserEnvelope("p1d:link-first"),
                goal: GoalHeadV1(
                    goalId: fixture.goal.id,
                    campId: fixture.goal.campId,
                    expectedGoalVersion: 1
                ),
                contract: active.ref,
                missionId: fixture.mission.id,
                expectedLinkVersion: nil
            )
        )
        #expect(first.link.version == 1)
        #expect(first.link.outcomeContractId == active.ref.id)
        #expect(throws: GoalMissionLinkConflictError.self) {
            _ = try fixture.store.linkMissionToActiveGoal(
                LinkMissionToGoalCommandV1(
                    envelope: p1dSystemEnvelope("p1d:link-stale"),
                    goal: GoalHeadV1(
                        goalId: first.goal.id,
                        campId: first.goal.campId,
                        expectedGoalVersion: first.goal.aggregateVersion
                    ),
                    contract: active.ref,
                    missionId: fixture.mission.id,
                    expectedLinkVersion: 0
                )
            )
        }
    }

    @Test func p1CReadyBehaviorRemainsValidWithoutOutcomeContract() throws {
        let fixture = try p1dContractFixture("p1c-ready")
        #expect(fixture.goal.status == .ready)
        #expect(fixture.goal.currentOutcomeContractId == nil)
        #expect(fixture.goal.currentOutcomeContractVersion == nil)
        #expect(GoalControllerTransitionPolicyV1.allows(from: .clarifying, to: .ready))
        #expect(!GoalControllerTransitionPolicyV1.allows(from: .ready, to: .active))
    }

    @Test func everyP1DContractAndGoalCommandRejectsWrongActorBeforeSQL() throws {
        let fixture = try p1dContractFixture("actors")
        let draft = try p1dCreateDraft(fixture)
        let before = try fixture.store.contractVersions(id: draft.ref.id)
        let badActors: [CommandEnvelopeV1] = [
            try CommandEnvelopeV1(
                idempotencyKey: "bad:cow",
                actorType: .cow,
                actorId: "cow:bad",
                deviceId: nil,
                correlationId: "trace:bad:cow",
                causationId: nil,
                occurredAt: p1dEpoch
            ),
            try CommandEnvelopeV1(
                idempotencyKey: "bad:coach",
                actorType: .coach,
                actorId: P1DActorID.coach,
                deviceId: nil,
                correlationId: "trace:bad:coach",
                causationId: nil,
                occurredAt: p1dEpoch
            ),
        ]
        for envelope in badActors {
            #expect(throws: P1DCommandAuthorizationError.self) {
                _ = try fixture.store.reviseContract(
                    ReviseOutcomeContractCommandV1(
                        envelope: envelope,
                        contract: draft.ref,
                        body: p1dBody(publicRelease: true)
                    )
                )
            }
        }
        #expect(try fixture.store.contractVersions(id: draft.ref.id) == before)
    }
}
