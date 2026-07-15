import Darwin
import Foundation
import GRDB
import Testing
import AgentLoopCore

@Suite(.serialized) struct BoardServerTests {
    @Test func boardServerForwardsProgressSearchAndCompleteTools() async throws {
        let harness = try Self.makeBoardHarness(startServer: false)
        let note = await harness.executor.execute(name: "progress_note", input: ["text": "阶段一"])
        guard case .result = note else {
            Issue.record("expected progress_note result")
            return
        }
        let search = await harness.executor.execute(name: "search_camp_notes", input: ["query": "missing"])
        guard case .result = search else {
            Issue.record("expected search_camp_notes result")
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
        #expect(try harness.db.card(id: harness.cardId)?.status == .done)
    }

    @Test func boardServerFramingForwardsToolCallsWhenSocketsAreAllowed() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        let client = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try client.hello(token: harness.server.token, cardId: harness.cardId)

        let note = try client.call(name: "progress_note", arguments: ["text": "阶段一"])
        #expect(note["kind"]?.stringValue == "result")
        let search = try client.call(name: "search_camp_notes", arguments: ["query": "missing"])
        #expect(search["isError"]?.boolValue == false)

        let complete = try client.call(name: "complete_card", arguments: [
            "outcome": "ok",
            "summary": "done",
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])
        #expect(complete["kind"]?.stringValue == "completed")
        #expect(try harness.db.card(id: harness.cardId)?.status == .done)
        guard case .completed = harness.server.terminalSnapshot else {
            Issue.record("expected completed terminal outcome")
            return
        }
        client.close()
        harness.server.stop()
    }

    @Test func boardServerRejectsWrongTokenAndMismatchedCard() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        let wrongToken = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try wrongToken.send(["type": "hello", "token": "bad"])
        #expect(try wrongToken.readLine() == nil)
        wrongToken.close()

        let wrongCard = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try wrongCard.send(JSONValue.object(["type": "hello", "token": .string(harness.server.token), "cardId": "other-card"]))
        #expect(try wrongCard.readLine() == nil)
        wrongCard.close()
        harness.server.stop()
    }

    @Test func boardServerRejectsSecondConcurrentConnection() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
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
        harness.server.stop()
    }

    @Test func boardServerStopWhileConnectionIsActiveClosesExactlyOnce() throws {
        guard agentLoopCanBindListenerSocket() else { return }
        let harness = try Self.makeBoardHarness(startServer: true)
        let client = try BoardSocketTestClient(path: harness.server.socketURL.path)
        try client.hello(token: harness.server.token, cardId: harness.cardId)

        harness.server.stop()
        #expect(try client.readLine() == nil)
        client.close()
    }

    @Test func boardServerDefinitionsExposeFiveToolsWhenFullAccess() throws {
        let harness = try Self.makeBoardHarness(startServer: false)
        #expect(harness.toolNames == ["complete_card", "block_card", "progress_note", "ask_user", "search_camp_notes"])
        harness.server.stop()
    }

    private static func makeBoardHarness(startServer: Bool) throws -> (
        db: AppDatabase,
        cardId: String,
        server: BoardToolServer,
        executor: ToolExecutor,
        toolNames: [String]
    ) {
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
            .appendingPathComponent("t")
            .appendingPathComponent("b\(UUID().uuidString.prefix(8))")
        let workspace = base.appendingPathComponent("ws")
        let sockets = base.appendingPathComponent("s")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sockets, withIntermediateDirectories: true)
        let db = try AppDatabase(path: base.appendingPathComponent("test.sqlite").path)
        let ids = try db.createSingleCardMission(
            campName: "c",
            squadName: "s",
            goal: "g",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            assigneeId: nil,
            maxTurns: 5,
            workspacePath: workspace.path
        )
        let runId = UUID().uuidString
        try db.startRun(cardId: ids.cardId, runId: runId)
        let built = BoardToolServer.makeExecutor(
            db: db,
            cardId: ids.cardId,
            runId: runId,
            workspaceRoot: workspace,
            artifactStoreRoot: base.appendingPathComponent("artifacts"),
            campId: try db.squad(forCard: ids.cardId)?.campId,
            toolAccess: .full,
            autonomy: .standard
        )
        let server = BoardToolServer(
            socketURL: try BoardToolServer.makeSocketURL(directory: sockets),
            cardId: ids.cardId,
            executor: built.executor,
            toolDefs: built.toolDefs
        )
        if startServer {
            try server.start()
        }
        return (db, ids.cardId, server, built.executor, built.toolDefs.map(\.name))
    }
}

func agentLoopCanBindListenerSocket() -> Bool {
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build")
        .appendingPathComponent("t")
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
    private let fd: Int32

    init(path: String) throws {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
        }
        var noSIGPIPE: Int32 = 1
        guard setsockopt(
            fd,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSIGPIPE,
            socklen_t(MemoryLayout<Int32>.size)
        ) == 0 else {
            Darwin.close(fd)
            throw BoardToolServerError.socketSetupFailed("SO_NOSIGPIPE: \(String(cString: strerror(errno)))")
        }
        try Self.connect(fd: fd, path: path)
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }

    func hello(token: String, cardId: String) throws {
        try send(["type": "hello", "token": .string(token), "cardId": .string(cardId)])
        let response = try #require(try readLine())
        #expect(response["type"]?.stringValue == "hello_ok")
    }

    func call(name: String, arguments: JSONValue) throws -> JSONValue {
        try send([
            "type": "tool_call",
            "id": .string(UUID().uuidString),
            "name": .string(name),
            "arguments": arguments,
        ])
        return try #require(try readLine())
    }

    func send(_ value: JSONValue) throws {
        guard try sendObservingPeerClosure(value) else {
            throw BoardToolServerError.socketSetupFailed("peer closed socket")
        }
    }

    func sendObservingPeerClosure(_ value: JSONValue) throws -> Bool {
        var data = Data(try value.encodedString().utf8)
        data.append(UInt8(ascii: "\n"))
        return try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return true }
            let written = Darwin.write(fd, base, data.count)
            if written < 0 {
                if errno == EPIPE || errno == ECONNRESET || errno == ENOTCONN { return false }
                throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
            }
            return true
        }
    }

    func readLine() throws -> JSONValue? {
        var buffer = Data()
        var byte = UInt8()
        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { return nil }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK { return nil }
                if errno == ECONNRESET || errno == ENOTCONN { return nil }
                throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
            }
            if byte == UInt8(ascii: "\n") {
                guard let text = String(data: buffer, encoding: .utf8), !text.isEmpty else {
                    return nil
                }
                return try JSONValue.decoded(from: text)
            }
            buffer.append(byte)
        }
    }

    func close() {
        Darwin.close(fd)
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
