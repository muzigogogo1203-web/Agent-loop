import Darwin
import Foundation

public enum BoardServerBridgeMain {
    public static func exitIfRequested(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard arguments.contains("--board-server") else { return }
        do {
            guard let socketPath = environment["AGENTLOOP_BOARD_SOCKET"],
                  let token = environment["AGENTLOOP_BOARD_TOKEN"] else {
                throw BoardToolServerError.invalidFrame("missing board socket environment")
            }
            let cardId = environment["AGENTLOOP_BOARD_CARD_ID"]
            let toolNames = Set(
                (environment["AGENTLOOP_BOARD_TOOLS"] ?? defaultToolNames.joined(separator: ","))
                    .split(separator: ",")
                    .map { String($0) }
            )
            let bridge = try BoardSocketBridgeClient(socketPath: socketPath, token: token, cardId: cardId)
            try run(bridge: bridge, toolNames: toolNames)
            Foundation.exit(0)
        } catch {
            FileHandle.standardError.write(Data("board-server failed: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static let defaultToolNames = [
        "complete_card",
        "block_card",
        "ask_user",
        "progress_note",
        "search_camp_notes",
    ]

    private static func run(bridge: BoardSocketBridgeClient, toolNames: Set<String>) throws {
        var buffer = Data()
        while true {
            let chunk = FileHandle.standardInput.availableData
            if chunk.isEmpty { return }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                guard let raw = String(data: line, encoding: .utf8), !raw.isEmpty else {
                    continue
                }
                if let response = try handle(raw: raw, bridge: bridge, toolNames: toolNames) {
                    writeStdout(response)
                }
            }
        }
    }

    private static func handle(
        raw: String,
        bridge: BoardSocketBridgeClient,
        toolNames: Set<String>
    ) throws -> JSONValue? {
        guard let message = try? JSONValue.decoded(from: raw),
              let method = message["method"]?.stringValue else {
            return rpcError(id: nil, code: -32700, message: "invalid JSON-RPC frame")
        }
        let id = message["id"]
        switch method {
        case "initialize":
            guard let id else { return nil }
            return [
                "jsonrpc": "2.0",
                "id": id,
                "result": [
                    "protocolVersion": "2025-06-18",
                    "capabilities": ["tools": [:]],
                    "serverInfo": ["name": "ranchboard", "version": "1.0"],
                ],
            ]
        case "notifications/initialized":
            return nil
        case "tools/list":
            guard let id else { return nil }
            return [
                "jsonrpc": "2.0",
                "id": id,
                "result": ["tools": .array(toolDefinitions(names: toolNames).map(toolInfo))],
            ]
        case "tools/call":
            guard let id else { return nil }
            guard let name = message["params"]?["name"]?.stringValue else {
                return rpcError(id: id, code: -32602, message: "tools/call missing name")
            }
            let arguments = message["params"]?["arguments"] ?? .object([:])
            let result = try bridge.callTool(name: name, arguments: arguments)
            return [
                "jsonrpc": "2.0",
                "id": id,
                "result": [
                    "content": [
                        [
                            "type": "text",
                            "text": .string(result.text),
                        ],
                    ],
                    "isError": .bool(result.isError),
                ],
            ]
        default:
            return rpcError(id: id, code: -32601, message: "method not supported by AgentLoop board bridge")
        }
    }

    private static func rpcError(id: JSONValue?, code: Int, message: String) -> JSONValue {
        [
            "jsonrpc": "2.0",
            "id": id ?? .null,
            "error": [
                "code": .number(Double(code)),
                "message": .string(message),
            ],
        ]
    }

    private static func toolDefinitions(names: Set<String>) -> [ToolDef] {
        let all = [
            ToolDef.completeCard,
            ToolDef.blockCard,
            ToolDef.askUser,
            ToolDef(name: "progress_note", description: ToolDef.addProgressNote.description, inputSchema: ToolDef.addProgressNote.inputSchema),
            ToolDef.searchCampNotes,
        ]
        return all.filter { names.contains($0.name) }
    }

    private static func toolInfo(_ def: ToolDef) -> JSONValue {
        [
            "name": .string(def.name),
            "description": .string(def.description),
            "inputSchema": def.inputSchema,
        ]
    }

    private static func writeStdout(_ value: JSONValue) {
        guard let encoded = try? value.encodedString() else { return }
        var data = Data(encoded.utf8)
        data.append(UInt8(ascii: "\n"))
        FileHandle.standardOutput.write(data)
    }
}

private struct BoardSocketBridgeClient {
    struct ToolResult {
        let text: String
        let isError: Bool
    }

    private let handle: FileHandle

    init(socketPath: String, token: String, cardId: String?) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
        }
        do {
            try Self.connect(fd: fd, path: socketPath)
        } catch {
            close(fd)
            throw error
        }
        handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var hello: [String: JSONValue] = [
            "type": "hello",
            "token": .string(token),
        ]
        if let cardId {
            hello["cardId"] = .string(cardId)
        }
        try write(.object(hello))
        guard let response = try read(),
              response["type"]?.stringValue == "hello_ok" else {
            throw BoardToolServerError.unauthorized
        }
    }

    func callTool(name: String, arguments: JSONValue) throws -> ToolResult {
        let id = UUID().uuidString
        try write([
            "type": "tool_call",
            "id": .string(id),
            "name": .string(name),
            "arguments": arguments,
        ])
        guard let response = try read(),
              response["type"]?.stringValue == "tool_result" else {
            throw BoardToolServerError.invalidFrame("missing tool_result")
        }
        return ToolResult(
            text: response["text"]?.stringValue ?? "",
            isError: response["isError"]?.boolValue ?? false
        )
    }

    private static func connect(fd: Int32, path: String) throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= capacity else {
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

    private func write(_ value: JSONValue) throws {
        var data = Data(try value.encodedString().utf8)
        data.append(UInt8(ascii: "\n"))
        try handle.write(contentsOf: data)
    }

    private func read() throws -> JSONValue? {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                guard let text = String(data: line, encoding: .utf8), !text.isEmpty else {
                    return nil
                }
                return try JSONValue.decoded(from: text)
            }
        }
    }
}
