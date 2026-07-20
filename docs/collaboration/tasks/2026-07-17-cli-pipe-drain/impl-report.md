# Impl Report — CLI 管道排空状态机收口

> 注：实现由 Codex（gpt-5.5, xhigh，session 019f7043-93e1-7981-af8d-c2484754029b）完成；Codex 在最终绿验证阶段因磁盘满（ENOSPC）崩溃，未及写本报告。本报告由 Claude 依据 Codex 会话日志与 diff 重建，验证由 Claude 在磁盘恢复后代跑。

## 改动文件

- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
  - 新增公开 `CliPipeDrain`（`ReadResult` + 可注入 `drain` 状态机）：进程退出后宽限期内 drain 到 EAGAIN/EOF 即停；退出观察后先立即重读一次（消 :497 竞态）；`.data` 分支也做退出观察（plan 缺口修补，否则孙进程洪泛下永远观察不到退出）；静默期 10ms→100ms 指数退避。
  - `readStdout`/`readStderr` 收敛为 `drainStdout`/`drainStderr` 薄包装；stdout 出口统一 flush 残行；`profileKind` 恒 nil 参数删除。
  - `readPipeChunk` 改 `inout` 复用 4KB buffer；`CliPipeDrainControl` actor 删除，退出信号由 `CliExitBox.value` 推导。
  - `init` 新增 `pipeDrainGrace: Duration = .seconds(1)`。
- `Sources/AgentLoopTestSuite/CliBackendTests.swift`
  - 新增 5 测试：孙进程持管道宽限收尾（e2e）、无换行残行 usage 捕获（e2e）、退出观察后重读（单元）、静默退避与重置（单元）、数据洪泛宽限封顶（单元）。

## 红阶段证据（来自 Codex 会话日志）

- 新增两个 e2e 测试后跑 `RunTests`：孙进程持管道测试令旧实现把整个测试进程拖挂，超过测试内 10s 看门狗窗口仍不退出，Codex 沙箱内无法 kill，遂记录 hang 证据后继续实现（正是问题 1 的现网表现）。

## 验证结果

- `RunTests` 414/414 全绿，完整输出见 `verify.log`。
- 环境备注：本 worktree 目录名过长导致 harness socket 路径超 macOS 104 字符上限，须从短 CWD 运行（`cd /tmp/<短目录> && <worktree>/.build/debug/RunTests`）；详见 acceptance.md。

## 偏差

- `.data` 分支的退出观察为 plan 未写明的必要补充（review 已确认为正向偏差）。
- 本报告与验证的执行主体如上注所述（Codex 崩溃兜底，协议 §5「死角兜底」路径）。
