# Plan：CliProcessBackend 管道排空状态机收口重构

任务级别：Level 2/3（并发模型）。设计决策已由用户在需求中给定，无 open questions。

## 背景

`Sources/AgentLoopCore/Loop/CliProcessBackend.swift` 的 pipe drain 状态机有一簇 review 已确认的问题（基于 main 011b2cf，近因 diff 见 `git show ab96834`）：

1. **[corr :467] 孙进程占管道导致永久挂起**：`runProcess` 在 `exitBox.wait()` 返回后无限期 `await` 两个 `Task.detached` 读任务。若 CLI 的孙进程继承了 stdout/stderr 写端并持续写入（如 `yes 1>&2 &` 后主进程退出），读任务永远走 `.data` 分支等不到 EOF，卡片永久 running 且取消无效（`onCancel` 只 terminate 已退出的主进程；detached task 不继承取消）。
2. **[corr :501] 出口不 flush 残行**：`.eof` / `.wouldBlock+shouldStop` / `.failed` 三个出口直接 return，buffer 里未换行终止的最后一行永不送入 `CliOutputParser` —— CLI 最终输出不带 `\n` 时 `turnEnded` 的 usage 丢失、tokensIn/Out 偏低。
3. **[alt :497] shouldStop 竞态丢数据**：`.wouldBlock` 读到 EAGAIN 后才跨 actor 检查 `shouldStop`；「子进程写最后一行 → 退出 → processDidExit 置位」发生在这两步之间时，最后一行已在管道里却被跳过。
4. **[eff :498] 轮询浪费**：10ms sleep 轮询 + 每轮跨 actor `shouldStop` 检查 + 每轮新分配 4KB buffer，静默期两个 task 约 200 次唤醒/秒/进程。
5. **[简化] 冗余抽象与复制粘贴**：`CliPipeDrainControl` actor 只是一次性 Bool，可由既有 `CliExitBox.value` 推导；`readStderr` 与 `readStdout` 是同一状态机的复制粘贴；`readStdout` 的 `profileKind` 参数恒传 nil。

## 目标

- 用统一语义修复 1+3：**进程退出后，在宽限期内继续 drain，直到 EAGAIN/EOF 即停；宽限期到仍有数据流入则强制停**。
- 所有出口路径 flush 残行（修 2）。
- 轮询退避 + buffer 复用（修 4 的最低要求）。
- 删 `CliPipeDrainControl`、合并两个 read 函数为共享 drain 状态机、删恒 nil 的 `profileKind` 参数（修 5）。
- 先为 1/2/3 写失败测试，重构后全绿。

## 非目标

- 不做 DispatchSource / kqueue 事件驱动重写（记 P3 后续项；本轮退避轮询已满足要求）。
- 不动 `CliOutputParser`、超时/kill 语义、`BoardToolServer`、卡片状态机其余部分。
- 不破坏 `CliProcessBackend.init` 既有调用方（新参数一律带默认值）。

## 设计

### 新公开类型 `CliPipeDrain`（放在 CliProcessBackend.swift 内）

测试套件是普通 `import AgentLoopCore`（无 @testable），所以状态机做成 public 可注入（同 `CliOutputParser` 先例）：

```swift
public enum CliPipeDrain {
    public enum ReadResult: Sendable {
        case data(Data)
        case wouldBlock
        case interrupted
        case eof
        case failed(String)
    }

    /// 排空状态机。进程退出后在 grace 宽限期内 drain 到 EAGAIN/EOF 即停。
    /// 闭包参数均为非 @Sendable、非逃逸的 async 闭包，在调用方 task 内顺序执行。
    public static func drain(
        grace: Duration,
        readChunk: () -> ReadResult,
        isExited: () async -> Bool,
        sleep: (Duration) async -> Void,
        now: () -> ContinuousClock.Instant,
        onData: (Data) async -> Void,
        onReadFailure: (String) async -> Void
    ) async
}
```

### 状态机语义（精确规约，测试即按此写）

