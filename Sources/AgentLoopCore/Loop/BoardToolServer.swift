import Darwin
import Foundation
import Security

public enum BoardToolServerError: Error, Sendable, Equatable {
    case socketPathTooLong(String)
    case socketSetupFailed(String)
    case invalidFrame(String)
    case unauthorized
    case cardMismatch(expected: String, actual: String)
    case unknownTool(String)
}

public final class BoardToolServer: @unchecked Sendable {
    public let socketURL: URL
    public let token: String

    private let cardId: String
    private let executor: ToolExecutor
    private let toolDefs: [ToolDef]
    private let onTerminal: @Sendable (LoopOutcome) -> Void
    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var activeConnectionFD: Int32 = -1
    private var stopped = false
    private var terminalOutcome: LoopOutcome?

    public init(
        socketURL: URL,
        token: String = BoardToolServer.makeToken(),
        cardId: String,
        executor: ToolExecutor,
        toolDefs: [ToolDef],
        onTerminal: @escaping @Sendable (LoopOutcome) -> Void = { _ in }
    ) {
        self.socketURL = socketURL
        self.token = token
        self.cardId = cardId
        self.executor = executor
        self.toolDefs = toolDefs
        self.onTerminal = onTerminal
    }

    deinit {
        stop()
    }

    public static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func defaultSocketDirectory() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BoardToolServerError.socketSetupFailed("Application Support directory is unavailable")
        }
        let directory = base.appendingPathComponent("AgentLoop").appendingPathComponent("board-sockets")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return directory
    }

    public static func makeSocketURL(directory: URL? = nil) throws -> URL {
        let directory = try directory ?? defaultSocketDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let random = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
        return directory.appendingPathComponent("\(random).sock")
    }

    public static func makeExecutor(
        db: AppDatabase,
        cardId: String,
        runId: String,
        workspaceRoot: URL?,
        artifactStoreRoot: URL,
        campId: String?,
        toolAccess: ToolAccess,
        autonomy: MissionAutonomy
    ) -> (executor: ToolExecutor, toolDefs: [ToolDef]) {
        let board = BoardTools(
            db: db,
            cardId: cardId,
            runId: runId,
            workspaceRoot: workspaceRoot,
            artifactStoreRoot: artifactStoreRoot
        )
        var handlers: [String: any ToolHandler] = [
            "complete_card": BoardToolHandler(tools: board, op: .complete),
            "block_card": BoardToolHandler(tools: board, op: .block),
            "progress_note": BoardToolHandler(tools: board, op: .note),
            "ask_user": BoardToolHandler(tools: board, op: .askUser),
        ]
        var defs = [
            ToolDef.completeCard,
            ToolDef.blockCard,
            Self.progressNoteTool,
            ToolDef.askUser,
        ]
        if toolAccess.allows("search_camp_notes") {
            handlers["search_camp_notes"] = CampNotesSearchTool(db: db, campId: campId)
            defs.append(ToolDef.searchCampNotes)
        }
        let approvalJar = ApprovalTokenJar((try? db.approvalDecisions(cardId: cardId)) ?? [])
        for (name, handler) in handlers where ToolDef.risk(name) != .readOnly {
            handlers[name] = ApprovalGateHandler(
                inner: handler,
                toolName: name,
                autonomy: autonomy,
                jar: approvalJar,
                db: db,
                cardId: cardId,
                runId: runId
            )
        }
        return (ToolExecutor(handlers: handlers), defs)
    }

    public func start() throws {
        let path = socketURL.path
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BoardToolServerError.socketSetupFailed("socket: \(String(cString: strerror(errno)))")
        }
        do {
            try bindAndListen(fd: fd, path: path)
        } catch {
            close(fd)
            throw error
        }
        lock.lock()
        listenFD = fd
        stopped = false
        lock.unlock()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        let fds: (Int32, Int32) = {
            lock.lock()
            defer { lock.unlock() }
            guard !stopped else { return (-1, -1) }
            stopped = true
            let result = (listenFD, activeConnectionFD)
            listenFD = -1
            activeConnectionFD = -1
            return result
        }()
        if fds.0 >= 0 { close(fds.0) }
        if fds.1 >= 0 { close(fds.1) }
        try? FileManager.default.removeItem(at: socketURL)
    }

    public var terminalSnapshot: LoopOutcome? {
        lock.lock()
        defer { lock.unlock() }
        return terminalOutcome
    }

    private static let progressNoteTool = ToolDef(
        name: "progress_note",
        description: ToolDef.addProgressNote.description,
        inputSchema: ToolDef.addProgressNote.inputSchema
    )

    private func bindAndListen(fd: Int32, path: String) throws {
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
        try? FileManager.default.removeItem(atPath: path)
        let length = socklen_t(MemoryLayout<sockaddr_un>.offset(of: \.sun_path)! + pathBytes.count)
        address.sun_len = UInt8(length)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, length)
            }
        }
        guard bindResult == 0 else {
            throw BoardToolServerError.socketSetupFailed("bind \(path): \(String(cString: strerror(errno)))")
        }
        guard listen(fd, 1) == 0 else {
            throw BoardToolServerError.socketSetupFailed("listen \(path): \(String(cString: strerror(errno)))")
        }
    }

    private func acceptLoop() {
        while true {
            let fd = currentListenFD()
            guard fd >= 0 else { return }
            let connection = accept(fd, nil, nil)
            if connection < 0 {
                if isStopped() { return }
                continue
            }
            guard claimConnection(connection) else {
                close(connection)
                continue
            }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handle(connection: connection)
                self?.releaseConnection(connection)
            }
        }
    }

    private func handle(connection fd: Int32) {
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var authorized = false
        var buffer = Data()
        while true {
            // 不用 FileHandle.availableData:fd 被并发关闭时它抛 ObjC 异常直接炸进程;POSIX read 安静返回 -1/0
            guard let chunk = Self.readChunk(fd), !chunk.isEmpty else { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                guard let text = String(data: line, encoding: .utf8), !text.isEmpty else {
                    continue
                }
                guard processLine(text, authorized: &authorized, handle: handle) else {
                    return
                }
            }
        }
    }

    private static func readChunk(_ fd: Int32) -> Data? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let n = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, 4096) }
        guard n > 0 else { return nil }
        return Data(buffer[0..<n])
    }

    private func processLine(_ line: String, authorized: inout Bool, handle: FileHandle) -> Bool {
        guard let message = try? JSONValue.decoded(from: line),
              let object = message.objectValue else {
            writeResponse(handle: handle, id: nil, outcome: .error("invalid JSON frame"))
            return true
        }
        if !authorized {
            guard object["type"]?.stringValue == "hello",
                  object["token"]?.stringValue == token else {
                return false
            }
            if let actualCardId = object["cardId"]?.stringValue, actualCardId != cardId {
                return false
            }
            authorized = true
            writeRaw(handle: handle, ["type": "hello_ok"])
            return true
        }
        handleToolCall(object: object, handle: handle)
        return true
    }

    private func handleToolCall(object: [String: JSONValue], handle: FileHandle) {
        let id = object["id"]?.stringValue
        guard object["type"]?.stringValue == "tool_call",
              let name = object["name"]?.stringValue else {
            writeResponse(handle: handle, id: id, outcome: .error("invalid tool_call frame"))
            return
        }
        if let declaredCardId = object["cardId"]?.stringValue, declaredCardId != cardId {
            writeResponse(handle: handle, id: id, outcome: .error("tool call cardId mismatch"))
            return
        }
        guard toolDefs.contains(where: { $0.name == name }) else {
            writeResponse(handle: handle, id: id, outcome: .error("unknown board tool \(name)"))
            return
        }
        let arguments = object["arguments"] ?? .object([:])
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
        writeResponse(handle: handle, id: id, outcome: box.outcome ?? .error("tool call did not return"))
    }

    private func writeResponse(handle: FileHandle, id: String?, outcome: ToolOutcome) {
        var frame: [String: JSONValue] = [
            "type": "tool_result",
            "id": .string(id ?? ""),
        ]
        switch outcome {
        case .result(let text):
            frame["kind"] = "result"
            frame["text"] = .string(text)
            frame["isError"] = false
        case .error(let message):
            frame["kind"] = "error"
            frame["text"] = .string(message)
            frame["isError"] = true
        case .completed(let handoff):
            let loopOutcome = LoopOutcome.completed(handoff)
            setTerminal(loopOutcome)
            frame["kind"] = "completed"
            frame["text"] = .string("已完成")
            frame["isError"] = false
        case .blocked(let reason, let detail):
            let loopOutcome = LoopOutcome.blocked(reason: reason, detail: detail)
            setTerminal(loopOutcome)
            frame["kind"] = "blocked"
            frame["reason"] = .string(reason)
            frame["detail"] = .string(detail)
            frame["text"] = .string(detail.isEmpty ? reason : detail)
            frame["isError"] = false
        }
        writeRaw(handle: handle, .object(frame))
    }

    private func setTerminal(_ outcome: LoopOutcome) {
        lock.lock()
        terminalOutcome = outcome
        lock.unlock()
        onTerminal(outcome)
    }

    private func writeRaw(handle: FileHandle, _ value: JSONValue) {
        guard let encoded = try? value.encodedString() else { return }
        var data = Data(encoded.utf8)
        data.append(UInt8(ascii: "\n"))
        try? handle.write(contentsOf: data)
    }

    private func currentListenFD() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        return stopped ? -1 : listenFD
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
