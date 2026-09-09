import Darwin
import Foundation
import GRDB
import Testing
import AgentLoopCore

private struct P1F1VerifierRootHashMaterial: Encodable {
    struct Root: Encodable {
        let campId: String
        let rootId: String
        let standardizedAbsolutePath: String
    }

    let generation: Int
    let roots: [Root]
}

private struct P1F1VerifierLegacyAttestation: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originalRefHash: String
}

private struct P1F1VerifierFixture: Sendable {
    let database: AppDatabase
    let campId: String
    let cardId: String
    let base: URL
    let root: URL
    let snapshot: ManagedArtifactRootSnapshotV1
}

private func p1f1VerifierSnapshot(
    generation: Int = 1,
    descriptors: [ManagedArtifactRootDescriptorV1]
) throws -> ManagedArtifactRootSnapshotV1 {
    let ordered = descriptors.sorted { lhs, rhs in
        if lhs.rootId != rhs.rootId {
            return lhs.rootId.utf8.lexicographicallyPrecedes(rhs.rootId.utf8)
        }
        return lhs.campId.utf8.lexicographicallyPrecedes(rhs.campId.utf8)
    }
    let material = P1F1VerifierRootHashMaterial(
        generation: generation,
        roots: ordered.map {
            .init(
                campId: $0.campId,
                rootId: $0.rootId,
                standardizedAbsolutePath: $0.rootURL.standardizedFileURL.path
            )
        }
    )
    return try ManagedArtifactRootSnapshotV1.frozen(
        generation: generation,
        rootSetHash: CanonicalContractCodingV1.hash(material),
        roots: ordered
    )
}

private func p1f1VerifierFixture(
    database: AppDatabase,
    campId: String,
    cardId: String,
    label: String = UUID().uuidString
) throws -> P1F1VerifierFixture {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-p1f1-verifier-\(label)")
    let root = base.appendingPathComponent("managed", isDirectory: true)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let descriptor = try ManagedArtifactRootDescriptorV1.registered(
        rootId: "managed-root-v1",
        campId: campId,
        rootURL: root
    )
    return .init(
        database: database,
        campId: campId,
        cardId: cardId,
        base: base,
        root: root,
        snapshot: try p1f1VerifierSnapshot(descriptors: [descriptor])
    )
}

private func p1f1VerifierFixture() throws -> P1F1VerifierFixture {
    let databaseBase = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-p1f1-verifier-db-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: databaseBase,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: databaseBase.appendingPathComponent("test.sqlite").path
    )
    let camp = try database.ensureDefaultCamp()
    let mission = try database.createSingleCardMission(
        campName: camp.name,
        squadName: "verifier",
        goal: "verify artifacts",
        cardTitle: "artifact",
        cardDescription: "artifact",
        expectedOutput: "artifact",
        assigneeId: nil,
        maxTurns: 3,
        campId: camp.id
    )
    return try p1f1VerifierFixture(
        database: database,
        campId: camp.id,
        cardId: mission.cardId
    )
}

private func p1f1SeedVerifierArtifact(
    fixture: P1F1VerifierFixture,
    id: String,
    path: URL,
    storageClass: ArtifactStorageClassV1 = .unresolved,
    evidenceKind: ArtifactStorageEvidenceKindV1 = .legacyUnknown,
    managedRootId: String? = nil,
    objectId: String? = nil,
    contentHash: String? = nil,
    fileIdentityHash: String? = nil,
    originalRefHashOverride: String? = nil,
    classificationEvidenceHashOverride: String? = nil,
    campId: String? = nil,
    cardId: String? = nil
) throws {
    let owningCampId = campId ?? fixture.campId
    let owningCardId = cardId ?? fixture.cardId
    let canonicalOriginalRefHash = CanonicalJSONV1.sha256Hex(
        Data(path.path.utf8)
    )
    let originalRefHash = originalRefHashOverride
        ?? canonicalOriginalRefHash
    let canonicalClassificationEvidenceHash = try CanonicalContractCodingV1
        .hash(
            P1F1VerifierLegacyAttestation(
                schemaVersion: 1,
                artifactId: id,
                cardId: owningCardId,
                campId: owningCampId,
                originalRefHash: canonicalOriginalRefHash
            )
        )
    let classificationEvidenceHash = classificationEvidenceHashOverride
        ?? canonicalClassificationEvidenceHash
    try fixture.database.pool.write { database in
        try ArtifactRecord(
            id: id,
            cardId: owningCardId,
            path: path.path,
            kind: "file",
            label: "fixture",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ).insert(database)
        try database.execute(
            sql: """
                INSERT INTO artifact_storage_origin(
                  artifactId,campId,state,storageClass,evidenceKind,
                  managedRootId,objectId,contentHash,fileIdentityHash,
                  originalRefHash,classificationEvidenceHash,
                  terminalDisposition,terminalAuthorityHash,version,
                  classifiedAt,redactedAt
                ) VALUES (?,?,'active',?,?,?,?,?,?,?,?,NULL,NULL,1,?,NULL)
                """,
            arguments: [
                id,
                owningCampId,
                storageClass.rawValue,
                evidenceKind.rawValue,
                managedRootId,
                objectId,
                contentHash,
                fileIdentityHash,
                originalRefHash,
                classificationEvidenceHash,
                Date(timeIntervalSince1970: 1_700_000_000),
            ]
        )
    }
}

