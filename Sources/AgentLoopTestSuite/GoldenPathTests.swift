import Testing
import Foundation
import Darwin
import GRDB
import AgentLoopCore

private final class ModelCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var models: [String] = []

    func append(_ model: String) {
        lock.withLock { models.append(model) }
    }

    var values: [String] {
        lock.withLock { models }
    }
}

private func goldenTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func goldenArtifactRoot() throws -> URL {
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "golden-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let artifacts = stateRoot.appendingPathComponent("artifacts", isDirectory: true)
    try FileManager.default.createDirectory(
        at: artifacts,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    return artifacts
}

private struct GoldenDispatchContextFixture {
    let workspaceRoot: URL
    let firstCardId: String
}

private func goldenAttachDispatchContext(
    db: AppDatabase,
    missionId: String,
    companionIds: [String]
) throws -> GoldenDispatchContextFixture {
    guard let primaryCompanionId = companionIds.first else {
        throw EngineContextValidationErrorV1()
    }
    let workspaceRoot = try attachP1F1DispatchContext(
        db: db,
        missionId: missionId,
        companionId: primaryCompanionId
    )
    guard let primaryCompanion = try db.companion(id: primaryCompanionId),
          let runtimeProfileId = primaryCompanion.runtimeProfileId
    else {
        throw EngineContextValidationErrorV1()
    }
    for companionId in companionIds.dropFirst() {
        guard var companion = try db.companion(id: companionId) else {
            throw EngineContextValidationErrorV1()
        }
        companion.runtimeProfileId = runtimeProfileId
        companion.modelPolicy = .pinned
        try db.saveCompanion(companion)
    }
    guard let firstCard = try db.cards(missionId: missionId).first else {
        throw EngineContextValidationErrorV1()
    }
    try db.pool.write { database in
        try AppDatabase.appendEvent(
            database,
            missionId: missionId,
            cardId: firstCard.id,
            runId: nil,
            kind: EventKind.cardReady,
            payload: .object([:])
        )
    }
    return GoldenDispatchContextFixture(
        workspaceRoot: workspaceRoot,
        firstCardId: firstCard.id
    )
}

private func goldenEvents(_ db: AppDatabase, missionId: String) throws -> [EventRecord] {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }
}

private func goldenProposalInput(cards: [JSONValue]) -> JSONValue {
    ["goalRefined": "两卡依赖行动", "cards": .array(cards)]
}

private func goldenCardDraftInput(
    title: String,
    description: String,
    expectedOutput: String,
    assignee: Int,
    dependsOn: [Int] = []
) -> JSONValue {
    [
        "title": .string(title),
        "description": .string(description),
        "expectedOutput": .string(expectedOutput),
        "assignee": .number(Double(assignee)),
        "dependsOn": .array(dependsOn.map { .number(Double($0)) }),
    ]
}

private func goldenR9DExpectAuthorityFailure(
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected R9-D authority failure")
    } catch is EngineRuntimeAuthorityErrorV1 {
    } catch {
        Issue.record("unexpected R9-D authority error: \(error)")
    }
}

private enum GoldenR9DFixtureError: Error, Sendable {
    case injected
}

private final class GoldenR9DLockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    func increment() { lock.withLock { stored += 1 } }
    var value: Int { lock.withLock { stored } }
}

private final class GoldenR9DBridgeStageFixture: @unchecked Sendable {
    let stagingDirectory: URL
    private let bytes = Data("real-staged-bridge".utf8)

    init(stagingDirectory: URL) {
        self.stagingDirectory = stagingDirectory
    }

    func stage(sourcePath: String) throws
        -> EngineBoardBridgeExecutableAuthorityV1
    {
        let hash = CanonicalJSONV1.sha256Hex(bytes)
        let authorityDirectory = stagingDirectory.appendingPathComponent(
            "board-bridge-\(hash)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: authorityDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let executable = authorityDirectory.appendingPathComponent(
            "executable"
        )
        try bytes.write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: executable.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: authorityDirectory.path
        )
        var info = stat()
        guard Darwin.lstat(executable.path, &info) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        return try EngineBoardBridgeExecutableAuthorityV1(
            sourcePath: sourcePath,
            stagedPath: executable.path,
            executableHash: hash,
            designatedRequirement:
                "identifier com.muzi.agentloop.board-bridge",
            teamIdentifier: "TEAM123456",
            cdHash: String(repeating: "a", count: 40),
            stagedDevice: UInt64(info.st_dev),
            stagedInode: UInt64(info.st_ino)
        )
    }
}

