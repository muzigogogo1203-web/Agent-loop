import Testing
import Foundation
import Darwin
import GRDB
import AgentLoopCore

// M7-D5/D8：紧急收哨 + 429 全局冷却

private func haltTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func haltArtifactRoot() throws -> URL {
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "halt-state-\(UUID().uuidString)",
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

private func haltCompanion(_ db: AppDatabase) throws -> CompanionRecord {
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    return companion
}

private func completeScript() -> [TurnResult] {
    [TurnResult(content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
        "outcome": "o", "summary": "s", "noArtifactReason": "无",
        "verification": [["method": "自查", "passed": true, "note": "ok"]],
        "risks": [],
    ])], stopReason: .toolUse)]
}

private enum HaltR9DFixtureError: Error {
    case injected
}

private enum HaltR9DExecutableOperationStage:
    Sendable, CustomStringConvertible
{
    case initialCapture
    case initialValidate
    case retryCapture(EngineRuntimeExecutableRemovalCheckpointV1)
    case retryRemove(EngineRuntimeExecutableRemovalCheckpointV1)
    case parentCapture(moveExactTombstone: Bool)

    var description: String {
        switch self {
        case .initialCapture:
            return "initial_capture"
        case .initialValidate:
            return "initial_validate"
        case .retryCapture(let checkpoint):
            return "retry_capture_\(Self.name(of: checkpoint))"
        case .retryRemove(let checkpoint):
            return "retry_remove_\(Self.name(of: checkpoint))"
        case .parentCapture(let moveExactTombstone):
            return "parent_capture_move_exact_tombstone_\(moveExactTombstone)"
        }
    }

    private static func name(
        of checkpoint: EngineRuntimeExecutableRemovalCheckpointV1
    ) -> String {
        switch checkpoint {
        case .afterUnseal:
            return "after_unseal"
        case .afterExecutableUnlink:
            return "after_executable_unlink"
        case .afterChildFsync:
            return "after_child_fsync"
        }
    }
}

private struct HaltR9DExecutableOperationFailure:
    Error, @unchecked Sendable, CustomStringConvertible
{
    let stage: HaltR9DExecutableOperationStage
    let underlying: any Error

    var description: String {
        "R9-D executable operation failed at \(stage): \(underlying)"
    }
}

private func haltR9DAtExecutableStage<T>(
    _ stage: HaltR9DExecutableOperationStage,
    operation: () throws -> T
) throws -> T {
    do {
        return try operation()
    } catch {
        throw HaltR9DExecutableOperationFailure(
            stage: stage,
            underlying: error
        )
    }
}

private final class HaltR9DCensusPages: @unchecked Sendable {
    private let lock = NSLock()
    private var capacities: [Int] = []
    private let leader: Int32
    private let foreign: Int32

    init(leader: Int32, foreign: Int32) {
        self.leader = leader
        self.foreign = foreign
    }

    func page(capacity: Int) -> [Int32] {
        lock.withLock {
            capacities.append(capacity)
            if capacities.count == 1 { return [leader, 999] }
            return [leader, foreign]
        }
    }

    var requestedCapacities: [Int] { lock.withLock { capacities } }
}

private final class HaltR9DProcessInspector:
    EngineRuntimeProcessInspectingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private var snapshotResults:
        [Result<[EngineRuntimeProcessSnapshotV1], Error>]
    private var existenceResults: [Result<Bool, Error>]
    private let failingSignals: Set<Int32>
    private var storedSignals: [(Int32, Int32)] = []

    init(
        snapshots: [Result<[EngineRuntimeProcessSnapshotV1], Error>],
        existence: [Result<Bool, Error>] = [.success(false)],
        failingSignals: Set<Int32> = []
    ) {
        snapshotResults = snapshots
        existenceResults = existence
        self.failingSignals = failingSignals
    }

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        try lock.withLock {
            guard !snapshotResults.isEmpty else {
                throw HaltR9DFixtureError.injected
            }
            return try snapshotResults.removeFirst().get()
        }
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        try lock.withLock {
            storedSignals.append((signal, processGroupId))
            if failingSignals.contains(signal) {
                throw EngineRuntimeAuthorityErrorV1.processSignal(EIO)
            }
        }
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        try lock.withLock {
            guard !existenceResults.isEmpty else { return false }
            return try existenceResults.removeFirst().get()
        }
    }

    var signals: [(Int32, Int32)] { lock.withLock { storedSignals } }
}

private func haltR9DSnapshot(
    pid: Int32,
    group: Int32,
    uid: UInt32 = UInt32(getuid()),
    hash: Character = "a"
) -> EngineRuntimeProcessSnapshotV1 {
    EngineRuntimeProcessSnapshotV1(
        pid: pid,
        processGroupId: group,
        uid: uid,
        startSeconds: UInt64(pid),
        startMicroseconds: 7,
        executablePath: "/fixtures/\(hash)/executable",
        executableDevice: UInt64(pid + 10),
        executableInode: UInt64(pid + 20),
        executableHash: String(repeating: hash, count: 64),
        designatedRequirement: "identifier fixture.\(hash)",
        cdHash: String(repeating: hash, count: 40)
    )
}

private func haltR9DAuthority(
    _ snapshot: EngineRuntimeProcessSnapshotV1
) -> EngineOwnedRuntimeExecutableV1 {
    EngineOwnedRuntimeExecutableV1(
        executablePath: snapshot.executablePath,
        executableDevice: snapshot.executableDevice,
        executableInode: snapshot.executableInode,
        executableHash: snapshot.executableHash,
        designatedRequirement: snapshot.designatedRequirement,
        cdHash: snapshot.cdHash
    )
}

private func haltR9DExpectAuthorityFailure(
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected R9-D fail-closed error")
    } catch is EngineRuntimeAuthorityErrorV1 {
    } catch is EngineRuntimeCleanupAggregateErrorV1 {
    } catch is HaltR9DFixtureError {
    } catch {
        Issue.record("unexpected R9-D error: \(error)")
    }
}

