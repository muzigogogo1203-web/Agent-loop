import Darwin
import Foundation
import Testing
import AgentLoopCore

private enum BoardSocketTestClientError: Error, Equatable {
    case receiveTimedOut
}

private enum BoardSocketTestClientLifecycleEvent: Equatable, Sendable {
    case opened(Int32)
    case closed(Int32, Int32)
}

private final class BoardSocketTestClientLifecycleProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var eventsStorage: [BoardSocketTestClientLifecycleEvent] = []

    func record(_ event: BoardSocketTestClientLifecycleEvent) {
        lock.withLock {
            eventsStorage.append(event)
        }
    }

    func events() -> [BoardSocketTestClientLifecycleEvent] {
        lock.withLock { eventsStorage }
    }
}

private final class P1F1D078LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private enum P1F1D078PeerValidationError: Error, Equatable {
    case rejected(Int32)
}

private final class P1F1D078PeerProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let expectedPid: Int32
    private let rejectsPeer: Bool
    private var callsStorage: [Int32] = []

    init(expectedPid: Int32 = getpid(), rejectsPeer: Bool = false) {
        self.expectedPid = expectedPid
        self.rejectsPeer = rejectsPeer
    }

    func validate(_ peerPid: Int32) throws {
        try lock.withLock {
            callsStorage.append(peerPid)
            guard !rejectsPeer, peerPid == expectedPid else {
                throw P1F1D078PeerValidationError.rejected(peerPid)
            }
        }
    }

    func snapshot() -> [Int32] {
        lock.withLock { callsStorage }
    }
}

private final class P1F1D078CapabilityHandler:
    @unchecked Sendable, ToolHandler
{
    private let lock = NSLock()
    private var inputsStorage: [JSONValue] = []

    func execute(input: JSONValue) async -> ToolOutcome {
        lock.withLock { inputsStorage.append(input) }
        return .result("bound capability result")
    }

    func snapshot() -> [JSONValue] {
        lock.withLock { inputsStorage }
    }
}

private final class P1F1D078SocketAuthorityFixture: @unchecked Sendable {
    let root: URL
    let executionId: String
    let authority: EngineBoardSocketDirectoryAuthorityV1
    let socketURL: URL

    private let lock = NSLock()
    private var closed = false

    init(label: String = "board") throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(
                "b-\(label.prefix(1))-\(UUID().uuidString.prefix(8))",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        executionId = UUID().uuidString
        let descriptor = root.path.withCString {
            Darwin.open(
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw BoardToolServerError.socketSetupFailed(
                "open socket authority"
            )
        }
        var information = stat()
        guard Darwin.fstat(descriptor, &information) == 0 else {
            _ = Darwin.close(descriptor)
            throw BoardToolServerError.socketSetupFailed(
                "stat socket authority"
            )
        }
        do {
            authority = try EngineBoardSocketDirectoryAuthorityV1(
                directoryURL: try p1f1CanonicalDirectoryURL(descriptor),
                ownedDescriptor: descriptor,
                device: UInt64(information.st_dev),
                inode: UInt64(information.st_ino),
                uid: UInt32(information.st_uid),
                mode: UInt16(information.st_mode & mode_t(0o777)),
                ownerIdentityHash: String(repeating: "7", count: 64),
                bootId: executionId
            )
        } catch {
            _ = Darwin.close(descriptor)
            throw error
        }
        socketURL = try BoardToolServer.makeSocketURL(
            directoryAuthority: authority,
            executionId: executionId
        )
    }

    func close() throws {
        let shouldClose = lock.withLock { () -> Bool in
            guard !closed else { return false }
            closed = true
            return true
        }
        guard shouldClose else { return }
        try authority.close()
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }
}

private final class BoardServerTerminalRecorder:
    @unchecked Sendable, EngineBoardTerminalSink
{
    private let lock = NSLock()
    private var storage: [EngineBoardTerminalIntentV1] = []

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        lock.withLock { storage.append(intent) }
    }

    func snapshot() -> [EngineBoardTerminalIntentV1] {
        lock.withLock { storage }
    }
}

private final class BoardServerProgressRecorder:
    @unchecked Sendable, EngineProgressSink
{
    private let lock = NSLock()
    private var storage: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        lock.withLock { storage.append(payload) }
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] {
        lock.withLock { storage }
    }
}

private final class BoardServerStopProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var errorStorage: Bool?
    let finished = DispatchSemaphore(value: 0)

    func record(error: Bool) {
        lock.withLock { errorStorage = error }
        finished.signal()
    }

    var failed: Bool? { lock.withLock { errorStorage } }
}

private final class BoardAsyncStopTestLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, any Error>?
    private var waiters: [CheckedContinuation<Void, any Error>] = []

    var finished: Bool { lock.withLock { result != nil } }

    func finish(_ result: Result<Void, any Error> = .success(())) {
        let pending = lock.withLock { () -> [CheckedContinuation<Void, any Error>] in
            guard self.result == nil else { return [] }
            self.result = result
            let pending = waiters
            waiters.removeAll()
            return pending
        }
        for waiter in pending { waiter.resume(with: result) }
    }

    func wait(phase: String) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let completed = lock.withLock { () -> Result<Void, any Error>? in
                if let result { return result }
                waiters.append(continuation)
                return nil
            }
            if let completed {
                continuation.resume(with: completed)
            } else {
                // This is failure containment, never an ordering delay.
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    self.finish(.failure(BoardToolServerError.socketCleanupFailed(
                        "async stop test timed out: \(phase)"
                    )))
                }
            }
        }
    }
}

private final class BoardSuspendedHandlerTestGate: @unchecked Sendable {
    let queue = DispatchQueue(label: "board-async-stop-handler-test")
    private let lock = NSLock()
    private var released = false

    init() { queue.suspend() }

    func release() {
        lock.withLock {
            guard !released else { return }
            released = true
            queue.resume()
        }
    }
}

private struct P1F1D078BoardSnapshot: Sendable {
    let intents: [EngineBoardTerminalIntentV1]
    let unexpectedErrorType: String?
}

private actor P1F1D078ForwardingBoardSink: EngineBoardTerminalSink {
    private let downstream: any EngineBoardTerminalSink
    private var intents: [EngineBoardTerminalIntentV1] = []
    private var unexpectedErrorType: String?

    init(downstream: any EngineBoardTerminalSink) {
        self.downstream = downstream
    }

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        intents.append(intent)
        do {
            try await downstream.submit(intent)
        } catch {
            unexpectedErrorType = String(reflecting: type(of: error))
            throw error
        }
    }

    func snapshot() -> P1F1D078BoardSnapshot {
        P1F1D078BoardSnapshot(
            intents: intents,
            unexpectedErrorType: unexpectedErrorType
        )
    }
}

private actor P1F1D078ProgressSink: EngineProgressSink {
    private var payloads: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        payloads.append(payload)
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] { payloads }
}

private actor P1F1D078EventSink {
    private var events: [EngineExecutionEvent] = []

    func append(_ event: EngineExecutionEvent) {
        events.append(event)
    }

    func snapshot() -> [EngineExecutionEvent] { events }
}

