# M2 内核 — 实现计划（Level 3，需用户确认后触发）

来源：spec §16-M2（`docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md`）。
验收基准（spec 原文）：**两卡依赖行动端到端，下游冷启动开工**。

分支：实现在 `feat/m2`（基于 tag `m1` / feat/m1 HEAD 创建，由 Claude 在触发前建好）。Codex 不 commit。

修订记录：v2 —— 已吸收三视角对抗性自审（决策完备/spec 一致性/可实现性）的全部 P0–P2 与 P3 结论。

## 现状基础（已存在，勿重建）

M1 已交付且 M2 直接复用（列出以防重复造轮子；改动范围以下文为准）：

- migration v1 的 12 张表（spec §4.2 中的 companion_note 属 M4，M1 未建），含 `card.idemKey UNIQUE`、`dependsOnJson`（恒 `'[]'`，从未被读）、`tokenBudget`（从未被用）、`blockedReasonJson`。
- `CardStatus` 穷举状态机 `canTransition(to:)`（`Records.swift:6-20`），已含 `running→ready`（中断恢复）与 `running→canceled`。
- `transitionCard` / `startRun` / `finishRun` / `completeCard` / `blockCard`：状态 + 事件同事务。**注意事实**：`startRun`（`AppDatabase.swift:340-360`）是在自己的 `pool.write` 里内联做 ready→running guard + update + 事件，**不经过 `transitionCard`**。
- `HandoffPayload` v1 及 `parse` 校验（outcome/summary 非空、artifacts XOR noArtifactReason），`BoardTools.complete()` 的产物先拷贝耐久（copy 非 move、失败回滚）后落库。
- `AgentLoop`（终结契约、提醒、三振、pause 封顶、按轮重试）、`CardRunner`（取消→ready、失败→blocked）、`ContextPacket`（`upstreamHandoffs: [String]` 参数存在但恒空）。
- 每伙伴自选模型：`CompanionRecord.model` 列 + `AppStore` 按 `companion.model` 现建 provider（`AppStore.swift:96`）。
- `MockProvider` 脚本回放（`callCount` / `recordedHistories`）、`createSingleCardMission` 测试夹具（注意：其 `memberIdsJson` 恒写 `"[]"`、maxTurns=30 是 `AppStore.swift:111` 调用点字面量、tokenBudget=200_000 是夹具参数默认值——**Core 层目前没有默认值常量**）。
- `mission` 表已有 `status/budgetTokens/spentTokens/revision` 列，但 `status` 是裸 String 且恒为 `"executing"`，从未 rollup；`mission.squadId NOT NULL REFERENCES squad`。

## 目标

1. **规划者**：行动创建后由 LLM 一次规划调用产出多卡执行图（幂等 upsert、确定性回退、绝不信任模型 id）。
2. **Mission 状态机**：`planning → executing → delivering → accepted / failed`，由卡片状态纯函数 rollup，投影与事件同事务。
3. **串行依赖调度**：`actor Orchestrator` level-triggered reconcile（事件 + 周期 tick、幂等），`todo` 依赖全 done → `ready`，同一时刻至多一张卡在跑（一卡一主，M2 全局串行）。
4. **下游冷启动**：上游交接包 + 产物路径注入下游 `ContextPacket`，下游零聊天史开工。
5. **卡级 token 硬顶**：启用 `card.tokenBudget`（spec §5.2-5 内核不变量），超限 → `blocked(budget_exhausted)`。
6. **最小行动收口**：`delivering` 时可「收营」→ `accepted`；可「放弃」→ `failed`（在途卡终态化）。UI 为最小可用版。

## 非目标（防 scope creep）

- 多伙伴**并发**执行、`ask_user` 门、小队动态流、交付面板与行动视图人性化完整版（M3）。
- 营地笔记 / 伙伴记忆 / 向导注入上下文包（M4；`ContextPacket` 预留位即可，不实现）。
- 崩溃重启恢复 reconcile、预算 10% 收尾线注入、行动总额耗尽三选（加注/提前收营/终止）（M5）。`mission.spentTokens` 本期只累加展示，不触发暂停；规划轮消耗不产生 run 行、暂不计入 spentTokens（M5 预算体系补账，此处明示为已接受偏差）。
- 无工作目录小队的交付暂存区 `staging/<card_id>/`（spec §8）：M2 维持 M1 行为——无工作目录时文件工具报错；带产物的多卡行动需绑定工作目录。M2 验收路径（两卡 + 工作目录）不需要它。
- OpenAICompatProvider、动态重规划（revision 恒 1）、收营蒸馏营地笔记。
- 不改 `HandoffPayload` v1 字段与既有校验规则；不改文件/网络工具边界。blocked 原因维持 M1 的 `(reason, detail)` 字符串形态（spec §5.1 类型化关联值枚举的完整形态推迟到 M3 ask_user 需要 UserRequest 时一并改造，明示为已接受偏差）。

