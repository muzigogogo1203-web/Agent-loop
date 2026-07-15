import Darwin
import Foundation

public struct CliCommandSpec: Sendable, Equatable {
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]
    public let cleanupURLs: [URL]

    public init(command: String, arguments: [String], environment: [String: String] = [:], cleanupURLs: [URL] = []) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.cleanupURLs = cleanupURLs
    }
}

public enum CliBackendPolicy {
    public static let bannedFlags: [String] = [
        "--dangerously-bypass-approvals-and-sandbox",
        "--dangerously-bypass-hook-trust",
        "--dangerously-skip-permissions",
        "--allow-dangerously-skip-permissions",
        "--yolo",
        "bypassPermissions",
        "danger-full-access",
    ]

    public static func sandbox(for autonomy: MissionAutonomy) -> String {
        switch autonomy {
        case .careful:
            return "read-only"
        case .standard, .free:
            return "workspace-write"
        }
    }

    public static func claudePermissionMode(for autonomy: MissionAutonomy) -> String {
        switch autonomy {
        case .careful:
            return "plan"
        case .standard, .free:
            return "acceptEdits"
        }
    }

    public static func commandSpec(
        kind: RuntimeProfileKind,
        commandOverride: String?,
        workspace: URL?,
        prompt: String,
        bridgeExecutablePath: String,
        socketURL: URL,
        token: String,
        cardId: String,
        toolNames: [String],
        autonomy: MissionAutonomy
    ) throws -> CliCommandSpec {
        let spec: CliCommandSpec
        switch kind {
        case .cliCodex:
            spec = codexSpec(
                command: commandOverride ?? "codex",
                workspace: workspace,
                prompt: prompt,
                bridgeExecutablePath: bridgeExecutablePath,
                socketURL: socketURL,
                token: token,
                cardId: cardId,
                toolNames: toolNames,
                autonomy: autonomy
            )
        case .cliClaude:
            spec = try claudeSpec(
                command: commandOverride ?? "claude",
                workspace: workspace,
                prompt: prompt,
                bridgeExecutablePath: bridgeExecutablePath,
                socketURL: socketURL,
                token: token,
                cardId: cardId,
                toolNames: toolNames,
                autonomy: autonomy
            )
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            preconditionFailure("CliBackendPolicy only supports cli_* runtime profiles")
        }
        try assertNoBannedFlags(spec)
        return spec
    }

    public static func assertNoBannedFlags(_ spec: CliCommandSpec) throws {
        let haystack = ([spec.command] + spec.arguments).joined(separator: "\n")
        for banned in bannedFlags where haystack.contains(banned) {
            throw CliProcessBackendError.bannedFlag(banned)
        }
    }

    private static func codexSpec(
        command: String,
        workspace: URL?,
        prompt: String,
        bridgeExecutablePath: String,
        socketURL: URL,
        token: String,
        cardId: String,
        toolNames: [String],
        autonomy: MissionAutonomy
    ) -> CliCommandSpec {
        var args = ["exec"]
        if let workspace {
            args += ["--cd", workspace.path]
        }
        args += [
            "--sandbox", sandbox(for: autonomy),
            "-m", KernelDefaults.codexCliDefaultModel,
            "-c", "model_reasoning_effort=\(tomlString(KernelDefaults.codexCliReasoningEffort))",
            "-c", "mcp_servers.ranchboard.command=\(tomlString(bridgeExecutablePath))",
            "-c", "mcp_servers.ranchboard.args=[\(tomlString("--board-server"))]",
            "-c", "mcp_servers.ranchboard.env.AGENTLOOP_BOARD_SOCKET=\(tomlString(socketURL.path))",
            "-c", "mcp_servers.ranchboard.env.AGENTLOOP_BOARD_TOKEN=\(tomlString(token))",
            "-c", "mcp_servers.ranchboard.env.AGENTLOOP_BOARD_CARD_ID=\(tomlString(cardId))",
            "-c", "mcp_servers.ranchboard.env.AGENTLOOP_BOARD_TOOLS=\(tomlString(toolNames.joined(separator: ",")))",
            "--json",
            prompt,
        ]
        return CliCommandSpec(command: command, arguments: args)
    }