private func p1f1VerifierUnresolvedReason(
    _ result: ArtifactOwnershipVerificationV1
) -> UnresolvedArtifactReasonV1? {
    guard case .unresolved(let evidence) = result else { return nil }
    return evidence.reason
}

private func p1f1VerifierManagedEvidence(
    _ result: ArtifactOwnershipVerificationV1
) -> VerifiedManagedArtifactEvidenceV1? {
    guard case .managed(let evidence) = result else { return nil }
    return evidence
}

private func p1f1PromoteVerifierArtifactToManaged(
    fixture: P1F1VerifierFixture,
    evidence: VerifiedManagedArtifactEvidenceV1
) throws {
    try fixture.database.pool.write { database in
        try database.execute(
            sql: """
                UPDATE artifact_storage_origin
                SET storageClass='managed',
                    evidenceKind='verifiedManagedRootCapability',
                    managedRootId=?,objectId=?,contentHash=?,fileIdentityHash=?
                WHERE artifactId=?
                """,
            arguments: [
                evidence.managedRootId,
                evidence.objectId,
                evidence.contentHash,
                evidence.fileIdentityHash,
                evidence.artifactId,
            ]
        )
        #expect(database.changesCount == 1)
    }
}

private func p1f1CreateCrossCampArtifact(
    fixture: P1F1VerifierFixture,
    artifactId: String,
    path: URL,
    contentHash: String? = nil,
    fileIdentityHash: String? = nil
) throws {
    let camp = try fixture.database.createCamp(
        name: "Verifier cross Camp \(artifactId.suffix(4))"
    )
    let mission = try fixture.database.createSingleCardMission(
        campName: camp.name,
        squadName: "cross verifier",
        goal: "cross Camp evidence",
        cardTitle: "cross artifact",
        cardDescription: "cross artifact",
        expectedOutput: "cross artifact",
        assigneeId: nil,
        maxTurns: 3,
        campId: camp.id
    )
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: artifactId,
        path: path,
        storageClass: contentHash == nil ? .unresolved : .managed,
        evidenceKind: contentHash == nil
            ? .legacyUnknown
            : .verifiedManagedRootCapability,
        managedRootId: contentHash == nil ? nil : "cross-root-v1",
        objectId: contentHash == nil ? nil : "cross-object.bin",
        contentHash: contentHash,
        fileIdentityHash: fileIdentityHash,
        campId: camp.id,
        cardId: mission.cardId
    )
}