private func haltR9DAssertStartupCleanupBehavior() throws {
    let leader = haltR9DSnapshot(pid: 101, group: 101, hash: "a")
    let child = haltR9DSnapshot(pid: 102, group: 101, hash: "b")
    let unrelated = haltR9DSnapshot(pid: 900, group: 900, hash: "f")
    let censusPages = HaltR9DCensusPages(leader: leader.pid, foreign: 103)
    let completePIDs = try EngineDarwinProcessCensusV1.enumerate(
        initialCapacity: 2,
        page: censusPages.page(capacity:)
    )
    #expect(censusPages.requestedCapacities == [2, 4])
    #expect(completePIDs == [leader.pid, 103])
    let inspector = HaltR9DProcessInspector(
        snapshots: [
            .success([leader, child, unrelated]),
            .success([leader, child, unrelated]),
        ],
        existence: [.success(false)]
    )
    try EngineOldBootProcessCleanupV1(
        processInspector: inspector,
        terminationGrace: .zero,
        sleep: { _ in }
    ).terminateOwnedProcessGroups(
        authorities: [haltR9DAuthority(leader), haltR9DAuthority(child)]
    )
    #expect(inspector.signals.map(\.0) == [SIGSTOP, SIGTERM, SIGCONT])
    #expect(inspector.signals.allSatisfy { $0.1 == 101 })

    let foreign = haltR9DSnapshot(
        pid: 103,
        group: 101,
        uid: UInt32(getuid()) + 1,
        hash: "c"
    )
    let foreignInspector = HaltR9DProcessInspector(
        snapshots: [.success([leader, foreign])]
    )
    haltR9DExpectAuthorityFailure {
        try EngineOldBootProcessCleanupV1(
            processInspector: foreignInspector,
            terminationGrace: .zero,
            sleep: { _ in }
        ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    }
    #expect(foreignInspector.signals.isEmpty)

    let saturatedForeignInspector = HaltR9DProcessInspector(
        snapshots: [.success(completePIDs.map { pid in
            pid == leader.pid ? leader : foreign
        })]
    )
    haltR9DExpectAuthorityFailure {
        try EngineOldBootProcessCleanupV1(
            processInspector: saturatedForeignInspector,
            terminationGrace: .zero,
            sleep: { _ in }
        ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    }
    #expect(saturatedForeignInspector.signals.isEmpty)

    let unavailableInspector = HaltR9DProcessInspector(
        snapshots: [.failure(HaltR9DFixtureError.injected)]
    )
    haltR9DExpectAuthorityFailure {
        try EngineOldBootProcessCleanupV1(
            processInspector: unavailableInspector,
            terminationGrace: .zero,
            sleep: { _ in }
        ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    }
    #expect(unavailableInspector.signals.isEmpty)
}

private func haltR9DAssertRetryAndDriftBehavior() throws {
    let leader = haltR9DSnapshot(pid: 201, group: 201, hash: "a")
    let drift = haltR9DSnapshot(pid: 201, group: 201, hash: "d")
    let driftInspector = HaltR9DProcessInspector(
        snapshots: [.success([leader]), .success([drift])]
    )
    haltR9DExpectAuthorityFailure {
        try EngineOldBootProcessCleanupV1(
            processInspector: driftInspector,
            terminationGrace: .zero,
            sleep: { _ in }
        ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    }
    #expect(driftInspector.signals.map(\.0) == [SIGSTOP])

    let killInspector = HaltR9DProcessInspector(
        snapshots: [.success([leader]), .success([leader])],
        existence: [.success(true), .success(false)]
    )
    try EngineOldBootProcessCleanupV1(
        processInspector: killInspector,
        terminationGrace: .zero,
        sleep: { _ in }
    ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    #expect(killInspector.signals.map(\.0)
        == [SIGSTOP, SIGTERM, SIGCONT, SIGKILL])

    let signalFailure = HaltR9DProcessInspector(
        snapshots: [.success([leader]), .success([leader])],
        existence: [.success(true), .success(false)],
        failingSignals: [SIGTERM]
    )
    haltR9DExpectAuthorityFailure {
        try EngineOldBootProcessCleanupV1(
            processInspector: signalFailure,
            terminationGrace: .zero,
            sleep: { _ in }
        ).terminateOwnedProcessGroups(authorities: [haltR9DAuthority(leader)])
    }
    #expect(signalFailure.signals.map(\.0)
        == [SIGSTOP, SIGTERM, SIGCONT, SIGKILL])

    // Executable authorities live under the canonical long state root in
    // production. The macOS temporary directory is exposed as /var while
    // F_GETPATH returns /private/var; the validator intentionally rejects
    // that alias outside the dedicated socket-temp authority path.
    let root = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
    ).standardizedFileURL.appendingPathComponent(
        "r9d-old-executable-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let bytes = Data("immutable-old-executable".utf8)
    let hash = CanonicalJSONV1.sha256Hex(bytes)
    let authorityURL = root.appendingPathComponent(
        "cli_codex-\(hash)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: authorityURL,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let executableURL = authorityURL.appendingPathComponent("executable")
    try bytes.write(to: executableURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: executableURL.path
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: authorityURL.path
    )
    let parent = root.path.withCString {
        Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    }
    #expect(parent >= 0)
    defer { #expect(Darwin.close(parent) == 0) }
    let signing = EngineRuntimeSigningIdentitySnapshotV1(
        designatedRequirement: "anchor apple generic and identifier codex",
        teamIdentifier: "2DC432GLL2",
        cdHash: String(repeating: "e", count: 40)
    )
    let snapshot = try haltR9DAtExecutableStage(.initialCapture) {
        try EngineRuntimeExecutableRemovalValidatorV1.capture(
            parentDescriptor: parent,
            authorityName: authorityURL.lastPathComponent,
            inspectSignature: { _ in signing }
        )
    }
    try haltR9DAtExecutableStage(.initialValidate) {
        try EngineRuntimeExecutableRemovalValidatorV1
            .validateImmediatelyBeforeUnseal(
                snapshot,
                parentDescriptor: parent,
                inspectSignature: { _ in signing }
            )
    }
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: authorityURL.path
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: executableURL.path
    )
    try Data("mutated-old-executable!".utf8).write(to: executableURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: executableURL.path
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: authorityURL.path
    )
    haltR9DExpectAuthorityFailure {
        try EngineRuntimeExecutableRemovalValidatorV1
            .validateImmediatelyBeforeUnseal(
                snapshot,
                parentDescriptor: parent,
                inspectSignature: { _ in signing }
            )
    }
    #expect(FileManager.default.fileExists(atPath: executableURL.path))

    for checkpoint in [
        EngineRuntimeExecutableRemovalCheckpointV1.afterUnseal,
        .afterExecutableUnlink,
        .afterChildFsync,
    ] {
        let retryBytes = Data("retryable-\(checkpoint)".utf8)
        let retryHash = CanonicalJSONV1.sha256Hex(retryBytes)
        let retryAuthority = root.appendingPathComponent(
            "cli_codex-\(retryHash)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: retryAuthority,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let retryExecutable = retryAuthority.appendingPathComponent(
            "executable"
        )
        try retryBytes.write(to: retryExecutable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: retryExecutable.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: retryAuthority.path
        )
        let retrySnapshot = try haltR9DAtExecutableStage(
            .retryCapture(checkpoint)
        ) {
            try EngineRuntimeExecutableRemovalValidatorV1.capture(
                parentDescriptor: parent,
                authorityName: retryAuthority.lastPathComponent,
                inspectSignature: { _ in signing }
            )
        }
        haltR9DExpectAuthorityFailure {
            try EngineRuntimeExecutableRemovalValidatorV1.removeImmediately(
                retrySnapshot,
                parentDescriptor: parent,
                inspectSignature: { _ in signing },
                checkpoint: { reached in
                    if reached == checkpoint {
                        throw HaltR9DFixtureError.injected
                    }
                }
            )
        }
        #expect(FileManager.default.fileExists(atPath: retryAuthority.path))
        if checkpoint == .afterUnseal {
            #expect(
                try FileManager.default.attributesOfItem(
                    atPath: retryAuthority.path
                )[.posixPermissions] as? NSNumber == NSNumber(value: 0o500)
            )
            #expect(FileManager.default.fileExists(
                atPath: retryExecutable.path
            ))
        } else {
            #expect(!FileManager.default.fileExists(
                atPath: retryExecutable.path
            ))
        }
        try haltR9DAtExecutableStage(.retryRemove(checkpoint)) {
            try EngineRuntimeExecutableRemovalValidatorV1.removeImmediately(
                retrySnapshot,
                parentDescriptor: parent,
                inspectSignature: { _ in signing }
            )
        }
        #expect(!FileManager.default.fileExists(atPath: retryAuthority.path))
    }

    for moveExactTombstone in [false, true] {
        let parentURL = root.appendingPathComponent(
            "parent-swap-\(moveExactTombstone)",
            isDirectory: true
        )
        let movedParentURL = root.appendingPathComponent(
            "parent-moved-\(moveExactTombstone)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let parentBytes = Data(
            "parent-identity-\(moveExactTombstone)".utf8
        )
        let parentHash = CanonicalJSONV1.sha256Hex(parentBytes)
        let parentAuthority = parentURL.appendingPathComponent(
            "cli_codex-\(parentHash)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: parentAuthority,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let parentExecutable = parentAuthority.appendingPathComponent(
            "executable"
        )
        try parentBytes.write(to: parentExecutable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: parentExecutable.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: parentAuthority.path
        )
        var originalParent = parentURL.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard originalParent >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        let parentSnapshot = try haltR9DAtExecutableStage(
            .parentCapture(moveExactTombstone: moveExactTombstone)
        ) {
            try EngineRuntimeExecutableRemovalValidatorV1.capture(
                parentDescriptor: originalParent,
                authorityName: parentAuthority.lastPathComponent,
                inspectSignature: { _ in signing }
            )
        }
        if moveExactTombstone {
            haltR9DExpectAuthorityFailure {
                try EngineRuntimeExecutableRemovalValidatorV1
                    .removeImmediately(
                        parentSnapshot,
                        parentDescriptor: originalParent,
                        inspectSignature: { _ in signing },
                        checkpoint: { reached in
                            if reached == .afterExecutableUnlink {
                                throw HaltR9DFixtureError.injected
                            }
                        }
                    )
            }
            #expect(!FileManager.default.fileExists(
                atPath: parentExecutable.path
            ))
        }
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&originalParent)

        try FileManager.default.moveItem(
            at: parentURL,
            to: movedParentURL
        )
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let replacementAuthority = parentURL.appendingPathComponent(
            parentAuthority.lastPathComponent,
            isDirectory: true
        )
        if moveExactTombstone {
            try FileManager.default.moveItem(
                at: movedParentURL.appendingPathComponent(
                    parentAuthority.lastPathComponent,
                    isDirectory: true
                ),
                to: replacementAuthority
            )
        }
        var replacementParent = parentURL.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard replacementParent >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        haltR9DExpectAuthorityFailure {
            try EngineRuntimeExecutableRemovalValidatorV1.removeImmediately(
                parentSnapshot,
                parentDescriptor: replacementParent,
                inspectSignature: { _ in signing }
            )
        }
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&replacementParent)
        if moveExactTombstone {
            #expect(FileManager.default.fileExists(
                atPath: replacementAuthority.path
            ))
        } else {
            #expect(FileManager.default.fileExists(
                atPath: movedParentURL
                    .appendingPathComponent(
                        parentAuthority.lastPathComponent,
                        isDirectory: true
                    )
                    .appendingPathComponent("executable").path
            ))
        }
    }
}

private final class HaltR9DTeardownRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [EngineRuntimeTeardownStepKindV1] = []
    private let failures: Set<EngineRuntimeTeardownStepKindV1>

    init(failures: Set<EngineRuntimeTeardownStepKindV1> = []) {
        self.failures = failures
    }

    func close(_ kind: EngineRuntimeTeardownStepKindV1) throws {
        try lock.withLock {
            stored.append(kind)
            if failures.contains(kind) { throw HaltR9DFixtureError.injected }
        }
    }

    var values: [EngineRuntimeTeardownStepKindV1] {
        lock.withLock { stored }
    }
}

