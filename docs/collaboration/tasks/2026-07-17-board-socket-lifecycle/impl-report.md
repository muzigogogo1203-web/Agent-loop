# Implementation Report

## Changed files

- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
  - Added injectable `handlerQueue` with the planned default queue.
  - Strongly dispatches claimed connections to `handle`.
  - Added listener ownership transfer to `acceptLoop`, stop-time AF_UNIX self-connect wakeup, start guard, and removed `currentListenFD`.
  - Replaced the local SIGPIPE helper with `PosixSockets.disableSIGPIPE`.
- `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift`
  - Replaced the private SIGPIPE implementation with the shared helper.
- `Sources/AgentLoopCore/Support/PosixSockets.swift`
  - Added the shared `SO_NOSIGPIPE` helper.
- `Sources/AgentLoopTestSuite/BoardServerTests.swift`
  - Replaced the inline SIGPIPE setup.
  - Added handler-lifetime and blocked-accept-loop regression tests with multi-round fd thresholds.
- `docs/collaboration/tasks/2026-07-17-board-socket-lifecycle/verify.log`
  - Full output from the required `swift run RunTests` command.

## Test results

`swift run RunTests` was executed twice and the complete output is in `verify.log`. Both attempts stopped before project compilation because the environment cannot write `/Users/muzi/.cache/clang/ModuleCache`, and the active Swift compiler (`6.2.3`) does not match the SDK's Swift module version (`6.2.3.3.2`). No test cases ran.

## Why the regressions catch the old bugs

- The handler regression freezes the handler queue after the first connection is claimed, stops the server to release the accept-loop hold, and asserts the server remains alive until the queued handler closes its connection. The old weak handler dispatch deallocates the server at that point and leaks the claimed fd; the 20-round fd threshold detects the accumulated leak.
- The stop regression first confirms the listener has entered its normal accept state, then stops and releases the server. A failed wakeup leaves the accept loop blocked and retaining the server; the bounded deallocation assertion catches that. The 100-round socket-path and fd checks also exercise listener close ownership repeatedly.

## Deviations

None from the rewritten plan. `blocked.md` was deleted after the plan's question was resolved.

## 修复轮补记（Claude 接管，2026-07-17）

Codex 修复轮因网络故障中断且未产出改动（协议降级），reviews/02-claude-review.md 的修复由 Claude 直接实现：

- P1-1：回归 1 每轮 `queueResumed` + defer 守卫，throw 路径不再释放挂起队列（原 SIGTRAP/exit 133 根因）。
- P1-2：BoardServerTests 的 harness socket 目录与 `agentLoopCanBindListenerSocket()` 探针改用 `NSTemporaryDirectory()` 短路径（worktree 前缀超 AF_UNIX sun_path 104 字节上限）。
- P2-1：`start()` 在 bind 前锁内查重，避免误用双 start 先 unlink 活 listener 的 socket 文件。
- P2-2：`acceptLoop(claiming:)` 携带 start 捕获的 fd，claim 锁内校验 `listenFD == expectedFD && !acceptLoopOwnsListener`。
- P2-3：回归 1 自旋后补 `#expect(weakServer == nil)`。

验证轮发现并追加两项（同类环境问题外溢）：

- CliBackendTests 的 harness socket 目录同样超长导致 3 个测试失败（其中 cancellation 测试因 start() 先抛错而断言错位），同样改短路径。
- 回归 1 的 connect 在 backlog=1 且 acceptLoop 未及时取走连接时会 ECONNREFUSED，client/probe 均改为 `connectClientWithRetry`（2s 有界重试）。

最终验证：Claude 在 worktree 本地 `swift run RunTests` 全绿（411 tests, 4 suites, 13.5s），完整输出见 verify.log。`slowActiveStreamDoesNotIdleTimeout` 曾在一轮中偶发失败、重跑即绿，为负载 flake，与本改动无关。
