import Testing
import Foundation
import GRDB
import AgentLoopCore

// M7-D6：shell 工具——执行/退出码/超时/截断/进程登记清理

private func tempWorkspace() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private actor LoginShellStartBarrier {
    private let participantCount: Int
    private var arrivals = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(participantCount: Int) {
        self.participantCount = participantCount
    }

    func wait() async {
        precondition(arrivals < participantCount)
        arrivals += 1
        if arrivals == participantCount {
            let pending = waiters
            waiters.removeAll()
            for waiter in pending {
                waiter.resume()
            }
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private actor LoginShellCaptureProbe {
    private var count = 0
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func capture() async -> [String: String] {
        count += 1
        let pendingStarts = startWaiters
        startWaiters.removeAll()
        for waiter in pendingStarts {
            waiter.resume()
        }
        await withCheckedContinuation { continuation in
            if released {
                continuation.resume()
            } else {
                releaseWaiters.append(continuation)
            }
        }
        return [
            "LOGIN_CAPTURE_MARKER": "single-flight",
            "PATH": "/single-flight/login/bin",
        ]
    }

    func waitUntilCaptureStarts() async {
        if count > 0 {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseCaptures() {
        released = true
        let pending = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func captureCount() -> Int {
        count
    }
}

@Test func shellRunsCommandInWorkspaceAndReportsExitCode() async throws {
    let workspace = try tempWorkspace()
    let tool = ShellTool(workspaceRoot: workspace)
    let outcome = await tool.execute(input: ["command": "echo 你好营地 && pwd"])
    guard case .result(let text) = outcome else {
        Issue.record("expected result")
        return
    }
    #expect(text.contains("退出码 0"))
    #expect(text.contains("你好营地"))
    // cwd 锁定小队工作目录（/private 前缀差异用 realpath 归一）
    let resolved = workspace.resolvingSymlinksInPath().path
    #expect(text.contains(resolved) || text.contains(workspace.path))
}

@Test func shellNonzeroExitIsResultNotError() async throws {
    // 退出码非零是结果不是工具错误：模型自判（测试跑挂了也要能看输出）
    let tool = ShellTool(workspaceRoot: try tempWorkspace())
    let outcome = await tool.execute(input: ["command": "echo 出错前的输出; exit 3"])
    guard case .result(let text) = outcome else {
        Issue.record("expected result")
        return
    }
    #expect(text.contains("退出码 3"))
    #expect(text.contains("出错前的输出"))
}

@Test func shellTimeoutTerminatesProcess() async throws {
    let registry = ShellProcessRegistry()
    let tool = ShellTool(
        workspaceRoot: try tempWorkspace(),
        timeout: .milliseconds(300),
        registry: registry
    )
    _ = await LoginShellEnvironment.shared.environment()
    let clock = ContinuousClock()
    let started = clock.now
    let outcome = await tool.execute(input: ["command": "echo 先输出这句; sleep 30"])
    let elapsed = clock.now - started
    guard case .error(let message) = outcome else {
        Issue.record("expected timeout error")
        return
    }
    #expect(message.contains("超时"))
    #expect(message.contains("先输出这句"))
    #expect(elapsed < .seconds(5))
    #expect(registry.activeCount == 0)
}

@Test func shellOutputTruncatedByteSafe() async throws {
    let tool = ShellTool(workspaceRoot: try tempWorkspace())
    // 60KB 输出 → 截断到 20KB 内 + 截断标记
    let outcome = await tool.execute(input: ["command": "head -c 60000 /dev/zero | tr '\\0' 'a'"])
    guard case .result(let text) = outcome else {
        Issue.record("expected result")
        return
    }
    #expect(text.utf8.count < 21_000)
    #expect(text.contains("截断"))
}

@Test func shellRejectsEmptyCommand() async throws {
    let tool = ShellTool(workspaceRoot: try tempWorkspace())
    let outcome = await tool.execute(input: ["command": "  "])
    guard case .error = outcome else {
        Issue.record("expected error")
        return
    }
}

@Test func shellRegistryTerminateAllKillsRunning() async throws {
    let registry = ShellProcessRegistry()
    let tool = ShellTool(workspaceRoot: try tempWorkspace(), timeout: .seconds(30), registry: registry)
    _ = await LoginShellEnvironment.shared.environment()
    let task = Task {
        await tool.execute(input: ["command": "sleep 30"])
    }
    // 等进程登记
    var waited = 0
    while registry.activeCount == 0 && waited < 100 {
        try await Task.sleep(for: .milliseconds(20))
        waited += 1
    }
    guard registry.activeCount == 1 else {
        task.cancel()
        _ = await task.value
        Issue.record("expected one registered shell process")
        return
    }
    registry.terminateAll()  // 收哨/退出路径
    _ = await task.value
    #expect(registry.activeCount == 0)
}

@Test func loginShellEnvironmentCapturesPath() async throws {
    let participantCount = 20
    let startBarrier = LoginShellStartBarrier(
        participantCount: participantCount
    )
    let probe = LoginShellCaptureProbe()
    let environment = LoginShellEnvironment(capture: {
        await probe.capture()
    })
    let values = await withTaskGroup(
        of: [String: String].self,
        returning: [[String: String]].self
    ) { group in
        for _ in 0..<participantCount {
            group.addTask {
                await startBarrier.wait()
                return await environment.environment()
            }
        }
        await probe.waitUntilCaptureStarts()
        await probe.releaseCaptures()
        var captured: [[String: String]] = []
        for await value in group {
            captured.append(value)
        }
        return captured
    }
    let count = await probe.captureCount()
    let first = try #require(values.first)
    #expect(count == 1)
    #expect(values.count == participantCount)
    #expect(first["PATH"] == "/single-flight/login/bin")
    #expect(first["LOGIN_CAPTURE_MARKER"] == "single-flight")
    #expect(values.allSatisfy { $0 == first })
}

@Test func dangerousShellSuspendsUnderStandardAutonomy() async throws {
    // 集成：标准档 + run_shell（dangerous）→ 审批挂起，命令不执行
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: workspace.path
    )
    let shellInput: JSONValue = [
        "command": "touch 不该出现的文件",
    ]
    let runId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: runId)
    let squad = try #require(try db.squad(forCard: ids.cardId))
    let gatedShell = ApprovalGateHandler(
        inner: ShellTool(workspaceRoot: workspace),
        toolName: "run_shell",
        autonomy: .standard,
        db: db,
        cardId: ids.cardId,
        runId: runId,
        campId: squad.campId
    )
    let outcome = await gatedShell.execute(input: shellInput)
    guard case let .blocked(reason, detail) = outcome else {
        Issue.record("dangerous shell must suspend for explicit approval")
        return
    }

    #expect(reason == "needs_human_input")
    #expect(detail == "等待你批准：跑命令")
    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("不该出现的文件").path))
    let approvals = try await db.pool.read { database in
        try UserRequestRecord.filter(Column("cardId") == ids.cardId).fetchAll(database)
    }
    #expect(approvals.count == 1)
    #expect(approvals.first?.kind == .approval)
}
