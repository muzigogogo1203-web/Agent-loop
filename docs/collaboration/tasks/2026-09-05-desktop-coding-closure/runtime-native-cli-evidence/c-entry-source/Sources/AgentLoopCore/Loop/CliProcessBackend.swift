import Darwin
import CryptoKit
import Foundation

protocol CliProcessCodeSignatureRevalidatingV1: Sendable {
    func revalidateCLI(
        _ authority: CliExecutableAuthorityV1
    ) throws
    func revalidateBoardBridge(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws
}

private struct CliProcessLiveCodeSignatureRevalidatorV1:
    CliProcessCodeSignatureRevalidatingV1
{
    func revalidateCLI(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        try authority.revalidateStagedCodeSignature()
    }

    func revalidateBoardBridge(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws {
        try authority.revalidateStagedCodeSignature()
    }
}

package enum CliAuxiliaryDescriptorFailureV1: Error, Sendable, Equatable {
    case invalidDescriptor
    case duplicationFailed
    case originalCloseFailed
}

package enum CliAuxiliaryDescriptorV1 {
    package static func normalizeOwned(
        _ descriptor: inout Int32
    ) throws {
        guard descriptor >= 0 else {
            throw CliAuxiliaryDescriptorFailureV1.invalidDescriptor
        }
        guard descriptor <= STDERR_FILENO else { return }
        let original = descriptor
        let duplicate = Darwin.fcntl(
            original,
            F_DUPFD_CLOEXEC,
            STDERR_FILENO + 1
        )
        guard duplicate > STDERR_FILENO else {
            if duplicate >= 0 { _ = Darwin.close(duplicate) }
            throw CliAuxiliaryDescriptorFailureV1.duplicationFailed
        }
        descriptor = duplicate
        guard Darwin.close(original) == 0 else {
            throw CliAuxiliaryDescriptorFailureV1.originalCloseFailed
        }
    }
}

public struct CliCommandSpec: Sendable, Equatable {
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]
    public let stdinBytes: Data
    public let cleanupURLs: [URL]
    package let cleanupAuthorities: [CliCleanupFileAuthorityV1]

    public init(
        command: String,
        arguments: [String],
        environment: [String: String] = [:],
        stdinBytes: Data = Data(),
        cleanupURLs: [URL] = []
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.stdinBytes = stdinBytes
        self.cleanupURLs = cleanupURLs
        cleanupAuthorities = []
    }

    package init(
        command: String,
        arguments: [String],
        environment: [String: String] = [:],
        stdinBytes: Data = Data(),
        cleanupAuthorities: [CliCleanupFileAuthorityV1]
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.stdinBytes = stdinBytes
        self.cleanupAuthorities = cleanupAuthorities
        cleanupURLs = cleanupAuthorities.map(\.fileURL)
    }
}

package struct CliProcessLaunchRequestV1: Sendable {
    package let executionId: String
    package let spec: CliCommandSpec
    package let cliExecutableAuthority: CliExecutableAuthorityV1
    package let workspaceURL: URL
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1
    package let boardSocketBasename: String
    package let boardToken: String
    package let boardCardId: String
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink

    package init(
        executionId: String,
        spec: CliCommandSpec,
        cliExecutableAuthority: CliExecutableAuthorityV1,
        workspaceURL: URL,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1,
        boardSocketDirectoryAuthority:
            EngineBoardSocketDirectoryAuthorityV1,
        boardSocketBasename: String,
        boardToken: String,
        boardCardId: String,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        try cliExecutableAuthority.validateCanonical()
        try bridgeExecutableAuthority.validateCanonical()
        let expectedSocket = try BoardToolServer.makeSocketURL(
            directoryAuthority: boardSocketDirectoryAuthority,
            executionId: executionId
        )
        guard let stdinPrompt = String(
            data: spec.stdinBytes,
            encoding: .utf8
        ) else {
            throw EngineContextValidationErrorV1()
        }
        guard spec.command == cliExecutableAuthority.stagedPath,
              (1...4_194_304).contains(spec.stdinBytes.count),
              !spec.arguments.contains(stdinPrompt),
              !spec.arguments.contains(boardToken),
              !spec.arguments.contains(boardCardId),
              !spec.arguments.contains(expectedSocket.path),
              spec.cleanupURLs
                == spec.cleanupAuthorities.map(\.fileURL),
              Set(spec.cleanupURLs.map(\.path)).count
                == spec.cleanupURLs.count,
              workspaceURL.isFileURL,
              workspaceURL.baseURL == nil,
              workspaceURL.path.hasPrefix("/"),
              !workspaceURL.path.isEmpty,
              workspaceURL.standardizedFileURL.path == workspaceURL.path,
              !boardSocketBasename.isEmpty,
              !boardSocketBasename.contains("/"),
              !boardSocketBasename.utf8.contains(0),
              boardSocketBasename == expectedSocket.lastPathComponent,
              boardToken.utf8.count == 64,
              boardToken.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
              })
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(boardCardId)
        self.executionId = executionId
        self.spec = spec
        self.cliExecutableAuthority = cliExecutableAuthority
        self.workspaceURL = workspaceURL
        self.boundCapabilityTools = boundCapabilityTools
        self.bridgeExecutableAuthority = bridgeExecutableAuthority
        self.boardSocketDirectoryAuthority =
            boardSocketDirectoryAuthority
        self.boardSocketBasename = boardSocketBasename
        self.boardToken = boardToken
        self.boardCardId = boardCardId
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
    }
}

package enum CliProcessFrameV1: Sendable, Equatable {
    case stdoutLine(String)
    case stderr(Data)
    case exited(Int32)
}

package struct CliProcessExitEvidenceV1: Sendable, Equatable {
    package let pid: Int32
    package let processGroupID: Int32
    package let status: Int32
    package let termSent: Bool
    package let killSent: Bool
    package let stdoutEOF: Bool
    package let stderrEOF: Bool
    package let childReaped: Bool

    package init(
        pid: Int32,
        processGroupID: Int32,
        status: Int32,
        termSent: Bool,
        killSent: Bool,
        stdoutEOF: Bool,
        stderrEOF: Bool,
        childReaped: Bool
    ) {
        self.pid = pid
        self.processGroupID = processGroupID
        self.status = status
        self.termSent = termSent
        self.killSent = killSent
        self.stdoutEOF = stdoutEOF
        self.stderrEOF = stderrEOF
        self.childReaped = childReaped
    }
}

package protocol CliProcessDrivingV1: Sendable {
    var supportsProcessGroupCancellation: Bool { get }
    func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error>
    func cancel(executionId: String) async throws -> CliProcessExitEvidenceV1
}

public enum CliProcessBackendError: Error, Sendable, Equatable {
    case pipeSetupFailed(String)
    case invalidMechanicsConfiguration(String)
    case reservedEnvironmentKey(String)
    case processLaunchFailed(String)
    case processNotRegistered(String)
    case processSignalFailed(signal: Int32, detail: String)
    case processGroupStillAlive(Int32)
    case processCleanupFailed(String)
    case pipeDrainIncomplete(String)
}

public enum CliPipeDrain {
    public enum ReadResult: Sendable {
        case data(Data)
        case wouldBlock
        case interrupted
        case eof
        case failed(String)
    }

    private static let minimumBackoff: Duration = .milliseconds(10)
    private static let maximumBackoff: Duration = .milliseconds(100)

