import Darwin
import Foundation
import Testing
@testable import AgentLoopCore

@Test func cliEngineCommandBuilderPinsSafeFlags() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("cli-builder-safe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }

    let builder = CliEngineCommandBuilderV1()
    let codex = try builder.buildCodex(
        p1f1dCLIInput(
            command: "/tmp/fake-codex",
            configURL: base.appendingPathComponent("unused.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession)
        )
    )
    let claude = try builder.buildClaude(
        p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: base.appendingPathComponent("claude.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession)
        )
    )
    let banned = [
        "--dangerously-bypass-approvals-and-sandbox",
        "--dangerously-bypass-hook-trust",
        "--dangerously-skip-permissions",
        "--allow-dangerously-skip-permissions",
        "--yolo",
        "bypassPermissions",
        "danger-full-access",
    ]
    for spec in [codex, claude] {
        let rendered = ([spec.command] + spec.arguments)
            .joined(separator: "\n")
        for value in banned {
            #expect(!rendered.contains(value))
        }
    }
}

@Test func cliEngineCommandBuilderMapsSandboxWithoutEscalation() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("cli-builder-sandbox-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }

    let builder = CliEngineCommandBuilderV1()
    let codexReadOnly = try builder.buildCodex(
        p1f1dCLIInput(
            command: "/tmp/fake-codex",
            configURL: base.appendingPathComponent("unused-read.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession),
            sandbox: "read-only"
        )
    )
    #expect(
        p1f1dValues(after: "-s", in: codexReadOnly.arguments)
            == ["read-only"]
    )
    #expect(throws: EngineContextValidationErrorV1()) {
        _ = try p1f1dCLIInput(
            command: "/tmp/fake-codex",
            configURL: base.appendingPathComponent("unused-write.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession),
            sandbox: "workspace-write"
        )
    }
    #expect(codexReadOnly.arguments.contains("-m"))
    #expect(
        codexReadOnly.arguments.contains {
            $0.contains("model_reasoning_effort")
        }
    )

    let claudeReadOnly = try builder.buildClaude(
        p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: base.appendingPathComponent("claude-read.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession),
            sandbox: "read-only"
        )
    )
    #expect(
        p1f1dValues(
            after: "--permission-mode",
            in: claudeReadOnly.arguments
        ) == ["dontAsk"]
    )
    #expect(throws: EngineContextValidationErrorV1()) {
        _ = try p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: base.appendingPathComponent("claude-write.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession),
            sandbox: "workspace-write"
        )
    }
}

@Test func cliRuntimeRejectsUnsafeSandboxValues() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("cli-builder-reject-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }

    let harness = try CliMechanicsHarness(identity: "129")
    defer { harness.remove() }
    let executableAuthority = try p1f1dCLIExecutableAuthority(
        kind: .cliCodex,
        stagedPath: "/tmp/fake-codex"
    )

    #expect(throws: EngineContextValidationErrorV1()) {
        _ = try CliEngineRuntimeConfigurationV1(
            command: executableAuthority.stagedPath,
            cliExecutableAuthority: executableAuthority,
            sandbox: "danger-full-access",
            reasoningEffort: "high",
            bridgeExecutableAuthority: try p1f1dCLIBridgeAuthority(),
            boardSocketDirectoryAuthority:
                harness.socketDirectoryAuthority,
            claudeConfigDirectory: base,
            ranchSessionId: p1f1dCLIRanchSession
        )
    }

    #expect(throws: EngineContextValidationErrorV1()) {
        _ = try p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: base.appendingPathComponent("must-not-exist.json"),
            session: .first(ranchUUID: p1f1dCLIRanchSession),
            sandbox: "bypassPermissions"
        )
    }
    #expect(
        !FileManager.default.fileExists(
            atPath: base.appendingPathComponent("must-not-exist.json").path
        )
    )
}

@Test func cliProviderParserExtractsProgressAndUsageFromJSONL() throws {
    let sessionId = "00000000-0000-4000-8000-000000000104"
    let parser = try ClaudeCliEventParserV1(
        expectedSessionId: sessionId
    )
    let events = try parser.parse(
        line:
            #"{"type":"assistant","session_id":"00000000-0000-4000-8000-000000000104","message":{"role":"assistant","content":[{"type":"text","text":"hello"}],"usage":{"input_tokens":3,"output_tokens":5,"cache_read_input_tokens":2}}}"#
    )
    #expect(
        events == [
            .progress(message: "hello"),
            .usage(
                EngineUsageV1(
                    inputTokens: 3,
                    outputTokens: 5,
                    cacheReadTokens: 2,
                    costMicros: 0
                )
            ),
        ]
    )
}

@Test func cliAdapterBlocksWhenProcessExitsWithoutBoardTerminator()
    async throws
{
    let terminal = P1F1DCLIAdapterTerminalSink()
    let board = P1F1DCLIAdapterBoardSink()
    let progress = P1F1DCLIAdapterProgressSink()
    let driver = P1F1DCLIAdapterProcessDriver(
        board: board,
        progress: progress,
        frames: [
            .stdoutLine(
                #"{"type":"thread.started","thread_id":"codex-thread-114"}"#
            ),
            .stdoutLine(
                #"{"type":"item.completed","item":{"id":"i114","type":"agent_message","text":"fake progress"}}"#
            ),
            .stdoutLine(
                #"{"type":"turn.completed","usage":{"input_tokens":7,"cached_input_tokens":0,"output_tokens":9}}"#
            ),
            .exited(0),
        ]
    )
    let executionId = "00000000-0000-4000-8000-000000000114"
    let (profile, request) = try p1f1dCLIAdapterRequest(
        kind: .cliCodex,
        executionId: executionId,
        externalSessionId: nil
    )
    let configurationFixture = try p1f1dCLIAdapterConfiguration(
        kind: .cliCodex
    )
    defer { p1f1dCLIAdapterRecordCleanup(configurationFixture) }
    let adapter = CliEngineAdapter(
        profile: profile,
        descriptor: p1f1dCLIAdapterDescriptor(kind: .cliCodex),
        processDriver: driver,
        configuration: configurationFixture.configuration,
        commandBuilder: CliEngineCommandBuilderV1(),
        codexParser: CodexCliEventParserV1(),
        claudeParserFactory: {
            try ClaudeCliEventParserV1(expectedSessionId: $0)
        },
        sanitizer: CliEngineSecretSanitizerV1(),
        context: try p1f1dCLIAdapterContext(),
        workspace: try p1f1dCLIAdapterWorkspace(),
        boundCapabilityTools: p1f1dCLIBoundCapabilityTools(),
        resolvedSessionRef: nil,
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress
    )
    var payloads: [EngineExecutionEventPayloadV1] = []
    for try await payload in adapter.execute(request: request) {
        payloads.append(payload)
    }

    #expect(payloads.contains(.progress(message: "fake progress")))
    #expect(
        payloads.contains(
            .usage(
                EngineUsageV1(
                    inputTokens: 7,
                    outputTokens: 9,
                    cacheReadTokens: 0,
                    costMicros: 0
                )
            )
        )
    )
    let intents = await terminal.snapshot()
    #expect(intents.count == 1)
    guard case let .blocked(subtype, reasonCode, _) = intents.first else {
        Issue.record("EOF without Board terminal did not fail closed")
        return
    }
    #expect(subtype == .engineProtocolError)
    #expect(reasonCode == "engine_protocol_error")
    #expect(await board.snapshot().isEmpty)
}

@Test func cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe()
    async throws
{
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliMechanicsHarness(identity: "152")
    defer { harness.remove() }
    let request = try harness.request(
        command: "/bin/sh",
        arguments: [
            "-c",
            "(sleep 0.3) >&2 & printf '%s\\n' 'parent-exited'; exit 0",
        ]
    )
    let signatureRevalidator = CliMechanicsSignatureRevalidator(
        expectedCLI: request.cliExecutableAuthority,
        expectedBoardBridge: request.bridgeExecutableAuthority
    )
    let backend = try CliProcessBackend(
        pipeDrainGrace: .milliseconds(50),
        processInspector: harness.processInspector,
        codeSignatureRevalidator: signatureRevalidator
    )
    let completion = StreamCompletion<[CliProcessFrameV1]>()
    let consumer = Task {
        do {
            var frames: [CliProcessFrameV1] = []
            for try await frame in backend.launch(request) {
                frames.append(frame)
            }
            await completion.finish(.success(frames))
        } catch {
            await completion.finish(.failure(error))
        }
    }

    var result: Result<[CliProcessFrameV1], Error>?
    for _ in 0..<200 {
        if let value = await completion.value() {
            result = value
            break
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    guard let result else {
        consumer.cancel()
        Issue.record("CLI mechanics stream did not finish before watchdog")
        return
    }
    switch result {
    case .success:
        Issue.record("held pipe cleanup was reported as certain")
    case let .failure(error):
        guard let backendError = error as? CliProcessBackendError,
              case .pipeDrainIncomplete = backendError
        else {
            throw error
        }
    }
    consumer.cancel()
    #expect(
        !FileManager.default.fileExists(atPath: harness.socketURL.path)
    )
    #expect(signatureRevalidator.snapshot() == [.cli, .boardBridge])
}

@Test func cliProcessBackendCapturesFinalLineWithoutNewline() async throws {
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliMechanicsHarness(identity: "213")
    defer { harness.remove() }
    let request = try harness.request(
        command: "/bin/sh",
        arguments: ["-c", "printf '%s' 'final-line'; exit 0"]
    )
    let signatureRevalidator = CliMechanicsSignatureRevalidator(
        expectedCLI: request.cliExecutableAuthority,
        expectedBoardBridge: request.bridgeExecutableAuthority
    )
    let backend = try CliProcessBackend(
        processInspector: harness.processInspector,
        codeSignatureRevalidator: signatureRevalidator
    )
    var frames: [CliProcessFrameV1] = []
    for try await frame in backend.launch(request) {
        frames.append(frame)
    }

    #expect(frames.contains(.stdoutLine("final-line")))
    #expect(frames.contains(.exited(0)))
    #expect(
        !FileManager.default.fileExists(atPath: harness.socketURL.path)
    )
    #expect(signatureRevalidator.snapshot() == [.cli, .boardBridge])
}
@Test func cliPipeDrainRereadsAfterExitObserved() async {
    let clock = ContinuousClock()
    var reads: [CliPipeDrain.ReadResult] = [
        .wouldBlock,
        .data(Data("{\"usage\":{\"input_tokens\":3,\"output_tokens\":5}}\n".utf8)),
        .wouldBlock,
    ]
    var readCount = 0
    var received: [Data] = []

    await CliPipeDrain.drain(
        grace: .seconds(1),
        readChunk: {
            readCount += 1
            guard !reads.isEmpty else { return .wouldBlock }
            return reads.removeFirst()
        },
        isExited: { true },
        sleep: { _ in },
        now: { clock.now },
        onData: { received.append($0) },
        onReadFailure: { _ in }
    )

    #expect(readCount >= 3)
    #expect(received == [Data("{\"usage\":{\"input_tokens\":3,\"output_tokens\":5}}\n".utf8)])
}

@Test func cliPipeDrainBacksOffPollingWhileSilent() async {
    let clock = ContinuousClock()
    var exitChecks = 0
    var silentSleeps: [Duration] = []

    await CliPipeDrain.drain(
        grace: .seconds(1),
        readChunk: { .wouldBlock },
        isExited: {
            exitChecks += 1
            return exitChecks > 6
        },
        sleep: { silentSleeps.append($0) },
        now: { clock.now },
        onData: { _ in },
        onReadFailure: { _ in }
    )

    #expect(silentSleeps == [
        .milliseconds(10),
        .milliseconds(20),
        .milliseconds(40),
        .milliseconds(80),
        .milliseconds(100),
        .milliseconds(100),
    ])

    var resetReads: [CliPipeDrain.ReadResult] = [
        .wouldBlock,
        .wouldBlock,
        .data(Data("x".utf8)),
        .wouldBlock,
        .wouldBlock,
    ]
    var resetExitChecks = 0
    var resetSleeps: [Duration] = []

    await CliPipeDrain.drain(
        grace: .seconds(1),
        readChunk: {
            guard !resetReads.isEmpty else { return .wouldBlock }
            return resetReads.removeFirst()
        },
        isExited: {
            resetExitChecks += 1
            return resetExitChecks > 4
        },
        sleep: { resetSleeps.append($0) },
        now: { clock.now },
        onData: { _ in },
        onReadFailure: { _ in }
    )

    #expect(resetSleeps == [.milliseconds(10), .milliseconds(20), .milliseconds(10)])
}

@Test func cliPipeDrainStopsAtGraceDeadlineWhileDataFlows() async {
    let clock = ContinuousClock()
    let start = clock.now
    var tick = 0
    var received = 0

    await CliPipeDrain.drain(
        grace: .milliseconds(250),
        readChunk: { .data(Data("x".utf8)) },
        isExited: { true },
        sleep: { _ in },
        now: {
            defer { tick += 1 }
            return start.advanced(by: .milliseconds(100 * tick))
        },
        onData: { _ in received += 1 },
        onReadFailure: { _ in }
    )

    #expect(received >= 1)
    #expect(received <= 4)
}

@Test func cliProcessBackendCancellationEscalatesAfterGrace()
    async throws
{
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliMechanicsHarness(identity: "346")
    defer { harness.remove() }
    let request = try harness.request(
        command: "/bin/sh",
        arguments: [
            "-c",
            "trap '' TERM; printf '%s\\n' 'ready'; while :; do sleep 1; done",
        ]
    )
    let signatureRevalidator = CliMechanicsSignatureRevalidator(
        expectedCLI: request.cliExecutableAuthority,
        expectedBoardBridge: request.bridgeExecutableAuthority
    )
    let backend = try CliProcessBackend(
        terminationGrace: .milliseconds(50),
        killGrace: .seconds(1),
        pipeDrainGrace: .seconds(1),
        processInspector: harness.processInspector,
        codeSignatureRevalidator: signatureRevalidator
    )
    _ = await LoginShellEnvironment.shared.environment()
    let frames = CliMechanicsFrameRecorder()
    let consumer = Task {
        do {
            for try await frame in backend.launch(request) {
                await frames.append(frame)
            }
            await frames.finish()
        } catch {
            await frames.finish(error: error)
        }
    }
    try await frames.waitForStdout("ready")

    let evidence = try await backend.cancel(executionId: request.executionId)
    await consumer.value

    #expect(evidence.termSent)
    #expect(evidence.killSent)
    #expect(evidence.stdoutEOF)
    #expect(evidence.stderrEOF)
    #expect(evidence.childReaped)
    #expect(await frames.failure() == nil)
    #expect(
        !FileManager.default.fileExists(atPath: harness.socketURL.path)
    )
    #expect(signatureRevalidator.snapshot() == [.cli, .boardBridge])
}

@Test func cliProcessBackendCancellationReturnsCheckedEvidence()
    async throws
{
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliMechanicsHarness(identity: "372")
    defer { harness.remove() }
    let request = try harness.request(
        command: "/bin/sh",
        arguments: [
            "-c",
            "printf '%s\\n' 'ready'; exec /bin/sleep 30",
        ]
    )
    let signatureRevalidator = CliMechanicsSignatureRevalidator(
        expectedCLI: request.cliExecutableAuthority,
        expectedBoardBridge: request.bridgeExecutableAuthority
    )
    let backend = try CliProcessBackend(
        terminationGrace: .seconds(1),
        killGrace: .seconds(1),
        pipeDrainGrace: .seconds(1),
        processInspector: harness.processInspector,
        codeSignatureRevalidator: signatureRevalidator
    )
    _ = await LoginShellEnvironment.shared.environment()
    let frames = CliMechanicsFrameRecorder()
    let consumer = Task {
        do {
            for try await frame in backend.launch(request) {
                await frames.append(frame)
            }
            await frames.finish()
        } catch {
            await frames.finish(error: error)
        }
    }
    try await frames.waitForStdout("ready")

    let evidence = try await backend.cancel(executionId: request.executionId)
    await consumer.value

    #expect(evidence.pid > 0)
    #expect(evidence.processGroupID == evidence.pid)
    #expect(evidence.termSent)
    #expect(!evidence.killSent)
    #expect(evidence.stdoutEOF)
    #expect(evidence.stderrEOF)
    #expect(evidence.childReaped)
    #expect(await frames.failure() == nil)
    #expect(signatureRevalidator.snapshot() == [.cli, .boardBridge])
}

