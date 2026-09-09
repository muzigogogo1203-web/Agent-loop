import Foundation

/// 活跃子进程注册表（M7-D6）：shell 与 M8 MCP 子进程统一登记，
/// 行动取消 / 紧急收哨 / App 退出时终止，防僵尸。
/// 用锁而非 actor：App 退出钩子（applicationWillTerminate）是同步上下文。
/// 限制申报：terminate 只送达直接子进程，孙进程逃逸靠各工具自身超时兜底。
public final class ShellProcessRegistry: @unchecked Sendable {
    public static let shared = ShellProcessRegistry()

    private let lock = NSLock()
    private var pids: Set<Int32> = []

    public init() {}

    public func register(_ pid: Int32) {
        lock.lock()
        defer { lock.unlock() }
        pids.insert(pid)
    }

    public func unregister(_ pid: Int32) {
        lock.lock()
        defer { lock.unlock() }
        pids.remove(pid)
    }

    public var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pids.count
    }

    /// 终止全部登记中的子进程（SIGTERM）。收哨与退出钩子调用。
    public func terminateAll() {
        lock.lock()
        let snapshot = pids
        pids.removeAll()
        lock.unlock()
        for pid in snapshot {
            let diagnostic = RuntimeLifecycleDiagnostics.isEnabled
                ? RuntimeLifecycleDiagnostics.signalWillSend(
                    target: pid, signal: SIGTERM,
                    path: self === Self.shared ? 2 : 1
                )
                : nil
            let result = kill(pid, SIGTERM)
            let failure = errno
            RuntimeLifecycleDiagnostics.signalDidSend(
                owner: diagnostic, result: result, errorNumber: failure
            )
        }
    }
}

/// 登录 shell 环境捕获（M7-D6）：Finder 启动的 GUI app 只有极简 PATH，
/// shell 命令与 npx/uvx 拉起的 MCP server 会找不到可执行文件（桌面 agent 宿主经典坑）。
/// 启动后异步捕获一次（zsh -l -c env），shell 工具与 M8 MCP 子进程共用。
/// 锁保护缓存与 single-flight 任务，并发首用只捕获一次。
public final class LoginShellEnvironment: @unchecked Sendable {
    public static let shared = LoginShellEnvironment()

    private enum Resolution {
        case cached([String: String])
        case pending(Task<[String: String], Never>)
    }

    private let lock = NSLock()
    private let captureEnvironment: @Sendable () async -> [String: String]
    private var cached: [String: String]?
    private var inFlight: Task<[String: String], Never>?

    public init() {
        captureEnvironment = {
            await Self.capture()
        }
    }

    package init(
        capture: @escaping @Sendable () async -> [String: String]
    ) {
        captureEnvironment = capture
    }

    /// 捕获过的登录环境（合并进程环境兜底）；捕获失败返回进程环境。
    public func environment() async -> [String: String] {
        switch resolution() {
        case .cached(let existing):
            return existing
        case .pending(let task):
            let merged = await task.value
            finish(merged)
            return merged
        }
    }

    private func resolution() -> Resolution {
        lock.lock()
        defer { lock.unlock() }
        if let cached {
            return .cached(cached)
        }
        if let inFlight {
            return .pending(inFlight)
        }
        let base = ProcessInfo.processInfo.environment
        let capture = captureEnvironment
        let task = Task.detached {
            let captured = await capture()
            return base.merging(captured) { _, fromLogin in fromLogin }
        }
        inFlight = task
        return .pending(task)
    }

    private func finish(_ environment: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        if cached == nil {
            cached = environment
        }
        inFlight = nil
    }

    package static func capture() async -> [String: String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", "env"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: [:])
                    return
                }
                // 登录 rc 卡死兜底：5s 强制终止
                let deadline = DispatchTime.now() + 5
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(data: data, encoding: .utf8) ?? ""
                var result: [String: String] = [:]
                for line in text.split(separator: "\n") {
                    guard let eq = line.firstIndex(of: "=") else { continue }
                    let key = String(line[..<eq])
                    let value = String(line[line.index(after: eq)...])
                    if !key.isEmpty { result[key] = value }
                }
                continuation.resume(returning: result)
            }
        }
    }
}