    /// Drains a non-blocking pipe. After process exit is observed, drain until EAGAIN/EOF or grace expiry.
    public static func drain(
        grace: Duration,
        readChunk: () -> ReadResult,
        isExited: () async -> Bool,
        sleep: (Duration) async -> Void,
        now: () -> ContinuousClock.Instant,
        onData: (Data) async -> Void,
        onReadFailure: (String) async -> Void
    ) async {
        var exitObservedAt: ContinuousClock.Instant?
        var backoff = minimumBackoff

        while true {
            switch readChunk() {
            case .data(let chunk):
                if exitObservedAt == nil, await isExited() {
                    exitObservedAt = now()
                }
                await onData(chunk)
                backoff = minimumBackoff
                if let observedAt = exitObservedAt, observedAt.duration(to: now()) >= grace {
                    return
                }
            case .interrupted:
                continue
            case .eof:
                return
            case .failed(let message):
                await onReadFailure(message)
                return
            case .wouldBlock:
                if exitObservedAt != nil {
                    return
                }
                if await isExited() {
                    exitObservedAt = now()
                    continue
                }
                await sleep(backoff)
                backoff = min(backoff * 2, maximumBackoff)
            }
        }
    }
}

public struct CliProcessBackend: CliProcessDrivingV1 {
    private let terminationGrace: Duration
    private let killGrace: Duration
    private let pipeDrainGrace: Duration
    private let registry: ShellProcessRegistry
    private let processInspector: any EngineRuntimeProcessInspectingV1
    private let codeSignatureRevalidator:
        any CliProcessCodeSignatureRevalidatingV1
    private let environmentProvider: @Sendable () async -> [String: String]
    private let mechanicsState: CliProcessMechanicsState

    package init(
        terminationGrace: Duration = .seconds(5),
        killGrace: Duration = .seconds(2),
        pipeDrainGrace: Duration = .seconds(1),
        registry: ShellProcessRegistry = .shared,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws {
        try self.init(
            terminationGrace: terminationGrace,
            killGrace: killGrace,
            pipeDrainGrace: pipeDrainGrace,
            registry: registry,
            processInspector: processInspector,
            codeSignatureRevalidator:
                CliProcessLiveCodeSignatureRevalidatorV1(),
            environmentProvider: {
                await LoginShellEnvironment.shared.environment()
            }
        )
    }

    init(
        terminationGrace: Duration = .seconds(5),
        killGrace: Duration = .seconds(2),
        pipeDrainGrace: Duration = .seconds(1),
        registry: ShellProcessRegistry = .shared,
        processInspector: any EngineRuntimeProcessInspectingV1,
        codeSignatureRevalidator:
            any CliProcessCodeSignatureRevalidatingV1,
        environmentProvider: @escaping @Sendable () async -> [String: String] = {
            await LoginShellEnvironment.shared.environment()
        }
    ) throws {
        guard terminationGrace >= .zero,
              killGrace > .zero,
              pipeDrainGrace > .zero else {
            throw CliProcessBackendError.invalidMechanicsConfiguration(
                "process grace durations must be nonnegative, with positive kill/drain grace"
            )
        }
        self.terminationGrace = terminationGrace
        self.killGrace = killGrace
        self.pipeDrainGrace = pipeDrainGrace
        self.registry = registry
        self.processInspector = processInspector
        self.codeSignatureRevalidator = codeSignatureRevalidator
        self.environmentProvider = environmentProvider
        mechanicsState = CliProcessMechanicsState()
    }
}

extension CliProcessBackend {
    package var supportsProcessGroupCancellation: Bool { true }

    package func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error> {
        AsyncThrowingStream { continuation in
            let execution = CliProcessExecution(
                request: request,
                terminationGrace: terminationGrace,
                killGrace: killGrace,
                pipeDrainGrace: pipeDrainGrace,
                registry: registry,
                processInspector: processInspector,
                codeSignatureRevalidator: codeSignatureRevalidator,
                environmentProvider: environmentProvider,
                owner: mechanicsState,
                continuation: continuation
            )
            do {
                try mechanicsState.register(execution)
            } catch {
                continuation.finish(throwing: error)
                return
            }
            continuation.onTermination = { termination in
                guard case .cancelled = termination else { return }
                execution.requestStreamCancellation()
            }
            execution.start()
        }
    }

    package func cancel(
        executionId: String
    ) async throws -> CliProcessExitEvidenceV1 {
        guard let execution = mechanicsState.execution(id: executionId) else {
            throw CliProcessBackendError.processNotRegistered(executionId)
        }
        return try await execution.cancel()
    }
}

private final class CliProcessMechanicsState: @unchecked Sendable {
    private let lock = NSLock()
    private var executions: [String: CliProcessExecution] = [:]

    func register(_ execution: CliProcessExecution) throws {
        lock.lock()
        defer { lock.unlock() }
        let id = execution.executionId
        guard executions[id] == nil else {
            throw CliProcessBackendError.processLaunchFailed(
                "duplicate execution registration"
            )
        }
        executions[id] = execution
    }

    func execution(id: String) -> CliProcessExecution? {
        lock.lock()
        defer { lock.unlock() }
        return executions[id]
    }

    func remove(_ execution: CliProcessExecution) {
        lock.lock()
        defer { lock.unlock() }
        if executions[execution.executionId] === execution {
            executions.removeValue(forKey: execution.executionId)
        }
    }
}

private struct CliProcessReapResult: Sendable {
    let status: Int32?
    let failure: String?
}

private final class CliProcessReapState: @unchecked Sendable {
    private let lock = NSLock()
    private var didExit = false

    func markExited() {
        lock.lock()
        didExit = true
        lock.unlock()
    }

    var exited: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExit
    }
}

private struct CliSpawnCore: @unchecked Sendable {
    let pid: Int32
    let processGroupID: Int32
    let server: BoardToolServer
    let stdinGate: CliStdinStartGate
    let stdinTask: Task<Void, Error>
    let reapTask: Task<CliProcessReapResult, Never>
    let stdoutTask: Task<Bool, Never>
    let stderrTask: Task<Bool, Never>
}

private final class CliStdinStartGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            let shouldResume = lock.withLock {
                if isOpen { return true }
                waiters.append(continuation)
                return false
            }
            if shouldResume { continuation.resume() }
        }
    }

    func open() {
        let pending: [CheckedContinuation<Void, Never>] = lock.withLock {
            guard !isOpen else { return [] }
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            return pending
        }
        for waiter in pending { waiter.resume() }
    }
}

private struct CliRegisteredProcess: @unchecked Sendable {
    let core: CliSpawnCore
    let completionTask: Task<CliProcessExitEvidenceV1, Error>
}

private final class CliProcessExecution: @unchecked Sendable {
    let executionId: String

    private enum Registration {
        case pending
        case ready(CliRegisteredProcess)
        case failed(any Error)
    }

    private static let reservedBoardEnvironmentKeys: Set<String> = [
        "AGENTLOOP_BOARD_SOCKET",
        "AGENTLOOP_BOARD_TOKEN",
        "AGENTLOOP_BOARD_CARD_ID",
        "AGENTLOOP_BOARD_TOOLS",
    ]
    private static let reservedClaudeEnvironment: [String: String] = [
        "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1",
        "CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS": "1",
        "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1",
        "DISABLE_AUTOUPDATER": "1",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
        "DISABLE_TELEMETRY": "1",
        "DISABLE_ERROR_REPORTING": "1",
        "DISABLE_BUG_COMMAND": "1",
    ]