private final class P1F1D078BoardHarness: @unchecked Sendable {
    let cardId: String
    let server: BoardToolServer
    let executor: ToolExecutor
    let toolNames: [String]
    let terminal: BoardServerTerminalRecorder
    let progress: BoardServerProgressRecorder
    let accepted: P1F1D078LockedCounter
    let peer: P1F1D078PeerProbe

    private let socketAuthority: P1F1D078SocketAuthorityFixture

    init(
        startServer: Bool,
        acceptQueue: DispatchQueue?,
        handlerQueue: DispatchQueue?
    ) throws {
        let fixture = try P1F1D078SocketAuthorityFixture(label: "harness")
        socketAuthority = fixture
        cardId = UUID().uuidString
        terminal = BoardServerTerminalRecorder()
        progress = BoardServerProgressRecorder()
        let acceptedCounter = P1F1D078LockedCounter()
        let peerProbe = P1F1D078PeerProbe()
        accepted = acceptedCounter
        peer = peerProbe
        let built = BoardToolServer.makeExecutor(
            boardTerminalSink: terminal,
            progressSink: progress
        )
        executor = built.executor
        toolNames = built.toolDefs.map(\.name)
        do {
            server = try BoardToolServer(
                directoryAuthority: fixture.authority,
                socketBasename: fixture.socketURL.lastPathComponent,
                token: BoardToolServer.makeToken(),
                cardId: cardId,
                boardTerminalSink: terminal,
                progressSink: progress,
                boundCapabilityTools: EngineBoundCapabilityToolsV1(
                    logicalDefinitions: built.toolDefs,
                    capabilityTools: []
                ),
                validatePeer: { try peerProbe.validate($0) },
                onTerminalAccepted: { acceptedCounter.increment() },
                acceptQueue: acceptQueue,
                handlerQueue: handlerQueue
            )
            if startServer {
                try server.start()
            }
        } catch {
            let primary = error
            do {
                try fixture.close()
            } catch {
                Issue.record("Board harness authority cleanup failed")
            }
            throw primary
        }
    }

    func close() throws {
        try server.stop()
        try socketAuthority.close()
    }
}

private final class P1F1D078ServerFixture: @unchecked Sendable {
    let socketAuthority: P1F1D078SocketAuthorityFixture
    let server: BoardToolServer

    init(
        label: String,
        token: String,
        cardId: String,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        peerProbe: P1F1D078PeerProbe,
        accepted: P1F1D078LockedCounter,
        acceptQueue: DispatchQueue? = nil,
        handlerQueue: DispatchQueue? = nil
    ) throws {
        let authority = try P1F1D078SocketAuthorityFixture(label: label)
        socketAuthority = authority
        do {
            server = try BoardToolServer(
                directoryAuthority: authority.authority,
                socketBasename: authority.socketURL.lastPathComponent,
                token: token,
                cardId: cardId,
                boardTerminalSink: boardTerminalSink,
                progressSink: progressSink,
                boundCapabilityTools: boundCapabilityTools,
                validatePeer: { try peerProbe.validate($0) },
                onTerminalAccepted: { accepted.increment() },
                acceptQueue: acceptQueue,
                handlerQueue: handlerQueue
            )
        } catch {
            let primary = error
            do {
                try authority.close()
            } catch {
                Issue.record("078 failed-server authority cleanup failed")
            }
            throw primary
        }
    }

    func close() throws {
        try server.stop()
        try socketAuthority.close()
    }
}

