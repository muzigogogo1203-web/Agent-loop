# Board socket 生命周期收尾（review 留存三项）

任务级别：Level 3（并发模型）。基线：main 011b2cf（本 worktree 分支 claude/magical-ptolemy-19d5ce）。

## 目标

修复 `git show ab96834` 之后 review 留存的三项：

1. 连接 fd 泄漏窗口：`BoardToolServer.acceptLoop()` 用 `[weak self]` 派发 `handle()`；若 server 在 `claimConnection` 之后、block 执行之前失去最后强引用，`handle()` 永不运行，连接 fd 泄漏（deinit→stop() 只 shutdown 不 close）。
2. listener fd 跨线程 close 竞态：`currentListenFD()` 锁内取 fd、锁外 `accept`，而 `stop()` 在锁外 `close(listenerToClose)`，close-then-reuse 窗口内 fd 号可能被复用，accept 到别人的连接。
3. SO_NOSIGPIPE 的 setsockopt 包装写了三遍且行为分叉（BoardServerBridgeMain.swift:227 throw 版 / BoardToolServer.swift:263 Bool 版 / BoardServerTests.swift:203-213 内联版），抽共享 helper。

## 非目标

- 不改 McpTransport.swift 的 `F_SETNOSIGPIPE`（那是 pipe fd，fcntl 路径，保持原样）。
- 不支持 BoardToolServer 的 stop 后重启复用（现有唯一调用方 CliProcessBackend 是一次性 start/stop）；只加防御性 guard，不做完整重启语义。
- 不回退「单一 close owner」不变量，不引入 double-close。

## 设计决策（Codex 不得偏离）

### 修复 1：handler block 强持 server

`acceptLoop()` 派发 `handle()` 时去掉 `[weak self]`，改为强捕获：

```swift
handlerQueue.async { self.handle(connection: connection) }
```

理由：block 只被队列持有到执行完毕，无 retain cycle；`handle()` 仍是连接 fd 的唯一 close owner；deinit 只可能在无 pending/运行中 handler block 时发生，「已 claim 未 handle」态在结构上不可能存在于 dealloc 时刻。

配套：`BoardToolServer.init` 新增参数 `handlerQueue: DispatchQueue = DispatchQueue.global(qos: .utility)`（public，带默认值，现有调用方零改动），存为 `private let handlerQueue`。仅 `handle()` 的派发用它；`start()` 里派发 acceptLoop 的 `DispatchQueue.global` 与 `[weak self]` **保持不变**（block 未跑时 server 可被释放，listener 由 stop()/deinit 兜底关闭，见修复 2）。此参数是测试注入点（挂起队列冻结「已 claim 未 handle」窗口）。

### 修复 2：listener close 所有权移交 acceptLoop + stop() 自连唤醒

**不要用 shutdown() 唤醒 listener**：macOS/BSD 对 listening socket 的 shutdown 返回 ENOTCONN 且不会唤醒阻塞中的 accept（Linux 行为不同）。AF_UNIX 有路径可用，用自连唤醒。

新增锁保护状态：`private var acceptLoopOwnsListener = false`。

`acceptLoop()` 改为进入时锁内 claim：

```swift
private func acceptLoop() {
    lock.lock()
    if stopped || listenFD < 0 {
        let fd = listenFD
        listenFD = -1
        lock.unlock()
        if fd >= 0 { close(fd) }
        return
    }
    let fd = listenFD
    acceptLoopOwnsListener = true
    lock.unlock()

    while !isStopped() {
        let connection = accept(fd, nil, nil)
        if connection < 0 {
            if isStopped() { break }
            continue
        }
        if isStopped() {          // 自连唤醒或 stop 后的迟到客户端
            close(connection)
            break
        }
        guard PosixSockets.disableSIGPIPE(connection) else {
            close(connection)
            continue
        }
        guard claimConnection(connection) else {
            close(connection)
            continue
        }
        handlerQueue.async { self.handle(connection: connection) }
    }

    close(fd)                     // listener 唯一 close 点（已 claim 分支）
    lock.lock()
    if listenFD == fd { listenFD = -1 }
    acceptLoopOwnsListener = false
    lock.unlock()
}
```

`stop()` 改为：

