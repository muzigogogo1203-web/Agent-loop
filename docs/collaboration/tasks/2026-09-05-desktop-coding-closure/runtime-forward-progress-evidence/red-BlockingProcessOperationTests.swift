import Darwin
import Foundation
import Testing
@testable import AgentLoopCore

private let blockingProgressEvidenceKey =
    "AGENTLOOP_BLOCKING_PROGRESS_EVIDENCE"
private let blockingProgressLabel = "blocking-process-progress-child"

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

            var byte: UInt8 = 0xA5
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
    controller.name = "AgentLoop.test.blocking-process-controller"
    controller.qualityOfService = .utility
    controller.start()

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