    private static func claudeSpec(
        command: String,
        workspace: URL?,
        prompt: String,
        bridgeExecutablePath: String,
        socketURL: URL,
        token: String,
        cardId: String,
        toolNames: [String],
        autonomy: MissionAutonomy
    ) throws -> CliCommandSpec {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentloop-claude-mcp-\(UUID().uuidString).json")
        let config: JSONValue = [
            "mcpServers": [
                "ranchboard": [
                    "command": .string(bridgeExecutablePath),
                    "args": ["--board-server"],
                    "env": [
                        "AGENTLOOP_BOARD_SOCKET": .string(socketURL.path),
                        "AGENTLOOP_BOARD_TOKEN": .string(token),
                        "AGENTLOOP_BOARD_CARD_ID": .string(cardId),
                        "AGENTLOOP_BOARD_TOOLS": .string(toolNames.joined(separator: ",")),
                    ],
                ],
            ],
        ]
        try Data(try config.encodedString().utf8).write(to: configURL, options: .atomic)

        var args = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--mcp-config", configURL.path,
            "--permission-mode", claudePermissionMode(for: autonomy),
        ]
        if let model = KernelDefaults.claudeCliModel, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--model", model]
        }
        if let workspace {
            args += ["--add-dir", workspace.path]
        }
        return CliCommandSpec(command: command, arguments: args, cleanupURLs: [configURL])
    }

    private static func tomlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

public enum CliProcessBackendError: Error, Sendable, Equatable {
    case unsupportedKind(RuntimeProfileKind)
    case bannedFlag(String)
    case processExitedWithoutTerminator(status: Int32, stderrTail: String)
}

public struct CliProcessBackend: CardExecutionBackend {
    private let db: AppDatabase
    private let artifactStoreRoot: URL
    private let profileKind: RuntimeProfileKind
    private let commandOverride: String?
    private let bridgeExecutablePath: String
    private let timeout: Duration
    private let socketDirectory: URL?
    private let registry: ShellProcessRegistry

    public init(
        db: AppDatabase,
        artifactStoreRoot: URL,
        profileKind: RuntimeProfileKind,
        commandOverride: String? = nil,
        bridgeExecutablePath: String = CommandLine.arguments.first ?? "AgentLoopApp",
        timeout: Duration = KernelDefaults.cliCardTimeout,
        socketDirectory: URL? = nil,
        registry: ShellProcessRegistry = .shared
    ) {
        self.db = db
        self.artifactStoreRoot = artifactStoreRoot
        self.profileKind = profileKind
        self.commandOverride = commandOverride
        self.bridgeExecutablePath = bridgeExecutablePath
        self.timeout = timeout
        self.socketDirectory = socketDirectory
        self.registry = registry
    }

