import Darwin
import Foundation
import GRDB

package struct PreparedArtifactV1: Sendable, Equatable {
    package let proposalId: String
    package let proposalArtifactId: String
    package let artifactId: String
    package let executionId: String
    package let cardId: String
    package let campId: String
    package let ordinal: Int
    package let kind: String
    package let label: String
    package let byteCount: Int
    package let contentHash: String
    package let blobRelativePath: String
    package let managedRootId: String
    package let objectId: String
    package let fileIdentityHash: String
    package let proposalArtifactVersion: Int
    package let blobVersion: Int
    package let preparedAt: Date

    fileprivate init(
        proposalId: String,
        proposalArtifactId: String,
        artifactId: String,
        executionId: String,
        cardId: String,
        campId: String,
        ordinal: Int,
        kind: String,
        label: String,
        byteCount: Int,
        contentHash: String,
        blobRelativePath: String,
        managedRootId: String,
        objectId: String,
        fileIdentityHash: String,
        proposalArtifactVersion: Int,
        blobVersion: Int,
        preparedAt: Date
    ) {
        self.proposalId = proposalId
        self.proposalArtifactId = proposalArtifactId
        self.artifactId = artifactId
        self.executionId = executionId
        self.cardId = cardId
        self.campId = campId
        self.ordinal = ordinal
        self.kind = kind
        self.label = label
        self.byteCount = byteCount
        self.contentHash = contentHash
        self.blobRelativePath = blobRelativePath
        self.managedRootId = managedRootId
        self.objectId = objectId
        self.fileIdentityHash = fileIdentityHash
        self.proposalArtifactVersion = proposalArtifactVersion
        self.blobVersion = blobVersion
        self.preparedAt = preparedAt
    }
}

package enum ArtifactGarbageCollectionCheckpointV1: Sendable, Equatable {
    case afterQuarantineCommit
    case afterUnlink
    case beforeTombstoneCommit
}

package enum ArtifactStagingCleanupCheckpointV1: Sendable, Equatable {
    case afterDirectoryOpenBeforeTraversal(relativePath: String)
}

package enum ArtifactStagingCleanupObservationV1: Sendable, Equatable {
    case afterUnlink(relativePath: String)
    case afterRemoveDirectory(relativePath: String)
    case afterParentDirectorySync(relativePath: String)
}

package struct ArtifactGarbageCollectionReceiptV1: Sendable, Equatable {
    package let retainedContentHashes: [String]
    package let quarantinedContentHashes: [String]
    package let deletedContentHashes: [String]
}

enum ArtifactBlobStoreErrorV1: Error, Sendable, Equatable {
    case invalidDate
    case invalidRelativePath(String)
    case fileSystem(path: String, operation: String, code: Int32)
    case irregularFile(String)
    case fileChanged(String)
    case sizeMismatch(path: String, expected: Int, actual: Int)
    case contentHashMismatch(path: String, expected: String, actual: String)
    case proposalUnavailable(String)
    case workspaceIdentityMismatch
    case proposalArtifactGraphInvalid(String)
    case blobGraphInvalid(String)
    case blobCASConflict(String)
}

private struct ArtifactPreparationRowV1 {
    let proposalId: String
    let proposalArtifactId: String
    let artifactId: String
    let executionId: String
    let cardId: String
    let campId: String
    let workspaceHash: String
    let ordinal: Int
    let sourceRelativePath: String
    let kind: String
    let label: String
    let byteCount: Int
    let contentHash: String
    let state: EngineProposalArtifactStateV1
    let version: Int
}

private struct ArtifactVerifiedFileV1 {
    let data: Data
    let objectId: String
    let fileIdentityHash: String
}

private enum ArtifactQuarantineResolutionV1 {
    case retained
    case deleted
}