## 关键决策（请用户过目，均已定，列出备否决）

| # | 决策 | 理由 |
|---|---|---|
| D1 | M2 执行**全局串行**（同一时刻至多一张 running 卡），但规划者可把不同卡指派给小队内不同伙伴 | 验收只要求两卡串行；跨伙伴交接让「冷启动」有真实意义；并发留 M3 只改调度阀门 |
| D2 | 卡级 maxTurns / tokenBudget 一律取 `KernelDefaults` 常量（新增，见下），**规划者不做预算分配**（spec §13「缺省取设置默认值」允许；接设置项留 M5） | 砍掉一个模型可搞砸的自由度；分配策略等 M5 预算体系一起做 |
| D3 | `LLMProvider.streamTurn` 增加 `toolChoice` 参数，规划调用强制 `tool_choice: propose_plan` | 比「靠 prompt 恳求 + 校验兜底」可靠一个数量级；协议改动一次到位 |
| D4 | 交接包投影列 `card.handoffJson` + 显式 `card.stage` 列（migration v2），完成事务内同写 | 下游冷启动与详情面板需快查交接包；stage 是派发与渲染的权威序，不靠解析 idemKey 字符串 |
| D5 | 最小收营/放弃进 M2 | Mission 状态机没有终态就无法穷举测试；蒸馏与验收面板仍在 M4/M3 |
| D6 | Orchestrator 注入 `makeProvider: @Sendable (String) -> any LLMProvider` 工厂；派发卡用该卡 assignee 伙伴的 `companion.model`，规划调用用 `startMission` 传入的 `plannerModel`（App 层取设置默认模型） | 保住 M1 的每伙伴自选模型行为；测试注入恒返 MockProvider 的工厂 |
| D7 | `card.tokenBudget` 按 **per-attempt（每次 Run）** 语义执法：`retryCard` 即用户显式加注，新 Run 预算重新起算（与 maxTurns 的 per-run 语义对称，spec §6.1）；跨 Run 累计留 M5 | 简单且与 spec §6.1 伪代码一致；M2 默认 200k 几乎打不到 |
| D8 | **删除 M1 单卡直跑路径**：`AppStore.startRun(companion:title:...)` 与旧表单整体移除，TaskRunView 全面替换为行动视图；单卡场景 = 规划者产出单卡计划，仍走 Orchestrator。`createSingleCardMission` 仅作为测试夹具保留 | 避免绕过一卡一主注册表阀门的第二条执行路径 |

## 数据模型 / 契约变化（逐字段）

### migration v2（`AppDatabase.swift` migrator 追加 `registerMigration("v2")`，可重放）

```sql
ALTER TABLE card ADD COLUMN handoffJson TEXT NULL;
ALTER TABLE card ADD COLUMN stage INTEGER NOT NULL DEFAULT 1;
UPDATE mission SET status = 'executing'
  WHERE status NOT IN ('planning','executing','delivering','accepted','failed');
```

`CardRecord` 增加 `handoffJson: String?`、`stage: Int`。mission 行的 UPDATE 是枚举化前的数据归一化兜底（防手改库/实验数据解码失败）。为可测性，把 `migrator` 从 private 放宽为 `internal`（GRDB `DatabaseMigrator.migrate(_:upTo:)` 供测试构造 v1-only 库）。

### KernelDefaults（新建 `Sources/AgentLoopCore/Kernel/KernelDefaults.swift`）

```swift
public enum KernelDefaults {
    public static let maxTurns = 30
    public static let cardTokenBudget = 200_000
    public static let missionBudget = 200_000
    public static let maxTokensPerTurn = 8192      // 卡执行与规划轮共用
    public static let planMaxCards = 6
}
```

`AppStore.swift:111` 的字面量 30、`createSingleCardMission` 的默认参 200_000 改为引用此处。

### MissionStatus（`Records.swift`）

```swift
public enum MissionStatus: String, Codable, Sendable {
    case planning, executing, delivering, accepted, failed
}
```

`MissionRecord.status` 由 `String` 改为 `MissionStatus`（TEXT 列不变；v2 已做值归一化）。`createSingleCardMission` 相应改为 `.executing`。

Rollup 纯函数（放 `Records.swift`，与 CardStatus 同居）：

```swift
extension MissionStatus {
    public static func rollup(current: MissionStatus, cards: [CardStatus]) -> MissionStatus
}
```

