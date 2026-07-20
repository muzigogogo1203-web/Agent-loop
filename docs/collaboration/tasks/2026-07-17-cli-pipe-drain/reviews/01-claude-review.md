# Claude Review 01 — CLI 管道排空状态机收口

结论：**通过**。无 P0/P1；实现与 plan 一致，且含一处正向偏差（见下）。P2/P3 均为后续项，不阻塞验收。

## 逐项清单

1. **符合 plan** ✓ 只改了 `CliProcessBackend.swift` 与 `CliBackendTests.swift`，无 plan 外改动。
   - **正向偏差**：`CliPipeDrain.drain` 在 `.data` 分支也做退出观察（`exitObservedAt == nil` 时查 `isExited`）。这修掉了 plan 规约的真实缺口——孙进程持续灌数据时永远不走 `.wouldBlock`，plan 原版永远观察不到退出、宽限期永不生效（问题 1 修不掉）。正确的必要补充，予以确认。
2. **正确性** ✓ 状态机逐分支 trace：退出观察后立即重读一次消除 :497 竞态（写入 happens-before 退出，观察退出后读到 EAGAIN 即证管道排空）；宽限期在 `.data` 分支按 chunk 检查，孙进程洪泛有界；全部出口路径后统一 flush 残行（含 `.failed`）。
3. **并发** ✓ drain 的闭包参数为非 @Sendable async 闭包，同 task 内顺序调用，`lineBuffer`/`readBuffer` 可变捕获合法；detached task 捕获的 `CliExitBox`/`CliRunMetrics` 是 actor，continuation Sendable。`CliPipeDrainControl` 已删，退出信号统一由 `CliExitBox.value` 推导。
4. **数据层** ✓ 未触及。
5. **契约** ✓ `init` 新参数 `pipeDrainGrace` 带默认值，不破坏调用方；新公开 API `CliPipeDrain` 自洽（测试可注入，不依赖私有类型）。
6. **测试真实性** ✓（本项由 Claude 代跑，见 acceptance.md 环境备注）红阶段证据：Codex 会话日志记录旧实现把 RunTests 拖挂超过看门狗窗口（问题 1 的现网表现）。绿验证：`RunTests` 414/414 全绿（verify.log），新旧 CLI 测试全过，无 `yes` 进程残留。退避序列 10→20→40→80→100→100 与重置、退出后重读、宽限封顶均有精确断言。
7. **安全** ✓ 未触及 Keychain/沙箱/日志敏感面。
8. **代码质量** ✓ 贴合既有风格；`profileKind` 恒 nil 参数已删；无死代码。

## P2（建议，后续任务）

- **P2-1 测试守卫盲区**：`agentLoopCanBindListenerSocket()` 探针路径（~99 字符）短于 harness 真实 socket 路径（~113 字符），长名 worktree 下守卫放行但测试实跑 `socketPathTooLong`。应让探针路径长度 ≥ 真实最坏路径，或 harness socket 改用短临时目录。
- **P2-2 协议文档过时命令**：`docs/collaboration/claude-codex-protocol.md` §5 的 `--dangerously-bypass-hook-trust=false` 在 codex CLI 0.132.0 直接报错退出（该 flag 不接受值；正确做法是省略）。且本机需显式 `-m gpt-5.5`（默认模型 gpt-5.6-luna 被 API 拒）。

## P3（备忘）

- `.data` 分支在退出观察前每 chunk 一次跨 actor `isExited()`（洪泛修复的必要代价）；如需进一步降开销可按时间片节流该检查。
- drain 可迁移 DispatchSource read source / kqueue 彻底去轮询（plan 非目标，维持备忘）。
