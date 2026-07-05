# Claude Project Guide — AgentLoop

AgentLoop 是 macOS 原生 Swift/SwiftUI 多 Agent 协作工具（awesome-hermes 的单运行时原生续作）。设计基准：`docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md`。

## 默认开发范式（重要）

本项目**默认使用 Claude×Codex 协作范式**：Claude 负责规划与 review，Codex（GPT-5.5）负责实现与一切可外包的探索/验证工作。收到非琐碎实现请求时，先读并遵循：

- `docs/collaboration/claude-codex-protocol.md`（协议全文，含触发命令、review 清单、兜底规则）

除非用户明确说跳过流程，不要自己动手写实现代码——把实现外包给 Codex，核心目标是节省 Claude token 并保证 review 完备。

## 项目速查

- 权威测试跑法：`swift run RunTests`（本机 CLT-only，`swift test` 输出不可靠）
- 构建/启动：`swift run AgentLoopApp`
- 测试代码位置：`Sources/AgentLoopTestSuite/`
- 技术栈：Swift 6 严格并发、GRDB 7、actor + TaskGroup + AsyncStream、macOS 14+
- 用户偏好中文讨论；设计讨论沿用远征风命名（营地/小队/行动/小目标/伙伴）
- 不 push / rebase / 改写历史，除非用户明确要求；保留用户未提交改动
