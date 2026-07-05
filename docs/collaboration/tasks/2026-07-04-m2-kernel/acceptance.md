# M2 内核 — 验收记录

日期：2026-07-04 ｜ 分支：`feat/m2`（基于 tag `m1`）｜ 流程：Claude plan/review × Codex impl（协议 v1），plan 经用户确认（Level 3），1 轮实现 + 1 轮修复。

## 改了什么

- **规划者**（`Kernel/Planner.swift` 新建）：强制 `tool_choice: propose_plan` 的单轮规划调用；校验纯函数（1–6 卡、字段非空、assignee 名册序号、dependsOn 仅引用更早卡）；矫正重试两分支（is_error tool_result / 纯 user 纠错）；确定性单卡回退（`plan_fallback{llm_failed|invalid_after_retry}`）。
- **planMission**（AppDatabase）：单写事务、守卫顺序=存在→已有卡 no-op（`plan_noop{cards_exist}`，单规划者不变量 spec §5.2-1）→非 planning no-op（`plan_noop{not_planning}`，吸收放弃竞态）；内核生成全部 id，idemKey `mission:<id>:stage-N` + 显式 `stage` 列。
- **Mission 状态机**：`MissionStatus` 枚举 + rollup 纯函数（粘性终态、delivering=全终态且≥1 done、防御 failed），挂点 transitionCard/completeCard/blockCard/planMission 同事务，`mission_status_changed` 事件。
- **调度**（`Kernel/Orchestrator.swift` 新建，actor）：level-triggered reconcile（事件 + 可注入 tick，pending 位合并并发触发）；todo 依赖全 done → ready；全局串行阀门 + 注册表一卡一主；`cancelling` 集合杜绝放弃窗口重派发；startMission（建 squad 持久化名册 + planning mission）/cancelMission（终态 guard、先置 failed 再逐卡 `card_canceled`，走状态机走廊）/retryCard/closeout（非 delivering 抛 `MissionStateError`）/waitUntilIdle/shutdown；KernelEvent 多消费者广播。
- **下游冷启动**：`UpstreamHandoff` 注入 ContextPacket（结果/摘要/验证/风险/next/双路径/无产物原因，确定性渲染无时间戳）；`card.handoffJson` 投影列（migration v2，同事务写入）。
- **卡级 token 硬顶**：`AgentLoop` tokenBudget（per-attempt 语义 D7）饱和累加，超限 `blocked(budget_exhausted)`；`mission.spentTokens` 累加展示。
- **Provider 协议**：`ToolChoice`（`.auto` 不发键，缓存前缀字节级不变，有测试断言）。
- **App 层**：D8 删除单卡直跑路径；行动表单（目标 + 伙伴多选 + 工作目录）、规划中指示、卡片清单（CardRowView 六状态人话文案 + blocked 原因 + 重试）、交付物条、收营/放弃；provider 工厂按 companion.model 路由（D6）。
- migration v2：`card.handoffJson`/`card.stage` + mission.status 归一化，可重放（有 v1-only 构造测试）。

## Review 轮次

- 01-claude-review：P1×1（放弃窗口幽灵重派发）、P2×3（reconcile 信号丢弃、名册失配静默停摆、取消绕过状态机走廊）、P3×5。
- 修复轮：P1/P2 全修 + P3-2，各配回归测试（含 HangingProvider 竞态测试）。P3-1/3/4/5 备忘不修（理由见 review 与 impl-report）。

## 验证

- **真机**（权威）：`swift run RunTests` **107/107 全绿，0.44s**；`swift build`（含 App 目标）干净。
- Codex 沙箱：106/107（keychainRoundTrip -50 为既知环境性失败）；verify.log 含两轮全量输出。
- 金路径离线覆盖 M2 验收语句：两卡依赖、跨伙伴 model 路由、下游首条消息含上游摘要与产物路径、产物耐久落盘、planning→executing→delivering→accepted 全轨迹。

## 有意偏差（已接受）

1. `CardStatus.canTransition` 新增 `ready→blocked`（修复轮引入）：供内核 block 无法派发的 ready 卡（assignee 不可解析），替代静默停摆——与 spec §5.1 既有补充转移（running→ready 等）同性质的内核防御扩展。
2. `AppDatabase.migrator` 为 `public static`（测试 target 非 @testable 所需）。
3. Orchestrator tick 懒启动（Swift 6 actor init 限制）；`shutdown()` App 内暂无人调（进程退出兜底，M5 生命周期打磨）。
4. 规划轮 token 不入账 spentTokens；mission 总额不执法（M5）。

## 残留风险 / 用户待办

- **活体冒烟未做（spec §15-5 硬门）**：请按 `docs/superpowers/2026-07-04-m2-live-smoke.md` 用真实 API 跑一次两卡依赖行动（零人工到可收营 → Finder reveal → 收营）。通过后 M2 才算收口。
- blocked 上游会让行动停在「进行中」且无行动级停滞提示（M3 动态流覆盖）。
- 下游读上游产物依赖工作目录原文件仍在（工具沙箱不能越界读耐久区）。

---

**2026-07-05 用户正式测试通过**（含 M2.1 指派去重崩溃修复、M2.2 流式空闲超时放宽；真机 109/109 绿）。M2 收口，tag `m2`。
