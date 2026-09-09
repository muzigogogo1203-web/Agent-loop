import Darwin
import CryptoKit
import Foundation
import Security

package typealias EngineBoardPeerValidateV1 =
    @Sendable (_ peerPid: Int32) throws -> Void

public enum BoardToolServerError: Error, Sendable, Equatable {
    case socketPathTooLong(String)
    case socketSetupFailed(String)
    case socketCollision
    case socketIdentityMismatch
    case socketCleanupFailed(String)
    case invalidFrame(String)
    case unauthorized
    case cardMismatch(expected: String, actual: String)
    case unknownTool(String)
}

public final class BoardToolServer: @unchecked Sendable {
    private struct SocketIdentity: Sendable, Equatable {
        let device: UInt64
        let inode: UInt64
        let uid: UInt32
    }

    private static let maximumFrameBytes = 256 * 1_024
    private static let boardDefinitions: [ToolDef] = [
        .completeCard,
        .blockCard,
        .addProgressNote,
        .askUser,
    ]
    private static let protocolError: JSONValue = [
        "code": "board_protocol_error",
        "type": "error",
    ]

    public let socketURL: URL
    public let token: String

    private let directoryAuthority: EngineBoardSocketDirectoryAuthorityV1
    private let socketBasename: String
    private let cardId: String
    private let executor: ToolExecutor
    private let toolDefs: [ToolDef]
    private let helloFrame: JSONValue
    private let boardTerminalSink: any EngineBoardTerminalSink
    private let progressSink: any EngineProgressSink
    private let validatePeer: EngineBoardPeerValidateV1
    private let onTerminalAccepted: @Sendable () -> Void
    private let acceptQueue: DispatchQueue?
    private let handlerQueue: DispatchQueue?
    private let diagnosticId = UUID()
    private let acceptGroup = DispatchGroup()
    private let handlerGroup = DispatchGroup()
    private let cleanupLock = NSLock()
    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var startInProgress = false
    private var acceptLoopOwnsListener = false
    private var activeConnectionFD: Int32 = -1
    private var stopped = false
    private var boundSocket = false
    private var boundSocketIdentity: SocketIdentity?
    private var socketCleanupComplete = false
    private var terminalIntentAccepted = false
    private var asyncFailure: BoardToolServerError?
    private var asyncStopInFlight = false
    private var asyncStopWaiters: [CheckedContinuation<Void, any Error>] = []

    package init(
        directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
        socketBasename: String,
        token: String,
        cardId: String,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        validatePeer: @escaping EngineBoardPeerValidateV1,
        onTerminalAccepted: @escaping @Sendable () -> Void,
        acceptQueue: DispatchQueue? = nil,
        handlerQueue: DispatchQueue? = nil
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        guard Self.isLowercaseHex(token, count: 64),
              Self.isCanonicalSocketBasename(socketBasename)
        else {
            throw BoardToolServerError.invalidFrame(
                "invalid Board server authority"
            )
        }
        let assembly = try Self.makeExecutor(
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink,
            boundCapabilityTools: boundCapabilityTools
        )
        self.directoryAuthority = directoryAuthority
        self.socketBasename = socketBasename
        socketURL = directoryAuthority.directoryURL.appendingPathComponent(
            socketBasename,
            isDirectory: false
        )
        self.token = token
        self.cardId = cardId
        executor = assembly.executor
        toolDefs = assembly.toolDefs
        helloFrame = Self.makeHelloFrame(assembly.toolDefs)
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
        self.validatePeer = validatePeer
        self.onTerminalAccepted = onTerminalAccepted
        self.acceptQueue = acceptQueue
        self.handlerQueue = handlerQueue
    }

    deinit {
        signalStop()
    }

    public static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    package static func makeSocketURL(
        directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
        executionId: String
    ) throws -> URL {
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        let digest = SHA256.hash(data: Data(executionId.utf8))
        let prefix = digest.prefix(8).map {
            String(format: "%02x", $0)
        }.joined()
        return directoryAuthority.directoryURL.appendingPathComponent(
            "s-\(prefix).sock",
            isDirectory: false
        )
    }