@Test func cliBackendLiveSpikeRunsMechanicsOnlyWhenEnabled() async throws {
    guard ProcessInfo.processInfo.environment["AGENTLOOP_CLI_SPIKE"] == "1"
    else { return }
    guard agentLoopCanBindListenerSocket() else { return }
    let harness = try CliMechanicsHarness(identity: "408")
    defer { harness.remove() }
    let backend = try CliProcessBackend(
        processInspector: harness.processInspector
    )
    let request = try harness.request(
        command: "codex",
        arguments: ["--version"]
    )
    var frames: [CliProcessFrameV1] = []
    for try await frame in backend.launch(request) {
        frames.append(frame)
    }
    #expect(frames.contains(.exited(0)))
}

private final class CliMechanicsProcessInspector:
    EngineRuntimeProcessInspectingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private var authority: CliExecutableAuthorityV1?

    func select(_ authority: CliExecutableAuthorityV1) {
        lock.withLock { self.authority = authority }
    }

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        guard let authority = lock.withLock({ authority }) else {
            throw EngineContextValidationErrorV1()
        }
        var pids = [pid_t](repeating: 0, count: 512)
        let count = pids.withUnsafeMutableBytes { bytes in
            proc_listchildpids(
                getpid(),
                bytes.baseAddress,
                Int32(bytes.count)
            )
        }
        guard count >= 0, Int(count) <= pids.count else {
            throw EngineContextValidationErrorV1()
        }
        return pids.prefix(Int(count)).compactMap { pid in
            guard pid > 0 else { return nil }
            let pgid = getpgid(pid)
            guard pgid > 0 else { return nil }
            return EngineRuntimeProcessSnapshotV1(
                pid: pid,
                processGroupId: pgid,
                uid: getuid(),
                startSeconds: 1,
                startMicroseconds: 0,
                executablePath: authority.stagedPath,
                executableDevice: authority.stagedDevice,
                executableInode: authority.stagedInode,
                executableHash: authority.executableHash,
                designatedRequirement: authority.designatedRequirement,
                cdHash: authority.cdHash
            )
        }
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        guard Darwin.kill(-processGroupId, signal) == 0 || errno == ESRCH else {
            throw EngineContextValidationErrorV1()
        }
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        if Darwin.kill(-processGroupId, 0) == 0 { return true }
        if errno == ESRCH { return false }
        if errno == EPERM { return true }
        throw EngineContextValidationErrorV1()
    }
}

private enum CliMechanicsSignatureCall: Sendable, Equatable {
    case cli
    case boardBridge
}

private final class CliMechanicsSignatureRevalidator:
    CliProcessCodeSignatureRevalidatingV1, @unchecked Sendable
{
    private let expectedCLI: CliExecutableAuthorityV1
    private let expectedBoardBridge: EngineBoardBridgeExecutableAuthorityV1
    private let lock = NSLock()
    private var calls: [CliMechanicsSignatureCall] = []

    init(
        expectedCLI: CliExecutableAuthorityV1,
        expectedBoardBridge: EngineBoardBridgeExecutableAuthorityV1
    ) {
        self.expectedCLI = expectedCLI
        self.expectedBoardBridge = expectedBoardBridge
    }

    func revalidateCLI(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        try authority.validateCanonical()
        guard authority == expectedCLI else {
            throw EngineContextValidationErrorV1()
        }
        try record(.cli, expectedPrefix: [])
    }

    func revalidateBoardBridge(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws {
        try authority.validateCanonical()
        guard authority == expectedBoardBridge else {
            throw EngineContextValidationErrorV1()
        }
        try record(.boardBridge, expectedPrefix: [.cli])
    }

    func snapshot() -> [CliMechanicsSignatureCall] {
        lock.withLock { calls }
    }

    private func record(
        _ call: CliMechanicsSignatureCall,
        expectedPrefix: [CliMechanicsSignatureCall]
    ) throws {
        try lock.withLock {
            guard calls == expectedPrefix else {
                throw EngineContextValidationErrorV1()
            }
            calls.append(call)
        }
    }
}

private struct CliMechanicsHarness {
    let base: URL
    let workspace: URL
    let socketURL: URL
    let executionId: String
    let socketDirectoryAuthority: EngineBoardSocketDirectoryAuthorityV1
    let processInspector = CliMechanicsProcessInspector()

    init(identity: String) throws {
        let suffix = String(repeating: "0", count: 12 - identity.count)
            + identity
        executionId = "00000000-0000-4000-8000-\(suffix)"
        base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(
                "c-\(identity)-\(UUID().uuidString.prefix(4))",
                isDirectory: true
            )
        workspace = base.appendingPathComponent(
            "workspace",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: base.path
        )
        let descriptor = base.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var information = stat()
        guard Darwin.fstat(descriptor, &information) == 0 else {
            _ = Darwin.close(descriptor)
            throw EngineContextValidationErrorV1()
        }
        socketDirectoryAuthority = try EngineBoardSocketDirectoryAuthorityV1(
            directoryURL: try p1f1CanonicalDirectoryURL(descriptor),
            ownedDescriptor: descriptor,
            device: UInt64(information.st_dev),
            inode: UInt64(information.st_ino),
            uid: UInt32(information.st_uid),
            mode: UInt16(information.st_mode & mode_t(0o777)),
            ownerIdentityHash: String(repeating: "a", count: 64),
            bootId: executionId
        )
        socketURL = try BoardToolServer.makeSocketURL(
            directoryAuthority: socketDirectoryAuthority,
            executionId: executionId
        )
    }

    func request(
        command: String,
        arguments: [String],
        cleanupURLs: [URL] = []
    ) throws -> CliProcessLaunchRequestV1 {
        let sourcePath: String
        if command.contains("/") {
            sourcePath = URL(fileURLWithPath: command)
                .resolvingSymlinksInPath().standardizedFileURL.path
        } else {
            guard let path = ProcessInfo.processInfo.environment["PATH"],
                  let found = path.split(separator: ":").lazy.map({
                      URL(fileURLWithPath: String($0), isDirectory: true)
                          .appendingPathComponent(command)
                  }).first(where: {
                      FileManager.default.isExecutableFile(atPath: $0.path)
                  })
            else {
                throw EngineContextValidationErrorV1()
            }
            sourcePath = found.resolvingSymlinksInPath()
                .standardizedFileURL.path
        }
        let stagedDirectory = base.appendingPathComponent(
            "staged-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: stagedDirectory,
            withIntermediateDirectories: false
        )
        let staged = stagedDirectory.appendingPathComponent("executable")
        if command == "/bin/sh" {
            try Data("#!/bin/sh\nexec /bin/sh \"$@\"\n".utf8).write(
                to: staged,
                options: .atomic
            )
        } else {
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: sourcePath),
                to: staged
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: staged.path
        )
        var info = stat()
        guard staged.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
            throw EngineContextValidationErrorV1()
        }
        let hash = CanonicalJSONV1.sha256Hex(try Data(contentsOf: staged))
        let authority = try CliExecutableAuthorityV1(
            kind: .cliCodex,
            command: "codex",
            commandSourcePath: sourcePath,
            commandSourceHash: hash,
            resolvedExecutablePath: sourcePath,
            stagedPath: staged.path,
            executableHash: hash,
            designatedRequirement: "anchor apple generic and identifier mechanics.fixture",
            teamIdentifier: "2DC432GLL2",
            cdHash: String(repeating: "a", count: 40),
            stagedDevice: UInt64(info.st_dev),
            stagedInode: UInt64(info.st_ino)
        )
        processInspector.select(authority)
        let bridgeAuthority = try EngineBoardBridgeExecutableAuthorityV1(
            sourcePath: sourcePath,
            stagedPath: staged.path,
            executableHash: hash,
            designatedRequirement: "anchor apple generic and identifier com.muzi.agentloop.board-bridge",
            teamIdentifier: "2DC432GLL2",
            cdHash: String(repeating: "a", count: 40),
            stagedDevice: UInt64(info.st_dev),
            stagedInode: UInt64(info.st_ino)
        )
        let definitions: [ToolDef] = [
            .completeCard, .blockCard, .addProgressNote, .askUser,
        ]
        return try CliProcessLaunchRequestV1(
            executionId: executionId,
            spec: CliCommandSpec(
                command: staged.path,
                arguments: arguments,
                environment: [:],
                stdinBytes: Data("mechanics one-shot stdin".utf8),
                cleanupURLs: cleanupURLs
            ),
            cliExecutableAuthority: authority,
            workspaceURL: workspace,
            boundCapabilityTools: EngineBoundCapabilityToolsV1(
                logicalDefinitions: definitions,
                capabilityTools: []
            ),
            bridgeExecutableAuthority: bridgeAuthority,
            boardSocketDirectoryAuthority: socketDirectoryAuthority,
            boardSocketBasename: socketURL.lastPathComponent,
            boardToken: String(repeating: "a", count: 64),
            boardCardId: p1f1dCLICard,
            boardTerminalSink: P1F1DCLIAdapterBoardSink(),
            progressSink: P1F1DCLIAdapterProgressSink()
        )
    }

    func remove() {
        do {
            try socketDirectoryAuthority.close()
        } catch {
            Issue.record("mechanics socket authority close failed")
        }
        try? FileManager.default.removeItem(at: base)
    }
}

private actor CliMechanicsFrameRecorder {
    private var frames: [CliProcessFrameV1] = []
    private var storedError: (any Error)?
    private var didFinish = false

    func append(_ frame: CliProcessFrameV1) {
        frames.append(frame)
    }

    func finish(error: (any Error)? = nil) {
        storedError = error
        didFinish = true
    }

    func waitForStdout(_ expected: String) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !frames.contains(.stdoutLine(expected)),
              !didFinish,
              ContinuousClock.now < deadline
        {
            try await Task.sleep(for: .milliseconds(20))
        }
        guard frames.contains(.stdoutLine(expected)) else {
            if let storedError { throw storedError }
            throw CliProcessBackendError.processLaunchFailed(
                "process did not become ready"
            )
        }
    }

    func failure() -> String? {
        storedError.map { String(describing: $0) }
    }
}
private actor StreamCompletion<Value> {
    private var stored: Result<Value, Error>?

    func finish(_ result: Result<Value, Error>) {
        stored = result
    }

    func value() -> Result<Value, Error>? {
        stored
    }
}

private let p1f1dCLIWorkspace = URL(
    fileURLWithPath: "/tmp/p1f1d-cli-workspace"
)
private let p1f1dCLISocket = URL(
    fileURLWithPath: "/tmp/s-0123456789abcdef.sock"
)
private let p1f1dCLIBridge = "/tmp/AgentLoopBoardBridge"
private let p1f1dCLICard = "20000000-0000-4000-8000-000000000072"
private let p1f1dCLIRanchSession = "30000000-0000-4000-8000-000000000072"
private let p1f1dCLIToken = String(repeating: "b", count: 64)
private let p1f1dCLITools = [
    "add_progress_note", "ask_user", "block_card", "complete_card",
]

private func p1f1dCLIBoundCapabilityTools()
    -> EngineBoundCapabilityToolsV1
{
    EngineBoundCapabilityToolsV1(
        logicalDefinitions: [
            .completeCard, .blockCard, .addProgressNote, .askUser,
        ],
        capabilityTools: []
    )
}
private let p1f1dCLIPrompt = "Contract: exact P1-F1D"
private let p1f1dCLIModel = "gpt-test"

private func p1f1dCLIExecutableAuthority(
    kind: RuntimeProfileKind,
    stagedPath: String,
    generation: UInt64 = 72
) throws -> CliExecutableAuthorityV1 {
    try CliExecutableAuthorityV1(
        kind: kind,
        command: kind == .cliCodex ? "codex" : "claude",
        commandSourcePath: "/fixtures/\(kind.rawValue)/command",
        commandSourceHash: String(repeating: "1", count: 64),
        resolvedExecutablePath: "/fixtures/\(kind.rawValue)/native",
        stagedPath: stagedPath,
        executableHash: String(repeating: generation == 72 ? "2" : "3", count: 64),
        designatedRequirement: "anchor apple generic and identifier fixture.\(kind.rawValue)",
        teamIdentifier: kind == .cliCodex ? "2DC432GLL2" : "Q6L2SF6YDW",
        cdHash: String(repeating: generation == 72 ? "a" : "b", count: 40),
        stagedDevice: generation,
        stagedInode: generation + 1
    )
}

private func p1f1dCLIBridgeAuthority() throws
    -> EngineBoardBridgeExecutableAuthorityV1
{
    try EngineBoardBridgeExecutableAuthorityV1(
        sourcePath: "/fixtures/AgentLoopBoardBridge",
        stagedPath: p1f1dCLIBridge,
        executableHash: String(repeating: "4", count: 64),
        designatedRequirement: "anchor apple generic and identifier com.muzi.agentloop.board-bridge",
        teamIdentifier: "2DC432GLL2",
        cdHash: String(repeating: "c", count: 40),
        stagedDevice: 74,
        stagedInode: 75
    )
}

private func p1f1dCLIInput(
    command: String,
    configURL: URL,
    session: CliEngineSessionCommandV1,
    sandbox: String = "read-only",
    prompt: String = p1f1dCLIPrompt,
    boardSocketURL: URL = p1f1dCLISocket
) throws -> CliEngineCommandInputV1 {
    let kind: RuntimeProfileKind = command.contains("claude")
        ? .cliClaude : .cliCodex
    let executableAuthority = try p1f1dCLIExecutableAuthority(
        kind: kind,
        stagedPath: command
    )
    return try CliEngineCommandInputV1(
        command: command,
        cliExecutableAuthority: executableAuthority,
        workspaceURL: p1f1dCLIWorkspace,
        sandbox: sandbox,
        model: p1f1dCLIModel,
        reasoningEffort: "high",
        prompt: prompt,
        bridgeExecutableAuthority: p1f1dCLIBridgeAuthority(),
        boardSocketURL: boardSocketURL,
        boardToken: p1f1dCLIToken,
        boardCardId: p1f1dCLICard,
        toolNames: p1f1dCLITools,
        claudeConfigURL: configURL,
        session: session
    )
}

private let p1f1dCodexConfigPairs = [
    "model_reasoning_effort=\"high\"",
    "approval_policy=\"never\"",
    "web_search=\"disabled\"",
    "tools.web_search=false",
    "features.shell_tool=false",
    "features.apps=false",
    "apps._default.enabled=false",
    "features.browser_use=false",
    "features.browser_use_external=false",
    "features.browser_use_full_cdp_access=false",
    "features.in_app_browser=false",
    "features.computer_use=false",
    "features.image_generation=false",
    "features.code_mode=false",
    "features.code_mode_host=false",
    "features.code_mode_only=false",
    "features.plugins=false",
    "features.plugin_sharing=false",
    "features.remote_plugin=false",
    "features.tool_suggest=false",
    "features.workspace_dependencies=false",
    "features.auth_elicitation=false",
    "features.tool_call_mcp_elicitation=false",
    "features.request_permissions_tool=false",
    "features.hooks=false",
    "features.multi_agent=false",
    "features.goals=false",
    "features.memories=false",
    "features.chronicle=false",
    "features.skill_mcp_dependency_install=false",
    "features.guardian_approval=false",
    "features.unified_exec=false",
    "features.shell_snapshot=false",
    "check_for_update_on_startup=false",
    "project_doc_max_bytes=0",
    "instructions=\"\"",
    "developer_instructions=\"\"",
    "skills.include_instructions=false",
    "skills.bundled.enabled=false",
    "include_environment_context=false",
    "include_permissions_instructions=false",
    "include_apps_instructions=false",
    "include_collaboration_mode_instructions=false",
    "projects.\"/tmp/p1f1d-cli-workspace\".trust_level=\"untrusted\"",
    "mcp_servers={ranchboard={command=\"/tmp/AgentLoopBoardBridge\",args=[\"--board-server\"],env_vars=[\"AGENTLOOP_BOARD_SOCKET\",\"AGENTLOOP_BOARD_TOKEN\",\"AGENTLOOP_BOARD_CARD_ID\",\"AGENTLOOP_BOARD_TOOLS\"],required=true,enabled_tools=[\"add_progress_note\",\"ask_user\",\"block_card\",\"complete_card\"],default_tools_approval_mode=\"approve\"}}",
]