private func haltR9DAssertCheckedTeardownBehavior() throws {
    let orderedKinds: [EngineRuntimeTeardownStepKindV1] = [
        .retainedCliGenerations,
        .retainedBridgeGenerations,
        .currentBootResidue,
        .boardSocketAuthority,
        .runtimeDirectoryDescriptors,
    ]
    let blockedRecorder = HaltR9DTeardownRecorder()
    let blocked = EngineCheckedRuntimeTeardownV1(
        outstandingCaptureCount: { 1 },
        steps: orderedKinds.map { kind in
            EngineRuntimeTeardownStepV1(kind: kind) {
                try blockedRecorder.close(kind)
            }
        }
    )
    haltR9DExpectAuthorityFailure { try blocked.close() }
    #expect(blockedRecorder.values.isEmpty)
    try blocked.requireOpen()

    let recorder = HaltR9DTeardownRecorder(
        failures: [.retainedBridgeGenerations, .boardSocketAuthority]
    )
    let teardown = EngineCheckedRuntimeTeardownV1(
        outstandingCaptureCount: { 0 },
        steps: orderedKinds.map { kind in
            EngineRuntimeTeardownStepV1(kind: kind) {
                try recorder.close(kind)
            }
        }
    )
    haltR9DExpectAuthorityFailure { try teardown.close() }
    #expect(recorder.values == orderedKinds)
    haltR9DExpectAuthorityFailure { try teardown.close() }
    haltR9DExpectAuthorityFailure { try teardown.requireOpen() }
    #expect(recorder.values == orderedKinds)

    var reusedOwner = "/dev/null".withCString {
        Darwin.open($0, O_RDONLY | O_CLOEXEC)
    }
    #expect(reusedOwner >= 0)
    var sentinel: Int32 = -1
    haltR9DExpectAuthorityFailure {
        try EngineRuntimeOwnedDescriptorV1.closeOnce(
            &reusedOwner,
            close: { descriptor in
                #expect(Darwin.close(descriptor) == 0)
                sentinel = "/dev/null".withCString {
                    Darwin.open($0, O_RDONLY | O_CLOEXEC)
                }
                #expect(sentinel == descriptor)
                throw HaltR9DFixtureError.injected
            }
        )
    }
    #expect(reusedOwner == -1)
    #expect(Darwin.fcntl(sentinel, F_GETFD) >= 0)
    #expect(Darwin.close(sentinel) == 0)
}

private func planningScript() -> [TurnResult] {
    [TurnResult(content: [.toolUse(id: "plan", name: "propose_plan", input: [
        "goalRefined": "规划完成",
        "cards": [[
            "title": "执行",
            "description": "执行任务",
            "expectedOutput": "可验证结果",
            "assignee": 0,
            "dependsOn": [],
        ]],
    ])], stopReason: .toolUse)]
}

private func waitForCard(
    _ db: AppDatabase, _ cardId: String, status: CardStatus, timeout: Duration = .seconds(5)
) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if try db.card(id: cardId)?.status == status { return true }
        try await Task.sleep(for: .milliseconds(30))
    }
    return try db.card(id: cardId)?.status == status
}

private func globalEvents(_ db: AppDatabase, kind: String) throws -> Int {
    try db.pool.read { database in
        try EventRecord.filter(Column("kind") == kind).fetchCount(database)
    }
}

private actor HaltGate {
    private var passesBeforeSuspend: Int
    private var entered = false
    private var opened = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    init(passesBeforeSuspend: Int = 0) {
        self.passesBeforeSuspend = passesBeforeSuspend
    }

    func suspend() async {
        if passesBeforeSuspend > 0 {
            passesBeforeSuspend -= 1
            return
        }
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !opened else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        opened = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private actor HaltHangingProvider: LLMProvider {
    private var calls = 0
    private var cancellations = 0
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String, history: [APIMessage], tools: [ToolDef],
        toolChoice: ToolChoice, maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
                do {
                    try await Task.sleep(for: .seconds(3_600))
                    continuation.finish()
                } catch is CancellationError {
                    await self.markCanceled()
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func markStarted() {
        calls += 1
        startedWaiters.forEach { $0.resume() }
        startedWaiters.removeAll()
    }

    private func markCanceled() {
        cancellations += 1
    }

    func waitUntilStarted() async {
        guard calls == 0 else { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func waitUntilCanceled(timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while cancellations == 0 && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return cancellations > 0
    }

    var callCount: Int { calls }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private struct HaltFailingTransport: McpTransport {
    let messages = AsyncThrowingStream<Data, Error> { $0.finish() }
    func start() async throws { throw McpClientError.connectionClosed }
    func send(_ data: Data) async throws { throw McpClientError.connectionClosed }
    func close() async {}
}

/// 立抛 429 的替身：AgentLoop 层 429 不重试（provider 层已重试过），错误直达 Orchestrator
private struct RateLimitedProvider: LLMProvider {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                    toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.http(status: 429, body: "rate limited"))
        }
    }
}

private struct HaltGatedPlanningProvider: LLMProvider {
    let base: any LLMProvider
    let gate: HaltGate

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in base.streamTurn(
                        system: system,
                        history: history,
                        tools: tools,
                        toolChoice: toolChoice,
                        maxTokens: maxTokens
                    ) {
                        continuation.yield(event)
                    }
                    await gate.suspend()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@Test func emergencyStopHaltsDispatchAndResumeContinues() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: completeScript())
        ),
        makeProvider: { _, _ in MockProvider(script: completeScript()) },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )

    // 收哨后 reconcile 不派发
    try await orchestrator.emergencyStop()
    await orchestrator.reconcile()
    try await Task.sleep(for: .milliseconds(150))
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(try globalEvents(db, kind: "camp_halted") == 1)
    let halted = await orchestrator.isHalted
    #expect(halted)

    // 解除收哨 → 立即派发 → 完成
    try await orchestrator.resume()
    let done = try await waitForCard(db, ids.cardId, status: .done)
    #expect(done)
    #expect(try globalEvents(db, kind: "camp_resumed") == 1)
}

@Test func haltedStartupRunsCleanupWithoutPumpTimerOrProvider() async throws {
    try haltR9DAssertStartupCleanupBehavior()
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let planningMissionId = try db.createMissionShell(
        goal: "planning", companionIds: [companion.id], workspacePath: nil)
    let campId = try #require(try db.squad(forMission: ids.missionId)?.campId)
    let server = McpServerRecord.new(name: "halt-test", command: "false", args: [])
    try db.addMcpServer(server)
    try db.setMcpServerEnabled(campId: campId, serverId: server.id, enabled: true)
    try db.transitionDispatchMode(from: .running, to: .halted)

    let transportCreations = LockedCounter()
    let manager = McpServerManager(
        db: db,
        transportFactory: { _, _ in
            transportCreations.increment()
            return HaltFailingTransport()
        },
        baseEnvironment: { [:] },
        initTimeout: .milliseconds(10),
        callTimeout: .milliseconds(10)
    )
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: .milliseconds(1),
        mcpManager: manager
    )

    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(await provider.callCount == 0)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(transportCreations.count == 0)
    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    let planningEvents = try db.events(missionId: planningMissionId)
    #expect(planningEvents.contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    #expect(planningEvents.filter {
        $0.kind == EventKind.missionFailed
    }.count == 1)
    let planningWork = try await db.pool.read { database in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateId") == planningMissionId
            )
            .fetchAll(database)
    }
    #expect(planningWork.count == 1)
    #expect(planningWork.first?.state == .canceled)
    #expect(
        planningWork.first?.errorMessage
            == "emergency_halt_during_planning"
    )
    await orchestrator.shutdown()
}

@Test func startupBootstrapGateBlocksDispatchUntilRecoveryCompletes() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let provider = MockProvider(script: completeScript())
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "halt-startup-bootstrap-too-early",
        model: "m"
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        requiresStartupRecovery: true
    )
    let missionCountBefore = try await db.pool.read { try MissionRecord.fetchCount($0) }

    await orchestrator.reconcile()
    do {
        _ = try await orchestrator.startMission(
            goal: "too early", companionIds: [companion.id],
            workspacePath: nil,
            plannerModel: planningIdentity.plannerModel,
            runtimeProfileId: planningIdentity.runtimeProfileId,
            budgetTokens: KernelDefaults.missionBudget,
            campId: nil,
            autonomy: .standard,
            idempotencyKey: planningIdentity.idempotencyKey,
            traceId: planningIdentity.traceId
        )
        Issue.record("startup bootstrap must reject direct starts before recovery")
    } catch let error as UserVisibleOperationError {
        #expect(error.failure.traceId == planningIdentity.traceId)
        #expect(error.failure.operation == .missionStart)
        #expect(error.failure.scope.type == .mission)
        #expect(error.failure.scope.id == "mission_index")
    } catch {
        Issue.record("unexpected bootstrap error: \(error)")
    }

    #expect(try await db.pool.read { try MissionRecord.fetchCount($0) } == missionCountBefore)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)

    await orchestrator.recoverAndReconcile()
    try await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