@Suite(.serialized) struct BoardServerTests {
    @Test func boardServerForwardsProgressAndCompleteTools() async throws {
        let harness = try Self.makeBoardHarness(startServer: false)
        defer { Self.closeRecordingFailure(harness) }
        let note = await harness.executor.execute(
            name: "add_progress_note",
            input: ["text": "阶段一"]
        )
        guard case .result = note else {
            Issue.record("expected add_progress_note result")
            return
        }

        let complete = await harness.executor.execute(name: "complete_card", input: [
            "outcome": "ok",
            "summary": "done",
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])
        guard case .completed = complete else {
            Issue.record("expected complete_card terminal outcome")
            return
        }
        #expect(
            harness.progress.snapshot()
                == [.progress(message: "阶段一")]
        )
        let intents = harness.terminal.snapshot()
        #expect(intents.count == 1)
        guard case .completed = try #require(intents.first) else {
            Issue.record("expected completed Board intent")
            return
        }
    }

    @Test func boardServerFramingForwardsToolCallsWhenSocketsAreAllowed() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let acceptQueue = DispatchQueue(
            label: "board-framing-accept-\(UUID().uuidString)",
            qos: .userInitiated
        )
        let handlerQueue = DispatchQueue(
            label: "board-framing-handler-\(UUID().uuidString)",
            qos: .userInitiated
        )
        acceptQueue.sync {}
        handlerQueue.sync {}
        let harness = try Self.makeBoardHarness(
            startServer: true,
            acceptQueue: acceptQueue,
            handlerQueue: handlerQueue
        )
        defer { Self.closeRecordingFailure(harness) }
        let client = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try client.hello(token: harness.server.token, cardId: harness.cardId)

        let note = try client.call(
            name: "add_progress_note",
            arguments: ["text": "阶段一"]
        )
        #expect(note["kind"]?.stringValue == "result")
        let complete = try client.call(name: "complete_card", arguments: [
            "outcome": "ok",
            "summary": "done",
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])
        #expect(complete["kind"]?.stringValue == "completed")
        #expect(harness.terminal.snapshot().count == 1)
        guard case .completed = try #require(
            harness.terminal.snapshot().first
        ) else {
            Issue.record("expected completed terminal intent")
            return
        }
        #expect(harness.accepted.value == 1)
        client.close()
        try harness.server.stop()
    }

    @Test func boardSocketClientDistinguishesTimeoutFromEOF() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let queue = DispatchQueue(label: "board-timeout-test")
        queue.suspend()
        var queueResumed = false
        defer {
            if !queueResumed {
                queue.resume()
            }
        }
        let harness = try Self.makeBoardHarness(
            startServer: true,
            handlerQueue: queue
        )
        defer { Self.closeRecordingFailure(harness) }
        let client = try BoardSocketTestClient(
            path: harness.server.socketURL.path
        )
        defer { client.close() }
        try client.send([
            "type": "hello",
            "token": .string(harness.server.token),
            "cardId": .string(harness.cardId),
        ])
        #expect(throws: BoardSocketTestClientError.receiveTimedOut) {
            _ = try client.readLine()
        }
        queueResumed = true
        queue.resume()
    }

    @Test func boardSocketClientClosesDescriptorWhenConnectFails() throws {
        let path = "/tmp/al-missing-\(UUID().uuidString.prefix(8)).sock"
        var unrelatedFDs = [Int32](repeating: -1, count: 2)
        let pipeResult = unrelatedFDs.withUnsafeMutableBufferPointer { buffer in
            Darwin.pipe(buffer.baseAddress!)
        }
        guard pipeResult == 0 else {
            throw BoardToolServerError.socketSetupFailed(
                "pipe: \(String(cString: strerror(errno)))"
            )
        }
        defer {
            Darwin.close(unrelatedFDs[0])
            Darwin.close(unrelatedFDs[1])
        }
        let lifecycle = BoardSocketTestClientLifecycleProbe()
        for _ in 0..<20 {
            #expect(throws: BoardToolServerError.self) {
                _ = try BoardSocketTestClient(
                    path: path,
                    lifecycleObserver: { lifecycle.record($0) }
                )
            }
        }
        #expect(Darwin.fcntl(unrelatedFDs[0], F_GETFD) >= 0)
        #expect(Darwin.fcntl(unrelatedFDs[1], F_GETFD) >= 0)
        let events = lifecycle.events()
        guard events.count == 40 else {
            Issue.record("expected 40 owned descriptor lifecycle events")
            return
        }
        for attempt in 0..<20 {
            let openEvent = events[attempt * 2]
            let closeEvent = events[(attempt * 2) + 1]
            guard case .opened(let openedFD) = openEvent,
                  case .closed(let closedFD, let closeResult) = closeEvent else {
                Issue.record(
                    "expected ordered open/close pair for attempt \(attempt)"
                )
                return
            }
            #expect(closedFD == openedFD)
            #expect(closeResult == 0)
        }
    }

    @Test func boardServerRejectsWrongTokenAndMismatchedCard() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        defer { Self.closeRecordingFailure(harness) }
        let wrongToken = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try wrongToken.send(["type": "hello", "token": "bad"])
        #expect(try Self.p1f1d078ReadProtocolRejection(wrongToken)
            == #"{"code":"board_protocol_error","type":"error"}"#)
        wrongToken.close()

        let wrongCard = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try wrongCard.send(JSONValue.object(["type": "hello", "token": .string(harness.server.token), "cardId": "other-card"]))
        #expect(try Self.p1f1d078ReadProtocolRejection(wrongCard)
            == #"{"code":"board_protocol_error","type":"error"}"#)
        wrongCard.close()
        try harness.server.stop()
    }

    @Test func boardServerRejectsSecondConcurrentConnection() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        defer { Self.closeRecordingFailure(harness) }
        let first = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try first.hello(token: harness.server.token, cardId: harness.cardId)

        let second = try BoardSocketTestClient(path: harness.server.socketURL.path)
        let sent = try second.sendObservingPeerClosure(
            JSONValue.object(["type": "hello", "token": .string(harness.server.token), "cardId": .string(harness.cardId)])
        )
        let peerClosed = sent ? (try second.readLine() == nil) : true
        #expect(peerClosed)
        first.close()
        second.close()
        try harness.server.stop()
    }

    @Test func boardServerStopWhileConnectionIsActiveClosesExactlyOnce() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        defer { Self.closeRecordingFailure(harness) }
        let client = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try client.hello(token: harness.server.token, cardId: harness.cardId)

        try harness.server.stop()
        #expect(try client.readLine() == nil)
        client.close()
    }

    @Test(arguments: [false, true])
    func boardServerAsyncStopJoinsCleanupDespiteCallerCancellation(
        replaceSocket: Bool
    ) async throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let gate = BoardSuspendedHandlerTestGate()
        var harness: P1F1D078BoardHarness?
        var client: BoardSocketTestClient?
        var probe: BoardSocketTestClient?
        var movedSocket: URL?
        defer {
            // Every failure path unblocks the owned handler before joining it.
            gate.release()
            probe?.close()
            client?.close()
            if let movedSocket, let harness {
                do {
                    if FileManager.default.fileExists(atPath: harness.server.socketURL.path) {
                        try FileManager.default.removeItem(at: harness.server.socketURL)
                    }
                    try FileManager.default.moveItem(at: movedSocket, to: harness.server.socketURL)
                } catch {
                    Issue.record("async stop test socket authority restoration failed: \(error)")
                }
            }
            if let harness { Self.closeRecordingFailure(harness) }
        }
        let made = try Self.makeBoardHarness(startServer: true, handlerQueue: gate.queue)
        harness = made
        let server = made.server
        let activeClient = try Self.connectClientWithRetry(path: server.socketURL.path)
        client = activeClient
        let secondClient = try Self.connectClientWithRetry(path: server.socketURL.path)
        probe = secondClient
        let sent = try secondClient.sendObservingPeerClosure([
            "type": "hello", "token": .string(server.token), "cardId": .string(made.cardId),
        ])
        // Rejection proves the first connection owns the controlled handler slot.
        try #require(sent ? (try secondClient.readRawLine() == nil) : true)
        secondClient.close()
        probe = nil

        let arrivals = (0..<3).map { _ in BoardAsyncStopTestLatch() }
        let completions = (0..<3).map { _ in BoardAsyncStopTestLatch() }
        let callers = (0..<3).map { index in
            Task {
                arrivals[index].finish()
                do {
                    try await server.stopAsync()
                    completions[index].finish()
                } catch {
                    completions[index].finish(.failure(error))
                }
            }
        }
        defer { for caller in callers { caller.cancel() } }
        for arrival in arrivals { try await arrival.wait(phase: "caller arrival") }
        // Arrival is not evidence that every caller registered as a stop waiter.
        // EOF and closed listener establish that real cleanup has started.
        try #require(try activeClient.readRawLine() == nil)
        try Self.p1f1d078WaitForListenerClosed(path: server.socketURL.path)
        for completion in completions { #expect(!completion.finished) }
        callers[0].cancel()

        if replaceSocket {
            let moved = server.socketURL.deletingLastPathComponent()
                .appendingPathComponent("original.sock")
            try FileManager.default.moveItem(at: server.socketURL, to: moved)
            movedSocket = moved
            try Data("replacement sentinel".utf8).write(to: server.socketURL)
        }
        // Independent async test work must be able to release the join dependency.
        await Task { gate.release() }.value
        for completion in completions {
            do {
                try await completion.wait(phase: "checked stop completion")
                #expect(!replaceSocket)
            } catch {
                #expect(replaceSocket)
                #expect(error as? BoardToolServerError == .socketIdentityMismatch)
            }
        }
        #expect(callers[0].isCancelled)
        #expect(try activeClient.readRawLine() == nil)
        if let moved = movedSocket {
            #expect(try Data(contentsOf: server.socketURL) == Data("replacement sentinel".utf8))
            try FileManager.default.removeItem(at: server.socketURL)
            try FileManager.default.moveItem(at: moved, to: server.socketURL)
            movedSocket = nil
            // A completed failure cannot be cached: restored authority permits retry.
            try await server.stopAsync()
        }
        #expect(!FileManager.default.fileExists(atPath: server.socketURL.path))
        try await server.stopAsync()
        try made.close()
    }

    @Test func boardServerStopWaitsForBlockedHandlerThenCloses() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let baseline = Self.fileDescriptorCount()
        for _ in 0..<20 {
            let queue = DispatchQueue(label: "board-handler-test")
            queue.suspend()
            // 释放挂起状态的队列会被 libdispatch trap 掉整个进程；任何 throw 路径都必须恰好 resume 一次
            var queueResumed = false
            var server: BoardToolServer?
            var harness: P1F1D078BoardHarness?
            var ownedClient: BoardSocketTestClient?
            var ownedProbe: BoardSocketTestClient?
            defer {
                if !queueResumed {
                    queueResumed = true
                    queue.resume()
                }
                ownedProbe?.close()
                ownedClient?.close()
                if let harness { Self.closeRecordingFailure(harness) }
            }
            var cardId = ""
            do {
                let made = try Self.makeBoardHarness(
                    startServer: false,
                    handlerQueue: queue
                )
                harness = made
                server = made.server
                cardId = made.cardId
            }
            try server?.start()
            // backlog=1：acceptLoop 尚未取走上一个连接时新 connect 会被拒，需有界重试
            let client = try Self.connectClientWithRetry(path: server!.socketURL.path)
            ownedClient = client
            let probe = try Self.connectClientWithRetry(path: server!.socketURL.path)
            ownedProbe = probe
            let sent = try probe.sendObservingPeerClosure(["type": "hello", "token": .string(server!.token), "cardId": .string(cardId)])
            #expect(sent ? (try probe.readLine() == nil) : true)
            probe.close()
            let stoppingServer = try #require(server)
            let stopProbe = BoardServerStopProbe()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try stoppingServer.stop()
                    stopProbe.record(error: false)
                } catch {
                    stopProbe.record(error: true)
                }
            }
            #expect(stopProbe.finished.wait(timeout: .now() + 0.1) == .timedOut)
            queueResumed = true
            queue.resume()
            #expect(stopProbe.finished.wait(timeout: .now() + 2) == .success)
            #expect(stopProbe.failed == false)
            #expect(try client.readLine() == nil)
            client.close()
            try harness?.close()
            server = nil
            harness = nil
        }
        #expect(Self.fileDescriptorCount() - baseline < 10)
    }

    @Test func boardServerStopWakesBlockedAcceptLoopAndReleasesListener() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let baseline = Self.fileDescriptorCount()
        for _ in 0..<100 {
            var server: BoardToolServer?
            var harness: P1F1D078BoardHarness?
            var ownedClient: BoardSocketTestClient?
            defer {
                ownedClient?.close()
                if let harness { Self.closeRecordingFailure(harness) }
            }
            var cardId = ""
            do {
                let made = try Self.makeBoardHarness(startServer: true)
                harness = made
                server = made.server
                cardId = made.cardId
            }
            let socketPath = server!.socketURL.path
            let client = try BoardSocketTestClient(path: socketPath)
            ownedClient = client
            try client.hello(token: server!.token, cardId: cardId)
            client.close()
            try server?.stop()
            weak var weakServer = server
            server = nil
            try harness?.close()
            harness = nil
            let deadline = Date().addingTimeInterval(5)
            while weakServer != nil, Date() < deadline { usleep(10_000) }
            #expect(weakServer == nil)
            #expect(!FileManager.default.fileExists(atPath: socketPath))
        }
        #expect(Self.fileDescriptorCount() - baseline < 10)
    }

    @Test func boardServerDefinitionsExposeExactlyFourBoardTools() throws {
        let harness = try Self.makeBoardHarness(startServer: false)
        defer { Self.closeRecordingFailure(harness) }
        #expect(
            harness.toolNames
                == [
                    "complete_card", "block_card", "add_progress_note",
                    "ask_user",
                ]
        )
        try harness.server.stop()
    }

    @Test func p1f1_078BoardServerForwardsProposalWithoutDatabaseAuthority()
        async throws
    {
        guard agentLoopCanBindListenerSocket() else { return }
        let executionId = "00000000-0000-4000-8000-000000000078"
        let runId = "10000000-0000-4000-8000-000000000078"
        let cardId = "20000000-0000-4000-8000-000000000078"
        let router = EngineEventRouterV1(
            executionId: executionId,
            runId: runId,
            cardId: cardId,
            nextSequence: 8,
            initialUsage: .zero
        )
        let manifestCalls = P1F1D078LockedCounter()
        let commits = P1F1D078EventSink()
        let routerSink = EngineBoardTerminalRouterSinkV1(
            router: router,
            manifestResolver: { _ in
                manifestCalls.increment()
                return []
            },
            commit: { event in
                await commits.append(event)
            }
        )
        let forwardingSink = P1F1D078ForwardingBoardSink(
            downstream: routerSink
        )
        let progressSink = P1F1D078ProgressSink()
        let capabilityHandler = P1F1D078CapabilityHandler()
        let logicalDefinitions = Self.p1f1d078LogicalDefinitions()
        let boundCapabilityTools = EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: [
                ExternalTool(
                    def: .readFile,
                    handler: capabilityHandler
                ),
            ]
        )
        let token = String(repeating: "c", count: 64)
        let accepted = P1F1D078LockedCounter()
        let peer = P1F1D078PeerProbe()
        let main = try P1F1D078ServerFixture(
            label: "main",
            token: token,
            cardId: cardId,
            boardTerminalSink: forwardingSink,
            progressSink: progressSink,
            boundCapabilityTools: boundCapabilityTools,
            peerProbe: peer,
            accepted: accepted,
            acceptQueue: DispatchQueue(
                label: "p1f1-078-main-accept",
                qos: .userInitiated
            ),
            handlerQueue: DispatchQueue(
                label: "p1f1-078-main-handler",
                qos: .userInitiated
            )
        )
        try main.server.start()
        defer { Self.p1f1d078CloseRecordingFailure(main) }

        try Self.p1f1d078AssertProtocolRejections(
            logicalDefinitions: logicalDefinitions
        )
        try Self.p1f1d078AssertInitializerAndSocketLifecycle(
            logicalDefinitions: logicalDefinitions
        )

        let expectedTools = logicalDefinitions
            .sorted { Array($0.name.utf8).lexicographicallyPrecedes(
                Array($1.name.utf8)
            ) }
            .map(Self.p1f1d078ToolJSON)
        let listRPC = try JSONValue.object([
            "jsonrpc": "2.0",
            "id": "p1f1-078-list",
            "method": "tools/list",
        ]).encodedString()
        let listResponse = try #require(
            try BoardServerBridgeMain.processJSONRPCFrameForTesting(
                raw: listRPC,
                socketPath: main.server.socketURL.path,
                token: token,
                cardId: cardId
            )
        )
        #expect(
            listResponse["result"]?["tools"]
                == .array(expectedTools)
        )

        let hello: JSONValue = [
            "cardId": .string(cardId),
            "token": .string(token),
            "type": "hello",
        ]
        let canonicalHello = try hello.encodedString()
        #expect(
            canonicalHello
                == "{\"cardId\":\"\(cardId)\",\"token\":\"\(token)\",\"type\":\"hello\"}"
        )
        let authorized = try Self.p1f1d078ConnectAuthorizedClientWithRetry(
            socketPath: main.server.socketURL.path,
            canonicalHello: canonicalHello
        )
        let client = authorized.client
        let rawHelloOK = authorized.helloOK
        let expectedHelloOK = try JSONValue.object([
            "tools": .array(expectedTools),
            "type": "hello_ok",
        ]).encodedString()
        #expect(rawHelloOK == expectedHelloOK)
        #expect(rawHelloOK.utf8.count + 1 <= 256 * 1_024)

        let capabilityArguments: JSONValue = ["path": "README.md"]
        let capabilityCall: JSONValue = [
            "arguments": capabilityArguments,
            "cardId": .string(cardId),
            "id": "p1f1-078-capability",
            "name": "read_file",
            "type": "tool_call",
        ]
        let canonicalCapabilityCall = try capabilityCall.encodedString()
        #expect(
            canonicalCapabilityCall
                == "{\"arguments\":{\"path\":\"README.md\"},\"cardId\":\"\(cardId)\",\"id\":\"p1f1-078-capability\",\"name\":\"read_file\",\"type\":\"tool_call\"}"
        )
        try client.sendRaw(canonicalCapabilityCall)
        let capabilityResponse = try #require(try client.readLine())
        #expect(capabilityResponse["kind"]?.stringValue == "result")
        #expect(
            capabilityResponse["text"]?.stringValue
                == "bound capability result"
        )
        #expect(capabilityHandler.snapshot() == [capabilityArguments])
        #expect(accepted.value == 0)
        #expect(manifestCalls.value == 0)
        #expect((await forwardingSink.snapshot()).intents.isEmpty)

        let rpcArguments: JSONValue = [
                "outcome": "implemented",
                "summary": "parent Board server forwarded one intent",
                "artifacts": [],
                "noArtifactReason": "No file artifact in socket conformance.",
                "verification": [[
                    "method": "authenticated frame",
                    "passed": true,
                    "note": "same typed parent sink",
                ]],
                "risks": [],
        ]
        let terminalCall: JSONValue = [
            "arguments": rpcArguments,
            "cardId": .string(cardId),
            "id": "p1f1-078-terminal",
            "name": "complete_card",
            "type": "tool_call",
        ]
        try client.sendRaw(try terminalCall.encodedString())
        let response = try #require(try client.readLine())
        client.close()

        let redSnapshot = await forwardingSink.snapshot()
        #expect(redSnapshot.unexpectedErrorType == nil)
        #expect(response["isError"]?.boolValue == false)
        #expect(response["text"]?.stringValue == "Card completed.")
        #expect(main.server.socketURL == main.socketAuthority.socketURL)
        #expect(main.server.token == token)
        #expect(accepted.value == 1)
        #expect(manifestCalls.value == 1)
        #expect(await progressSink.snapshot().isEmpty)
        #expect(capabilityHandler.snapshot() == [capabilityArguments])
        #expect(redSnapshot.intents.count == 1)
        guard case let .completed(handoff) = try #require(
            redSnapshot.intents.first
        ) else {
            Issue.record("parent server must forward completed Board intent")
            return
        }
        #expect(handoff.outcome == "implemented")

        let routed = await commits.snapshot()
        #expect(routed.count == 1)
        let event = try #require(routed.first)
        #expect(event.executionId == executionId)
        #expect(event.sequence == 8)
        guard case let .terminal(proposal) = event.payload else {
            Issue.record("same parent sink must route one terminal proposal")
            return
        }
        #expect(proposal.terminalKind == .completed)
        #expect(proposal.payload == .completed(handoff: handoff))
        #expect(proposal.artifacts.isEmpty)
        #expect(peer.snapshot().count == 2)
        #expect(peer.snapshot().allSatisfy { $0 == getpid() })

        let mainSocketPath = main.server.socketURL.path
        try main.close()
        #expect(!FileManager.default.fileExists(atPath: mainSocketPath))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bridgeSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift"
            ),
            encoding: .utf8
        )
        for forbidden in [
            "EngineTerminalSink", "EngineBoardTerminalSink",
            "EngineProgressSink", "terminalOutcome",
            "AGENTLOOP_BOARD_TOOLS", "defaultToolNames",
        ] {
            #expect(!bridgeSource.contains(forbidden))
        }
        let serverSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AgentLoopCore/Loop/BoardToolServer.swift"
            ),
            encoding: .utf8
        )
        #expect(!serverSource.contains("AppDatabase"))
        #expect(!serverSource.contains("terminalOutcome"))
    }

    private static func p1f1d078LogicalDefinitions() -> [ToolDef] {
        [
            .completeCard,
            .blockCard,
            .addProgressNote,
            .askUser,
            .readFile,
        ]
    }

    private static func p1f1d078ToolJSON(_ definition: ToolDef) -> JSONValue {
        [
            "description": .string(definition.description),
            "inputSchema": definition.inputSchema,
            "name": .string(definition.name),
        ]
    }

    private static func p1f1d078CloseRecordingFailure(
        _ fixture: P1F1D078ServerFixture
    ) {
        do {
            try fixture.close()
        } catch {
            Issue.record("078 server fixture cleanup failed")
        }
    }

    private static func p1f1d078AssertProtocolRejections(
        logicalDefinitions: [ToolDef]
    ) throws {
        let terminal = BoardServerTerminalRecorder()
        let progress = BoardServerProgressRecorder()
        let handler = P1F1D078CapabilityHandler()
        let accepted = P1F1D078LockedCounter()
        let cardId = "21000000-0000-4000-8000-000000000078"
        let token = String(repeating: "d", count: 64)
        let bound = EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: [ExternalTool(def: .readFile, handler: handler)]
        )

        let rejectedPeer = P1F1D078PeerProbe(rejectsPeer: true)
        let peerFixture = try P1F1D078ServerFixture(
            label: "wrong-peer",
            token: token,
            cardId: cardId,
            boardTerminalSink: terminal,
            progressSink: progress,
            boundCapabilityTools: bound,
            peerProbe: rejectedPeer,
            accepted: accepted
        )
        try peerFixture.server.start()
        let peerClient = try connectClientWithRetry(
            path: peerFixture.server.socketURL.path
        )
        #expect(try peerClient.readRawLine() == nil)
        peerClient.close()
        #expect(rejectedPeer.snapshot() == [getpid()])
        try peerFixture.close()

        let peer = P1F1D078PeerProbe()
        let fixture = try P1F1D078ServerFixture(
            label: "protocol",
            token: token,
            cardId: cardId,
            boardTerminalSink: terminal,
            progressSink: progress,
            boundCapabilityTools: bound,
            peerProbe: peer,
            accepted: accepted
        )
        try fixture.server.start()
        defer { p1f1d078CloseRecordingFailure(fixture) }

        let wrongToken: JSONValue = [
            "cardId": .string(cardId),
            "token": .string(String(repeating: "e", count: 64)),
            "type": "hello",
        ]
        let wrongCard: JSONValue = [
            "cardId": "22000000-0000-4000-8000-000000000078",
            "token": .string(token),
            "type": "hello",
        ]
        let authorizationFingerprints = try [wrongToken, wrongCard].map {
            try p1f1d078RejectedHello(
                raw: $0.encodedString(),
                socketPath: fixture.server.socketURL.path
            )
        }
        #expect(Set(authorizationFingerprints).count == 1)

        let validCall: [String: JSONValue] = [
            "arguments": ["path": "README.md"],
            "cardId": .string(cardId),
            "id": "p1f1-078-rejected",
            "name": "read_file",
            "type": "tool_call",
        ]
        var wrongCallCard = validCall
        wrongCallCard["cardId"] =
            "23000000-0000-4000-8000-000000000078"
        var unknownName = validCall
        unknownName["name"] = "unlisted_tool"
        var missingArguments = validCall
        missingArguments.removeValue(forKey: "arguments")
        var extraKey = validCall
        extraKey["extra"] = true
        let duplicateKey =
            "{\"arguments\":{\"path\":\"README.md\"},"
            + "\"cardId\":\"\(cardId)\",\"id\":\"duplicate\","
            + "\"name\":\"read_file\",\"name\":\"read_file\","
            + "\"type\":\"tool_call\"}"
        let noncanonical =
            "{ \"type\": \"tool_call\", \"name\": \"read_file\","
            + " \"id\": \"noncanonical\", \"cardId\": \"\(cardId)\","
            + " \"arguments\": {\"path\":\"README.md\"} }"
        let oversized = try JSONValue.object([
            "arguments": [
                "path": .string(String(repeating: "x", count: 256 * 1_024)),
            ],
            "cardId": .string(cardId),
            "id": "oversized",
            "name": "read_file",
            "type": "tool_call",
        ]).encodedString()
        #expect(oversized.utf8.count + 1 > 256 * 1_024)

        let rejectedCalls = try [
            try JSONValue.object(wrongCallCard).encodedString(),
            try JSONValue.object(unknownName).encodedString(),
            try JSONValue.object(missingArguments).encodedString(),
            try JSONValue.object(extraKey).encodedString(),
            duplicateKey,
            noncanonical,
            oversized,
        ].map {
            try p1f1d078RejectedCall(
                raw: $0,
                socketPath: fixture.server.socketURL.path,
                token: token,
                cardId: cardId
            )
        }
        #expect(Set(rejectedCalls).count == 1)
        #expect(handler.snapshot().isEmpty)
        #expect(terminal.snapshot().isEmpty)
        #expect(progress.snapshot().isEmpty)
        #expect(accepted.value == 0)
        #expect(peer.snapshot().count == 9)
        #expect(peer.snapshot().allSatisfy { $0 == getpid() })
    }

    private static func p1f1d078RejectedHello(
        raw: String,
        socketPath: String
    ) throws -> String {
        let client = try connectClientWithRetry(path: socketPath)
        defer { client.close() }
        let sent = try client.sendRawObservingPeerClosure(raw)
        guard sent else { return "EOF" }
        return try p1f1d078ReadProtocolRejection(client)
    }

    private static func p1f1d078ConnectAuthorizedClientWithRetry(
        socketPath: String,
        canonicalHello: String,
        timeout: TimeInterval = 2
    ) throws -> (client: BoardSocketTestClient, helloOK: String) {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            do {
                let client = try BoardSocketTestClient(path: socketPath)
                let sent = try client.sendRawObservingPeerClosure(
                    canonicalHello
                )
                if sent, let response = try client.readRawLine() {
                    return (client, response)
                }
                client.close()
            } catch BoardToolServerError.socketSetupFailed(_)
                where Date() < deadline
            {
                // The previous authenticated bridge connection may still be
                // leaving the single-connection gate. Retry only until the
                // fixed local deadline.
            }
            guard Date() < deadline else {
                throw BoardToolServerError.socketSetupFailed(
                    "authorized Board test connection timed out"
                )
            }
            usleep(10_000)
        }
    }

    private static func p1f1d078RejectedCall(
        raw: String,
        socketPath: String,
        token: String,
        cardId: String
    ) throws -> String {
        let client = try connectClientWithRetry(path: socketPath)
        defer { client.close() }
        _ = try client.hello(token: token, cardId: cardId)
        let sent = try client.sendRawObservingPeerClosure(raw)
        guard sent else { return "EOF" }
        return try p1f1d078ReadProtocolRejection(client)
    }

    private static func p1f1d078ReadProtocolRejection(
        _ client: BoardSocketTestClient
    ) throws -> String {
        guard let first = try client.readRawLine() else { return "EOF" }
        #expect(try client.readRawLine() == nil)
        return first
    }

    private static func p1f1d078AssertInitializerAndSocketLifecycle(
        logicalDefinitions: [ToolDef]
    ) throws {
        let schema: JSONValue = [
            "additionalProperties": false,
            "properties": .object([:]),
            "type": "object",
        ]
        let handler = P1F1D078CapabilityHandler()
        let malformedSchema = ToolDef(
            name: "malformed_schema",
            description: "malformed",
            inputSchema: "not-an-object"
        )
        try p1f1d078ExpectInitializerRejection(
            EngineBoundCapabilityToolsV1(
                logicalDefinitions: Array(logicalDefinitions.dropLast())
                    + [malformedSchema],
                capabilityTools: [
                    ExternalTool(def: malformedSchema, handler: handler),
                ]
            )
        )
        try p1f1d078ExpectInitializerRejection(
            EngineBoundCapabilityToolsV1(
                logicalDefinitions: logicalDefinitions + [.readFile],
                capabilityTools: [
                    ExternalTool(def: .readFile, handler: handler),
                    ExternalTool(def: .readFile, handler: handler),
                ]
            )
        )
        let manyDefinitions = (0..<253).map { index in
            ToolDef(
                name: String(format: "capability_%03d", index),
                description: "bounded capability",
                inputSchema: schema
            )
        }
        try p1f1d078ExpectInitializerRejection(
            EngineBoundCapabilityToolsV1(
                logicalDefinitions: Array(logicalDefinitions.dropLast())
                    + manyDefinitions,
                capabilityTools: manyDefinitions.map {
                    ExternalTool(def: $0, handler: handler)
                }
            )
        )
        let oversizedDefinition = ToolDef(
            name: "oversized_tool",
            description: String(repeating: "x", count: 256 * 1_024),
            inputSchema: schema
        )
        try p1f1d078ExpectInitializerRejection(
            EngineBoundCapabilityToolsV1(
                logicalDefinitions: Array(logicalDefinitions.dropLast())
                    + [oversizedDefinition],
                capabilityTools: [
                    ExternalTool(def: oversizedDefinition, handler: handler),
                ]
            )
        )
        #expect(handler.snapshot().isEmpty)

        let terminal = BoardServerTerminalRecorder()
        let progress = BoardServerProgressRecorder()
        let bound = EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: [ExternalTool(def: .readFile, handler: handler)]
        )
        let collision = try P1F1D078ServerFixture(
            label: "collision",
            token: String(repeating: "f", count: 64),
            cardId: "24000000-0000-4000-8000-000000000078",
            boardTerminalSink: terminal,
            progressSink: progress,
            boundCapabilityTools: bound,
            peerProbe: P1F1D078PeerProbe(),
            accepted: P1F1D078LockedCounter()
        )
        let sentinel = Data("do-not-predelete".utf8)
        try sentinel.write(to: collision.socketAuthority.socketURL)
        var before = stat()
        #expect(
            collision.server.socketURL.path.withCString {
                Darwin.lstat($0, &before)
            } == 0
        )
        #expect(throws: BoardToolServerError.self) {
            try collision.server.start()
        }
        var after = stat()
        #expect(
            collision.server.socketURL.path.withCString {
                Darwin.lstat($0, &after)
            } == 0
        )
        #expect(before.st_dev == after.st_dev)
        #expect(before.st_ino == after.st_ino)
        #expect(try Data(contentsOf: collision.socketAuthority.socketURL)
            == sentinel)
        try collision.close()

        try p1f1d078AssertReplacementSafeStop(
            boundCapabilityTools: bound,
            terminal: terminal,
            progress: progress
        )
        #expect(handler.snapshot().isEmpty)
        #expect(terminal.snapshot().isEmpty)
        #expect(progress.snapshot().isEmpty)
    }

    private static func p1f1d078ExpectInitializerRejection(
        _ boundCapabilityTools: EngineBoundCapabilityToolsV1
    ) throws {
        let authority = try P1F1D078SocketAuthorityFixture(label: "bad-init")
        var rejected = false
        do {
            let server = try BoardToolServer(
                directoryAuthority: authority.authority,
                socketBasename: authority.socketURL.lastPathComponent,
                token: String(repeating: "a", count: 64),
                cardId: "25000000-0000-4000-8000-000000000078",
                boardTerminalSink: BoardServerTerminalRecorder(),
                progressSink: BoardServerProgressRecorder(),
                boundCapabilityTools: boundCapabilityTools,
                validatePeer: { _ in },
                onTerminalAccepted: {}
            )
            Issue.record("078 invalid definitions unexpectedly initialized")
            try server.stop()
        } catch is BoardToolServerError {
            rejected = true
        }
        #expect(rejected)
        try authority.close()
    }

    private static func p1f1d078AssertReplacementSafeStop(
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        terminal: BoardServerTerminalRecorder,
        progress: BoardServerProgressRecorder
    ) throws {
        let handlerQueue = DispatchQueue(label: "p1f1-078-replacement")
        let handlerStarted = DispatchSemaphore(value: 0)
        let releaseHandler = DispatchSemaphore(value: 0)
        handlerQueue.async {
            handlerStarted.signal()
            releaseHandler.wait()
        }
        #expect(handlerStarted.wait(timeout: .now() + 2) == .success)
        var handlerReleased = false
        let fixture = try P1F1D078ServerFixture(
            label: "replacement",
            token: String(repeating: "b", count: 64),
            cardId: "26000000-0000-4000-8000-000000000078",
            boardTerminalSink: terminal,
            progressSink: progress,
            boundCapabilityTools: boundCapabilityTools,
            peerProbe: P1F1D078PeerProbe(),
            accepted: P1F1D078LockedCounter(),
            handlerQueue: handlerQueue
        )
        var client: BoardSocketTestClient?
        var replacementFD: Int32 = -1
        var stopLaunched = false
        var stopFinished = false
        let stopProbe = BoardServerStopProbe()
        let moved = fixture.socketAuthority.root
            .appendingPathComponent("original.sock")
        defer {
            if !handlerReleased {
                handlerReleased = true
                releaseHandler.signal()
            }
            client?.close()
            if replacementFD >= 0 {
                if Darwin.close(replacementFD) != 0 {
                    Issue.record("078 replacement descriptor cleanup failed")
                }
                replacementFD = -1
            }
            if stopLaunched {
                if !stopFinished,
                   stopProbe.finished.wait(timeout: .now() + 2) != .success
                {
                    Issue.record(
                        "078 replacement stop cleanup timed out"
                    )
                }
            } else {
                do {
                    try fixture.server.stop()
                } catch {
                    Issue.record("078 replacement server cleanup failed")
                }
            }
            for url in [fixture.server.socketURL, moved] {
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        Issue.record("078 replacement path cleanup failed")
                    }
                }
            }
            do {
                try fixture.socketAuthority.close()
            } catch {
                Issue.record("078 replacement authority cleanup failed")
            }
        }
        try fixture.server.start()
        client = try connectClientWithRetry(
            path: fixture.server.socketURL.path
        )
        let probe = try connectClientWithRetry(
            path: fixture.server.socketURL.path
        )
        let probeSent = try probe.sendObservingPeerClosure([
            "cardId": "26000000-0000-4000-8000-000000000078",
            "token": .string(String(repeating: "b", count: 64)),
            "type": "hello",
        ])
        #expect(probeSent ? (try probe.readRawLine() == nil) : true)
        probe.close()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try fixture.server.stop()
                stopProbe.record(error: false)
            } catch {
                stopProbe.record(error: true)
            }
        }
        stopLaunched = true
        let activeClient = try #require(client)
        #expect(try activeClient.readRawLine() == nil)
        try p1f1d078WaitForListenerClosed(
            path: fixture.server.socketURL.path
        )
        #expect(stopProbe.finished.wait(timeout: .now()) == .timedOut)

        try FileManager.default.moveItem(
            at: fixture.server.socketURL,
            to: moved
        )
        replacementFD = try p1f1d078BindSocket(
            path: fixture.server.socketURL.path
        )
        var replacementBefore = stat()
        #expect(
            fixture.server.socketURL.path.withCString {
                Darwin.lstat($0, &replacementBefore)
            } == 0
        )

        handlerReleased = true
        releaseHandler.signal()
        #expect(stopProbe.finished.wait(timeout: .now() + 2) == .success)
        stopFinished = true
        #expect(stopProbe.failed == true)
        client?.close()
        client = nil
        var replacementAfter = stat()
        #expect(
            fixture.server.socketURL.path.withCString {
                Darwin.lstat($0, &replacementAfter)
            } == 0
        )
        #expect(replacementBefore.st_dev == replacementAfter.st_dev)
        #expect(replacementBefore.st_ino == replacementAfter.st_ino)
        #expect(replacementAfter.st_mode & S_IFMT == S_IFSOCK)

        #expect(Darwin.close(replacementFD) == 0)
        replacementFD = -1
        try FileManager.default.removeItem(at: fixture.server.socketURL)
        try FileManager.default.removeItem(at: moved)
        try fixture.socketAuthority.close()
    }

    private static func p1f1d078WaitForListenerClosed(
        path: String,
        timeout: TimeInterval = 2
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else {
                throw BoardToolServerError.socketSetupFailed(
                    "listener close probe"
                )
            }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = Array(path.utf8) + [0]
            guard pathBytes.count
                <= MemoryLayout.size(ofValue: address.sun_path)
            else {
                _ = Darwin.close(fd)
                throw BoardToolServerError.socketPathTooLong(path)
            }
            withUnsafeMutableBytes(of: &address.sun_path) { raw in
                raw.copyBytes(from: pathBytes)
            }
            let length = socklen_t(
                MemoryLayout<sockaddr_un>.offset(of: \.sun_path)!
                    + pathBytes.count
            )
            address.sun_len = UInt8(length)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, length)
                }
            }
            let savedErrno = errno
            #expect(Darwin.close(fd) == 0)
            if result != 0,
               savedErrno == ECONNREFUSED || savedErrno == ENOENT
            {
                return
            }
            guard Date() < deadline else {
                throw BoardToolServerError.socketSetupFailed(
                    "listener did not close"
                )
            }
            usleep(10_000)
        }
    }

    private static func p1f1d078BindSocket(path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BoardToolServerError.socketSetupFailed("replacement socket")
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path)
        else {
            _ = Darwin.close(fd)
            throw BoardToolServerError.socketPathTooLong(path)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
        }
        let length = socklen_t(
            MemoryLayout<sockaddr_un>.offset(of: \.sun_path)!
                + pathBytes.count
        )
        address.sun_len = UInt8(length)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, length)
            }
        }
        guard result == 0, Darwin.listen(fd, 1) == 0 else {
            let message = String(cString: strerror(errno))
            _ = Darwin.close(fd)
            throw BoardToolServerError.socketSetupFailed(message)
        }
        return fd
    }

    private static func makeBoardHarness(
        startServer: Bool,
        acceptQueue: DispatchQueue? = nil,
        handlerQueue: DispatchQueue? = nil
    ) throws -> P1F1D078BoardHarness {
        try P1F1D078BoardHarness(
            startServer: startServer,
            acceptQueue: acceptQueue,
            handlerQueue: handlerQueue
        )
    }

    private static func closeRecordingFailure(
        _ harness: P1F1D078BoardHarness
    ) {
        do {
            try harness.close()
        } catch {
            Issue.record("Board harness shutdown failed")
        }
    }

    private static func fileDescriptorCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? 0
    }

    private static func connectClientWithRetry(path: String, timeout: TimeInterval = 2) throws -> BoardSocketTestClient {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            do {
                return try BoardSocketTestClient(path: path)
            } catch BoardToolServerError.socketSetupFailed(let message)
                where message.contains("Connection refused") && Date() < deadline {
                usleep(10_000)
            }
        }
    }
}