    private let request: CliProcessLaunchRequestV1
    private let terminationGrace: Duration
    private let killGrace: Duration
    private let pipeDrainGrace: Duration
    private let registry: ShellProcessRegistry
    private let processInspector: any EngineRuntimeProcessInspectingV1
    private let codeSignatureRevalidator:
        any CliProcessCodeSignatureRevalidatingV1
    private let environmentProvider: @Sendable () async -> [String: String]
    private let owner: CliProcessMechanicsState
    private let diagnosticId = UUID()
    private let continuation:
        AsyncThrowingStream<CliProcessFrameV1, Error>.Continuation
    private let lock = NSLock()
    private var registration: Registration = .pending
    private var registrationWaiters:
        [CheckedContinuation<CliRegisteredProcess, Error>] = []
    private var cancellationTask:
        Task<CliProcessExitEvidenceV1, Error>?
    private var cancellationRequested = false
    private var termSent = false
    private var killSent = false

    init(
        request: CliProcessLaunchRequestV1,
        terminationGrace: Duration,
        killGrace: Duration,
        pipeDrainGrace: Duration,
        registry: ShellProcessRegistry,
        processInspector: any EngineRuntimeProcessInspectingV1,
        codeSignatureRevalidator:
            any CliProcessCodeSignatureRevalidatingV1,
        environmentProvider: @escaping @Sendable () async -> [String: String],
        owner: CliProcessMechanicsState,
        continuation:
            AsyncThrowingStream<CliProcessFrameV1, Error>.Continuation
    ) {
        executionId = request.executionId
        self.request = request
        self.terminationGrace = terminationGrace
        self.killGrace = killGrace
        self.pipeDrainGrace = pipeDrainGrace
        self.registry = registry
        self.processInspector = processInspector
        self.codeSignatureRevalidator = codeSignatureRevalidator
        self.environmentProvider = environmentProvider
        self.owner = owner
        self.continuation = continuation
    }

    func start() {
        RuntimeLifecycleDiagnostics.event(.cliRunQueued, owner: diagnosticId)
        Task { [self] in
            await run()
        }
    }

    func requestStreamCancellation() {
        Task { [self] in
            do {
                _ = try await cancel()
            } catch {
                // The stream is already canceled. The same mechanics failure
                // remains observable from an explicit cancel call and from the
                // shared completion task when a consumer is still attached.
            }
        }
    }

    func cancel() async throws -> CliProcessExitEvidenceV1 {
        let task: Task<CliProcessExitEvidenceV1, Error> = lock.withLock {
            if let cancellationTask {
                return cancellationTask
            }
            let created = Task { [self] in
                try await performCancellation()
            }
            cancellationTask = created
            return created
        }
        return try await task.value
    }

    private func run() async {
        RuntimeLifecycleDiagnostics.event(.cliRunStarted, owner: diagnosticId)
        var server: BoardToolServer?
        var registered = false
        defer { owner.remove(self) }

        do {
            try validateLaunchInputs()
            RuntimeLifecycleDiagnostics.event(
                .cliLaunchInputsValidated, owner: diagnosticId
            )
            RuntimeLifecycleDiagnostics.event(
                .cliEnvironmentRequested, owner: diagnosticId
            )
            var environment = await environmentProvider()
            RuntimeLifecycleDiagnostics.event(
                .cliEnvironmentReady, owner: diagnosticId
            )
            for key in Self.reservedBoardEnvironmentKeys {
                environment[key] = nil
            }
            for key in Self.reservedClaudeEnvironment.keys {
                environment[key] = nil
            }
            environment.merge(request.spec.environment) { _, override in
                override
            }
            let boardSocketURL = try BoardToolServer.makeSocketURL(
                directoryAuthority: request.boardSocketDirectoryAuthority,
                executionId: request.executionId
            )
            guard boardSocketURL.lastPathComponent
                    == request.boardSocketBasename
            else {
                throw CliProcessBackendError.invalidMechanicsConfiguration(
                    "Board socket authority mismatch"
                )
            }
            environment["AGENTLOOP_BOARD_SOCKET"] = boardSocketURL.path
            environment["AGENTLOOP_BOARD_TOKEN"] = request.boardToken
            environment["AGENTLOOP_BOARD_CARD_ID"] = request.boardCardId
            environment["AGENTLOOP_BOARD_TOOLS"] = request
                .boundCapabilityTools.logicalDefinitions.map(\.name)
                .sorted().joined(separator: ",")
            try validateEnvironment(environment)
            RuntimeLifecycleDiagnostics.event(
                .cliEnvironmentValidated, owner: diagnosticId
            )

            let boardServer = try BoardToolServer(
                directoryAuthority: request.boardSocketDirectoryAuthority,
                socketBasename: request.boardSocketBasename,
                token: request.boardToken,
                cardId: request.boardCardId,
                boardTerminalSink: request.boardTerminalSink,
                progressSink: request.progressSink,
                boundCapabilityTools: request.boundCapabilityTools,
                validatePeer: { peerPid in
                    try Self.validateBoardPeer(
                        peerPid,
                        authority: self.request.bridgeExecutableAuthority,
                        processInspector: self.processInspector
                    )
                },
                onTerminalAccepted: { [weak self] in
                    self?.requestStreamCancellation()
                }
            )
            server = boardServer
            RuntimeLifecycleDiagnostics.event(
                .cliBoardStartCalled, owner: diagnosticId
            )
            try boardServer.start()
            RuntimeLifecycleDiagnostics.event(
                .cliBoardStartReturned, owner: diagnosticId
            )

            let core = try await spawn(
                environment: environment,
                server: boardServer
            )
            let completionTask = Task { [self, core] in
                try await finalize(core)
            }
            let process = CliRegisteredProcess(
                core: core,
                completionTask: completionTask
            )
            registered = true
            publishRegistration(process)
            core.stdinGate.open()

            let evidence = try await completionTask.value
            continuation.yield(.exited(evidence.status))
            continuation.finish()
        } catch {
            var terminalError: any Error = error
            if !registered {
                var cleanupFailed = false
                if let server {
                    do {
                        try await server.stopAsync()
                    } catch {
                        cleanupFailed = true
                    }
                }
                do {
                    try removeCleanupFiles()
                } catch {
                    cleanupFailed = true
                }
                if cleanupFailed {
                    terminalError = CliProcessBackendError
                        .processCleanupFailed(
                            "pre-registration Board or config cleanup failed"
                        )
                }
                owner.remove(self)
                failRegistration(terminalError)
            }
            continuation.finish(throwing: terminalError)
        }
    }