private func p1f1dCodexArguments(
    resumedSessionID: String? = nil
) -> [String] {
    var arguments = [
        "-a", "never",
        "-C", p1f1dCLIWorkspace.path,
        "-s", "read-only",
        "-m", p1f1dCLIModel,
        "exec",
        "--ignore-user-config",
        "--ignore-rules",
        "--strict-config",
        "--skip-git-repo-check",
    ]
    for pair in p1f1dCodexConfigPairs {
        arguments += ["-c", pair]
    }
    arguments += ["--json"]
    if let resumedSessionID {
        arguments += ["resume", resumedSessionID]
    }
    arguments += ["-"]
    return arguments
}

private let p1f1dClaudeEnvironment = [
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1",
    "CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS": "1",
    "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1",
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1",
    "DISABLE_BUG_COMMAND": "1",
]

private func p1f1dClaudeArguments(
    configURL: URL,
    sessionPair: [String]
) -> [String] {
    [
        "-p",
        "--input-format", "text",
        "--output-format", "stream-json",
        "--verbose",
        "--mcp-config", configURL.path,
        "--tools", "",
        "--setting-sources", "",
        "--strict-mcp-config",
        "--allowedTools",
        "mcp__ranchboard__add_progress_note",
        "mcp__ranchboard__ask_user",
        "mcp__ranchboard__block_card",
        "mcp__ranchboard__complete_card",
        "--permission-mode", "dontAsk",
        "--disable-slash-commands",
        "--no-chrome",
    ] + sessionPair + [
        "--model", p1f1dCLIModel,
        "--add-dir", p1f1dCLIWorkspace.path,
    ]
}

private func p1f1dValues(after flag: String, in arguments: [String])
    -> [String]
{
    arguments.indices.compactMap { index in
        guard arguments[index] == flag,
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }
}

private actor P1F1DCLIAdapterTerminalSink: EngineTerminalSink {
    private var intents: [EngineTerminalIntentV1] = []

    func submit(_ intent: EngineTerminalIntentV1) async throws {
        intents.append(intent)
    }

    func snapshot() -> [EngineTerminalIntentV1] { intents }
}

private actor P1F1DCLIAdapterBoardSink: EngineBoardTerminalSink {
    private var intents: [EngineBoardTerminalIntentV1] = []

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        intents.append(intent)
    }

    func snapshot() -> [EngineBoardTerminalIntentV1] { intents }
}

private actor P1F1DCLIAdapterProgressSink: EngineProgressSink {
    private var payloads: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        payloads.append(payload)
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] { payloads }
}

private struct P1F1DCLIAdapterLaunchSnapshot: Sendable {
    let executionId: String
    let spec: CliCommandSpec
    let workspaceURL: URL
    let boardSocketURL: URL
    let boardToken: String
    let boardCardId: String
    let boundCapabilityTools: EngineBoundCapabilityToolsV1
    let cleanupContents: [String: String]
    let boardSinkMatched: Bool
    let progressSinkMatched: Bool
}

private final class P1F1DCLIAdapterProcessDriver:
    CliProcessDrivingV1, @unchecked Sendable
{
    let supportsProcessGroupCancellation = true

    private let lock = NSLock()
    private let expectedBoard: P1F1DCLIAdapterBoardSink
    private let expectedProgress: P1F1DCLIAdapterProgressSink
    private let frames: [CliProcessFrameV1]
    private var stored: [P1F1DCLIAdapterLaunchSnapshot] = []

    init(
        board: P1F1DCLIAdapterBoardSink,
        progress: P1F1DCLIAdapterProgressSink,
        frames: [CliProcessFrameV1] = []
    ) {
        expectedBoard = board
        expectedProgress = progress
        self.frames = frames
    }

    func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error> {
        let cleanupContents: [String: String]
        let boardSocketURL: URL
        do {
            boardSocketURL = try BoardToolServer.makeSocketURL(
                directoryAuthority: request.boardSocketDirectoryAuthority,
                executionId: request.executionId
            )
            guard boardSocketURL.lastPathComponent
                    == request.boardSocketBasename
            else {
                throw EngineContextValidationErrorV1()
            }
            cleanupContents = try Dictionary(
                uniqueKeysWithValues: request.spec.cleanupURLs.map { url in
                    (
                        url.path,
                        try String(contentsOf: url, encoding: .utf8)
                    )
                }
            )
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        let snapshot = P1F1DCLIAdapterLaunchSnapshot(
            executionId: request.executionId,
            spec: request.spec,
            workspaceURL: request.workspaceURL,
            boardSocketURL: boardSocketURL,
            boardToken: request.boardToken,
            boardCardId: request.boardCardId,
            boundCapabilityTools: request.boundCapabilityTools,
            cleanupContents: cleanupContents,
            boardSinkMatched:
                (request.boardTerminalSink as? P1F1DCLIAdapterBoardSink)
                    === expectedBoard,
            progressSinkMatched:
                (request.progressSink as? P1F1DCLIAdapterProgressSink)
                    === expectedProgress
        )
        lock.lock()
        stored.append(snapshot)
        lock.unlock()
        do {
            for url in request.spec.cleanupURLs {
                try FileManager.default.removeItem(at: url)
            }
            try request.boardSocketDirectoryAuthority.close()
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        return AsyncThrowingStream { continuation in
            for frame in self.frames {
                continuation.yield(frame)
            }
            continuation.finish()
        }
    }

    func cancel(
        executionId: String
    ) async throws -> CliProcessExitEvidenceV1 {
        CliProcessExitEvidenceV1(
            pid: 72,
            processGroupID: 72,
            status: 15,
            termSent: true,
            killSent: false,
            stdoutEOF: true,
            stderrEOF: true,
            childReaped: true
        )
    }

    var snapshots: [P1F1DCLIAdapterLaunchSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private func p1f1dCLIAdapterContext()
    throws -> EngineResolvedContextTransportV1
{
    try EngineResolvedContextTransportV1(
        envelope: p1f1CanonicalEnvelope(),
        packet: p1f1ContextPacket(),
        canonicalEnvelopeJSON: p1f1ContextGolden,
        hash: p1f1ContextGoldenHash
    )
}

private func p1f1dCLIAdapterWorkspace()
    throws -> EngineResolvedWorkspaceV1
{
    let identity = try EngineWorkspaceIdentityV1(
        campId: p1f1EngineCampID,
        squadId: "60000000-0000-4000-8000-000000000072",
        workspacePath: p1f1dCLIWorkspace.path,
        bookmarkHash: nil
    )
    return try EngineResolvedWorkspaceV1(
        identity: identity,
        url: p1f1dCLIWorkspace,
        release: {}
    )
}

private func p1f1dCLIAdapterDescriptor(
    kind: RuntimeProfileKind
) -> ExecutionEngineDescriptor {
    ExecutionEngineDescriptor(
        adapterId: kind == .cliCodex
            ? "agentloop.cli.codex" : "agentloop.cli.claude",
        adapterVersion: "1",
        profileKind: kind,
        streamingProgress: .supported,
        boardTerminal: .supported,
        toolBridge: .supported,
        cancellation: .supported,
        sessionResume: .supported,
        usageMetering: .supported,
        workspaceRead: .supported,
        workspaceWrite: .supported,
        network: .supported,
        replayClassResolver: { _ in .nonReplayable }
    )
}

private final class P1F1DCLIAdapterConfigurationFixture {
    let configuration: CliEngineRuntimeConfigurationV1
    let root: URL

    init(configuration: CliEngineRuntimeConfigurationV1, root: URL) {
        self.configuration = configuration
        self.root = root
    }

    func cleanup() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
        guard !fileManager.fileExists(atPath: root.path) else {
            throw EngineContextValidationErrorV1()
        }
    }
}

private func p1f1dCLIAdapterRecordCleanup(
    _ fixture: P1F1DCLIAdapterConfigurationFixture
) {
    do {
        try fixture.cleanup()
    } catch {
        Issue.record("P1-F1D CLI adapter fixture cleanup failed: \(error)")
    }
}

private func p1f1dCLIAdapterCreateOwnedDirectory(
    _ directory: URL
) throws -> stat {
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: false
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: directory.path
    )
    var information = stat()
    guard directory.path.withCString({
        Darwin.lstat($0, &information)
    }) == 0,
          information.st_mode & S_IFMT == S_IFDIR,
          information.st_uid == getuid(),
          information.st_mode & mode_t(0o777) == mode_t(0o700)
    else {
        throw EngineContextValidationErrorV1()
    }
    return information
}

private func p1f1dCLIAdapterConfiguration(
    kind: RuntimeProfileKind
) throws -> P1F1DCLIAdapterConfigurationFixture {
    let command = kind == .cliCodex
        ? "/tmp/fake-codex" : "/tmp/fake-claude"
    let executableAuthority = try p1f1dCLIExecutableAuthority(
        kind: kind,
        stagedPath: command
    )
    let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
        .appendingPathComponent(
            "p1f1d-cli-\(UUID().uuidString)",
            isDirectory: true
        )
    var completed = false
    defer {
        if !completed, FileManager.default.fileExists(atPath: root.path) {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record(
                    "P1-F1D CLI adapter preflight cleanup failed: \(error)"
                )
            }
        }
    }
    _ = try p1f1dCLIAdapterCreateOwnedDirectory(root)
    let configDirectory = root.appendingPathComponent(
        "config",
        isDirectory: true
    )
    _ = try p1f1dCLIAdapterCreateOwnedDirectory(configDirectory)
    let socketDirectory = root.appendingPathComponent(
        "socket",
        isDirectory: true
    )
    let information = try p1f1dCLIAdapterCreateOwnedDirectory(
        socketDirectory
    )
    let descriptor = socketDirectory.path.withCString {
        Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    }
    guard descriptor >= 0 else { throw EngineContextValidationErrorV1() }
    var openedInformation = stat()
    guard Darwin.fstat(descriptor, &openedInformation) == 0,
          openedInformation.st_dev == information.st_dev,
          openedInformation.st_ino == information.st_ino
    else {
        _ = Darwin.close(descriptor)
        throw EngineContextValidationErrorV1()
    }
    let directoryAuthority: EngineBoardSocketDirectoryAuthorityV1
    do {
        directoryAuthority = try EngineBoardSocketDirectoryAuthorityV1(
            directoryURL: try p1f1CanonicalDirectoryURL(descriptor),
            ownedDescriptor: descriptor,
            device: UInt64(openedInformation.st_dev),
            inode: UInt64(openedInformation.st_ino),
            uid: UInt32(openedInformation.st_uid),
            mode: UInt16(openedInformation.st_mode & mode_t(0o777)),
            ownerIdentityHash: String(repeating: "7", count: 64),
            bootId: p1f1dCLIRanchSession
        )
    } catch {
        let primary = error
        if Darwin.close(descriptor) != 0 {
            Issue.record("P1-F1D CLI adapter descriptor cleanup failed")
        }
        throw primary
    }
    let configuration = try CliEngineRuntimeConfigurationV1(
        command: command,
        cliExecutableAuthority: executableAuthority,
        sandbox: "read-only",
        reasoningEffort: "high",
        bridgeExecutableAuthority: p1f1dCLIBridgeAuthority(),
        boardSocketDirectoryAuthority: directoryAuthority,
        claudeConfigDirectory: configDirectory,
        ranchSessionId: p1f1dCLIRanchSession
    )
    completed = true
    return P1F1DCLIAdapterConfigurationFixture(
        configuration: configuration,
        root: root
    )
}

private func p1f1dCLIAdapterRequest(
    kind: RuntimeProfileKind,
    executionId: String,
    externalSessionId: String?
) throws -> (RuntimeProfileRecord, EngineExecutionRequest) {
    let adapterId = kind == .cliCodex
        ? "agentloop.cli.codex" : "agentloop.cli.claude"
    let profileId = kind == .cliCodex
        ? "40000000-0000-4000-8000-000000000072"
        : "40000000-0000-4000-8000-000000000073"
    let profile = RuntimeProfileRecord(
        id: profileId,
        kind: kind,
        name: "P1-F1D real adapter handoff",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let contract = try OutcomeContractRef(
        id: p1f1EngineContractID,
        version: 7,
        hash: p1f1EngineHashA
    )
    let descriptor = p1f1dCLIAdapterDescriptor(kind: kind)
    let scope = try EngineSessionScopeV1.derived(
        campId: p1f1EngineCampID,
        profileId: profileId,
        descriptor: descriptor,
        engineKind: adapterId,
        model: p1f1dCLIModel,
        workspaceHash: p1f1EngineWorkspaceHash,
        contract: contract
    )
    let scopeBytes = try CanonicalJSONV1.encode(scope)
    let sessionRef: EngineSessionReferenceV1?
    if let externalSessionId {
        sessionRef = try EngineSessionReferenceV1(
            sessionId: "70000000-0000-4000-8000-000000000072",
            externalSessionId: externalSessionId
        )
    } else {
        sessionRef = nil
    }
    return (
        profile,
        try EngineExecutionRequest.makeCanonical(
            executionId: executionId,
            idempotencyKey: "p1f1d-cli-handoff-\(executionId)",
            campId: p1f1EngineCampID,
            campLifecycleVersion: 1,
            runId: "10000000-0000-4000-8000-000000000072",
            cardId: p1f1dCLICard,
            contract: contract,
            adapterId: adapterId,
            adapterVersion: "1",
            profileId: profileId,
            engineKind: adapterId,
            model: p1f1dCLIModel,
            replayClass: .nonReplayable,
            contextJson: p1f1ContextGolden,
            contextHash: p1f1ContextGoldenHash,
            sessionScopeJson: String(decoding: scopeBytes, as: UTF8.self),
            sessionScopeHash: CanonicalJSONV1.sha256Hex(scopeBytes),
            requiredCapabilities: [
                .boardTerminal, .sessionResume, .streamingProgress,
            ],
            approvalGrantIds: [],
            budget: EngineExecutionBudgetV1(
                tokenLimit: 1_000,
                costMicrosLimit: 1_000_000,
                wallClockSeconds: 60
            ),
            workspace: EngineWorkspaceRefV1(
                reference:
                    "squad-workspace.v1:60000000-0000-4000-8000-000000000072",
                hash: p1f1EngineWorkspaceHash
            ),
            sessionRef: sessionRef
        )
    )
}

private func p1f1dAssertNoTopLevelBoardEnvironment(
    _ environment: [String: String]
) {
    for key in [
        "AGENTLOOP_BOARD_SOCKET", "AGENTLOOP_BOARD_TOKEN",
        "AGENTLOOP_BOARD_CARD_ID", "AGENTLOOP_BOARD_TOOLS",
    ] {
        #expect(environment[key] == nil)
    }
}

private func p1f1dAssertRealCLIAdapterHandoff(
    kind: RuntimeProfileKind,
    executionId: String,
    externalSessionId: String?
) async throws {
    let (profile, request) = try p1f1dCLIAdapterRequest(
        kind: kind,
        executionId: executionId,
        externalSessionId: externalSessionId
    )
    let context = try p1f1dCLIAdapterContext()
    let configurationFixture = try p1f1dCLIAdapterConfiguration(kind: kind)
    defer { p1f1dCLIAdapterRecordCleanup(configurationFixture) }
    let terminal = P1F1DCLIAdapterTerminalSink()
    let board = P1F1DCLIAdapterBoardSink()
    let progress = P1F1DCLIAdapterProgressSink()
    let driver = P1F1DCLIAdapterProcessDriver(
        board: board,
        progress: progress
    )
    let adapter = CliEngineAdapter(
        profile: profile,
        descriptor: p1f1dCLIAdapterDescriptor(kind: kind),
        processDriver: driver,
        configuration: configurationFixture.configuration,
        commandBuilder: CliEngineCommandBuilderV1(),
        codexParser: CodexCliEventParserV1(),
        claudeParserFactory: {
            try ClaudeCliEventParserV1(expectedSessionId: $0)
        },
        sanitizer: CliEngineSecretSanitizerV1(),
        context: context,
        workspace: try p1f1dCLIAdapterWorkspace(),
        boundCapabilityTools: p1f1dCLIBoundCapabilityTools(),
        resolvedSessionRef: nil,
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress
    )
    for try await _ in adapter.execute(request: request) {}

    let snapshot = try #require(driver.snapshots.first)
    #expect(driver.snapshots.count == 1)
    #expect(snapshot.executionId == request.executionId)
    #expect(snapshot.workspaceURL == p1f1dCLIWorkspace)
    #expect(snapshot.boardCardId == request.cardId)
    #expect(snapshot.boardSinkMatched)
    #expect(snapshot.progressSinkMatched)
    #expect(snapshot.boardToken.count == 64)
    #expect(
        snapshot.boundCapabilityTools.logicalDefinitions
            == p1f1dCLIBoundCapabilityTools().logicalDefinitions
    )
    #expect(snapshot.boundCapabilityTools.capabilityTools.isEmpty)
    #expect(
        snapshot.boardToken.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
        }
    )
    #expect(snapshot.boardSocketURL.isFileURL)
    #expect(snapshot.boardSocketURL.path.hasPrefix("/"))
    p1f1dAssertNoTopLevelBoardEnvironment(snapshot.spec.environment)
    let renderedPrompt = try CliEnginePromptV1.render(context)
    #expect(snapshot.spec.stdinBytes == Data(renderedPrompt.utf8))
    #expect(!snapshot.spec.arguments.contains(renderedPrompt))
    #expect(!snapshot.spec.arguments.contains(snapshot.boardToken))
    #expect(!snapshot.spec.arguments.contains(snapshot.boardSocketURL.path))

    if kind == .cliCodex {
        #expect(snapshot.spec.command == "/tmp/fake-codex")
        #expect(snapshot.spec.cleanupURLs.isEmpty)
        #expect(
            p1f1dValues(after: "-C", in: snapshot.spec.arguments)
                == [snapshot.workspaceURL.path]
        )
        let pairs = p1f1dValues(after: "-c", in: snapshot.spec.arguments)
        #expect(
            pairs.filter { $0.hasPrefix("mcp_servers={ranchboard=") }
                .count == 1
        )
        if let externalSessionId {
            #expect(
                p1f1dValues(after: "resume", in: snapshot.spec.arguments)
                    == [externalSessionId]
            )
        } else {
            #expect(!snapshot.spec.arguments.contains("resume"))
        }
    } else {
        #expect(snapshot.spec.command == "/tmp/fake-claude")
        let cleanupURL = try #require(snapshot.spec.cleanupURLs.first)
        #expect(snapshot.spec.cleanupURLs.count == 1)
        #expect(
            p1f1dValues(after: "--mcp-config", in: snapshot.spec.arguments)
                == [cleanupURL.path]
        )
        #expect(
            p1f1dValues(after: "--add-dir", in: snapshot.spec.arguments)
                == [snapshot.workspaceURL.path]
        )
        let config = try JSONValue.decoded(
            from: try #require(snapshot.cleanupContents[cleanupURL.path])
        )
        let env = try #require(
            config["mcpServers"]?["ranchboard"]?["env"]?.objectValue
        )
        #expect(
            env["AGENTLOOP_BOARD_SOCKET"]?.stringValue
                == snapshot.boardSocketURL.path
        )
        #expect(
            env["AGENTLOOP_BOARD_TOKEN"]?.stringValue
                == snapshot.boardToken
        )
        #expect(
            env["AGENTLOOP_BOARD_CARD_ID"]?.stringValue
                == snapshot.boardCardId
        )
        if let externalSessionId {
            #expect(
                p1f1dValues(after: "--resume", in: snapshot.spec.arguments)
                    == [externalSessionId]
            )
        } else {
            #expect(
                p1f1dValues(
                    after: "--session-id",
                    in: snapshot.spec.arguments
                ) == [p1f1dCLIRanchSession]
            )
        }
        #expect(!FileManager.default.fileExists(atPath: cleanupURL.path))
    }
}