规则（穷举测试）：
- `accepted` / `failed` 是粘性终态：`current` 为二者之一时原样返回，永不重算。
- `cards.isEmpty` → `planning`。
- 存在非终态卡（终态 = done/canceled；blocked **非**终态）→ `executing`。
- 全部终态且 ≥1 done → `delivering`。
- 全部终态且 0 done → `failed`（防御路径；正常只经放弃产生。这是对 spec §5.1「failed 仅两个触发」的**有意**防御性扩展，标注于此）。
- `accepted` 仅由收营动作显式设置（`delivering → accepted`）；`failed` 由放弃动作或上条防御规则设置。

### PlanProposal（`Kernel/Planner.swift`，内核内部契约，不落库）

```swift
struct PlanProposal: Codable {           // propose_plan 工具的入参形状
    let goalRefined: String              // 精炼目标一句话
    let cards: [CardDraft]
    struct CardDraft: Codable {
        let title: String
        let description: String
        let expectedOutput: String       // 必填，spec §6.2-2
        let assignee: Int                // 名册枚举序号，非 id ——绝不信任模型 id（spec §5.3）
        let dependsOn: [Int]             // 只允许引用更早的卡序号（0-based）
    }
}
```

`propose_plan` 工具 schema（用既有 `objectSchema` helper，`additionalProperties: false`，required 全字段）。仅规划调用可见，**不进 `m1Tools`**，伙伴执行时不可见。

校验纯函数 `PlanProposal.validate(rosterCount:) -> Result<PlanProposal, String>`：
- `1 <= cards.count <= KernelDefaults.planMaxCards`；
- 每卡 title/description/expectedOutput trim 后非空；
- `0 <= assignee < rosterCount`；
- `dependsOn` 元素 ∈ `0..<该卡下标`（天然无环、无自引用、无前向引用）且去重。

### 事件新增 kind（payload 均经 `JSONValue.encodedString()`，sortedKeys）

| kind | 挂载 | payload |
|---|---|---|
| `plan_started` | mission | `{}` |
| `plan_completed` | mission | `{goalRefined, cardIds: [...], titles: [...]}` |
| `plan_noop` | mission | `{reason: "cards_exist" \| "not_planning"}`（单规划者审计，spec §5.2-1） |
| `plan_fallback` | mission | `{reason: "llm_failed" \| "invalid_after_retry"}` |
| `card_ready` | card | `{}` |
| `card_canceled` | card | `{reason: "mission_abandoned"}`（每张被终态化的卡各一条，同事务） |
| `mission_status_changed` | mission | `{from, to}` |
| `mission_accepted` | mission | `{}` |
| `mission_failed` | mission | `{reason: "abandoned" \| "defensive_rollup"}` |

### LLMProvider 协议（`Provider/LLMProvider.swift`）

```swift
public enum ToolChoice: Sendable, Equatable { case auto; case tool(name: String) }
// streamTurn 增加参数：toolChoice: ToolChoice
```

- `AnthropicProvider.requestBody`：`.tool(name)` 编码为 `"tool_choice": {"name": name, "type": "tool"}`；`.auto` **不发该键**（与 M1 请求体字节级一致，保 prompt 缓存）。
- 波及的调用点全部显式传 `.auto`：`AgentLoop`（经 `providerTurnWithRetry`）、`ChatService`、测试里的 `MockProvider` / `FlakyProvider`（签名跟进；`MockProvider` 记录收到的 toolChoice 数组供断言）。

### ContextPacket 冷启动升级（`Loop/ContextPacket.swift`）

`upstreamHandoffs` 由 `[String]` 改为 `[UpstreamHandoff]`：

```swift
public struct UpstreamHandoff: Sendable {
    public let cardTitle: String
    public let handoff: HandoffPayload           // 从 card.handoffJson 解码
    public let workspaceRelativePaths: [String]  // 下游可用 read_file 直接读
    public let durablePaths: [String]            // 耐久备份绝对路径（信息性）
}
```

渲染进首条 user 消息的「# 上游交接」段，每个上游一小节，**确定性顺序**（按 `card.stage` 升序）、**无时间戳/UUID**（prompt 缓存纪律）。逐字段渲染：结果（outcome）、摘要（summary）、验证（method + ✓/✗ + note）、风险、建议下一步（next，advisory 文本，内核不机读）、产物两组路径并注明「工作目录内路径可直接用 read_file 读取」；**产物为空时渲染「无文件产物：<noArtifactReason>」**。

## 内核行为（边界与错误路径逐条）

### DB 层前置重构（pool.write 不可重入）

GRDB `DatabasePool.write` 不可重入，reconcile/planMission/cancel 的「单写事务」无法调用现有 public 方法。重构：`transitionCard` / `completeCard` / `blockCard` 各拆出接受 `Database` 参数的内部变体 `func xxx(_ db: Database, ...)`，现签名 public 方法变为 `pool.write` 薄包装（既有调用点零改动）；`rollupMission(_ db: Database, missionId:)`、reconcile、`planMission`、`cancelMissionCards` 一律在同一事务内使用 db 级变体。