```swift
public func stop() {
    lock.lock()
    guard !stopped else { lock.unlock(); return }
    stopped = true
    if activeConnectionFD >= 0 {
        _ = shutdown(activeConnectionFD, SHUT_RDWR)   // 现有机制不变
    }
    let ownsTransferred = acceptLoopOwnsListener
    var listenerToClose: Int32 = -1
    if !ownsTransferred {
        listenerToClose = listenFD
        listenFD = -1                                  // 锁内收走所有权，acceptLoop 之后 claim 会看到 stopped/-1
    }
    lock.unlock()

    if ownsTransferred {
        Self.wakeAcceptLoop(socketPath: socketURL.path) // 自连唤醒，close 由 acceptLoop 负责
    } else if listenerToClose >= 0 {
        close(listenerToClose)
    }
    try? FileManager.default.removeItem(at: socketURL) // 必须在唤醒之后（唤醒 connect 需要 socket 文件）
}
```

`wakeAcceptLoop(socketPath:)`：建 AF_UNIX socket、connect 到 path（复用现有 sockaddr_un 组装逻辑或最小内联）、无论成败立即 close 本端 fd、忽略所有错误。connect 失败（如 backlog 已满）意味着 accept 队列里已有连接，acceptLoop 会因它醒来并在 `isStopped()` 检查处退出，无需重试。

`currentListenFD()` 删除（loop 内不再重读 fd）。`start()` 加防御：锁内若 `listenFD >= 0 || acceptLoopOwnsListener` 则 throw `socketSetupFailed("board server already started")`。更新 stop() 附近的中文注释以反映新所有权模型。

竞态论证（review 时逐条核对）：claim 与 stop 都在锁内串行化——stop 先行则 claim 看到 stopped/-1 自行退出或关闭；claim 先行则 stop 只唤醒不碰 fd，close 唯一发生在 acceptLoop 尾部。accept 只会作用于 acceptLoop 自己持有、且 stop() 永不 close 的 fd，复用窗口消失。

### 修复 3：共享 `PosixSockets.disableSIGPIPE`

新文件 `Sources/AgentLoopCore/Support/PosixSockets.swift`：

```swift
import Darwin

public enum PosixSockets {
    /// SO_NOSIGPIPE：对端先关时 write 返回 EPIPE 而不是 SIGPIPE 杀进程。
    /// 失败返回 false，errno 留给调用方取用。
    @discardableResult
    public static func disableSIGPIPE(_ fd: Int32) -> Bool {
        var enabled: Int32 = 1
        return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0
    }
}
```

三处替换：
- BoardToolServer.swift:263 `disableSIGPIPE` 私有方法删除，调用点改 `PosixSockets.disableSIGPIPE(connection)`。
- BoardServerBridgeMain.swift:227 私有 throw 版删除，调用点改 `guard PosixSockets.disableSIGPIPE(fd) else { throw BoardToolServerError.socketSetupFailed("SO_NOSIGPIPE: \(String(cString: strerror(errno)))") }`。
- BoardServerTests.swift:203-213 内联版删除，同样 guard+throw（保留失败时 `Darwin.close(fd)`）。

## 触及文件清单

| 文件 | 改动 |
|---|---|
| `Sources/AgentLoopCore/Loop/BoardToolServer.swift` | 修复 1+2：handlerQueue 参数、acceptLoop claim/owner 重写、stop() 自连唤醒、wakeAcceptLoop、删 currentListenFD、start() 防御 guard、用 PosixSockets |
| `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift` | 修复 3：删私有 disableSIGPIPE，用共享 helper |
| `Sources/AgentLoopCore/Support/PosixSockets.swift` | 新增 |
| `Sources/AgentLoopTestSuite/BoardServerTests.swift` | 修复 3 替换内联版；新增两个回归测试（见下） |

## 测试要求（`Sources/AgentLoopTestSuite/BoardServerTests.swift`）

沿用 `guard agentLoopCanBindListenerSocket() else { return }` 门。fd 计数用 `/dev/fd` 条目数；因 fd 计数是进程全局、其他 suite 可能并行，**断言用多轮增量阈值而非精确相等**（真泄漏每轮 +1，阈值远小于轮数即可稳定区分）。