private final class GoldenR9DBridgeCaptureGate: @unchecked Sendable {
    private let lock = NSLock()
    private var failuresRemaining = 2
    private let stagingDirectory: URL
    private let signing = EngineRuntimeSigningIdentitySnapshotV1(
        designatedRequirement:
            "identifier com.muzi.agentloop.board-bridge",
        teamIdentifier: "TEAM123456",
        cdHash: String(repeating: "a", count: 40)
    )

    init(stagingDirectory: URL) {
        self.stagingDirectory = stagingDirectory
    }

    func capture(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws -> EngineRuntimeExecutableRemovalSnapshotV1 {
        let injected = lock.withLock { () -> Bool in
            guard failuresRemaining > 0 else { return false }
            failuresRemaining -= 1
            return true
        }
        if injected { throw GoldenR9DFixtureError.injected }
        return try EnginePackagedBridgeStagedOwnershipV1.capture(
            authority: authority,
            stagingDirectory: stagingDirectory,
            inspectSignature: { _ in self.signing }
        )
    }

    func remove(
        _ snapshot: EngineRuntimeExecutableRemovalSnapshotV1
    ) throws {
        try EnginePackagedBridgeStagedOwnershipV1.remove(
            snapshot: snapshot,
            stagingDirectory: stagingDirectory,
            inspectSignature: { _ in self.signing }
        )
    }
}

private func goldenR9DCLICompositionAuthority() throws
    -> CliExecutableAuthorityV1
{
    try CliExecutableAuthorityV1(
        kind: .cliClaude,
        command: "claude",
        commandSourcePath: "/fixtures/cli_claude/command",
        commandSourceHash: String(repeating: "1", count: 64),
        resolvedExecutablePath: "/fixtures/cli_claude/native",
        stagedPath: "/fixtures/staged/cli_claude",
        executableHash: String(repeating: "2", count: 64),
        designatedRequirement:
            "anchor apple generic and identifier fixture.cli_claude",
        teamIdentifier: "Q6L2SF6YDW",
        cdHash: String(repeating: "a", count: 40),
        stagedDevice: 81,
        stagedInode: 82
    )
}

private func goldenR9DCLICompositionSnapshot(
    _ authority: CliExecutableAuthorityV1
) throws -> CliHelpSnapshotV1 {
    let firstFlags = [
        "--add-dir", "--allowedTools", "--disable-slash-commands",
        "--input-format", "--mcp-config", "--model", "--no-chrome",
        "--output-format", "--permission-mode", "--session-id",
        "--setting-sources", "--strict-mcp-config", "--tools",
        "--verbose", "-p",
    ].sorted()
    let resumeFlags = [
        "--add-dir", "--allowedTools", "--disable-slash-commands",
        "--input-format", "--mcp-config", "--model", "--no-chrome",
        "--output-format", "--permission-mode", "--resume",
        "--setting-sources", "--strict-mcp-config", "--tools",
        "--verbose", "-p",
    ].sorted()
    return try CliHelpSnapshotV1(
        executableAuthority: authority,
        versionLine: "2.1.81 (Claude Code)",
        rootExitStatus: 0,
        rootStdoutHash: String(repeating: "6", count: 64),
        firstExitStatus: 0,
        firstStdoutHash: String(repeating: "7", count: 64),
        resumeExitStatus: 0,
        resumeStdoutHash: String(repeating: "8", count: 64),
        rootFlags: [],
        firstFlags: firstFlags,
        resumeFlags: resumeFlags,
        subcommands: []
    )
}

private func goldenR9DCompositionFactories() -> [EngineAdapterFactoryV1] {
    EngineAdapterFactoryV1.builtInFactories(
        makeModelLoopAdapter: { _, _ in
            throw GoldenR9DFixtureError.injected
        },
        makeCodexAdapter: { _, _ in
            throw GoldenR9DFixtureError.injected
        },
        makeClaudeAdapter: { _, _ in
            throw GoldenR9DFixtureError.injected
        }
    )
}

private func goldenR9DAssertColdStartAuthorities() throws {
    let stateBytes = Data(
        #"{"canonicalPath":"/tmp/r9d-state","device":11,"inode":22,"uid":33}"#.utf8
    )
    let state = EngineStateRootIdentityV1(
        canonicalPath: "/tmp/r9d-state",
        device: 11,
        inode: 22,
        uid: 33
    )
    #expect(try state.canonicalBytes() == stateBytes)
    #expect(
        try state.identityHash()
            == "e888ec3e4562c482724b0e9ff248cdc249d098a0c310d273ad408d29973474fd"
    )
    let ownerBytes = Data(
        #"{"bootUUID":"11111111-2222-4333-8444-555555555555","stateRootIdentityHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"#.utf8
    )
    let owner = try EngineRuntimeOwnerDocumentV1.decodeCanonical(ownerBytes)
    #expect(try owner.canonicalBytes() == ownerBytes)
    #expect(try owner.ownerIdentityHash()
        == "0088fbce837df6b89d3fe7f71f0b53f616c20800eda8b393569f3c0863c54b7c")
    #expect(try owner.shortDirectoryName() == "a-0088fbce837d")
    for rejected in [
        Data((String(decoding: ownerBytes, as: UTF8.self) + "\n").utf8),
        Data(#"{ "bootUUID":"11111111-2222-4333-8444-555555555555","stateRootIdentityHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"#.utf8),
        Data(#"{"stateRootIdentityHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bootUUID":"11111111-2222-4333-8444-555555555555"}"#.utf8),
        Data(#"{"bootUUID":"11111111-2222-4333-8444-555555555555","stateRootIdentityHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","extra":true}"#.utf8),
        Data(#"{"bootUUID":"11111111-2222-4333-8444-555555555555","stateRootIdentityHash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#.utf8),
    ] {
        goldenR9DExpectAuthorityFailure {
            _ = try EngineRuntimeOwnerDocumentV1.decodeCanonical(rejected)
        }
    }

    let root = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
    ).appendingPathComponent(
        "g-\(String(UUID().uuidString.prefix(8)))",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let stateLock = try StateDirectoryLock(directoryURL: root)
    let duplicate = try stateLock.duplicateLockedDirectoryDescriptor()
    var duplicateInfo = stat()
    #expect(Darwin.fstat(duplicate, &duplicateInfo) == 0)
    #expect(duplicateInfo.st_mode & S_IFMT == S_IFDIR)
    #expect(duplicateInfo.st_uid == getuid())
    #expect(Darwin.fcntl(duplicate, F_GETFD) & FD_CLOEXEC != 0)
    #expect(Darwin.close(duplicate) == 0)
    let captured = try EngineStateRootIdentityV1.capture(
        stateDirectoryLock: stateLock
    )
    #expect(captured.canonicalPath == root.path)
    #expect(captured.device == UInt64(duplicateInfo.st_dev))
    #expect(captured.inode == UInt64(duplicateInfo.st_ino))

    let collisionRoot = root.appendingPathComponent(
        "short-root-collisions",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: collisionRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let occupied = collisionRoot.appendingPathComponent(
        "occupied",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: occupied,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    var exhaustedAttempts = 0
    do {
        _ = try EngineRuntimeShortRootCollisionGateV1.resolve {
            exhaustedAttempts += 1
            guard occupied.path.withCString({ Darwin.mkdir($0, 0o700) })
                    == 0
            else {
                throw EngineRuntimeAuthorityErrorV1
                    .descriptorFailure(errno)
            }
            return occupied
        }
        Issue.record("eight real short-root collisions must exhaust")
    } catch let error as EngineRuntimeAuthorityErrorV1 {
        #expect(error == .collisionExhausted)
    }
    #expect(exhaustedAttempts == 8)
    #expect(EngineRuntimeShortRootCollisionGateV1.maximumAttempts == 8)

    var retryAttempts = 0
    let admitted = try EngineRuntimeShortRootCollisionGateV1.resolve {
        retryAttempts += 1
        let candidate = retryAttempts == 1
            ? occupied
            : collisionRoot.appendingPathComponent(
                "admitted",
                isDirectory: true
            )
        guard candidate.path.withCString({ Darwin.mkdir($0, 0o700) }) == 0
        else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        return candidate
    }
    #expect(retryAttempts == 2)
    #expect(admitted.lastPathComponent == "admitted")
    #expect(FileManager.default.fileExists(atPath: admitted.path))

    let socketRoot = root.appendingPathComponent(
        "a-0088fbce837d",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: socketRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let socketDescriptor = socketRoot.path.withCString {
        Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    }
    #expect(socketDescriptor >= 0)
    var socketInfo = stat()
    #expect(Darwin.fstat(socketDescriptor, &socketInfo) == 0)
    let authority = try EngineBoardSocketDirectoryAuthorityV1(
        directoryURL: socketRoot,
        ownedDescriptor: socketDescriptor,
        device: UInt64(socketInfo.st_dev),
        inode: UInt64(socketInfo.st_ino),
        uid: UInt32(socketInfo.st_uid),
        mode: UInt16(socketInfo.st_mode & mode_t(0o777)),
        ownerIdentityHash: captured.identityHash(),
        bootId: UUID().uuidString
    )
    let executionId = "22222222-3333-4444-8555-666666666666"
    let socketURL = try EngineRuntimeDirectoryBootstrapV1.makeSocketURL(
        directoryAuthority: authority,
        executionId: executionId
    )
    #expect(socketURL.lastPathComponent == "s-7303dad5f020a7d9.sock")
    #expect(socketURL.path.utf8.count + 1
        <= MemoryLayout.size(ofValue: sockaddr_un().sun_path))

    let lease = try authority.makeDescriptorLease()
    goldenR9DExpectAuthorityFailure { try authority.close() }
    try lease.close()
    goldenR9DExpectAuthorityFailure { try lease.close() }
    try authority.close()
    goldenR9DExpectAuthorityFailure {
        _ = try authority.makeDescriptorLease()
    }

    // The system Darwin temp directory is presented through `/var`, while an
    // opened descriptor reports its one canonical path under `/private/var`.
    // The socket authority must accept that exact descriptor path without
    // asking Foundation to rewrite it back through the public alias.
    let rawDarwinTempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "golden-canonical-socket-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(
        at: rawDarwinTempRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: rawDarwinTempRoot) }
    var canonicalDescriptor = rawDarwinTempRoot.path.withCString {
        Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    }
    #expect(canonicalDescriptor >= 0)
    defer {
        if canonicalDescriptor >= 0 {
            _ = Darwin.close(canonicalDescriptor)
        }
    }
    var canonicalPathBytes = [CChar](
        repeating: 0,
        count: Int(MAXPATHLEN)
    )
    #expect(Darwin.fcntl(
        canonicalDescriptor,
        F_GETPATH,
        &canonicalPathBytes
    ) == 0)
    let canonicalSocketRoot = URL(
        fileURLWithPath: String(cString: canonicalPathBytes),
        isDirectory: true
    )
    #expect(canonicalSocketRoot.path.hasPrefix("/private/var/folders/"))
    #expect(
        canonicalSocketRoot.standardizedFileURL.path
            != canonicalSocketRoot.path
    )
    var canonicalInfo = stat()
    #expect(Darwin.fstat(canonicalDescriptor, &canonicalInfo) == 0)
    let canonicalAuthority = try EngineBoardSocketDirectoryAuthorityV1(
        directoryURL: canonicalSocketRoot,
        ownedDescriptor: canonicalDescriptor,
        device: UInt64(canonicalInfo.st_dev),
        inode: UInt64(canonicalInfo.st_ino),
        uid: UInt32(canonicalInfo.st_uid),
        mode: UInt16(canonicalInfo.st_mode & mode_t(0o777)),
        ownerIdentityHash: captured.identityHash(),
        bootId: UUID().uuidString
    )
    canonicalDescriptor = -1
    try canonicalAuthority.close()
}