### startMission（Orchestrator API + `AppDatabase.createMissionShell`）

```swift
func startMission(goal: String, companionIds: [String],
                  workspacePath: String?, plannerModel: String) async throws -> String
```

1. 单写事务 `createMissionShell`：`ensureDefaultCamp()` 营地下新建 `SquadRecord`（name = 目标首行截断 30 字符；`memberIdsJson` = companionIds 按用户勾选顺序编码——这是名册持久化的唯一权威；workspacePath 落列）+ `MissionRecord`（status `.planning`，`budgetTokens = KernelDefaults.missionBudget`，revision 1）+ 事件 `mission_created`、`plan_started`。返回 missionId。
2. spawn 规划 Task 并登记进 `planningTasks: [missionId: Task]`（放弃行动时可取消，见 cancelMission）；startMission 立即返回。
3. 规划 Task：发 `planningStarted` 事件 → LLM 规划调用 → 校验/矫正/回退 → `planMission` → 发 `planCompleted` + `missionChanged` → `reconcile()`。结束后自注销出 `planningTasks`。

### 规划调用（`Kernel/Planner.swift`）

- 一轮 `streamTurn(system: 规划者提示词, history: [首条 user], tools: [propose_plan], toolChoice: .tool("propose_plan"), maxTokens: KernelDefaults.maxTokensPerTurn)`，provider 由 `makeProvider(plannerModel)` 取得。user 消息含：目标原文、名册枚举（`序号. 名字 — 职责摘要`，摘要 = rolePrompt 首行截断 40 字符，顺序 = squad 名册序）、工作目录有无、指导语（建议 2–4 卡、串行依赖、每卡必须有可验证的 expectedOutput）。传输错误复用 `providerTurnWithRetry` 同款重试策略（可重试集合一致，退避 2s/4s）。
- **一次矫正重试**，两个分支的历史形状写死（tool_result 必须引用 tool_use id，孤立 tool_result 是非法请求）：
  - 响应含 `propose_plan` tool_use 但校验失败 → 追加 assistant 原文 + 引用该 tool_use id 的 `is_error` tool_result（内容为校验错误）后重发；
  - 响应无任何 tool_use（纯文本）→ 追加 assistant 原文 + 普通 user 纠错消息（「必须调用 propose_plan 并给出全部必填参数」）后重发。
- 再失败 → **确定性回退**并记 `plan_fallback{invalid_after_retry}`；LLM 彻底失败（重试耗尽）→ 回退并记 `plan_fallback{llm_failed}`（spec §5.3：规划有确定性回退）。
- 回退计划：单卡——title = 目标原文首行截断 60 字符；description = 目标原文全文；expectedOutput = `"完成行动目标，交付可验证的产物，并在交接包中说明验证方式"`；assignee = 名册第 0 位；无依赖。
- 仅 DB 写入失败才以 `kernelError` 事件上报，mission 停在 `planning`。

### planMission（`AppDatabase`，单写事务；守卫顺序即单规划者不变量落点）

```swift
func planMission(missionId: String, goalRefined: String, drafts: [PlanProposal.CardDraft]) throws
```

1. guard mission 存在（否则 throw `RecordNotFoundError`，编程错误）。
2. **单规划者不变量（spec §5.2-1，先于状态检查）**：该 mission 已有任何卡 → 记 `plan_noop{cards_exist}` 并 return（no-op，绝不 throw）。
3. guard `status == .planning`：不满足（如规划中被放弃，mission 已 failed）→ 记 `plan_noop{not_planning}` 并 return（no-op，绝不 throw——这是「放弃与在途规划竞态」的吸收点）。
4. 从 `squad.memberIdsJson` 解码名册，assignee 序号 → 伙伴 id（越界在 validate 已挡）。
5. 逐卡插入：id = 内核 UUID；`idemKey = "mission:<missionId>:stage-<N>"`、`stage = N`（N 从 1 起 = 数组序）；status 一律 `.todo`（就绪统一由 reconcile 提升，路径唯一）；`dependsOnJson` = 序号映射成**内核生成的卡 id** 数组；`maxTurns = KernelDefaults.maxTurns`、`tokenBudget = KernelDefaults.cardTokenBudget`；assigneeId = 名册映射。
6. 更新 `mission.goalRefined`，rollup（→ `.executing`），记 `plan_completed` + `mission_status_changed`。

### Rollup 挂点

