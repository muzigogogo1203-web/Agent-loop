# Acceptance — board socket 生命周期收尾

日期：2026-07-17（worktree claude/magical-ptolemy-19d5ce，基线 main 011b2cf）

## 改了什么

### 生产代码

- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
  - 修复 1（连接 fd 泄漏）：acceptLoop 派发 `handle()` 由 `[weak self]` 改为强捕获，「已 claim 未 handle」态在 dealloc 时刻结构性不可达；新增 `handlerQueue` 注入点（init 默认参数，调用方零改动）。
  - 修复 2（listener close 竞态）：listener close 所有权锁内移交 acceptLoop（`acceptLoop(claiming:)` 校验 `listenFD == expectedFD && !acceptLoopOwnsListener`）；stop() 对已认领 listener 只做 AF_UNIX 自连唤醒（macOS 对 listening socket 的 shutdown 不唤醒 accept，故不用 shutdown），未认领则锁内收走所有权后 close；start() 增加 bind 前防御 guard。
  - 修复 3：私有 SIGPIPE 包装删除，改用共享 helper。
- `Sources/AgentLoopCore/Support/PosixSockets.swift`（新增）：`PosixSockets.disableSIGPIPE(fd) -> Bool`，errno 留给调用方。
- `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift`：throw 版 SIGPIPE 包装删除，调用点 guard + 共享 helper。

### 测试

- `Sources/AgentLoopTestSuite/BoardServerTests.swift`
  - 新增回归 1 `boardServerHandlerBlockKeepsServerAliveUntilConnectionCloses`：挂起 handlerQueue 冻结「已 claim 未 handle」窗口，stop 后掉最后强引用，断言 handler block 强持 server（旧代码此处立即 dealloc 且泄 fd）；20 轮 + fd 增量阈值。
  - 新增回归 2 `boardServerStopWakesBlockedAcceptLoopAndReleasesListener`：stop 唤醒阻塞中的 acceptLoop、server 可释放、socket 文件删除；100 轮 churn + fd 增量阈值（兼作压测）。
  - 测试 socket 目录与 `agentLoopCanBindListenerSocket()` 探针改 `NSTemporaryDirectory()` 短路径；连接加 ECONNREFUSED 有界重试；SIGPIPE 内联包装改共享 helper。
- `Sources/AgentLoopTestSuite/CliBackendTests.swift`：harness socket 目录同样改短路径（worktree 下超 sun_path 104 字节上限，此前 3 个测试在 worktree 环境伪失败）。

## 验证了什么

- `swift run RunTests` 在 worktree 全绿：**411 tests / 4 suites passed（13.5s）**，完整输出 verify.log。
- 两个新回归的区分度已论证（见 reviews/01、02）：回归 1 的旧代码路径在「宽限期后仍存活」断言处必失败；回归 2 在唤醒机制失效时以 5s 超时失败。
- 既有回归 `boardServerStopWhileConnectionIsActiveClosesExactlyOnce` 原样通过；「单一 close owner」不变量保持：连接 fd 唯一 close 于 handle()，listener 唯一 close 于 acceptLoop 尾部（未认领时归 stop()）。

## 残留风险

- `slowActiveStreamDoesNotIdleTimeout`（AgentLoopTests）在一轮验证中偶发失败、重跑即绿，为并行负载 flake，与本改动无关联路径；如再现建议单独排查。
- stop→start 重启复用仍非支持场景（P2-2 只堵了旧 block 抢占新 listener 的洞）；生产唯一调用方 CliProcessBackend 为一次性 start/stop。
- 回归 1 的 probe 判定依赖 SO_RCVTIMEO=1s（reviews/01 P3-1 备忘），极端负载下理论上可能空过 claim 确认；当前 .serialized 下风险可忽略。

## 流程备注

- Codex 首轮实现完成主体；修复轮因 Codex CLI 网络故障中断，按协议兜底由 Claude 接管完成（详见 impl-report 补记）。
- 本机 codex CLI 已更换为 ChatGPT.app 内置 0.144.5，协议文档触发模板的 `--dangerously-bypass-hook-trust=false` 已失效（已另开任务卡修文档）。