```
var exitObservedAt: Instant? = nil      // 首次观察到进程退出的时刻
var backoff = 10ms                       // 最小退避
loop:
  switch readChunk():
  case .data(chunk):
      await onData(chunk)
      backoff = 10ms                     // 有数据即重置退避
      if let t = exitObservedAt, now() - t >= grace { return }   // 宽限期兜底（修 1）
  case .interrupted:
      continue
  case .eof:
      return
  case .failed(msg):
      await onReadFailure(msg); return
  case .wouldBlock:
      if exitObservedAt != nil { return }        // 退出已观察后的 EAGAIN → 管道已排空，安全停止
      if await isExited() {
          exitObservedAt = now()
          continue                               // 关键：先标记、立即重读一次，消除 :497 竞态（修 3）
      }
      await sleep(backoff)
      backoff = min(backoff * 2, 100ms)          // 指数退避（修 4）
```

正确性论证（修 3）：进程对管道的写入 happens-before 其退出；因此「观察到退出之后」再读到 EAGAIN，说明主子进程的全部输出都已被消费，停止不丢数据。孙进程持写端的场景由 grace 兜底（修 1）：EAGAIN 停（孙进程静默）或 grace 到期强制停（孙进程持续写）。

### fd 接线（runProcess 内）

- 删除 `CliPipeDrainControl` actor 及 `processDidExit()` 调用；读任务改为直接持有 `CliExitBox`，`isExited = { await exitBox.value != nil }`。
- `readStdout`/`readStderr` 收敛为两个薄包装 `drainStdout` / `drainStderr`，共同委托 `CliPipeDrain.drain`；`profileKind` 参数删除：
  - **stdout 包装**：本地 `var lineBuffer = Data()`；`onData` 里 append + 按 `\n` 切行 → `CliOutputParser.events` → `metrics.addUsage` + `continuation.yield`（逻辑照旧）。**drain 返回后统一 flush**：`lineBuffer` 非空则整体作为一行走同一解析路径（修 2；覆盖 eof/宽限停/failed 全部出口）。
  - **stderr 包装**：`onData = metrics.appendStderr`；无需 flush（stderrTail 是原始字节，不切行）。
  - 两者 `onReadFailure` 保持现状（"stdout/stderr read failed: …" 进 stderr tail）。
- `readChunk` fd 版：包装闭包内复用 `var bytes = [UInt8](4096)`（修 4 的 buffer 复用）；`readPipeChunk` 改为 `readPipeChunk(_ fd:, into: inout [UInt8])`。
- 生产参数：`sleep = { try? await Task.sleep(for: $0) }`、`now = { ContinuousClock.now }`（或 `ContinuousClock().now`，取编译通过的写法）。
- `runProcess` 主体顺序不变：`exitBox.wait()` → `setExitStatus` → cancel timeoutTask → `await stdoutTask.value` / `await stderrTask.value`（现在有界：≤ 退避上限 + grace）→ 关读端 fd。关读端后孙进程再写会收 SIGPIPE 自灭。

### 新配置

- `CliProcessBackend.init` 增加 `pipeDrainGrace: Duration = .seconds(1)` 存储属性并穿透到 `runProcess` → 两个 drain 包装。测试注入小值（如 300ms）。
- 退避常量（10ms 起、×2、上限 100ms）作为 `CliPipeDrain` 内部常量，不外露。

### Swift 6 并发注意

- `drain` 的闭包参数必须是非 `@Sendable` 的普通 async 闭包（同一 task 内顺序调用），这样包装层才能捕获并变异 `lineBuffer`/`bytes` 局部 var。若编译器仍拒绝变异捕获，兜底方案：在 task 内用一个私有 `final class`（非 Sendable）持有可变状态，语义不变。
- 读任务仍用 `Task.detached`（closure @Sendable，捕获的 `CliExitBox`/`CliRunMetrics` 是 actor、continuation 是 Sendable，均合法）。

## 触及文件清单

| 文件 | 改动 |
|---|---|
| `Sources/AgentLoopCore/Loop/CliProcessBackend.swift` | 新增 `CliPipeDrain`；删 `CliPipeDrainControl`；`readStdout`/`readStderr` → `drainStdout`/`drainStderr` 薄包装；`readPipeChunk` 复用 buffer；init 加 `pipeDrainGrace` |
| `Sources/AgentLoopTestSuite/CliBackendTests.swift` | 新增 5 个测试（下节） |

## 测试要求（TDD：先写、先看 1/2 红）

