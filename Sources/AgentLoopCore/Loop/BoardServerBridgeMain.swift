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
                  let token = environment["AGENTLOOP_BOARD_TOKEN"],
                  let cardId = environment["AGENTLOOP_BOARD_CARD_ID"] else {
                throw BoardToolServerError.invalidFrame("missing board socket environment")
            }
            let bridge = try BoardSocketBridgeClient(
                socketPath: socketPath,
                token: token,
                cardId: cardId
            )
            do {
                try run(bridge: bridge)
            } catch {
                let primary = error
                do {
                    try bridge.close()
                } catch {
                    throw BoardToolServerError.socketSetupFailed(
                        "board bridge close failed"
                    )
                }
                throw primary
            }
            try bridge.close()
            Foundation.exit(0)
        } catch {
            FileHandle.standardError.write(Data("board-server failed\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func run(bridge: BoardSocketBridgeClient) throws {
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
                if let response = try handle(raw: raw, bridge: bridge) {
                    try writeStdout(response)
                }
            }
        }
    }

    private static func handle(
        raw: String,
        bridge: BoardSocketBridgeClient
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
                "result": [
                    "tools": .array(bridge.definitions.map(toolInfo)),
                ],
            ]
        case "tools/call":
            guard let id else { return nil }
            guard let name = message["params"]?["name"]?.stringValue else {
                return rpcError(id: id, code: -32602, message: "tools/call missing name")
            }
            guard bridge.contains(name: name) else {
                return rpcError(
                    id: id,
                    code: -32602,
                    message: "tools/call name is not listed"
                )
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

    package static func processJSONRPCFrameForTesting(
        raw: String,
        socketPath: String,
        token: String,
        cardId: String
    ) throws -> JSONValue? {
        let bridge = try BoardSocketBridgeClient(
            socketPath: socketPath,
            token: token,
            cardId: cardId
        )
        let response: JSONValue?
        do {
            response = try handle(raw: raw, bridge: bridge)
        } catch {
            let primary = error
            do {
                try bridge.close()
            } catch {
                throw BoardToolServerError.socketSetupFailed(
                    "board bridge close failed"
                )
            }
            throw primary
        }
        do {
            try bridge.close()
        } catch {
            throw BoardToolServerError.socketSetupFailed(
                "board bridge close failed"
            )
        }
        return response
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

    private static func toolInfo(_ def: ToolDef) -> JSONValue {
        [
            "name": .string(def.name),
            "description": .string(def.description),
            "inputSchema": def.inputSchema,
        ]
    }

    private static func writeStdout(_ value: JSONValue) throws {
        let encoded = try value.encodedString()
        var data = Data(encoded.utf8)
        data.append(UInt8(ascii: "\n"))
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}

private final class BoardSocketBridgeClient {
    struct ToolResult {
        let text: String
        let isError: Bool
    }

    private static let maximumFrameBytes = 256 * 1_024
    private let handle: FileHandle
    private let cardId: String
    private(set) var definitions: [ToolDef] = []
    private var listedNames = Set<String>()
    private var readBuffer = Data()
    private var closed = false

    init(socketPath: String, token: String, cardId: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        var resolvedPathBytes = [CChar](
            repeating: 0,
            count: Int(MAXPATHLEN)
        )
        let resolvedPathResult = socketPath.withCString {
            Darwin.realpath($0, &resolvedPathBytes)
        }
        guard socketPath.hasPrefix("/"),
              !socketPath.utf8.contains(0),
              resolvedPathResult != nil,
              String(
                  decoding: resolvedPathBytes.prefix { $0 != 0 }
                      .map { UInt8(bitPattern: $0) },
                  as: UTF8.self
              ) == socketPath,
              Self.isLowercaseHex(token, count: 64)
        else {
            throw BoardToolServerError.invalidFrame(
                "invalid board socket environment"
            )
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BoardToolServerError.socketSetupFailed(String(cString: strerror(errno)))
        }
        do {
            guard PosixSockets.disableSIGPIPE(fd) else {
                throw BoardToolServerError.socketSetupFailed("SO_NOSIGPIPE: \(String(cString: strerror(errno)))")
            }
            try Self.connect(fd: fd, path: socketPath)
        } catch {
            guard Darwin.close(fd) == 0 else {
                throw BoardToolServerError.socketSetupFailed(
                    "board bridge socket close failed"
                )
            }
            throw error
        }
        handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        self.cardId = cardId
        do {
            try write([
                "cardId": .string(cardId),
                "token": .string(token),
                "type": "hello",
            ])
            guard let response = try readCanonicalFrame() else {
                throw BoardToolServerError.unauthorized
            }
            definitions = try Self.validateHello(response)
            listedNames = Set(definitions.map(\.name))
        } catch {
            let primary = error
            do {
                try close()
            } catch {
                throw BoardToolServerError.socketSetupFailed(
                    "board bridge socket close failed"
                )
            }
            throw primary
        }
    }

    func contains(name: String) -> Bool {
        listedNames.contains(name)
    }

    func callTool(name: String, arguments: JSONValue) throws -> ToolResult {
        guard listedNames.contains(name) else {
            throw BoardToolServerError.unknownTool(name)
        }
        let id = UUID().uuidString
        try write([
            "arguments": arguments,
            "cardId": .string(cardId),
            "id": .string(id),
            "name": .string(name),
            "type": "tool_call",
        ])
        guard let response = try readCanonicalFrame(),
              let object = response.objectValue,
              object["type"]?.stringValue == "tool_result",
              object["id"]?.stringValue == id,
              object["kind"]?.stringValue != nil,
              let text = object["text"]?.stringValue,
              let isError = object["isError"]?.boolValue,
              Set(object.keys).isSubset(of: Set([
                  "detail", "id", "isError", "kind", "reason", "text",
                  "type",
              ]))
        else {
            throw BoardToolServerError.invalidFrame("missing tool_result")
        }
        return ToolResult(
            text: text,
            isError: isError
        )
    }

    func close() throws {
        guard !closed else { return }
        try handle.close()
        closed = true
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
        guard data.count <= Self.maximumFrameBytes else {
            throw BoardToolServerError.invalidFrame(
                "board bridge frame is too large"
            )
        }
        try handle.write(contentsOf: data)
    }

    private func readCanonicalFrame() throws -> JSONValue? {
        while true {
            if let newline = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = readBuffer[..<newline]
                readBuffer.removeSubrange(readBuffer.startIndex...newline)
                guard line.count + 1 <= Self.maximumFrameBytes,
                      let text = String(data: line, encoding: .utf8),
                      !text.isEmpty
                else {
                    throw BoardToolServerError.invalidFrame(
                        "invalid board parent frame"
                    )
                }
                let value = try JSONValue.decoded(from: text)
                guard try value.encodedString() == text else {
                    throw BoardToolServerError.invalidFrame(
                        "noncanonical board parent frame"
                    )
                }
                return value
            }
            let chunk = handle.availableData
            if chunk.isEmpty { return nil }
            readBuffer.append(chunk)
            guard readBuffer.count <= Self.maximumFrameBytes else {
                throw BoardToolServerError.invalidFrame(
                    "board parent frame is too large"
                )
            }
        }
    }

    private static func validateHello(_ value: JSONValue) throws -> [ToolDef] {
        guard let object = value.objectValue,
              Set(object.keys) == Set(["tools", "type"]),
              object["type"]?.stringValue == "hello_ok",
              let tools = object["tools"]?.arrayValue,
              (1...256).contains(tools.count)
        else {
            throw BoardToolServerError.invalidFrame(
                "invalid board hello response"
            )
        }
        var definitions: [ToolDef] = []
        var seen = Set<String>()
        for value in tools {
            guard let tool = value.objectValue,
                  Set(tool.keys)
                    == Set(["description", "inputSchema", "name"]),
                  let name = tool["name"]?.stringValue,
                  let description = tool["description"]?.stringValue,
                  let schema = tool["inputSchema"],
                  schema.objectValue != nil,
                  seen.insert(name).inserted
            else {
                throw BoardToolServerError.invalidFrame(
                    "invalid board tool definition"
                )
            }
            do {
                try EngineContractValidationV1.validateToolName(name)
                try CanonicalContractCodingV1.validateNonempty(description)
            } catch {
                throw BoardToolServerError.invalidFrame(
                    "invalid board tool definition"
                )
            }
            definitions.append(
                ToolDef(
                    name: name,
                    description: description,
                    inputSchema: schema
                )
            )
        }
        guard definitions.map(\.name) == definitions.map(\.name).sorted(by: {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }) else {
            throw BoardToolServerError.invalidFrame(
                "unsorted board tool definitions"
            )
        }
        return definitions
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
}
