import Darwin
import Foundation
import Testing
@testable import AgentLoopCore

private let blockingProgressEvidenceKey =
    "AGENTLOOP_BLOCKING_PROGRESS_EVIDENCE"
private let blockingProgressLabel = "blocking-process-progress-child"
private let helpProbeProgressEvidenceKey =
    "AGENTLOOP_HELP_PROBE_PROGRESS_EVIDENCE"
private let helpProbeProgressLabel = "help-probe-progress-child"
private let cliResumeSignalProgressEvidenceKey =
    "AGENTLOOP_CLI_RESUME_SIGNAL_PROGRESS_EVIDENCE"
private let cliResumeSignalProgressLabel = "cli-resume-signal-progress-child"

private enum BlockingProgressTestError: Error, CustomStringConvertible {
    case invalidChildEnvironment
    case invalidEvidencePath
    case setup([String])

    var description: String {
        switch self {
        case .invalidChildEnvironment:
            return "invalid blocking-progress child environment"
        case .invalidEvidencePath:
            return "invalid blocking-progress evidence path"
        case .setup(let failures):
            return "blocking-progress setup failed: \(failures.joined(separator: "; "))"
        }
    }
}

private enum HelpProbeProgressSentinel: Error, Equatable {
    case blockedVersionRun
}

private enum CliResumeSignalProgressSentinel: Error, Equatable {
    case blockedResume
}

private final class HelpProbeProgressObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var invocationCountStorage = 0
    private var authorityStorage: CliExecutableAuthorityV1?
    private var argumentsStorage: [String]?

    func record(
        authority: CliExecutableAuthorityV1,
        arguments: [String]
    ) {
        lock.withLock {
            invocationCountStorage += 1
            authorityStorage = authority
            argumentsStorage = arguments
        }
    }

    var snapshot: (
        invocationCount: Int,
        authority: CliExecutableAuthorityV1?,
        arguments: [String]?
    ) {
        lock.withLock {
            (invocationCountStorage, authorityStorage, argumentsStorage)
        }
    }
}

private final class HelpProbeProgressOwnedDescriptor: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32

    init(_ descriptor: Int32) {
        self.descriptor = descriptor
    }

    func take() -> Int32? {
        lock.withLock {
            guard descriptor >= 0 else { return nil }
            let owned = descriptor
            descriptor = -1
            return owned
        }
    }

    func closeIfOwned() -> Int32? {
        guard let owned = take() else { return nil }
        return Darwin.close(owned) == 0 ? nil : errno
    }
}

private struct HelpProbeProgressUnusedInspector:
    EngineRuntimeProcessInspectingV1
{
    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        throw BlockingProgressTestError.invalidChildEnvironment
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        throw BlockingProgressTestError.invalidChildEnvironment
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        throw BlockingProgressTestError.invalidChildEnvironment
    }
}

private final class CliResumeSignalProgressInspector:
    EngineRuntimeProcessInspectingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private let state: BlockingProgressState
    private let readerOwner: HelpProbeProgressOwnedDescriptor
    private var invocationCount = 0
    private var observedSignal: Int32?
    private var observedProcessGroupId: Int32?

    init(
        state: BlockingProgressState,
        readerOwner: HelpProbeProgressOwnedDescriptor
    ) {
        self.state = state
        self.readerOwner = readerOwner
    }

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        throw BlockingProgressTestError.invalidChildEnvironment
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        throw BlockingProgressTestError.invalidChildEnvironment
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        lock.withLock {
            invocationCount += 1
            observedSignal = signal
            observedProcessGroupId = processGroupId
        }
        guard let ownedReader = readerOwner.take() else {
            throw BlockingProgressTestError.setup([
                "resume signal reader ownership lost",
            ])
        }
        var byte: UInt8 = 0
        state.markReadEntered()
        var count: Int
        repeat {
            count = Darwin.read(ownedReader, &byte, 1)
        } while count < 0 && errno == EINTR
        let readError = count < 0 ? errno : nil
        let closeResult = Darwin.close(ownedReader)
        let closeError = closeResult == 0 ? nil : errno
        state.recordRead(
            count: count,
            byte: byte,
            errorNumber: readError,
            closeError: closeError
        )
        throw CliResumeSignalProgressSentinel.blockedResume
    }

    var invocation: (count: Int, signal: Int32?, processGroupId: Int32?) {
        lock.withLock {
            (invocationCount, observedSignal, observedProcessGroupId)
        }
    }
}

