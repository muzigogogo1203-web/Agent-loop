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
    let task = Task {
        await tool.execute(input: ["command": "sleep 30"])
    }
    // 等进程登记
    var waited = 0
    while registry.activeCount == 0 && waited < 100 {
        try await Task.sleep(for: .milliseconds(20))
        waited += 1
    }
    #expect(registry.activeCount == 1)
    registry.terminateAll()  // 收哨/退出路径
    _ = await task.value
    #expect(registry.activeCount == 0)
}

@Test func loginShellEnvironmentCapturesPath() async {
    let env = await LoginShellEnvironment.capture()
    // 登录 shell 的 PATH 应存在且非空（本机 zsh；失败时返回空表也不崩）
    if let path = env["PATH"] {
        #expect(!path.isEmpty)
    }
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
    let mock = MockProvider(script: [
        TurnResult(content: [.toolUse(id: "s1", name: "run_shell",
                                      input: ["command": "touch 不该出现的文件"])],
                   stopReason: .toolUse),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("a"))
    for try await _ in try runner.run(
        cardId: ids.cardId, companionName: "n", rolePrompt: "r", autonomy: .standard) {}

    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("不该出现的文件").path))
    let approvals = try await db.pool.read { database in
        try UserRequestRecord.filter(Column("cardId") == ids.cardId).fetchAll(database)
    }
    #expect(approvals.first?.kind == .approval)
}