    public func run(context: CardExecutionContext) throws -> AsyncThrowingStream<AgentEvent, Error> {
        guard profileKind.isCLI else {
            throw CliProcessBackendError.unsupportedKind(profileKind)
        }
        guard let card = try db.card(id: context.cardId) else {
            throw RecordNotFoundError(table: "card", id: context.cardId)
        }
        let squad = try db.squad(forCard: card.id)
        let workspaceAccess = WorkspaceScopedAccess(
            workspacePath: squad?.workspacePath,
            bookmark: squad?.workspaceBookmark
        )
        let workspace = workspaceAccess.url
        let runId = UUID().uuidString
        try db.startRun(cardId: card.id, runId: runId)

        let board = BoardToolServer.makeExecutor(
            db: db,
            cardId: card.id,
            runId: runId,
            workspaceRoot: workspace,
            artifactStoreRoot: artifactStoreRoot,
            campId: squad?.campId,
            toolAccess: context.toolAccess,
            autonomy: context.autonomy
        )
        let socketURL = try BoardToolServer.makeSocketURL(directory: socketDirectory)
        let processHandle = CliProcessHandle(registry: registry)
        let server = BoardToolServer(
            socketURL: socketURL,
            cardId: card.id,
            executor: board.executor,
            toolDefs: board.toolDefs,
            onTerminal: { _ in processHandle.terminate() }
        )
        let packet = ContextPacket(
            companionName: context.companionName,
            rolePrompt: context.rolePrompt,
            cardTitle: card.title,
            cardDescription: card.descriptionText,
            expectedOutput: card.expectedOutput,
            workspacePath: workspace?.path,
            upstreamHandoffs: context.upstreamHandoffs,
            answeredRequests: context.answeredRequests,
            campNotes: context.campNotes,
            companionNotes: context.companionNotes,
            toolNames: board.toolDefs.map(\.name)
        )
        let prompt = Self.renderPrompt(packet: packet)
        let spec = try CliBackendPolicy.commandSpec(
            kind: profileKind,
            commandOverride: commandOverride,
            workspace: workspace,
            prompt: prompt,
            bridgeExecutablePath: bridgeExecutablePath,
            socketURL: socketURL,
            token: server.token,
            cardId: card.id,
            toolNames: board.toolDefs.map(\.name),
            autonomy: context.autonomy
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                let metrics = CliRunMetrics()
                do {
                    try server.start()
                    try await withTaskCancellationHandler {
                        try await Self.runProcess(
                            spec: spec,
                            workspace: workspace,
                            processHandle: processHandle,
                            metrics: metrics,
                            timeout: timeout,
                            continuation: continuation
                        )
                    } onCancel: {
                        processHandle.terminate()
                    }
                    // 取消使进程被 SIGTERM 后 runProcess 正常返回;必须显式检查,走 canceled 收尾
                    try Task.checkCancellation()
                    let snapshot = await metrics.snapshot()
                    let turns = max(1, snapshot.turns)
                    if let outcome = server.terminalSnapshot {
                        switch outcome {
                        case .completed:
                            try db.finishRun(
                                id: runId,
                                outcome: "completed",
                                turns: turns,
                                tokensIn: snapshot.inputTokens,
                                tokensOut: snapshot.outputTokens
                            )
                            continuation.yield(.finished(outcome))
                        case .blocked:
                            try db.finishRun(
                                id: runId,
                                outcome: "blocked",
                                turns: turns,
                                tokensIn: snapshot.inputTokens,
                                tokensOut: snapshot.outputTokens
                            )
                            continuation.yield(.finished(outcome))
                        }
                    } else {
                        let detail = snapshot.timedOut
                            ? "CLI 执行超过 \(timeout) 后被终止。stderr 尾部：\(snapshot.stderrTail)"
                            : "CLI 退出但没有调用 complete_card / block_card。退出码 \(snapshot.exitStatus ?? -1)。stderr 尾部：\(snapshot.stderrTail)"
                        try blockCardIfStillRunning(cardId: card.id, runId: runId, reason: "tool_failure", detail: detail)
                        try db.finishRun(
                            id: runId,
                            outcome: "blocked",
                            turns: turns,
                            tokensIn: snapshot.inputTokens,
                            tokensOut: snapshot.outputTokens
                        )
                        let outcome = LoopOutcome.blocked(reason: "tool_failure", detail: detail)
                        continuation.yield(.finished(outcome))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    let snapshot = await metrics.snapshot()
                    try? db.finishRun(
                        id: runId,
                        outcome: "canceled",
                        turns: max(0, snapshot.turns),
                        tokensIn: snapshot.inputTokens,
                        tokensOut: snapshot.outputTokens
                    )
                    try? interruptCardIfStillRunning(cardId: card.id, runId: runId)
                    continuation.finish()
                } catch {
                    let snapshot = await metrics.snapshot()
                    try? db.finishRun(
                        id: runId,
                        outcome: "failed",
                        turns: max(0, snapshot.turns),
                        tokensIn: snapshot.inputTokens,
                        tokensOut: snapshot.outputTokens
                    )
                    let detail = String(describing: error)
                    try? db.appendDiagnosticEvent(
                        cardId: card.id,
                        runId: runId,
                        kind: EventKind.runError,
                        payload: ["error": .string(detail)]
                    )
                    try? blockCardIfStillRunning(
                        cardId: card.id,
                        runId: runId,
                        reason: "tool_failure",
                        detail: "CLI 运行错误：\(detail)"
                    )
                    continuation.finish(throwing: error)
                }
                server.stop()
                for url in spec.cleanupURLs {
                    try? FileManager.default.removeItem(at: url)
                }
                workspaceAccess.stop()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func renderPrompt(packet: ContextPacket) -> String {
        let userText = packet.firstUserMessage.content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined(separator: "\n")
        return """
        \(packet.system)

        # CLI 牧工工具约束
        你会看到一个名为 ranchboard 的 MCP server。唯一终结方式是调用 ranchboard.complete_card 或 ranchboard.block_card；需要向用户提问时调用 ranchboard.ask_user；阶段进展使用 ranchboard.progress_note。
        不要用普通文本宣布完成。

        \(userText)
        """
    }

    private static func runProcess(
        spec: CliCommandSpec,
        workspace: URL?,
        processHandle: CliProcessHandle,
        metrics: CliRunMetrics,
        timeout: Duration,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [spec.command] + spec.arguments
        var environment = await LoginShellEnvironment.shared.environment()
        environment.merge(spec.environment) { _, override in override }
        process.environment = environment
        process.currentDirectoryURL = workspace

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let exitBox = CliExitBox()
        process.terminationHandler = { process in
            processHandle.unregister(process.processIdentifier)
            Task { await exitBox.finish(process.terminationStatus) }
        }

        try process.run()
        processHandle.set(process)
        continuation.yield(.turnStarted)

        let stdoutTask = Task.detached {
            await readStdout(stdout.fileHandleForReading, profileKind: nil, metrics: metrics, continuation: continuation)
        }
        let stderrTask = Task.detached {
            await readStderr(stderr.fileHandleForReading, metrics: metrics)
        }
        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            guard await exitBox.value == nil else { return }
            await metrics.markTimedOut()
            processHandle.terminate()
            try? await Task.sleep(for: .seconds(5))
            if await exitBox.value == nil {
                processHandle.kill()
            }
        }

        let status = await exitBox.wait()
        await metrics.setExitStatus(status)
        timeoutTask.cancel()
        try? stdout.fileHandleForReading.close()
        try? stderr.fileHandleForReading.close()
        stdoutTask.cancel()
        stderrTask.cancel()
    }

    private static func readStdout(
        _ handle: FileHandle,
        profileKind: RuntimeProfileKind?,
        metrics: CliRunMetrics,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                guard let text = String(data: line, encoding: .utf8), !text.isEmpty else { continue }
                for event in CliOutputParser.events(from: text) {
                    if case .turnEnded(let usage) = event {
                        await metrics.addUsage(usage)
                    }
                    continuation.yield(event)
                }
            }
        }
    }