`rollupMission(_ db: Database, missionId:)`（同事务调用）：读该 mission 全卡状态 → 纯函数 rollup → 有变化才 UPDATE mission.status + 记 `mission_status_changed`；**当结果为 `.failed` 且 current 非终态时，同事务追加 `mission_failed{defensive_rollup}`**。挂进：`transitionCard`（db 级变体）、`completeCard`、`blockCard`、`planMission`。**`startRun` 不挂**（如实：它是内联转移不经 transitionCard；ready→running 不可能改变 rollup 结果，故不重构不挂载）。`cancelMissionCards` 不走通用挂点（见下，避免伪 delivering 瞬态）。

### 调度（`Kernel/Orchestrator.swift`，`public actor`）

```swift
public actor Orchestrator {
    init(db: AppDatabase, makeProvider: @escaping @Sendable (String) -> any LLMProvider,
         artifactStoreRoot: URL, tickInterval: Duration? = .seconds(5))
}
```

持有：`running: [String: Task<Void, Never>]`（cardId → runner task）、`planningTasks: [String: Task<Void, Never>]`、`continuations: [UUID: AsyncStream<KernelEvent>.Continuation]`（**多消费者广播**；`events()` 每次调用新建一条流，`.unbounded` 缓冲）、tick Task。

```swift
public enum KernelEvent: Sendable {
    case planningStarted(missionId: String)
    case planCompleted(missionId: String, fallback: Bool)
    case missionChanged(missionId: String)          // 状态或卡片集有变，UI 重读快照
    case cardEvent(cardId: String, AgentEvent)      // 转发在跑卡的流事件
    case kernelError(missionId: String, message: String)
}
```

API：`startMission`（上文）、`reconcile()`、`cancelMission(_:)`、`retryCard(_:)`（blocked→ready + reconcile）、`closeout(_:)`、`events() -> AsyncStream<KernelEvent>`、`waitUntilIdle() async`（`running` 与 `planningTasks` 均空且无在途 reconcile 时返回——测试的确定性等待手段）、`shutdown() async`（取消 tick 与两个注册表内全部 task、finish 全部 continuation；AppStore 退出与测试 teardown 调用）。

生命周期：tick Task 常驻（每轮 `sleep(tickInterval)` 后调 `reconcile()`；`tickInterval == nil` 则不建 tick Task——测试默认传 nil，用事件与 `waitUntilIdle` 驱动）；reconcile 自身在无 `.executing` mission 时快速返回（tick 兜底漏事件，spec §5.3）。

`reconcile()`（幂等，触发 = 规划完成 + 每次 runner task 退出 + tick + retryCard）：**只扫 `mission.status == .executing` 的 mission**。
1. 单写事务：每张 `.todo` 卡解析 `dependsOnJson`，全部依赖 `.done` → db 级 `transitionCard(.ready, "card_ready")`。
2. **串行阀门（D1）+ 一卡一主（spec §5.2-3）**：`running` 注册表非空则不派发。为空时取 `stage` 最小的 `.ready` 卡派发：同步先在注册表占位，再 spawn task 跑 `CardRunner`（DB 侧 `startRun` 的 ready→running guard 是第二道锁）。task 退出（任何出口）自注销并再触发 `reconcile()`。
3. 派发时组装冷启动上下文：读该卡 `dependsOnJson` → 各上游卡的 `handoffJson` + `artifact` 表行 → `[UpstreamHandoff]`（按 stage 升序）→ `CardRunner.run(..., upstreamHandoffs:)`；provider = `makeProvider(assignee 伙伴.model)`；workspacePath 与伙伴名/职责经 card → mission → squad/companion 查询取得。上游卡必为 done（ready 的充要条件）；`handoffJson` 为 nil 时以 `kernelError` 上报并把该卡 block（防御，不 crash）。
4. 幂等性依据：状态提升有 `canTransition` guard；派发有注册表 + DB 双重 guard；重复调用无副作用。

`closeout(missionId)`：guard `status == .delivering`，否则 throw 类型化 `MissionStateError(missionId:from:expected:)`（UI 据此提示）；通过则单写事务 mission → `.accepted` + `mission_accepted` + `mission_status_changed`。

`cancelMission(missionId)`（放弃）：
1. **guard：mission 已是 accepted/failed → 整体 no-op return**（收营单向，spec §5.1；UI 在终态后同时隐藏放弃按钮）。
2. 取消 `planningTasks[missionId]`（若在规划中）与注册表内该 mission 的 runner task，await 退出（既有中断路径把 running 卡放回 `ready`，run outcome `canceled`——沿用）。
3. 单写事务 `cancelMissionCards`，**顺序固定**：先直接 UPDATE mission → `.failed` + 记 `mission_failed{abandoned}` + `mission_status_changed`（粘性终态即刻生效，杜绝「最后一张卡终态化时 rollup 先算出 delivering」的伪状态事件）；再逐张非终态卡（todo/ready/blocked/running）用 db 级转移置 `.canceled` 并各记 `card_canceled{mission_abandoned}`（转移全部合法；已终态卡跳过）。本函数不走通用 rollup 挂点。
4. 与完成竞态：runner 可能赶在取消前 complete——事务内逐卡按当前状态判定，done 卡保持 done；粘性终态保证 failed 不被重算。规划调用若已在途且取消未及时生效，其返回后调 `planMission` 被守卫 3 吸收为 no-op（白烧一轮 token，M2 接受）。