@Test func p1f1_072CodexFakeCLIExactSessionBindAndResume() async throws {
    let configURL = URL(fileURLWithPath: "/tmp/p1f1d-unused-codex.json")
    let builder = CliEngineCommandBuilderV1()
    let systemTempSocketDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("a-0123456789ab", isDirectory: true)
    try FileManager.default.createDirectory(
        at: systemTempSocketDirectory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: systemTempSocketDirectory) }
    var systemTempDescriptor = Darwin.open(
        systemTempSocketDirectory.path,
        O_RDONLY | O_DIRECTORY | O_CLOEXEC
    )
    guard systemTempDescriptor >= 0 else {
        throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
    }
    defer { try? EngineRuntimeOwnedDescriptorV1.closeOnce(&systemTempDescriptor) }
    let canonicalSystemTempDirectory = try p1f1CanonicalDirectoryURL(
        systemTempDescriptor
    )
    let existingCanonicalSocket = canonicalSystemTempDirectory
        .appendingPathComponent("s-0123456789abcdef.sock")
    guard FileManager.default.createFile(
        atPath: existingCanonicalSocket.path,
        contents: Data()
    ) else {
        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
    }
    #expect(
        existingCanonicalSocket.standardizedFileURL.path
            != existingCanonicalSocket.path
    )
    #expect(
        CliEngineCommandInputV1.isCanonicalBoardSocketURL(
            existingCanonicalSocket
        )
    )
    _ = try p1f1dCLIInput(
        command: "/tmp/fake-codex",
        configURL: configURL,
        session: .first(ranchUUID: p1f1dCLIRanchSession),
        boardSocketURL: existingCanonicalSocket
    )
    let firstInput = try p1f1dCLIInput(
        command: "/tmp/fake-codex",
        configURL: configURL,
        session: .first(ranchUUID: p1f1dCLIRanchSession)
    )
    let first = try builder.buildCodex(firstInput)

    #expect(first.command == "/tmp/fake-codex")
    #expect(first.arguments == p1f1dCodexArguments())
    #expect(first.environment.isEmpty)
    #expect(first.stdinBytes == Data(p1f1dCLIPrompt.utf8))
    #expect(first.cleanupURLs.isEmpty)
    #expect(p1f1dValues(after: "-c", in: first.arguments) == p1f1dCodexConfigPairs)
    #expect(!first.arguments.contains(p1f1dCLIPrompt))
    #expect(!first.arguments.contains(p1f1dCLIToken))
    #expect(!first.arguments.contains(p1f1dCLISocket.path))

    let parser = CodexCliEventParserV1()
    #expect(
        try parser.parse(
            line: #"{"type":"thread.started","thread_id":"codex-thread-072"}"#
        ) == [.sessionBound(externalSessionId: "codex-thread-072")]
    )
    let usage = try parser.parse(
        line: #"{"type":"turn.completed","usage":{"input_tokens":3,"cached_input_tokens":2,"output_tokens":5}}"#
    )
    #expect(
        usage == [
            .usage(
                EngineUsageV1(
                    inputTokens: 3,
                    outputTokens: 5,
                    cacheReadTokens: 2,
                    costMicros: 0
                )
            ),
        ]
    )

    let resumeInput = try p1f1dCLIInput(
        command: "/tmp/fake-codex",
        configURL: configURL,
        session: .resume(externalID: "codex-thread-072")
    )
    let resume = try builder.buildCodex(resumeInput)
    #expect(
        resume.arguments
            == p1f1dCodexArguments(resumedSessionID: "codex-thread-072")
    )
    #expect(p1f1dValues(after: "-c", in: resume.arguments) == p1f1dCodexConfigPairs)
    #expect(resume.environment.isEmpty)
    #expect(resume.stdinBytes == Data(p1f1dCLIPrompt.utf8))
    #expect(resume.cleanupURLs.isEmpty)
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliCodex,
        executionId: "A0000000-0000-4000-8000-000000000072",
        externalSessionId: nil
    )
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliCodex,
        executionId: "B0000000-0000-4000-8000-000000000072",
        externalSessionId: "codex-thread-072"
    )
}

@Test func p1f1_073ClaudeFakeCLIExactSessionBindAndResume() async throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1f1d-073-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }
    let configURL = base.appendingPathComponent("ranchboard.json")
    let builder = CliEngineCommandBuilderV1()
    let firstInput = try p1f1dCLIInput(
        command: "/tmp/fake-claude",
        configURL: configURL,
        session: .first(ranchUUID: p1f1dCLIRanchSession)
    )
    let first = try builder.buildClaude(firstInput)

    #expect(first.command == "/tmp/fake-claude")
    #expect(
        first.arguments
            == p1f1dClaudeArguments(
                configURL: configURL,
                sessionPair: ["--session-id", p1f1dCLIRanchSession]
            )
    )
    #expect(first.environment == p1f1dClaudeEnvironment)
    #expect(first.stdinBytes == Data(p1f1dCLIPrompt.utf8))
    #expect(!first.arguments.contains(p1f1dCLIPrompt))
    #expect(!first.arguments.contains(p1f1dCLIToken))
    #expect(!first.arguments.contains(p1f1dCLISocket.path))
    #expect(first.cleanupURLs == [configURL])
    let expectedConfig =
        #"{"mcpServers":{"ranchboard":{"args":["--board-server"],"command":"/tmp/AgentLoopBoardBridge","env":{"AGENTLOOP_BOARD_CARD_ID":"20000000-0000-4000-8000-000000000072","AGENTLOOP_BOARD_SOCKET":"/tmp/s-0123456789abcdef.sock","AGENTLOOP_BOARD_TOKEN":""#
        + p1f1dCLIToken
        + #"","AGENTLOOP_BOARD_TOOLS":"add_progress_note,ask_user,block_card,complete_card"}}}}"#
    #expect(
        try String(contentsOf: configURL, encoding: .utf8) == expectedConfig
    )
    let attributes = try FileManager.default.attributesOfItem(
        atPath: configURL.path
    )
    #expect(
        (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600
    )
    let unlinkStatus = configURL.path.withCString { Darwin.unlink($0) }
    let unlinkError = errno
    guard unlinkStatus == 0 || unlinkError == ENOENT else {
        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(unlinkError),
            userInfo: [NSFilePathErrorKey: configURL.path]
        )
    }

    let parser = try ClaudeCliEventParserV1(
        expectedSessionId: p1f1dCLIRanchSession
    )
    #expect(
        try parser.parse(
            line: #"{"type":"system","subtype":"init","session_id":"30000000-0000-4000-8000-000000000072"}"#
        ) == [.sessionBound(externalSessionId: p1f1dCLIRanchSession)]
    )
    let result = try parser.parse(
        line: #"{"type":"result","subtype":"success","is_error":false,"result":"done","session_id":"30000000-0000-4000-8000-000000000072","total_cost_usd":0.000001,"usage":{"input_tokens":3,"output_tokens":5,"cache_read_input_tokens":2}}"#
    )
    #expect(result.contains(.result))
    #expect(
        result.contains(
            .usage(
                EngineUsageV1(
                    inputTokens: 3,
                    outputTokens: 5,
                    cacheReadTokens: 2,
                    costMicros: 1
                )
            )
        )
    )

    let resumeInput = try p1f1dCLIInput(
        command: "/tmp/fake-claude",
        configURL: configURL,
        session: .resume(externalID: p1f1dCLIRanchSession)
    )
    let resume = try builder.buildClaude(resumeInput)
    #expect(
        resume.arguments
            == p1f1dClaudeArguments(
                configURL: configURL,
                sessionPair: ["--resume", p1f1dCLIRanchSession]
            )
    )
    #expect(resume.environment == p1f1dClaudeEnvironment)
    #expect(resume.stdinBytes == Data(p1f1dCLIPrompt.utf8))
    #expect(resume.cleanupURLs == [configURL])
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliClaude,
        executionId: "A0000000-0000-4000-8000-000000000073",
        externalSessionId: nil
    )
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliClaude,
        executionId: "B0000000-0000-4000-8000-000000000073",
        externalSessionId: p1f1dCLIRanchSession
    )
}

@Test func p1f1_074CLINeverUsesLastContinueAndReinjectsFlags() async throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1f1d-074-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }
    let builder = CliEngineCommandBuilderV1()
    let codexFirstInput = try p1f1dCLIInput(
        command: "/tmp/fake-codex",
        configURL: base.appendingPathComponent("unused.json"),
        session: .first(ranchUUID: p1f1dCLIRanchSession)
    )
    let codexFirst = try builder.buildCodex(codexFirstInput)
    let codexResume = try builder.buildCodex(
        p1f1dCLIInput(
            command: "/tmp/fake-codex",
            configURL: base.appendingPathComponent("unused.json"),
            session: .resume(externalID: "codex-thread-074")
        )
    )
    let claudeFirstURL = base.appendingPathComponent("claude-first.json")
    let claudeResumeURL = base.appendingPathComponent("claude-resume.json")
    let claudeFirst = try builder.buildClaude(
        p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: claudeFirstURL,
            session: .first(ranchUUID: p1f1dCLIRanchSession)
        )
    )
    let claudeResume = try builder.buildClaude(
        p1f1dCLIInput(
            command: "/tmp/fake-claude",
            configURL: claudeResumeURL,
            session: .resume(externalID: p1f1dCLIRanchSession)
        )
    )

    for spec in [codexFirst, codexResume, claudeFirst, claudeResume] {
        #expect(!spec.arguments.contains("--last"))
        #expect(!spec.arguments.contains("--continue"))
        #expect(!spec.arguments.contains(p1f1dCLIPrompt))
        #expect(!spec.arguments.contains(p1f1dCLIToken))
        #expect(!spec.arguments.contains(p1f1dCLISocket.path))
        #expect(spec.stdinBytes == Data(p1f1dCLIPrompt.utf8))
    }
    #expect(!claudeFirst.arguments.contains("-c"))
    #expect(!claudeResume.arguments.contains("-c"))
    #expect(
        p1f1dValues(after: "-c", in: codexFirst.arguments)
            == p1f1dCodexConfigPairs
    )
    #expect(
        p1f1dValues(after: "-c", in: codexResume.arguments)
            == p1f1dCodexConfigPairs
    )
    for spec in [codexFirst, codexResume] {
        #expect(p1f1dValues(after: "-C", in: spec.arguments) == [p1f1dCLIWorkspace.path])
        #expect(p1f1dValues(after: "-s", in: spec.arguments) == ["read-only"])
        #expect(p1f1dValues(after: "-m", in: spec.arguments) == [p1f1dCLIModel])
        #expect(p1f1dValues(after: "--json", in: spec.arguments).first == (spec.arguments.contains("resume") ? "resume" : "-"))
        #expect(spec.arguments.contains("--ignore-user-config"))
        #expect(spec.arguments.contains("--ignore-rules"))
        #expect(spec.arguments.contains("--strict-config"))
        #expect(spec.arguments.contains("--skip-git-repo-check"))
    }
    for spec in [claudeFirst, claudeResume] {
        #expect(p1f1dValues(after: "-p", in: spec.arguments) == ["--input-format"])
        #expect(p1f1dValues(after: "--input-format", in: spec.arguments) == ["text"])
        #expect(p1f1dValues(after: "--output-format", in: spec.arguments) == ["stream-json"])
        #expect(spec.arguments.contains("--verbose"))
        #expect(p1f1dValues(after: "--permission-mode", in: spec.arguments) == ["dontAsk"])
        #expect(p1f1dValues(after: "--tools", in: spec.arguments) == [""])
        #expect(p1f1dValues(after: "--setting-sources", in: spec.arguments) == [""])
        #expect(spec.arguments.contains("--strict-mcp-config"))
        #expect(spec.arguments.contains("--disable-slash-commands"))
        #expect(spec.arguments.contains("--no-chrome"))
        #expect(p1f1dValues(after: "--model", in: spec.arguments) == [p1f1dCLIModel])
        #expect(p1f1dValues(after: "--add-dir", in: spec.arguments) == [p1f1dCLIWorkspace.path])
        #expect(spec.environment == p1f1dClaudeEnvironment)
    }
    #expect(!codexFirst.arguments.joined(separator: " ").contains("acceptEdits"))
    #expect(!claudeFirst.arguments.contains("--bare"))
    do {
        _ = try builder.buildCodex(
            p1f1dCLIInput(
                command: "/tmp/fake-codex",
                configURL: base.appendingPathComponent("skill.json"),
                session: .first(ranchUUID: p1f1dCLIRanchSession),
                prompt: "Do not expand $danger-skill in Ranch"
            )
        )
        Issue.record("Codex explicit skill token must fail closed")
    } catch is EngineContextValidationErrorV1 {
        // Expected: the canonical prompt remains unmodified and is rejected.
    }
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliCodex,
        executionId: "A0000000-0000-4000-8000-000000000074",
        externalSessionId: nil
    )
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliCodex,
        executionId: "B0000000-0000-4000-8000-000000000074",
        externalSessionId: "codex-thread-074"
    )
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliClaude,
        executionId: "C0000000-0000-4000-8000-000000000074",
        externalSessionId: nil
    )
    try await p1f1dAssertRealCLIAdapterHandoff(
        kind: .cliClaude,
        executionId: "D0000000-0000-4000-8000-000000000074",
        externalSessionId: p1f1dCLIRanchSession
    )
}