private struct BlockingProgressSnapshot: Sendable {
    let readEntered: Bool
    let siblingProgressed: Bool
    let rescueUsed: Bool
    let entryTimedOut: Bool
    let readCount: Int?
    let readByte: UInt8?
    let readError: Int32?
    let readerCloseError: Int32?
    let writeCount: Int?
    let writeError: Int32?
    let writerCloseError: Int32?
    let controllerCompleted: Bool
}

private final class BlockingProgressState: @unchecked Sendable {
    private let lock = NSLock()
    private var readEntered = false
    private var siblingProgressed = false
    private var rescueUsed = false
    private var entryTimedOut = false
    private var readCount: Int?
    private var readByte: UInt8?
    private var readError: Int32?
    private var readerCloseError: Int32?
    private var writeCount: Int?
    private var writeError: Int32?
    private var writerCloseError: Int32?
    private var siblingTask: Task<Void, Never>?
    private var controllerCompleted = false
    private var controllerWaiter: CheckedContinuation<Void, Never>?

    func markReadEntered() {
        lock.withLock { readEntered = true }
    }

    func hasReadEntered() -> Bool {
        lock.withLock { readEntered }
    }

    func markSiblingProgressed() {
        lock.withLock { siblingProgressed = true }
    }

    func hasSiblingProgressed() -> Bool {
        lock.withLock { siblingProgressed }
    }

    func markRescueUsed() {
        lock.withLock { rescueUsed = true }
    }

    func markEntryTimedOut() {
        lock.withLock { entryTimedOut = true }
    }

    func recordRead(
        count: Int,
        byte: UInt8,
        errorNumber: Int32?,
        closeError: Int32?
    ) {
        lock.withLock {
            readCount = count
            readByte = byte
            readError = errorNumber
            readerCloseError = closeError
        }
    }

    func recordWrite(
        count: Int?,
        errorNumber: Int32?,
        closeError: Int32?
    ) {
        lock.withLock {
            writeCount = count
            writeError = errorNumber
            writerCloseError = closeError
        }
    }

    func retainSiblingTask(_ task: Task<Void, Never>) {
        lock.withLock {
            precondition(siblingTask == nil)
            siblingTask = task
        }
    }

    func retainedSiblingTask() -> Task<Void, Never>? {
        lock.withLock { siblingTask }
    }

    func completeController() {
        let waiter: CheckedContinuation<Void, Never>? = lock.withLock {
            precondition(!controllerCompleted)
            controllerCompleted = true
            let waiter = controllerWaiter
            controllerWaiter = nil
            return waiter
        }
        waiter?.resume()
    }

    func waitForControllerCompletion() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            let completed = lock.withLock {
                if controllerCompleted { return true }
                precondition(controllerWaiter == nil)
                controllerWaiter = continuation
                return false
            }
            if completed { continuation.resume() }
        }
    }

    func snapshot() -> BlockingProgressSnapshot {
        lock.withLock {
            BlockingProgressSnapshot(
                readEntered: readEntered,
                siblingProgressed: siblingProgressed,
                rescueUsed: rescueUsed,
                entryTimedOut: entryTimedOut,
                readCount: readCount,
                readByte: readByte,
                readError: readError,
                readerCloseError: readerCloseError,
                writeCount: writeCount,
                writeError: writeError,
                writerCloseError: writerCloseError,
                controllerCompleted: controllerCompleted
            )
        }
    }
}

private func blockingProgressEvidenceURL(
    environment: [String: String]
) throws -> URL {
    guard let path = environment[blockingProgressEvidenceKey],
          path.hasPrefix("/"),
          !path.utf8.contains(0)
    else { throw BlockingProgressTestError.invalidEvidencePath }
    let evidence = URL(fileURLWithPath: path)
    let base = evidence.deletingLastPathComponent()
    let prefix = blockingProgressLabel + "-"
    guard evidence.standardizedFileURL.path == path,
          evidence.lastPathComponent == "phases.evidence",
          base.lastPathComponent.hasPrefix(prefix),
          UUID(uuidString: String(
              base.lastPathComponent.dropFirst(prefix.count)
          )) != nil,
          base.deletingLastPathComponent().standardizedFileURL
            == FileManager.default.temporaryDirectory.standardizedFileURL
    else { throw BlockingProgressTestError.invalidEvidencePath }
    return evidence
}

