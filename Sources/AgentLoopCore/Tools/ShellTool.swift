import Foundation

/// shell 工具（M7-D6，dangerous 级）：/bin/zsh -c，锁定小队工作目录，
/// 超时终止、输出字节安全截断；进程登记 ShellProcessRegistry（收哨/退出统一清理）。
/// 危险面由审批矩阵把守（标准档必审），能力面由白名单把守。
public struct ShellTool: ToolHandler {
    let workspaceRoot: URL
    let timeout: Duration
    let registry: ShellProcessRegistry

    static let maxOutputBytes = 20_000

    public init(
        workspaceRoot: URL,
        timeout: Duration = KernelDefaults.shellTimeout,
        registry: ShellProcessRegistry = .shared
    ) {
        self.workspaceRoot = workspaceRoot
        self.timeout = timeout
        self.registry = registry
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard let command = input["command"]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else {
            return .error("需要非空的 command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = workspaceRoot
        process.environment = await LoginShellEnvironment.shared.environment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return .error("命令启动失败：\(error.localizedDescription)")
        }
        let pid = process.processIdentifier
        registry.register(pid)
        defer { registry.unregister(pid) }

        // 输出读取放后台线程（readDataToEndOfFile 随进程退出返回）
        async let outputData: Data = Self.readAll(pipe)

        // 超时/取消看护：轮询等待，越线 SIGTERM，宽限后 SIGKILL
        var timedOut = false
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while process.isRunning {
            if Task.isCancelled || clock.now >= deadline {
                timedOut = clock.now >= deadline
                process.terminate()
                try? await Task.sleep(for: .milliseconds(300))
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let raw = String(data: await outputData, encoding: .utf8) ?? ""
        let output = TextTruncation.truncateUTF8(
            raw, maxBytes: Self.maxOutputBytes, suffix: "\n…（输出已按 20KB 截断）")

        if Task.isCancelled {
            return .error("命令因任务取消被终止")
        }
        if timedOut {
            return .error("命令超时（\(timeout)）被终止。已捕获输出：\n\(output)")
        }
        let status = process.terminationStatus
        return .result("退出码 \(status)\n\(output)")
    }

    private static func readAll(_ pipe: Pipe) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }
    }
}
