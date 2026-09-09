import Foundation
import GRDB
import Testing
import AgentLoopCore

private let p1f1OriginNow = Date(timeIntervalSince1970: 4_100_000)

private struct P1F1OriginGraphCounts: Equatable {
    let artifacts: Int
    let origins: Int
    let references: Int
}

private struct P1F1OriginLegacyEvidenceMaterial: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originalRefHash: String
}

private struct P1F1OriginRootSetMaterial: Encodable {
    let generation: Int
    let roots: [P1F1OriginRootMaterial]
}

private struct P1F1OriginRootMaterial: Encodable {
    let campId: String
    let rootId: String
    let standardizedAbsolutePath: String
}

private struct P1F1OriginFixture {
    let root: URL
    let database: AppDatabase
    let campID = "10000000-0000-4000-8000-000000000001"
    let squadID = "10000000-0000-4000-8000-000000000002"
    let missionID = "10000000-0000-4000-8000-000000000003"
    let cardID = "10000000-0000-4000-8000-000000000004"

    init(_ label: String) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agentloop-p1f1-origin-\(label)-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        database = try AppDatabase(
            path: root.appendingPathComponent("origin.sqlite").path
        )
        try database.pool.write { db in
            try CampRecord(
                id: campID,
                name: "P1-F1 Origin Camp",
                createdAt: p1f1OriginNow
            ).insert(db)
            try db.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',1,?,?,NULL,NULL)
                    """,
                arguments: [campID, p1f1OriginNow, p1f1OriginNow]
            )
            try SquadRecord(
                id: squadID,
                campId: campID,
                name: "Origin Squad",
                memberIdsJson: "[]",
                workspacePath: root.appendingPathComponent("workspace").path,
                workspaceBookmark: nil,
                createdAt: p1f1OriginNow
            ).insert(db)
            try MissionRecord(
                id: missionID,
                squadId: squadID,
                goalRaw: "classify artifacts",
                goalRefined: "classify artifacts",
                status: .executing,
                budgetTokens: 10_000,
                spentTokens: 0,
                revision: 1,
                createdAt: p1f1OriginNow
            ).insert(db)
            try CardRecord(
                id: cardID,
                missionId: missionID,
                idemKey: "p1f1-origin-card",
                title: "Origin card",
                descriptionText: "exercise typed artifact ownership",
                expectedOutput: "classified artifact",
                assigneeId: nil,
                status: .ready,
                blockedReasonJson: nil,
                dependsOnJson: "[]",
                handoffJson: nil,
                stage: 1,
                maxTurns: 4,
                tokenBudget: 5_000,
                createdAt: p1f1OriginNow
            ).insert(db)
        }
    }

    func insertLegacyArtifact(
        at fileURL: URL,
        artifactID: String
    ) throws -> ArtifactStorageOriginRecord {
        let originalRefHash = CanonicalJSONV1.sha256Hex(Data(fileURL.path.utf8))
        let evidenceHash = try CanonicalContractCodingV1.hash(
            P1F1OriginLegacyEvidenceMaterial(
                schemaVersion: 1,
                artifactId: artifactID,
                cardId: cardID,
                campId: campID,
                originalRefHash: originalRefHash
            )
        )
        try database.pool.write { db in
            try ArtifactRecord(
                id: artifactID,
                cardId: cardID,
                path: fileURL.path,
                kind: "report",
                label: "Legacy report",
                createdAt: p1f1OriginNow
            ).insert(db)
            try db.execute(
                sql: """
                    INSERT INTO artifact_storage_origin(
                      artifactId,campId,state,storageClass,evidenceKind,
                      managedRootId,objectId,contentHash,fileIdentityHash,
                      originalRefHash,classificationEvidenceHash,
                      terminalDisposition,terminalAuthorityHash,version,
                      classifiedAt,redactedAt
                    ) VALUES (
                      ?,?,'active','unresolved','legacyUnknown',
                      NULL,NULL,NULL,NULL,?,?,NULL,NULL,1,?,NULL
                    )
                    """,
                arguments: [
                    artifactID,
                    campID,
                    originalRefHash,
                    evidenceHash,
                    p1f1OriginNow,
                ]
            )
        }
        return try database.pool.read { db in
            guard let origin = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            ) else {
                throw RecordNotFoundError(
                    table: ArtifactStorageOriginRecord.databaseTableName,
                    id: artifactID
                )
            }
            return origin
        }
    }
}

private func p1f1OriginRootSnapshot(
    rootID: String,
    campID: String,
    rootURL: URL
) throws -> ManagedArtifactRootSnapshotV1 {
    let descriptor = try ManagedArtifactRootDescriptorV1.registered(
        rootId: rootID,
        campId: campID,
        rootURL: rootURL
    )
    let generation = 1
    let rootSetHash = try CanonicalContractCodingV1.hash(
        P1F1OriginRootSetMaterial(
            generation: generation,
            roots: [
                P1F1OriginRootMaterial(
                    campId: campID,
                    rootId: rootID,
                    standardizedAbsolutePath: rootURL.standardizedFileURL.path
                ),
            ]
        )
    )
    return try ManagedArtifactRootSnapshotV1.frozen(
        generation: generation,
        rootSetHash: rootSetHash,
        roots: [descriptor]
    )
}

private func p1f1OriginManagedEvidence(
    fixture: P1F1OriginFixture,
    artifactID: String,
    managedRoot: URL
) throws -> ArtifactOriginUpgradeEvidenceV1 {
    let roots = try p1f1OriginRootSnapshot(
        rootID: "p1f1-managed-root",
        campID: fixture.campID,
        rootURL: managedRoot
    )
    let verification = try ArtifactOwnershipVerifier(
        database: fixture.database,
        roots: roots
    ).verify(
        artifactId: artifactID,
        expectedOriginVersion: 1
    )
    guard case let .managed(evidence) = verification else {
        Issue.record("managed-root legacy artifact was not verified as managed")
        throw P1ContractValidationError.invalidValue
    }
    return .managed(evidence)
}

private func p1f1OriginCounts(
    _ database: AppDatabase,
    artifactID: String
) throws -> P1F1OriginGraphCounts {
    try database.pool.read { db in
        func count(_ table: String, key: String = "artifactId") throws -> Int {
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM \(table) WHERE \(key)=?",
                arguments: [artifactID]
            ) ?? 0
        }
        return try P1F1OriginGraphCounts(
            artifacts: count("artifact", key: "id"),
            origins: count("artifact_storage_origin"),
            references: count("artifact_blob_reference")
        )
    }
}

private func p1f1OriginEnableFinalization(
    fixture: P1F1OriginFixture
) throws {
    let workID = "10000000-0000-4000-8000-000000000031"
    let jobID = "10000000-0000-4000-8000-000000000032"
    try fixture.database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO durable_work(
                  id,campId,campLifecycleVersion,kind,aggregateType,
                  aggregateId,idempotencyKey,
                  state,attempt,maxAttempts,notBefore,leaseOwner,leaseExpiresAt,
                  inputJson,inputHash,outputJson,errorCode,errorMessage,traceId,
                  version,createdAt,updatedAt,finishedAt
                ) VALUES (
                  ?,?,1,'campDeletion','camp',?,?,'queued',0,4,NULL,NULL,NULL,
                  '{}',?,NULL,NULL,NULL,?,1,?,?,NULL
                )
                """,
            arguments: [
                workID,
                fixture.campID,
                fixture.campID,
                "p1f1-origin-delete-work",
                String(repeating: "a", count: 64),
                "trace:p1f1-origin-delete",
                p1f1OriginNow,
                p1f1OriginNow,
            ]
        )
        try db.execute(
            sql: """
                INSERT INTO camp_deletion_job(
                  id,campId,workId,requestIdempotencyKey,confirmationId,
                  confirmationHash,unknownArtifactDisposition,
                  requestedByActorId,state,phaseCursorJson,lastErrorCode,
                  version,createdAt,updatedAt,completedAt
                ) VALUES (
                  ?,?,?,?, ?,?,'detachOnlyNeverUnlink',?,
                  'finalizing','{}',NULL,1,?,?,NULL
                )
                """,
            arguments: [
                jobID,
                fixture.campID,
                workID,
                "p1f1-origin-delete-request",
                "p1f1-origin-delete-confirmation",
                String(repeating: "b", count: 64),
                "actor:p1f1-origin-test",
                p1f1OriginNow,
                p1f1OriginNow,
            ]
        )
        try db.execute(
            sql: """
                UPDATE camp_lifecycle
                SET state='deleting',version=version+1,updatedAt=?,
                    deletionRequestedAt=?
                WHERE campId=? AND state='active'
                """,
            arguments: [p1f1OriginNow, p1f1OriginNow, fixture.campID]
        )
        #expect(db.changesCount == 1)
    }
}