private func helpProbeProgressEvidenceURL(
    environment: [String: String]
) throws -> URL {
    guard let path = environment[helpProbeProgressEvidenceKey],
          path.hasPrefix("/"),
          !path.utf8.contains(0)
    else { throw BlockingProgressTestError.invalidEvidencePath }
    let evidence = URL(fileURLWithPath: path)
    let base = evidence.deletingLastPathComponent()
    let prefix = helpProbeProgressLabel + "-"
    guard evidence.standardizedFileURL.path == path,
          evidence.lastPathComponent == "phases.evidence",
          base.lastPathComponent.hasPrefix(prefix),
          UUID(uuidString: String(
              base.lastPathComponent.dropFirst(prefix.count)
          )) != nil,
          base.deletingLastPathComponent().standardizedFileURL
            == FileManager.default.temporaryDirectory.standardizedFileURL
    else { throw BlockingProgressTestError.invalidEvidencePath }
    return evidence
}

private func cliResumeSignalProgressEvidenceURL(
    environment: [String: String]
) throws -> URL {
    guard let path = environment[cliResumeSignalProgressEvidenceKey],
          path.hasPrefix("/"),
          !path.utf8.contains(0)
    else { throw BlockingProgressTestError.invalidEvidencePath }
    let evidence = URL(fileURLWithPath: path)
    let base = evidence.deletingLastPathComponent()
    let prefix = cliResumeSignalProgressLabel + "-"
    guard evidence.standardizedFileURL.path == path,
          evidence.lastPathComponent == "phases.evidence",
          base.lastPathComponent.hasPrefix(prefix),
          UUID(uuidString: String(
              base.lastPathComponent.dropFirst(prefix.count)
          )) != nil,
          base.deletingLastPathComponent().standardizedFileURL
            == FileManager.default.temporaryDirectory.standardizedFileURL
    else { throw BlockingProgressTestError.invalidEvidencePath }
    return evidence
}

private func helpProbeProgressAuthority(
    base: URL
) throws -> CliExecutableAuthorityV1 {
    let executable = base.appendingPathComponent("validated-not-executed")
    let bytes = Data("help-probe fixture must not execute\n".utf8)
    try bytes.write(to: executable, options: .withoutOverwriting)
    guard Darwin.chmod(executable.path, 0o700) == 0 else {
        throw BlockingProgressTestError.setup([
            "chmod fixture errno=\(errno)",
        ])
    }
    var information = stat()
    guard executable.path.withCString({
        Darwin.lstat($0, &information)
    }) == 0 else {
        throw BlockingProgressTestError.setup([
            "lstat fixture errno=\(errno)",
        ])
    }
    let hash = CanonicalJSONV1.sha256Hex(bytes)
    return try CliExecutableAuthorityV1(
        kind: .cliCodex,
        command: "codex",
        commandSourcePath: executable.path,
        commandSourceHash: hash,
        resolvedExecutablePath: executable.path,
        stagedPath: executable.path,
        executableHash: hash,
        designatedRequirement: "help-probe-progress-fixture",
        teamIdentifier: "2DC432GLL2",
        cdHash: String(repeating: "0", count: 40),
        stagedDevice: UInt64(information.st_dev),
        stagedInode: UInt64(information.st_ino)
    )
}

private func closeBlockingProgressSetupDescriptors(
    readDescriptor: inout Int32,
    writeDescriptor: inout Int32,
    primary: String
) throws -> Never {
    var failures = [primary]
    for (label, descriptor) in [
        ("read", readDescriptor),
        ("write", writeDescriptor),
    ] where descriptor >= 0 {
        if Darwin.close(descriptor) != 0 {
            failures.append("close \(label) errno=\(errno)")
        }
        if label == "read" {
            readDescriptor = -1
        } else {
            writeDescriptor = -1
        }
    }
    throw BlockingProgressTestError.setup(failures)
}