    private static func readStderr(_ handle: FileHandle, metrics: CliRunMetrics) async {
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            await metrics.appendStderr(chunk)
        }
    }

    private func blockCardIfStillRunning(cardId: String, runId: String, reason: String, detail: String) throws {
        guard try db.card(id: cardId)?.status == .running else { return }
        try db.blockCard(id: cardId, runId: runId, reason: reason, detail: detail)
    }

    private func interruptCardIfStillRunning(cardId: String, runId: String) throws {
        guard try db.card(id: cardId)?.status == .running else { return }
        try db.transitionCard(
            id: cardId,
            to: .ready,
            eventKind: EventKind.cardInterrupted,
            payload: ["runId": .string(runId), "reason": "canceled"]
        )
    }
}

public enum CliOutputParser {
    public static func events(from line: String) -> [AgentEvent] {
        guard let value = try? JSONValue.decoded(from: line) else { return [] }
        var events = textCandidates(value).map(AgentEvent.textDelta)
        if let usage = usageCandidate(value) {
            events.append(.turnEnded(usage: usage))
        }
        return events
    }

    private static func textCandidates(_ value: JSONValue) -> [String] {
        switch value {
        case .object(let object):
            var found: [String] = []
            for key in ["delta", "text", "content"] {
                if let text = object[key]?.stringValue,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   text.count > 1 {
                    found.append(text)
                }
            }
            for child in object.values {
                found.append(contentsOf: textCandidates(child))
            }
            return Array(NSOrderedSet(array: found)) as? [String] ?? found
        case .array(let values):
            return values.flatMap(textCandidates)
        case .string, .number, .bool, .null:
            return []
        }
    }