    private func validateLaunchInputs() throws {
        let strings = [request.spec.command]
            + request.spec.arguments
            + [request.workspaceURL.path]
        guard !request.spec.command.isEmpty,
              strings.allSatisfy({ !$0.utf8.contains(0) }),
              request.spec.command
                == request.cliExecutableAuthority.stagedPath,
              (1...4_194_304).contains(request.spec.stdinBytes.count)
        else {
            throw CliProcessBackendError.invalidMechanicsConfiguration(
                "process command contains invalid bytes"
            )
        }
        let workspaceDescriptor = request.workspaceURL.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard workspaceDescriptor >= 0 else {
            throw CliProcessBackendError.invalidMechanicsConfiguration(
                "workspace directory is unavailable"
            )
        }
        var workspaceInfo = stat()
        let workspaceIsAuthorized =
            Darwin.fstat(workspaceDescriptor, &workspaceInfo) == 0
            && workspaceInfo.st_mode & S_IFMT == S_IFDIR
            && workspaceInfo.st_uid == getuid()
        let workspaceClosed = Darwin.close(workspaceDescriptor) == 0
        guard workspaceIsAuthorized, workspaceClosed else {
            throw CliProcessBackendError.invalidMechanicsConfiguration(
                "workspace directory identity is unavailable"
            )
        }
        for key in request.spec.environment.keys
        where Self.reservedBoardEnvironmentKeys.contains(key) {
            throw CliProcessBackendError.reservedEnvironmentKey(key)
        }
        switch request.cliExecutableAuthority.kind {
        case .cliCodex:
            guard request.spec.environment.isEmpty else {
                throw CliProcessBackendError.invalidMechanicsConfiguration(
                    "Codex child environment must be empty"
                )
            }
        case .cliClaude:
            guard request.spec.environment
                    == Self.reservedClaudeEnvironment
            else {
                throw CliProcessBackendError.invalidMechanicsConfiguration(
                    "Claude reserved environment mismatch"
                )
            }
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            throw CliProcessBackendError.invalidMechanicsConfiguration(
                "non-CLI executable authority"
            )
        }
        try Self.validateExecutableAuthority(
            request.cliExecutableAuthority,
            codeSignatureRevalidator: codeSignatureRevalidator
        )
        try Self.validateBridgeAuthority(
            request.bridgeExecutableAuthority,
            codeSignatureRevalidator: codeSignatureRevalidator
        )
    }

    private func validateEnvironment(
        _ environment: [String: String]
    ) throws {
        for (key, value) in environment {
            guard !key.isEmpty,
                  !key.contains("="),
                  !key.utf8.contains(0),
                  !value.utf8.contains(0) else {
                throw CliProcessBackendError.invalidMechanicsConfiguration(
                    "process environment contains invalid bytes"
                )
            }
        }
    }