private func startBlockingProgressController(
    state: BlockingProgressState,
    ownedWriter: Int32,
    releaseByte: UInt8,
    name: String
) -> Thread {
    let controller = Thread {
        let entryDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !state.hasReadEntered(), ContinuousClock.now < entryDeadline {
            Thread.sleep(forTimeInterval: 0.001)
        }

        if state.hasReadEntered() {
            let sibling = Task.detached {
                state.markSiblingProgressed()
            }
            state.retainSiblingTask(sibling)
            let progressDeadline = ContinuousClock.now.advanced(
                by: .seconds(1)
            )
            while !state.hasSiblingProgressed(),
                  ContinuousClock.now < progressDeadline
            {
                Thread.sleep(forTimeInterval: 0.001)
            }
            if !state.hasSiblingProgressed() {
                state.markRescueUsed()
            }

            var byte = releaseByte
            var written: Int
            repeat {
                written = Darwin.write(ownedWriter, &byte, 1)
            } while written < 0 && errno == EINTR
            let writeError = written < 0 ? errno : nil
            let closeResult = Darwin.close(ownedWriter)
            let closeError = closeResult == 0 ? nil : errno
            state.recordWrite(
                count: written,
                errorNumber: writeError,
                closeError: closeError
            )
        } else {
            state.markEntryTimedOut()
            let closeResult = Darwin.close(ownedWriter)
            let closeError = closeResult == 0 ? nil : errno
            state.recordWrite(
                count: nil,
                errorNumber: nil,
                closeError: closeError
            )
        }
        state.completeController()
    }
    controller.name = name
    controller.qualityOfService = .utility
    controller.start()
    return controller
}

private func runBlockingProgressChild(evidence: URL) async throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    guard Darwin.pipe(&descriptors) == 0 else {
        throw BlockingProgressTestError.setup(["pipe errno=\(errno)"])
    }
    var readDescriptor = descriptors[0]
    var writeDescriptor = descriptors[1]
    guard Darwin.fcntl(writeDescriptor, F_SETNOSIGPIPE, 1) == 0 else {
        try closeBlockingProgressSetupDescriptors(
            readDescriptor: &readDescriptor,
            writeDescriptor: &writeDescriptor,
            primary: "F_SETNOSIGPIPE errno=\(errno)"
        )
    }

    let state = BlockingProgressState()
    let ownedWriter = writeDescriptor
    writeDescriptor = -1
    let controller = startBlockingProgressController(
        state: state,
        ownedWriter: ownedWriter,
        releaseByte: 0xA5,
        name: "AgentLoop.test.blocking-process-controller"
    )

    let ownedReader = readDescriptor
    readDescriptor = -1
    let operationTask = BlockingProcessOperation.start {
        var byte: UInt8 = 0
        state.markReadEntered()
        var count: Int
        repeat {
            count = Darwin.read(ownedReader, &byte, 1)
        } while count < 0 && errno == EINTR
        let readError = count < 0 ? errno : nil
        let closeResult = Darwin.close(ownedReader)
        let closeError = closeResult == 0 ? nil : errno
        state.recordRead(
            count: count,
            byte: byte,
            errorNumber: readError,
            closeError: closeError
        )
        return count
    }
    operationTask.cancel()
    let cancellationObserved = operationTask.isCancelled
    let operationResult = await operationTask.value
    await state.waitForControllerCompletion()
    withExtendedLifetime(controller) {}
    if let siblingTask = state.retainedSiblingTask() {
        await siblingTask.value
    }
    let snapshot = state.snapshot()
    print(
        "BLOCKING PROGRESS PHASES "
            + "cancelled=\(cancellationObserved) "
            + "operation=\(operationResult) "
            + "entered=\(snapshot.readEntered) "
            + "sibling=\(snapshot.siblingProgressed) "
            + "rescue=\(snapshot.rescueUsed) "
            + "entry-timeout=\(snapshot.entryTimedOut) "
            + "read=\(String(describing: snapshot.readCount)) "
            + "read-byte=\(String(describing: snapshot.readByte)) "
            + "read-errno=\(String(describing: snapshot.readError)) "
            + "read-close-errno=\(String(describing: snapshot.readerCloseError)) "
            + "write=\(String(describing: snapshot.writeCount)) "
            + "write-errno=\(String(describing: snapshot.writeError)) "
            + "write-close-errno=\(String(describing: snapshot.writerCloseError)) "
            + "controller=\(snapshot.controllerCompleted)"
    )

    try #require(cancellationObserved)
    try #require(snapshot.readEntered)
    try #require(!snapshot.entryTimedOut)
    try #require(operationResult == 1)
    try #require(snapshot.readCount == 1)
    try #require(snapshot.readByte == 0xA5)
    try #require(snapshot.readError == nil)
    try #require(snapshot.readerCloseError == nil)
    try #require(snapshot.writeCount == 1)
    try #require(snapshot.writeError == nil)
    try #require(snapshot.writerCloseError == nil)
    try #require(snapshot.siblingProgressed)
    try #require(snapshot.controllerCompleted)
    try #require(!snapshot.rescueUsed)
    try Data("blocking-progress-ok\n".utf8).write(
        to: evidence,
        options: .withoutOverwriting
    )
}