private func p1f1PreparePendingArtifact(
    fixture: P1F1EngineFixture,
    contentHash: String,
    key: String
) throws -> EngineTerminalProposalContentV1 {
    let request = try fixture.begin(key: "\(key)-begin")
    let execution = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    let version: Int = execution["version"]
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: request.executionId,
        expectedVersion: version,
        requestHash: request.requestHash,
        commandIdempotencyKey: "\(key)-dispatch",
        now: p1f1EngineTestNow.addingTimeInterval(1)
    )
    let relativePath = "pending/\(key).bin"
    return try EngineTerminalProposalContentV1(
        protocolVersion: "agentloop.execution.v1",
        executionId: request.executionId,
        runId: request.runId,
        cardId: request.cardId,
        sequence: 0,
        terminalIdempotencyKey: "\(key)-terminal",
        terminalKind: .completed,
        terminalSubtype: nil,
        payload: .completed(
            handoff: HandoffPayload(
                outcome: "pending",
                summary: "pending verifier counterexample",
                artifacts: [
                    .init(
                        relativePath: relativePath,
                        kind: "file",
                        label: "Pending"
                    ),
                ],
                verification: [],
                risks: []
            )
        ),
        artifacts: [
            EngineTerminalArtifactDeclarationV1(
                ordinal: 0,
                sourceRelativePath: relativePath,
                kind: "file",
                label: "Pending",
                byteCount: 1,
                contentHash: contentHash
            ),
        ]
    )
}

private func p1f1RecordPendingArtifact(
    fixture: P1F1EngineFixture,
    contentHash: String,
    key: String
) throws {
    let content = try p1f1PreparePendingArtifact(
        fixture: fixture,
        contentHash: contentHash,
        key: key
    )
    _ = try fixture.store.recordEngineTerminalProposal(content)
}

private struct P1F1VerifierFixtureFailure: Error {}

private func p1f1PrepareManagedVerifierArtifact(
    fixture: P1F1VerifierFixture,
    id: String,
    fileName: String,
    bytes: Data
) throws -> (URL, VerifiedManagedArtifactEvidenceV1) {
    let path = fixture.root.appendingPathComponent(fileName)
    try bytes.write(to: path)
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: id,
        path: path
    )
    let result = try ArtifactOwnershipVerifier(
        database: fixture.database,
        roots: fixture.snapshot
    ).verify(artifactId: id, expectedOriginVersion: 1)
    guard let evidence = p1f1VerifierManagedEvidence(result) else {
        Issue.record("fixture must first establish exact managed evidence")
        throw P1F1VerifierFixtureFailure()
    }
    return (path, evidence)
}