private func enqueueStartupPlanningProbe(
    db: AppDatabase,
    companion: CompanionRecord,
    command: String,
    provider: any LLMProvider
) throws -> (
    identity: TestPlanningCommandIdentity,
    resolver: TestPlanningProviderResolver,
    missionId: String,
    workId: String
) {
    let identity = try testPlanningCommandIdentity(
        db: db,
        command: command,
        model: "m"
    )
    let resolver = TestPlanningProviderResolver(
        profileId: identity.runtimeProfileId,
        model: identity.plannerModel,
        provider: provider
    )
    let enqueued = try db.enqueueMissionPlanning(
        goal: "startup planning probe \(command)",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: KernelDefaults.missionBudget,
        campId: companion.campId,
        autonomy: .standard,
        planningInput: try PlanningWorkInput(
            plannerModel: identity.plannerModel,
            runtimeProfileId: identity.runtimeProfileId
        ),
        idempotencyKey: identity.idempotencyKey,
        traceId: identity.traceId,
        planningProviderResolver: resolver
    )
    return (
        identity,
        resolver,
        enqueued.missionId,
        enqueued.workId
    )
}

private func installStartupCardAdoptionFailure(
    db: AppDatabase,
    triggerName: String,
    cardId: String
) throws {
    try db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER \(triggerName)
            BEFORE UPDATE OF status ON card
            WHEN OLD.id = '\(cardId)'
              AND OLD.status = 'running'
              AND NEW.status = 'ready'
            BEGIN
              SELECT RAISE(ABORT, 'injected startup Card adoption failure');
            END
            """)
    }
}

private func installStartupPlanningAdoptionFailure(
    db: AppDatabase,
    triggerName: String,
    workId: String
) throws {
    try db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER \(triggerName)
            BEFORE UPDATE OF state ON durable_work
            WHEN OLD.id = '\(workId)'
              AND OLD.state = 'running'
              AND NEW.state = 'queued'
            BEGIN
              SELECT RAISE(ABORT, 'injected startup planning adoption failure');
            END
            """)
    }
}

private struct HaltPlanningSnapshot: Equatable {
    let missions: Int
    let squads: Int
    let works: Int
    let attempts: Int
    let cards: Int
    let events: Int
}

private func haltPlanningSnapshot(
    _ db: AppDatabase
) throws -> HaltPlanningSnapshot {
    try db.pool.read { database in
        HaltPlanningSnapshot(
            missions: try MissionRecord.fetchCount(database),
            squads: try SquadRecord.fetchCount(database),
            works: try DurableWorkRecord.fetchCount(database),
            attempts: try DurableWorkAttemptRecord.fetchCount(database),
            cards: try CardRecord.fetchCount(database),
            events: try EventRecord.fetchCount(database)
        )
    }
}

private func haltPlanningWorks(
    _ db: AppDatabase,
    missionId: String
) throws -> [DurableWorkRecord] {
    try db.pool.read { database in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateType") == "mission"
                    && Column("aggregateId") == missionId
            )
            .order(Column("createdAt"), Column("id"))
            .fetchAll(database)
    }
}

@Test func runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let identity = try testPlanningCommandIdentity(
        db: db,
        command: "running-startup-two-phase",
        model: "m"
    )
    let provider = HaltHangingProvider()
    let resolutions = LockedCounter()
    let resolver = TestPlanningProviderResolver { _, _ in
        resolutions.increment()
        return provider
    }
    let enqueued = try db.enqueueMissionPlanning(
        goal: "must wait for Card recovery",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: KernelDefaults.missionBudget,
        campId: companion.campId,
        autonomy: .standard,
        planningInput: try PlanningWorkInput(
            plannerModel: identity.plannerModel,
            runtimeProfileId: identity.runtimeProfileId
        ),
        idempotencyKey: identity.idempotencyKey,
        traceId: identity.traceId,
        planningProviderResolver: resolver
    )
    #expect(resolutions.count == 1)

    let supervisor = DurableWorkSupervisor(
        database: db,
        planningProviderResolver: resolver,
        workerId: "two-phase-startup-worker",
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )
    try await supervisor.recoverOnStartup(
        profileModels: [identity.runtimeProfileId: identity.plannerModel]
    )

    do {
        try await supervisor.startIfNeeded()
        Issue.record(
            "running recovery must remain suppressed until Card recovery activates it"
        )
    } catch is SupervisorDispatchSuppressedError {
    } catch {
        Issue.record("unexpected two-phase startup error: \(error)")
    }

    #expect(
        try DurableWorkStore(database: db).work(id: enqueued.workId)?.state
            == .queued
    )
    #expect(resolutions.count == 1)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(10))
}

@Test func startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let card = try db.createSingleCardMission(
        campName: "startup-card-failure",
        squadName: "startup-card-failure",
        goal: "recover Card before planning",
        cardTitle: "orphan",
        cardDescription: "orphan",
        expectedOutput: "recovered",
        assigneeId: companion.id,
        maxTurns: 5,
        workspacePath: nil
    )
    try db.startRun(cardId: card.cardId, runId: "startup-card-failure-run")
    try installStartupCardAdoptionFailure(
        db: db,
        triggerName: "fail_r11_startup_card_adoption",
        cardId: card.cardId
    )
    let planningProvider = HaltHangingProvider()
    let planning = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "card-adoption-failure-suppresses-planning",
        provider: planningProvider
    )
    let cardProvider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: planning.resolver,
        makeProvider: { _, _ in cardProvider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()

    #expect(try db.dispatchMode() == .running)
    #expect(await orchestrator.isHalted)
    #expect(await planningProvider.callCount == 0)
    #expect(await cardProvider.callCount == 0)
    #expect(
        try DurableWorkStore(database: db).work(id: planning.workId)?.state
            == .queued
    )
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(
        try db.runs(cardId: card.cardId)
            .first { $0.id == "startup-card-failure-run" }?.outcome == nil
    )
    _ = await orchestrator.shutdown()
}

@Test func explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let card = try db.createSingleCardMission(
        campName: "startup-card-retry",
        squadName: "startup-card-retry",
        goal: "retry Card recovery",
        cardTitle: "orphan",
        cardDescription: "orphan",
        expectedOutput: "recovered",
        assigneeId: companion.id,
        maxTurns: 5,
        workspacePath: nil
    )
    let crashedRunId = "startup-card-retry-run"
    try db.startRun(cardId: card.cardId, runId: crashedRunId)
    try installStartupCardAdoptionFailure(
        db: db,
        triggerName: "fail_r11_startup_card_retry",
        cardId: card.cardId
    )
    let planningProvider = MockProvider(script: planningScript())
    let planning = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "card-retry-activates-once",
        provider: planningProvider
    )
    let cardProvider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: planning.resolver,
        makeProvider: { _, _ in cardProvider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()
    #expect(await planningProvider.callCount == 0)
    #expect(
        try DurableWorkStore(database: db).work(id: planning.workId)?.state
            == .queued
    )

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_r11_startup_card_retry")
    }
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()
    #expect(await planningProvider.callCount == 1)
    #expect(
        try DurableWorkStore(database: db).work(id: planning.workId)?.state
            == .succeeded
    )
    #expect(
        try db.runs(cardId: card.cardId)
            .first { $0.id == crashedRunId }?.outcome == "interrupted"
    )

    await orchestrator.recoverAndReconcile()
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()
    #expect(await planningProvider.callCount == 1)
    _ = await orchestrator.shutdown()
}

@Test func startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent()
    async throws
{
    do {
        let db = try haltTempDB()
        let companion = try haltCompanion(db)
        let planningProvider = MockProvider(script: planningScript())
        let planning = try enqueueStartupPlanningProbe(
            db: db,
            companion: companion,
            command: "first-phase-full-retry",
            provider: planningProvider
        )
        _ = try #require(try db.claimNextPlanning(
            workerId: "crashed-first-phase-worker",
            now: Date(timeIntervalSinceReferenceDate: 1_000),
            leaseDuration: 60
        ))
        try installStartupPlanningAdoptionFailure(
            db: db,
            triggerName: "fail_r11_first_phase_adoption",
            workId: planning.workId
        )
        let orchestrator = Orchestrator(
            db: db,
            planningProviderResolver: planning.resolver,
            makeProvider: { _, _ in nil },
            artifactStoreRoot: try haltArtifactRoot(),
            tickInterval: nil
        )

        await orchestrator.recoverAndReconcile()
        #expect(await planningProvider.callCount == 0)
        #expect(try db.dispatchMode() == .running)
        #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
        #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)

        try await db.pool.write {
            try $0.execute(sql: "DROP TRIGGER fail_r11_first_phase_adoption")
        }
        try await orchestrator.resume()
        try await orchestrator.waitUntilIdle()
        #expect(await planningProvider.callCount == 1)
        #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
        #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
        _ = await orchestrator.shutdown()
    }

    do {
        let db = try haltTempDB()
        let companion = try haltCompanion(db)
        let card = try db.createSingleCardMission(
            campName: "card-only-retry",
            squadName: "card-only-retry",
            goal: "Card-only retry",
            cardTitle: "orphan",
            cardDescription: "orphan",
            expectedOutput: "recovered",
            assigneeId: companion.id,
            maxTurns: 5,
            workspacePath: nil
        )
        try db.startRun(
            cardId: card.cardId,
            runId: "card-only-retry-run"
        )
        try installStartupCardAdoptionFailure(
            db: db,
            triggerName: "fail_r11_card_only_retry",
            cardId: card.cardId
        )
        let planningProvider = MockProvider(script: planningScript())
        let planning = try enqueueStartupPlanningProbe(
            db: db,
            companion: companion,
            command: "card-only-retry",
            provider: planningProvider
        )
        let cardProvider = MockProvider(script: completeScript())
        let orchestrator = Orchestrator(
            db: db,
            planningProviderResolver: planning.resolver,
            makeProvider: { _, _ in cardProvider },
            artifactStoreRoot: try haltArtifactRoot(),
            tickInterval: nil
        )

        await orchestrator.recoverAndReconcile()
        #expect(await planningProvider.callCount == 0)
        #expect(try db.dispatchMode() == .running)
        #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
        #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)

        try await db.pool.write {
            try $0.execute(sql: "DROP TRIGGER fail_r11_card_only_retry")
        }
        try await orchestrator.resume()
        try await orchestrator.waitUntilIdle()
        #expect(await planningProvider.callCount == 1)
        #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
        #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
        _ = await orchestrator.shutdown()
    }
}