private extension EnginePackagedBridgePackageFactsV1 {
    func replacing(
        helperPath: String? = nil,
        nestedCodeSealed: Bool? = nil,
        sealedHelperCDHash: String? = nil
    ) -> Self {
        Self(
            containingAppPath: containingAppPath,
            helperPath: helperPath ?? self.helperPath,
            nestedCodeSealed: nestedCodeSealed ?? self.nestedCodeSealed,
            sealedHelperIdentifier: sealedHelperIdentifier,
            sealedHelperCDHash:
                sealedHelperCDHash ?? self.sealedHelperCDHash,
            appSignature: appSignature,
            helperSignature: helperSignature
        )
    }

    func replacingHelper(
        cdHash: String? = nil,
        teamIdentifier: String? = nil,
        designatedRequirement: String? = nil,
        trustedDeveloperID: Bool? = nil,
        adHoc: Bool? = nil,
        previewInvocation: String? = nil
    ) -> Self {
        let signature = EnginePackagedCodeSignatureFactsV1(
            identifier: helperSignature.identifier,
            cdHash: cdHash ?? helperSignature.cdHash,
            teamIdentifier:
                teamIdentifier ?? helperSignature.teamIdentifier,
            designatedRequirement:
                designatedRequirement
                    ?? helperSignature.designatedRequirement,
            trustedDeveloperID:
                trustedDeveloperID
                    ?? helperSignature.trustedDeveloperID,
            hardenedRuntime: helperSignature.hardenedRuntime,
            secureTimestamp: helperSignature.secureTimestamp,
            adHoc: adHoc ?? helperSignature.adHoc,
            previewInvocation:
                previewInvocation ?? helperSignature.previewInvocation
        )
        return Self(
            containingAppPath: containingAppPath,
            helperPath: self.helperPath,
            nestedCodeSealed: nestedCodeSealed,
            sealedHelperIdentifier: sealedHelperIdentifier,
            sealedHelperCDHash: sealedHelperCDHash,
            appSignature: appSignature,
            helperSignature: signature
        )
    }
}