@Test func p1f1_057VerifierNoFollowClassificationMatrix() throws {
    let fixture = try p1f1VerifierFixture()
    let verifier = ArtifactOwnershipVerifier(
        database: fixture.database,
        roots: fixture.snapshot
    )

    // Canonical legacy attestation may classify as managed only after a real
    // descriptor walk and content observation.
    let managed = fixture.root.appendingPathComponent("managed.bin")
    let bytes = Data("managed".utf8)
    try bytes.write(to: managed)
    let managedID = "11111111-1111-4111-8111-111111111111"
    let hash = CanonicalJSONV1.sha256Hex(bytes)
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: managedID,
        path: managed
    )
    let managedResult = try verifier.verify(
        artifactId: managedID,
        expectedOriginVersion: 1
    )
    guard case .managed(let evidence) = managedResult else {
        Issue.record("exact managed provenance must verify as managed")
        return
    }
    #expect(evidence.artifactId == managedID)
    #expect(evidence.campId == fixture.campId)
    #expect(evidence.contentHash == hash)

    // A separate canonical legacy attestation outside every frozen root may
    // classify as workspace-external.
    let outside = fixture.base.appendingPathComponent("outside.bin")
    try Data("outside".utf8).write(to: outside)
    let outsideID = "22222222-2222-4222-8222-222222222222"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: outsideID,
        path: outside
    )
    let outsideResult = try verifier.verify(
        artifactId: outsideID,
        expectedOriginVersion: 1
    )
    guard case .workspaceExternal = outsideResult else {
        Issue.record("outside every available root must verify external")
        return
    }

    // Missing legacy paths never become external or already-absent proofs.
    let missingID = "33333333-3333-4333-8333-333333333333"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: missingID,
        path: fixture.base.appendingPathComponent("missing.bin")
    )
    let missingResult = try verifier.verify(
        artifactId: missingID,
        expectedOriginVersion: 1
    )
    guard case .unresolved(let missingEvidence) = missingResult else {
        Issue.record("unknown missing must remain unresolved")
        return
    }
    #expect(missingEvidence.reason == .unknownMissing)

    // The final component is always no-follow.
    let symlink = fixture.base.appendingPathComponent("link.bin")
    try FileManager.default.createSymbolicLink(
        at: symlink,
        withDestinationURL: managed
    )
    let symlinkID = "44444444-4444-4444-8444-444444444444"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: symlinkID,
        path: symlink
    )
    let symlinkResult = try verifier.verify(
        artifactId: symlinkID,
        expectedOriginVersion: 1
    )
    guard case .unresolved(let symlinkEvidence) = symlinkResult else {
        Issue.record("symlink must remain unresolved")
        return
    }
    #expect(symlinkEvidence.reason == .symlink)

    // Raw path identity is checked before any ownership proof.
    let rawHashDrift = fixture.base.appendingPathComponent("raw-hash-drift.bin")
    try Data("raw hash drift".utf8).write(to: rawHashDrift)
    let rawHashDriftID = "60000000-0000-4000-8000-000000000001"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: rawHashDriftID,
        path: rawHashDrift,
        originalRefHashOverride: String(repeating: "b", count: 64)
    )
    #expect(
        p1f1VerifierUnresolvedReason(
            try verifier.verify(
                artifactId: rawHashDriftID,
                expectedOriginVersion: 1
            )
        ) == .identityDrift
    )

    // A syntactically valid but noncanonical legacy classification
    // attestation is not verifier authority.
    let attestationDrift = fixture.base
        .appendingPathComponent("attestation-drift.bin")
    try Data("attestation drift".utf8).write(to: attestationDrift)
    let attestationDriftID = "60000000-0000-4000-8000-000000000002"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: attestationDriftID,
        path: attestationDrift,
        classificationEvidenceHashOverride: String(repeating: "c", count: 64)
    )
    #expect(
        p1f1VerifierUnresolvedReason(
            try verifier.verify(
                artifactId: attestationDriftID,
                expectedOriginVersion: 1
            )
        ) == .identityDrift
    )

    // POSIX access denial is distinct from missing and never becomes an
    // external proof.
    let denied = fixture.base.appendingPathComponent("permission-denied.bin")
    try Data("permission denied".utf8).write(to: denied)
    let deniedID = "60000000-0000-4000-8000-000000000003"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: deniedID,
        path: denied
    )
    guard Darwin.chmod(denied.path, 0) == 0 else {
        throw POSIXError(.EACCES)
    }
    defer { _ = Darwin.chmod(denied.path, S_IRUSR | S_IWUSR) }
    #expect(
        p1f1VerifierUnresolvedReason(
            try verifier.verify(
                artifactId: deniedID,
                expectedOriginVersion: 1
            )
        ) == .permissionDenied
    )

    // A frozen root registry is fail-closed when even one registered root is
    // unavailable.
    let unavailableArtifact = fixture.base
        .appendingPathComponent("unavailable-root-artifact.bin")
    try Data("unavailable root".utf8).write(to: unavailableArtifact)
    let unavailableID = "60000000-0000-4000-8000-000000000004"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: unavailableID,
        path: unavailableArtifact
    )
    let unavailableDescriptor = try ManagedArtifactRootDescriptorV1.registered(
        rootId: "unavailable-root-v1",
        campId: fixture.campId,
        rootURL: fixture.base.appendingPathComponent("root-does-not-exist")
    )
    let unavailableVerifier = ArtifactOwnershipVerifier(
        database: fixture.database,
        roots: try p1f1VerifierSnapshot(
            descriptors: [unavailableDescriptor]
        )
    )
    #expect(
        p1f1VerifierUnresolvedReason(
            try unavailableVerifier.verify(
                artifactId: unavailableID,
                expectedOriginVersion: 1
            )
        ) == .managedRootUnavailable
    )

    // Directories and other irregular objects are never file proofs.
    let irregular = fixture.base
        .appendingPathComponent("irregular", isDirectory: true)
    try FileManager.default.createDirectory(
        at: irregular,
        withIntermediateDirectories: true
    )
    let irregularID = "60000000-0000-4000-8000-000000000005"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: irregularID,
        path: irregular
    )
    #expect(
        p1f1VerifierUnresolvedReason(
            try verifier.verify(
                artifactId: irregularID,
                expectedOriginVersion: 1
            )
        ) == .irregularFile
    )

    // String-prefix resemblance is not root membership.
    let spoofDirectory = fixture.base
        .appendingPathComponent("managed-spoof", isDirectory: true)
    try FileManager.default.createDirectory(
        at: spoofDirectory,
        withIntermediateDirectories: true
    )
    let spoof = spoofDirectory.appendingPathComponent("prefix.bin")
    try Data("prefix spoof".utf8).write(to: spoof)
    let spoofID = "60000000-0000-4000-8000-000000000006"
    try p1f1SeedVerifierArtifact(
        fixture: fixture,
        id: spoofID,
        path: spoof
    )
    let spoofResult = try verifier.verify(
        artifactId: spoofID,
        expectedOriginVersion: 1
    )
    guard case .workspaceExternal = spoofResult else {
        Issue.record("path-prefix spoof must remain outside managed roots")
        return
    }
}

