import Foundation
import GRDB
import Testing
import AgentLoopCore

private let p1f1ArtifactNow = Date(timeIntervalSince1970: 4_100_000)

private enum P1F1InjectedArtifactCrash: Error, Equatable {
    case preparation(ArtifactPreparationCheckpointV1)
}

private final class P1F1ArtifactCheckpointProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ArtifactPreparationCheckpointV1] = []

    func append(_ checkpoint: ArtifactPreparationCheckpointV1) {
        lock.lock()
        storage.append(checkpoint)
        lock.unlock()
    }

    var values: [ArtifactPreparationCheckpointV1] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class P1F1StagingCleanupProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ArtifactStagingCleanupObservationV1] = []

    func append(_ observation: ArtifactStagingCleanupObservationV1) {
        lock.lock()
        storage.append(observation)
        lock.unlock()
    }

    var values: [ArtifactStagingCleanupObservationV1] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class P1F1StagingDirectoryReplacement: @unchecked Sendable {
    private let lock = NSLock()
    private let stagingChild: URL
    private let movedOutside: URL
    private var replacementCount = 0

    init(stagingChild: URL, movedOutside: URL) {
        self.stagingChild = stagingChild
        self.movedOutside = movedOutside
    }

    func replace(
        at checkpoint: ArtifactStagingCleanupCheckpointV1
    ) throws {
        guard checkpoint == .afterDirectoryOpenBeforeTraversal(
            relativePath: ".staging/orphan"
        ) else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        replacementCount += 1
        try FileManager.default.moveItem(
            at: stagingChild,
            to: movedOutside
        )
        try FileManager.default.createSymbolicLink(
            at: stagingChild,
            withDestinationURL: movedOutside
        )
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return replacementCount
    }
}

private struct P1F1ArtifactBlobFixture {
    let engine: P1F1EngineFixture
    let root: URL
    let workspaceRoot: URL
    let artifactRoot: URL
    let stateLock: StateDirectoryLock
    let blobStore: ArtifactBlobStore