private func goldenR9DAssertStandaloneBridgePackaging() async throws {
    let appPath = "/Applications/Coding Ranch.app"
    let helperPath = appPath
        + "/Contents/Helpers/AgentLoopBoardBridge"
    let helperCDHash = String(repeating: "a", count: 40)
    let appCDHash = String(repeating: "b", count: 40)
    let developer = EnginePackagedBridgePackageFactsV1(
        containingAppPath: appPath,
        helperPath: helperPath,
        nestedCodeSealed: true,
        sealedHelperIdentifier: "com.muzi.agentloop.board-bridge",
        sealedHelperCDHash: helperCDHash,
        appSignature: EnginePackagedCodeSignatureFactsV1(
            identifier: "com.muzi.agentloop",
            cdHash: appCDHash,
            teamIdentifier: "TEAM123456",
            designatedRequirement: "anchor apple generic and identifier com.muzi.agentloop",
            trustedDeveloperID: true,
            hardenedRuntime: true,
            secureTimestamp: true,
            adHoc: false,
            previewInvocation: nil
        ),
        helperSignature: EnginePackagedCodeSignatureFactsV1(
            identifier: "com.muzi.agentloop.board-bridge",
            cdHash: helperCDHash,
            teamIdentifier: "TEAM123456",
            designatedRequirement: "anchor apple generic and identifier com.muzi.agentloop.board-bridge",
            trustedDeveloperID: true,
            hardenedRuntime: true,
            secureTimestamp: true,
            adHoc: false,
            previewInvocation: nil
        )
    )
    let acceptedDeveloper = try EnginePackagedBridgeAuthenticityValidatorV1
        .validate(developer)
    #expect(acceptedDeveloper.mode == .developerID)
    #expect(acceptedDeveloper.appCDHash == appCDHash)
    #expect(acceptedDeveloper.helperCDHash == helperCDHash)
    #expect(acceptedDeveloper.teamIdentifier == "TEAM123456")
    let readerIdentity = try EnginePackagedBridgeAuthenticityReaderV1
        .validate(
            helperSourcePath: helperPath,
            readPackageFacts: { actualAppPath, actualHelperPath in
                #expect(actualAppPath == appPath)
                #expect(actualHelperPath == helperPath)
                return developer
            }
        )
    #expect(readerIdentity == acceptedDeveloper)

    let preview = EnginePackagedBridgePackageFactsV1(
        containingAppPath: appPath,
        helperPath: helperPath,
        nestedCodeSealed: true,
        sealedHelperIdentifier: "com.muzi.agentloop.board-bridge",
        sealedHelperCDHash: helperCDHash,
        appSignature: EnginePackagedCodeSignatureFactsV1(
            identifier: "com.muzi.agentloop", cdHash: appCDHash,
            teamIdentifier: nil, designatedRequirement: "identifier com.muzi.agentloop",
            trustedDeveloperID: false, hardenedRuntime: false,
            secureTimestamp: false, adHoc: true,
            previewInvocation: nil
        ),
        helperSignature: EnginePackagedCodeSignatureFactsV1(
            identifier: "com.muzi.agentloop.board-bridge", cdHash: helperCDHash,
            teamIdentifier: nil,
            designatedRequirement: "identifier com.muzi.agentloop.board-bridge",
            trustedDeveloperID: false, hardenedRuntime: false,
            secureTimestamp: false, adHoc: true,
            previewInvocation: nil
        )
    )
    #expect(try EnginePackagedBridgeAuthenticityValidatorV1
        .validate(preview).mode == .adHocPreview)

    let rejected: [EnginePackagedBridgePackageFactsV1] = [
        developer.replacing(helperPath: "/tmp/AgentLoopBoardBridge"),
        developer.replacing(nestedCodeSealed: false),
        developer.replacing(sealedHelperCDHash: String(repeating: "c", count: 40)),
        developer.replacingHelper(teamIdentifier: "OTHERTEAM1"),
        developer.replacingHelper(designatedRequirement: "identifier com.muzi.agentloop.board-bridge"),
        developer.replacingHelper(trustedDeveloperID: false, adHoc: true),
        preview.replacingHelper(
            previewInvocation: "44444444-5555-4666-8777-888888888888"
        ),
        preview.replacingHelper(cdHash: String(repeating: "d", count: 40)),
    ]
    for facts in rejected {
        goldenR9DExpectAuthorityFailure {
            _ = try EnginePackagedBridgeAuthenticityValidatorV1.validate(facts)
        }
    }

    let stagingDirectory = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
    ).standardizedFileURL.appendingPathComponent(
            "r9d-bridge-owner-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(
        at: stagingDirectory,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: stagingDirectory) }
    let stage = GoldenR9DBridgeStageFixture(
        stagingDirectory: stagingDirectory
    )
    let capture = GoldenR9DBridgeCaptureGate(
        stagingDirectory: stagingDirectory
    )
    let manager = EnginePackagedBridgeGenerationManagerV1(
        operations: EnginePackagedBridgeGenerationOperationsV1(
            loadPackageIdentity: { acceptedDeveloper },
            stage: { try stage.stage(sourcePath: helperPath) },
            captureRemovalSnapshot: { try capture.capture($0) },
            removeStaged: { try capture.remove($0) }
        )
    )
    let cliAuthority = try goldenR9DCLICompositionAuthority()
    let cliSnapshot = try goldenR9DCLICompositionSnapshot(cliAuthority)
    let cliRemovalCount = GoldenR9DLockedCounter()
    let composer = EngineAdapterRegistryComposerV1(
        factories: goldenR9DCompositionFactories(),
        operations: EngineAdapterRegistryCompositionOperationsV1(
            identifyAndStage: { kind, command in
                #expect(kind == .cliClaude)
                #expect(command == "claude")
                return cliAuthority
            },
            snapshot: { authority in
                #expect(authority == cliAuthority)
                return cliSnapshot
            },
            validateRegistration: { factory, snapshot in
                #expect(factory.profileKinds == [.cliClaude])
                #expect(snapshot == cliSnapshot)
            },
            sourceIdentityMatches: { $0 == cliAuthority },
            removeStagedAuthority: { authority in
                #expect(authority == cliAuthority)
                cliRemovalCount.increment()
            },
            identifyAndStageBoardBridge: {
                try manager.identifyAndStage()
            },
            bridgeSourceIdentityMatches: {
                try manager.sourceIdentityMatches($0)
            },
            removeStagedBridgeAuthority: { try manager.remove($0) }
        )
    )
    do {
        _ = try await composer.registry(
            requestedProfileKinds: [.openAIAPI, .cliClaude]
        )
        Issue.record("bridge cleanup aggregate must escape composition")
    } catch is EngineRuntimeCleanupAggregateErrorV1 {
    } catch {
        Issue.record("wrong bridge composition cleanup error: \(error)")
    }
    #expect(cliRemovalCount.value == 1)
    let retained = try await composer.takeRetainedAuthoritiesForTeardown()
    #expect(retained.cli.isEmpty)
    #expect(retained.bridge.isEmpty)
    let unclaimed = manager.retainedUnclaimedAuthoritiesForTeardown()
    #expect(unclaimed.count == 1)
    let staged = try #require(unclaimed.first)
    #expect(FileManager.default.fileExists(atPath: staged.stagedPath))
    let teardownAuthorities = EngineRuntimeBridgeTeardownAuthoritiesV1.merge(
        composer: retained.bridge,
        manager: unclaimed
    )
    #expect(teardownAuthorities == [staged])
    for authority in teardownAuthorities { try manager.remove(authority) }
    #expect(!FileManager.default.fileExists(atPath: staged.stagedPath))
    #expect(manager.retainedUnclaimedAuthoritiesForTeardown().isEmpty)
}