@Suite(.serialized)
struct P1F1ArtifactStorageOriginTests {
    @Test func p1f1_053TypedManagedOriginCreatesAtomically() throws {
        let fixture = try P1F1EngineFixture()
        let workspaceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentloop-p1f1-origin-managed-\(UUID().uuidString)")
        let stateRoot = workspaceRoot.appendingPathComponent("state")
        let artifactRoot = stateRoot.appendingPathComponent("artifacts")
        try FileManager.default.createDirectory(
            at: stateRoot,
            withIntermediateDirectories: true
        )
        let artifactBytes = Data("managed artifact\n".utf8)
        let relativePath = "outputs/result.txt"
        let workspaceFile = workspaceRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: workspaceFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try artifactBytes.write(to: workspaceFile)

        let request = try fixture.begin(key: "p1f1-origin-managed-begin")
        let execution = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        let executionVersion: Int = execution["version"]
        _ = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: executionVersion,
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-origin-managed-dispatch",
            now: p1f1OriginNow
        )
        let contentHash = CanonicalJSONV1.sha256Hex(artifactBytes)
        let proposal = try fixture.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: request.executionId,
                runId: request.runId,
                cardId: request.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-origin-managed-terminal",
                terminalKind: .completed,
                terminalSubtype: nil,
                payload: .completed(
                    handoff: HandoffPayload(
                        outcome: "implemented",
                        summary: "typed managed artifact",
                        artifacts: [
                            .init(
                                relativePath: relativePath,
                                kind: "report",
                                label: "Managed report"
                            ),
                        ],
                        verification: [
                            .init(method: "hash", passed: true, note: contentHash),
                        ],
                        risks: []
                    )
                ),
                artifacts: [
                    EngineTerminalArtifactDeclarationV1(
                        ordinal: 0,
                        sourceRelativePath: relativePath,
                        kind: "report",
                        label: "Managed report",
                        byteCount: artifactBytes.count,
                        contentHash: contentHash
                    ),
                ]
            )
        )
        let stateLock = try StateDirectoryLock(directoryURL: stateRoot)
        let blobStore = ArtifactBlobStore(
            database: fixture.db,
            artifactStoreRoot: artifactRoot,
            stateDirectoryLock: stateLock
        )
        let prepared = try ArtifactStager(
            database: fixture.db,
            blobStore: blobStore
        ).prepare(
            proposalId: proposal.proposal.id,
            workspaceRoot: workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )
        #expect(prepared.count == 1)
        let preparedArtifact = try #require(prepared.first)
        let originStore = ArtifactStorageOriginStore(database: fixture.db)
        let inserted = try fixture.db.pool.write { db in
            try originStore.insertPreparedArtifacts(
                prepared,
                proposalId: proposal.proposal.id,
                database: db
            )
        }
        #expect(inserted.map(\.id) == [preparedArtifact.artifactId])

        let origin = try fixture.db.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: preparedArtifact.artifactId
            )
            return try #require(fetched)
        }
        let reference = try fixture.db.pool.read { db in
            let fetched = try ArtifactBlobReferenceRecord.fetchOne(
                db,
                key: preparedArtifact.artifactId
            )
            return try #require(fetched)
        }
        #expect(origin.storageClass == .managed)
        #expect(origin.evidenceKind == .typedPreparedArtifact)
        #expect(origin.managedRootId == preparedArtifact.managedRootId)
        #expect(origin.objectId == preparedArtifact.objectId)
        #expect(origin.contentHash == preparedArtifact.contentHash)
        #expect(origin.fileIdentityHash == preparedArtifact.fileIdentityHash)
        #expect(reference.proposalArtifactId == preparedArtifact.proposalArtifactId)
        #expect(reference.executionId == preparedArtifact.executionId)
        #expect(reference.campId == preparedArtifact.campId)
        #expect(reference.contentHash == preparedArtifact.contentHash)
        #expect(reference.state == .active)

        let stable = try p1f1OriginCounts(
            fixture.db,
            artifactID: preparedArtifact.artifactId
        )
        #expect(stable == P1F1OriginGraphCounts(
            artifacts: 1,
            origins: 1,
            references: 1
        ))
        #expect(throws: (any Error).self) {
            try fixture.db.pool.write { db in
                try originStore.insertPreparedArtifacts(
                    prepared,
                    proposalId: proposal.proposal.id,
                    database: db
                )
            }
        }
        #expect(try p1f1OriginCounts(
            fixture.db,
            artifactID: preparedArtifact.artifactId
        ) == stable)

        // The package seam above proves the Origin Store in isolation. A
        // second graph proves the kernel owns the same insertion inside the
        // existing terminal transaction and that replay validates rather
        // than repairs or reinserts the graph.
        let integrated = try P1F1EngineFixture()
        let integratedWorkspace = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentloop-p1f1-origin-integrated-\(UUID().uuidString)"
            )
        let integratedState = integratedWorkspace.appendingPathComponent(
            "state"
        )
        let integratedArtifactRoot = integratedState.appendingPathComponent(
            "artifacts"
        )
        try FileManager.default.createDirectory(
            at: integratedState,
            withIntermediateDirectories: true
        )
        let integratedBytes = Data("kernel-managed artifact\n".utf8)
        let integratedRelativePath = "outputs/kernel-result.txt"
        let integratedSource = integratedWorkspace.appendingPathComponent(
            integratedRelativePath
        )
        try FileManager.default.createDirectory(
            at: integratedSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try integratedBytes.write(to: integratedSource)
        let integratedRequest = try integrated.begin(
            key: "p1f1-origin-integrated-begin"
        )
        let integratedExecution = try p1f1ExecutionRow(
            integrated.db,
            id: integratedRequest.executionId
        )
        _ = try integrated.store.markEngineDispatchStarted(
            executionId: integratedRequest.executionId,
            expectedVersion: integratedExecution["version"],
            requestHash: integratedRequest.requestHash,
            commandIdempotencyKey: "p1f1-origin-integrated-dispatch",
            now: p1f1OriginNow
        )
        let integratedHash = CanonicalJSONV1.sha256Hex(integratedBytes)
        let integratedProposal = try integrated.store
            .recordEngineTerminalProposal(
                EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: integratedRequest.executionId,
                    runId: integratedRequest.runId,
                    cardId: integratedRequest.cardId,
                    sequence: 0,
                    terminalIdempotencyKey:
                        "p1f1-origin-integrated-terminal",
                    terminalKind: .completed,
                    terminalSubtype: nil,
                    payload: .completed(
                        handoff: HandoffPayload(
                            outcome: "implemented",
                            summary: "kernel owns the artifact graph",
                            artifacts: [
                                .init(
                                    relativePath: integratedRelativePath,
                                    kind: "report",
                                    label: "Kernel report"
                                ),
                            ],
                            verification: [
                                .init(
                                    method: "hash",
                                    passed: true,
                                    note: integratedHash
                                ),
                            ],
                            risks: []
                        )
                    ),
                    artifacts: [
                        EngineTerminalArtifactDeclarationV1(
                            ordinal: 0,
                            sourceRelativePath: integratedRelativePath,
                            kind: "report",
                            label: "Kernel report",
                            byteCount: integratedBytes.count,
                            contentHash: integratedHash
                        ),
                    ]
                )
            )
        let integratedLock = try StateDirectoryLock(
            directoryURL: integratedState
        )
        let integratedBlobStore = ArtifactBlobStore(
            database: integrated.db,
            artifactStoreRoot: integratedArtifactRoot,
            stateDirectoryLock: integratedLock
        )
        let integratedPrepared = try ArtifactStager(
            database: integrated.db,
            blobStore: integratedBlobStore
        ).prepare(
            proposalId: integratedProposal.proposal.id,
            workspaceRoot: integratedWorkspace,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )
        let integratedPreparedArtifact = try #require(
            integratedPrepared.first
        )
        let integratedOriginStore = ArtifactStorageOriginStore(
            database: integrated.db
        )

        // Declared artifacts never fall back to the legacy zero-artifact
        // path when the kernel has no reviewed artifact dependencies.
        #expect(throws: EngineTerminalConflictErrorV1.self) {
            try integrated.store.commitEngineTerminal(
                proposalId: integratedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1OriginNow.addingTimeInterval(1)
            )
        }
        #expect(try p1f1OriginCounts(
            integrated.db,
            artifactID: integratedPreparedArtifact.artifactId
        ) == P1F1OriginGraphCounts(
            artifacts: 0,
            origins: 0,
            references: 0
        ))
        #expect(
            try integrated.db.card(id: integratedRequest.cardId)?.status
                == .running
        )

        let kernelStore = EngineExecutionStore(
            database: integrated.db,
            descriptorResolver: { _, _ in integrated.descriptor },
            clock: { p1f1OriginNow },
            artifactBlobStore: integratedBlobStore,
            artifactStorageOriginStore: integratedOriginStore
        )

        // A failure after artifact insertion but before the strict command
        // graph completes must roll the whole outer transaction back.
        try integrated.db.pool.write { database in
            try database.execute(sql: """
                CREATE TEMP TRIGGER p1f1_053_abort_terminal_domain_event
                BEFORE INSERT ON domain_event
                WHEN NEW.commandIdempotencyKey =
                  'engine.terminal.v1:p1f1-origin-integrated-terminal'
                BEGIN
                  SELECT RAISE(ABORT, 'p1f1_053_terminal_abort');
                END
                """)
        }
        #expect(throws: (any Error).self) {
            try kernelStore.commitEngineTerminal(
                proposalId: integratedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1OriginNow.addingTimeInterval(1)
            )
        }
        try integrated.db.pool.write { database in
            try database.execute(
                sql: "DROP TRIGGER p1f1_053_abort_terminal_domain_event"
            )
        }
        #expect(try p1f1OriginCounts(
            integrated.db,
            artifactID: integratedPreparedArtifact.artifactId
        ) == P1F1OriginGraphCounts(
            artifacts: 0,
            origins: 0,
            references: 0
        ))
        #expect(
            try integrated.db.card(id: integratedRequest.cardId)?.status
                == .running
        )
        let pendingProposal = try integrated.db.pool.read { database in
            try EngineTerminalProposalRecord.fetchOne(
                database,
                key: integratedProposal.proposal.id
            )
        }
        let pendingProposalRow = try #require(pendingProposal)
        #expect(pendingProposalRow.state == .pending)

        let committed = try kernelStore.commitEngineTerminal(
            proposalId: integratedProposal.proposal.id,
            checkedUsage: .zero,
            now: p1f1OriginNow.addingTimeInterval(1)
        )
        #expect(committed.artifactIds == integratedPrepared.map(\.artifactId))
        #expect(try integrated.db.card(id: integratedRequest.cardId)?.status == .done)
        let integratedCounts = try p1f1OriginCounts(
            integrated.db,
            artifactID: integratedPreparedArtifact.artifactId
        )
        #expect(integratedCounts == P1F1OriginGraphCounts(
            artifacts: 1,
            origins: 1,
            references: 1
        ))

        let replay = try kernelStore.commitEngineTerminal(
            proposalId: integratedProposal.proposal.id,
            checkedUsage: .zero,
            now: p1f1OriginNow.addingTimeInterval(1)
        )
        #expect(replay == committed)
        #expect(try p1f1OriginCounts(
            integrated.db,
            artifactID: integratedPreparedArtifact.artifactId
        ) == integratedCounts)

        try integrated.db.pool.write { db in
            try db.execute(
                sql: """
                    UPDATE artifact_storage_origin
                    SET contentHash=? WHERE artifactId=?
                    """,
                arguments: [
                    p1f1EngineHashF,
                    integratedPreparedArtifact.artifactId,
                ]
            )
            #expect(db.changesCount == 1)
        }
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            try kernelStore.commitEngineTerminal(
                proposalId: integratedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1OriginNow.addingTimeInterval(1)
            )
        }
    }

    @Test func p1f1_054TypedExternalOriginCreatesAtomically() throws {
        let fixture = try P1F1OriginFixture("external")
        let externalURL = fixture.root.appendingPathComponent("external-report.txt")
        try Data("external artifact\n".utf8).write(to: externalURL)
        let artifactID = "10000000-0000-4000-8000-000000000011"
        let reference = try WorkspaceExternalArtifactReferenceV1.explicit(
            cardId: fixture.cardID,
            path: externalURL.path,
            kind: "report",
            label: "External report",
            classifiedAt: p1f1OriginNow
        )
        let store = ArtifactStorageOriginStore(
            database: fixture.database,
            artifactIdFactory: { artifactID }
        )
        let inserted = try fixture.database.pool.write { db in
            try store.insertWorkspaceExternalArtifact(reference, database: db)
        }
        #expect(inserted.id == artifactID)
        #expect(inserted.cardId == fixture.cardID)
        #expect(inserted.path == externalURL.path)

        let origin = try fixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            )
            return try #require(fetched)
        }
        #expect(origin.campId == fixture.campID)
        #expect(origin.state == .active)
        #expect(origin.storageClass == .workspaceExternal)
        #expect(origin.evidenceKind == .explicitWorkspaceExternal)
        #expect(origin.managedRootId == nil)
        #expect(origin.objectId == nil)
        #expect(origin.contentHash == nil)
        #expect(origin.fileIdentityHash == nil)
        #expect(origin.originalRefHash.count == 64)
        #expect(origin.classificationEvidenceHash.count == 64)

        let stable = try p1f1OriginCounts(fixture.database, artifactID: artifactID)
        #expect(stable == P1F1OriginGraphCounts(
            artifacts: 1,
            origins: 1,
            references: 0
        ))
        #expect(throws: (any Error).self) {
            try fixture.database.pool.write { db in
                try store.insertWorkspaceExternalArtifact(reference, database: db)
            }
        }
        #expect(try p1f1OriginCounts(
            fixture.database,
            artifactID: artifactID
        ) == stable)
    }

    @Test func p1f1_055LegacyUpgradeRequiresVerifierEvidence() throws {
        // A sealed proof is only a snapshot. If another Camp claims the same
        // durable path before consumption, the Origin Store must re-check the
        // verifier's ambiguity predicate on the consuming transaction handle.
        let ambiguousFixture = try P1F1OriginFixture(
            "legacy-upgrade-consumption-recheck"
        )
        let ambiguousManagedRoot = ambiguousFixture.root
            .appendingPathComponent("managed-root")
        try FileManager.default.createDirectory(
            at: ambiguousManagedRoot,
            withIntermediateDirectories: true
        )
        let ambiguousFile = ambiguousManagedRoot
            .appendingPathComponent("legacy-report.txt")
        try Data("legacy managed artifact\n".utf8).write(to: ambiguousFile)
        let ambiguousArtifactID = "10000000-0000-4000-8000-000000000020"
        let ambiguousBefore = try ambiguousFixture.insertLegacyArtifact(
            at: ambiguousFile,
            artifactID: ambiguousArtifactID
        )
        let ambiguousEvidence = try p1f1OriginManagedEvidence(
            fixture: ambiguousFixture,
            artifactID: ambiguousArtifactID,
            managedRoot: ambiguousManagedRoot
        )

        let crossCampID = "20000000-0000-4000-8000-000000000001"
        let crossSquadID = "20000000-0000-4000-8000-000000000002"
        let crossMissionID = "20000000-0000-4000-8000-000000000003"
        let crossCardID = "20000000-0000-4000-8000-000000000004"
        let crossArtifactID = "20000000-0000-4000-8000-000000000005"
        let crossOriginalRefHash = CanonicalJSONV1.sha256Hex(
            Data(ambiguousFile.path.utf8)
        )
        let crossEvidenceHash = try CanonicalContractCodingV1.hash(
            P1F1OriginLegacyEvidenceMaterial(
                schemaVersion: 1,
                artifactId: crossArtifactID,
                cardId: crossCardID,
                campId: crossCampID,
                originalRefHash: crossOriginalRefHash
            )
        )
        try ambiguousFixture.database.pool.write { db in
            try CampRecord(
                id: crossCampID,
                name: "Cross-Camp claimant",
                createdAt: p1f1OriginNow
            ).insert(db)
            try db.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',1,?,?,NULL,NULL)
                    """,
                arguments: [crossCampID, p1f1OriginNow, p1f1OriginNow]
            )
            try SquadRecord(
                id: crossSquadID,
                campId: crossCampID,
                name: "Cross-Camp squad",
                memberIdsJson: "[]",
                workspacePath: ambiguousFixture.root
                    .appendingPathComponent("cross-workspace").path,
                workspaceBookmark: nil,
                createdAt: p1f1OriginNow
            ).insert(db)
            try MissionRecord(
                id: crossMissionID,
                squadId: crossSquadID,
                goalRaw: "claim the same path",
                goalRefined: "claim the same path",
                status: .executing,
                budgetTokens: 10_000,
                spentTokens: 0,
                revision: 1,
                createdAt: p1f1OriginNow
            ).insert(db)
            try CardRecord(
                id: crossCardID,
                missionId: crossMissionID,
                idemKey: "p1f1-cross-camp-origin-card",
                title: "Cross-Camp origin card",
                descriptionText: "introduce post-proof ambiguity",
                expectedOutput: "ambiguous ownership",
                assigneeId: nil,
                status: .ready,
                blockedReasonJson: nil,
                dependsOnJson: "[]",
                handoffJson: nil,
                stage: 1,
                maxTurns: 4,
                tokenBudget: 5_000,
                createdAt: p1f1OriginNow
            ).insert(db)
            try ArtifactRecord(
                id: crossArtifactID,
                cardId: crossCardID,
                path: ambiguousFile.path,
                kind: "report",
                label: "Cross-Camp legacy report",
                createdAt: p1f1OriginNow
            ).insert(db)
            try db.execute(
                sql: """
                    INSERT INTO artifact_storage_origin(
                      artifactId,campId,state,storageClass,evidenceKind,
                      managedRootId,objectId,contentHash,fileIdentityHash,
                      originalRefHash,classificationEvidenceHash,
                      terminalDisposition,terminalAuthorityHash,version,
                      classifiedAt,redactedAt
                    ) VALUES (
                      ?,?,'active','unresolved','legacyUnknown',
                      NULL,NULL,NULL,NULL,?,?,NULL,NULL,1,?,NULL
                    )
                    """,
                arguments: [
                    crossArtifactID,
                    crossCampID,
                    crossOriginalRefHash,
                    crossEvidenceHash,
                    p1f1OriginNow,
                ]
            )
        }
        let ambiguityStore = ArtifactStorageOriginStore(
            database: ambiguousFixture.database
        )
        #expect(throws: (any Error).self) {
            try ambiguousFixture.database.pool.write { db in
                try ambiguityStore.upgradeLegacyOrigin(
                    artifactId: ambiguousArtifactID,
                    expectedVersion: 1,
                    evidence: ambiguousEvidence,
                    at: p1f1OriginNow.addingTimeInterval(1),
                    database: db
                )
            }
        }
        let ambiguousAfter = try ambiguousFixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: ambiguousArtifactID
            )
            return try #require(fetched)
        }
        #expect(ambiguousAfter == ambiguousBefore)

        // A sealed proof is also invalidated by a competing live origin in
        // the same Camp; Camp equality does not make duplicate path identity
        // exclusive between artifacts.
        let sameCampFixture = try P1F1OriginFixture(
            "legacy-upgrade-same-camp-ambiguity"
        )
        let sameCampManagedRoot = sameCampFixture.root
            .appendingPathComponent("managed-root")
        try FileManager.default.createDirectory(
            at: sameCampManagedRoot,
            withIntermediateDirectories: true
        )
        let sameCampFile = sameCampManagedRoot
            .appendingPathComponent("legacy-report.txt")
        try Data("same Camp legacy managed artifact\n".utf8).write(
            to: sameCampFile
        )
        let sameCampArtifactID = "10000000-0000-4000-8000-000000000030"
        let sameCampBefore = try sameCampFixture.insertLegacyArtifact(
            at: sameCampFile,
            artifactID: sameCampArtifactID
        )
        let sameCampEvidence = try p1f1OriginManagedEvidence(
            fixture: sameCampFixture,
            artifactID: sameCampArtifactID,
            managedRoot: sameCampManagedRoot
        )
        _ = try sameCampFixture.insertLegacyArtifact(
            at: sameCampFile,
            artifactID: "10000000-0000-4000-8000-000000000031"
        )
        let sameCampStore = ArtifactStorageOriginStore(
            database: sameCampFixture.database
        )
        #expect(throws: (any Error).self) {
            try sameCampFixture.database.pool.write { database in
                try sameCampStore.upgradeLegacyOrigin(
                    artifactId: sameCampArtifactID,
                    expectedVersion: 1,
                    evidence: sameCampEvidence,
                    at: p1f1OriginNow.addingTimeInterval(1),
                    database: database
                )
            }
        }
        let sameCampAfter = try sameCampFixture.database.pool.read { database in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                database,
                key: sameCampArtifactID
            )
            return try #require(fetched)
        }
        #expect(sameCampAfter == sameCampBefore)

        let fixture = try P1F1OriginFixture("legacy-upgrade")
        let managedRoot = fixture.root.appendingPathComponent("managed-root")
        try FileManager.default.createDirectory(
            at: managedRoot,
            withIntermediateDirectories: true
        )
        let managedFile = managedRoot.appendingPathComponent("legacy-report.txt")
        try Data("legacy managed artifact\n".utf8).write(to: managedFile)
        let artifactID = "10000000-0000-4000-8000-000000000021"
        let before = try fixture.insertLegacyArtifact(
            at: managedFile,
            artifactID: artifactID
        )
        let evidence = try p1f1OriginManagedEvidence(
            fixture: fixture,
            artifactID: artifactID,
            managedRoot: managedRoot
        )
        let store = ArtifactStorageOriginStore(database: fixture.database)

        #expect(throws: (any Error).self) {
            try fixture.database.pool.write { db in
                try store.upgradeLegacyOrigin(
                    artifactId: artifactID,
                    expectedVersion: 2,
                    evidence: evidence,
                    at: p1f1OriginNow.addingTimeInterval(1),
                    database: db
                )
            }
        }
        let afterRejectedCAS = try fixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            )
            return try #require(fetched)
        }
        #expect(afterRejectedCAS == before)

        let upgraded = try fixture.database.pool.write { db in
            try store.upgradeLegacyOrigin(
                artifactId: artifactID,
                expectedVersion: 1,
                evidence: evidence,
                at: p1f1OriginNow.addingTimeInterval(1),
                database: db
            )
        }
        #expect(upgraded.artifact.id == artifactID)
        #expect(upgraded.origin.version == 2)
        #expect(upgraded.origin.state == .active)
        #expect(upgraded.origin.storageClass == .managed)
        #expect(upgraded.origin.evidenceKind == .verifiedManagedRootCapability)
        #expect(upgraded.origin.managedRootId == "p1f1-managed-root")
        #expect(upgraded.origin.objectId != nil)
        #expect(upgraded.origin.contentHash?.count == 64)
        #expect(upgraded.origin.fileIdentityHash?.count == 64)
        #expect(upgraded.origin.originalRefHash == before.originalRefHash)
        #expect(upgraded.blobReference == nil)
    }

    @Test func p1f1_056OriginRedactionTerminalDispositionLocks() throws {
        let fixture = try P1F1OriginFixture("redaction-lock")
        let managedRoot = fixture.root.appendingPathComponent("managed-root")
        try FileManager.default.createDirectory(
            at: managedRoot,
            withIntermediateDirectories: true
        )
        let managedFile = managedRoot.appendingPathComponent("terminal-report.txt")
        try Data("terminal managed artifact\n".utf8).write(to: managedFile)
        let artifactID = "10000000-0000-4000-8000-000000000041"
        _ = try fixture.insertLegacyArtifact(at: managedFile, artifactID: artifactID)
        let evidence = try p1f1OriginManagedEvidence(
            fixture: fixture,
            artifactID: artifactID,
            managedRoot: managedRoot
        )
        let store = ArtifactStorageOriginStore(database: fixture.database)
        _ = try fixture.database.pool.write { db in
            try store.upgradeLegacyOrigin(
                artifactId: artifactID,
                expectedVersion: 1,
                evidence: evidence,
                at: p1f1OriginNow.addingTimeInterval(1),
                database: db
            )
        }
        let terminalAt = p1f1OriginNow.addingTimeInterval(2)
        let authorityHash = String(repeating: "c", count: 64)

        #expect(throws: (any Error).self) {
            try fixture.database.pool.write { db in
                try db.execute(
                    sql: """
                        UPDATE artifact_storage_origin
                        SET state='tombstoned',managedRootId=NULL,objectId=NULL,
                            terminalDisposition='managedDeleted',
                            terminalAuthorityHash=?,version=version+1,redactedAt=?
                        WHERE artifactId=?
                        """,
                    arguments: [authorityHash, terminalAt, artifactID]
                )
            }
        }
        let beforeFinalization = try fixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            )
            return try #require(fetched)
        }
        #expect(beforeFinalization.state == .active)
        #expect(beforeFinalization.redactedAt == nil)

        try p1f1OriginEnableFinalization(fixture: fixture)
        try fixture.database.pool.write { db in
            try db.execute(
                sql: """
                    UPDATE artifact_storage_origin
                    SET state='tombstoned',managedRootId=NULL,objectId=NULL,
                        terminalDisposition='managedDeleted',
                        terminalAuthorityHash=?,version=version+1,redactedAt=?
                    WHERE artifactId=? AND version=2
                    """,
                arguments: [authorityHash, terminalAt, artifactID]
            )
            #expect(db.changesCount == 1)
        }
        let terminal = try fixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            )
            return try #require(fetched)
        }
        #expect(terminal.state == .tombstoned)
        #expect(terminal.storageClass == .managed)
        #expect(terminal.managedRootId == nil)
        #expect(terminal.objectId == nil)
        #expect(terminal.terminalDisposition == .managedDeleted)
        #expect(terminal.terminalAuthorityHash == authorityHash)
        #expect(terminal.version == 3)
        #expect(terminal.redactedAt == terminalAt)

        #expect(throws: (any Error).self) {
            try fixture.database.pool.write { db in
                try db.execute(
                    sql: """
                        UPDATE artifact_storage_origin
                        SET version=version+1 WHERE artifactId=?
                        """,
                    arguments: [artifactID]
                )
            }
        }
        #expect(throws: (any Error).self) {
            try fixture.database.pool.write { db in
                try db.execute(
                    sql: "DELETE FROM artifact_storage_origin WHERE artifactId=?",
                    arguments: [artifactID]
                )
            }
        }
        let locked = try fixture.database.pool.read { db in
            let fetched = try ArtifactStorageOriginRecord.fetchOne(
                db,
                key: artifactID
            )
            return try #require(fetched)
        }
        #expect(locked == terminal)
    }
}
