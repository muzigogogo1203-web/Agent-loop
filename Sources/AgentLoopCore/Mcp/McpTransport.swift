import Foundation

/// MCP stdio 传输抽象（M8-D1/D3）：一条连接 = 一个子进程的 stdin/stdout，
/// 消息为换行分隔的 JSON-RPC 2.0。协议面极小，自写 MiniMCP 而非官方 SDK
/// （探针结论：SDK 的 StdioTransport 只接现成 fd，子进程生命周期仍需自管，
/// 却拖进 swift-nio 等六个传递依赖——桥接税大于收益）。
/// FakeTransport（测试）与 StdioProcessTransport（真子进程）共用此协议。
public protocol McpTransport: Sendable {
    /// 建立连接（拉起子进程/开始读取）。只调用一次。
    func start() async throws
    /// 发送一条完整消息（不含换行符，由传输层负责封帧）。
    func send(_ data: Data) async throws
    /// 逐条产出对端消息（已去封帧）。流结束/抛错 = 连接已死。
    var messages: AsyncThrowingStream<Data, Error> { get }
    /// 关闭连接并回收资源（幂等）。
    func close() async
}

/// 真子进程 stdio 传输：/usr/bin/env 解析 command（npx/uvx 依赖登录 PATH，
/// 由调用方在 environment 里合成，M7 LoginShellEnvironment），
/// PID 登记 ShellProcessRegistry（收哨/退出统一清理，M7-D6）。
public final class StdioProcessTransport: McpTransport, @unchecked Sendable {
    public let messages: AsyncThrowingStream<Data, Error>

    private let command: String
    private let args: [String]
    private let environment: [String: String]
    private let registry: ShellProcessRegistry
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation

    private let lock = NSLock()
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var closed = false
    /// 诊断用：stderr 尾部（server 启动失败时的人话线索）
    private var stderrTail = Data()

    private static let maxStderrTailBytes = 4096

    public init(
        command: String,
        args: [String],
        environment: [String: String],
        registry: ShellProcessRegistry = .shared
    ) {
        self.command = command
        self.args = args
        self.environment = environment
        self.registry = registry
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messages = AsyncThrowingStream { continuation = $0 }
        self.continuation = continuation
    }

    public func start() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        process.environment = environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let pid = process.processIdentifier
        registry.register(pid)

        // 对端先退时写 stdin 会触发 SIGPIPE（默认杀死整个 App）——按 fd 关掉
        let stdinFD = stdin.fileHandleForWriting.fileDescriptor
        _ = fcntl(stdinFD, F_SETNOSIGPIPE, 1)

        storeProcess(process, stdin: stdin.fileHandleForWriting)

        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.registry.unregister(pid)
            self.finishStream()
        }

        // 读取循环：换行分帧。readDataToEndOfFile 会阻塞，放专用后台线程。
        let stdoutHandle = stdout.fileHandleForReading
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var buffer = Data()
            while true {
                let chunk = stdoutHandle.availableData
                if chunk.isEmpty { break } // EOF：进程退出或管道关闭
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)
                    if !line.isEmpty {
                        self?.continuation.yield(Data(line))
                    }
                }
            }
            self?.finishStream()
        }
        let stderrHandle = stderr.fileHandleForReading
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                let chunk = stderrHandle.availableData
                if chunk.isEmpty { break }
                self?.appendStderr(chunk)
            }
        }
    }

    public func send(_ data: Data) async throws {
        let handle: FileHandle? = {
            lock.lock()
            defer { lock.unlock() }
            return closed ? nil : stdinHandle
        }()
        guard let handle else {
            throw McpClientError.connectionClosed
        }
        var framed = data
        framed.append(UInt8(ascii: "\n"))
        do {
            try handle.write(contentsOf: framed)
        } catch {
            throw McpClientError.connectionClosed
        }
    }

    public func close() async {
        let process: Process? = {
            lock.lock()
            defer { lock.unlock() }
            guard !closed else { return nil }
            closed = true
            return self.process
        }()
        guard let process else { return }
        try? stdinHandle?.close()
        if process.isRunning {
            process.terminate()
            try? await Task.sleep(for: .milliseconds(300))
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        finishStream()
    }

    /// server 启动失败时给设置页的人话线索（stderr 尾部）。
    public var stderrSnapshot: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: stderrTail, encoding: .utf8) ?? ""
    }

    private func storeProcess(_ process: Process, stdin: FileHandle) {
        lock.lock()
        defer { lock.unlock() }
        self.process = process
        self.stdinHandle = stdin
    }

    private func appendStderr(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        stderrTail.append(chunk)
        if stderrTail.count > Self.maxStderrTailBytes {
            stderrTail.removeFirst(stderrTail.count - Self.maxStderrTailBytes)
        }
    }

    private func finishStream() {
        continuation.finish()
    }
}