private enum P1F1D075UnexpectedFactoryInvocation: Error {
    case invoked
}

private enum P1F1D075InspectorMutation: Sendable {
    case none
    case executableHash
    case executablePath
    case designatedRequirement
    case cdHash
}

private final class P1F1D075LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() { lock.withLock { storage += 1 } }
    var value: Int { lock.withLock { storage } }
}

private final class P1F1D075AuthorityRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CliExecutableAuthorityV1] = []

    func append(_ value: CliExecutableAuthorityV1) {
        lock.withLock { storage.append(value) }
    }

    var values: [CliExecutableAuthorityV1] { lock.withLock { storage } }
}

private final class P1F1D075ProcessInspector:
    EngineRuntimeProcessInspectingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private var authority: CliExecutableAuthorityV1
    private var mutation: P1F1D075InspectorMutation
    private var sentSignals: [(Int32, Int32)] = []

    init(
        authority: CliExecutableAuthorityV1,
        mutation: P1F1D075InspectorMutation = .none
    ) {
        self.authority = authority
        self.mutation = mutation
    }

    func select(
        _ authority: CliExecutableAuthorityV1,
        mutation: P1F1D075InspectorMutation = .none
    ) {
        lock.withLock {
            self.authority = authority
            self.mutation = mutation
        }
    }

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        let selected = lock.withLock { (authority, mutation) }
        var pids = [pid_t](repeating: 0, count: 512)
        let count = pids.withUnsafeMutableBytes { bytes in
            proc_listchildpids(
                getpid(),
                bytes.baseAddress,
                Int32(bytes.count)
            )
        }
        guard count >= 0, Int(count) <= pids.count else {
            throw EngineContextValidationErrorV1()
        }
        return pids.prefix(Int(count)).compactMap { pid in
            guard pid > 0 else { return nil }
            let pgid = getpgid(pid)
            guard pgid > 0 else { return nil }
            return EngineRuntimeProcessSnapshotV1(
                pid: pid,
                processGroupId: pgid,
                uid: getuid(),
                startSeconds: 1,
                startMicroseconds: 0,
                executablePath: selected.1 == .executablePath
                    ? selected.0.stagedPath + ".drift"
                    : selected.0.stagedPath,
                executableDevice: selected.0.stagedDevice,
                executableInode: selected.0.stagedInode,
                executableHash: selected.1 == .executableHash
                    ? String(repeating: "f", count: 64)
                    : selected.0.executableHash,
                designatedRequirement:
                    selected.1 == .designatedRequirement
                        ? selected.0.designatedRequirement + ".drift"
                        : selected.0.designatedRequirement,
                cdHash: selected.1 == .cdHash
                    ? String(repeating: "f", count: 40)
                    : selected.0.cdHash
            )
        }
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        lock.withLock { sentSignals.append((signal, processGroupId)) }
        guard Darwin.kill(-processGroupId, signal) == 0 || errno == ESRCH else {
            throw EngineContextValidationErrorV1()
        }
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        if Darwin.kill(-processGroupId, 0) == 0 { return true }
        if errno == ESRCH { return false }
        if errno == EPERM { return true }
        throw EngineContextValidationErrorV1()
    }

    var signals: [(Int32, Int32)] { lock.withLock { sentSignals } }
}

private enum P1F1D075ClosedStdioFixtureError: Error, Equatable {
    case invalidExecutable
    case fileActions(Int32)
    case spawn(Int32)
    case wait
    case status(Int32)
    case close(Int32)
    case evidence
    case residue
}

private func p1f1d075CStringVector(
    _ strings: [String]
) throws -> [UnsafeMutablePointer<CChar>?] {
    var result: [UnsafeMutablePointer<CChar>?] = []
    for string in strings {
        guard !string.utf8.contains(0), let pointer = strdup(string) else {
            result.forEach { if let pointer = $0 { free(pointer) } }
            throw P1F1D075ClosedStdioFixtureError.invalidExecutable
        }
        result.append(pointer)
    }
    result.append(nil)
    return result
}

private func p1f1d075FreeCStringVector(
    _ strings: [UnsafeMutablePointer<CChar>?]
) {
    strings.forEach { if let pointer = $0 { free(pointer) } }
}

private func p1f1d075RunClosedStdioSubprocess(
    base: URL,
    evidence: URL
) throws {
    let executable = URL(
        fileURLWithPath: CommandLine.arguments[0],
        relativeTo: URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
    ).standardizedFileURL.path
    guard executable.hasPrefix("/"),
          FileManager.default.isExecutableFile(atPath: executable)
    else {
        throw P1F1D075ClosedStdioFixtureError.invalidExecutable
    }

    var actions: posix_spawn_file_actions_t?
    var code = posix_spawn_file_actions_init(&actions)
    guard code == 0 else {
        throw P1F1D075ClosedStdioFixtureError.fileActions(code)
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    for (descriptor, flags) in [
        (STDIN_FILENO, O_RDONLY),
        (STDOUT_FILENO, O_WRONLY),
        (STDERR_FILENO, O_WRONLY),
    ] {
        code = "/dev/null".withCString { path in
            posix_spawn_file_actions_addopen(
                &actions,
                descriptor,
                path,
                flags,
                0
            )
        }
        guard code == 0 else {
            throw P1F1D075ClosedStdioFixtureError.fileActions(code)
        }
    }

    var arguments = try p1f1d075CStringVector([
        "/usr/bin/env",
        "AGENTLOOP_R9C_CLOSED_STDIO=help",
        "AGENTLOOP_R9C_FIXTURE_BASE=\(base.path)",
        "AGENTLOOP_R9C_FIXTURE_EVIDENCE=\(evidence.path)",
        executable,
        "--filter",
        "p1f1_075.*",
    ])
    defer { p1f1d075FreeCStringVector(arguments) }
    var pid: pid_t = 0
    code = "/usr/bin/env".withCString { path in
        arguments.withUnsafeMutableBufferPointer { buffer in
            posix_spawn(
                &pid,
                path,
                &actions,
                nil,
                buffer.baseAddress,
                environ
            )
        }
    }
    guard code == 0 else {
        throw P1F1D075ClosedStdioFixtureError.spawn(code)
    }
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno == EINTR { continue }
        throw P1F1D075ClosedStdioFixtureError.wait
    }
    guard status == 0 else {
        throw P1F1D075ClosedStdioFixtureError.status(status)
    }
    guard try String(contentsOf: evidence, encoding: .utf8)
            == "closed-stdio-help-ok\n"
    else {
        throw P1F1D075ClosedStdioFixtureError.evidence
    }
    guard !FileManager.default.fileExists(atPath: base.path) else {
        throw P1F1D075ClosedStdioFixtureError.residue
    }
}

private func p1f1d075CloseFixtureStandardDescriptors() throws {
    for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
        if Darwin.close(descriptor) != 0, errno != EBADF {
            throw P1F1D075ClosedStdioFixtureError.close(descriptor)
        }
    }
}

private func p1f1d075WriteExecutable(
    _ script: String,
    at path: URL
) throws -> CliExecutableAuthorityV1 {
    try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try script.write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: path.path
    )
    var info = stat()
    guard path.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
        throw EngineContextValidationErrorV1()
    }
    let bytes = try Data(contentsOf: path)
    return try CliExecutableAuthorityV1(
        kind: .cliCodex,
        command: "codex",
        commandSourcePath: "/fixtures/@openai/codex/bin/codex.js",
        commandSourceHash: String(repeating: "7", count: 64),
        resolvedExecutablePath: path.path,
        stagedPath: path.path,
        executableHash: CanonicalJSONV1.sha256Hex(bytes),
        designatedRequirement: "anchor apple generic and identifier codex and certificate leaf[subject.OU] = 2DC432GLL2",
        teamIdentifier: "2DC432GLL2",
        cdHash: String(repeating: "7", count: 40),
        stagedDevice: UInt64(info.st_dev),
        stagedInode: UInt64(info.st_ino)
    )
}

private func p1f1d075ExpectedProductionCodexNativePath(
    forWrapper path: String
) throws -> String {
    let packageRoot = URL(fileURLWithPath: path)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    #if arch(arm64)
    let relativePath = "node_modules/@openai/codex-darwin-arm64/"
        + "vendor/aarch64-apple-darwin/bin/codex"
    #elseif arch(x86_64)
    let relativePath = "node_modules/@openai/codex-darwin-x64/"
        + "vendor/x86_64-apple-darwin/bin/codex"
    #else
    throw EngineContextValidationErrorV1()
    #endif
    return packageRoot
        .appendingPathComponent(relativePath)
        .standardizedFileURL.path
}

private func p1f1d075ExpectProbeFailure(
    _ expected: CliHelpProbeFailureV1,
    context: String = "probe",
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record(
            "\(context): expected fail-closed CLI authority/probe failure"
        )
    } catch let error as CliHelpProbeFailureV1 {
        if error != expected {
            Issue.record(
                "\(context): expected \(expected), got \(error)"
            )
        }
    } catch {
        Issue.record(
            "\(context): wrong CLI authority/probe failure type: \(error)"
        )
    }
}

private func p1f1d075CaptureProbeFailure(
    _ operation: () async throws -> Void
) async -> CliHelpProbeFailureV1? {
    do {
        try await operation()
        Issue.record("expected fail-closed CLI authority/probe failure")
        return nil
    } catch let error as CliHelpProbeFailureV1 {
        return error
    } catch {
        Issue.record("wrong CLI authority/probe failure type: \(error)")
        return nil
    }
}

private func p1f1d075ExpectSelectionFailure(
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected exact factory selection failure")
    } catch let error as EngineAdapterSelectionErrorV1 {
        #expect(error == .descriptorMismatch)
    } catch {
        Issue.record("wrong factory selection failure type: \(error)")
    }
}

private enum P1F1D075CompositionEffect: Equatable {
    case identify(RuntimeProfileKind)
    case probe(RuntimeProfileKind)
    case validate(RuntimeProfileKind)
    case remove(RuntimeProfileKind)
    case bridge
    case removeBridge
}

private enum P1F1D075BridgeMatchResult {
    case value(Bool)
    case failure
}

private enum P1F1D075SourceMatchResult {
    case value(Bool)
    case failure
}

private final class P1F1D075CompositionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [P1F1D075CompositionEffect] = []
    private var currentAuthorities: [RuntimeProfileKind: CliExecutableAuthorityV1]
        = [:]
    private var currentBridge: EngineBoardBridgeExecutableAuthorityV1
    private var validationFailures: Set<RuntimeProfileKind> = []
    private var snapshotFailures: Set<RuntimeProfileKind> = []
    private var removalFailures: Set<RuntimeProfileKind> = []
    private var stageFailures:
        [RuntimeProfileKind: CliHelpProbeFailureV1] = [:]
    private var sourceMatchResults:
        [RuntimeProfileKind: [P1F1D075SourceMatchResult]] = [:]
    private var stageAttempts: [RuntimeProfileKind: UInt64] = [:]
    private var bridgeStageAttempt: UInt64 = 0
    private var bridgeMatchResults: [P1F1D075BridgeMatchResult] = []

    init() throws {
        currentAuthorities[.cliCodex] = try p1f1dCLIExecutableAuthority(
            kind: .cliCodex,
            stagedPath: "/fixtures/staged/codex"
        )
        currentAuthorities[.cliClaude] = try p1f1dCLIExecutableAuthority(
            kind: .cliClaude,
            stagedPath: "/fixtures/staged/claude"
        )
        currentBridge = try p1f1dCLIBridgeAuthority()
    }

    func append(_ effect: P1F1D075CompositionEffect) {
        lock.withLock { stored.append(effect) }
    }

    func takeEffects() -> [P1F1D075CompositionEffect] {
        lock.withLock {
            let values = stored
            stored = []
            return values
        }
    }

    func authority(_ kind: RuntimeProfileKind) throws
        -> CliExecutableAuthorityV1
    {
        try lock.withLock {
            guard let value = currentAuthorities[kind] else {
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            }
            return value
        }
    }

    func stageAuthority(_ kind: RuntimeProfileKind) throws
        -> CliExecutableAuthorityV1
    {
        try lock.withLock {
            if let failure = stageFailures[kind] { throw failure }
            let attempt = (stageAttempts[kind] ?? 0) + 1
            stageAttempts[kind] = attempt
            let value = try p1f1dCLIExecutableAuthority(
                kind: kind,
                stagedPath: "/fixtures/staged/\(kind.rawValue)-\(attempt)",
                generation: 72 + attempt
            )
            currentAuthorities[kind] = value
            return value
        }
    }

    func bridgeAuthority() -> EngineBoardBridgeExecutableAuthorityV1 {
        lock.withLock { currentBridge }
    }

    func stageBridge() throws -> EngineBoardBridgeExecutableAuthorityV1 {
        try lock.withLock {
            bridgeStageAttempt += 1
            let original = currentBridge
            let value = try EngineBoardBridgeExecutableAuthorityV1(
                sourcePath: original.sourcePath,
                stagedPath: "/fixtures/staged/bridge-\(bridgeStageAttempt)",
                executableHash: String(repeating: "4", count: 64),
                designatedRequirement: original.designatedRequirement,
                teamIdentifier: original.teamIdentifier,
                cdHash: String(repeating: "c", count: 40),
                stagedDevice: 200 + bridgeStageAttempt,
                stagedInode: 300 + bridgeStageAttempt
            )
            currentBridge = value
            return value
        }
    }

    func sourceMatches(_ authority: CliExecutableAuthorityV1) throws
        -> Bool
    {
        try lock.withLock {
            if var results = sourceMatchResults[authority.kind],
               !results.isEmpty
            {
                let result = results.removeFirst()
                sourceMatchResults[authority.kind] = results
                switch result {
                case .value(let value): return value
                case .failure:
                    throw P1F1D075UnexpectedFactoryInvocation.invoked
                }
            }
            return currentAuthorities[authority.kind] == authority
        }
    }

    func bridgeMatches(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws -> Bool {
        try lock.withLock {
            if !bridgeMatchResults.isEmpty {
                switch bridgeMatchResults.removeFirst() {
                case .value(let result): return result
                case .failure:
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
            }
            return currentBridge == authority
        }
    }

    func invalidate(_ kind: RuntimeProfileKind) throws {
        let replacement = try p1f1dCLIExecutableAuthority(
            kind: kind,
            stagedPath: "/fixtures/staged/\(kind.rawValue)-changed",
            generation: 79
        )
        lock.withLock { currentAuthorities[kind] = replacement }
    }

    func invalidateBridge() throws {
        let original = bridgeAuthority()
        let replacement = try EngineBoardBridgeExecutableAuthorityV1(
            sourcePath: original.sourcePath,
            stagedPath: original.stagedPath + "-changed",
            executableHash: String(repeating: "5", count: 64),
            designatedRequirement: original.designatedRequirement,
            teamIdentifier: original.teamIdentifier,
            cdHash: String(repeating: "d", count: 40),
            stagedDevice: original.stagedDevice + 10,
            stagedInode: original.stagedInode + 10
        )
        lock.withLock { currentBridge = replacement }
    }

    func setValidationFailure(
        _ kind: RuntimeProfileKind,
        enabled: Bool
    ) {
        lock.withLock {
            if enabled { validationFailures.insert(kind) }
            else { validationFailures.remove(kind) }
        }
    }

    func validate(_ kind: RuntimeProfileKind) throws {
        let fails = lock.withLock { validationFailures.contains(kind) }
        if fails { throw CliHelpProbeFailureV1.unsupportedVersion }
    }

    func setStageFailure(
        _ kind: RuntimeProfileKind,
        failure: CliHelpProbeFailureV1?
    ) {
        lock.withLock { stageFailures[kind] = failure }
    }

    func enqueueSourceMatches(
        _ kind: RuntimeProfileKind,
        _ results: [P1F1D075SourceMatchResult]
    ) {
        lock.withLock {
            sourceMatchResults[kind, default: []]
                .append(contentsOf: results)
        }
    }

    func setSnapshotFailure(
        _ kind: RuntimeProfileKind,
        enabled: Bool
    ) {
        lock.withLock {
            if enabled { snapshotFailures.insert(kind) }
            else { snapshotFailures.remove(kind) }
        }
    }

    func snapshot(_ authority: CliExecutableAuthorityV1) throws
        -> CliHelpSnapshotV1
    {
        append(.probe(authority.kind))
        let fails = lock.withLock {
            snapshotFailures.contains(authority.kind)
        }
        if fails { throw P1F1D075UnexpectedFactoryInvocation.invoked }
        return try p1f1d075Snapshot(authority)
    }

    func setRemovalFailure(
        _ kind: RuntimeProfileKind,
        enabled: Bool
    ) {
        lock.withLock {
            if enabled { removalFailures.insert(kind) }
            else { removalFailures.remove(kind) }
        }
    }

    func remove(_ authority: CliExecutableAuthorityV1) throws {
        append(.remove(authority.kind))
        let fails = lock.withLock {
            removalFailures.contains(authority.kind)
        }
        if fails { throw P1F1D075UnexpectedFactoryInvocation.invoked }
    }

    func enqueueBridgeMatches(
        _ results: [P1F1D075BridgeMatchResult]
    ) {
        lock.withLock { bridgeMatchResults.append(contentsOf: results) }
    }
}

private func p1f1d075Snapshot(
    _ authority: CliExecutableAuthorityV1
) throws -> CliHelpSnapshotV1 {
    let codex = authority.kind == .cliCodex
    return try CliHelpSnapshotV1(
        executableAuthority: authority,
        versionLine: codex
            ? "codex-cli 0.144.5"
            : "2.1.81 (Claude Code)",
        rootExitStatus: 0,
        rootStdoutHash: String(repeating: "6", count: 64),
        firstExitStatus: 0,
        firstStdoutHash: String(repeating: "7", count: 64),
        resumeExitStatus: 0,
        resumeStdoutHash: String(repeating: "8", count: 64),
        rootFlags: codex ? ["-C", "-a", "-m", "-s"] : [],
        firstFlags: codex
            ? [
                "--ignore-rules", "--ignore-user-config", "--json",
                "--skip-git-repo-check", "--strict-config", "-c",
            ]
            : [
                "--add-dir", "--allowedTools", "--disable-slash-commands",
                "--input-format", "--mcp-config", "--model", "--no-chrome",
                "--output-format", "--permission-mode", "--session-id",
                "--setting-sources", "--strict-mcp-config", "--tools",
                "--verbose", "-p",
            ].sorted(),
        resumeFlags: codex
            ? [
                "--ignore-rules", "--ignore-user-config", "--json",
                "--skip-git-repo-check", "--strict-config", "-c",
            ]
            : [
                "--add-dir", "--allowedTools", "--disable-slash-commands",
                "--input-format", "--mcp-config", "--model", "--no-chrome",
                "--output-format", "--permission-mode", "--resume",
                "--setting-sources", "--strict-mcp-config", "--tools",
                "--verbose", "-p",
            ].sorted(),
        subcommands: codex ? ["resume"] : []
    )
}

private func p1f1d075Factories() -> [EngineAdapterFactoryV1] {
    EngineAdapterFactoryV1.builtInFactories(
        makeModelLoopAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        },
        makeCodexAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        },
        makeClaudeAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        }
    )
}