private func runHelpProbeProgressChild(evidence: URL) async throws {
    let authority = try helpProbeProgressAuthority(
        base: evidence.deletingLastPathComponent()
    )
    var descriptors = [Int32](repeating: -1, count: 2)
    guard Darwin.pipe(&descriptors) == 0 else {
        throw BlockingProgressTestError.setup(["pipe errno=\(errno)"])
    }
    var readDescriptor = descriptors[0]
    var writeDescriptor = descriptors[1]
    guard Darwin.fcntl(writeDescriptor, F_SETNOSIGPIPE, 1) == 0 else {
        try closeBlockingProgressSetupDescriptors(
            readDescriptor: &readDescriptor,
            writeDescriptor: &writeDescriptor,
            primary: "F_SETNOSIGPIPE errno=\(errno)"
        )
    }

    let state = BlockingProgressState()
    let observation = HelpProbeProgressObservation()
    let ownedWriter = writeDescriptor
    writeDescriptor = -1
    let controller = startBlockingProgressController(
        state: state,
        ownedWriter: ownedWriter,
        releaseByte: 0xC7,
        name: "AgentLoop.test.help-probe-controller"
    )

    let readerOwner = HelpProbeProgressOwnedDescriptor(readDescriptor)
    readDescriptor = -1
    let probe = CliHelpProbeV1(
        processInspector: HelpProbeProgressUnusedInspector(),
        synchronousRunner: { observedAuthority, arguments in
            observation.record(
                authority: observedAuthority,
                arguments: arguments
            )
            guard let ownedReader = readerOwner.take() else {
                throw BlockingProgressTestError.setup([
                    "help probe reader ownership lost",
                ])
            }
            var byte: UInt8 = 0
            state.markReadEntered()
            var count: Int
            repeat {
                count = Darwin.read(ownedReader, &byte, 1)
            } while count < 0 && errno == EINTR
            let readError = count < 0 ? errno : nil
            let closeResult = Darwin.close(ownedReader)
            let closeError = closeResult == 0 ? nil : errno
            state.recordRead(
                count: count,
                byte: byte,
                errorNumber: readError,
                closeError: closeError
            )
            throw HelpProbeProgressSentinel.blockedVersionRun
        }
    )
    let snapshotTask = Task {
        try await probe.snapshot(for: .cliCodex, authority: authority)
    }
    snapshotTask.cancel()
    let cancellationObserved = snapshotTask.isCancelled
    let result = await snapshotTask.result
    await state.waitForControllerCompletion()
    withExtendedLifetime(controller) {}
    if let siblingTask = state.retainedSiblingTask() {
        await siblingTask.value
    }
    let abandonedReaderCloseError = readerOwner.closeIfOwned()
    let snapshot = state.snapshot()
    let invocation = observation.snapshot
    print(
        "HELP PROBE PROGRESS PHASES "
            + "cancelled=\(cancellationObserved) "
            + "invocations=\(invocation.invocationCount) "
            + "arguments=\(String(describing: invocation.arguments)) "
            + "entered=\(snapshot.readEntered) "
            + "sibling=\(snapshot.siblingProgressed) "
            + "rescue=\(snapshot.rescueUsed) "
            + "entry-timeout=\(snapshot.entryTimedOut) "
            + "read=\(String(describing: snapshot.readCount)) "
            + "read-byte=\(String(describing: snapshot.readByte)) "
            + "read-errno=\(String(describing: snapshot.readError)) "
            + "read-close-errno=\(String(describing: snapshot.readerCloseError)) "
            + "write=\(String(describing: snapshot.writeCount)) "
            + "write-errno=\(String(describing: snapshot.writeError)) "
            + "write-close-errno=\(String(describing: snapshot.writerCloseError)) "
            + "controller=\(snapshot.controllerCompleted)"
    )

    try #require(cancellationObserved)
    try #require(abandonedReaderCloseError == nil)
    try #require(invocation.invocationCount == 1)
    try #require(invocation.authority == authority)
    try #require(invocation.arguments == ["--version"])
    switch result {
    case .success:
        throw BlockingProgressTestError.setup([
            "injected help probe run unexpectedly succeeded",
        ])
    case .failure(let error):
        try #require(
            error as? HelpProbeProgressSentinel == .blockedVersionRun
        )
    }
    try #require(snapshot.readEntered)
    try #require(!snapshot.entryTimedOut)
    try #require(snapshot.readCount == 1)
    try #require(snapshot.readByte == 0xC7)
    try #require(snapshot.readError == nil)
    try #require(snapshot.readerCloseError == nil)
    try #require(snapshot.writeCount == 1)
    try #require(snapshot.writeError == nil)
    try #require(snapshot.writerCloseError == nil)
    try #require(snapshot.siblingProgressed)
    try #require(snapshot.controllerCompleted)
    try #require(!snapshot.rescueUsed)
    try Data("help-probe-progress-ok\n".utf8).write(
        to: evidence,
        options: .withoutOverwriting
    )
}