@Test func staleStartupRecoveryCannotActivateAfterConcurrentControlTransition()
    async throws
{
    do {
        let db = try haltTempDB()
        let companion = try haltCompanion(db)
        let planningProvider = HaltHangingProvider()
        let planning = try enqueueStartupPlanningProbe(
            db: db,
            companion: companion,
            command: "shutdown-clears-first-phase-token",
            provider: planningProvider
        )
        _ = try #require(try db.claimNextPlanning(
            workerId: "crashed-shutdown-worker",
            now: Date(timeIntervalSinceReferenceDate: 1_000),
            leaseDuration: 60
        ))
        try installStartupPlanningAdoptionFailure(
            db: db,
            triggerName: "fail_r11_shutdown_first_phase",
            workId: planning.workId
        )
        let orchestrator = Orchestrator(
            db: db,
            planningProviderResolver: planning.resolver,
            makeProvider: { _, _ in nil },
            artifactStoreRoot: try haltArtifactRoot(),
            tickInterval: nil
        )

        await orchestrator.recoverAndReconcile()
        #expect(await planningProvider.callCount == 0)
        _ = await orchestrator.shutdown()
        try await db.pool.write {
            try $0.execute(sql: "DROP TRIGGER fail_r11_shutdown_first_phase")
        }
        do {
            try await orchestrator.resume()
            Issue.record("shutdown must invalidate first-phase retry")
        } catch is KernelHaltedError {
        } catch {
            Issue.record("unexpected post-shutdown retry error: \(error)")
        }
        await orchestrator.recoverAndReconcile()
        #expect(await planningProvider.callCount == 0)
    }

    do {
        let db = try haltTempDB()
        let companion = try haltCompanion(db)
        let card = try db.createSingleCardMission(
            campName: "emergency-clears-card-token",
            squadName: "emergency-clears-card-token",
            goal: "emergency wins Card retry",
            cardTitle: "orphan",
            cardDescription: "orphan",
            expectedOutput: "recovered",
            assigneeId: companion.id,
            maxTurns: 5,
            workspacePath: nil
        )
        try db.startRun(
            cardId: card.cardId,
            runId: "emergency-clears-card-token-run"
        )
        try installStartupCardAdoptionFailure(
            db: db,
            triggerName: "fail_r11_emergency_card_phase",
            cardId: card.cardId
        )
        let planningProvider = HaltHangingProvider()
        let planning = try enqueueStartupPlanningProbe(
            db: db,
            companion: companion,
            command: "emergency-clears-card-token",
            provider: planningProvider
        )
        let orchestrator = Orchestrator(
            db: db,
            planningProviderResolver: planning.resolver,
            makeProvider: { _, _ in nil },
            artifactStoreRoot: try haltArtifactRoot(),
            tickInterval: nil
        )

        await orchestrator.recoverAndReconcile()
        #expect(await planningProvider.callCount == 0)
        do {
            try await orchestrator.emergencyStop()
            Issue.record(
                "emergency control must not mutate an unrecovered supervisor"
            )
        } catch is SupervisorRecoveryRequiredError {
            // Engine-first recovery reaches legacy Card adoption before the
            // planning supervisor leaves initialized. A failure at that gate
            // must remain a first-phase recovery failure; emergency control
            // cannot manufacture a running supervisor or a durable halt.
        } catch {
            Issue.record("unexpected pre-recovery stop error: \(error)")
        }
        #expect(try db.dispatchMode() == .running)
        #expect(
            try DurableWorkStore(database: db)
                .work(id: planning.workId)?.state == .queued
        )
        try await db.pool.write {
            try $0.execute(sql: "DROP TRIGGER fail_r11_emergency_card_phase")
        }
        #expect(await planningProvider.callCount == 0)
        _ = await orchestrator.shutdown()
    }
}

@Test func haltedStartupWithWorklessLegacyMissionLeavesNoActivePlanning()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let missionId = try db.createMissionShell(
        goal: "halted workless legacy planning",
        companionIds: [companion.id],
        workspacePath: nil,
        campId: companion.campId
    )
    try db.transitionDispatchMode(from: .running, to: .halted)
    let provider = HaltHangingProvider()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: .milliseconds(1)
    )

    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    let works = try haltPlanningWorks(db, missionId: missionId)
    let work = try #require(works.first)
    let attemptCount = try await db.pool.read { database in
        try DurableWorkAttemptRecord
            .filter(Column("workId") == work.id)
            .fetchCount(database)
    }
    let events = try db.events(missionId: missionId)
    #expect(await orchestrator.isHalted)
    #expect(await provider.callCount == 0)
    #expect(try db.mission(id: missionId)?.status == .failed)
    #expect(works.count == 1)
    #expect(work.state == .canceled)
    #expect(work.errorCode == "work_canceled")
    #expect(
        work.errorMessage
            == "emergency_halt_during_planning"
    )
    #expect(attemptCount == 0)
    #expect(
        events.filter { $0.kind == EventKind.missionFailed }.count == 1
    )
    #expect(
        !events.contains { $0.kind == EventKind.planningTokens }
    )
    _ = await orchestrator.shutdown()
}

@Test func oldBootRuntimeAuthorityRetryAndDriftBehaviorIsFailClosed() throws {
    try haltR9DAssertRetryAndDriftBehavior()
}