    package static func makeExecutor(
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> (executor: ToolExecutor, toolDefs: [ToolDef]) {
        let board = BoardTools(
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink
        )
        let handlers: [String: any ToolHandler] = [
            "complete_card": BoardToolHandler(tools: board, op: .complete),
            "block_card": BoardToolHandler(tools: board, op: .block),
            "add_progress_note": BoardToolHandler(tools: board, op: .note),
            "ask_user": BoardToolHandler(tools: board, op: .askUser),
        ]
        return (
            ToolExecutor(handlers: handlers),
            boardDefinitions
        )
    }

    private static func makeExecutor(
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        boundCapabilityTools: EngineBoundCapabilityToolsV1
    ) throws -> (executor: ToolExecutor, toolDefs: [ToolDef]) {
        let logicalDefinitions = boundCapabilityTools.logicalDefinitions
        let capabilityTools = boundCapabilityTools.capabilityTools
        guard logicalDefinitions.count >= boardDefinitions.count,
              Array(logicalDefinitions.prefix(boardDefinitions.count))
                == boardDefinitions,
              Array(logicalDefinitions.dropFirst(boardDefinitions.count))
                == capabilityTools.map(\.def),
              logicalDefinitions.count <= 256
        else {
            throw BoardToolServerError.invalidFrame(
                "invalid Board tool authority"
            )
        }
        var seen = Set<String>()
        for definition in logicalDefinitions {
            do {
                try EngineContractValidationV1.validateToolName(
                    definition.name
                )
                try CanonicalContractCodingV1.validateNonempty(
                    definition.description
                )
            } catch {
                throw BoardToolServerError.invalidFrame(
                    "invalid Board tool definition"
                )
            }
            guard definition.inputSchema.objectValue != nil,
                  seen.insert(definition.name).inserted
            else {
                throw BoardToolServerError.invalidFrame(
                    "invalid Board tool definition"
                )
            }
        }
        let sortedDefinitions = logicalDefinitions.sorted {
            $0.name.utf8.lexicographicallyPrecedes($1.name.utf8)
        }
        let hello = makeHelloFrame(sortedDefinitions)
        guard (try hello.encodedString()).utf8.count + 1
                <= maximumFrameBytes
        else {
            throw BoardToolServerError.invalidFrame(
                "Board tool definition frame is too large"
            )
        }
        let board = makeExecutor(
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink
        )
        var handlers = board.executor.handlers
        for tool in capabilityTools {
            handlers[tool.def.name] = tool.handler
        }
        return (
            ToolExecutor(handlers: handlers),
            logicalDefinitions
        )
    }

    private static func toolJSON(_ definition: ToolDef) -> JSONValue {
        [
            "description": .string(definition.description),
            "inputSchema": definition.inputSchema,
            "name": .string(definition.name),
        ]
    }

    private static func makeHelloFrame(
        _ definitions: [ToolDef]
    ) -> JSONValue {
        let sorted = definitions.sorted {
            $0.name.utf8.lexicographicallyPrecedes($1.name.utf8)
        }
        return [
            "tools": .array(sorted.map(toolJSON)),
            "type": "hello_ok",
        ]
    }

    package static func isCanonicalSocketBasename(_ value: String) -> Bool {
        guard value.utf8.count == 23,
              value.hasPrefix("s-"),
              value.hasSuffix(".sock")
        else { return false }
        return isLowercaseHex(
            String(value.dropFirst(2).dropLast(5)),
            count: 16
        )
    }

    private static func isLowercaseHex(
        _ value: String,
        count: Int
    ) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                    .contains(byte)
        }
    }

    public func start() throws {
        let reserved = lock.withLock { () -> Bool in
            guard !startInProgress,
                  listenFD < 0,
                  !acceptLoopOwnsListener
            else { return false }
            startInProgress = true
            return true
        }
        guard reserved else {
            throw BoardToolServerError.socketSetupFailed(
                "board server already started"
            )
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            lock.withLock { startInProgress = false }
            throw BoardToolServerError.socketSetupFailed("socket: \(String(cString: strerror(errno)))")
        }
        let identity: SocketIdentity
        do {
            identity = try bindAndListen(fd: fd)
        } catch {
            lock.withLock { startInProgress = false }
            guard Darwin.close(fd) == 0 else {
                throw BoardToolServerError.socketCleanupFailed(
                    "listener close failed"
                )
            }
            throw error
        }
        let installed = lock.withLock { () -> Bool in
            defer { startInProgress = false }
            guard listenFD < 0, !acceptLoopOwnsListener else {
                return false
            }
            listenFD = fd
            stopped = false
            boundSocket = true
            boundSocketIdentity = identity
            socketCleanupComplete = false
            asyncFailure = nil
            return true
        }
        guard installed else {
            guard Darwin.close(fd) == 0 else {
                throw BoardToolServerError.socketCleanupFailed(
                    "listener close failed"
                )
            }
            throw BoardToolServerError.socketSetupFailed(
                "board server already started"
            )
        }

        let group = acceptGroup
        let diagnosticId = diagnosticId
        group.enter()
        RuntimeLifecycleDiagnostics.event(
            .boardAcceptQueued,
            owner: diagnosticId
        )
        Self.scheduleWorker(on: acceptQueue, name: "AgentLoop.board.accept") {
            [weak self, group, diagnosticId] in
            RuntimeLifecycleDiagnostics.event(
                .boardAcceptStarted,
                owner: diagnosticId
            )
            defer {
                RuntimeLifecycleDiagnostics.event(
                    .boardAcceptFinished,
                    owner: diagnosticId
                )
                group.leave()
            }
            self?.acceptLoop(claiming: fd)
        }
    }

    private static func scheduleWorker(
        on queue: DispatchQueue?,
        name: String,
        work: @escaping @Sendable () -> Void
    ) {
        if let queue {
            queue.async(execute: work)
        } else {
            let worker = Thread(block: work)
            worker.name = name
            worker.qualityOfService = .utility
            worker.start()
        }
    }

    package func stopAsync() async throws {
        // Cancellation of an awaiting caller never abandons owned cleanup.
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let shouldStart = lock.withLock {
                asyncStopWaiters.append(continuation)
                guard !asyncStopInFlight else { return false }
                asyncStopInFlight = true
                return true
            }
            guard shouldStart else { return }
            Self.scheduleWorker(on: nil, name: "AgentLoop.board.stop") { [self] in
                let result: Result<Void, any Error>
                do {
                    try stop()
                    result = .success(())
                } catch {
                    result = .failure(error)
                }
                let waiters = lock.withLock {
                    let waiters = asyncStopWaiters
                    asyncStopWaiters.removeAll()
                    asyncStopInFlight = false
                    return waiters
                }
                // Reset before resuming so a later caller can retry checked cleanup.
                for waiter in waiters { waiter.resume(with: result) }
            }
        }
    }

    package func stop() throws {
        RuntimeLifecycleDiagnostics.event(
            .boardStopStarted,
            owner: diagnosticId
        )
        signalStop()
        acceptGroup.wait()
        RuntimeLifecycleDiagnostics.event(
            .boardAcceptJoined,
            owner: diagnosticId
        )
        handlerGroup.wait()
        RuntimeLifecycleDiagnostics.event(
            .boardHandlersJoined,
            owner: diagnosticId
        )
        var firstError: (any Error)? = lock.withLock { asyncFailure }
        do {
            try unlinkOwnedSocket()
        } catch {
            if firstError == nil { firstError = error }
        }
        if let firstError { throw firstError }
    }

    private func signalStop() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        // 活动连接由 handle() 的 FileHandle 唯一拥有。这里只 shutdown 以唤醒 read；
        // listener 若已移交给 acceptLoop，则由自连唤醒后由 acceptLoop 唯一关闭。
        let connection = activeConnectionFD
        let connectionShutdownFailed = connection >= 0
            && shutdown(connection, SHUT_RDWR) != 0
            && errno != ENOTCONN
        let ownsTransferred = acceptLoopOwnsListener
        var listenerToClose: Int32 = -1
        if !ownsTransferred {
            listenerToClose = listenFD
            listenFD = -1
        }
        lock.unlock()

        if connectionShutdownFailed {
            recordAsyncFailure(
                .socketCleanupFailed("active connection shutdown failed")
            )
        }
        if ownsTransferred {
            if let failure = Self.wakeAcceptLoop(socketPath: socketURL.path) {
                recordAsyncFailure(failure)
            }
        } else if listenerToClose >= 0 {
            guard Darwin.close(listenerToClose) == 0 else {
                recordAsyncFailure(
                    .socketCleanupFailed("listener close failed")
                )
                return
            }
        }
    }

    private func bindAndListen(fd: Int32) throws -> SocketIdentity {
        let lease = try directoryAuthority.makeDescriptorLease()
        let parent = lease.fileDescriptor
        var capturedIdentity: SocketIdentity?
        do {
            try validateDirectory(parent)
            var existing = stat()
            let existingResult = socketBasename.withCString {
                Darwin.fstatat(parent, $0, &existing, AT_SYMLINK_NOFOLLOW)
            }
            guard existingResult != 0 else {
                throw BoardToolServerError.socketCollision
            }
            guard errno == ENOENT else {
                throw BoardToolServerError.socketSetupFailed(
                    "socket basename inspection failed"
                )
            }

            let path = socketURL.path
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = Array(path.utf8) + [0]
            let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
            guard pathBytes.count <= pathCapacity else {
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
            let bindResult = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(
                    to: sockaddr.self,
                    capacity: 1
                ) { sockaddrPointer in
                    Darwin.bind(fd, sockaddrPointer, length)
                }
            }
            guard bindResult == 0 else {
                if errno == EADDRINUSE {
                    throw BoardToolServerError.socketCollision
                }
                throw BoardToolServerError.socketSetupFailed(
                    "bind \(path): \(String(cString: strerror(errno)))"
                )
            }
            try validateDirectory(parent)
            var socketInfo = stat()
            guard socketBasename.withCString({
                Darwin.fstatat(
                    parent,
                    $0,
                    &socketInfo,
                    AT_SYMLINK_NOFOLLOW
                )
            }) == 0,
                socketInfo.st_mode & S_IFMT == S_IFSOCK,
                socketInfo.st_uid == getuid()
            else {
                throw BoardToolServerError.socketIdentityMismatch
            }
            let identity = SocketIdentity(
                device: UInt64(socketInfo.st_dev),
                inode: UInt64(socketInfo.st_ino),
                uid: UInt32(socketInfo.st_uid)
            )
            capturedIdentity = identity
            guard listen(fd, 1) == 0 else {
                throw BoardToolServerError.socketSetupFailed(
                    "listen \(path): \(String(cString: strerror(errno)))"
                )
            }
            try lease.close()
            return identity
        } catch {
            let primary = error
            if let capturedIdentity {
                do {
                    try unlinkSocket(
                        parent: parent,
                        expected: capturedIdentity
                    )
                } catch {
                    let cleanupFailure = error
                    do {
                        try lease.close()
                    } catch {
                        throw BoardToolServerError.socketCleanupFailed(
                            "directory lease close failed"
                        )
                    }
                    throw cleanupFailure
                }
            }
            do {
                try lease.close()
            } catch {
                throw BoardToolServerError.socketCleanupFailed(
                    "directory lease close failed"
                )
            }
            throw primary
        }
    }

    private func validateDirectory(_ descriptor: Int32) throws {
        var descriptorInfo = stat()
        var pathInfo = stat()
        guard Darwin.fstat(descriptor, &descriptorInfo) == 0,
              directoryAuthority.directoryURL.path.withCString({
                  Darwin.lstat($0, &pathInfo)
              }) == 0,
              descriptorInfo.st_mode & S_IFMT == S_IFDIR,
              pathInfo.st_mode & S_IFMT == S_IFDIR,
              UInt64(descriptorInfo.st_dev) == directoryAuthority.device,
              UInt64(descriptorInfo.st_ino) == directoryAuthority.inode,
              UInt32(descriptorInfo.st_uid) == directoryAuthority.uid,
              UInt16(descriptorInfo.st_mode & mode_t(0o777))
                == directoryAuthority.mode,
              descriptorInfo.st_dev == pathInfo.st_dev,
              descriptorInfo.st_ino == pathInfo.st_ino,
              descriptorInfo.st_uid == pathInfo.st_uid,
              descriptorInfo.st_mode == pathInfo.st_mode
        else {
            throw BoardToolServerError.socketIdentityMismatch
        }
    }

    private func acceptLoop(claiming expectedFD: Int32) {
        let diagnosticId = diagnosticId
        // 锁内校验自己 start 时捕获的 fd 仍是当前 listener 且无人认领，防止 stop→start 后
        // 滞留的旧 block 抢占新 listener。不匹配时对应 fd 已被 stop()/其 owner 关闭，直接退出。
        lock.lock()
        guard !stopped, listenFD == expectedFD, !acceptLoopOwnsListener else {
            lock.unlock()
            return
        }
        let fd = expectedFD
        acceptLoopOwnsListener = true
        lock.unlock()

        while !isStopped() {
            let connection = accept(fd, nil, nil)
            if connection < 0 {
                if isStopped() { break }
                if errno == EINTR { continue }
                recordAsyncFailure(
                    .socketSetupFailed("Board accept failed")
                )
                break
            }
            RuntimeLifecycleDiagnostics.event(
                .boardConnectionAccepted,
                owner: diagnosticId
            )
            if isStopped() {
                closeConnection(connection)
                break
            }
            guard PosixSockets.disableSIGPIPE(connection) else {
                closeConnection(connection)
                continue
            }
            do {
                try validateAcceptedPeer(connection)
            } catch {
                closeConnection(connection)
                continue
            }
            guard claimConnection(connection) else {
                closeConnection(connection)
                continue
            }
            let group = handlerGroup
            group.enter()
            RuntimeLifecycleDiagnostics.event(
                .boardHandlerQueued,
                owner: diagnosticId
            )
            Self.scheduleWorker(on: handlerQueue, name: "AgentLoop.board.handler") {
                [self, group, diagnosticId] in
                RuntimeLifecycleDiagnostics.event(
                    .boardHandlerStarted,
                    owner: diagnosticId
                )
                defer {
                    RuntimeLifecycleDiagnostics.event(
                        .boardHandlerFinished,
                        owner: diagnosticId
                    )
                    group.leave()
                }
                handle(connection: connection)
            }
        }

        if Darwin.close(fd) != 0 {
            recordAsyncFailure(
                .socketCleanupFailed("listener close failed")
            )
        }
        lock.lock()
        if listenFD == fd { listenFD = -1 }
        acceptLoopOwnsListener = false
        lock.unlock()
    }

    private func handle(connection fd: Int32) {
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer {
            // 先从共享状态解绑，再由唯一 owner 关闭，避免 stop() 命中已复用的 fd。
            releaseConnection(fd)
            do {
                try handle.close()
            } catch {
                recordAsyncFailure(
                    .socketCleanupFailed("connection close failed")
                )
            }
        }
        var authorized = false
        var buffer = Data()
        while true {
            // 不用 FileHandle.availableData:fd 被并发关闭时它抛 ObjC 异常直接炸进程;POSIX read 安静返回 -1/0
            let chunk: Data
            do {
                guard let value = try Self.readChunk(fd), !value.isEmpty else {
                    break
                }
                chunk = value
            } catch {
                if !isStopped() {
                    recordAsyncFailure(
                        .socketSetupFailed("Board connection read failed")
                    )
                }
                break
            }
            buffer.append(chunk)
            if buffer.count > Self.maximumFrameBytes,
               !buffer.contains(UInt8(ascii: "\n"))
            {
                writeProtocolErrorRecordingFailure(handle: handle)
                return
            }
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                guard line.count + 1 <= Self.maximumFrameBytes,
                      let text = String(data: line, encoding: .utf8),
                      !text.isEmpty
                else {
                    writeProtocolErrorRecordingFailure(handle: handle)
                    return
                }
                do {
                    guard try processLine(
                        text,
                        authorized: &authorized,
                        handle: handle
                    ) else {
                        return
                    }
                } catch {
                    if !isStopped() {
                        recordAsyncFailure(
                            .socketSetupFailed(
                                "Board protocol response failed"
                            )
                        )
                    }
                    return
                }
            }
        }
    }

    private static func readChunk(_ fd: Int32) throws -> Data? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(fd, $0.baseAddress, $0.count)
            }
            if count > 0 { return Data(buffer[0..<count]) }
            if count == 0 { return nil }
            if errno == EINTR { continue }
            throw BoardToolServerError.socketSetupFailed(
                "Board connection read failed"
            )
        }
    }

    private func processLine(
        _ line: String,
        authorized: inout Bool,
        handle: FileHandle
    ) throws -> Bool {
        let message: JSONValue
        do {
            message = try JSONValue.decoded(from: line)
        } catch {
            try writeProtocolError(handle: handle)
            return false
        }
        guard let object = message.objectValue,
              try message.encodedString() == line
        else {
            try writeProtocolError(handle: handle)
            return false
        }
        if !authorized {
            guard Set(object.keys) == Set(["cardId", "token", "type"]),
                  object["type"]?.stringValue == "hello",
                  object["token"]?.stringValue == token,
                  object["cardId"]?.stringValue == cardId else {
                try writeProtocolError(handle: handle)
                return false
            }
            authorized = true
            try writeRaw(handle: handle, helloFrame)
            return true
        }
        return try handleToolCall(object: object, handle: handle)
    }

    private func handleToolCall(
        object: [String: JSONValue],
        handle: FileHandle
    ) throws -> Bool {
        guard Set(object.keys)
                == Set(["arguments", "cardId", "id", "name", "type"]),
              object["type"]?.stringValue == "tool_call",
              let id = object["id"]?.stringValue,
              !id.isEmpty,
              let name = object["name"]?.stringValue,
              let arguments = object["arguments"]
        else {
            try writeProtocolError(handle: handle)
            return false
        }
        if object["cardId"]?.stringValue != cardId {
            try writeProtocolError(handle: handle)
            return false
        }
        guard toolDefs.contains(where: { $0.name == name }) else {
            try writeProtocolError(handle: handle)
            return false
        }
        if Self.isTerminalTool(name), hasAcceptedTerminalIntent() {
            try writeResponse(
                handle: handle,
                id: id,
                outcome: .error("Board intent rejected.")
            )
            return true
        }
        let semaphore = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable {
            var outcome: ToolOutcome?
        }
        let box = Box()
        Task {
            box.outcome = await executor.execute(name: name, input: arguments)
            semaphore.signal()
        }
        semaphore.wait()
        var outcome = box.outcome ?? .error("tool call did not return")
        if !Self.isTerminalTool(name) {
            switch outcome {
            case .completed, .blocked:
                outcome = .error("Board intent rejected.")
            case .result, .error:
                break
            }
        }
        try writeResponse(
            handle: handle,
            id: id,
            outcome: outcome
        )
        return true
    }

    private func writeProtocolError(handle: FileHandle) throws {
        try writeRaw(handle: handle, Self.protocolError)
    }

    private func writeProtocolErrorRecordingFailure(handle: FileHandle) {
        do {
            try writeProtocolError(handle: handle)
        } catch {
            if !isStopped() {
                recordAsyncFailure(
                    .socketSetupFailed("Board protocol response failed")
                )
            }
        }
    }

    private func writeResponse(
        handle: FileHandle,
        id: String?,
        outcome: ToolOutcome
    ) throws {
        var frame: [String: JSONValue] = [
            "type": "tool_result",
            "id": .string(id ?? ""),
        ]
        var accepted = false
        switch outcome {
        case .result(let text):
            frame["kind"] = "result"
            frame["text"] = .string(text)
            frame["isError"] = false
        case .error(let message):
            frame["kind"] = "error"
            frame["text"] = .string(message)
            frame["isError"] = true
        case .completed:
            guard recordAcceptedTerminal() else {
                frame["kind"] = "error"
                frame["text"] = "Board intent rejected."
                frame["isError"] = true
                try writeRaw(handle: handle, .object(frame))
                return
            }
            accepted = true
            frame["kind"] = "completed"
            frame["text"] = .string("Card completed.")
            frame["isError"] = false
        case .blocked(let reason, let detail):
            guard recordAcceptedTerminal() else {
                frame["kind"] = "error"
                frame["text"] = "Board intent rejected."
                frame["isError"] = true
                try writeRaw(handle: handle, .object(frame))
                return
            }
            accepted = true
            frame["kind"] = "blocked"
            frame["reason"] = .string(reason)
            frame["detail"] = .string(detail)
            frame["text"] = .string(detail.isEmpty ? reason : detail)
            frame["isError"] = false
        }
        defer {
            if accepted {
                onTerminalAccepted()
            }
        }
        try writeRaw(handle: handle, .object(frame))
    }

    private func recordAcceptedTerminal() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !terminalIntentAccepted else { return false }
        terminalIntentAccepted = true
        return true
    }

    private func hasAcceptedTerminalIntent() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminalIntentAccepted
    }

    private static func isTerminalTool(_ name: String) -> Bool {
        name == "complete_card" || name == "block_card"
    }

    private func unlinkOwnedSocket() throws {
        cleanupLock.lock()
        defer { cleanupLock.unlock() }

        let identity = lock.withLock { () -> SocketIdentity? in
            guard boundSocket, !socketCleanupComplete else { return nil }
            return boundSocketIdentity
        }
        guard let identity else { return }

        let lease = try directoryAuthority.makeDescriptorLease()
        let parent = lease.fileDescriptor
        do {
            try validateDirectory(parent)
            try unlinkSocket(parent: parent, expected: identity)
            try lease.close()
        } catch {
            let primary = error
            do {
                try lease.close()
            } catch is EngineRuntimeAuthorityErrorV1 {
                if !(primary is EngineRuntimeAuthorityErrorV1) {
                    throw BoardToolServerError.socketCleanupFailed(
                        "directory lease close failed"
                    )
                }
            }
            throw primary
        }

        lock.withLock {
            socketCleanupComplete = true
            boundSocket = false
            boundSocketIdentity = nil
        }
    }

    private func unlinkSocket(
        parent: Int32,
        expected: SocketIdentity
    ) throws {
        var information = stat()
        guard socketBasename.withCString({
            Darwin.fstatat(
                parent,
                $0,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }) == 0,
            information.st_mode & S_IFMT == S_IFSOCK,
            UInt64(information.st_dev) == expected.device,
            UInt64(information.st_ino) == expected.inode,
            UInt32(information.st_uid) == expected.uid,
            information.st_uid == getuid()
        else {
            throw BoardToolServerError.socketIdentityMismatch
        }
        guard socketBasename.withCString({
            Darwin.unlinkat(parent, $0, 0)
        }) == 0,
            Darwin.fsync(parent) == 0
        else {
            throw BoardToolServerError.socketCleanupFailed(
                "socket unlink or parent fsync failed"
            )
        }
    }

    private func writeRaw(handle: FileHandle, _ value: JSONValue) throws {
        let encoded = try value.encodedString()
        var data = Data(encoded.utf8)
        data.append(UInt8(ascii: "\n"))
        guard data.count <= Self.maximumFrameBytes else {
            throw BoardToolServerError.invalidFrame(
                "Board frame is too large"
            )
        }
        try handle.write(contentsOf: data)
    }

    private static func wakeAcceptLoop(
        socketPath: String
    ) -> BoardToolServerError? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            return .socketSetupFailed("accept wake socket failed")
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path)
        else {
            guard Darwin.close(fd) == 0 else {
                return .socketCleanupFailed("accept wake close failed")
            }
            return .socketPathTooLong(socketPath)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
        }
        let length = socklen_t(
            MemoryLayout<sockaddr_un>.offset(of: \.sun_path)!
                + pathBytes.count
        )
        address.sun_len = UInt8(length)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(fd, sockaddrPointer, length)
            }
        }
        let connectionError = errno
        guard Darwin.close(fd) == 0 else {
            return .socketCleanupFailed("accept wake close failed")
        }
        guard connected == 0
                || connectionError == ECONNREFUSED
                || connectionError == ENOENT
        else {
            return .socketSetupFailed("accept wake connect failed")
        }
        return nil
    }

    private func validateAcceptedPeer(_ descriptor: Int32) throws {
        var peerPID: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        guard Darwin.getsockopt(
            descriptor,
            SOL_LOCAL,
            LOCAL_PEERPID,
            &peerPID,
            &length
        ) == 0,
            length == socklen_t(MemoryLayout<pid_t>.size),
            peerPID > 0
        else {
            throw BoardToolServerError.unauthorized
        }
        try validatePeer(peerPID)
    }

    private func closeConnection(_ descriptor: Int32) {
        if Darwin.close(descriptor) != 0 {
            recordAsyncFailure(
                .socketCleanupFailed("connection close failed")
            )
        }
    }

    private func recordAsyncFailure(_ failure: BoardToolServerError) {
        lock.withLock {
            if asyncFailure == nil { asyncFailure = failure }
        }
    }

    private func isStopped() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func claimConnection(_ fd: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped, activeConnectionFD < 0 else { return false }
        activeConnectionFD = fd
        return true
    }

    private func releaseConnection(_ fd: Int32) {
        lock.lock()
        if activeConnectionFD == fd {
            activeConnectionFD = -1
        }
        lock.unlock()
    }
}
