# Claude Project Guide — AgentLoop / 个人 AI 牧场

AgentLoop 是当前内部 target 和兼容名称；Coding 牧场是第一个旗舰场景。已经接受的长期产品与系统设计基准是：

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
- 2026-09-05 当前接手与桌面基线决策记录：
  `docs/collaboration/tasks/2026-09-05-product-takeover-baseline/spec.md`

旧 MVP/V2/视觉 spec 和任务报告继续作为历史证据，但不得覆盖长期总 spec 的产品方向或 2026-09-05 的当前治理决定。当前由 Codex 担任产品与工程负责人，在已确认方向和安全边界内自主作出日常、可逆决策。P0–P6 的进入条件、完成门、权限边界和独立复核仍然有效。

## Claude 的可选参与方式

Claude Code 仅在被单独请求或授权时作为可选参与者，承担规划、调研或职责隔离的独立 review；默认 reviewer 是与实现职责隔离的 Codex agent。Claude 不再是每个非琐碎任务的默认规划者或唯一 reviewer，也不能覆盖 Codex 在已确认方向内的普通决策权。参与任务时，必须遵循当前 task spec/plan、权限与阶段门，并保护未提交的用户改动。

历史 Claude×Codex 协作流程在下列文档中保留供证据与按需复用；顶部的 2026-09-05 主动覆写是当前规则：

- `docs/collaboration/claude-codex-protocol.md`

经证据可以决定的日常可逆事项不必上升用户。修改北极星、目标用户、隐私/权限原则、核心产品不变量，或证据不足且所有路径都依赖猜测时，仍必须与用户深入交流。

## 项目速查

- 权威测试跑法：`swift run RunTests`（本机 CLT-only，`swift test` 输出不可靠）
- 构建：`swift build --product AgentLoopApp`
- 真实启动：`scripts/run-app.sh`（本机必须打 .app 壳启动，直跑裸二进制不渲染文字；`--preview` / `--dark` 可选）
- 测试代码位置：`Sources/AgentLoopTestSuite/`
- 技术栈：Swift 6 严格并发、GRDB 7、actor + TaskGroup + AsyncStream、macOS 14+
- 用户偏好中文讨论；设计讨论沿用远征风命名（营地/小队/行动/小目标/伙伴）
- 不 push / rebase / 改写历史，除非用户明确要求；保留用户未提交改动
- 当前 App 不是 App Sandbox：`scripts/agentloop.entitlements` 明确设置 `com.apple.security.app-sandbox=false`