@Test func haltedStartupCleanupFailureRetriesRecoveryBeforeDurableRunning()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = HaltHangingProvider()
    let planning = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halted-startup-cleanup-retry",
        provider: provider
    )
    try db.transitionDispatchMode(from: .running, to: .halted)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_r11_halted_startup_cleanup
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mission_failed'
            BEGIN
              SELECT RAISE(ABORT, 'injected halted startup cleanup failure');
            END
            """)
    }
    let supervisor = DurableWorkSupervisor(
        database: db,
        planningProviderResolver: planning.resolver,
        workerId: "halted-startup-cleanup-retry-worker",
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )

    do {
        try await supervisor.recoverOnStartup(
            profileModels: [
                planning.identity.runtimeProfileId:
                    planning.identity.plannerModel
            ]
        )
        Issue.record("halted startup cleanup failure must remain visible")
    } catch is DatabaseError {
    } catch {
        Issue.record("unexpected halted startup cleanup error: \(error)")
    }

    #expect(try db.dispatchMode() == .halted)
    #expect(
        try DurableWorkStore(database: db)
            .work(id: planning.workId)?.state == .queued
    )
    #expect(try db.mission(id: planning.missionId)?.status == .planning)
    #expect(await provider.callCount == 0)
    do {
        try await supervisor.startIfNeeded()
        Issue.record("failed halted cleanup must keep dispatch suppressed")
    } catch is SupervisorRecoveryRequiredError {
    } catch {
        Issue.record("unexpected failed-cleanup gate error: \(error)")
    }

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_r11_halted_startup_cleanup")
    }
    try await supervisor.recoverOnStartup(
        profileModels: [
            planning.identity.runtimeProfileId:
                planning.identity.plannerModel
        ]
    )

    let recoveredWork = try #require(
        try DurableWorkStore(database: db).work(id: planning.workId)
    )
    #expect(recoveredWork.state == .canceled)
    #expect(
        recoveredWork.errorMessage
            == "emergency_halt_during_planning"
    )
    #expect(try db.mission(id: planning.missionId)?.status == .failed)
    #expect(
        try db.events(missionId: planning.missionId)
            .filter { $0.kind == EventKind.missionFailed }
            .count == 1
    )
    #expect(await provider.callCount == 0)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(10))
}

@Test func haltRacingSameKeyReplayOrAbsentPreflightWritesNothing()
    throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let identity = try testPlanningCommandIdentity(
        db: db,
        command: "halt-race-replay",
        model: "m"
    )
    let provider = MockProvider(script: planningScript())
    let resolutions = LockedCounter()
    let resolver = TestPlanningProviderResolver { _, _ in
        resolutions.increment()
        return provider
    }
    let input = try PlanningWorkInput(
        plannerModel: identity.plannerModel,
        runtimeProfileId: identity.runtimeProfileId
    )
    _ = try db.enqueueMissionPlanning(
        goal: "same-key halt race",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: KernelDefaults.missionBudget,
        campId: companion.campId,
        autonomy: .standard,
        planningInput: input,
        idempotencyKey: identity.idempotencyKey,
        traceId: identity.traceId,
        planningProviderResolver: resolver
    )
    #expect(resolutions.count == 1)
    try db.transitionDispatchMode(from: .running, to: .halted)
    let haltedSnapshot = try haltPlanningSnapshot(db)

    do {
        _ = try db.enqueueMissionPlanning(
            goal: "same-key halt race",
            companionIds: [companion.id],
            workspacePath: nil,
            budgetTokens: KernelDefaults.missionBudget,
            campId: companion.campId,
            autonomy: .standard,
            planningInput: input,
            idempotencyKey: identity.idempotencyKey,
            traceId: "ignored-halted-replay-trace",
            planningProviderResolver: resolver
        )
        Issue.record("halt must beat same-key replay")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted replay error: \(error)")
    }
    #expect(resolutions.count == 1)
    #expect(try haltPlanningSnapshot(db) == haltedSnapshot)

    do {
        _ = try db.enqueueMissionPlanning(
            goal: "absent-key halt race",
            companionIds: [companion.id],
            workspacePath: nil,
            budgetTokens: KernelDefaults.missionBudget,
            campId: companion.campId,
            autonomy: .standard,
            planningInput: input,
            idempotencyKey: "mission-start:halted-absent:v1",
            traceId: "halted-absent-trace",
            planningProviderResolver: resolver
        )
        Issue.record("halt must beat absent-key preflight")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted absent-key error: \(error)")
    }
    #expect(resolutions.count == 1)
    #expect(try haltPlanningSnapshot(db) == haltedSnapshot)
}

@Test func haltRacingEnqueueClaimOrRenewHasControlWinnerOnly()
    throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: planningScript())
    let first = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halt-race-renew",
        provider: provider
    )
    let second = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halt-race-claim",
        provider: provider
    )
    let claim = try #require(try db.claimNextPlanning(
        workerId: "halt-race-owned-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    #expect(claim.workId == first.workId || claim.workId == second.workId)
    try db.transitionDispatchMode(from: .running, to: .halted)
    let haltedSnapshot = try haltPlanningSnapshot(db)

    do {
        _ = try db.claimNextPlanning(
            workerId: "halt-race-losing-claim",
            now: Date(timeIntervalSinceReferenceDate: 1_001),
            leaseDuration: 60
        )
        Issue.record("claim must not cross the durable halt fence")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted claim error: \(error)")
    }
    do {
        _ = try db.renewPlanningLease(
            claim: claim,
            now: Date(timeIntervalSinceReferenceDate: 1_001),
            leaseDuration: 60
        )
        Issue.record("renew must not cross the durable halt fence")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted renew error: \(error)")
    }

    #expect(try haltPlanningSnapshot(db) == haltedSnapshot)
    #expect(
        try DurableWorkStore(database: db)
            .work(id: claim.workId)?.version == claim.version
    )
}

@Test func haltRacingFailureOrOverflowTerminalHasSingleOwner()
    throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: planningScript())
    let first = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halt-terminal-failure",
        provider: provider
    )
    let second = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halt-terminal-overflow",
        provider: provider
    )
    let firstClaim = try #require(try db.claimNextPlanning(
        workerId: "halt-terminal-first-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let secondClaim = try #require(try db.claimNextPlanning(
        workerId: "halt-terminal-second-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    try db.transitionDispatchMode(from: .running, to: .halted)
    let canceledMissionIds =
        try db.cancelAllPlanningForEmergencyHalt(
            reason: "emergency_halt_during_planning",
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    let haltOwnedSnapshot = try haltPlanningSnapshot(db)

    let failure = try PlanningAttemptFailure(
        code: "planning_provider_failed",
        safeMessage: "must lose to halt",
        disposition: .deterministic,
        usage: Usage(
            inputTokens: 7,
            outputTokens: 11,
            cacheReadTokens: 13
        )
    )
    do {
        _ = try db.recordPlanningAttemptFailure(
            claim: firstClaim,
            failure: failure,
            now: Date(timeIntervalSinceReferenceDate: 1_002)
        )
        Issue.record("provider failure must lose to halt cleanup")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted failure error: \(error)")
    }

    let overflow = PlanningUsageOverflowEvidenceV1.turnAggregate(
        priorAccumulatedUsage: try PlanningUsageCountersV1(
            cacheReadTokens: 1,
            inputTokens: 2,
            outputTokens: 3
        ),
        incomingUsage: try PlanningUsageCountersV1(
            cacheReadTokens: 4,
            inputTokens: 5,
            outputTokens: 6
        ),
        overflowFields: [.outputTokens]
    )
    do {
        _ = try db.recordPlanningUsageOverflow(
            claim: secondClaim,
            evidence: overflow,
            now: Date(timeIntervalSinceReferenceDate: 1_002)
        )
        Issue.record("usage overflow must lose to halt cleanup")
    } catch is PlanningDurableDispatchNotRunningError {
    } catch {
        Issue.record("unexpected halted overflow error: \(error)")
    }

    #expect(Set(canceledMissionIds) == Set([first.missionId, second.missionId]))
    #expect(try haltPlanningSnapshot(db) == haltOwnedSnapshot)
    for planning in [first, second] {
        let work = try #require(
            try DurableWorkStore(database: db).work(id: planning.workId)
        )
        let events = try db.events(missionId: planning.missionId)
        #expect(work.state == .canceled)
        #expect(
            work.errorMessage
                == "emergency_halt_during_planning"
        )
        #expect(
            events.filter { $0.kind == EventKind.missionFailed }.count
                == 1
        )
        #expect(
            events.allSatisfy {
                $0.kind != EventKind.planningTokens
                    && $0.kind != EventKind.planningUsageOverflow
            }
        )
        #expect(try db.cards(missionId: planning.missionId).isEmpty)
    }
}

@Test func resumeOpensSupervisorOnlyAfterDurableRunningAndKicksOnce()
    async throws
{
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: planningScript())
    let initial = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "resume-supervisor-initial",
        provider: provider
    )
    let supervisor = DurableWorkSupervisor(
        database: db,
        planningProviderResolver: initial.resolver,
        workerId: "resume-supervisor-worker",
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )
    try await supervisor.recoverOnStartup(
        profileModels: [
            initial.identity.runtimeProfileId:
                initial.identity.plannerModel
        ]
    )
    try await supervisor.suppressForEmergencyStop()
    try db.transitionDispatchMode(from: .running, to: .halted)
    let canceledMissionIds =
        try db.cancelAllPlanningForEmergencyHalt(
            reason: "emergency_halt_during_planning",
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    try await supervisor.didCommitEmergencyPlanningCleanup(
        missionIds: canceledMissionIds
    )

    do {
        try await supervisor.resumeAfterDurableRunning()
        Issue.record("supervisor must not open before durable running")
    } catch is SupervisorDispatchSuppressedError {
    } catch {
        Issue.record("unexpected pre-running resume error: \(error)")
    }
    #expect(await provider.callCount == 0)

    try db.transitionDispatchMode(from: .halted, to: .running)
    let resumed = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "resume-supervisor-dispatch",
        provider: provider
    )
    do {
        try await supervisor.startIfNeeded()
        Issue.record("suppressed supervisor must not dispatch before resume")
    } catch is SupervisorDispatchSuppressedError {
    } catch {
        Issue.record("unexpected suppressed start error: \(error)")
    }
    #expect(await provider.callCount == 0)

    try await supervisor.resumeAfterDurableRunning()
    try await supervisor.waitUntilTerminal(workId: resumed.workId)
    try await supervisor.waitUntilIdle()
    try await supervisor.resumeAfterDurableRunning()
    try await supervisor.waitUntilIdle()

    #expect(await provider.callCount == 1)
    #expect(
        try DurableWorkStore(database: db)
            .work(id: initial.workId)?.state == .canceled
    )
    #expect(
        try DurableWorkStore(database: db)
            .work(id: resumed.workId)?.state == .succeeded
    )
    #expect(try db.cards(missionId: resumed.missionId).count == 1)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(10))
}

@Test func delayedStartupRecoveryCannotClearFailedEmergencyStop() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let initialCardEventIds = try db.events(cardId: ids.cardId)
        .map { $0.id }
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_bootstrap_halt_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_halted'
            BEGIN SELECT RAISE(ABORT, 'injected bootstrap halt failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let recoveryGate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        recoveryPostAdoptionGate: { await recoveryGate.suspend() },
        requiresStartupRecovery: true
    )

    let delayedRecovery = Task {
        await orchestrator.recoverAndReconcile()
    }
    await recoveryGate.waitUntilEntered()
    do {
        try await orchestrator.emergencyStop()
        Issue.record("injected bootstrap halt persistence failure should throw")
    } catch is HaltPersistenceError {
    } catch {
        Issue.record("unexpected bootstrap stop error: \(error)")
    }
    await recoveryGate.open()
    await delayedRecovery.value

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    #expect(
        try db.events(cardId: ids.cardId).map { $0.id }
            == initialCardEventIds
    )

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_bootstrap_halt_event") }
    try await orchestrator.emergencyStop()
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    await orchestrator.shutdown()
}

@Test func delayedStartupRecoveryCannotReviveShutdownKernel() async throws {
    try haltR9DAssertCheckedTeardownBehavior()
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        requiresStartupRecovery: true
    )

    await orchestrator.shutdown()
    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
}

@Test func missingDurableControlRowKeepsStartupFailClosed() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try await db.pool.write { database in
        try database.execute(sql: "DELETE FROM kernel_control WHERE id = 'global'")
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: .milliseconds(1)
    )

    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(await provider.callCount == 0)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    await orchestrator.shutdown()
}

@Test func haltedStartupRepairsAndAdoptsBeforeAtomicCleanupWithoutDispatch() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    let planningProvider = HaltHangingProvider()
    let interruptedPlanning = try enqueueStartupPlanningProbe(
        db: db,
        companion: companion,
        command: "halted-startup-adopts-planning",
        provider: planningProvider
    )
    let planningClaim = try #require(try db.claimNextPlanning(
        workerId: "crashed-halted-startup-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    #expect(planningClaim.workId == interruptedPlanning.workId)
    let worklessMissionId = try db.createMissionShell(
        goal: "halted startup repairs workless planning",
        companionIds: [companion.id],
        workspacePath: nil,
        campId: companion.campId
    )
    try db.transitionDispatchMode(from: .running, to: .halted)
    let cardProvider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: interruptedPlanning.resolver,
        makeProvider: { _, _ in cardProvider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()
    let interruptedAttempt = try await db.pool.read { database in
        try DurableWorkAttemptRecord.fetchOne(
            database,
            key: [
                "workId": interruptedPlanning.workId,
                "attempt": planningClaim.attempt,
            ]
        )
    }
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(await planningProvider.callCount == 0)
    #expect(await cardProvider.callCount == 0)
    #expect(interruptedAttempt?.outcome == .interrupted)
    #expect(
        try DurableWorkStore(database: db)
            .work(id: interruptedPlanning.workId)?.state == .canceled
    )
    #expect(
        try haltPlanningWorks(db, missionId: worklessMissionId)
            .map(\.state) == [.canceled]
    )
    #expect(
        try db.mission(id: interruptedPlanning.missionId)?.status
            == .failed
    )
    #expect(try db.mission(id: worklessMissionId)?.status == .failed)

    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await planningProvider.callCount == 0)
    #expect(await cardProvider.callCount == 1)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 2)
    #expect(runs.filter { $0.outcome == nil }.isEmpty)
    await orchestrator.shutdown()
}

@Test func haltDuringReconcileDatabaseWindowDropsStaleCandidate() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: completeScript())
    let gate = HaltGate(passesBeforeSuspend: 1)
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        reconcilePostDatabaseGate: { await gate.suspend() }
    )
    await orchestrator.recoverAndReconcile()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )

    let staleReconcile = Task { await orchestrator.reconcile() }
    await gate.waitUntilEntered()
    try await orchestrator.emergencyStop()
    await gate.open()
    await staleReconcile.value

    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func haltedPendingReconcileDoesNotRunAnotherDatabasePass() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: completeScript())
    let gate = HaltGate(passesBeforeSuspend: 1)
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        reconcilePostDatabaseGate: { await gate.suspend() }
    )
    await orchestrator.recoverAndReconcile()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )

    let firstReconcile = Task { await orchestrator.reconcile() }
    await gate.waitUntilEntered()
    try await db.pool.write { database in
        try database.execute(
            sql: "UPDATE card SET status = ? WHERE id = ?",
            arguments: [CardStatus.todo.rawValue, ids.cardId]
        )
    }
    let pendingReconcile = Task { await orchestrator.reconcile() }
    await pendingReconcile.value

    try await orchestrator.emergencyStop()
    await gate.open()
    await firstReconcile.value

    #expect(try db.card(id: ids.cardId)?.status == .todo)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func haltDuringRunningCardLeavesReadyCardAndNoOpenRun() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let provider = HaltHangingProvider()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()
    await provider.waitUntilStarted()
    try await orchestrator.emergencyStop()
    await orchestrator.reconcile()

    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func haltAfterProviderResponseCannotWriteTokensOrCards() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: planningScript())
    let gate = HaltGate()
    let gatedPlanner = HaltGatedPlanningProvider(base: provider, gate: gate)
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "halt-after-planner-response",
        model: "m"
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: gatedPlanner
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    let missionId = try await orchestrator.startMission(
        goal: "g",
        companionIds: [companion.id],
        workspacePath: nil,
        plannerModel: planningIdentity.plannerModel,
        runtimeProfileId: planningIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: nil,
        autonomy: .standard,
        idempotencyKey: planningIdentity.idempotencyKey,
        traceId: planningIdentity.traceId
    )
    await gate.waitUntilEntered()

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    await gate.open()
    try await stopping.value

    #expect(try db.mission(id: missionId)?.status == .failed)
    #expect(try db.cards(missionId: missionId).isEmpty)
    #expect(try db.events(missionId: missionId).contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    #expect(!((try db.events(missionId: missionId)).contains { $0.kind == EventKind.planningTokens }))
    await orchestrator.shutdown()
}

@Test func emergencyStopCancelsRunningBeforeWaitingForPlanner() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let runningIds = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "running",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: runningIds.missionId,
        companionId: companion.id
    )
    let planner = MockProvider(script: planningScript())
    let runner = HaltHangingProvider()
    let gate = HaltGate()
    let gatedPlanner = HaltGatedPlanningProvider(base: planner, gate: gate)
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "halt-cancels-running-before-planner",
        model: "planner"
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: gatedPlanner
        ),
        makeProvider: { model, _ in
            if model == "planner" { return planner }
            return runner
        },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()
    await runner.waitUntilStarted()
    let planningMissionId = try await orchestrator.startMission(
        goal: "planning", companionIds: [companion.id],
        workspacePath: nil,
        plannerModel: planningIdentity.plannerModel,
        runtimeProfileId: planningIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: nil,
        autonomy: .standard,
        idempotencyKey: planningIdentity.idempotencyKey,
        traceId: planningIdentity.traceId
    )
    await gate.waitUntilEntered()

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    let runningWasCanceledBeforePlannerReleased = await runner.waitUntilCanceled()
    #expect(runningWasCanceledBeforePlannerReleased)

    await gate.open()
    try await stopping.value

    #expect(try db.card(id: runningIds.cardId)?.status == .ready)
    #expect(try db.runs(cardId: runningIds.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    #expect(try db.events(cardId: runningIds.cardId).contains {
        $0.kind == EventKind.cardReady
    })
    await orchestrator.shutdown()
}

@Test func haltCleanupFailureKeepsSupervisorSuppressedAndBlocksResume() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let planner = MockProvider(script: planningScript())
    let runner = MockProvider(script: completeScript())
    let gate = HaltGate()
    let gatedPlanner = HaltGatedPlanningProvider(base: planner, gate: gate)
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "halt-planning-cleanup-failure",
        model: "planner"
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: gatedPlanner
        ),
        makeProvider: { model, _ in
            if model == "planner" { return planner }
            return runner
        },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    let readyIds = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "ready",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: readyIds.missionId,
        companionId: companion.id
    )
    let planningMissionId = try await orchestrator.startMission(
        goal: "planning", companionIds: [companion.id],
        workspacePath: nil,
        plannerModel: planningIdentity.plannerModel,
        runtimeProfileId: planningIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: nil,
        autonomy: .standard,
        idempotencyKey: planningIdentity.idempotencyKey,
        traceId: planningIdentity.traceId
    )
    await gate.waitUntilEntered()
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_interrupted_planning_event
            BEFORE INSERT ON event WHEN NEW.kind = 'mission_failed'
            BEGIN SELECT RAISE(ABORT, 'injected planning cleanup failure'); END
            """)
    }

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    await gate.open()
    do {
        try await stopping.value
        Issue.record("planning cleanup failure should make stop throw")
    } catch is PlanningHaltCleanupError {
    } catch {
        Issue.record("unexpected stop error: \(error)")
    }

    #expect(try db.dispatchMode() == .halted)
    #expect(try db.mission(id: planningMissionId)?.status == .planning)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    let rolledBackPlanningEvents = try db.events(missionId: planningMissionId)
    #expect(!rolledBackPlanningEvents.contains { $0.kind == EventKind.missionFailed })
    #expect(!rolledBackPlanningEvents.contains {
        $0.kind == EventKind.missionStatusChanged
            && $0.payloadJson.contains("\"to\":\"failed\"")
    })
    #expect(await runner.callCount == 0)
    #expect(try db.card(id: readyIds.cardId)?.status == .ready)
    #expect(try db.runs(cardId: readyIds.cardId).isEmpty)

    do {
        try await orchestrator.resume()
        Issue.record("resume must remain fail-closed while planning cleanup fails")
    } catch is PlanningHaltCleanupError {
    } catch {
        Issue.record("unexpected resume error: \(error)")
    }
    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await runner.callCount == 0)

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_interrupted_planning_event")
    }
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()

    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    let committedPlanningEvents =
        try db.events(missionId: planningMissionId)
    #expect(committedPlanningEvents.contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    #expect(committedPlanningEvents.filter {
        $0.kind == EventKind.missionFailed
    }.count == 1)
    let committedPlanningWork = try await db.pool.read {
        database in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateId") == planningMissionId
            )
            .fetchAll(database)
    }
    #expect(committedPlanningWork.count == 1)
    #expect(committedPlanningWork.first?.state == .canceled)
    #expect(
        committedPlanningWork.first?.errorMessage
            == "emergency_halt_during_planning"
    )
    #expect(try db.card(id: readyIds.cardId)?.status == .done)
    #expect(await runner.callCount == 1)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 1)
    await orchestrator.shutdown()
}