    init(
        cleanupCheckpoint:
            (@Sendable (ArtifactStagingCleanupCheckpointV1) throws -> Void)?
            = nil,
        cleanupObserver:
            (@Sendable (ArtifactStagingCleanupObservationV1) -> Void)? = nil
    ) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agentloop-p1f1-artifact-\(UUID().uuidString)"
        )
        let workspaceRoot = root.appendingPathComponent("workspace")
        let artifactRoot = root.appendingPathComponent("artifact-store")
        try FileManager.default.createDirectory(
            at: workspaceRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: artifactRoot,
            withIntermediateDirectories: true
        )
        let engine = try P1F1EngineFixture()
        let stateLock = try StateDirectoryLock(directoryURL: root)
        self.engine = engine
        self.root = root
        self.workspaceRoot = workspaceRoot
        self.artifactRoot = artifactRoot
        self.stateLock = stateLock
        self.blobStore = ArtifactBlobStore(
            database: engine.db,
            artifactStoreRoot: artifactRoot,
            stateDirectoryLock: stateLock,
            cleanupCheckpoint: cleanupCheckpoint,
            cleanupObserver: cleanupObserver
        )
    }

    func stager(
        checkpoint: (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)? = nil
    ) -> ArtifactStager {
        ArtifactStager(
            database: engine.db,
            blobStore: blobStore,
            checkpoint: checkpoint
        )
    }

    func sourceURL(_ relativePath: String) -> URL {
        workspaceRoot.appendingPathComponent(relativePath)
    }

    func blobURL(_ contentHash: String) -> URL {
        artifactRoot.appendingPathComponent("blobs/\(contentHash)")
    }

    @discardableResult
    func recordProposal(
        bytes: Data,
        relativePath: String = "reports/result.md",
        suffix: String,
        cardOrdinal: Int = 0,
        writeWorkspace: Bool = true
    ) throws -> EngineTerminalProposalSnapshotV1 {
        let cardID: String
        if cardOrdinal == 0 {
            cardID = p1f1EngineCardID
        } else {
            cardID = String(
                format: "00000000-0000-4000-8000-%012d",
                100 + cardOrdinal
            )
            try engine.insertReadyCard(
                cardID,
                idemKey: "p1f1-artifact-card-\(suffix)"
            )
        }
        if writeWorkspace {
            let source = sourceURL(relativePath)
            try FileManager.default.createDirectory(
                at: source.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try bytes.write(to: source)
        }
        let context = try p1f1CanonicalEnvelope(cardID: cardID)
        let contextBytes = try CanonicalJSONV1.encode(context)
        let request = try engine.begin(
            key: "p1f1-artifact-begin-\(suffix)",
            fields: engine.fields(
                cardID: cardID,
                contextJson: String(decoding: contextBytes, as: UTF8.self),
                contextHash: CanonicalJSONV1.sha256Hex(contextBytes)
            )
        )
        let execution = try p1f1ExecutionRow(engine.db, id: request.executionId)
        _ = try engine.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: execution["version"],
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-artifact-dispatch-\(suffix)",
            now: p1f1ArtifactNow
        )
        let hash = CanonicalJSONV1.sha256Hex(bytes)
        let declaration = EngineTerminalArtifactDeclarationV1(
            ordinal: 0,
            sourceRelativePath: relativePath,
            kind: "report",
            label: "Artifact \(suffix)",
            byteCount: bytes.count,
            contentHash: hash
        )
        let content = try EngineTerminalProposalContentV1(
            protocolVersion: "agentloop.execution.v1",
            executionId: request.executionId,
            runId: request.runId,
            cardId: request.cardId,
            sequence: 0,
            terminalIdempotencyKey: "p1f1-artifact-terminal-\(suffix)",
            terminalKind: .completed,
            terminalSubtype: nil,
            payload: .completed(
                handoff: HandoffPayload(
                    outcome: "implemented",
                    summary: "artifact staging fixture",
                    artifacts: [
                        .init(
                            relativePath: relativePath,
                            kind: declaration.kind,
                            label: declaration.label
                        ),
                    ],
                    verification: [
                        .init(method: "artifact-store", passed: true, note: "atomic"),
                    ],
                    risks: []
                )
            ),
            artifacts: [declaration]
        )
        return try engine.store.recordEngineTerminalProposal(content)
    }

    @discardableResult
    func recordNoArtifactProposal(
        suffix: String
    ) throws -> EngineTerminalProposalSnapshotV1 {
        let request = try engine.begin(key: "p1f1-artifact-empty-begin-\(suffix)")
        let execution = try p1f1ExecutionRow(engine.db, id: request.executionId)
        _ = try engine.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: execution["version"],
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-artifact-empty-dispatch-\(suffix)",
            now: p1f1ArtifactNow
        )
        return try engine.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: request,
                key: "p1f1-artifact-empty-terminal-\(suffix)"
            )
        )
    }

    func insertBlob(
        bytes: Data,
        claimedHash: String? = nil,
        state: ArtifactBlobStateV1 = .available,
        version: Int = 1,
        createdAt: Date = p1f1ArtifactNow.addingTimeInterval(-25 * 60 * 60)
    ) throws -> String {
        let hash = claimedHash ?? CanonicalJSONV1.sha256Hex(bytes)
        let relativePath = state == .deletedTombstone ? "" : "blobs/\(hash)"
        if state != .deletedTombstone {
            let url = blobURL(hash)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try bytes.write(to: url)
        }
        try engine.db.pool.write { database in
            try database.execute(
                sql: """
                    INSERT INTO artifact_blob(
                      contentHash,byteCount,relativePath,state,version,
                      createdAt,verifiedAt,deletedAt
                    ) VALUES (?,?,?,?,?,?,?,?)
                    """,
                arguments: [
                    hash,
                    bytes.count,
                    relativePath,
                    state.rawValue,
                    version,
                    createdAt,
                    createdAt,
                    state == .deletedTombstone ? createdAt : nil,
                ]
            )
        }
        return hash
    }

    func attachActiveReference(
        _ proposal: EngineTerminalProposalSnapshotV1,
        contentHash: String
    ) throws {
        let proposalArtifact = try #require(proposal.artifacts.first)
        try engine.db.pool.write { database in
            let owner = try #require(
                try Row.fetchOne(
                    database,
                    sql: """
                        SELECT p.executionId,e.campId,e.cardId
                        FROM engine_terminal_proposal p
                        JOIN engine_execution e ON e.id=p.executionId
                        WHERE p.id=?
                        """,
                    arguments: [proposal.proposal.id]
                )
            )
            try database.execute(
                sql: """
                    UPDATE engine_proposal_artifact
                    SET state='prepared',preparedAt=?,version=version+1
                    WHERE id=? AND state='declared'
                    """,
                arguments: [p1f1ArtifactNow, proposalArtifact.id]
            )
            try database.execute(
                sql: """
                    UPDATE engine_terminal_proposal
                    SET state='committed',committedAt=?,version=version+1
                    WHERE id=? AND state='pending'
                    """,
                arguments: [p1f1ArtifactNow, proposal.proposal.id]
            )
            try ArtifactRecord(
                id: proposalArtifact.artifactId,
                cardId: owner["cardId"],
                path: blobURL(contentHash).path,
                kind: proposalArtifact.kind,
                label: proposalArtifact.label,
                createdAt: p1f1ArtifactNow
            ).insert(database)
            try database.execute(
                sql: """
                    INSERT INTO artifact_storage_origin(
                      artifactId,campId,state,storageClass,evidenceKind,
                      managedRootId,objectId,contentHash,fileIdentityHash,
                      originalRefHash,classificationEvidenceHash,
                      terminalDisposition,terminalAuthorityHash,version,
                      classifiedAt,redactedAt
                    ) VALUES (?,?,'active','managed','typedPreparedArtifact',
                      'artifact-root','object',?,?,?, ?,NULL,NULL,1,?,NULL)
                    """,
                arguments: [
                    proposalArtifact.artifactId,
                    owner["campId"],
                    contentHash,
                    p1f1EngineHashC,
                    p1f1EngineHashD,
                    p1f1EngineHashE,
                    p1f1ArtifactNow,
                ]
            )
            try database.execute(
                sql: """
                    INSERT INTO artifact_blob_reference(
                      artifactId,proposalArtifactId,executionId,campId,
                      contentHash,state,createdAt,tombstonedAt
                    ) VALUES (?,?,?,?,?,'active',?,NULL)
                    """,
                arguments: [
                    proposalArtifact.artifactId,
                    proposalArtifact.id,
                    owner["executionId"],
                    owner["campId"],
                    contentHash,
                    p1f1ArtifactNow,
                ]
            )
        }
    }

    func attachDeletionRoot(
        _ proposal: EngineTerminalProposalSnapshotV1,
        contentHash: String
    ) throws {
        let proposalArtifact = try #require(proposal.artifacts.first)
        try engine.db.pool.write { database in
            try database.execute(
                sql: """
                    UPDATE engine_terminal_proposal
                    SET state='committed',committedAt=?,version=version+1
                    WHERE id=? AND state='pending'
                    """,
                arguments: [p1f1ArtifactNow, proposal.proposal.id]
            )
            let lifecycleVersion = try #require(
                try Int.fetchOne(
                    database,
                    sql: "SELECT version FROM camp_lifecycle WHERE campId=?",
                    arguments: [p1f1EngineCampID]
                )
            )
            let workID = "p1f1-artifact-deletion-work"
            let jobID = "p1f1-artifact-deletion-job"
            try database.execute(
                sql: """
                    INSERT INTO durable_work(
                      id,campId,campLifecycleVersion,kind,aggregateType,
                      aggregateId,idempotencyKey,state,attempt,maxAttempts,
                      notBefore,leaseOwner,leaseExpiresAt,inputJson,inputHash,
                      outputJson,errorCode,errorMessage,traceId,version,
                      createdAt,updatedAt,finishedAt
                    ) VALUES (?, ?,?,'campDeletion','camp',?,?,'queued',0,4,
                      NULL,NULL,NULL,'{}',?,NULL,NULL,NULL,?,1,?,?,NULL)
                    """,
                arguments: [
                    workID,
                    p1f1EngineCampID,
                    lifecycleVersion,
                    p1f1EngineCampID,
                    "p1f1-artifact-deletion-idem",
                    p1f1EngineHashA,
                    "trace:p1f1:artifact-deletion",
                    p1f1ArtifactNow,
                    p1f1ArtifactNow,
                ]
            )
            try database.execute(
                sql: """
                    INSERT INTO camp_deletion_job(
                      id,campId,workId,requestIdempotencyKey,confirmationId,
                      confirmationHash,unknownArtifactDisposition,
                      requestedByActorId,state,phaseCursorJson,lastErrorCode,
                      version,createdAt,updatedAt,completedAt
                    ) VALUES (?,?,?,?,?,?,'detachOnlyNeverUnlink','user:test',
                      'requested','{}',NULL,1,?,?,NULL)
                    """,
                arguments: [
                    jobID,
                    p1f1EngineCampID,
                    workID,
                    "p1f1-artifact-delete-request",
                    "p1f1-artifact-delete-confirmation",
                    p1f1EngineHashB,
                    p1f1ArtifactNow,
                    p1f1ArtifactNow,
                ]
            )
            try database.execute(
                sql: """
                    INSERT INTO camp_deletion_proposal_blob(
                      id,jobId,campId,proposalArtifactId,contentHash,
                      expectedBlobVersion,state,attempt,lastErrorCode,version,
                      createdAt,reservedAt,finishedAt
                    ) VALUES (?,?,?,?,?,1,'pending',0,NULL,1,?,NULL,NULL)
                    """,
                arguments: [
                    "p1f1-artifact-deletion-blob",
                    jobID,
                    p1f1EngineCampID,
                    proposalArtifact.id,
                    contentHash,
                    p1f1ArtifactNow,
                ]
            )
        }
    }

    func proposalArtifactState(
        _ proposal: EngineTerminalProposalSnapshotV1
    ) throws -> String {
        try engine.db.pool.read { database in
            try #require(
                try String.fetchOne(
                    database,
                    sql: """
                        SELECT state FROM engine_proposal_artifact
                        WHERE proposalId=?
                        """,
                    arguments: [proposal.proposal.id]
                )
            )
        }
    }
}