### 回归 1：`boardServerHandlerBlockKeepsServerAliveUntilConnectionCloses`

针对修复 1，用挂起的 handlerQueue 确定性冻结「已 claim 未 handle」窗口。

（2026-07-17 blocked.md 裁决：原步骤漏了 stop()——acceptLoop 经 `self?.acceptLoop()` 调用期间新旧代码都强持 self，必须先 stop() 让 acceptLoop 退出释放强引用，weak 断言才有区分度。修正如下。）

1. 建挂起的串行队列 `queue.suspend()`，以 `handlerQueue: queue` 建 server 并 start。
2. 客户端 connect（不必等 hello_ok——handle 在挂起队列上不会跑）。用探针确认 claim 已发生：第二个客户端 connect 后 send hello，`readLine()` 应返回 nil（被 claim-fail 路径关闭）；有界自旋等待（≤2s）。
3. `server.stop()`（唤醒并退出 acceptLoop，释放其对 self 的强持有；活动连接 fd 仅被 shutdown，close 仍归挂起中的 handle()）。
4. `weak var weakServer = server; server = nil`；sleep 宽限期（200–500ms，给 acceptLoop 退出留时间）。**关键断言：`weakServer != nil`**——旧代码 handler block 弱持有，acceptLoop 退出后 server 立即 dealloc、weakServer 变 nil、连接 fd 泄漏，此断言必失败；新代码 block 强持 server，保持非 nil。
5. `queue.resume()`；有界自旋等 `weakServer == nil`（handle 因 shutdown 读到 EOF 退出、close fd、block 释放、deinit 完成）；客户端 `readLine()` 返回 nil 后 `close()`。
6. 泄漏断言：整个场景循环 20 轮（每轮独立 server/queue/client），结束后 fd 数相对基线增量 < 10（旧代码每轮泄 1 个连接 fd，共 20+）。

### 回归 2：`boardServerStopWakesBlockedAcceptLoopAndReleasesListener`

针对修复 2，验证自连唤醒 + listener 唯一 close：

1. fd 基线。建 server、start，无客户端；接一个探针客户端完成 hello 再 close（确认 acceptLoop 已 claim listener 并回到 accept 阻塞）。
2. `stop()`；`weak var weakServer = server; server = nil`；有界自旋（≤5s）断言 `weakServer == nil`——若唤醒机制失效（如误用 shutdown），acceptLoop 永久阻塞在 accept、强持 self，此断言超时失败，即为回归信号。
3. 断言 socket 文件已删除；fd 增量回落（多轮阈值：整场景 100 轮 start→hello→stop→释放，结束 fd 增量 < 10，同时覆盖原「100 轮压测」的作用）。

### 既有测试

`boardServerStopWhileConnectionIsActiveClosesExactlyOnce` 及其余 BoardServerTests 必须原样通过（`stop()` 对活动连接仍只 shutdown、close 归 handle()，行为不变）。

## 边界与错误路径

- stop() 幂等（stopped guard 不变）；deinit→stop() 路径：未 claim 时直接 close listener，已 claim 时不可能发生（acceptLoop 强持 self 期间不会 deinit）。
- 唤醒 connect 与真实客户端连接同时到达：acceptLoop 醒来先查 `isStopped()`，无论 accept 到哪个都 close 后退出。
- start() 从未调用或 bind 失败后 stop()：listenFD=-1、owns=false，仅 removeItem，无害。
- `swift run RunTests` 全绿是硬性验收；新测试须先确认在旧实现上确实失败（Codex 在 impl-report 里说明验证方式，可临时 stash 修复跑一次或以推理说明）。

## 验证命令

```bash
swift run RunTests   # 权威跑法；swift test 在本机 CLT-only 环境输出不可靠
```

完整输出存 `docs/collaboration/tasks/2026-07-17-board-socket-lifecycle/verify.log`。

## 完成定义

- 三项修复全部落地且不越出触及文件清单。
- 两个新回归 + 全套既有测试在 `swift run RunTests` 下全绿。
- `impl-report.md`：改动文件列表、测试结果、新回归为何能抓住旧 bug 的简述、任何偏离 plan 之处。

## Open questions

（无）