    private static func usageCandidate(_ value: JSONValue) -> Usage? {
        switch value {
        case .object(let object):
            let input = object["input_tokens"]?.intValue
                ?? object["prompt_tokens"]?.intValue
                ?? object["inputTokens"]?.intValue
            let output = object["output_tokens"]?.intValue
                ?? object["completion_tokens"]?.intValue
                ?? object["outputTokens"]?.intValue
            let cache = object["cache_read_input_tokens"]?.intValue
                ?? object["cached_tokens"]?.intValue
                ?? object["cacheReadTokens"]?.intValue
            if input != nil || output != nil || cache != nil {
                return Usage(inputTokens: input ?? 0, outputTokens: output ?? 0, cacheReadTokens: cache ?? 0)
            }
            for child in object.values {
                if let usage = usageCandidate(child) {
                    return usage
                }
            }
            return nil
        case .array(let values):
            for value in values {
                if let usage = usageCandidate(value) {
                    return usage
                }
            }
            return nil
        case .string, .number, .bool, .null:
            return nil
        }
    }
}

private final class CliProcessHandle: @unchecked Sendable {
    private let lock = NSLock()
    private let registry: ShellProcessRegistry
    private var process: Process?
    /// 取消可能先于进程注册到达;记住意图,set() 时补杀(否则 terminate 变空操作,取消挂到超时)
    private var terminateRequested = false

    init(registry: ShellProcessRegistry) {
        self.registry = registry
    }

    func set(_ process: Process) {
        lock.lock()
        self.process = process
        registry.register(process.processIdentifier)
        let pendingTerminate = terminateRequested
        lock.unlock()
        if pendingTerminate, process.isRunning {
            process.terminate()
        }
    }

    func unregister(_ pid: Int32) {
        registry.unregister(pid)
    }

    func terminate() {
        lock.lock()
        terminateRequested = true
        let process = self.process
        lock.unlock()
        guard let process, process.isRunning else { return }
        process.terminate()
    }

    func kill() {
        let process = currentProcess()
        guard let process, process.isRunning else { return }
        Darwin.kill(process.processIdentifier, SIGKILL)
    }

    private func currentProcess() -> Process? {
        lock.lock()
        defer { lock.unlock() }
        return process
    }
}

private actor CliRunMetrics {
    struct Snapshot: Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let turns: Int
        let stderrTail: String
        let timedOut: Bool
        let exitStatus: Int32?
    }

    private var inputTokens = 0
    private var outputTokens = 0
    private var turns = 0
    private var stderrTail = Data()
    private var timedOut = false
    private var exitStatus: Int32?

    func addUsage(_ usage: Usage) {
        turns += 1
        inputTokens = Self.saturatingAdd(inputTokens, usage.inputTokens)
        outputTokens = Self.saturatingAdd(outputTokens, usage.outputTokens)
    }

    func appendStderr(_ data: Data) {
        stderrTail.append(data)
        if stderrTail.count > KernelDefaults.cliStderrTailBytes {
            stderrTail.removeFirst(stderrTail.count - KernelDefaults.cliStderrTailBytes)
        }
    }

    func markTimedOut() {
        timedOut = true
    }

    func setExitStatus(_ status: Int32) {
        exitStatus = status
    }

    func snapshot() -> Snapshot {
        Snapshot(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            turns: turns,
            stderrTail: String(data: stderrTail, encoding: .utf8) ?? "",
            timedOut: timedOut,
            exitStatus: exitStatus
        )
    }

    private static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(max(0, rhs))
        return overflow ? Int.max : sum
    }
}

private actor CliExitBox {
    private var status: Int32?
    private var waiters: [CheckedContinuation<Int32, Never>] = []

    var value: Int32? { status }

    func wait() async -> Int32 {
        if let status { return status }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish(_ status: Int32) {
        guard self.status == nil else { return }
        self.status = status
        let waiters = self.waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: status)
        }
    }
}