private func p1f1d075CompositionOperations(
    _ recorder: P1F1D075CompositionRecorder
) -> EngineAdapterRegistryCompositionOperationsV1 {
    EngineAdapterRegistryCompositionOperationsV1(
        identifyAndStage: { kind, _ in
            recorder.append(.identify(kind))
            return try recorder.stageAuthority(kind)
        },
        snapshot: { authority in
            try recorder.snapshot(authority)
        },
        validateRegistration: { factory, snapshot in
            let kind = snapshot.executableAuthority.kind
            recorder.append(.validate(kind))
            guard factory.profileKinds == [kind] else {
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            }
            try recorder.validate(kind)
        },
        sourceIdentityMatches: { try recorder.sourceMatches($0) },
        removeStagedAuthority: { try recorder.remove($0) },
        identifyAndStageBoardBridge: {
            recorder.append(.bridge)
            return try recorder.stageBridge()
        },
        bridgeSourceIdentityMatches: { try recorder.bridgeMatches($0) },
        removeStagedBridgeAuthority: { _ in
            recorder.append(.removeBridge)
        }
    )
}

private func p1f1d075AssertGenerationComposition() async throws {
    let recorder = try P1F1D075CompositionRecorder()
    let composer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(recorder)
    )

    let modelOnly = try await composer.registry(
        requestedProfileKinds: [.openAIAPI]
    )
    #expect(modelOnly.factories.map(\.adapterId) == ["agentloop.model-loop"])
    #expect(recorder.takeEffects().isEmpty)

    let codex = try await composer.registry(
        requestedProfileKinds: [.openAIAPI, .cliCodex]
    )
    #expect(codex.factories.map(\.adapterId)
        == ["agentloop.model-loop", "agentloop.cli.codex"])
    #expect(recorder.takeEffects()
        == [.identify(.cliCodex), .probe(.cliCodex),
            .validate(.cliCodex), .bridge])

    _ = try await composer.registry(
        requestedProfileKinds: [.cliCodex, .openAIAPI]
    )
    #expect(recorder.takeEffects().isEmpty)

    let both = try await composer.registry(
        requestedProfileKinds: [.cliClaude, .cliCodex, .openAIAPI]
    )
    #expect(both.factories.map(\.adapterId) == [
        "agentloop.model-loop", "agentloop.cli.claude",
        "agentloop.cli.codex",
    ])
    #expect(recorder.takeEffects()
        == [.identify(.cliClaude), .probe(.cliClaude),
            .validate(.cliClaude)])

    try recorder.invalidate(.cliClaude)
    recorder.setValidationFailure(.cliClaude, enabled: true)
    let partial = try await composer.registry(
        requestedProfileKinds: [.cliClaude, .cliCodex, .openAIAPI]
    )
    #expect(partial.factories.map(\.adapterId)
        == ["agentloop.model-loop", "agentloop.cli.codex"])
    #expect(recorder.takeEffects()
        == [.identify(.cliClaude), .probe(.cliClaude),
            .validate(.cliClaude), .remove(.cliClaude)])

    recorder.setValidationFailure(.cliClaude, enabled: false)
    _ = try await composer.registry(
        requestedProfileKinds: [.cliClaude, .cliCodex, .openAIAPI]
    )
    #expect(recorder.takeEffects()
        == [.identify(.cliClaude), .probe(.cliClaude),
            .validate(.cliClaude)])

    try recorder.invalidateBridge()
    _ = try await composer.registry(
        requestedProfileKinds: [.cliClaude, .cliCodex, .openAIAPI]
    )
    #expect(recorder.takeEffects() == [.bridge])
}

private func p1f1d075AssertFailedAttemptOwnership() async throws {
    let recorder = try P1F1D075CompositionRecorder()
    recorder.setSnapshotFailure(.cliClaude, enabled: true)
    recorder.setRemovalFailure(.cliClaude, enabled: true)
    let composer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(recorder)
    )
    do {
        _ = try await composer.registry(
            requestedProfileKinds: [.openAIAPI, .cliClaude]
        )
        Issue.record("snapshot cleanup failure must be propagated")
    } catch is EngineRuntimeCleanupAggregateErrorV1 {
    } catch {
        Issue.record("wrong snapshot cleanup failure: \(error)")
    }
    #expect(recorder.takeEffects() == [
        .identify(.cliClaude), .probe(.cliClaude), .remove(.cliClaude),
    ])

    recorder.setSnapshotFailure(.cliClaude, enabled: false)
    recorder.setRemovalFailure(.cliClaude, enabled: false)
    let recovered = try await composer.registry(
        requestedProfileKinds: [.openAIAPI, .cliClaude]
    )
    #expect(recovered.factories.map(\.adapterId) == [
        "agentloop.model-loop", "agentloop.cli.claude",
    ])
    #expect(recorder.takeEffects() == [
        .identify(.cliClaude), .probe(.cliClaude),
        .validate(.cliClaude), .bridge,
    ])

    let retained = try await composer.takeRetainedAuthoritiesForTeardown()
    #expect(retained.cli.count == 2)
    #expect(retained.bridge.count == 1)
    for authority in retained.cli { try recorder.remove(authority) }
    for _ in retained.bridge { recorder.append(.removeBridge) }
    #expect(recorder.takeEffects() == [
        .remove(.cliClaude), .remove(.cliClaude), .removeBridge,
    ])
}

private func p1f1d075AssertAcquisitionTransactionUnwind() async throws {
    let recorder = try P1F1D075CompositionRecorder()
    recorder.setValidationFailure(.cliCodex, enabled: true)
    recorder.setRemovalFailure(.cliCodex, enabled: true)
    let composer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(recorder)
    )
    do {
        _ = try await composer.registry(
            requestedProfileKinds: [
                .openAIAPI, .cliClaude, .cliCodex,
            ]
        )
        Issue.record("fatal second acquisition must unwind the first")
    } catch is EngineRuntimeCleanupAggregateErrorV1 {
    } catch {
        Issue.record("wrong acquisition unwind error: \(error)")
    }
    #expect(recorder.takeEffects() == [
        .identify(.cliClaude), .probe(.cliClaude),
        .validate(.cliClaude),
        .identify(.cliCodex), .probe(.cliCodex),
        .validate(.cliCodex), .remove(.cliCodex),
        .remove(.cliClaude),
    ])
    let retained = try await composer.takeRetainedAuthoritiesForTeardown()
    #expect(retained.cli.map(\.kind) == [.cliCodex])
    #expect(retained.bridge.isEmpty)
}

private func p1f1d075AssertOuterAcquisitionGuard() async throws {
    let recorder = try P1F1D075CompositionRecorder()
    let composer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(recorder)
    )
    _ = try await composer.registry(
        requestedProfileKinds: [.openAIAPI, .cliCodex]
    )
    _ = recorder.takeEffects()
    recorder.enqueueSourceMatches(.cliCodex, [.failure])
    do {
        _ = try await composer.registry(
            requestedProfileKinds: [
                .openAIAPI, .cliClaude, .cliCodex,
            ]
        )
        Issue.record("retained identity failure must unwind new staging")
    } catch is P1F1D075UnexpectedFactoryInvocation {
    } catch {
        Issue.record("wrong retained identity failure: \(error)")
    }
    #expect(recorder.takeEffects() == [
        .identify(.cliClaude), .probe(.cliClaude),
        .validate(.cliClaude), .remove(.cliClaude),
    ])
    let retained = try await composer.takeRetainedAuthoritiesForTeardown()
    #expect(retained.cli.map(\.kind) == [.cliCodex])
    #expect(retained.bridge.count == 1)

    let cleanupRecorder = try P1F1D075CompositionRecorder()
    cleanupRecorder.setStageFailure(.cliClaude, failure: .cleanup)
    let cleanupComposer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(cleanupRecorder)
    )
    do {
        _ = try await cleanupComposer.registry(
            requestedProfileKinds: [.openAIAPI, .cliClaude]
        )
        Issue.record("CLI acquisition cleanup failure must not publish")
    } catch let failure as CliHelpProbeFailureV1 {
        #expect(failure == .cleanup)
    } catch {
        Issue.record("wrong CLI acquisition cleanup failure: \(error)")
    }
    #expect(cleanupRecorder.takeEffects() == [.identify(.cliClaude)])
    let cleanupRetained = try await cleanupComposer
        .takeRetainedAuthoritiesForTeardown()
    #expect(cleanupRetained.cli.isEmpty)
    #expect(cleanupRetained.bridge.isEmpty)
}

private func p1f1d075AssertBridgeAttemptOwnership() async throws {
    let recorder = try P1F1D075CompositionRecorder()
    recorder.enqueueBridgeMatches([.value(false), .failure])
    let composer = EngineAdapterRegistryComposerV1(
        factories: p1f1d075Factories(),
        operations: p1f1d075CompositionOperations(recorder)
    )
    let requested: Set<RuntimeProfileKind> = [.openAIAPI, .cliCodex]
    for _ in 0..<2 {
        let partial = try await composer.registry(
            requestedProfileKinds: requested
        )
        #expect(partial.factories.map(\.adapterId)
            == ["agentloop.model-loop"])
        #expect(recorder.takeEffects() == [
            .identify(.cliCodex), .probe(.cliCodex),
            .validate(.cliCodex), .bridge, .removeBridge,
            .remove(.cliCodex),
        ])
    }
    let recovered = try await composer.registry(
        requestedProfileKinds: requested
    )
    #expect(recovered.factories.map(\.adapterId) == [
        "agentloop.model-loop", "agentloop.cli.codex",
    ])
    #expect(recorder.takeEffects() == [
        .identify(.cliCodex), .probe(.cliCodex),
        .validate(.cliCodex), .bridge,
    ])
}

private final class P1F1D075Driver:
    CliProcessDrivingV1, @unchecked Sendable
{
    let supportsProcessGroupCancellation = true

    func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func cancel(executionId: String) async throws
        -> CliProcessExitEvidenceV1
    {
        throw P1F1D075UnexpectedFactoryInvocation.invoked
    }
}

private final class P1F1D075LazyCellBox: @unchecked Sendable {
    var cell: EngineSynchronousLazyCellV1<any CliProcessDrivingV1>?
}

private func p1f1d075AssertSynchronousLazySeed() async throws {
    let count = P1F1D075LockedCounter()
    let driver = P1F1D075Driver()
    let box = P1F1D075LazyCellBox()
    let cell = EngineSynchronousLazyCellV1<any CliProcessDrivingV1> {
        #expect(box.cell?.isResolved == false)
        count.increment()
        return driver
    }
    box.cell = cell
    let seedClosure = cell.makeValueClosure()
    let values = try await withThrowingTaskGroup(
        of: (any CliProcessDrivingV1).self,
        returning: [any CliProcessDrivingV1].self
    ) { group in
        for _ in 0..<16 { group.addTask { try seedClosure() } }
        var result: [any CliProcessDrivingV1] = []
        for try await value in group { result.append(value) }
        return result
    }
    #expect(count.value == 1)
    #expect(values.count == 16)
    #expect(values.allSatisfy { ($0 as AnyObject) === driver })
    #expect(cell.isResolved)

    let retryCount = P1F1D075LockedCounter()
    let retry = EngineSynchronousLazyCellV1<any CliProcessDrivingV1> {
        retryCount.increment()
        if retryCount.value == 1 {
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        }
        return driver
    }
    do {
        _ = try retry.makeValueClosure()()
        Issue.record("first synchronous driver maker must throw")
    } catch is P1F1D075UnexpectedFactoryInvocation {
    }
    #expect(!retry.isResolved)
    #expect((try retry.makeValueClosure()() as AnyObject) === driver)
    #expect(retryCount.value == 2)
}

private func p1f1d075WritePipe(
    _ data: Data,
    descriptor: Int32
) throws {
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let written = Darwin.write(
                descriptor,
                bytes.baseAddress?.advanced(by: offset),
                bytes.count - offset
            )
            if written < 0, errno == EINTR { continue }
            guard written > 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            offset += written
        }
    }
}