@Test func twoCardMissionEndToEndColdStart() async throws {
    try goldenR9DAssertColdStartAuthorities()
    let db = try goldenTempDB()
    let camp = try db.ensureDefaultCamp()
    let companionA = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理资料", model: "model-a", campId: camp.id)
    let companionB = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "写结论", model: "model-b", campId: camp.id)
    try db.saveCompanion(companionA)
    try db.saveCompanion(companionB)

    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try Data("A facts".utf8).write(
        to: workspace.appendingPathComponent("facts.md"),
        options: .atomic
    )
    let artifactRoot = try goldenArtifactRoot()

    let plannerProvider = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "plan", name: "propose_plan", input: goldenProposalInput(cards: [
                goldenCardDraftInput(title: "整理事实", description: "写 facts.md", expectedOutput: "facts.md", assignee: 0),
                goldenCardDraftInput(title: "写结论", description: "基于 facts.md 写结论", expectedOutput: "文字结论", assignee: 1, dependsOn: [0]),
            ]))],
            stopReason: .toolUse
        ),
    ])
    let providerA = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "complete-a", name: "complete_card", input: [
                "outcome": "facts ready",
                "summary": "A 产出了 facts.md",
                "artifacts": [[
                    "relativePath": "facts.md",
                    "kind": "markdown",
                    "label": "事实文件",
                ]],
                "verification": [["method": "read_file", "passed": true, "note": "facts.md 存在"]],
                "risks": [],
                "next": "请 B 基于 facts.md 总结",
            ])],
            stopReason: .toolUse
        ),
    ])
    let providerB = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "complete-b", name: "complete_card", input: [
                "outcome": "final ready",
                "summary": "B 已引用 A 的 facts.md 结论",
                "artifacts": [],
                "noArtifactReason": "最终结论写在交接包中",
                "verification": [["method": "检查上游摘要", "passed": true, "note": "已看到 facts.md"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let modelCalls = ModelCallLog()
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "golden-two-card-cold-start",
        model: "planner-model"
    )
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: plannerProvider
        ),
        makeProvider: { model, _ in
            modelCalls.append(model)
            switch model {
            case "planner-model": return plannerProvider
            case "model-a": return providerA
            case "model-b": return providerB
            default: return MockProvider(script: [])
            }
        },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    let missionId = try await orch.startMission(
        goal: "两卡依赖行动",
        companionIds: [companionA.id, companionB.id],
        workspacePath: workspace.path,
        plannerModel: planningIdentity.plannerModel,
        runtimeProfileId: planningIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: nil,
        autonomy: .standard,
        idempotencyKey: planningIdentity.idempotencyKey,
        traceId: planningIdentity.traceId
    )
    try await orch.waitUntilIdle()
    let dispatch = try goldenAttachDispatchContext(
        db: db,
        missionId: missionId,
        companionIds: [companionA.id, companionB.id]
    )
    defer { try? FileManager.default.removeItem(at: dispatch.workspaceRoot) }
    try Data("A facts".utf8).write(
        to: dispatch.workspaceRoot.appendingPathComponent("facts.md"),
        options: .atomic
    )
    try await orch.retryContext(cardId: dispatch.firstCardId)
    try await orch.waitUntilIdle()

    let mission = try #require(try db.mission(id: missionId))
    #expect(mission.status == .delivering)
    let events = try goldenEvents(db, missionId: missionId)
    let transitions = events
        .filter { $0.kind == "mission_status_changed" }
        .map(\.payloadJson)
        .joined(separator: "\n")
    #expect(transitions.contains("planning"))
    #expect(transitions.contains("executing"))
    #expect(transitions.contains("delivering"))

    let bHistory = await providerB.recordedHistories
    guard case .text(let bFirstUser) = bHistory.first?.first?.content.first else {
        Issue.record("expected B first user text")
        return
    }
    #expect(bFirstUser.contains("A 产出了 facts.md"))
    #expect(bFirstUser.contains("facts.md"))

    let artifacts = try db.missionArtifacts(missionId: missionId)
    #expect(artifacts.count == 1)
    let artifact = try #require(artifacts.first)
    #expect(FileManager.default.fileExists(
        atPath: artifactRoot.appendingPathComponent(artifact.path).path
    ))

    try await orch.closeout(missionId, distillModel: "distill-model")
    #expect(try db.mission(id: missionId)?.status == .accepted)
    #expect(modelCalls.values.contains("model-a"))
    #expect(modelCalls.values.contains("model-b"))
    await orch.shutdown()
}