@Test func p1f1_058VerifierHardlinkCrossCampConcurrentSnapshotMatrix() throws {
    // A real same-inode hardlink is independently ambiguous.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("shared.bin")
        try Data("shared".utf8).write(to: source)
        let hardlink = fixture.root.appendingPathComponent("shared-link.bin")
        try FileManager.default.linkItem(at: source, to: hardlink)
        let artifactID = "70000000-0000-4000-8000-000000000001"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let result = try ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot
        ).verify(artifactId: artifactID, expectedOriginVersion: 1)
        #expect(p1f1VerifierUnresolvedReason(result) == .ambiguousHardlink)
        #expect(FileManager.default.fileExists(atPath: hardlink.path))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    // A live artifact row in another Camp claiming the same path is
    // independently ambiguous even when st_nlink is one.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("cross-camp.bin")
        try Data("cross Camp".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000002"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        try p1f1CreateCrossCampArtifact(
            fixture: fixture,
            artifactId: "70000000-0000-4000-8000-000000000003",
            path: source
        )
        let result = try ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot
        ).verify(artifactId: artifactID, expectedOriginVersion: 1)
        #expect(p1f1VerifierUnresolvedReason(result) == .ambiguousHardlink)
    }

    // A different live artifact in the same Camp is still a competing
    // ownership claim. Camp equality must not turn duplicate path or file
    // identity into an exclusive proof.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("same-camp.bin")
        try Data("same Camp conflict".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000018"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let fetchedCamp = try fixture.database.camp(id: fixture.campId)
        let camp = try #require(fetchedCamp)
        let competingMission = try fixture.database.createSingleCardMission(
            campName: camp.name,
            squadName: "same Camp verifier",
            goal: "competing ownership claim",
            cardTitle: "same Camp artifact",
            cardDescription: "same Camp artifact",
            expectedOutput: "same Camp artifact",
            assigneeId: nil,
            maxTurns: 3,
            campId: fixture.campId
        )
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000019",
            path: source,
            campId: fixture.campId,
            cardId: competingMission.cardId
        )
        let result = try ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot
        ).verify(artifactId: artifactID, expectedOriginVersion: 1)
        #expect(p1f1VerifierUnresolvedReason(result) == .ambiguousHardlink)
    }

    // Replacing the artifact after its first descriptor snapshot is identity
    // drift, independently of root drift.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("identity-drift.bin")
        try Data("identity A".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000004"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                try FileManager.default.removeItem(at: source)
                try Data("identity B".utf8).write(to: source)
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .identityDrift
        )
    }

    // In-place same-inode mutation is content drift, not a valid proof.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("content-drift.bin")
        try Data("content-A".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000005"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let handle = try FileHandle(forWritingTo: source)
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: Data("content-B".utf8))
                try handle.synchronize()
            }
        )
        let result = try verifier.verify(
            artifactId: artifactID,
            expectedOriginVersion: 1
        )
        try handle.close()
        #expect(p1f1VerifierUnresolvedReason(result) == .contentDrift)
    }

    // Owning-root tree drift is independently incomplete-root-set.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("root-drift.bin")
        try Data("stable artifact".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000006"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                try Data("root drift".utf8).write(
                    to: fixture.root.appendingPathComponent("concurrent.bin")
                )
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .incompleteRootSet
        )
    }

    // Exact managed provenance may sign already-absent only after a second
    // missing check and a complete frozen-root snapshot.
    do {
        let fixture = try p1f1VerifierFixture()
        let (source, evidence) = try p1f1PrepareManagedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000007",
            fileName: "already-absent.bin",
            bytes: Data("already absent".utf8)
        )
        try p1f1PromoteVerifierArtifactToManaged(
            fixture: fixture,
            evidence: evidence
        )
        try FileManager.default.removeItem(at: source)
        let result = try ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot
        ).verify(artifactId: evidence.artifactId, expectedOriginVersion: 1)
        guard case .managedAlreadyAbsent(let absent) = result else {
            Issue.record("exact stable managed missing path must sign absent")
            return
        }
        #expect(absent.contentHash == evidence.contentHash)
        #expect(absent.fileIdentityHash == evidence.fileIdentityHash)
    }

    // Missing-managed plus a pending proposal content root is ambiguous.
    do {
        let engine = try P1F1EngineFixture()
        let fixture = try p1f1VerifierFixture(
            database: engine.db,
            campId: p1f1EngineCampID,
            cardId: p1f1EngineCardID,
            label: "missing-pending-\(UUID().uuidString)"
        )
        let (source, evidence) = try p1f1PrepareManagedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000008",
            fileName: "missing-pending.bin",
            bytes: Data("missing pending".utf8)
        )
        try p1f1PromoteVerifierArtifactToManaged(
            fixture: fixture,
            evidence: evidence
        )
        try FileManager.default.removeItem(at: source)
        try p1f1RecordPendingArtifact(
            fixture: engine,
            contentHash: evidence.contentHash,
            key: "missing-pending"
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try ArtifactOwnershipVerifier(
                    database: fixture.database,
                    roots: fixture.snapshot
                ).verify(
                    artifactId: evidence.artifactId,
                    expectedOriginVersion: 1
                )
            ) == .ambiguousHardlink
        )
    }

    // Missing-managed plus a persisted cross-Camp file identity is
    // ambiguous even when no target path remains.
    do {
        let fixture = try p1f1VerifierFixture()
        let (source, evidence) = try p1f1PrepareManagedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000009",
            fileName: "missing-cross-camp.bin",
            bytes: Data("missing cross Camp".utf8)
        )
        try p1f1PromoteVerifierArtifactToManaged(
            fixture: fixture,
            evidence: evidence
        )
        try FileManager.default.removeItem(at: source)
        try p1f1CreateCrossCampArtifact(
            fixture: fixture,
            artifactId: "70000000-0000-4000-8000-000000000010",
            path: fixture.base.appendingPathComponent("cross-camp-claim.bin"),
            contentHash: evidence.contentHash,
            fileIdentityHash: evidence.fileIdentityHash
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try ArtifactOwnershipVerifier(
                    database: fixture.database,
                    roots: fixture.snapshot
                ).verify(
                    artifactId: evidence.artifactId,
                    expectedOriginVersion: 1
                )
            ) == .ambiguousHardlink
        )
    }

    // Missing-managed never bypasses the immutable raw path attestation.
    do {
        let fixture = try p1f1VerifierFixture()
        let (source, evidence) = try p1f1PrepareManagedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000011",
            fileName: "missing-path-drift.bin",
            bytes: Data("missing path drift".utf8)
        )
        try p1f1PromoteVerifierArtifactToManaged(
            fixture: fixture,
            evidence: evidence
        )
        try FileManager.default.removeItem(at: source)
        try fixture.database.pool.write { database in
            try database.execute(
                sql: "UPDATE artifact SET path=? WHERE id=?",
                arguments: [
                    fixture.root.appendingPathComponent("drifted-missing.bin").path,
                    evidence.artifactId,
                ]
            )
        }
        #expect(
            p1f1VerifierUnresolvedReason(
                try ArtifactOwnershipVerifier(
                    database: fixture.database,
                    roots: fixture.snapshot
                ).verify(
                    artifactId: evidence.artifactId,
                    expectedOriginVersion: 1
                )
            ) == .identityDrift
        )
    }

    // A residual hardlink is found from the persisted file identity even
    // after the original managed object path is gone and st_nlink falls to 1.
    do {
        let fixture = try p1f1VerifierFixture()
        let (source, evidence) = try p1f1PrepareManagedVerifierArtifact(
            fixture: fixture,
            id: "70000000-0000-4000-8000-000000000012",
            fileName: "missing-residual-source.bin",
            bytes: Data("missing residual".utf8)
        )
        try p1f1PromoteVerifierArtifactToManaged(
            fixture: fixture,
            evidence: evidence
        )
        let residual = fixture.root
            .appendingPathComponent("missing-residual-link.bin")
        try FileManager.default.linkItem(at: source, to: residual)
        try FileManager.default.removeItem(at: source)
        let residualResult = try ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot
        ).verify(
            artifactId: evidence.artifactId,
            expectedOriginVersion: 1
        )
        #expect(
            p1f1VerifierUnresolvedReason(residualResult)
                == .ambiguousHardlink
        )
        #expect(FileManager.default.fileExists(atPath: residual.path))
    }

    // A pending proposal inserted by the final-snapshot hook must be seen by
    // the common final database gate.
    do {
        let engine = try P1F1EngineFixture()
        let fixture = try p1f1VerifierFixture(
            database: engine.db,
            campId: p1f1EngineCampID,
            cardId: p1f1EngineCardID,
            label: "hook-pending-\(UUID().uuidString)"
        )
        let source = fixture.root.appendingPathComponent("hook-pending.bin")
        let bytes = Data("hook pending".utf8)
        try bytes.write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000013"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let content = try p1f1PreparePendingArtifact(
            fixture: engine,
            contentHash: CanonicalJSONV1.sha256Hex(bytes),
            key: "hook-pending"
        )
        let store = engine.store
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                _ = try store.recordEngineTerminalProposal(content)
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .ambiguousHardlink
        )
    }

    // A cross-Camp claim inserted by the final-snapshot hook must also be
    // seen before proof issuance.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("hook-cross-camp.bin")
        try Data("hook cross Camp".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000014"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                try p1f1CreateCrossCampArtifact(
                    fixture: fixture,
                    artifactId: "70000000-0000-4000-8000-000000000015",
                    path: source
                )
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .ambiguousHardlink
        )
    }

    // The common final gate fingerprints every frozen root, including roots
    // that do not own the candidate artifact.
    do {
        let fixture = try p1f1VerifierFixture()
        let nonowningRoot = fixture.base
            .appendingPathComponent("nonowning", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nonowningRoot,
            withIntermediateDirectories: true
        )
        let owningDescriptor = try ManagedArtifactRootDescriptorV1.registered(
            rootId: "a-owning-root",
            campId: fixture.campId,
            rootURL: fixture.root
        )
        let nonowningDescriptor = try ManagedArtifactRootDescriptorV1.registered(
            rootId: "z-nonowning-root",
            campId: fixture.campId,
            rootURL: nonowningRoot
        )
        let snapshot = try p1f1VerifierSnapshot(
            descriptors: [owningDescriptor, nonowningDescriptor]
        )
        let source = fixture.root
            .appendingPathComponent("nonowning-root-drift.bin")
        try Data("nonowning root drift".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000016"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: snapshot,
            beforeFinalSnapshotValidation: {
                try Data("drift".utf8).write(
                    to: nonowningRoot.appendingPathComponent("drift.bin")
                )
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .incompleteRootSet
        )
    }

    // Origin version drift after classification is caught by the same final
    // database snapshot gate.
    do {
        let fixture = try p1f1VerifierFixture()
        let source = fixture.root.appendingPathComponent("origin-drift.bin")
        try Data("origin drift".utf8).write(to: source)
        let artifactID = "70000000-0000-4000-8000-000000000017"
        try p1f1SeedVerifierArtifact(
            fixture: fixture,
            id: artifactID,
            path: source
        )
        let verifier = ArtifactOwnershipVerifier(
            database: fixture.database,
            roots: fixture.snapshot,
            beforeFinalSnapshotValidation: {
                try fixture.database.pool.write { database in
                    try database.execute(
                        sql: """
                            UPDATE artifact_storage_origin
                            SET version=version+1 WHERE artifactId=?
                            """,
                        arguments: [artifactID]
                    )
                }
            }
        )
        #expect(
            p1f1VerifierUnresolvedReason(
                try verifier.verify(
                    artifactId: artifactID,
                    expectedOriginVersion: 1
                )
            ) == .identityDrift
        )
    }
}