private func p1f1d075AssertLiveDrainOwnership() throws {
    var stdoutPipe = [Int32](repeating: -1, count: 2)
    guard stdoutPipe.withUnsafeMutableBufferPointer({
        Darwin.pipe($0.baseAddress!)
    }) == 0 else {
        throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
    }
    var stderrPipe = [Int32](repeating: -1, count: 2)
    guard stderrPipe.withUnsafeMutableBufferPointer({
        Darwin.pipe($0.baseAddress!)
    }) == 0 else {
        let primary = EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        for descriptor in stdoutPipe where descriptor >= 0 {
            #expect(Darwin.close(descriptor) == 0)
        }
        throw primary
    }
    defer {
        for descriptor in stdoutPipe + stderrPipe where descriptor >= 0 {
            #expect(Darwin.close(descriptor) == 0)
        }
    }

    let stdoutRead = stdoutPipe[0]
    let stderrRead = stderrPipe[0]
    let drain = EngineManagedProbeLiveDrainV1(
        stdoutDescriptor: stdoutRead,
        stderrDescriptor: stderrRead
    )
    stdoutPipe[0] = -1
    stderrPipe[0] = -1
    try drain.start(maximumOutputBytes: 1_024)
    try p1f1d075WritePipe(
        Data("live-drain".utf8),
        descriptor: stdoutPipe[1]
    )
    do {
        _ = try drain.finish()
        Issue.record("open writers must keep the first drain join bounded")
    } catch let error as EngineRuntimeAuthorityErrorV1 {
        #expect(error == .processGroupSurvived)
    } catch {
        Issue.record("wrong first live-drain timeout: \(error)")
    }
    try EngineRuntimeOwnedDescriptorV1.closeOnce(&stdoutPipe[1])
    try EngineRuntimeOwnedDescriptorV1.closeOnce(&stderrPipe[1])
    let output = try drain.finish()
    #expect(output.stdout == Data("live-drain".utf8))
    #expect(output.stderr.isEmpty)

    errno = 0
    let stdoutResult = Darwin.fcntl(stdoutRead, F_GETFD)
    let stdoutFailure = errno
    errno = 0
    let stderrResult = Darwin.fcntl(stderrRead, F_GETFD)
    let stderrFailure = errno
    #expect(stdoutResult == -1 && stdoutFailure == EBADF)
    #expect(stderrResult == -1 && stderrFailure == EBADF)
}

private final class P1F1D075LiveDrainManagedProcess:
    EngineManagedProbeProcessV1, @unchecked Sendable
{
    private let lock = NSLock()
    private let drain: EngineManagedProbeLiveDrainV1
    private let reaper: EngineManagedProbeBoundedLeaderReaperV1
    private let reapAttempts: P1F1D075LockedCounter
    private var stops = 0

    init(stdoutDescriptor: Int32, stderrDescriptor: Int32) {
        let attempts = P1F1D075LockedCounter()
        reapAttempts = attempts
        reaper = EngineManagedProbeBoundedLeaderReaperV1(
            deadline: ContinuousClock.now.advanced(by: .milliseconds(50)),
            waitNoHang: {
                attempts.increment()
                return .running
            }
        )
        drain = EngineManagedProbeLiveDrainV1(
            stdoutDescriptor: stdoutDescriptor,
            stderrDescriptor: stderrDescriptor
        )
    }

    func startBoundedConcurrentDrain(maximumOutputBytes: Int) throws {
        try drain.start(maximumOutputBytes: maximumOutputBytes)
    }

    func verifySuspendedImage() throws {}
    func resumeSuspended() throws {}
    func send(signal: Int32) throws {}

    func nextObservation() throws -> EngineManagedProbeObservationV1 {
        .deadline
    }

    func processGroupExists() throws -> Bool { true }

    func stopDrains() {
        lock.withLock { stops += 1 }
        drain.stop()
    }

    func finishDrains() throws -> EngineManagedProbeCapturedOutputV1 {
        try drain.finish()
    }

    func reapLeader() throws -> Int32 {
        try reaper.reap(observedStatus: nil)
    }

    var stopCount: Int { lock.withLock { stops } }
    var activeWorkerCount: Int { drain.activeWorkerCount }
    var reapAttemptCount: Int { reapAttempts.value }
}

private enum P1F1D075SurvivingGroupEntry {
    case run
    case abortSuspended
}

private func p1f1d075ContainsProcessGroupSurvived(
    _ error: any Error
) -> Bool {
    if (error as? EngineRuntimeAuthorityErrorV1)
        == .processGroupSurvived
    {
        return true
    }
    guard let aggregate = error as? EngineRuntimeCleanupAggregateErrorV1
    else { return false }
    return p1f1d075ContainsProcessGroupSurvived(aggregate.primary)
        || aggregate.cleanupFailures.contains {
            p1f1d075ContainsProcessGroupSurvived($0)
        }
}

private func p1f1d075AssertNoSecondDrainClose(
    process: P1F1D075LiveDrainManagedProcess,
    closedDescriptors: [Int32]
) throws {
    var sentinels: [Int32] = []
    defer {
        for descriptor in sentinels {
            #expect(Darwin.close(descriptor) == 0)
        }
    }
    for target in closedDescriptors {
        let source = Darwin.open("/dev/null", O_RDONLY)
        guard source >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        if source == target {
            sentinels.append(target)
            continue
        }
        let duplicated = Darwin.dup2(source, target)
        let duplicateFailure = errno
        #expect(Darwin.close(source) == 0)
        guard duplicated == target else {
            throw EngineRuntimeAuthorityErrorV1
                .descriptorFailure(duplicateFailure)
        }
        sentinels.append(target)
    }

    #expect(throws: EngineRuntimeAuthorityErrorV1.managedPolicy) {
        _ = try process.finishDrains()
    }
    for descriptor in sentinels {
        #expect(Darwin.fcntl(descriptor, F_GETFD) >= 0)
    }
}

private func p1f1d075AssertSurvivingGroupStopsLiveDrain(
    entry: P1F1D075SurvivingGroupEntry
) throws {
    var stdoutPipe = [Int32](repeating: -1, count: 2)
    guard stdoutPipe.withUnsafeMutableBufferPointer({
        Darwin.pipe($0.baseAddress!)
    }) == 0 else {
        throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
    }
    var stderrPipe = [Int32](repeating: -1, count: 2)
    guard stderrPipe.withUnsafeMutableBufferPointer({
        Darwin.pipe($0.baseAddress!)
    }) == 0 else {
        let primary = EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        for descriptor in stdoutPipe where descriptor >= 0 {
            #expect(Darwin.close(descriptor) == 0)
        }
        throw primary
    }
    defer {
        for descriptor in stdoutPipe + stderrPipe where descriptor >= 0 {
            #expect(Darwin.close(descriptor) == 0)
        }
    }

    let stdoutRead = stdoutPipe[0]
    let stderrRead = stderrPipe[0]
    let process = P1F1D075LiveDrainManagedProcess(
        stdoutDescriptor: stdoutRead,
        stderrDescriptor: stderrRead
    )
    stdoutPipe[0] = -1
    stderrPipe[0] = -1
    let started = ContinuousClock.now
    do {
        switch entry {
        case .run:
            _ = try EngineManagedProbeLifecycleV1.run(
                process: process,
                maximumOutputBytes: 1_024
            )
        case .abortSuspended:
            try EngineManagedProbeLifecycleV1.abortSuspended(
                process: process,
                maximumOutputBytes: 1_024
            )
        }
        Issue.record("surviving process group must fail closed")
    } catch {
        #expect(p1f1d075ContainsProcessGroupSurvived(error))
    }
    #expect(started.duration(to: .now) < .seconds(4))
    #expect(process.stopCount == 1)
    #expect(process.activeWorkerCount == 0)
    #expect(process.reapAttemptCount > 0)

    errno = 0
    let stdoutResult = Darwin.fcntl(stdoutRead, F_GETFD)
    let stdoutFailure = errno
    errno = 0
    let stderrResult = Darwin.fcntl(stderrRead, F_GETFD)
    let stderrFailure = errno
    #expect(stdoutResult == -1 && stdoutFailure == EBADF)
    #expect(stderrResult == -1 && stderrFailure == EBADF)
    try p1f1d075AssertNoSecondDrainClose(
        process: process,
        closedDescriptors: [stdoutRead, stderrRead]
    )
}

private final class P1F1D075ManagedProbeProcess:
    EngineManagedProbeProcessV1, @unchecked Sendable
{
    private let lock = NSLock()
    private var observations: [EngineManagedProbeObservationV1]
    private var existence: [Bool]
    private var drainWaitResults: [Bool]
    private let verificationError: Bool
    private let failingSignals: Set<Int32>
    private var stored: [String] = []
    private var closedDrainDescriptors = 0
    private let drainBarrier = EngineManagedProbeDrainBarrierV1()

    init(
        observations: [EngineManagedProbeObservationV1],
        existence: [Bool],
        drainWaitResults: [Bool] = [true],
        verificationError: Bool = false,
        failingSignals: Set<Int32> = []
    ) {
        self.observations = observations
        self.existence = existence
        self.drainWaitResults = drainWaitResults
        self.verificationError = verificationError
        self.failingSignals = failingSignals
    }

    func startBoundedConcurrentDrain(maximumOutputBytes: Int) throws {
        lock.withLock { stored.append("drain:\(maximumOutputBytes)") }
        try drainBarrier.startDraining()
    }

    func verifySuspendedImage() throws {
        try lock.withLock {
            stored.append("verify")
            if verificationError {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
        }
    }

    func resumeSuspended() throws {
        lock.withLock { stored.append("resume") }
    }

    func send(signal: Int32) throws {
        try lock.withLock {
            stored.append("signal:\(signal)")
            if failingSignals.contains(signal) {
                throw EngineRuntimeAuthorityErrorV1.processSignal(EIO)
            }
        }
    }

    func nextObservation() throws -> EngineManagedProbeObservationV1 {
        try lock.withLock {
            stored.append("observe")
            guard !observations.isEmpty else {
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            }
            return observations.removeFirst()
        }
    }

    func processGroupExists() throws -> Bool {
        lock.withLock {
            stored.append("exists")
            return existence.isEmpty ? false : existence.removeFirst()
        }
    }

    func stopDrains() {
        lock.withLock { stored.append("stop-drains") }
    }

    func finishDrains() throws -> EngineManagedProbeCapturedOutputV1 {
        lock.withLock { stored.append("finish-drains") }
        return try drainBarrier.join(
            waitUntilClosed: { _ in
                self.lock.withLock {
                    guard !self.drainWaitResults.isEmpty else { return true }
                    return self.drainWaitResults.removeFirst()
                }
            },
            result: {
                self.lock.withLock { self.closedDrainDescriptors += 2 }
                return EngineManagedProbeCapturedOutputV1(
                    stdout: Data("ok".utf8),
                    stderr: Data()
                )
            }
        )
    }

    func reapLeader() throws -> Int32 {
        lock.withLock { stored.append("reap") }
        return 0
    }

    var effects: [String] { lock.withLock { stored } }
    var drainDescriptorCloseCount: Int {
        lock.withLock { closedDrainDescriptors }
    }
}

private func p1f1d075AssertManagedProbeCleanup() throws {
    let timeoutThenJoin = P1F1D075ManagedProbeProcess(
        observations: [.exited(status: 0)],
        existence: [false, false],
        drainWaitResults: [false, true]
    )
    let cases: [P1F1D075ManagedProbeProcess] = [
        P1F1D075ManagedProbeProcess(
            observations: [], existence: [true, false],
            verificationError: true
        ),
        P1F1D075ManagedProbeProcess(
            observations: [.exited(status: 0)],
            existence: [true, true, false]
        ),
        P1F1D075ManagedProbeProcess(
            observations: [.deadline], existence: [true, false]
        ),
        P1F1D075ManagedProbeProcess(
            observations: [.outputLimit], existence: [true, false]
        ),
        P1F1D075ManagedProbeProcess(
            observations: [.deadline], existence: [true, false],
            failingSignals: [SIGTERM]
        ),
        timeoutThenJoin,
    ]
    for process in cases {
        do {
            _ = try EngineManagedProbeLifecycleV1.run(
                process: process,
                maximumOutputBytes: 64 * 1_024
            )
            Issue.record("managed probe fault must fail closed")
        } catch is EngineRuntimeAuthorityErrorV1 {
        } catch is EngineRuntimeCleanupAggregateErrorV1 {
        } catch {
            Issue.record("unexpected managed probe error: \(error)")
        }
        let effects = process.effects
        #expect(effects.contains("signal:\(SIGTERM)"))
        #expect(effects.contains("signal:\(SIGCONT)"))
        #expect(effects.contains("signal:\(SIGKILL)"))
        #expect(effects.contains("exists"))
        #expect(effects.contains("finish-drains"))
        #expect(effects.last == "reap")
        let term = try #require(effects.firstIndex(of: "signal:\(SIGTERM)"))
        let cont = try #require(effects.firstIndex(of: "signal:\(SIGCONT)"))
        let kill = try #require(effects.firstIndex(of: "signal:\(SIGKILL)"))
        #expect(term < cont && cont < kill)
    }
    let timeoutEffects = timeoutThenJoin.effects
    #expect(timeoutEffects.filter { $0 == "finish-drains" }.count == 2)
    #expect(timeoutThenJoin.drainDescriptorCloseCount == 2)
    let timeoutKill = try #require(
        timeoutEffects.firstIndex(of: "signal:\(SIGKILL)")
    )
    let timeoutJoin = try #require(
        timeoutEffects.lastIndex(of: "finish-drains")
    )
    #expect(timeoutKill < timeoutJoin)

    let abortTimeoutThenJoin = P1F1D075ManagedProbeProcess(
        observations: [],
        existence: [false],
        drainWaitResults: [false, true]
    )
    try EngineManagedProbeLifecycleV1.abortSuspended(
        process: abortTimeoutThenJoin,
        maximumOutputBytes: 64 * 1_024
    )
    let abortEffects = abortTimeoutThenJoin.effects
    #expect(abortEffects.filter { $0 == "finish-drains" }.count == 2)
    #expect(abortTimeoutThenJoin.drainDescriptorCloseCount == 2)
    let abortKill = try #require(
        abortEffects.firstIndex(of: "signal:\(SIGKILL)")
    )
    let abortJoin = try #require(
        abortEffects.lastIndex(of: "finish-drains")
    )
    #expect(abortKill < abortJoin)
}

private func p1f1d075AssertR9DCompositionContract() async throws {
    let diagnosticId = UUID()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 0
    )
    try await p1f1d075AssertGenerationComposition()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 0
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 1
    )
    try await p1f1d075AssertFailedAttemptOwnership()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 1
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 2
    )
    try await p1f1d075AssertAcquisitionTransactionUnwind()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 2
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 3
    )
    try await p1f1d075AssertOuterAcquisitionGuard()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 3
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 4
    )
    try await p1f1d075AssertBridgeAttemptOwnership()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 4
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 5
    )
    try await p1f1d075AssertSynchronousLazySeed()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 5
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 6
    )
    try p1f1d075AssertLiveDrainOwnership()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 6
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 7
    )
    try p1f1d075AssertSurvivingGroupStopsLiveDrain(entry: .run)
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 7
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 8
    )
    try p1f1d075AssertSurvivingGroupStopsLiveDrain(
        entry: .abortSuspended
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 8
    )
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionStarted, owner: diagnosticId, value: 9
    )
    try p1f1d075AssertManagedProbeCleanup()
    RuntimeLifecycleDiagnostics.event(
        .probeCompositionCompleted, owner: diagnosticId, value: 9
    )
}