@Test func haltPersistenceFailureKeepsSupervisorSuppressed() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_halt_orchestrator_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_halted'
            BEGIN SELECT RAISE(ABORT, 'injected halt failure'); END
            """)
    }
    let provider = HaltHangingProvider()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    await provider.waitUntilStarted()

    do {
        try await orchestrator.emergencyStop()
        Issue.record("halt persistence failure should throw")
    } catch {}

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
    await orchestrator.reconcile()
    #expect(await provider.callCount == 1)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_halt_orchestrator_event") }
    try await orchestrator.emergencyStop()
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    await orchestrator.shutdown()
}

@Test func resumePersistenceFailureStaysHaltedAndDispatchesNothing() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try db.transitionDispatchMode(from: .running, to: .halted)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_resume_orchestrator_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_resumed'
            BEGIN SELECT RAISE(ABORT, 'injected resume failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()

    do {
        try await orchestrator.resume()
        Issue.record("resume persistence failure should throw")
    } catch {}
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    await orchestrator.shutdown()
}

@Test func orphanRecoveryFailureKeepsResumeClosedUntilRetried() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try db.transitionDispatchMode(from: .running, to: .halted)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_orphan_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected orphan adoption failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let resumeGate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        resumePreAdoptionGate: { await resumeGate.suspend() }
    )
    await orchestrator.recoverAndReconcile()

    let firstResume = Task { try await orchestrator.resume() }
    await resumeGate.waitUntilEntered()
    do {
        try await orchestrator.resume()
        Issue.record("a concurrent resume must not report success while recovery is pending")
    } catch is KernelTransitionInProgressError {
    } catch {
        Issue.record("unexpected concurrent resume error: \(error)")
    }
    await resumeGate.open()
    do {
        try await firstResume.value
        Issue.record("resume must not open dispatch when orphan adoption fails")
    } catch is HaltRecoveryError {
    } catch {
        Issue.record("unexpected recovery error: \(error)")
    }

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_orphan_adoption") }
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()

    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(await provider.callCount == 1)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 1)
    await orchestrator.shutdown()
}

@Test func startupOrphanRecoveryFailureFailsClosedUntilExplicitRetry() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_startup_orphan_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected startup orphan adoption failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).count == 1)
    #expect(try db.runs(cardId: ids.cardId).first?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_startup_orphan_adoption")
    }
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()

    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(try db.runs(cardId: ids.cardId).count == 2)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func staleStartupRecoveryCannotStealNewResumePhase() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    let recoveryGate = HaltGate()
    let resumeGate = HaltGate()
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        recoveryPostAdoptionGate: { await recoveryGate.suspend() },
        resumePreAdoptionGate: { await resumeGate.suspend() }
    )

    let staleRecovery = Task { await orchestrator.recoverAndReconcile() }
    await recoveryGate.waitUntilEntered()
    try await orchestrator.emergencyStop()

    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_aba_resume_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected ABA adoption failure'); END
            """)
    }

    let resuming = Task { try await orchestrator.resume() }
    await resumeGate.waitUntilEntered()
    await recoveryGate.open()
    await staleRecovery.value
    await resumeGate.open()
    do {
        try await resuming.value
        Issue.record("the owning resume should surface its adoption failure")
    } catch is HaltRecoveryError {
    } catch {
        Issue.record("unexpected resume error: \(error)")
    }

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_aba_resume_adoption") }
    try await orchestrator.resume()
    try await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@MainActor