    private func spawn(
        environment: [String: String],
        server: BoardToolServer
    ) async throws -> CliSpawnCore {
        RuntimeLifecycleDiagnostics.event(
            .cliSpawnPreparationStarted, owner: diagnosticId
        )
        let diagnosticOwner = diagnosticId
        var stdinRead: Int32 = -1
        var stdinWrite: Int32 = -1
        var stdoutRead: Int32 = -1
        var stdoutWrite: Int32 = -1
        var stderrRead: Int32 = -1
        var stderrWrite: Int32 = -1
        defer {
            if stdinRead >= 0 { close(stdinRead) }
            if stdinWrite >= 0 { close(stdinWrite) }
            if stdoutRead >= 0 { close(stdoutRead) }
            if stdoutWrite >= 0 { close(stdoutWrite) }
            if stderrRead >= 0 { close(stderrRead) }
            if stderrWrite >= 0 { close(stderrWrite) }
        }

        (stdinRead, stdinWrite) = try Self.makePipe()
        (stdoutRead, stdoutWrite) = try Self.makePipe()
        (stderrRead, stderrWrite) = try Self.makePipe()
        do {
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdinRead)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdinWrite)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdoutRead)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdoutWrite)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stderrRead)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stderrWrite)
        } catch {
            throw CliProcessBackendError.pipeSetupFailed(
                "auxiliary descriptor normalization failed"
            )
        }
        guard fcntl(stdinWrite, F_SETNOSIGPIPE, 1) == 0 else {
            throw CliProcessBackendError.pipeSetupFailed(
                "stdin no-SIGPIPE setup failed"
            )
        }
        try Self.setNonBlocking(stdinWrite)
        try Self.setNonBlocking(stdoutRead)
        try Self.setNonBlocking(stderrRead)

        var fileActions: posix_spawn_file_actions_t?
        var code = posix_spawn_file_actions_init(&fileActions)
        guard code == 0 else {
            throw CliProcessBackendError.processLaunchFailed(
                "process file-actions setup failed"
            )
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        try Self.checkSpawnSetup(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                stdinRead,
                STDIN_FILENO
            )
        )
        try Self.checkSpawnSetup(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                stdoutWrite,
                STDOUT_FILENO
            )
        )
        try Self.checkSpawnSetup(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                stderrWrite,
                STDERR_FILENO
            )
        )
        for fd in [
            stdinRead, stdinWrite, stdoutRead, stdoutWrite,
            stderrRead, stderrWrite,
        ] {
            try Self.checkSpawnSetup(
                posix_spawn_file_actions_addclose(&fileActions, fd)
            )
        }
        try Self.checkSpawnSetup(
            posix_spawn_file_actions_addchdir_np(
                &fileActions,
                request.workspaceURL.path
            )
        )

        var attributes: posix_spawnattr_t?
        code = posix_spawnattr_init(&attributes)
        guard code == 0 else {
            throw CliProcessBackendError.processLaunchFailed(
                "process attributes setup failed"
            )
        }
        defer { posix_spawnattr_destroy(&attributes) }
        var defaultSignals = sigset_t()
        var signalMask = sigset_t()
        guard sigemptyset(&defaultSignals) == 0,
              sigaddset(&defaultSignals, SIGTERM) == 0,
              sigemptyset(&signalMask) == 0
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "process signal attributes setup failed"
            )
        }
        try Self.checkSpawnSetup(
            posix_spawnattr_setsigdefault(&attributes, &defaultSignals)
        )
        try Self.checkSpawnSetup(
            posix_spawnattr_setsigmask(&attributes, &signalMask)
        )
        try Self.checkSpawnSetup(
            posix_spawnattr_setflags(
                &attributes,
                Int16(
                    POSIX_SPAWN_SETPGROUP
                        | POSIX_SPAWN_CLOEXEC_DEFAULT
                        | POSIX_SPAWN_START_SUSPENDED
                        | POSIX_SPAWN_SETSIGDEF
                        | POSIX_SPAWN_SETSIGMASK
                )
            )
        )
        try Self.checkSpawnSetup(
            posix_spawnattr_setpgroup(&attributes, 0)
        )

        var arguments = try Self.makeCStringVector(
            [request.spec.command] + request.spec.arguments
        )
        defer { Self.freeCStringVector(arguments) }
        var environmentVector = try Self.makeCStringVector(
            environment.keys.sorted().map { key in
                "\(key)=\(environment[key]!)"
            }
        )
        defer { Self.freeCStringVector(environmentVector) }

        var pid: pid_t = 0
        RuntimeLifecycleDiagnostics.event(
            .cliPosixSpawnCalled, owner: diagnosticOwner
        )
        code = request.spec.command.withCString { executable in
            arguments.withUnsafeMutableBufferPointer { argv in
                environmentVector.withUnsafeMutableBufferPointer { envp in
                    posix_spawn(
                        &pid,
                        executable,
                        &fileActions,
                        &attributes,
                        argv.baseAddress,
                        envp.baseAddress
                    )
                }
            }
        }
        guard code == 0 else {
            RuntimeLifecycleDiagnostics.event(
                .cliSpawnFailed, owner: diagnosticOwner, value: Int(code)
            )
            throw CliProcessBackendError.processLaunchFailed(
                "staged process spawn failed"
            )
        }
        RuntimeLifecycleDiagnostics.event(
            .cliSpawned, owner: diagnosticOwner, value: Int(pid)
        )

        var groupRegistered = false
        var reapTask: Task<CliProcessReapResult, Never>?
        var stdoutTask: Task<Bool, Never>?
        var stderrTask: Task<Bool, Never>?
        do {
            try Self.checkedClose(&stdinRead)
            try Self.checkedClose(&stdoutWrite)
            try Self.checkedClose(&stderrWrite)

            let processGroupID = getpgid(pid)
            guard processGroupID == pid else {
                throw CliProcessBackendError.processLaunchFailed(
                    "child process group identity mismatch"
                )
            }
            RuntimeLifecycleDiagnostics.event(
                .cliSuspendedValidationCalled,
                owner: diagnosticOwner, value: Int(pid)
            )
            try Self.validateSuspendedImage(
                pid: pid,
                processGroupID: processGroupID,
                authority: request.cliExecutableAuthority,
                processInspector: processInspector
            )
            RuntimeLifecycleDiagnostics.event(
                .cliSuspendedValidationReturned,
                owner: diagnosticOwner, value: Int(pid)
            )

            registry.register(-processGroupID)
            groupRegistered = true
            let childPID = pid
            let reapState = CliProcessReapState()
            RuntimeLifecycleDiagnostics.event(
                .cliReapTaskQueued, owner: diagnosticOwner
            )
            let createdReapTask = BlockingProcessOperation.start {
                RuntimeLifecycleDiagnostics.event(
                    .cliReapTaskStarted, owner: diagnosticOwner
                )
                var rawStatus: Int32 = 0
                while true {
                    let result = waitpid(childPID, &rawStatus, 0)
                    let waitError = result < 0 ? errno : 0
                    if result == childPID {
                        RuntimeLifecycleDiagnostics.event(
                            .cliWaitpidReturned,
                            owner: diagnosticOwner, value: Int(result)
                        )
                        reapState.markExited()
                        return CliProcessReapResult(
                            status: Self.decodeWaitStatus(rawStatus),
                            failure: nil
                        )
                    }
                    if result < 0, waitError == EINTR { continue }
                    RuntimeLifecycleDiagnostics.event(
                        .cliWaitpidReturned,
                        owner: diagnosticOwner, value: Int(result)
                    )
                    if result < 0 {
                        RuntimeLifecycleDiagnostics.event(
                            .cliWaitpidError,
                            owner: diagnosticOwner, value: Int(waitError)
                        )
                    }
                    let detail = result < 0
                        ? "waitpid failed"
                        : "waitpid returned an unexpected child"
                    reapState.markExited()
                    return CliProcessReapResult(
                        status: nil,
                        failure: detail
                    )
                }
            }
            reapTask = createdReapTask
            let stdoutFD = stdoutRead
            stdoutRead = -1
            let stderrFD = stderrRead
            stderrRead = -1
            RuntimeLifecycleDiagnostics.event(
                .cliStdoutTaskQueued, owner: diagnosticOwner
            )
            let createdStdoutTask = Task.detached {
                [continuation, pipeDrainGrace, diagnosticOwner] in
                RuntimeLifecycleDiagnostics.event(
                    .cliStdoutTaskStarted, owner: diagnosticOwner
                )
                return await Self.drainStdout(
                    fd: stdoutFD,
                    reapState: reapState,
                    grace: pipeDrainGrace,
                    continuation: continuation,
                    diagnosticOwner: diagnosticOwner
                )
            }
            stdoutTask = createdStdoutTask
            RuntimeLifecycleDiagnostics.event(
                .cliStderrTaskQueued, owner: diagnosticOwner
            )
            let createdStderrTask = Task.detached {
                [continuation, pipeDrainGrace, diagnosticOwner] in
                RuntimeLifecycleDiagnostics.event(
                    .cliStderrTaskStarted, owner: diagnosticOwner
                )
                return await Self.drainStderr(
                    fd: stderrFD,
                    reapState: reapState,
                    grace: pipeDrainGrace,
                    continuation: continuation
                )
            }
            stderrTask = createdStderrTask

            RuntimeLifecycleDiagnostics.event(
                .cliSIGCONTCalled,
                owner: diagnosticOwner, value: Int(processGroupID)
            )
            try processInspector.send(
                signal: SIGCONT,
                processGroupId: processGroupID
            )
            RuntimeLifecycleDiagnostics.event(
                .cliSIGCONTReturned,
                owner: diagnosticOwner, value: Int(processGroupID)
            )
            let stdinFD = stdinWrite
            stdinWrite = -1
            let stdinGate = CliStdinStartGate()
            let stdinData = request.spec.stdinBytes
            let stdinTask = Task.detached {
                await stdinGate.wait()
                try await Self.writeAllStdinCancellable(
                    stdinData,
                    descriptor: stdinFD
                )
            }
            return CliSpawnCore(
                pid: childPID,
                processGroupID: processGroupID,
                server: server,
                stdinGate: stdinGate,
                stdinTask: stdinTask,
                reapTask: createdReapTask,
                stdoutTask: createdStdoutTask,
                stderrTask: createdStderrTask
            )
        } catch {
            let primaryError = error
            var cleanupFailure: (any Error)?
            if groupRegistered {
                let signalOutcome = Self.signalSpawnedGroupForTermination(
                    processGroupID: pid,
                    processInspector: processInspector
                )
                if let failure = signalOutcome.failure,
                   signalOutcome.groupStillLiveAfterFailure
                {
                    cleanupFailure = failure
                } else {
                    _ = await reapTask?.value
                    _ = await stdoutTask?.value
                    _ = await stderrTask?.value
                    do {
                        guard !(try processInspector.processGroupExists(pid))
                        else {
                            throw CliProcessBackendError
                                .processGroupStillAlive(pid)
                        }
                        registry.unregister(-pid)
                        cleanupFailure = signalOutcome.failure
                    } catch {
                        cleanupFailure = signalOutcome.failure ?? error
                    }
                }
            } else {
                do {
                    try Self.terminateAndReapSpawnedGroup(
                        pid: pid,
                        processGroupID: pid,
                        processInspector: processInspector
                    )
                } catch {
                    cleanupFailure = error
                }
            }
            for closeOperation in [
                { try Self.checkedClose(&stdinRead) },
                { try Self.checkedClose(&stdinWrite) },
                { try Self.checkedClose(&stdoutRead) },
                { try Self.checkedClose(&stdoutWrite) },
                { try Self.checkedClose(&stderrRead) },
                { try Self.checkedClose(&stderrWrite) },
            ] {
                do {
                    try closeOperation()
                } catch {
                    cleanupFailure = cleanupFailure ?? error
                }
            }
            if cleanupFailure != nil {
                throw CliProcessBackendError.processCleanupFailed(
                    "spawned process or pipe cleanup failed"
                )
            }
            throw primaryError
        }
    }

    private func performCancellation() async throws
        -> CliProcessExitEvidenceV1
    {
        let process = try await awaitRegistration()
        markCancellationRequested()
        process.core.stdinTask.cancel()
        try await terminateProcessGroup(process.core.processGroupID)
        return try await Self.awaitCompletion(
            process.completionTask,
            timeout: killGrace
        )
    }

    private func finalize(
        _ core: CliSpawnCore
    ) async throws -> CliProcessExitEvidenceV1 {
        let diagnosticId = diagnosticId
        var successful = false
        RuntimeLifecycleDiagnostics.event(
            .cliFinalizeStarted,
            owner: diagnosticId
        )
        defer {
            RuntimeLifecycleDiagnostics.event(
                .cliFinalizeFinished,
                owner: diagnosticId,
                value: successful ? 0 : 1
            )
        }
        var firstFailure: (any Error)?
        do {
            try await core.stdinTask.value
            RuntimeLifecycleDiagnostics.event(
                .cliStdinFinished,
                owner: diagnosticId,
                value: 0
            )
        } catch {
            RuntimeLifecycleDiagnostics.event(
                .cliStdinFinished,
                owner: diagnosticId,
                value: 1
            )
            if !isCancellationRequested() {
                firstFailure = error as? CliProcessBackendError
                    ?? CliProcessBackendError.processLaunchFailed(
                        "one-shot stdin operation failed"
                    )
            }
            do {
                try await terminateProcessGroup(core.processGroupID)
            } catch {
                firstFailure = firstFailure ?? error
            }
        }

        let reap = await core.reapTask.value
        RuntimeLifecycleDiagnostics.event(
            .cliReaped,
            owner: diagnosticId,
            value: reap.status == nil ? 1 : 0
        )
        let stdoutEOF = await core.stdoutTask.value
        RuntimeLifecycleDiagnostics.event(
            .cliStdoutFinished,
            owner: diagnosticId,
            value: stdoutEOF ? 0 : 1
        )
        let stderrEOF = await core.stderrTask.value
        RuntimeLifecycleDiagnostics.event(
            .cliStderrFinished,
            owner: diagnosticId,
            value: stderrEOF ? 0 : 1
        )
        if let failure = reap.failure {
            firstFailure = firstFailure
                ?? CliProcessBackendError.processCleanupFailed(
                "waitpid: \(failure)"
            )
        }
        if !stdoutEOF, firstFailure == nil {
            firstFailure = CliProcessBackendError.pipeDrainIncomplete(
                "stdout did not reach EOF"
            )
        }
        if !stderrEOF, firstFailure == nil {
            firstFailure = CliProcessBackendError.pipeDrainIncomplete(
                "stderr did not reach EOF"
            )
        }
        do {
            try await terminateProcessGroup(core.processGroupID)
            registry.unregister(-core.processGroupID)
        } catch {
            firstFailure = firstFailure ?? error
        }
        RuntimeLifecycleDiagnostics.event(
            .cliServerStopStarted,
            owner: diagnosticId
        )
        do {
            try await core.server.stopAsync()
            RuntimeLifecycleDiagnostics.event(
                .cliServerStopFinished,
                owner: diagnosticId,
                value: 0
            )
        } catch {
            RuntimeLifecycleDiagnostics.event(
                .cliServerStopFinished,
                owner: diagnosticId,
                value: 1
            )
            firstFailure = firstFailure ?? error
        }
        do {
            try removeCleanupFiles()
        } catch {
            firstFailure = firstFailure ?? error
        }
        if let firstFailure { throw firstFailure }

        let flags = currentSignalFlags()
        let evidence = CliProcessExitEvidenceV1(
            pid: core.pid,
            processGroupID: core.processGroupID,
            status: reap.status ?? -1,
            termSent: flags.term,
            killSent: flags.kill,
            stdoutEOF: stdoutEOF,
            stderrEOF: stderrEOF,
            childReaped: reap.status != nil
        )
        successful = true
        return evidence
    }

    private func removeCleanupFiles() throws {
        for authority in request.spec.cleanupAuthorities {
            do {
                try authority.removeExpectedFile()
            } catch {
                throw CliProcessBackendError.processCleanupFailed(
                    "checked cleanup authority failed"
                )
            }
        }
    }

    private func terminateProcessGroup(_ processGroupID: Int32) async throws {
        if try processInspector.processGroupExists(processGroupID) {
            if claimTermSignal() {
                do {
                    try processInspector.send(
                        signal: SIGTERM,
                        processGroupId: processGroupID
                    )
                } catch {
                    guard !(try processInspector.processGroupExists(
                        processGroupID
                    )) else { throw error }
                }
            }
            if terminationGrace > .zero {
                let clock = ContinuousClock()
                let deadline = clock.now.advanced(by: terminationGrace)
                while clock.now < deadline,
                      try processInspector.processGroupExists(processGroupID)
                {
                    do {
                        try await Task.sleep(for: .milliseconds(10))
                    } catch is CancellationError {
                        // Cancellation requests cleanup; they do not cancel it.
                    } catch {
                        throw error
                    }
                }
            }
        }
        if try processInspector.processGroupExists(processGroupID) {
            if claimKillSignal() {
                do {
                    try processInspector.send(
                        signal: SIGKILL,
                        processGroupId: processGroupID
                    )
                } catch {
                    guard !(try processInspector.processGroupExists(
                        processGroupID
                    )) else { throw error }
                }
            }
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: killGrace)
            while clock.now < deadline,
                  try processInspector.processGroupExists(processGroupID)
            {
                do {
                    try await Task.sleep(for: .milliseconds(10))
                } catch is CancellationError {
                    // Cancellation requests cleanup; they do not cancel it.
                } catch {
                    throw error
                }
            }
        }
        guard !(try processInspector.processGroupExists(processGroupID)) else {
            throw CliProcessBackendError.processGroupStillAlive(
                processGroupID
            )
        }
    }

    private func publishRegistration(_ process: CliRegisteredProcess) {
        lock.lock()
        registration = .ready(process)
        let waiters = registrationWaiters
        registrationWaiters.removeAll()
        lock.unlock()
        for waiter in waiters {
            waiter.resume(returning: process)
        }
    }

    private func failRegistration(_ error: any Error) {
        lock.lock()
        guard case .pending = registration else {
            lock.unlock()
            return
        }
        registration = .failed(error)
        let waiters = registrationWaiters
        registrationWaiters.removeAll()
        lock.unlock()
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }

    private func awaitRegistration() async throws -> CliRegisteredProcess {
        try await withCheckedThrowingContinuation { waiter in
            let snapshot: Registration = lock.withLock {
                switch registration {
                case .pending:
                    registrationWaiters.append(waiter)
                    return .pending
                case .ready, .failed:
                    return registration
                }
            }
            switch snapshot {
            case .pending:
                break
            case .ready(let process):
                waiter.resume(returning: process)
            case .failed(let error):
                waiter.resume(throwing: error)
            }
        }
    }

    private func markCancellationRequested() {
        lock.withLock { cancellationRequested = true }
    }

    private func isCancellationRequested() -> Bool {
        lock.withLock { cancellationRequested }
    }

    private func claimTermSignal() -> Bool {
        lock.withLock {
            guard !termSent else { return false }
            termSent = true
            return true
        }
    }

    private func claimKillSignal() -> Bool {
        lock.withLock {
            guard !killSent else { return false }
            killSent = true
            return true
        }
    }

    private func currentSignalFlags() -> (term: Bool, kill: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (termSent, killSent)
    }

    private static func makePipe() throws -> (Int32, Int32) {
        var descriptors = [Int32](repeating: -1, count: 2)
        let result = descriptors.withUnsafeMutableBufferPointer { buffer in
            Darwin.pipe(buffer.baseAddress!)
        }
        guard result == 0,
              fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) == 0,
              fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) == 0
        else {
            if descriptors[0] >= 0 { _ = Darwin.close(descriptors[0]) }
            if descriptors[1] >= 0 { _ = Darwin.close(descriptors[1]) }
            throw CliProcessBackendError.pipeSetupFailed(
                "pipe CLOEXEC setup failed"
            )
        }
        return (descriptors[0], descriptors[1])
    }

    private static func checkedClose(_ descriptor: inout Int32) throws {
        guard descriptor >= 0 else { return }
        let value = descriptor
        descriptor = -1
        guard Darwin.close(value) == 0 else {
            throw CliProcessBackendError.processCleanupFailed(
                "checked descriptor close failed"
            )
        }
    }

    private static func writeAllStdinCancellable(
        _ data: Data,
        descriptor ownedDescriptor: Int32
    ) async throws {
        var descriptor = ownedDescriptor
        do {
            var offset = 0
            while offset < data.count {
                try Task.checkCancellation()
                let written = data.withUnsafeBytes { bytes in
                    Darwin.write(
                        descriptor,
                        bytes.baseAddress?.advanced(by: offset),
                        bytes.count - offset
                    )
                }
                if written > 0 {
                    offset += written
                    continue
                }
                if written < 0, errno == EINTR { continue }
                if written < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                    do {
                        try await Task.sleep(for: .milliseconds(10))
                    } catch {
                        throw CancellationError()
                    }
                    continue
                }
                throw CliProcessBackendError.processLaunchFailed(
                    errno == EPIPE
                        ? "child closed one-shot stdin"
                        : "one-shot stdin write failed"
                )
            }
            try checkedClose(&descriptor)
        } catch {
            var closeFailure: (any Error)?
            do {
                try checkedClose(&descriptor)
            } catch {
                closeFailure = error
            }
            if let closeFailure { throw closeFailure }
            throw error
        }
    }

    private static func validateSuspendedImage(
        pid: Int32,
        processGroupID: Int32,
        authority: CliExecutableAuthorityV1,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws {
        guard let image = try processInspector.snapshots().first(where: {
            $0.pid == pid
        }),
            image.pid == pid,
            image.processGroupId == processGroupID,
            image.uid == getuid(),
            image.startSeconds > 0,
            image.executablePath == authority.stagedPath,
            image.executableDevice == authority.stagedDevice,
            image.executableInode == authority.stagedInode,
            image.executableHash == authority.executableHash,
            image.designatedRequirement == authority.designatedRequirement,
            image.cdHash == authority.cdHash
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "suspended executable image identity mismatch"
            )
        }
    }

    private static func validateBoardPeer(
        _ pid: Int32,
        authority: EngineBoardBridgeExecutableAuthorityV1,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws {
        guard let image = try processInspector.snapshots().first(where: {
            $0.pid == pid
        }),
            image.pid == pid,
            image.uid == getuid(),
            image.startSeconds > 0,
            image.executablePath == authority.stagedPath,
            image.executableDevice == authority.stagedDevice,
            image.executableInode == authority.stagedInode,
            image.executableHash == authority.executableHash,
            image.designatedRequirement == authority.designatedRequirement,
            image.cdHash == authority.cdHash
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "Board bridge peer identity mismatch"
            )
        }
    }

    private static func terminateAndReapSpawnedGroup(
        pid: Int32,
        processGroupID: Int32,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws {
        let signalOutcome = signalSpawnedGroupForTermination(
            processGroupID: processGroupID,
            processInspector: processInspector
        )
        var firstFailure = signalOutcome.failure
        var status: Int32 = 0
        let options = signalOutcome.groupStillLiveAfterFailure
            ? WNOHANG : 0
        while true {
            let result = waitpid(pid, &status, options)
            if result == pid || (result < 0 && errno == ECHILD) { break }
            if result < 0 && errno == EINTR { continue }
            if result == 0 {
                if firstFailure == nil {
                    firstFailure = CliProcessBackendError
                        .processGroupStillAlive(processGroupID)
                }
                break
            }
            if result < 0 {
                if firstFailure == nil {
                    firstFailure = CliProcessBackendError
                        .processCleanupFailed("spawned child reap failed")
                }
                break
            }
        }
        do {
            if try processInspector.processGroupExists(processGroupID),
               firstFailure == nil
            {
                firstFailure = CliProcessBackendError.processGroupStillAlive(
                    processGroupID
                )
            }
        } catch {
            if firstFailure == nil { firstFailure = error }
        }
        if let firstFailure { throw firstFailure }
    }

    private struct SpawnedGroupSignalOutcome {
        let failure: (any Error)?
        let groupStillLiveAfterFailure: Bool
    }

    private static func signalSpawnedGroupForTermination(
        processGroupID: Int32,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) -> SpawnedGroupSignalOutcome {
        do {
            guard try processInspector.processGroupExists(processGroupID)
            else {
                return SpawnedGroupSignalOutcome(
                    failure: nil,
                    groupStillLiveAfterFailure: false
                )
            }
        } catch {
            return SpawnedGroupSignalOutcome(
                failure: error,
                groupStillLiveAfterFailure: true
            )
        }
        var firstFailure: (any Error)?
        for signal in [SIGKILL, SIGCONT] {
            do {
                try processInspector.send(
                    signal: signal,
                    processGroupId: processGroupID
                )
            } catch let dispatchFailure {
                do {
                    if try processInspector.processGroupExists(
                        processGroupID
                    ), firstFailure == nil {
                        firstFailure = dispatchFailure
                    }
                } catch {
                    if firstFailure == nil {
                        firstFailure = dispatchFailure
                    }
                }
            }
        }
        guard firstFailure != nil else {
            return SpawnedGroupSignalOutcome(
                failure: nil,
                groupStillLiveAfterFailure: false
            )
        }
        do {
            return SpawnedGroupSignalOutcome(
                failure: firstFailure,
                groupStillLiveAfterFailure:
                    try processInspector.processGroupExists(processGroupID)
            )
        } catch {
            return SpawnedGroupSignalOutcome(
                failure: firstFailure ?? error,
                groupStillLiveAfterFailure: true
            )
        }
    }

    private static func validateExecutableAuthority(
        _ authority: CliExecutableAuthorityV1,
        codeSignatureRevalidator:
            any CliProcessCodeSignatureRevalidatingV1
    ) throws {
        try authority.validateCanonical()
        try codeSignatureRevalidator.revalidateCLI(authority)
        let identity = try executableFileIdentity(authority.stagedPath)
        guard identity.hash == authority.executableHash,
              identity.device == authority.stagedDevice,
              identity.inode == authority.stagedInode
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "CLI executable authority drift"
            )
        }
    }

    private static func validateBridgeAuthority(
        _ authority: EngineBoardBridgeExecutableAuthorityV1,
        codeSignatureRevalidator:
            any CliProcessCodeSignatureRevalidatingV1
    ) throws {
        try authority.validateCanonical()
        try codeSignatureRevalidator.revalidateBoardBridge(authority)
        let identity = try executableFileIdentity(authority.stagedPath)
        guard identity.hash == authority.executableHash,
              identity.device == authority.stagedDevice,
              identity.inode == authority.stagedInode
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "Board bridge executable authority drift"
            )
        }
    }

    private static func executableFileIdentity(
        _ path: String
    ) throws -> (hash: String, device: UInt64, inode: UInt64) {
        let descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw CliProcessBackendError.processLaunchFailed(
                "executable authority open failed"
            )
        }
        var descriptorOpen = true
        defer { if descriptorOpen { Darwin.close(descriptor) } }
        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_nlink == 1,
              before.st_uid == getuid(),
              before.st_mode & S_IXUSR != 0
        else {
            throw CliProcessBackendError.processLaunchFailed(
                "executable authority stat failed"
            )
        }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        var byteCount: Int64 = 0
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if count > 0 {
                hasher.update(data: Data(buffer[0..<count]))
                byteCount += Int64(count)
                continue
            }
            if count == 0 { break }
            if errno == EINTR { continue }
            throw CliProcessBackendError.processLaunchFailed(
                "executable authority read failed"
            )
        }
        var after = stat()
        guard Darwin.fstat(descriptor, &after) == 0,
              before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_mode == after.st_mode,
              before.st_uid == after.st_uid,
              before.st_nlink == after.st_nlink,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              byteCount == before.st_size,
              Darwin.close(descriptor) == 0
        else {
            descriptorOpen = false
            throw CliProcessBackendError.processLaunchFailed(
                "executable authority changed while hashing"
            )
        }
        descriptorOpen = false
        return (
            hash: hasher.finalize().map {
                String(format: "%02x", $0)
            }.joined(),
            device: UInt64(before.st_dev),
            inode: UInt64(before.st_ino)
        )
    }

    private static func setNonBlocking(_ fd: Int32) throws {
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0,
              fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0,
              fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else {
            throw CliProcessBackendError.pipeSetupFailed(
                "nonblocking pipe setup failed"
            )
        }
    }

    private static func checkSpawnSetup(_ code: Int32) throws {
        guard code == 0 else {
            throw CliProcessBackendError.processLaunchFailed(
                "process spawn setup failed"
            )
        }
    }

    private static func makeCStringVector(
        _ strings: [String]
    ) throws -> [UnsafeMutablePointer<CChar>?] {
        var result: [UnsafeMutablePointer<CChar>?] = []
        result.reserveCapacity(strings.count + 1)
        for string in strings {
            guard let duplicate = strdup(string) else {
                freeCStringVector(result)
                throw CliProcessBackendError.processLaunchFailed(
                    "unable to allocate process argument"
                )
            }
            result.append(duplicate)
        }
        result.append(nil)
        return result
    }

    private static func freeCStringVector(
        _ vector: [UnsafeMutablePointer<CChar>?]
    ) {
        for case let pointer? in vector {
            free(pointer)
        }
    }

    private static func decodeWaitStatus(_ raw: Int32) -> Int32 {
        let signal = raw & 0x7f
        if signal == 0 {
            return (raw >> 8) & 0xff
        }
        return 128 + signal
    }

    private static func awaitCompletion(
        _ task: Task<CliProcessExitEvidenceV1, Error>,
        timeout: Duration
    ) async throws -> CliProcessExitEvidenceV1 {
        try await withThrowingTaskGroup(
            of: CliProcessExitEvidenceV1.self
        ) { group in
            group.addTask { try await task.value }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CliProcessBackendError.processCleanupFailed(
                    "process did not exit within kill grace"
                )
            }
            guard let first = try await group.next() else {
                throw CliProcessBackendError.processCleanupFailed(
                    "process completion race produced no result"
                )
            }
            group.cancelAll()
            return first
        }
    }

    private static func drainStdout(
        fd: Int32,
        reapState: CliProcessReapState,
        grace: Duration,
        continuation:
            AsyncThrowingStream<CliProcessFrameV1, Error>.Continuation,
        diagnosticOwner: UUID
    ) async -> Bool {
        RuntimeLifecycleDiagnostics.event(
            .cliStdoutDrainEntered, owner: diagnosticOwner
        )
        var didLogFirstBytes = false
        var didLogFirstLine = false
        var lineBuffer = Data()
        let reachedEOF = await drainPipe(
            fd: fd,
            reapState: reapState,
            grace: grace,
            onData: { data in
                if !didLogFirstBytes {
                    RuntimeLifecycleDiagnostics.event(
                        .cliStdoutFirstBytes,
                        owner: diagnosticOwner, value: data.count
                    )
                    didLogFirstBytes = true
                }
                lineBuffer.append(data)
                while let newline = lineBuffer.firstIndex(
                    of: UInt8(ascii: "\n")
                ) {
                    let line = Data(lineBuffer[..<newline])
                    lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
                    let yieldResult = continuation.yield(
                        .stdoutLine(String(decoding: line, as: UTF8.self))
                    )
                    if !didLogFirstLine {
                        didLogFirstLine = true
                        let outcome: Int
                        switch yieldResult {
                        case .enqueued: outcome = 0
                        case .dropped: outcome = 1
                        case .terminated: outcome = 2
                        @unknown default: outcome = 3
                        }
                        RuntimeLifecycleDiagnostics.event(
                            .cliStdoutFirstLineYielded,
                            owner: diagnosticOwner, value: outcome
                        )
                    }
                }
            },
            onFinish: {
                if !lineBuffer.isEmpty {
                    let yieldResult = continuation.yield(
                        .stdoutLine(
                            String(decoding: lineBuffer, as: UTF8.self)
                        )
                    )
                    lineBuffer.removeAll()
                    if !didLogFirstLine {
                        didLogFirstLine = true
                        let outcome: Int
                        switch yieldResult {
                        case .enqueued: outcome = 0
                        case .dropped: outcome = 1
                        case .terminated: outcome = 2
                        @unknown default: outcome = 3
                        }
                        RuntimeLifecycleDiagnostics.event(
                            .cliStdoutFirstLineYielded,
                            owner: diagnosticOwner, value: outcome
                        )
                    }
                }
            }
        )
        return Darwin.close(fd) == 0 && reachedEOF
    }

    private static func drainStderr(
        fd: Int32,
        reapState: CliProcessReapState,
        grace: Duration,
        continuation:
            AsyncThrowingStream<CliProcessFrameV1, Error>.Continuation
    ) async -> Bool {
        let reachedEOF = await drainPipe(
            fd: fd,
            reapState: reapState,
            grace: grace,
            onData: { continuation.yield(.stderr($0)) },
            onFinish: {}
        )
        return Darwin.close(fd) == 0 && reachedEOF
    }

    private static func drainPipe(
        fd: Int32,
        reapState: CliProcessReapState,
        grace: Duration,
        onData: (Data) -> Void,
        onFinish: () -> Void
    ) async -> Bool {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var exitObservedAt: ContinuousClock.Instant?
        var backoff: Duration = .milliseconds(10)
        while true {
            if reapState.exited {
                if exitObservedAt == nil { exitObservedAt = .now }
                if let exitObservedAt,
                   exitObservedAt.duration(to: .now) >= grace
                {
                    onFinish()
                    return false
                }
            }
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(fd, $0.baseAddress, $0.count)
            }
            if count > 0 {
                onData(Data(buffer[0..<count]))
                backoff = .milliseconds(10)
                if reapState.exited {
                    if exitObservedAt == nil { exitObservedAt = .now }
                    if let exitObservedAt,
                       exitObservedAt.duration(to: .now) >= grace
                    {
                        onFinish()
                        return false
                    }
                }
                continue
            }
            if count == 0 {
                onFinish()
                return true
            }
            if errno == EINTR { continue }
            if errno != EAGAIN, errno != EWOULDBLOCK {
                onFinish()
                return false
            }

            do {
                try await Task.sleep(for: backoff)
            } catch {
                onFinish()
                return false
            }
            backoff = min(backoff * 2, .milliseconds(100))
        }
    }
}