private func runCliResumeSignalProgressChild(evidence: URL) async throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    guard Darwin.pipe(&descriptors) == 0 else {
        throw BlockingProgressTestError.setup(["pipe errno=\(errno)"])
    }
    var readDescriptor = descriptors[0]
    var writeDescriptor = descriptors[1]
    guard Darwin.fcntl(writeDescriptor, F_SETNOSIGPIPE, 1) == 0 else {
        try closeBlockingProgressSetupDescriptors(
            readDescriptor: &readDescriptor,
            writeDescriptor: &writeDescriptor,
            primary: "F_SETNOSIGPIPE errno=\(errno)"
        )
    }

    let state = BlockingProgressState()
    let readerOwner = HelpProbeProgressOwnedDescriptor(readDescriptor)
    readDescriptor = -1
    let inspector = CliResumeSignalProgressInspector(
        state: state,
        readerOwner: readerOwner
    )
    let ownedWriter = writeDescriptor
    writeDescriptor = -1
    let controller = startBlockingProgressController(
        state: state,
        ownedWriter: ownedWriter,
        releaseByte: 0xD3,
        name: "AgentLoop.test.cli-resume-signal-controller"
    )
    let signalTask = Task {
        try await CliProcessSignalOperationV1.send(
            signal: SIGCONT,
            processGroupId: 31415,
            using: inspector
        )
    }
    signalTask.cancel()
    let cancellationObserved = signalTask.isCancelled
    let result = await signalTask.result
    await state.waitForControllerCompletion()
    withExtendedLifetime(controller) {}
    if let siblingTask = state.retainedSiblingTask() {
        await siblingTask.value
    }
    let abandonedReaderCloseError = readerOwner.closeIfOwned()
    let snapshot = state.snapshot()
    let invocation = inspector.invocation
    print(
        "CLI RESUME SIGNAL PROGRESS PHASES "
            + "cancelled=\(cancellationObserved) "
            + "invocations=\(invocation.count) "
            + "signal=\(String(describing: invocation.signal)) "
            + "group=\(String(describing: invocation.processGroupId)) "
            + "entered=\(snapshot.readEntered) "
            + "sibling=\(snapshot.siblingProgressed) "
            + "rescue=\(snapshot.rescueUsed) "
            + "entry-timeout=\(snapshot.entryTimedOut) "
            + "read=\(String(describing: snapshot.readCount)) "
            + "read-byte=\(String(describing: snapshot.readByte)) "
            + "read-errno=\(String(describing: snapshot.readError)) "
            + "read-close-errno=\(String(describing: snapshot.readerCloseError)) "
            + "write=\(String(describing: snapshot.writeCount)) "
            + "write-errno=\(String(describing: snapshot.writeError)) "
            + "write-close-errno=\(String(describing: snapshot.writerCloseError)) "
            + "controller=\(snapshot.controllerCompleted)"
    )

    try #require(cancellationObserved)
    try #require(abandonedReaderCloseError == nil)
    try #require(invocation.count == 1)
    try #require(invocation.signal == SIGCONT)
    try #require(invocation.processGroupId == 31415)
    switch result {
    case .success:
        throw BlockingProgressTestError.setup([
            "injected resume signal unexpectedly succeeded",
        ])
    case .failure(let error):
        try #require(
            error as? CliResumeSignalProgressSentinel == .blockedResume
        )
    }
    try #require(snapshot.readEntered)
    try #require(!snapshot.entryTimedOut)
    try #require(snapshot.readCount == 1)
    try #require(snapshot.readByte == 0xD3)
    try #require(snapshot.readError == nil)
    try #require(snapshot.readerCloseError == nil)
    try #require(snapshot.writeCount == 1)
    try #require(snapshot.writeError == nil)
    try #require(snapshot.writerCloseError == nil)
    try #require(snapshot.siblingProgressed)
    try #require(snapshot.controllerCompleted)
    try #require(!snapshot.rescueUsed)
    try Data("cli-resume-signal-progress-ok\n".utf8).write(
        to: evidence,
        options: .withoutOverwriting
    )
}

