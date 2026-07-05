# M2 内核 — Claude Review 第 1 轮

范围：未提交 diff（基线 `778d95a`）+ impl-report.md + verify.log。
结论：实现高度符合 plan（含 D1–D8 全部决策、守卫顺序、事件契约、26+ 测试全部落地且断言真实）。verify.log 103/104 绿，唯一失败为预告的环境性 keychainRoundTrip。**1 条 P1、3 条 P2 需修复**；P3 备忘可选。

## P1

### P1-1 放弃行动窗口内 reconcile 会重派发下一张卡（幽灵 runner 烧 token）

`Orchestrator.cancelMission`（Orchestrator.swift:161-181）先取消并 await 在跑 runner，之后才在事务里置 mission failed。但 runner 被取消后其 task 尾部会走 `runnerFinished → reconcile()`（Orchestrator.swift:346-350），此刻 mission 仍是 `.executing`、后续卡仍 `.ready` → reconcile 会派发下一张卡并注册进 `running`。该新 runner 不在 cancelMission 先前的 `runningForMission` 快照里，不会被取消；随后事务把它的卡行置 `.canceled`，runner 继续对着已取消的卡跑完整个 LLM 循环（complete_card 时才因 canceled→done 非法而失败）。后果：真实 API 下放弃行动会白烧一张卡的 token，并留下一条 failed run 与事件噪音。测试未覆盖此竞态（cancelMissionTerminalizesAndFails 无在跑 runner）。

**修复**：Orchestrator 增加 `private var cancelling: Set<String> = []`；`cancelMission` 过终态 guard 后立即 `cancelling.insert(missionId)`，函数退出（含 error 路径）时移除；`reconcile()` 在 `guard let candidate` 之后增加 `guard !cancelling.contains(candidate.card.missionId) else { return }`。并在 OrchestratorTests 增加一条竞态回归测试：一张慢卡在跑（脚本含多轮 progress note）+ 一张 ready 卡，调 cancelMission，断言第二张卡的 run 行数为 0 且全部卡终态化。

## P2

### P2-1 reconcile 并发信号被丢弃而非合并

`reconcile()` 的 `guard !reconciling else { return }`（Orchestrator.swift:90）在有一次 reconcile 悬挂在 `pool.write` 时，把并发触发（tick / retryCard / 另一 runner 退出）直接丢弃，且在途那次用的是过期的 `hasRunning` 快照 → 该轮不派发。生产环境靠 5s tick 兜底（最坏 5s 停顿，spec §5.3 允许），测试路径串行不受影响，故仅 P2。

**修复（廉价）**：加 `private var reconcilePending = false`；guard 命中时置 `reconcilePending = true` 后 return；reconcile 主体外包一层 `repeat { … } while consumePending()` 式循环（进入循环前清 pending）。

### P2-2 名册解析静默失配可致卡片永久静默停摆

两处叠加：① `AppDatabase.companions(ids:)` 对不存在的 id 静默跳过（AppDatabase.swift 新增查询）——规划时 `validate(rosterCount:)` 用的是**过滤后**的 roster 数，而 `planMission` 用 squad.memberIdsJson**未过滤**序列做 `memberIds[draft.assignee]` 映射，两个下标空间错位时卡会被指派给不存在的伙伴；② `reconcile` 派发时 `guard let assigneeId …, let companion … else { return nil }`（Orchestrator.swift:137-140）静默返回——该 ready 卡此后每轮 reconcile 都跳过，**无 kernelError、无 blocked、UI 永远「待启动」**，违反 spec §14「每个静默状态显式可渲染」。

**修复**：`companions(ids:)` 改为对缺失 id 抛 `RecordNotFoundError`（调用点仅 Orchestrator.startMission 与 AppStore.reloadMission——后者传的是已存在卡的 assignee，改动无回归风险；AppStore 处用 try? 保持容错）；reconcile 对 assignee 无法解析的 ready 卡：`blockCard(reason: "other", detail: "负责伙伴不存在或未指派")` + 发 `kernelError`，不再静默 return nil。补一条测试：ready 卡 assigneeId 指向不存在伙伴 → reconcile 后卡为 blocked。

### P2-3 cancelMission 逐卡终态化绕过状态机走廊

cancelMission 事务内对卡直接 `card.update(database)`（Orchestrator.swift:213-216），绕过 `canTransition` guard 与 transitionCard 走廊。当前行为恰好等价（非终态→canceled 全合法），但违反 plan 明文「逐张非终态卡用 db 级转移置 .canceled」与 spec §5.1 单一穷举走廊纪律，未来加转移约束时此处会漏。

**修复**：改用 `db.transitionCard(database, id:, to: .canceled, eventKind: "card_canceled", payload: ["reason": "mission_abandoned"])`。其内部 rollup 因 mission 已先置 failed（粘性终态）必为 no-op，不会产生伪 delivering——保持现有「先置 failed 再逐卡」顺序不变。删除该循环里手写的 appendEvent（transitionCard 已记）。

## P3（备忘，可选修）

1. reconcile 错误路径 `kernelError(missionId: "")`（Orchestrator.swift:149）——missionId 缺失，UI 无从关联；可读性小改。
2. `handleCardEvent` 的 `.textDelta` 每 token 向 `cardLatest[cardId]` 写同值字符串（AppStore.swift），@Observable 每次赋值都触发失效；加同值守卫可省流式期间的无谓刷新。
3. `Orchestrator.shutdown()` 在 App 内无人调用——常驻单窗口进程退出即终止，影响轻；M5 打包阶段随生命周期打磨一并处理。
4. `AppDatabase.migrator` 为 `public static`（偏差已声明合理）；后续可收紧为 `package` 访问级。
5. GoldenPath 的 `bFirstUser.contains("facts.md")` 会被 B 卡自身描述满足（弱断言）；已有「A 产出了 facts.md」强断言 + ColdStartTests 的耐久路径断言兜底，不必改。

## 已核对为符合（抽样点）

- planMission 守卫顺序与 plan_noop{cards_exist|not_planning} 审计（含测试 10/11）；单规划者不变量落点成立。
- rollup 纯函数穷举 + 粘性终态 + defensive mission_failed 同事务；挂点 transitionCard/completeCard/blockCard/planMission，startRun 与 cancel 不挂——与 plan v2 一致。
- migration v2（双列 + status 归一化）+ `migrate(upTo:"v1")` 构造的可重放测试；completeCard 同事务写 handoffJson（sortedKeys）。
- pool.write 不可重入已通过 db 级变体重构解决，grep 未见嵌套写。
- ToolChoice: Sendable+Equatable；`.auto` 不发键（requestBody 测试断言缓存前缀不变）；矫正重试两分支历史形状（tool_result 引用 id / 纯 user 纠错）均有 recordedHistories 断言。
- AgentLoop token 硬顶饱和累加；finishRun spentTokens 溢出防护。
- 串行阀门权威断言 = run 区间不重叠；Orchestrator 测试全部 tickInterval nil + waitUntilIdle，无 sleep 轮询。
- D6 provider 工厂按 companion.model 路由（金路径断言 model-a/model-b/planner-model）。
- D8 完成：AppStore.startRun 单卡路径已删，无绕过 Orchestrator 的执行入口；M1.1 功能（伙伴编辑/私聊/活动时间线管线）未回归。
- 安全：新代码无 key/请求体日志；live-smoke 文档与新 UI 流程一致。