@Test func p1f1_075CLIHelpCapabilityMismatchIsUnsupported() async throws {
    try await p1f1d075AssertR9DCompositionContract()
    let environment = ProcessInfo.processInfo.environment
    let closedStdioFixture =
        environment["AGENTLOOP_R9C_CLOSED_STDIO"] == "help"
    let base: URL
    if closedStdioFixture {
        guard let path = environment["AGENTLOOP_R9C_FIXTURE_BASE"] else {
            throw P1F1D075ClosedStdioFixtureError.evidence
        }
        base = URL(fileURLWithPath: path, isDirectory: true)
    } else {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("p1f1d-075-\(UUID().uuidString)")
    }
    try FileManager.default.createDirectory(
        at: base,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }
    if !closedStdioFixture {
        let fixtureBase = base.appendingPathComponent(
            "closed-stdio-help-work"
        )
        let evidence = base.appendingPathComponent(
            "closed-stdio-help.evidence"
        )
        try p1f1d075RunClosedStdioSubprocess(
            base: fixtureBase,
            evidence: evidence
        )
    }
    let command = base
        .appendingPathComponent("codex-authority")
        .appendingPathComponent("executable")
    let invocations = base.appendingPathComponent("invocations.log")
    let rootOutput = "-a\n-C\n-s\n-m\nexec\n"
    let firstOutput = "--ignore-user-config\n--ignore-rules\n--strict-config\n--skip-git-repo-check\n-c\n--json\nresume\n"
    let resumeOutput = "--ignore-user-config\n--ignore-rules\n--strict-config\n--skip-git-repo-check\n-c\n--json\nresume\n"
    let script = """
    #!/bin/sh
    printf '%s\\n' "$*" >> "\(invocations.path)"
    if [ "$1" = "--version" ]; then
      printf '%s\\n' 'codex-cli 0.144.5'
      exit 0
    fi
    if [ "$1" = "--help" ]; then
      printf '%s' '\(rootOutput)'
      exit 0
    fi
    if [ "$1" = "exec" ] && [ "$2" = "--help" ]; then
      printf '%s' '\(firstOutput)'
      exit 0
    fi
    if [ "$1" = "exec" ] && [ "$2" = "resume" ] && [ "$3" = "--help" ]; then
      printf '%s' '\(resumeOutput)'
      exit 0
    fi
    exit 97
    """
    let authority = try p1f1d075WriteExecutable(script, at: command)
    let inspector = P1F1D075ProcessInspector(authority: authority)
    let probe = CliHelpProbeV1(processInspector: inspector)
    if closedStdioFixture {
        _ = await LoginShellEnvironment.shared.environment()
        try p1f1d075CloseFixtureStandardDescriptors()
    }
    let snapshot = try await probe.snapshot(
        for: .cliCodex,
        authority: authority
    )

    #expect(snapshot.kind == .cliCodex)
    #expect(snapshot.command == "codex")
    #expect(snapshot.executableAuthority == authority)
    #expect(snapshot.versionLine == "codex-cli 0.144.5")
    #expect(snapshot.rootExitStatus == 0)
    #expect(snapshot.firstExitStatus == 0)
    #expect(snapshot.resumeExitStatus == 0)
    #expect(snapshot.rootFlags == ["-C", "-a", "-m", "-s"])
    #expect(snapshot.firstFlags == ["--ignore-rules", "--ignore-user-config", "--json", "--skip-git-repo-check", "--strict-config", "-c"])
    #expect(snapshot.resumeFlags == ["--ignore-rules", "--ignore-user-config", "--json", "--skip-git-repo-check", "--strict-config", "-c"])
    #expect(snapshot.subcommands == ["resume"])
    #expect(snapshot.rootStdoutHash == CanonicalJSONV1.sha256Hex(Data(rootOutput.utf8)))
    #expect(
        snapshot.firstStdoutHash
            == CanonicalJSONV1.sha256Hex(Data(firstOutput.utf8))
    )
    #expect(
        snapshot.resumeStdoutHash
            == CanonicalJSONV1.sha256Hex(Data(resumeOutput.utf8))
    )
    #expect(
        try String(contentsOf: invocations, encoding: .utf8)
            == "--version\n--help\nexec --help\nexec resume --help\n"
    )
    if closedStdioFixture {
        #expect(snapshot.versionLine == "codex-cli 0.144.5")
        #expect(snapshot.resumeExitStatus == 0)
        for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
            let result = fcntl(descriptor, F_GETFD)
            let failure = errno
            #expect(result == -1)
            #expect(failure == EBADF)
        }
        guard let evidencePath =
                environment["AGENTLOOP_R9C_FIXTURE_EVIDENCE"]
        else {
            throw P1F1D075ClosedStdioFixtureError.evidence
        }
        try "closed-stdio-help-ok\n".write(
            to: URL(fileURLWithPath: evidencePath),
            atomically: true,
            encoding: .utf8
        )
        return
    }

    let cache = CliHelpSnapshotCacheV1(probe: probe)
    async let cachedA = cache.snapshot(for: authority)
    async let cachedB = cache.snapshot(for: authority)
    let concurrent = try await [cachedA, cachedB]
    #expect(concurrent == [snapshot, snapshot])
    let invocationLines = try String(
        contentsOf: invocations,
        encoding: .utf8
    ).split(separator: "\n")
    #expect(invocationLines.count == 8)

    for mutation in [
        P1F1D075InspectorMutation.executablePath,
        .executableHash,
        .designatedRequirement,
        .cdHash,
    ] {
        inspector.select(authority, mutation: mutation)
        await p1f1d075ExpectProbeFailure(.processImageIdentity) {
            _ = try await probe.snapshot(
                for: .cliCodex,
                authority: authority
            )
        }
    }
    #expect(inspector.signals.contains { $0.0 == SIGKILL || $0.0 == SIGTERM })
    inspector.select(authority)

    let driftPath = base
        .appendingPathComponent("drift-authority")
        .appendingPathComponent("executable")
    let driftAuthority = try p1f1d075WriteExecutable(script, at: driftPath)
    try "drift".write(to: driftPath, atomically: true, encoding: .utf8)
    await p1f1d075ExpectProbeFailure(.stagedIdentity) {
        _ = try await probe.snapshot(
            for: .cliCodex,
            authority: driftAuthority
        )
    }

    let changedScript = script + "\n# distinct immutable generation\n"
    let changedPath = base
        .appendingPathComponent("changed-authority")
        .appendingPathComponent("executable")
    let changedAuthority = try p1f1d075WriteExecutable(
        changedScript,
        at: changedPath
    )
    inspector.select(changedAuthority)
    let changedSnapshot = try await cache.snapshot(for: changedAuthority)
    #expect(changedSnapshot.executableAuthority != authority)
    #expect(changedSnapshot.executableAuthority.executableHash != authority.executableHash)

    let failedPath = base
        .appendingPathComponent("failed-authority")
        .appendingPathComponent("executable")
    let failedAuthority = try p1f1d075WriteExecutable(
        "#!/bin/sh\nexit 97\n",
        at: failedPath
    )
    inspector.select(failedAuthority)
    async let failedA = p1f1d075CaptureProbeFailure {
        _ = try await cache.snapshot(for: failedAuthority)
    }
    async let failedB = p1f1d075CaptureProbeFailure {
        _ = try await cache.snapshot(for: failedAuthority)
    }
    let failedResults = await [failedA, failedB]
    #expect(failedResults == [.exitStatus, .exitStatus])
    #expect(
        !FileManager.default.fileExists(
            atPath: failedPath.deletingLastPathComponent().path
        )
    )
    let retryAuthority = try p1f1d075WriteExecutable(script, at: failedPath)
    inspector.select(retryAuthority)
    _ = try await cache.snapshot(for: retryAuthority)

    let hungPath = base
        .appendingPathComponent("hung-authority")
        .appendingPathComponent("executable")
    let hungAuthority = try p1f1d075WriteExecutable(
        "#!/bin/sh\nexec /bin/sleep 30\n",
        at: hungPath
    )
    inspector.select(hungAuthority)
    await p1f1d075ExpectProbeFailure(.deadline, context: "hung probe") {
        _ = try await probe.snapshot(for: .cliCodex, authority: hungAuthority)
    }

    let forkingPath = base
        .appendingPathComponent("forking-authority")
        .appendingPathComponent("executable")
    let forkingAuthority = try p1f1d075WriteExecutable(
        """
        #!/bin/sh
        child_pid=''
        trap 'wait "$child_pid"; exit 0' TERM
        /bin/sleep 30 &
        child_pid=$!
        wait "$child_pid"
        """,
        at: forkingPath
    )
    inspector.select(forkingAuthority)
    await p1f1d075ExpectProbeFailure(
        .deadline,
        context: "forking probe"
    ) {
        _ = try await probe.snapshot(
            for: .cliCodex,
            authority: forkingAuthority
        )
    }

    let oversizedPath = base
        .appendingPathComponent("oversized-authority")
        .appendingPathComponent("executable")
    let oversizedAuthority = try p1f1d075WriteExecutable(
        "#!/bin/sh\nwhile :; do printf '0123456789abcdef'; done\n",
        at: oversizedPath
    )
    inspector.select(oversizedAuthority)
    await p1f1d075ExpectProbeFailure(.stdoutLimit) {
        _ = try await probe.snapshot(
            for: .cliCodex,
            authority: oversizedAuthority
        )
    }

    let continuousStderrPath = base
        .appendingPathComponent("continuous-stderr-authority")
        .appendingPathComponent("executable")
    let continuousStderrAuthority = try p1f1d075WriteExecutable(
        "#!/bin/sh\nwhile :; do printf '0123456789abcdef' >&2; done\n",
        at: continuousStderrPath
    )
    inspector.select(continuousStderrAuthority)
    await p1f1d075ExpectProbeFailure(
        .deadline,
        context: "continuous stderr probe"
    ) {
        _ = try await probe.snapshot(
            for: .cliCodex,
            authority: continuousStderrAuthority
        )
    }

    let productionStaging = base.appendingPathComponent("production-stage")
    try FileManager.default.createDirectory(
        at: productionStaging,
        withIntermediateDirectories: true
    )
    let productionAuthority = try probe.identifyAndStage(
        for: .cliCodex,
        command: "codex",
        stagingDirectory: productionStaging
    )
    let expectedProductionNativePath = try
        p1f1d075ExpectedProductionCodexNativePath(
            forWrapper: productionAuthority.commandSourcePath
        )
    #expect(productionAuthority.commandSourcePath.hasSuffix("/@openai/codex/bin/codex.js"))
    #expect(
        productionAuthority.resolvedExecutablePath
            == expectedProductionNativePath
    )
    #expect(productionAuthority.commandSourcePath != productionAuthority.resolvedExecutablePath)
    try probe.removeStagedAuthority(productionAuthority)

    await p1f1d075ExpectProbeFailure(.sourceIdentity) {
        _ = try probe.identifyAndStage(
            for: .cliCodex,
            command: command.path,
            stagingDirectory: productionStaging
        )
    }

    let profile = RuntimeProfileRecord(
        id: "40000000-0000-4000-8000-000000000075",
        kind: .cliCodex,
        name: "P1-F1D missing -c",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let factories = EngineAdapterFactoryV1.builtInFactories(
        makeModelLoopAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        },
        makeCodexAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        },
        makeClaudeAdapter: { _, _ in
            throw P1F1D075UnexpectedFactoryInvocation.invoked
        }
    ).filter { $0.profileKinds == [.cliCodex] }
    #expect(factories.map(\.adapterId) == ["agentloop.cli.codex"])
    let registrationCount = P1F1D075LockedCounter()
    try factories[0].validateRegistration(
        helpSnapshot: snapshot,
        validateCodexManagedPolicy: { received in
            #expect(received == authority)
            registrationCount.increment()
        },
        validateClaudeManagedPolicy: nil
    )
    #expect(registrationCount.value == 1)
    p1f1d075ExpectSelectionFailure {
        try factories[0].validateRegistration(
            helpSnapshot: snapshot,
            validateCodexManagedPolicy: nil,
            validateClaudeManagedPolicy: nil
        )
    }
    p1f1d075ExpectSelectionFailure {
        try factories[0].validateRegistration(
            helpSnapshot: snapshot,
            validateCodexManagedPolicy: { _ in
                throw EngineContextValidationErrorV1()
            },
            validateClaudeManagedPolicy: nil
        )
    }

    let generationB = try p1f1dCLIExecutableAuthority(
        kind: .cliCodex,
        stagedPath: authority.stagedPath,
        generation: 79
    )
    let generationBSnapshot = try CliHelpSnapshotV1(
        executableAuthority: generationB,
        versionLine: snapshot.versionLine,
        rootExitStatus: snapshot.rootExitStatus,
        rootStdoutHash: snapshot.rootStdoutHash,
        firstExitStatus: snapshot.firstExitStatus,
        firstStdoutHash: snapshot.firstStdoutHash,
        resumeExitStatus: snapshot.resumeExitStatus,
        resumeStdoutHash: snapshot.resumeStdoutHash,
        rootFlags: snapshot.rootFlags,
        firstFlags: snapshot.firstFlags,
        resumeFlags: snapshot.resumeFlags,
        subcommands: snapshot.subcommands
    )
    p1f1d075ExpectSelectionFailure {
        try factories[0].validateRegistration(
            helpSnapshot: generationBSnapshot,
            validateCodexManagedPolicy: { received in
                guard received == authority else {
                    throw EngineContextValidationErrorV1()
                }
            },
            validateClaudeManagedPolicy: nil
        )
    }

    let claudeAuthority = try p1f1dCLIExecutableAuthority(
        kind: .cliClaude,
        stagedPath: "/tmp/fake-claude"
    )
    let claudeSnapshot = try CliHelpSnapshotV1(
        executableAuthority: claudeAuthority,
        versionLine: "2.1.81 (Claude Code)",
        rootExitStatus: 0,
        rootStdoutHash: String(repeating: "8", count: 64),
        firstExitStatus: 0,
        firstStdoutHash: String(repeating: "9", count: 64),
        resumeExitStatus: 0,
        resumeStdoutHash: String(repeating: "9", count: 64),
        rootFlags: [],
        firstFlags: [
            "--add-dir", "--allowedTools", "--disable-slash-commands",
            "--input-format", "--mcp-config", "--model", "--no-chrome",
            "--output-format", "--permission-mode", "--resume",
            "--session-id", "--setting-sources", "--strict-mcp-config",
            "--tools", "--verbose", "-p",
        ].sorted(),
        resumeFlags: [
            "--add-dir", "--allowedTools", "--disable-slash-commands",
            "--input-format", "--mcp-config", "--model", "--no-chrome",
            "--output-format", "--permission-mode", "--resume",
            "--session-id", "--setting-sources", "--strict-mcp-config",
            "--tools", "--verbose", "-p",
        ].sorted(),
        subcommands: []
    )
    let claudeFactory = try #require(
        EngineAdapterFactoryV1.builtInFactories(
            makeModelLoopAdapter: { _, _ in
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            },
            makeCodexAdapter: { _, _ in
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            },
            makeClaudeAdapter: { _, _ in
                throw P1F1D075UnexpectedFactoryInvocation.invoked
            }
        ).first { $0.profileKinds == [.cliClaude] }
    )
    let receivedClaude = P1F1D075AuthorityRecorder()
    try claudeFactory.validateRegistration(
        helpSnapshot: claudeSnapshot,
        validateCodexManagedPolicy: nil,
        validateClaudeManagedPolicy: { receivedClaude.append($0) }
    )
    #expect(receivedClaude.values == [claudeAuthority])
    p1f1d075ExpectSelectionFailure {
        try factories[0].validateRegistration(
            helpSnapshot: claudeSnapshot,
            validateCodexManagedPolicy: { _ in },
            validateClaudeManagedPolicy: nil
        )
    }

    let degradedSnapshot = try CliHelpSnapshotV1(
        executableAuthority: authority,
        versionLine: "codex-cli 0.144.5",
        rootExitStatus: 0,
        rootStdoutHash: snapshot.rootStdoutHash,
        firstExitStatus: 0,
        firstStdoutHash: snapshot.firstStdoutHash,
        resumeExitStatus: 0,
        resumeStdoutHash: snapshot.resumeStdoutHash,
        rootFlags: snapshot.rootFlags,
        firstFlags: snapshot.firstFlags.filter { $0 != "-c" },
        resumeFlags: snapshot.resumeFlags.filter { $0 != "-c" },
        subcommands: snapshot.subcommands
    )
    let registry = try EngineAdapterRegistryV1(
        factories: factories,
        helpSnapshots: [.cliCodex: degradedSnapshot]
    )
    do {
        _ = try registry.resolve(
            profile: profile,
            requiredCapabilities: [.boardTerminal]
        )
        Issue.record("missing -c must not satisfy Board capability")
    } catch let error as EngineAdapterSelectionErrorV1 {
        #expect(error == .unsupportedCapability(.boardTerminal))
    } catch {
        throw error
    }
}