@Test func blockingProcessOperationPreservesCooperativeProgress() async throws {
    let environment = ProcessInfo.processInfo.environment
    if environment[blockingProgressEvidenceKey] != nil {
        guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == "1"
        else { throw BlockingProgressTestError.invalidChildEnvironment }
        try await runBlockingProgressChild(
            evidence: try blockingProgressEvidenceURL(environment: environment)
        )
        return
    }
    guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == nil
    else { throw BlockingProgressTestError.invalidChildEnvironment }
    try await runOwnedSelfExecTest(OwnedSelfExecTestRequest(
        label: blockingProgressLabel,
        filter: "blockingProcessOperationPreservesCooperativeProgress",
        modeEnvironmentKey: "LIBDISPATCH_COOPERATIVE_POOL_STRICT",
        mode: "1",
        evidenceEnvironmentKey: blockingProgressEvidenceKey,
        expectedEvidence: Data("blocking-progress-ok\n".utf8),
        containment: .seconds(15)
    ))
}

@Test func cliHelpProbeSnapshotPreservesCooperativeProgress() async throws {
    let environment = ProcessInfo.processInfo.environment
    if environment[helpProbeProgressEvidenceKey] != nil {
        guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == "1"
        else { throw BlockingProgressTestError.invalidChildEnvironment }
        try await runHelpProbeProgressChild(
            evidence: try helpProbeProgressEvidenceURL(
                environment: environment
            )
        )
        return
    }
    guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == nil
    else { throw BlockingProgressTestError.invalidChildEnvironment }
    try await runOwnedSelfExecTest(OwnedSelfExecTestRequest(
        label: helpProbeProgressLabel,
        filter: "cliHelpProbeSnapshotPreservesCooperativeProgress",
        modeEnvironmentKey: "LIBDISPATCH_COOPERATIVE_POOL_STRICT",
        mode: "1",
        evidenceEnvironmentKey: helpProbeProgressEvidenceKey,
        expectedEvidence: Data("help-probe-progress-ok\n".utf8),
        containment: .seconds(15)
    ))
}

@Test func cliResumeSignalPreservesCooperativeProgress() async throws {
    let environment = ProcessInfo.processInfo.environment
    if environment[cliResumeSignalProgressEvidenceKey] != nil {
        guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == "1"
        else { throw BlockingProgressTestError.invalidChildEnvironment }
        try await runCliResumeSignalProgressChild(
            evidence: try cliResumeSignalProgressEvidenceURL(
                environment: environment
            )
        )
        return
    }
    guard environment["LIBDISPATCH_COOPERATIVE_POOL_STRICT"] == nil
    else { throw BlockingProgressTestError.invalidChildEnvironment }
    try await runOwnedSelfExecTest(OwnedSelfExecTestRequest(
        label: cliResumeSignalProgressLabel,
        filter: "cliResumeSignalPreservesCooperativeProgress",
        modeEnvironmentKey: "LIBDISPATCH_COOPERATIVE_POOL_STRICT",
        mode: "1",
        evidenceEnvironmentKey: cliResumeSignalProgressEvidenceKey,
        expectedEvidence: Data("cli-resume-signal-progress-ok\n".utf8),
        containment: .seconds(15)
    ))
}