@Test func directMissionAndProposalStartsAreRejectedWhileHalted() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let campId = try #require(companion.campId)
    let thread = try db.findOrCreateGuideThread(campId: campId)
    let block = SquadProposalBlock(
        proposalId: "halted-proposal", name: "队", memberIds: [companion.id],
        goal: "g", budget: nil, status: .pending)
    let messageId = try db.appendChatMessage(
        threadId: thread.id, role: "guide", contentJson: try block.encodedString())
    try db.transitionDispatchMode(from: .running, to: .halted)
    let provider = MockProvider(script: planningScript())
    let planningIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "halted-direct-start",
        model: "m"
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: planningIdentity.runtimeProfileId,
            model: planningIdentity.plannerModel,
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil
    )
    let beforeCount = try await db.pool.read { try MissionRecord.fetchCount($0) }

    do {
        _ = try await orchestrator.startMission(
            goal: "g",
            companionIds: [companion.id],
            workspacePath: nil,
            plannerModel: planningIdentity.plannerModel,
            runtimeProfileId: planningIdentity.runtimeProfileId,
            budgetTokens: KernelDefaults.missionBudget,
            campId: nil,
            autonomy: .standard,
            idempotencyKey: planningIdentity.idempotencyKey,
            traceId: planningIdentity.traceId
        )
        Issue.record("direct start should be rejected while halted")
    } catch let error as UserVisibleOperationError {
        #expect(error.failure.traceId == planningIdentity.traceId)
        #expect(error.failure.operation == .missionStart)
        #expect(error.failure.scope.type == .mission)
        #expect(error.failure.scope.id == "mission_index")
    } catch {
        Issue.record("unexpected direct-start error: \(error)")
    }
    let coordinator = PlanningEntryCoordinator(
        db: db,
        orchestrator: orchestrator,
        makeUUIDString: { "halted-proposal-trace" }
    )
    let captured = try coordinator.captureConfirmedProposal(
        messageId: messageId,
        runtime: PlanningEntryRuntimeSelection(
            runtimeProfileId: planningIdentity.runtimeProfileId,
            plannerModel: planningIdentity.plannerModel
        ),
        fallbackBudget: KernelDefaults.missionBudget,
        autonomy: .standard
    )
    do {
        _ = try await coordinator.startConfirmedProposal(captured)
        Issue.record("proposal confirmation should be rejected while halted")
    } catch is KernelHaltedError {
    } catch {
        Issue.record("unexpected proposal error: \(error)")
    }

    let afterCount = try await db.pool.read { try MissionRecord.fetchCount($0) }
    #expect(afterCount == beforeCount)
    let stored = try db.messages(threadId: thread.id).first { $0.id == messageId }?.proposal
    #expect(stored?.status == .pending)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func rateLimitTriggersGlobalCooldownThenRecovers() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let first = try db.createSingleCardMission(
        campName: "c", squadName: "s1", goal: "g",
        cardTitle: "t1", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: first.missionId,
        companionId: companion.id
    )
    // 首个 provider 抛 429，之后的派发换成正常 Mock（按调用次数切换）
    let counter = CallCounter()
    let rateLimitClock = ManualRateLimitClock()
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: RateLimitedProvider()
        ),
        makeProvider: { _, _ in
            if counter.next() == 0 {
                return RateLimitedProvider()
            }
            return MockProvider(script: completeScript())
        },
        artifactStoreRoot: try haltArtifactRoot(),
        tickInterval: nil,
        rateLimitCooldown: .milliseconds(400),
        mcpManager: nil,
        externalOperationWorkflow: nil,
        rateLimitNow: { rateLimitClock.now() }
    )

    await orchestrator.recoverAndReconcile()
    // 429 → 卡片按错误路径 blocked + 冷却事件
    let blocked = try await waitForCard(db, first.cardId, status: .blocked)
    #expect(blocked)
    // CardRunner 先持久化 blocked，Orchestrator 随后写 cooldown 事件并移除 running。
    // 等完整错误处理周期结束，避免用 card 状态替代 cooldown 事件的同步点。
    try await orchestrator.waitUntilIdle()
    #expect(try globalEvents(db, kind: "rate_limit_cooldown") == 1)

    // 冷却期内：第二个行动不派发
    let second = try db.createSingleCardMission(
        campName: "c", squadName: "s2", goal: "g",
        cardTitle: "t2", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: second.missionId,
        companionId: companion.id
    )
    await orchestrator.reconcile()
    #expect(try db.runs(cardId: second.cardId).isEmpty)

    // 冷却过点：恢复派发
    rateLimitClock.advance(by: .milliseconds(400))
    await orchestrator.reconcile()
    let done = try await waitForCard(db, second.cardId, status: .done)
    #expect(done)
}

private final class ManualRateLimitClock: @unchecked Sendable {
    private let lock = NSLock()
    private var instant = ContinuousClock.now

    func now() -> ContinuousClock.Instant {
        lock.withLock { instant }
    }

    func advance(by duration: Duration) {
        lock.withLock {
            instant = instant + duration
        }
    }
}

/// 线程安全的调用计数器（makeProvider 是 @Sendable 闭包）
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = count
        count += 1
        return current
    }
}
