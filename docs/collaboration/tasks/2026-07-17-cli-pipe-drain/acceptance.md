# Acceptance — CLI 管道排空状态机收口（2026-07-17）

结论：**验收通过**。review 无 P0/P1（见 `reviews/01-claude-review.md`）。

## 改了什么

`CliProcessBackend` 的管道排空重构为统一的 `CliPipeDrain` 状态机，覆盖 review 确认的 5 个问题：

1. 孙进程继承管道写端导致卡片永久 running：进程退出后由 `pipeDrainGrace`（默认 1s）兜底，宽限内 drain 到 EAGAIN/EOF 即停，宽限到强制停；关读端后孙进程收 SIGPIPE 自灭。
2. 出口不 flush 残行丢 usage：drain 返回后统一 flush，覆盖 EOF/宽限停/失败全部路径。
3. EAGAIN 后检查退出的竞态：观察到退出先立即重读一次再停（写入 happens-before 退出保证不丢）。
4. 轮询浪费：静默期 10ms→100ms 指数退避（有数据即重置），读 buffer 复用。
5. 简化：删 `CliPipeDrainControl` actor（由 `CliExitBox.value` 推导）、合并 stdout/stderr 复制粘贴状态机、删恒 nil 的 `profileKind` 参数。

## 验证了什么

- `RunTests` 414/414 全绿（`verify.log`）；5 个新测试含红阶段证据（旧实现挂死 RunTests、残行 usage 丢失均先复现后修复）。
- 既有 CLI 行为测试（无终结器 blocked、超时 blocked、取消回 ready、live spike 门控）全部保持绿。

## 残留风险与环境备注

- **本 worktree 无法直接跑 socket 类测试**：目录名过长使 harness socket 路径（~113 字符）超 macOS `sun_path` 104 上限，且探针守卫（~99 字符）存在盲区不会跳过，表现为 8-9 个 `socketPathTooLong` 伪失败。权威跑法（本 worktree 内）：`mkdir -p /tmp/alrt && cd /tmp/alrt && <worktree绝对路径>/.build/debug/RunTests`。主仓库 checkout 不受影响。修守卫为 P2 后续项。
- `.data` 分支退出观察前每 chunk 一次跨 actor 检查（洪泛修复必要代价），P3 可节流。
- DispatchSource/kqueue 事件驱动为 P3 备忘。

## 过程备注（协议执行）

- Codex 完成实现与红阶段后、绿验证中因磁盘满崩溃（当时全盘仅剩 ~319MB）；按协议 §5 死角兜底由 Claude 接管验证与文档收尾。
- 协议 §5 首轮命令中 `--dangerously-bypass-hook-trust=false` 在 codex CLI 0.132.0 报错退出；本机另需显式 `-m gpt-5.5`（默认 gpt-5.6-luna 被 API 以版本过旧拒绝）。协议文档待修（P2-2）。