### 卡级 token 硬顶（`Loop/AgentLoop.swift`）

- `AgentLoop` 增加 `tokenBudget: Int` 参数（无默认值；`CardRunner` 传 `card.tokenBudget`；既有 4 处测试直接构造点 `AgentLoopTests.swift:95/259/396/432` 显式传 `Int.max`）。
- 每轮 `turnEnded(usage)` 后累加 `inputTokens + outputTokens`；循环条件收紧为 `turns < maxTurns && spent < tokenBudget`；因预算跳出 → `.blocked("budget_exhausted", "已用 <spent>/<budget> tokens")`。
- 语义 = per-attempt（D7）。累加防溢出按既有防御风格（历史雷点：退避算术溢出）。
- 10% 收尾线注入**不做**（M5，见非目标）。

### spentTokens 累加

`finishRun` 事务内追加：`mission.spentTokens += run.tokensIn + run.tokensOut`（经 cardId → missionId 查询）。仅展示，无行为分支。

## 触及文件清单（改动意图）

| 文件 | 动作 | 意图 |
|---|---|---|
| `Sources/AgentLoopCore/Kernel/KernelDefaults.swift` | 新建 | 默认值常量（上文） |
| `Sources/AgentLoopCore/Kernel/Planner.swift` | 新建 | propose_plan 工具 def、规划提示词、`PlanProposal` + `validate`、矫正重试两分支与确定性回退 |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | 新建 | actor：startMission/reconcile/串行派发/cancel/retry/closeout/waitUntilIdle/shutdown/tick/KernelEvent 广播；`MissionStateError` |
| `Sources/AgentLoopCore/Database/Records.swift` | 改 | `MissionStatus` 枚举 + rollup 纯函数；`MissionRecord.status` 改类型；`CardRecord.handoffJson`、`.stage` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | 改 | migration v2（含数据归一化）；migrator 改 internal；`transitionCard`/`completeCard`/`blockCard` 拆 db 级内部变体 + public 包装；`createMissionShell`；`planMission`；`rollupMission(db:)`；`cancelMissionCards`；查询：`cards(missionId:)`（ORDER BY stage）、`missionArtifacts(missionId:)`、`companions(ids:)`、`squad(forMission:)`；`finishRun` 累加 spentTokens；`createSingleCardMission` 改用 KernelDefaults 并写 stage=1 |
| `Sources/AgentLoopCore/Database/BoardCardTransactions.swift` | 改 | `completeCard` 同事务写 `handoffJson` + rollup；`blockCard` 挂 rollup（均经 db 级变体重构） |
| `Sources/AgentLoopCore/Loop/ContextPacket.swift` | 改 | `UpstreamHandoff` 结构与确定性渲染（含 noArtifactReason 分支） |
| `Sources/AgentLoopCore/Loop/CardRunner.swift` | 改 | 增 `upstreamHandoffs` 参数透传；透传 `tokenBudget`；maxTokensPerTurn 改引 KernelDefaults |
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | 改 | token 硬顶（上节） |
| `Sources/AgentLoopCore/Provider/LLMProvider.swift` | 改 | `ToolChoice: Sendable, Equatable` + `streamTurn` 签名 |
| `Sources/AgentLoopCore/Provider/AnthropicProvider.swift` | 改 | tool_choice 编码（`.auto` 不发键） |
| `Sources/AgentLoopCore/Provider/MockProvider.swift` | 改 | 签名跟进 + 记录 toolChoice 数组 |
| `Sources/AgentLoopCore/Chat/ChatService.swift` | 改 | 调用点传 `.auto` |
| `Sources/AgentLoopApp/AppStore.swift` | 改 | 持有 Orchestrator（makeProvider 闭包封装现有 provider(model:) 逻辑）；**删除单卡 startRun 路径（D8）**；mission 视图状态（卡片行快照重读 + 在跑卡活动流复用现有 ActivityItem 管线）；动作：startMission（传设置默认模型）/收营/放弃/重试；退出时 shutdown |
| `Sources/AgentLoopApp/Views/TaskRunView.swift` | 改 | 整体替换为行动视图：表单（目标多行 + 伙伴多选有序 + 工作目录）；规划中指示（复用 Avatar thinking + TypingIndicator）；卡片清单（CardRowView）；交付物条（聚合 mission 产物 + Finder reveal 沿用）；收营/放弃/重试按钮（终态后隐藏收营/放弃） |
| `Sources/AgentLoopApp/Views/Components/CardRowView.swift` | 新建 | 卡片行：六状态图标 + 人话文案（排队中/待启动/进行中/等你处理/已完成/已取消）+ 负责伙伴 + 最新进展一句话；**blocked 卡在该位置展示 blockedReason 的人话化 detail**（复用 blockedReasonJson，不新增交互） |
| 既有测试 | 改 | `FlakyProvider`/直接调 `streamTurn` 处签名跟进；AgentLoop 4 处构造点传 `Int.max`；`createSingleCardMission` 夹具保留 |