func agentLoopCanBindListenerSocket() -> Bool {
    // 与 makeBoardHarness 的 socket 目录同源：探针必须探真实绑定位置
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("al-probe")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("probe-\(UUID().uuidString.prefix(8)).sock").path
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer {
        close(fd)
        try? FileManager.default.removeItem(atPath: path)
    }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8) + [0]
    guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return false }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in
        raw.copyBytes(from: pathBytes)
    }
    let length = socklen_t(MemoryLayout<sockaddr_un>.offset(of: \.sun_path)! + pathBytes.count)
    address.sun_len = UInt8(length)
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.bind(fd, sockaddrPointer, length)
        }
    }
    return result == 0
}

private final class BoardSocketTestClient {
    private var fd: Int32 = -1
    private var authorizedCardId: String?
    private let lifecycleObserver:
        (@Sendable (BoardSocketTestClientLifecycleEvent) -> Void)?

    init(
        path: String,
        lifecycleObserver:
            (@Sendable (BoardSocketTestClientLifecycleEvent) -> Void)? = nil
    ) throws {
        self.lifecycleObserver = lifecycleObserver
        let openedFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard openedFD >= 0 else {
            throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
        }
        lifecycleObserver?(.opened(openedFD))
        guard PosixSockets.disableSIGPIPE(openedFD) else {
            Self.close(openedFD, observer: lifecycleObserver)
            throw BoardToolServerError.socketSetupFailed("SO_NOSIGPIPE: \(String(cString: strerror(errno)))")
        }
        do {
            try Self.connect(fd: openedFD, path: path)
        } catch {
            Self.close(openedFD, observer: lifecycleObserver)
            throw error
        }
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(openedFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        fd = openedFD
    }

    deinit {
        close()
    }

    @discardableResult
    func hello(token: String, cardId: String) throws -> String {
        try send([
            "type": "hello",
            "token": .string(token),
            "cardId": .string(cardId),
        ])
        let raw = try #require(try readRawLine())
        let response = try JSONValue.decoded(from: raw)
        #expect(response["type"]?.stringValue == "hello_ok")
        authorizedCardId = cardId
        return raw
    }

    func call(name: String, arguments: JSONValue) throws -> JSONValue {
        let cardId = try #require(authorizedCardId)
        try send([
            "type": "tool_call",
            "id": .string(UUID().uuidString),
            "name": .string(name),
            "cardId": .string(cardId),
            "arguments": arguments,
        ])
        return try #require(try readLine())
    }

    func send(_ value: JSONValue) throws {
        guard try sendObservingPeerClosure(value) else {
            throw BoardToolServerError.socketSetupFailed("peer closed socket")
        }
    }

    func sendRaw(_ raw: String) throws {
        guard try sendRawObservingPeerClosure(raw) else {
            throw BoardToolServerError.socketSetupFailed("peer closed socket")
        }
    }

    func sendObservingPeerClosure(_ value: JSONValue) throws -> Bool {
        try sendRawObservingPeerClosure(try value.encodedString())
    }

    func sendRawObservingPeerClosure(_ raw: String) throws -> Bool {
        var data = Data(raw.utf8)
        data.append(UInt8(ascii: "\n"))
        return try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return true }
            var offset = 0
            while offset < data.count {
                let written = Darwin.write(
                    fd,
                    base.advanced(by: offset),
                    data.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    if errno == EPIPE || errno == ECONNRESET
                        || errno == ENOTCONN
                    {
                        return false
                    }
                    throw BoardToolServerError.socketSetupFailed(
                        String(cString: strerror(errno))
                    )
                }
                offset += written
            }
            return true
        }
    }

    func readLine() throws -> JSONValue? {
        guard let raw = try readRawLine() else { return nil }
        return try JSONValue.decoded(from: raw)
    }

    func readRawLine() throws -> String? {
        var buffer = Data()
        var byte = UInt8()
        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { return nil }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw BoardSocketTestClientError.receiveTimedOut
                }
                if errno == ECONNRESET || errno == ENOTCONN { return nil }
                throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
            }
            if byte == UInt8(ascii: "\n") {
                guard let text = String(data: buffer, encoding: .utf8), !text.isEmpty else {
                    return nil
                }
                return text
            }
            buffer.append(byte)
        }
    }

    func close() {
        guard fd >= 0 else { return }
        let closingFD = fd
        fd = -1
        Self.close(closingFD, observer: lifecycleObserver)
    }

    private static func close(
        _ fd: Int32,
        observer:
            (@Sendable (BoardSocketTestClientLifecycleEvent) -> Void)?
    ) {
        let result = Darwin.close(fd)
        observer?(.closed(fd, result))
    }

    private static func connect(fd: Int32, path: String) throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw BoardToolServerError.socketPathTooLong(path)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.offset(of: \.sun_path)! + pathBytes.count)
        address.sun_len = UInt8(length)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(fd, sockaddrPointer, length)
            }
        }
        guard result == 0 else {
            throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
        }
    }
}