private func p1f1RequireRealPreparationFailure(
    _ operation: () throws -> Void
) throws {
    do {
        try operation()
        Issue.record("artifact preparation should fail")
    } catch {
        return
    }
}

@Suite(.serialized)
struct P1F1ArtifactBlobStoreTests {
    @Test func p1f1_043ExistingBlobVerifiedBeforeWorkspaceRead() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let bytes = Data("immutable existing blob".utf8)
        let proposal = try fixture.recordProposal(
            bytes: bytes,
            suffix: "043",
            writeWorkspace: false
        )
        let hash = try fixture.insertBlob(bytes: bytes)

        let prepared = try fixture.stager().prepare(
            proposalId: proposal.proposal.id,
            workspaceRoot: fixture.workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )

        #expect(prepared.map(\.contentHash) == [hash])
        #expect(try fixture.proposalArtifactState(proposal) == "prepared")
        #expect(!FileManager.default.fileExists(
            atPath: fixture.sourceURL("reports/result.md").path
        ))
        #expect(try Data(contentsOf: fixture.blobURL(hash)) == bytes)
    }

    @Test func p1f1_044WorkspaceSourceScopeSizeHashValidated() throws {
        let valid = try P1F1ArtifactBlobFixture()
        let bytes = Data("valid workspace source".utf8)
        let validProposal = try valid.recordProposal(bytes: bytes, suffix: "044-valid")
        let prepared = try valid.stager().prepare(
            proposalId: validProposal.proposal.id,
            workspaceRoot: valid.workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )
        #expect(prepared.map(\.contentHash) == [CanonicalJSONV1.sha256Hex(bytes)])

        for variant in ["scope", "size", "hash", "symlink"] {
            let fixture = try P1F1ArtifactBlobFixture()
            let proposal = try fixture.recordProposal(
                bytes: bytes,
                suffix: "044-\(variant)"
            )
            let source = fixture.sourceURL("reports/result.md")
            var workspaceHash = p1f1EngineWorkspaceHash
            switch variant {
            case "scope":
                workspaceHash = p1f1EngineHashF
            case "size":
                try Data("different-sized-workspace-source".utf8).write(to: source)
            case "hash":
                try Data(repeating: 0x78, count: bytes.count).write(to: source)
            case "symlink":
                let outside = fixture.root.appendingPathComponent("outside.txt")
                try bytes.write(to: outside)
                try FileManager.default.removeItem(at: source)
                try FileManager.default.createSymbolicLink(
                    at: source,
                    withDestinationURL: outside
                )
            default:
                Issue.record("unexpected variant")
            }
            try p1f1RequireRealPreparationFailure {
                _ = try fixture.stager().prepare(
                    proposalId: proposal.proposal.id,
                    workspaceRoot: fixture.workspaceRoot,
                    expectedWorkspaceHash: workspaceHash
                )
            }
            #expect(try fixture.proposalArtifactState(proposal) == "declared")
            #expect(!FileManager.default.fileExists(
                atPath: fixture.blobURL(CanonicalJSONV1.sha256Hex(bytes)).path
            ))
        }
    }

    @Test func p1f1_045StagingFsyncRenameThenReferenceCommit() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let bytes = Data("ordered staging bytes".utf8)
        let proposal = try fixture.recordProposal(bytes: bytes, suffix: "045")
        let probe = P1F1ArtifactCheckpointProbe()
        let prepared = try fixture.stager { probe.append($0) }.prepare(
            proposalId: proposal.proposal.id,
            workspaceRoot: fixture.workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )

        #expect(probe.values == [
            .afterTemporaryCreate,
            .afterTemporaryFileSync,
            .afterBlobRename,
            .afterBlobDirectorySync,
            .beforeDatabaseMutation,
            .afterBlobUpsert,
            .afterProposalArtifactCAS,
        ])
        let hash = CanonicalJSONV1.sha256Hex(bytes)
        #expect(prepared.map(\.contentHash) == [hash])
        #expect(try fixture.proposalArtifactState(proposal) == "prepared")
        #expect(try Data(contentsOf: fixture.blobURL(hash)) == bytes)
    }

    @Test func p1f1_046RenameBeforeRowCrashRecovers() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let bytes = Data("rename-before-row bytes".utf8)
        let proposal = try fixture.recordProposal(bytes: bytes, suffix: "046")
        let hash = CanonicalJSONV1.sha256Hex(bytes)
        let finalURL = fixture.blobURL(hash)
        try FileManager.default.createDirectory(
            at: finalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: finalURL)

        let recovered = try fixture.stager().recoverPreparation(
            proposalId: proposal.proposal.id,
            workspaceRoot: fixture.workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )

        #expect(recovered.map(\.contentHash) == [hash])
        #expect(try fixture.proposalArtifactState(proposal) == "prepared")
        #expect(try fixture.engine.db.pool.read { database in
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM artifact_blob WHERE contentHash=? AND state='available'",
                arguments: [hash]
            )
        } == 1)

        let cleanupProbe = P1F1StagingCleanupProbe()
        let cleanupFixture = try P1F1ArtifactBlobFixture(
            cleanupObserver: { cleanupProbe.append($0) }
        )
        let staging = cleanupFixture.artifactRoot
            .appendingPathComponent(".staging")
        let nested = staging.appendingPathComponent("nested")
        try FileManager.default.createDirectory(
            at: nested,
            withIntermediateDirectories: true
        )
        try Data("top-level orphan".utf8).write(
            to: staging.appendingPathComponent("a.tmp")
        )
        try Data("nested orphan".utf8).write(
            to: nested.appendingPathComponent("b.tmp")
        )

        try cleanupFixture.stager().cleanOrphanedStaging()

        #expect(cleanupProbe.values == [
            .afterUnlink(relativePath: ".staging/a.tmp"),
            .afterParentDirectorySync(relativePath: ".staging"),
            .afterUnlink(relativePath: ".staging/nested/b.tmp"),
            .afterParentDirectorySync(relativePath: ".staging/nested"),
            .afterRemoveDirectory(relativePath: ".staging/nested"),
            .afterParentDirectorySync(relativePath: ".staging"),
        ])

        let raceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentloop-p1f1-cleanup-race-\(UUID().uuidString)"
            )
        let raceArtifactRoot = raceRoot.appendingPathComponent("artifact-store")
        let raceStagingChild = raceArtifactRoot
            .appendingPathComponent(".staging/orphan")
        let movedOutside = raceRoot.appendingPathComponent("moved-outside")
        try FileManager.default.createDirectory(
            at: raceStagingChild,
            withIntermediateDirectories: true
        )
        let sentinel = raceStagingChild.appendingPathComponent("sentinel.txt")
        try Data("must survive namespace drift".utf8).write(to: sentinel)
        let replacement = P1F1StagingDirectoryReplacement(
            stagingChild: raceStagingChild,
            movedOutside: movedOutside
        )
        let raceEngine = try P1F1EngineFixture()
        let raceLock = try StateDirectoryLock(directoryURL: raceRoot)
        let raceStore = ArtifactBlobStore(
            database: raceEngine.db,
            artifactStoreRoot: raceArtifactRoot,
            stateDirectoryLock: raceLock,
            cleanupCheckpoint: { try replacement.replace(at: $0) }
        )
        let raceStager = ArtifactStager(
            database: raceEngine.db,
            blobStore: raceStore
        )

        try p1f1RequireRealPreparationFailure {
            try raceStager.cleanOrphanedStaging()
        }

        #expect(replacement.count == 1)
        #expect(FileManager.default.fileExists(
            atPath: movedOutside.appendingPathComponent("sentinel.txt").path
        ))
    }

    @Test func p1f1_047PrepareCrashWindowsNeverReferenceMissingBlob() throws {
        let checkpoints: [ArtifactPreparationCheckpointV1] = [
            .afterTemporaryCreate,
            .afterTemporaryFileSync,
            .afterBlobRename,
            .afterBlobDirectorySync,
            .beforeDatabaseMutation,
            .afterBlobUpsert,
            .afterProposalArtifactCAS,
        ]
        for (index, checkpoint) in checkpoints.enumerated() {
            let fixture = try P1F1ArtifactBlobFixture()
            let bytes = Data("crash-window-\(index)".utf8)
            let proposal = try fixture.recordProposal(
                bytes: bytes,
                suffix: "047-\(index)"
            )
            do {
                _ = try fixture.stager { observed in
                    if observed == checkpoint {
                        throw P1F1InjectedArtifactCrash.preparation(observed)
                    }
                }.prepare(
                    proposalId: proposal.proposal.id,
                    workspaceRoot: fixture.workspaceRoot,
                    expectedWorkspaceHash: p1f1EngineWorkspaceHash
                )
                Issue.record("checkpoint \(checkpoint) should interrupt preparation")
            } catch let error as P1F1InjectedArtifactCrash {
                #expect(error == .preparation(checkpoint))
            }
            #expect(try fixture.engine.db.pool.read { database in
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*)
                        FROM engine_proposal_artifact pa
                        LEFT JOIN artifact_blob b ON b.contentHash=pa.contentHash
                        WHERE pa.proposalId=? AND pa.state='prepared'
                          AND (b.contentHash IS NULL OR b.state<>'available')
                        """,
                    arguments: [proposal.proposal.id]
                )
            } == 0)
            let recovered = try fixture.stager().recoverPreparation(
                proposalId: proposal.proposal.id,
                workspaceRoot: fixture.workspaceRoot,
                expectedWorkspaceHash: p1f1EngineWorkspaceHash
            )
            #expect(recovered.count == 1)
            #expect(try fixture.proposalArtifactState(proposal) == "prepared")
        }
    }

    @Test func p1f1_048MissingOrCorruptBlobInvalidatesProposal() throws {
        for variant in ["missing", "corrupt"] {
            let fixture = try P1F1ArtifactBlobFixture()
            let bytes = Data("expected preparation bytes".utf8)
            let proposal = try fixture.recordProposal(
                bytes: bytes,
                suffix: "048-\(variant)",
                writeWorkspace: variant == "corrupt"
            )
            if variant == "corrupt" {
                _ = try fixture.insertBlob(
                    bytes: Data("corrupt immutable bytes".utf8),
                    claimedHash: CanonicalJSONV1.sha256Hex(bytes)
                )
            }
            try p1f1RequireRealPreparationFailure {
                _ = try fixture.stager().prepare(
                    proposalId: proposal.proposal.id,
                    workspaceRoot: fixture.workspaceRoot,
                    expectedWorkspaceHash: p1f1EngineWorkspaceHash
                )
            }
            let receipt = try fixture.engine.store.invalidateProposalAndCommitProtocolError(
                proposalId: proposal.proposal.id,
                expectedVersion: proposal.proposal.version,
                failure: EngineTerminalPreparationFailure(
                    reasonCode: "artifact_preparation_failed",
                    detail: "\(variant) artifact bytes"
                ),
                commandIdempotencyKey: "engine.terminal.v1:p1f1-artifact-invalid-\(variant)",
                now: p1f1ArtifactNow.addingTimeInterval(1)
            )
            #expect(receipt.disposition == .invalidProtocolError)
            #expect(try fixture.engine.db.pool.read { database in
                try String.fetchOne(
                    database,
                    sql: "SELECT state FROM engine_terminal_proposal WHERE id=?",
                    arguments: [proposal.proposal.id]
                )
            } == "invalid")
            #expect(try fixture.proposalArtifactState(proposal) == "declared")
        }
    }

    @Test func p1f1_049GCUsesExactThreeContentHashRootSets() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let pendingBytes = Data("pending proposal root".utf8)
        let activeBytes = Data("active reference root".utf8)
        let deletionBytes = Data("deletion proposal root".utf8)
        let unrootedBytes = Data("unrooted collectible blob".utf8)
        let pending = try fixture.recordProposal(
            bytes: pendingBytes,
            suffix: "049-pending"
        )
        let active = try fixture.recordProposal(
            bytes: activeBytes,
            suffix: "049-active",
            cardOrdinal: 1
        )
        let deletion = try fixture.recordProposal(
            bytes: deletionBytes,
            suffix: "049-deletion",
            cardOrdinal: 2
        )
        let pendingHash = try fixture.insertBlob(bytes: pendingBytes)
        let activeHash = try fixture.insertBlob(bytes: activeBytes)
        let deletionHash = try fixture.insertBlob(bytes: deletionBytes)
        let unrootedHash = try fixture.insertBlob(bytes: unrootedBytes)
        try fixture.attachActiveReference(active, contentHash: activeHash)
        try fixture.attachDeletionRoot(deletion, contentHash: deletionHash)

        let receipt = try fixture.blobStore.collectGarbage(now: p1f1ArtifactNow)

        #expect(receipt.retainedContentHashes == [
            pendingHash, activeHash, deletionHash,
        ].sorted())
        #expect(receipt.deletedContentHashes == [unrootedHash])
        #expect(FileManager.default.fileExists(atPath: fixture.blobURL(pendingHash).path))
        #expect(FileManager.default.fileExists(atPath: fixture.blobURL(activeHash).path))
        #expect(FileManager.default.fileExists(atPath: fixture.blobURL(deletionHash).path))
        #expect(!FileManager.default.fileExists(atPath: fixture.blobURL(unrootedHash).path))
        #expect(pending.proposal.state == .pending)
    }

    @Test func p1f1_050ProposalHashNeverKeepsBlobAlive() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let proposal = try fixture.recordNoArtifactProposal(suffix: "050")
        let proposalBytes = Data(proposal.proposal.proposalJson.utf8)
        #expect(CanonicalJSONV1.sha256Hex(proposalBytes) == proposal.proposal.proposalHash)
        _ = try fixture.insertBlob(
            bytes: proposalBytes,
            claimedHash: proposal.proposal.proposalHash
        )

        let receipt = try fixture.blobStore.collectGarbage(now: p1f1ArtifactNow)

        #expect(receipt.deletedContentHashes == [proposal.proposal.proposalHash])
        #expect(!FileManager.default.fileExists(
            atPath: fixture.blobURL(proposal.proposal.proposalHash).path
        ))
    }

    @Test func p1f1_051SharedBlobAndAgeBoundaryRetained() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let sharedBytes = Data("shared live bytes".utf8)
        let sharedA = try fixture.recordProposal(
            bytes: sharedBytes,
            suffix: "051-shared-a"
        )
        let sharedB = try fixture.recordProposal(
            bytes: sharedBytes,
            relativePath: "reports/shared-b.md",
            suffix: "051-shared-b",
            cardOrdinal: 1
        )
        let sharedHash = try fixture.insertBlob(bytes: sharedBytes)
        try fixture.attachActiveReference(sharedA, contentHash: sharedHash)
        try fixture.attachActiveReference(sharedB, contentHash: sharedHash)
        let freshBytes = Data("fresh unrooted bytes".utf8)
        let freshHash = try fixture.insertBlob(
            bytes: freshBytes,
            createdAt: p1f1ArtifactNow.addingTimeInterval(-24 * 60 * 60 + 1)
        )
        let boundaryBytes = Data("exact boundary bytes".utf8)
        let boundaryHash = try fixture.insertBlob(
            bytes: boundaryBytes,
            createdAt: p1f1ArtifactNow.addingTimeInterval(-24 * 60 * 60)
        )

        let receipt = try fixture.blobStore.collectGarbage(now: p1f1ArtifactNow)

        #expect(receipt.retainedContentHashes == [sharedHash, freshHash].sorted())
        #expect(receipt.deletedContentHashes == [boundaryHash])
        #expect(FileManager.default.fileExists(atPath: fixture.blobURL(sharedHash).path))
        #expect(FileManager.default.fileExists(atPath: fixture.blobURL(freshHash).path))
        #expect(!FileManager.default.fileExists(atPath: fixture.blobURL(boundaryHash).path))
    }

    @Test func p1f1_052DeletedTombstoneRestagesBytesWithCAS() throws {
        let fixture = try P1F1ArtifactBlobFixture()
        let bytes = Data("restaged tombstone bytes".utf8)
        let proposal = try fixture.recordProposal(bytes: bytes, suffix: "052")
        let hash = try fixture.insertBlob(
            bytes: bytes,
            state: .deletedTombstone,
            version: 7
        )

        let prepared = try fixture.stager().prepare(
            proposalId: proposal.proposal.id,
            workspaceRoot: fixture.workspaceRoot,
            expectedWorkspaceHash: p1f1EngineWorkspaceHash
        )

        #expect(prepared.map(\.contentHash) == [hash])
        let row = try fixture.engine.db.pool.read { database in
            try #require(
                try Row.fetchOne(
                    database,
                    sql: """
                        SELECT state,version,relativePath,deletedAt
                        FROM artifact_blob WHERE contentHash=?
                        """,
                    arguments: [hash]
                )
            )
        }
        #expect((row["state"] as String) == "available")
        #expect((row["version"] as Int) == 8)
        #expect((row["relativePath"] as String) == "blobs/\(hash)")
        #expect((row["deletedAt"] as Date?) == nil)
        #expect(try Data(contentsOf: fixture.blobURL(hash)) == bytes)
        #expect(try fixture.proposalArtifactState(proposal) == "prepared")
    }
}