@Test func twoCardMissionWithMidwayAskUser() async throws {
    try await goldenR9DAssertStandaloneBridgePackaging()
    let db = try goldenTempDB()
    let camp = try db.ensureDefaultCamp()
    let companionA = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理资料", model: "model-a", campId: camp.id)
    let companionB = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "写结论", model: "model-b", campId: camp.id)
    try db.saveCompanion(companionA)
    try db.saveCompanion(companionB)

    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let artifactRoot = try goldenArtifactRoot()

    let plannerProvider = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "plan", name: "propose_plan", input: goldenProposalInput(cards: [
                goldenCardDraftInput(title: "整理事实", description: "中途问用户", expectedOutput: "事实摘要", assignee: 0),
                goldenCardDraftInput(title: "写结论", description: "基于事实摘要写结论", expectedOutput: "文字结论", assignee: 1, dependsOn: [0]),
            ]))],
            stopReason: .toolUse
        ),
    ])
    let providerA = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "ask", name: "ask_user", input: [
                "kind": "choice",
                "prompt": "请选择事实整理路线",
                "options": ["fact-route-alpha-unique", "fact-route-beta-unique"],
            ])],
            stopReason: .toolUse
        ),
        TurnResult(
            content: [.toolUse(id: "complete-a", name: "complete_card", input: [
                "outcome": "facts ready",
                "summary": "用户选择 fact-route-beta-unique，A 已整理事实摘要",
                "artifacts": [],
                "noArtifactReason": "事实摘要写在交接包中",
                "verification": [["method": "检查用户回答", "passed": true, "note": "已按 fact-route-beta-unique 整理"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let providerB = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "complete-b", name: "complete_card", input: [
                "outcome": "final ready",
                "summary": "B 已基于 A 的事实摘要交付结论",
                "artifacts": [],
                "noArtifactReason": "最终结论写在交接包中",
                "verification": [["method": "检查上游摘要", "passed": true, "note": "已看到 beta 路线摘要"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "golden-two-card-midway-ask-user",
        model: "planner-model"
    )
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: plannerProvider
        ),
        makeProvider: { model, _ in
            switch model {
            case "planner-model": return plannerProvider
            case "model-a": return providerA
            case "model-b": return providerB
            default: return MockProvider(script: [])
            }
        },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    let missionId = try await orch.startMission(
        goal: "两卡中途问答行动",
        companionIds: [companionA.id, companionB.id],
        workspacePath: workspace.path,
        plannerModel: planningIdentity.plannerModel,
        runtimeProfileId: planningIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: nil,
        autonomy: .standard,
        idempotencyKey: planningIdentity.idempotencyKey,
        traceId: planningIdentity.traceId
    )
    try await orch.waitUntilIdle()
    let dispatch = try goldenAttachDispatchContext(
        db: db,
        missionId: missionId,
        companionIds: [companionA.id, companionB.id]
    )
    defer { try? FileManager.default.removeItem(at: dispatch.workspaceRoot) }
    try await orch.retryContext(cardId: dispatch.firstCardId)
    try await orch.waitUntilIdle()
    let request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":1}"#)
    try await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done])
    #expect(try db.mission(id: missionId)?.status == .delivering)

    let aHistory = await providerA.recordedHistories
    let aResumed = try #require(aHistory.indices.contains(1) ? aHistory[1].first : nil)
    guard case .text(let aUser) = aResumed.content.first else {
        Issue.record("expected A resumed user text")
        return
    }
    #expect(aUser.contains("请选择事实整理路线"))
    #expect(aUser.contains("fact-route-beta-unique"))

    let bHistory = await providerB.recordedHistories
    let bFirst = try #require(bHistory.first?.first)
    guard case .text(let bUser) = bFirst.content.first else {
        Issue.record("expected B first user text")
        return
    }
    #expect(bUser.contains("用户选择 fact-route-beta-unique"))
    #expect(!bUser.contains("# 此前你向用户提问的记录"))
    #expect(!bUser.contains("请选择事实整理路线"))
    await orch.shutdown()
}