package final class ArtifactBlobStore: @unchecked Sendable {
    private let database: AppDatabase
    private let artifactStoreRoot: URL
    private let stateDirectoryLock: StateDirectoryLock
    private let checkpoint:
        (@Sendable (ArtifactGarbageCollectionCheckpointV1) throws -> Void)?
    private let cleanupCheckpoint:
        (@Sendable (ArtifactStagingCleanupCheckpointV1) throws -> Void)?
    private let cleanupObserver:
        (@Sendable (ArtifactStagingCleanupObservationV1) -> Void)?
    private let operationLock = NSLock()

    package init(
        database: AppDatabase,
        artifactStoreRoot: URL,
        stateDirectoryLock: StateDirectoryLock,
        checkpoint:
            (@Sendable (ArtifactGarbageCollectionCheckpointV1) throws -> Void)?
            = nil,
        cleanupCheckpoint:
            (@Sendable (ArtifactStagingCleanupCheckpointV1) throws -> Void)?
            = nil,
        cleanupObserver:
            (@Sendable (ArtifactStagingCleanupObservationV1) -> Void)? = nil
    ) {
        self.database = database
        self.artifactStoreRoot = artifactStoreRoot.standardizedFileURL
        self.stateDirectoryLock = stateDirectoryLock
        self.checkpoint = checkpoint
        self.cleanupCheckpoint = cleanupCheckpoint
        self.cleanupObserver = cleanupObserver
    }

    package func validatePreparedArtifacts(
        proposalId: String,
        database: Database
    ) throws -> [PreparedArtifactV1] {
        try withExclusiveAccess {
            try validatePreparedArtifactsUnlocked(
                proposalId: proposalId,
                database: database
            )
        }
    }

    package func collectGarbage(
        now: Date
    ) throws -> ArtifactGarbageCollectionReceiptV1 {
        try withExclusiveAccess {
            guard now.timeIntervalSinceReferenceDate.isFinite else {
                throw ArtifactBlobStoreErrorV1.invalidDate
            }
            var retained = Set<String>()
            var deleted = Set<String>()
            let recovered = try recoverQuarantinedUnlocked(now: now)
            retained.formUnion(recovered.retainedContentHashes)
            deleted.formUnion(recovered.deletedContentHashes)

            let roots = try database.pool.read { db in
                try garbageCollectionRoots(database: db)
            }
            let records = try database.pool.read { db in
                try ArtifactBlobRecord
                    .order(Column("contentHash"))
                    .fetchAll(db)
            }
            let cutoff = now.addingTimeInterval(-24 * 60 * 60)
            for record in records where record.state == .available {
                if roots.contains(record.contentHash) || record.createdAt > cutoff {
                    retained.insert(record.contentHash)
                    continue
                }
                let quarantined = try database.pool.write { db -> Bool in
                    if try isGarbageCollectionRoot(
                        record.contentHash,
                        database: db
                    ) {
                        return false
                    }
                    try db.execute(
                        sql: """
                            UPDATE artifact_blob
                            SET state='quarantined',version=version+1
                            WHERE contentHash=? AND state='available'
                              AND version=? AND relativePath=?
                            """,
                        arguments: [
                            record.contentHash,
                            record.version,
                            record.relativePath,
                        ]
                    )
                    guard db.changesCount == 1 else {
                        throw ArtifactBlobStoreErrorV1.blobCASConflict(
                            record.contentHash
                        )
                    }
                    return true
                }
                guard quarantined else {
                    retained.insert(record.contentHash)
                    continue
                }
                try checkpoint?(.afterQuarantineCommit)
                switch try finalizeQuarantined(
                    record,
                    expectedVersion: record.version + 1,
                    now: now,
                    allowMissing: false
                ) {
                case .retained:
                    retained.insert(record.contentHash)
                case .deleted:
                    deleted.insert(record.contentHash)
                }
            }
            return receipt(retained: retained, deleted: deleted)
        }
    }

    package func recoverQuarantined(
        now: Date
    ) throws -> ArtifactGarbageCollectionReceiptV1 {
        try withExclusiveAccess {
            guard now.timeIntervalSinceReferenceDate.isFinite else {
                throw ArtifactBlobStoreErrorV1.invalidDate
            }
            return try recoverQuarantinedUnlocked(now: now)
        }
    }

    func prepareArtifacts(
        proposalId: String,
        workspaceRoot: URL,
        expectedWorkspaceHash: String,
        checkpoint preparationCheckpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)?
    ) throws -> [PreparedArtifactV1] {
        try withExclusiveAccess {
            let rows = try loadPreparationRows(
                proposalId: proposalId,
                expectedWorkspaceHash: expectedWorkspaceHash
            )
            for row in rows {
                if row.state == .prepared { continue }
                try prepareOne(
                    row,
                    workspaceRoot: workspaceRoot,
                    checkpoint: preparationCheckpoint
                )
            }
            return try database.pool.read { db in
                try validatePreparedArtifactsUnlocked(
                    proposalId: proposalId,
                    database: db
                )
            }
        }
    }

    func cleanOrphanedStagingFiles() throws {
        try withExclusiveAccess {
            let rootFD = try openArtifactStoreRootDirectory()
            defer { Darwin.close(rootFD) }
            let stagingFD: Int32
            do {
                stagingFD = try openDirectoryComponent(
                    ".staging",
                    parentFD: rootFD
                )
            } catch let error as ArtifactBlobStoreErrorV1 {
                if case let .fileSystem(_, operation, code) = error,
                   operation == "openat", code == ENOENT
                {
                    return
                }
                throw error
            }
            defer { Darwin.close(stagingFD) }
            try removeDirectoryContentsNoFollow(
                directoryFD: stagingFD,
                relativePath: ".staging"
            )
        }
    }

    private func withExclusiveAccess<T>(
        _ body: () throws -> T
    ) throws -> T {
        operationLock.lock()
        defer { operationLock.unlock() }
        try ensureArtifactStoreRoot()
        return try body()
    }

    private func ensureArtifactStoreRoot() throws {
        let stateRoot = stateDirectoryLock.lockFileURL
            .deletingLastPathComponent()
            .standardizedFileURL
        let stateComponents = stateRoot.pathComponents
        let artifactComponents = artifactStoreRoot.pathComponents
        guard artifactComponents.count > stateComponents.count,
              Array(artifactComponents.prefix(stateComponents.count))
                == stateComponents
        else {
            throw ArtifactBlobStoreErrorV1.invalidRelativePath(
                artifactStoreRoot.path
            )
        }
        var directoryFD = try openDirectory(stateRoot.path)
        defer { Darwin.close(directoryFD) }
        for component in artifactComponents.dropFirst(stateComponents.count) {
            guard component != ".", component != "..", !component.contains("/")
            else {
                throw ArtifactBlobStoreErrorV1.invalidRelativePath(
                    artifactStoreRoot.path
                )
            }
            let next = try openOrCreateDirectory(
                component,
                parentFD: directoryFD
            )
            guard Darwin.fsync(directoryFD) == 0 else {
                Darwin.close(next)
                throw fileSystemError(component, "fsync")
            }
            Darwin.close(directoryFD)
            directoryFD = next
        }
    }

    private func loadPreparationRows(
        proposalId: String,
        expectedWorkspaceHash: String
    ) throws -> [ArtifactPreparationRowV1] {
        try database.pool.read { db in
            guard let header = try Row.fetchOne(
                db,
                sql: """
                    SELECT p.state,e.requestJson,e.requestHash
                    FROM engine_terminal_proposal p
                    JOIN engine_execution e ON e.id=p.executionId
                    WHERE p.id=?
                    """,
                arguments: [proposalId]
            ), (header["state"] as String) == "pending"
            else {
                throw ArtifactBlobStoreErrorV1.proposalUnavailable(proposalId)
            }
            let requestJSON: String = header["requestJson"]
            let requestHash: String = header["requestHash"]
            let requestBytes = Data(requestJSON.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: requestBytes)
            guard CanonicalJSONV1.sha256Hex(requestBytes) == requestHash else {
                throw ArtifactBlobStoreErrorV1.proposalArtifactGraphInvalid(
                    proposalId
                )
            }
            let request = try CanonicalContractCodingV1.decode(
                EngineExecutionRequest.self,
                from: requestBytes
            )
            try request.validateCanonicalIdentity()
            let workspaceHash = request.workspace.hash
            guard workspaceHash == expectedWorkspaceHash else {
                throw ArtifactBlobStoreErrorV1.workspaceIdentityMismatch
            }
            let rawRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT p.id AS proposalId,pa.id AS proposalArtifactId,
                           pa.artifactId,p.executionId,e.cardId,e.campId,
                           pa.ordinal,pa.sourceRelativePath,
                           pa.kind,pa.label,pa.byteCount,pa.contentHash,
                           pa.state,pa.version
                    FROM engine_terminal_proposal p
                    JOIN engine_execution e ON e.id=p.executionId
                    JOIN engine_proposal_artifact pa ON pa.proposalId=p.id
                    WHERE p.id=?
                    ORDER BY pa.ordinal
                    """,
                arguments: [proposalId]
            )
            let rows = try rawRows.map { raw -> ArtifactPreparationRowV1 in
                let rawState: String = raw["state"]
                guard let state = EngineProposalArtifactStateV1(
                    rawValue: rawState
                ) else {
                    throw ArtifactBlobStoreErrorV1.proposalArtifactGraphInvalid(
                        proposalId
                    )
                }
                return ArtifactPreparationRowV1(
                    proposalId: raw["proposalId"],
                    proposalArtifactId: raw["proposalArtifactId"],
                    artifactId: raw["artifactId"],
                    executionId: raw["executionId"],
                    cardId: raw["cardId"],
                    campId: raw["campId"],
                    workspaceHash: workspaceHash,
                    ordinal: raw["ordinal"],
                    sourceRelativePath: raw["sourceRelativePath"],
                    kind: raw["kind"],
                    label: raw["label"],
                    byteCount: raw["byteCount"],
                    contentHash: raw["contentHash"],
                    state: state,
                    version: raw["version"]
                )
            }
            guard rows.enumerated().allSatisfy({ index, row in
                row.ordinal == index
                    && row.workspaceHash == expectedWorkspaceHash
                    && row.proposalId == proposalId
            }) else {
                throw ArtifactBlobStoreErrorV1.proposalArtifactGraphInvalid(
                    proposalId
                )
            }
            return rows
        }
    }

    private func prepareOne(
        _ row: ArtifactPreparationRowV1,
        workspaceRoot: URL,
        checkpoint preparationCheckpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)?
    ) throws {
        let relativeBlobPath = "blobs/\(row.contentHash)"
        let blobRecord = try database.pool.read { db in
            try ArtifactBlobRecord.fetchOne(db, key: row.contentHash)
        }
        let existingFile = try readRegularFileIfPresent(
            root: artifactStoreRoot,
            relativePath: relativeBlobPath,
            expectedSize: row.byteCount,
            expectedHash: row.contentHash
        )

        switch blobRecord?.state {
        case .available:
            guard let blobRecord,
                  blobRecord.relativePath == relativeBlobPath,
                  blobRecord.byteCount == row.byteCount,
                  existingFile != nil
            else {
                throw ArtifactBlobStoreErrorV1.blobGraphInvalid(row.contentHash)
            }
            try commitPreparedArtifact(
                row,
                blobRecord: blobRecord,
                preparedAt: Date(),
                checkpoint: preparationCheckpoint
            )
        case .quarantined:
            throw ArtifactBlobStoreErrorV1.blobGraphInvalid(row.contentHash)
        case .deletedTombstone, nil:
            if existingFile != nil {
                try commitPreparedArtifact(
                    row,
                    blobRecord: blobRecord,
                    preparedAt: Date(),
                    checkpoint: preparationCheckpoint
                )
                return
            }
            let source = try readRegularFile(
                root: workspaceRoot.standardizedFileURL,
                relativePath: row.sourceRelativePath,
                expectedSize: row.byteCount,
                expectedHash: row.contentHash
            )
            try stageBytes(
                source.data,
                executionId: row.executionId,
                artifactId: row.artifactId,
                contentHash: row.contentHash,
                checkpoint: preparationCheckpoint
            )
            try commitPreparedArtifact(
                row,
                blobRecord: blobRecord,
                preparedAt: Date(),
                checkpoint: preparationCheckpoint
            )
        }
    }

    private func commitPreparedArtifact(
        _ row: ArtifactPreparationRowV1,
        blobRecord: ArtifactBlobRecord?,
        preparedAt: Date,
        checkpoint preparationCheckpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)?
    ) throws {
        guard preparedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw ArtifactBlobStoreErrorV1.invalidDate
        }
        let relativeBlobPath = "blobs/\(row.contentHash)"
        try database.pool.write { db in
            try preparationCheckpoint?(.beforeDatabaseMutation)
            if let blobRecord {
                switch blobRecord.state {
                case .available:
                    try db.execute(
                        sql: """
                            UPDATE artifact_blob
                            SET verifiedAt=?
                            WHERE contentHash=? AND state='available'
                              AND version=? AND byteCount=? AND relativePath=?
                            """,
                        arguments: [
                            preparedAt,
                            row.contentHash,
                            blobRecord.version,
                            row.byteCount,
                            relativeBlobPath,
                        ]
                    )
                case .deletedTombstone:
                    try db.execute(
                        sql: """
                            UPDATE artifact_blob
                            SET byteCount=?,relativePath=?,state='available',
                                version=version+1,createdAt=?,verifiedAt=?,
                                deletedAt=NULL
                            WHERE contentHash=? AND state='deletedTombstone'
                              AND version=? AND relativePath=''
                            """,
                        arguments: [
                            row.byteCount,
                            relativeBlobPath,
                            preparedAt,
                            preparedAt,
                            row.contentHash,
                            blobRecord.version,
                        ]
                    )
                case .quarantined:
                    throw ArtifactBlobStoreErrorV1.blobGraphInvalid(
                        row.contentHash
                    )
                }
            } else {
                try db.execute(
                    sql: """
                        INSERT INTO artifact_blob(
                          contentHash,byteCount,relativePath,state,version,
                          createdAt,verifiedAt,deletedAt
                        ) VALUES (?, ?,?,'available',1,?,?,NULL)
                        """,
                    arguments: [
                        row.contentHash,
                        row.byteCount,
                        relativeBlobPath,
                        preparedAt,
                        preparedAt,
                    ]
                )
            }
            guard db.changesCount == 1 else {
                throw ArtifactBlobStoreErrorV1.blobCASConflict(row.contentHash)
            }
            try preparationCheckpoint?(.afterBlobUpsert)
            try db.execute(
                sql: """
                    UPDATE engine_proposal_artifact
                    SET state='prepared',preparedAt=?,version=version+1
                    WHERE id=? AND proposalId=? AND artifactId=?
                      AND state='declared' AND version=?
                    """,
                arguments: [
                    preparedAt,
                    row.proposalArtifactId,
                    row.proposalId,
                    row.artifactId,
                    row.version,
                ]
            )
            guard db.changesCount == 1 else {
                throw ArtifactBlobStoreErrorV1.blobCASConflict(
                    row.proposalArtifactId
                )
            }
            try preparationCheckpoint?(.afterProposalArtifactCAS)
        }
    }

    private func validatePreparedArtifactsUnlocked(
        proposalId: String,
        database db: Database
    ) throws -> [PreparedArtifactV1] {
        guard let proposalState = try String.fetchOne(
            db,
            sql: "SELECT state FROM engine_terminal_proposal WHERE id=?",
            arguments: [proposalId]
        ), proposalState == "pending"
        else {
            throw ArtifactBlobStoreErrorV1.proposalUnavailable(proposalId)
        }
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT p.id AS proposalId,pa.id AS proposalArtifactId,
                       pa.artifactId,p.executionId,e.cardId,e.campId,
                       pa.ordinal,pa.kind,pa.label,pa.byteCount,pa.contentHash,
                       pa.version AS proposalArtifactVersion,pa.preparedAt,
                       b.relativePath,b.version AS blobVersion,b.state AS blobState,
                       b.byteCount AS blobByteCount
                FROM engine_terminal_proposal p
                JOIN engine_execution e ON e.id=p.executionId
                JOIN engine_proposal_artifact pa ON pa.proposalId=p.id
                JOIN artifact_blob b ON b.contentHash=pa.contentHash
                WHERE p.id=? AND pa.state='prepared'
                ORDER BY pa.ordinal
                """,
            arguments: [proposalId]
        )
        let expectedCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM engine_proposal_artifact WHERE proposalId=?",
            arguments: [proposalId]
        ) ?? -1
        guard rows.count == expectedCount,
              rows.enumerated().allSatisfy({ index, row in
                  (row["ordinal"] as Int) == index
              })
        else {
            throw ArtifactBlobStoreErrorV1.proposalArtifactGraphInvalid(
                proposalId
            )
        }
        return try rows.map { row in
            let hash: String = row["contentHash"]
            let relativePath: String = row["relativePath"]
            let byteCount: Int = row["byteCount"]
            let preparedAt: Date? = row["preparedAt"]
            guard (row["blobState"] as String) == "available",
                  (row["blobByteCount"] as Int) == byteCount,
                  relativePath == "blobs/\(hash)",
                  let preparedAt
            else {
                throw ArtifactBlobStoreErrorV1.blobGraphInvalid(hash)
            }
            let verified = try readRegularFile(
                root: artifactStoreRoot,
                relativePath: relativePath,
                expectedSize: byteCount,
                expectedHash: hash
            )
            return PreparedArtifactV1(
                proposalId: row["proposalId"],
                proposalArtifactId: row["proposalArtifactId"],
                artifactId: row["artifactId"],
                executionId: row["executionId"],
                cardId: row["cardId"],
                campId: row["campId"],
                ordinal: row["ordinal"],
                kind: row["kind"],
                label: row["label"],
                byteCount: byteCount,
                contentHash: hash,
                blobRelativePath: relativePath,
                managedRootId: managedRootId,
                objectId: verified.objectId,
                fileIdentityHash: verified.fileIdentityHash,
                proposalArtifactVersion: row["proposalArtifactVersion"],
                blobVersion: row["blobVersion"],
                preparedAt: preparedAt
            )
        }
    }

    private var managedRootId: String {
        "artifact-root-v1:" + CanonicalJSONV1.sha256Hex(
            Data(artifactStoreRoot.path.utf8)
        )
    }

    private func recoverQuarantinedUnlocked(
        now: Date
    ) throws -> ArtifactGarbageCollectionReceiptV1 {
        let records = try database.pool.read { db in
            try ArtifactBlobRecord
                .filter(Column("state") == ArtifactBlobStateV1.quarantined.rawValue)
                .order(Column("contentHash"))
                .fetchAll(db)
        }
        var retained = Set<String>()
        var deleted = Set<String>()
        for record in records {
            switch try finalizeQuarantined(
                record,
                expectedVersion: record.version,
                now: now,
                allowMissing: true
            ) {
            case .retained:
                retained.insert(record.contentHash)
            case .deleted:
                deleted.insert(record.contentHash)
            }
        }
        return receipt(retained: retained, deleted: deleted)
    }

    private func finalizeQuarantined(
        _ candidate: ArtifactBlobRecord,
        expectedVersion: Int,
        now: Date,
        allowMissing: Bool
    ) throws -> ArtifactQuarantineResolutionV1 {
        try database.pool.write { db in
            guard let current = try ArtifactBlobRecord.fetchOne(
                db,
                key: candidate.contentHash
            ), current.state == .quarantined,
               current.version == expectedVersion,
               current.relativePath == candidate.relativePath,
               current.byteCount == candidate.byteCount
            else {
                throw ArtifactBlobStoreErrorV1.blobCASConflict(
                    candidate.contentHash
                )
            }
            if try isGarbageCollectionRoot(current.contentHash, database: db) {
                guard try readRegularFileIfPresent(
                    root: artifactStoreRoot,
                    relativePath: current.relativePath,
                    expectedSize: current.byteCount,
                    expectedHash: current.contentHash
                ) != nil else {
                    throw ArtifactBlobStoreErrorV1.blobGraphInvalid(
                        current.contentHash
                    )
                }
                try db.execute(
                    sql: """
                        UPDATE artifact_blob
                        SET state='available',version=version+1,verifiedAt=?
                        WHERE contentHash=? AND state='quarantined'
                          AND version=?
                        """,
                    arguments: [now, current.contentHash, current.version]
                )
                guard db.changesCount == 1 else {
                    throw ArtifactBlobStoreErrorV1.blobCASConflict(
                        current.contentHash
                    )
                }
                return .retained
            }
            try unlinkQuarantinedBlobBoundToVerifiedDescriptor(
                contentHash: current.contentHash,
                byteCount: current.byteCount,
                relativePath: current.relativePath,
                allowMissing: allowMissing
            )
            try checkpoint?(.afterUnlink)
            try checkpoint?(.beforeTombstoneCommit)
            try db.execute(
                sql: """
                    UPDATE artifact_blob
                    SET state='deletedTombstone',relativePath='',
                        deletedAt=?,version=version+1
                    WHERE contentHash=? AND state='quarantined' AND version=?
                    """,
                arguments: [now, current.contentHash, current.version]
            )
            guard db.changesCount == 1 else {
                throw ArtifactBlobStoreErrorV1.blobCASConflict(
                    current.contentHash
                )
            }
            return .deleted
        }
    }

    private func garbageCollectionRoots(
        database db: Database
    ) throws -> Set<String> {
        Set(try String.fetchAll(
            db,
            sql: """
                SELECT pa.contentHash
                FROM engine_proposal_artifact pa
                JOIN engine_terminal_proposal p ON p.id=pa.proposalId
                WHERE p.state='pending' AND pa.state IN ('declared','prepared')
                UNION
                SELECT contentHash FROM artifact_blob_reference
                WHERE state='active'
                UNION
                SELECT contentHash FROM camp_deletion_proposal_blob
                WHERE state IN (
                  'pending','reserved','unlinkReady','retryableFailure'
                )
                """
        ))
    }

    private func isGarbageCollectionRoot(
        _ contentHash: String,
        database db: Database
    ) throws -> Bool {
        try Bool.fetchOne(
            db,
            sql: """
                SELECT EXISTS(
                  SELECT 1
                  FROM engine_proposal_artifact pa
                  JOIN engine_terminal_proposal p ON p.id=pa.proposalId
                  WHERE pa.contentHash=? AND p.state='pending'
                    AND pa.state IN ('declared','prepared')
                  UNION ALL
                  SELECT 1 FROM artifact_blob_reference
                  WHERE contentHash=? AND state='active'
                  UNION ALL
                  SELECT 1 FROM camp_deletion_proposal_blob
                  WHERE contentHash=? AND state IN (
                    'pending','reserved','unlinkReady','retryableFailure'
                  )
                )
                """,
            arguments: [contentHash, contentHash, contentHash]
        ) ?? false
    }

    private func receipt(
        retained: Set<String>,
        deleted: Set<String>
    ) -> ArtifactGarbageCollectionReceiptV1 {
        ArtifactGarbageCollectionReceiptV1(
            retainedContentHashes: retained.sorted(),
            quarantinedContentHashes: [],
            deletedContentHashes: deleted.sorted()
        )
    }

    private func stageBytes(
        _ bytes: Data,
        executionId: String,
        artifactId: String,
        contentHash: String,
        checkpoint preparationCheckpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)?
    ) throws {
        let rootFD = try openDirectory(artifactStoreRoot.path)
        defer { Darwin.close(rootFD) }
        let stagingFD = try openOrCreateDirectory(".staging", parentFD: rootFD)
        defer { Darwin.close(stagingFD) }
        let executionFD = try openOrCreateDirectory(
            executionId,
            parentFD: stagingFD
        )
        defer { Darwin.close(executionFD) }
        let blobFD = try openOrCreateDirectory("blobs", parentFD: rootFD)
        defer { Darwin.close(blobFD) }
        let temporaryName = "\(artifactId).tmp"
        let temporaryFD = temporaryName.withCString { name in
            Darwin.openat(
                executionFD,
                name,
                O_CREAT | O_TRUNC | O_WRONLY | O_CLOEXEC | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
        guard temporaryFD >= 0 else {
            throw fileSystemError(temporaryName, "openat")
        }
        do {
            try writeAll(bytes, descriptor: temporaryFD, path: temporaryName)
            try preparationCheckpoint?(.afterTemporaryCreate)
            guard Darwin.fsync(temporaryFD) == 0 else {
                throw fileSystemError(temporaryName, "fsync")
            }
            try preparationCheckpoint?(.afterTemporaryFileSync)
        } catch {
            Darwin.close(temporaryFD)
            throw error
        }
        Darwin.close(temporaryFD)
        let renamed = temporaryName.withCString { temporary in
            contentHash.withCString { final in
                Darwin.renameat(executionFD, temporary, blobFD, final)
            }
        }
        guard renamed == 0 else {
            throw fileSystemError(temporaryName, "renameat")
        }
        try preparationCheckpoint?(.afterBlobRename)
        guard Darwin.fsync(blobFD) == 0 else {
            throw fileSystemError("blobs", "fsync")
        }
        try preparationCheckpoint?(.afterBlobDirectorySync)
    }

    private func unlinkQuarantinedBlobBoundToVerifiedDescriptor(
        contentHash: String,
        byteCount: Int,
        relativePath: String,
        allowMissing: Bool
    ) throws {
        guard relativePath == "blobs/\(contentHash)" else {
            throw ArtifactBlobStoreErrorV1.blobGraphInvalid(contentHash)
        }
        let rootFD = try openDirectory(artifactStoreRoot.path)
        defer { Darwin.close(rootFD) }
        let blobFD = try openDirectoryComponent("blobs", parentFD: rootFD)
        defer { Darwin.close(blobFD) }
        let descriptor = contentHash.withCString { name in
            Darwin.openat(
                blobFD,
                name,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        if descriptor < 0, errno == ENOENT, allowMissing { return }
        guard descriptor >= 0 else {
            throw fileSystemError(relativePath, "openat")
        }
        defer { Darwin.close(descriptor) }
        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0 else {
            throw fileSystemError(relativePath, "fstat")
        }
        guard before.st_mode & S_IFMT == S_IFREG else {
            throw ArtifactBlobStoreErrorV1.irregularFile(relativePath)
        }
        guard before.st_size >= 0,
              before.st_size <= Int64(Int.max),
              Int(before.st_size) == byteCount
        else {
            throw ArtifactBlobStoreErrorV1.sizeMismatch(
                path: relativePath,
                expected: byteCount,
                actual: before.st_size >= 0 && before.st_size <= Int64(Int.max)
                    ? Int(before.st_size) : -1
            )
        }
        let bytes = try readAll(
            descriptor: descriptor,
            expectedSize: byteCount,
            path: relativePath
        )
        let actualHash = CanonicalJSONV1.sha256Hex(bytes)
        guard actualHash == contentHash else {
            throw ArtifactBlobStoreErrorV1.contentHashMismatch(
                path: relativePath,
                expected: contentHash,
                actual: actualHash
            )
        }
        var afterRead = stat()
        guard Darwin.fstat(descriptor, &afterRead) == 0 else {
            throw fileSystemError(relativePath, "fstat")
        }
        guard sameFileSnapshot(before, afterRead) else {
            throw ArtifactBlobStoreErrorV1.fileChanged(relativePath)
        }
        var pathSnapshot = stat()
        let status = contentHash.withCString { name in
            Darwin.fstatat(blobFD, name, &pathSnapshot, AT_SYMLINK_NOFOLLOW)
        }
        guard status == 0,
              pathSnapshot.st_mode & S_IFMT == S_IFREG,
              sameFileSnapshot(afterRead, pathSnapshot)
        else {
            if status != 0 { throw fileSystemError(relativePath, "fstatat") }
            throw ArtifactBlobStoreErrorV1.fileChanged(relativePath)
        }
        let result = contentHash.withCString { name in
            Darwin.unlinkat(blobFD, name, 0)
        }
        guard result == 0 else {
            throw fileSystemError(relativePath, "unlinkat")
        }
        guard Darwin.fsync(blobFD) == 0 else {
            throw fileSystemError("blobs", "fsync")
        }
    }

    private func readAll(
        descriptor: Int32,
        expectedSize: Int,
        path: String
    ) throws -> Data {
        var data = Data()
        data.reserveCapacity(expectedSize)
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                while true {
                    let value = Darwin.read(
                        descriptor,
                        rawBuffer.baseAddress,
                        rawBuffer.count
                    )
                    if value < 0, errno == EINTR { continue }
                    return value
                }
            }
            guard count >= 0 else {
                throw fileSystemError(path, "read")
            }
            if count == 0 { break }
            data.append(contentsOf: buffer[0..<count])
            guard data.count <= expectedSize else {
                throw ArtifactBlobStoreErrorV1.sizeMismatch(
                    path: path,
                    expected: expectedSize,
                    actual: data.count
                )
            }
        }
        guard data.count == expectedSize else {
            throw ArtifactBlobStoreErrorV1.sizeMismatch(
                path: path,
                expected: expectedSize,
                actual: data.count
            )
        }
        return data
    }

    private func sameFileSnapshot(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
    }

    private func readRegularFileIfPresent(
        root: URL,
        relativePath: String,
        expectedSize: Int,
        expectedHash: String
    ) throws -> ArtifactVerifiedFileV1? {
        do {
            return try readRegularFile(
                root: root,
                relativePath: relativePath,
                expectedSize: expectedSize,
                expectedHash: expectedHash
            )
        } catch let error as ArtifactBlobStoreErrorV1 {
            if case let .fileSystem(_, operation, code) = error,
               operation == "openat", code == ENOENT
            {
                return nil
            }
            throw error
        }
    }

    private func readRegularFile(
        root: URL,
        relativePath: String,
        expectedSize: Int,
        expectedHash: String
    ) throws -> ArtifactVerifiedFileV1 {
        let components = try validatedComponents(relativePath)
        let rootFD = try openDirectory(root.path)
        var directoryFD = rootFD
        defer { Darwin.close(directoryFD) }
        for component in components.dropLast() {
            let next = try openDirectoryComponent(component, parentFD: directoryFD)
            Darwin.close(directoryFD)
            directoryFD = next
        }
        guard let final = components.last else {
            throw ArtifactBlobStoreErrorV1.invalidRelativePath(relativePath)
        }
        let descriptor = final.withCString { name in
            Darwin.openat(
                directoryFD,
                name,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(relativePath, "openat")
        }
        defer { Darwin.close(descriptor) }
        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0 else {
            throw fileSystemError(relativePath, "fstat")
        }
        guard before.st_mode & S_IFMT == S_IFREG else {
            throw ArtifactBlobStoreErrorV1.irregularFile(relativePath)
        }
        guard before.st_size >= 0, before.st_size <= Int64(Int.max) else {
            throw ArtifactBlobStoreErrorV1.sizeMismatch(
                path: relativePath,
                expected: expectedSize,
                actual: -1
            )
        }
        let size = Int(before.st_size)
        guard size == expectedSize else {
            throw ArtifactBlobStoreErrorV1.sizeMismatch(
                path: relativePath,
                expected: expectedSize,
                actual: size
            )
        }
        var data = Data()
        data.reserveCapacity(size)
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                while true {
                    let value = Darwin.read(
                        descriptor,
                        rawBuffer.baseAddress,
                        rawBuffer.count
                    )
                    if value < 0, errno == EINTR { continue }
                    return value
                }
            }
            guard count >= 0 else {
                throw fileSystemError(relativePath, "read")
            }
            if count == 0 { break }
            data.append(contentsOf: buffer[0..<count])
            guard data.count <= expectedSize else {
                throw ArtifactBlobStoreErrorV1.sizeMismatch(
                    path: relativePath,
                    expected: expectedSize,
                    actual: data.count
                )
            }
        }
        var after = stat()
        guard Darwin.fstat(descriptor, &after) == 0 else {
            throw fileSystemError(relativePath, "fstat")
        }
        guard before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
        else {
            throw ArtifactBlobStoreErrorV1.fileChanged(relativePath)
        }
        guard data.count == expectedSize else {
            throw ArtifactBlobStoreErrorV1.sizeMismatch(
                path: relativePath,
                expected: expectedSize,
                actual: data.count
            )
        }
        let actualHash = CanonicalJSONV1.sha256Hex(data)
        guard actualHash == expectedHash else {
            throw ArtifactBlobStoreErrorV1.contentHashMismatch(
                path: relativePath,
                expected: expectedHash,
                actual: actualHash
            )
        }
        let identity = "\(after.st_dev):\(after.st_ino):\(after.st_size)"
        return ArtifactVerifiedFileV1(
            data: data,
            objectId: "devino:\(after.st_dev):\(after.st_ino)",
            fileIdentityHash: CanonicalJSONV1.sha256Hex(Data(identity.utf8))
        )
    }

    private func validatedComponents(_ relativePath: String) throws -> [String] {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasSuffix("/"),
              !relativePath.contains("\\"),
              !relativePath.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw ArtifactBlobStoreErrorV1.invalidRelativePath(relativePath)
        }
        let components = relativePath.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw ArtifactBlobStoreErrorV1.invalidRelativePath(relativePath)
        }
        return components
    }

    private func openDirectory(_ path: String) throws -> Int32 {
        let descriptor = path.withCString { pointer in
            Darwin.open(
                pointer,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(path, "open")
        }
        return descriptor
    }

    private func openDirectoryComponent(
        _ name: String,
        parentFD: Int32
    ) throws -> Int32 {
        let descriptor = name.withCString { pointer in
            Darwin.openat(
                parentFD,
                pointer,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(name, "openat")
        }
        return descriptor
    }

    private func openOrCreateDirectory(
        _ name: String,
        parentFD: Int32
    ) throws -> Int32 {
        let result = name.withCString { pointer in
            Darwin.mkdirat(parentFD, pointer, S_IRWXU)
        }
        if result != 0, errno != EEXIST {
            throw fileSystemError(name, "mkdirat")
        }
        return try openDirectoryComponent(name, parentFD: parentFD)
    }

    private func writeAll(
        _ data: Data,
        descriptor: Int32,
        path: String
    ) throws {
        try data.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset < rawBuffer.count {
                var count = 0
                while true {
                    count = Darwin.write(
                        descriptor,
                        rawBuffer.baseAddress?.advanced(by: offset),
                        rawBuffer.count - offset
                    )
                    if count < 0, errno == EINTR { continue }
                    break
                }
                guard count > 0 else {
                    throw fileSystemError(path, "write")
                }
                offset += count
            }
        }
    }

    private func openArtifactStoreRootDirectory() throws -> Int32 {
        let stateRoot = stateDirectoryLock.lockFileURL
            .deletingLastPathComponent()
            .standardizedFileURL
        let stateComponents = stateRoot.pathComponents
        let artifactComponents = artifactStoreRoot.pathComponents
        guard artifactComponents.count > stateComponents.count,
              Array(artifactComponents.prefix(stateComponents.count))
                == stateComponents
        else {
            throw ArtifactBlobStoreErrorV1.invalidRelativePath(
                artifactStoreRoot.path
            )
        }
        var directoryFD = try openDirectory(stateRoot.path)
        for component in artifactComponents.dropFirst(stateComponents.count) {
            do {
                let next = try openDirectoryComponent(
                    component,
                    parentFD: directoryFD
                )
                Darwin.close(directoryFD)
                directoryFD = next
            } catch {
                Darwin.close(directoryFD)
                throw error
            }
        }
        return directoryFD
    }

    private func removeDirectoryContentsNoFollow(
        directoryFD: Int32,
        relativePath: String
    ) throws {
        for name in try directoryEntryNames(
            directoryFD: directoryFD,
            relativePath: relativePath
        ) {
            var pathSnapshot = stat()
            let status = name.withCString { pointer in
                Darwin.fstatat(
                    directoryFD,
                    pointer,
                    &pathSnapshot,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard status == 0 else {
                throw fileSystemError(
                    "\(relativePath)/\(name)",
                    "fstatat"
                )
            }
            switch pathSnapshot.st_mode & S_IFMT {
            case S_IFREG:
                let result = name.withCString { pointer in
                    Darwin.unlinkat(directoryFD, pointer, 0)
                }
                guard result == 0 else {
                    throw fileSystemError(
                        "\(relativePath)/\(name)",
                        "unlinkat"
                    )
                }
                cleanupObserver?(
                    .afterUnlink(relativePath: "\(relativePath)/\(name)")
                )
                try syncDirectoryAfterCleanupMutation(
                    directoryFD,
                    relativePath: relativePath
                )
            case S_IFDIR:
                let childFD = try openDirectoryComponent(
                    name,
                    parentFD: directoryFD
                )
                do {
                    var opened = stat()
                    guard Darwin.fstat(childFD, &opened) == 0 else {
                        throw fileSystemError(
                            "\(relativePath)/\(name)",
                            "fstat"
                        )
                    }
                    guard opened.st_mode & S_IFMT == S_IFDIR,
                          opened.st_dev == pathSnapshot.st_dev,
                          opened.st_ino == pathSnapshot.st_ino
                    else {
                        throw ArtifactBlobStoreErrorV1.fileChanged(
                            "\(relativePath)/\(name)"
                        )
                    }
                    try cleanupCheckpoint?(
                        .afterDirectoryOpenBeforeTraversal(
                            relativePath: "\(relativePath)/\(name)"
                        )
                    )
                    var rebound = stat()
                    let reboundStatus = name.withCString { pointer in
                        Darwin.fstatat(
                            directoryFD,
                            pointer,
                            &rebound,
                            AT_SYMLINK_NOFOLLOW
                        )
                    }
                    guard reboundStatus == 0,
                          rebound.st_mode & S_IFMT == S_IFDIR,
                          rebound.st_dev == opened.st_dev,
                          rebound.st_ino == opened.st_ino
                    else {
                        throw ArtifactBlobStoreErrorV1.fileChanged(
                            "\(relativePath)/\(name)"
                        )
                    }
                    try removeDirectoryContentsNoFollow(
                        directoryFD: childFD,
                        relativePath: "\(relativePath)/\(name)"
                    )
                    var finalSnapshot = stat()
                    let finalStatus = name.withCString { pointer in
                        Darwin.fstatat(
                            directoryFD,
                            pointer,
                            &finalSnapshot,
                            AT_SYMLINK_NOFOLLOW
                        )
                    }
                    guard finalStatus == 0,
                          finalSnapshot.st_mode & S_IFMT == S_IFDIR,
                          finalSnapshot.st_dev == opened.st_dev,
                          finalSnapshot.st_ino == opened.st_ino
                    else {
                        throw ArtifactBlobStoreErrorV1.fileChanged(
                            "\(relativePath)/\(name)"
                        )
                    }
                } catch {
                    Darwin.close(childFD)
                    throw error
                }
                Darwin.close(childFD)
                let result = name.withCString { pointer in
                    Darwin.unlinkat(directoryFD, pointer, AT_REMOVEDIR)
                }
                guard result == 0 else {
                    throw fileSystemError(
                        "\(relativePath)/\(name)",
                        "unlinkat"
                    )
                }
                cleanupObserver?(
                    .afterRemoveDirectory(
                        relativePath: "\(relativePath)/\(name)"
                    )
                )
                try syncDirectoryAfterCleanupMutation(
                    directoryFD,
                    relativePath: relativePath
                )
            default:
                throw ArtifactBlobStoreErrorV1.irregularFile(
                    "\(relativePath)/\(name)"
                )
            }
        }
    }

    private func syncDirectoryAfterCleanupMutation(
        _ directoryFD: Int32,
        relativePath: String
    ) throws {
        guard Darwin.fsync(directoryFD) == 0 else {
            throw fileSystemError(relativePath, "fsync")
        }
        cleanupObserver?(
            .afterParentDirectorySync(relativePath: relativePath)
        )
    }

    private func directoryEntryNames(
        directoryFD: Int32,
        relativePath: String
    ) throws -> [String] {
        let iteratorFD = ".".withCString { pointer in
            Darwin.openat(
                directoryFD,
                pointer,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard iteratorFD >= 0 else {
            throw fileSystemError(relativePath, "openat")
        }
        var directorySnapshot = stat()
        var iteratorSnapshot = stat()
        guard Darwin.fstat(directoryFD, &directorySnapshot) == 0,
              Darwin.fstat(iteratorFD, &iteratorSnapshot) == 0
        else {
            Darwin.close(iteratorFD)
            throw fileSystemError(relativePath, "fstat")
        }
        guard directorySnapshot.st_dev == iteratorSnapshot.st_dev,
              directorySnapshot.st_ino == iteratorSnapshot.st_ino
        else {
            Darwin.close(iteratorFD)
            throw ArtifactBlobStoreErrorV1.fileChanged(relativePath)
        }
        guard let stream = Darwin.fdopendir(iteratorFD) else {
            Darwin.close(iteratorFD)
            throw fileSystemError(relativePath, "fdopendir")
        }
        defer { Darwin.closedir(stream) }
        var names: [String] = []
        errno = 0
        while let entry = Darwin.readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(
                    to: CChar.self,
                    capacity: Int(MAXNAMLEN) + 1
                ) { String(cString: $0) }
            }
            if name != ".", name != ".." {
                names.append(name)
            }
            errno = 0
        }
        guard errno == 0 else {
            throw fileSystemError(relativePath, "readdir")
        }
        return names.sorted()
    }

    private func fileSystemError(
        _ path: String,
        _ operation: String
    ) -> ArtifactBlobStoreErrorV1 {
        ArtifactBlobStoreErrorV1.fileSystem(
            path: path,
            operation: operation,
            code: errno
        )
    }
}