全部放 `Sources/AgentLoopTestSuite/CliBackendTests.swift`，沿用 `CliBackendHarness`。

1. **`cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe`**（e2e，修 1）
   脚本：
   ```bash
   #!/bin/bash
   yes 1>&2 &
   printf '%s\n' '{"usage":{"input_tokens":1,"output_tokens":2}}'
   exit 0
   ```
   backend：`timeout: .seconds(30)`、`pipeDrainGrace: .milliseconds(300)`。消费 stream 放在子 Task，与 10 秒看门狗竞速（看门狗触发即 `#expect(false)` + cancel）。断言：流在看门狗前正常结束、卡片 blocked（无终结器路径）、run.tokensIn == 1、tokensOut == 2。
   旧代码：stderr 读任务永远 `.data`，流不结束 → 看门狗打红。
   （红阶段泄漏的 `yes` 会在 RunTests 进程退出、读端关闭后收 SIGPIPE 自灭，不需要额外清理。）

2. **`cliProcessBackendCapturesFinalLineWithoutNewline`**（e2e，修 2）
   脚本：
   ```bash
   #!/bin/bash
   printf '%s' '{"usage":{"input_tokens":11,"output_tokens":13}}'
   exit 0
   ```
   注意 `printf '%s'` 无换行。断言：流结束后 run.tokensIn == 11、tokensOut == 13（对照既有 `cliProcessBackendBlocksWhenCliExitsWithoutBoardTerminator` 的写法）。旧代码：残行被丢，tokens 为 0 → 红。

3. **`cliPipeDrainRereadsAfterExitObserved`**（单元，修 3；对新 API 写，实现前不编译/不绿即为红）
   脚本化闭包：`readChunk` 依序返回 `[.wouldBlock, .data("{…usage…}\n"), .wouldBlock]`（之后恒 `.wouldBlock`）；`isExited` 恒 true（模拟退出恰好落在 EAGAIN 检查点）。断言：`onData` 收到该行；`readChunk` 被调用 ≥ 3 次（证明观察到退出后发生了重读）；drain 正常返回。

4. **`cliPipeDrainBacksOffPollingWhileSilent`**（单元，修 4）
   `readChunk` 恒 `.wouldBlock`，`isExited` 前 N 次 false 后 true，`sleep` 记录时长。断言：记录序列按 10→20→40→80→100→100ms 单调爬升且封顶；另一段：中途插入一次 `.data` 后退避重置回 10ms。

5. **`cliPipeDrainStopsAtGraceDeadlineWhileDataFlows`**（单元，修 1 的时钟语义）
   `readChunk` 恒 `.data`，`isExited` 恒 true，`now` 用注入的假时钟每次前进；断言 drain 在累计超过 grace 后返回，且返回前收到的 `onData` 与假时钟推进一致（不需要逐字节精确，收到 ≥1 次且有界即可）。

既有测试（blocks-without-terminator / timeout / cancellation / live spike gate）必须保持全绿。

## 边界与错误路径

- **取消**：路径不变（onCancel → terminate → 退出 → drain 有界收尾 → `checkCancellation` 抛出走 canceled 收尾）；本重构使「取消后卡 running」不可能超过 退避上限+grace。
- **超时**：timeoutTask 逻辑不动。
- **`.failed`**：同样 flush 残行后返回。
- **EINTR**：`continue`，不变。

## 验证命令

- `swift run RunTests`（权威跑法；完整输出存 `verify.log`）。
- 构建可启动性以 `swift build` 通过为准（本任务不触 UI）。

## 完成定义

- 测试 1/2 在旧代码上确认为红（impl-report 里记录红阶段输出摘要），重构后 1–5 全绿，既有套件全绿。
- `CliPipeDrainControl` 已删除；`profileKind` 恒 nil 参数已删除；`readStdout`/`readStderr` 复制粘贴已收敛为共享状态机。
- 静默期无 10ms 固定轮询（退避封顶 100ms）、读循环无每轮 4KB 新分配。
- 不改动本清单以外的文件；不 commit。

## Open questions

（无）

## P3 备忘

- 后续可将 drain 迁移到 DispatchSource read source / kqueue 事件驱动，彻底消除轮询；本轮不做。