UI 原则：本期是**最小可用**行动视图；不做列式看板、不做小剧场、不做 matchedGeometry 大改（M3）。不暴露状态机术语，reduceMotion 沿用既有约定。

## 测试要求（`Sources/AgentLoopTestSuite/`，全部走 MockProvider/纯函数，不打真网；Orchestrator 测试一律 `tickInterval: nil` + `waitUntilIdle()`/事件驱动，禁止 sleep 轮询）

新建 `MissionRollupTests.swift`：
1. `rollupEmptyCardsIsPlanning`；2. `rollupMixedIsExecuting`（含 blocked 非终态）；3. `rollupAllTerminalWithDoneIsDelivering`；4. `rollupAllTerminalZeroDoneIsFailed`；5. `rollupTerminalStatesSticky`（accepted/failed 原样返回）。

新建 `PlannerTests.swift`（直接测 Planner + planMission，不经 Orchestrator）：
6. `validProposalPersistsCardsWithKernelIds`（idemKey stage-1..N、stage 列、全 `.todo`、dependsOn 序号→内核 id、assignee 序号→伙伴 id、goalRefined 落库、`plan_completed` 事件）；
7. `plannerForcesToolChoice`（MockProvider 断言收到 `.tool("propose_plan")`）；
8. `invalidProposalRetriesOnceThenFallsBack`（前向依赖脚本 + 再次无效 → 单卡回退 + `plan_fallback{invalid_after_retry}`；callCount == 2；`recordedHistories[1]` 含引用原 tool_use id 的 is_error tool_result）；
9. `noToolCallFallsBack`（纯文本响应两次 → 回退；`recordedHistories[1]` 含 assistant 原文 + 普通 user 纠错消息、**无** tool_result 块）；
10. `doublePlanIsNoopWithAuditEvent`（同一 mission 连续两次 planMission：第二次卡数不变 + `plan_noop{cards_exist}`）；
11. `planAfterCancelIsNoop`（mission 先被置 failed 再 planMission → 无卡插入 + `plan_noop{not_planning}`）；
12. `validateRejectsBadShapes`（0 卡 / 7 卡 / 空 expectedOutput / assignee 越界 / 自引用依赖，逐个 `.failure`）。

新建 `OrchestratorTests.swift`（fixture：Orchestrator(tickInterval: nil, makeProvider: 恒返脚本 MockProvider)）：
13. `dependentCardStaysTodoUntilUpstreamDone`；
14. `upstreamDoneUnlocksAndDispatchesDownstream`（A done 后 B ready→running→done）；
15. `serialGateNeverRunsTwoCards`（两张无依赖 ready 卡；权威断言 = run 表两行的 [startedAt, endedAt] 区间不重叠）；
16. `reconcileIsIdempotent`（连续两次 reconcile 只派发一次，run 行数 == 1）；
17. `cancelMissionTerminalizesAndFails`（各态卡分布 → 非终态卡全 canceled 且各有 `card_canceled` 事件、done 卡保持 done、mission failed、`mission_failed{abandoned}`；事件序列中**不出现** executing→delivering 瞬态）；
18. `cancelIsNoopWhenTerminal`（accepted 的 mission 调 cancelMission → 状态不变、零新事件）；
19. `retryBlockedCardRedispatches`（blocked→ready→跑完 done）；
20. `closeoutAcceptsFromDelivering` + `closeoutThrowsWhenNotDelivering`（断言 `MissionStateError`）。

新建 `ColdStartTests.swift`：
21. `downstreamPacketCarriesUpstreamHandoffAndPaths`（首条 user 消息含上游 outcome/summary/工作目录相对路径/耐久绝对路径；断言在 `recordedHistories` 上做）；
22. `packetRenderingIsDeterministic`（同输入两次渲染字节级相等；无时间戳；无产物上游渲染 noArtifactReason 行）。

