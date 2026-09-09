# Claude Project Guide — AgentLoop / 个人 AI 牧场

AgentLoop 是当前内部 target 和兼容名称；Coding 牧场是第一个旗舰场景。已经接受的长期产品与系统设计基准是：

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`

旧 MVP/V2/视觉 spec 和任务报告继续作为历史证据，但不得覆盖长期总 spec 的产品方向。当前长期实施按 P0–P6 阶段推进；每阶段必须先满足进入条件，随后按阶段 spec/plan 实施，并以明确完成门和红线决定能否跨阶段。

## 默认开发范式（重要）

本项目**默认使用 Claude×Codex 协作范式**：Claude 负责规划与独立 review，Codex 负责实现与一切可外包的探索/验证工作。收到非琐碎实现请求时，先读并遵循：

- `docs/collaboration/claude-codex-protocol.md`（协议全文，含触发命令、review 清单、兜底规则）

长期 Goal 已获得牧场主授权：阶段 spec、已决计划与权限范围内的例行推进无需反复请求确认；遇到总 spec 的强制暂停条件必须停止相关分支并升级，不能把自动推进解释为无限授权。

## 项目速查

- 权威测试跑法：`swift run RunTests`（本机 CLT-only，`swift test` 输出不可靠）
- 构建：`swift build --product AgentLoopApp`
- 真实启动：`scripts/run-app.sh`（本机必须打 .app 壳启动，直跑裸二进制不渲染文字；`--preview` / `--dark` 可选）
- 测试代码位置：`Sources/AgentLoopTestSuite/`
- 技术栈：Swift 6 严格并发、GRDB 7、actor + TaskGroup + AsyncStream、macOS 14+
- 用户偏好中文讨论；设计讨论沿用远征风命名（营地/小队/行动/小目标/伙伴）
- 不 push / rebase / 改写历史，除非用户明确要求；保留用户未提交改动
- 当前 App 不是 App Sandbox：`scripts/agentloop.entitlements` 明确设置 `com.apple.security.app-sandbox=false`