新建 `GoldenPathTests.swift`（spec §15-4 金路径）：
23. `twoCardMissionEndToEndColdStart`——makeProvider 按 model 返回对应脚本 MockProvider：规划轮（propose_plan：卡 A→伙伴甲、卡 B→伙伴乙 依赖 A）→ A：write_file + complete_card（1 产物）→ B：complete_card（noArtifactReason 引用 A 产物结论）。断言：mission 状态轨迹 planning→executing→delivering（事件表回放）；B 的首条 user 消息含 A 的摘要与产物路径；artifact 表 1 行且耐久文件存在；`closeout` 后 accepted；两张卡各自 provider 收到的 model == 各 assignee 伙伴的 model（D6 验证）。

`AgentLoopTests.swift` 追加：
24. `tokenBudgetExhaustionBlocks`（脚本多轮大 usage → `.blocked("budget_exhausted", …)`，轮数 < maxTurns）。

`DatabaseTests.swift` 追加：
25. `migrationV2AddsColumnsAndNormalizes`（`migrate(upTo: "v1")` 构造旧库并插入 status 为怪字符串的 mission → 完整 migrate → 列存在、status 归一为 executing；对已 v2 库重复 migrate 幂等）；
26. `completeCardWritesHandoffProjection`（handoffJson 可解码回 HandoffPayload；stage 保序）。

`AnthropicProviderTests.swift` 追加：requestBody 含 `.tool` 时的 tool_choice 键形状断言 + `.auto` 不发键断言（缓存前缀字节级不变）。

既有 75 测试零回归（`runnerCancellationLeavesCardReady` 等取消语义不得破坏）。

## 验证命令

- `swift run RunTests` 全绿（预期 75 → 103±，以 impl-report 实数为准）。权威跑法，勿用 `swift test`。
- `swift build` 干净；`swift run AgentLoopApp` 构建通过（GUI 冒烟由用户做）。
- verify.log 全量保存。

## 完成定义

1. 上述 26 项新测试全绿，既有测试零回归。
2. 金路径测试（#23）完整覆盖 M2 验收语句「两卡依赖行动端到端，下游冷启动开工」的离线版。
3. 五条内核不变量在代码中各有明确落点：单规划者（planMission 守卫 2/3 + 测试 10/11）、产物先耐久（沿用）、一卡一主（注册表 + startRun guard + 测试 15/16）、工具唯一终结（沿用）、内核查终止（maxTurns + tokenBudget 双硬顶 + 测试 24）。
4. UI：能创建多卡行动、看到规划中→卡片清单→逐卡推进→交付物条→收营，全程无死等指示（复用既有动效件）；blocked 卡可见人话原因并可重试。
5. impl-report.md + verify.log 齐全；plan 外零改动。
6. 活体冒烟（用户执行，真实 API）：`docs/superpowers/2026-07-04-m2-live-smoke.md` 脚本由本任务一并产出——两卡依赖真需求、零人工到 delivering、产物 Finder reveal、收营 accepted（spec §15-5 硬门）。

## 实现顺序（供 Codex 按序执行，每步测试先行）

1. `KernelDefaults` + `MissionStatus` + rollup 纯函数 + 测试 1–5。
2. migration v2（列 + 归一化 + migrator internal）+ `CardRecord` 字段 + db 级变体重构（transitionCard/completeCard/blockCard）+ `completeCard` 投影/rollup 挂点 + `finishRun` 累加 + 测试 25–26。
3. `ToolChoice` 协议改造 + AnthropicProvider 编码 + Mock/Flaky/ChatService 跟进 + AnthropicProviderTests 追加。
4. token 硬顶 + 测试 24（含既有 4 处构造点跟进）。
5. `UpstreamHandoff` + ContextPacket 渲染 + CardRunner 参数 + 测试 21–22。
6. `createMissionShell` + Planner + planMission + 测试 6–12。
7. Orchestrator（含 waitUntilIdle/shutdown/广播）+ 测试 13–20。
8. 金路径 + 测试 23。
9. App 层（AppStore + TaskRunView + CardRowView，D8 删旧路径），构建通过。
10. live-smoke 脚本文档。

## 已接受的残留风险（评审确认，不阻塞）

- 金路径用多个脚本 MockProvider 时，实现偏差会以「mock script exhausted」而非语义断言失败——定位靠 verify.log。
- 规划轮 token 不入账 spentTokens（M5 补）；mission 总额不执法，总消耗由「≤6 卡 × 卡级硬顶」间接封顶，活体冒烟时用户在场目视。
- 上游卡 blocked 时行动停在「进行中」且无卡在跑，行动级停滞提示与系统通知不在 M2（M3 动态流覆盖）。
- 下游读上游产物依赖工作目录内原文件仍在（工具沙箱不能越界读耐久区）；串行场景下用户中途手删工作目录文件会使冷启动引用失效。
- tool_choice 与矫正重试的真实 API 契约（MockProvider 不校验消息形状）由 §15-5 活体冒烟硬门兜底。

## Open questions

（无。D1–D8 为待用户过目的已定决策，见上表。）
