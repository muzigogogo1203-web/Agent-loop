# M3 并发与交互 — 实现计划（Level 3，需用户确认后触发）

来源：spec §16-M3（`docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md`）。
验收基准（spec 原文）：**3 伙伴并发行动，中途问答 + 验收；小剧场准确反映各伙伴真实状态**。
分工（2026-07-05 起）：Claude 写方案与实施把关，**正式测试由用户执行**，测试结论决定修复轮。

分支：`feat/m3`（基于 feat/m2 HEAD `0aee71e`，含 M2.1 崩溃修复）。Codex 不 commit。

修订记录：v2 —— 已吸收三视角对抗自审全部 8P1/10P2/13P3（事件串台、ask_user 重试漏洞、候选 JOIN 矛盾、kernelError 落库点清单、导航状态机、多 pending 渲染、超时/取消区分等）。

## 现状基础（feat/m2 已有，勿重建）

- `Orchestrator` actor：reconcile（promotion + `LIMIT 1` 串行派发）、`running: [cardId: Task]`、`cancelling` 集合、`reconcilePending` 合并、tick 可注入、`waitUntilIdle`/`shutdown`、KernelEvent 多消费者广播。**`emit(.kernelError)` 共 5 处**：规划 task catch（~L82）、reconcile 事务 catch（~L168，missionId 为空串）、assignee 缺失 block 路径（~L174）、cancelMission catch（~L253）、runner catch（~L337）。
- `AgentLoop`：maxTurns + tokenBudget 双硬顶、按轮传输重试（2s/4s，history 从本轮快照重发）、终结契约、三振；**无每轮超时**（URLSession 也未配 timeout——冒烟实证挂起流会长期占槽）。
- `user_request` 表 schema 已建（id/cardId/kind/prompt/optionsJson/answerJson/createdAt/answeredAt），零代码触达；无 `UserRequestRecord`。
- 工具：`ToolDef.m1Tools` 七件套；`ToolOutcome = result/error/completed/blocked`；`blockedReasonJson` 形状 `{reason, detail}`，仅 CardRowView 解析。
- 事件表 append-only，已有 kind **16 种**（含经 transitionCard 传入的 card_ready/card_canceled/card_interrupted）；查询仅 `events(cardId:)`；kernelError 只进内存流不落库。
- UI：TaskRunView（表单⇄行动视图判定 = `currentMissionId == nil && missionPhase == .idle`）、CardRowView（六状态 + blocked detail + **对所有 blocked 卡显示重试**）、DMChatView ChatBubble 可复用；`handleKernelEvent` 对**任意** mission 的事件都会 reloadMission 覆盖中央视图（M3 多 mission 并行下会串台——本期必修）；无动态流/详情面板/行动列表。
- 动画：CompanionAvatarView 仅 idle/thinking；TypingIndicatorView；reduceMotion 基础模式；无失焦暂停、无状态派生机。
- 测试：108 全绿；waitUntilIdle、HangingProvider、makeProvider 按 model 路由、`missingAssigneeBlocksReadyCard`（断言 assignee 缺失卡被 block("other")——M3 重写派发时**不得破坏**）。

## 目标

1. **多伙伴并发**：per-companion 阀门——每伙伴同时至多一张卡，不同伙伴 ready 卡全部并发派发（spec §5.2-3 升级为逐伙伴粒度）。
2. **ask_user 门**：`ask_user(kind, prompt, options?)` → `user_request` 持久门 → 卡挂起（blocked/needs_human_input）→ 作答 → 冷重启复跑携带问答（spec §8/§13）。
3. **每轮 120s 超时**（spec §5.3/§14）：超时取消本轮 → 同轮重试一次 → 再超 → blocked(tool_failure)。
4. **小队动态流**：右栏事件气泡流 + 输入区（答题 CTA/收营），数据源 = 事件表 + KernelEvent 刷新信号（spec §11 右栏）。
5. **行动视图人性化完整版**：卡片详情滑出面板、待答卡置顶琥珀高亮、交付物条分组、侧栏行动列表（僵尸行动可见可放弃）、卡行状态翻转与 feed 气泡插入的轻量承接动效（spec §11.2 第一条随本期落地）。
6. **角色状态动画全集 + 篝火小剧场**：七态动画由真实状态纯函数派生，清单⇄小剧场切换，≤10fps、失焦暂停、reduceMotion 静态替代（spec §11.2/11.3）。
7. **kernelError 落库**（kind `kernel_error`，重启不失忆）。

## 非目标

- M4：营地笔记、伙伴记忆、向导对话/camp_status/propose_squad、私聊带工具。
- M5：启动恢复 reconcile、行动总额三选与全局预算节流、上下文压缩、打包分发、URLSession 层网络超时（本期只做 loop 层每轮超时）。
- staging 交付暂存区（维持 M2 决定）；Rive/Lottie；多窗口；自定义看板列；动态流伙伴维度过滤与无限滚动（近 200 条封顶）。
- blocked 原因完整类型化枚举重构：沿用 `{reason, detail}` + 本期新增 `userRequestId`（M2 已声明偏差的延续）。
- **右栏输入框的「下达新行动」职能移至侧栏行动列表入口**（spec §11 原文三职能之一；申报偏差，理由：行动是侧栏导航实体，右栏重复入口徒增歧义）。
- **右栏实现为 TaskRunView 内 HSplitView 而非第三导航列**（视觉满足三栏，属实现自由度，申报备查）。

## 关键决策（请用户过目，均已定，列出备否决）

| # | 决策 | 理由 |
|---|---|---|
| D1 | 并发阀门 = **per-companion**：`running: [cardId: RunningEntry{task, assigneeId, missionId}]`；派发循环纯内存判定（busy 集合），**循环体内禁止 await**；候选集与 promotion 同一写事务内读取，assignee 缺失卡**在同一事务内** block（沿用 M2 语义）。跨 mission 排序 = mission.createdAt ASC, card.stage ASC | 一卡一主自然升级；僵尸行动不再独占全局槽；无 await 循环杜绝快照失效竞态 |
| D2 | ask_user 由 handler **一事务完成**（插 request + blocked + 事件），返回既有 `.blocked` 结局；事务失败沿用 block() 先例返回 `.error` 自愈 | 复用终结管道；持久门重启仍在（spec §13） |
| D3 | 作答复跑 = 冷重启 + **全部已答问答**按序注入；`answerUserRequest` guard = 卡 blocked **且 reasonJson.userRequestId == 本 requestId**，否则 StaleUserRequestError | 冷启动纪律一致；guard 收紧杜绝旧答案复活错误状态的卡 |
| D4 | 每轮超时改为 **空闲挂起检测**（正式测试实证修订：重负载轮的健康首 token 延迟可超 60s，按整轮总时长掐会误杀慢而活的流）——`turnTimeout: Duration = KernelDefaults.turnTimeout`（默认 120s）计量的是**连续无任何流事件的空闲时长**，每收到一个 ProviderEvent 重置计时；竞速后**先 `try Task.checkCancellation()`**——外部取消原样抛 CancellationError（放弃行动仍走 canceled 路径），仅外层未取消且空闲计时器先醒才算超时；timeoutCount 为 **providerTurnWithRetry 局部**（每轮重置，「连续两轮超时」= 同一 turn 连续两次尝试）；第二次超时由 providerTurnWithRetry 内部消化，loop 捕获特型 `TurnTimeoutError` 返回 `.blocked("tool_failure", …)`；超时重试沿用传输重试的 **history 快照纪律**（轮中增量全部丢弃重发） | spec §14 语义逐条落定；取消/超时不混淆；缓存前缀不被半截消息污染 |
| D5 | 动态流数据源 = 事件表（`events(missionId:limit:200)`），FeedEntry 派生为 Core 纯函数；KernelEvent 只当刷新信号 | 持久可回放；映射进 Core 才可测 |
| D6 | 详情面板 `.inspector`；待答卡置顶排序（needs_human_input 优先，余按 stage）；**needs_human_input 卡行隐藏通用「重试」，只渲染「去回答」答题组件**（防绕过持久门产生多条未答 request） | 修复自审 P1：重试绕门会破坏「最多一条未答」结构保证 |
| D7 | 动画派生纯函数作用域 = **当前 mission 的卡集**（伙伴在其他并行 mission 忙时本剧场显示其在本行动内的状态，napping/idle）；输入 = 卡状态集 + `cardPhases`（AppStore 由 AgentEvent 维护）+ 3s 瞬态完成集 | 验收「与清单一致」以当前行动为准；跨 mission 全局态观感混乱且难测 |
| D8 | 小剧场同数据第二渲染；**>6 伙伴双圈圆弧、>10 横向滚动**；30s 无交互（点击/滚动重置，随 mission 切换重置）→ 切换钮脉冲两次；篝火/地图 reduceMotion 时**静态单帧**（火苗定格、无粒子、地图定格展开态），与头像统一走 paused 条件 | spec §11.3 全项 + reduceMotion 无死角（live-test 第 6 步硬门） |
| D9 | 侧栏行动列表（最近 20 + 状态徽标），导航状态机见专节；右键放弃任意行动（AppStore 增 `cancelMission(missionId:)` 转发） | 僵尸可见可清；导航行为写死防分歧 |
| D10 | `m1Tools` 更名 `agentTools`（含 ask_user 共 8 件） | 名副其实；调用点仅 CardRunner 与测试 |

## 数据模型 / 契约变化（逐字段）

### UserRequestRecord（`Records.swift` 新增；表已存在，无迁移）

```swift
public struct UserRequestRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public var id: String            // 内核 UUID
    public var cardId: String
    public var kind: Kind            // enum Kind: String { choice, confirm, text }
    public var prompt: String
    public var optionsJson: String?  // kind==choice 必有：JSON [String]，2...6 项
    public var answerJson: String?   // {"choice": Int} / {"confirm": Bool} / {"text": String}
    public var createdAt: Date
    public var answeredAt: Date?
}
public enum AskUserAnswer: Sendable { case choice(Int), confirm(Bool), text(String) }  // View→Store 传参；Store 序列化 answerJson
// UserRequestRecord.humanAnswer() -> String：choice→选项文本（越界索引防御性渲染为「选项 N」）、confirm→「确认/否」、text→原文（Core，可测）
```

### ask_user 工具 schema（`ToolDef.swift`，加入 `agentTools`）

```text
ask_user:
  kind: string enum [choice, confirm, text]（必填）
  prompt: string（必填，trim 非空）
  options: array of string（kind==choice 必填 2–6 项；其他 kind 传入即校验错误）
additionalProperties: false, required: [kind, prompt]
```

校验失败或 suspend 事务失败 → `.error` tool_result（卡保持 running，模型自愈）。

### blockedReasonJson 扩展（向后兼容）

needs_human_input：`{"detail": <prompt>, "reason": "needs_human_input", "userRequestId": <id>}`（sortedKeys）。CardRowView 既有解析只读 reason/detail，不破坏。

### 事件新增 kind

| kind | 挂载 | payload |
|---|---|---|
| `user_request_created` | card | `{kind, prompt, userRequestId}` |
| `user_request_answered` | card | `{userRequestId}` |
| `kernel_error` | mission | `{message}`（独立小事务尽力而为，失败静默） |

`card_blocked`（ask_user 路径）payload 增 `userRequestId`。

### AppDatabase 新增 API

```swift
func suspendCardForUserRequest(cardId:runId:kind:prompt:options:) throws -> String
//   单事务：插 request + blocked 转移(含 rollup) + card_blocked/user_request_created 事件
func answerUserRequest(requestId:answerJson:) throws
//   单事务：guard request 未答 && 卡 blocked && 卡.reasonJson.userRequestId == requestId（D3）
//   → 写答案+answeredAt + 卡 blocked→ready(card_ready, payload {answeredRequest}) + user_request_answered 事件
//   guard 不满足 → throw StaleUserRequestError（UI 收到即刷新，CTA 消失）
func answeredRequests(cardId:) throws -> [UserRequestRecord]      // 已答，createdAt ASC
func pendingUserRequests(missionId:) throws -> [UserRequestRecord] // 未答，跨卡，createdAt ASC（feed 输入区数据源）
func events(missionId:limit:) throws -> [EventRecord]              // 取最近 limit(默认 200) 条后正序
func missions(limit:) throws -> [MissionRecord]                    // createdAt DESC，默认 20
func appendKernelErrorEvent(missionId:message:)                    // 独立写事务，错误吞掉
```

自愈边界：卡 blocked(needs_human_input) 但已无未答 request（理论不可达，防御）→ UI 按普通 blocked 处理（显示重试）。

### ContextPacket 扩展

新参数 `answeredRequests: [(prompt: String, answer: String)]`（humanAnswer 产物）。渲染进首条 user 消息「# 此前你向用户提问的记录」段（上游交接之后、「现在开始工作」之前），确定性顺序、无时间戳。

### Core 新增纯逻辑（均可单测）

```swift
// Feed/ActivityFeed.swift
public struct FeedEntry: Sendable, Identifiable { id, timestamp, actor: Actor, kind: Kind, text, cardId?, userRequestId? }
//   Actor = companion(id,name) | system | user；Kind = directive/planned/claimed/progress/question/blocked/delivered/canceled/statusChange/error
public enum ActivityFeed { static func entries(events:[EventRecord], cards:[CardRecord], companions:[String:CompanionRecord]) -> [FeedEntry] }
// 映射（其余 kind 一律不进 feed）：mission_created→directive(user)、plan_completed→planned(system,含卡数)、plan_fallback→planned(system,注明回退)、
// card_started→claimed(assignee)、progress_note→progress(assignee)、user_request_created→question(assignee,带 userRequestId)、
// user_request_answered→progress(user,"已回复")、card_blocked(非 needs_human_input)→blocked(assignee,人话 detail)、card_completed→delivered(assignee,summary)、
// card_canceled→canceled(system)、mission_status_changed(to==delivering)→statusChange(system,"全部小目标完成，等你收营")、
// mission_accepted/failed→statusChange(system)、kernel_error→error(system)

// Presentation/CompanionAnimState.swift
public enum TurnPhase: Sendable { case waitingProvider, streaming, toolRunning }
public enum CompanionAnimState: Sendable, Equatable { case idle, thinking, working, asking, scratching, celebrating, napping }
public enum AnimStateDeriver {
    static func derive(companionId: String, cards: [CardRecord], phases: [String: TurnPhase], recentlyCompletedCardIds: Set<String>) -> CompanionAnimState
}
// 优先级（高→低，穷举测试；cards = 当前 mission 卡集，D7）：
// celebrating(瞬态) > asking(blocked+needs_human_input) > scratching(其他 blocked) > working(running 且 toolRunning)
// > thinking(running 且 waitingProvider/streaming) > napping(有未终态卡但无 running) > idle(无卡/全终态)
```

## 内核行为（边界与错误路径逐条）

### 并发调度（`Orchestrator.swift`）

- `RunningEntry { task: Task<Void,Never>; assigneeId: String; missionId: String }`。
- `reconcileOnce` 重写：
  1. **单写事务**：promotion（不变）+ 读候选集——全部 executing mission 的 ready 卡按 `mission.createdAt, card.stage` 排序，companion 用 **LEFT JOIN**（或事务内逐卡查）；**assignee 为 nil 或伙伴缺失的候选在本事务内 block("other") + 记事件**（与 M2 逐字一致，`missingAssigneeBlocksReadyCard` 必须保持绿）；返回可派发候选数组（含 name/rolePrompt/model）。
  2. **事务外派发循环（纯内存，无 await）**：`busy = Set(running.values.assigneeId)`；逐候选：assignee ∉ busy 且 missionId ∉ cancelling 且 cardId ∉ running → `let task = Task { await run(...) }` 后**立即登记** running 与 busy（actor 隔离保证登记先于 runnerFinished 生效——runner 回调必须排队等 actor）。
- runner 的 `startRun` 抛 `CardTransitionError`（过期候选：派发与放弃竞态，卡已非 ready）→ **静默返回**（debug 日志，不 emit kernelError、不落库）——该竞态无害，不应渲染成用户可见故障。
- 一卡一主：伙伴粒度由 actor 注册表单锁保证（权威）；DB 侧仍是卡粒度 guard（startRun ready→running）。**明示非双锁**；M5 启动恢复引入 DB 遗留 running 行时需回访此处。
- `cancelMission`：按注册表 `missionId` 过滤取消（不再查卡表快照）；其余顺序同 M2。
- `answerUserRequest(requestId:answerJson:) async throws`：db 调用 + 成功后 **emit(.missionChanged(missionId))**（作答即时刷新 feed/CTA/置顶）+ `reconcile()`；StaleUserRequestError 原样上抛给 UI。
- 派发组装：`answeredRequests(cardId:)` 与 upstreamHandoffs 一并传 CardRunner。
- `kernel_error` 落库：**5 处 emit 点中带 missionId 的 4 处**（规划 catch / assignee 缺失路径 / cancelMission catch / runner catch）各补 `appendKernelErrorEvent`；reconcile 事务 catch（无 missionId）**不落库**只进内存流。
- `retryCard` 不变（UI 层保证 needs_human_input 卡无此入口，D6）。

### ask_user 全链路

1. 模型调 ask_user → 校验 → `suspendCardForUserRequest` → `.blocked` 终结 run → `blockCardIfStillRunning` no-op → finishRun(blocked)。
2. runner 退出 → 该伙伴解除占用，可跑其他卡（提问不堵别人）。
3. 作答（feed 输入区或卡行内联）→ `orchestrator.answerUserRequest` → guard（D3）→ 卡 ready → emit + reconcile → 冷重启带全部问答。
4. 竞态：作答 vs 放弃 → guard 卡非 blocked → Stale 上抛 → UI 刷新；作答 vs 作答（双入口同时）→ 事务串行，后到者 Stale。
5. 「挂起时最多一条未答」：模型路径结构保证（blocked 后不再运行）；UI 路径由 D6（无重试入口）封死。
6. 未答 request 随卡终态自然沉底（不清理，feed 不再渲染 CTA——渲染源是 `pendingUserRequests(missionId:)` 且卡须 blocked）。

### 每轮超时（`Loop/AgentLoop.swift`）

D4 已写死全部语义。补充实现位点：竞速包在 providerTurnWithRetry 的单次尝试粒度（`withThrowingTaskGroup`：流消费 vs `Task.sleep(turnTimeout)`），`TurnTimeoutError` 为 Core 新类型；第一次超时 yield `.turnRetrying(attempt:_, reason:"本轮超时")` 后立即重试（不退避）。

### App 层

**事件作用域（修自审 P1：多 mission 并行防串台）**：`handleKernelEvent` 一律先判归属——`missionChanged/planCompleted/planningStarted/kernelError` 带 missionId 直判；`cardEvent` 经 `missionCards` 的 cardId 集合判。**missionId == currentMissionId 才更新中央视图状态**（missionPhase/missionCards/feed/cardLatest/cardPhases…）；非当前 mission 的事件只触发 `missionList` 刷新（徽标）。**删除 `currentMissionId = currentMissionId ?? missionId` 隐式吸附**——currentMissionId 只由导航与 startMission 显式设置。

**导航状态机**（修自审 P2）：
- `Destination`：`.newMission`（原 .newTask 更名，新行动表单）、`.mission(String)`、`.settings`、`.chat(String)`、`.editCompanion(String?)`。
- 入口映射：侧栏「新行动」→ `.newMission`（表单）；`startMission` 成功 → `selection = .mission(id)` 且 `currentMissionId = id`（侧栏高亮随中央视图走）；列表选中 → `.mission(id)` → `currentMissionId = id` + reloadMission + feed 重读；放弃/收营留在当前 `.mission`；右键放弃非当前行动不改 selection。
- TaskRunView 判定改为 Destination 驱动（`.newMission` → 表单；`.mission` → 行动视图），废除 `currentMissionId == nil` 判定。
- `missionList` 刷新触发：任意 missionChanged / planCompleted / startMission 成功 / 放弃动作后。
- **启动领养（正式测试实证的坑）**：AppStore 启动时调一次 `orchestrator.reconcile()`（唤醒 tick）——重启后遗留的 executing 行动在行动列表**可见**且继续被调度，不再出现「看不见的行动占着执行槽」；用户可从列表选中查看或右键放弃。完整崩溃恢复（running 卡复位）仍属 M5。

**AppStore 新增**：`feedEntries`、`pendingRequests: [UserRequestRecord]`、`cardPhases`（turnStarted→waitingProvider、textDelta→streaming、toolStarted→toolRunning、toolFinished→streaming、finished→移除）、`recentlyCompleted: Set<String>`（3s Task 移除）、`companionAnimStates`（卡/相位/瞬态变化时重算）、`missionList`、`theaterMode`（随 currentMissionId 切换重置为清单）、`answerRequest(requestId:AskUserAnswer)`（序列化 + 转发 + Stale 时刷新 + `feedNotice` 轻提示）、`cancelMission(missionId:)` 转发。
刷新策略：missionChanged / toolFinished(add_progress_note|ask_user) / finished → 重读 feed + 卡片快照 + pendingRequests；textDelta 不触发重读。

**FeedView**：气泡流（复用 ChatBubble 样式）+ 底部输入区——**多条 pending 按 createdAt ASC 逐条堆叠渲染（可滚动）**，每条 = 卡题 + AskUserPromptView；delivering 时追加收营 CTA。与卡行内联同时可答，事务 guard 防双答。
**AskUserPromptView**：choice 按钮组 / confirm 确认取消 / text 输入提交；提交后本地禁用，Stale → 整体刷新。
**CardDetailInspector**（`.inspector`）：状态 + 人话时间线（events(cardId) 走 FeedEntry 映射）+ 交接包逐字段 + Run 历史 + 产物 reveal + 开发者视角（原始状态/idemKey/预算）。
**卡行**：动画态头像、待答置顶琥珀高亮 + 内联答题（无重试按钮，D6）、其他 blocked 卡保留重试、点击开详情；状态翻转加 `.transition`/`.animation` 轻量承接，feed 气泡插入动画同理（目标 5）。
**交付物条**：按卡分组 + 空态文案。

### 动画与小剧场

- 七态各 TimelineView interval：呼吸/眨眼 0.4s、思考 0.25s、干活敲击 0.3s、举手 0.5s、挠头 0.5s、欢呼 0.2s×3s、打盹 Zzz 0.6s；统一 `paused = reduceMotion || controlActiveState != .key`；reduceMotion 每态静态姿势 + SF Symbol 角标。
- `CampfireTheaterView`：中心篝火（2 帧火苗 0.3s + 3 点火星循环；**reduceMotion 静态单帧无粒子**）；伙伴围坐 ≤6 单圈、7–10 双圈、>10 横向滚动；每人大号头像(动画态)+名字+一行状态短语；点击开该伙伴在跑/最近卡详情。规划中场景：向导 + 摊地图 2 帧（reduceMotion 定格展开态）。
- 切换：分段控件「清单｜小剧场」；executing 且 30s 无交互（点击/滚动/切 mission 重置）→ 切换钮 `.symbolEffect(.pulse, options: .repeat(2))`；reduceMotion 不脉冲。

## 触及文件清单（改动意图）

| 文件 | 动作 | 意图 |
|---|---|---|
| `Kernel/Orchestrator.swift` | 改 | RunningEntry、两段式派发（事务内候选+block，事务外无 await 循环）、answerUserRequest、kernel_error 四点落库、过期候选静默、cancel 简化 |
| `Kernel/KernelDefaults.swift` | 改 | `turnTimeout: Duration = .seconds(120)` |
| `Loop/AgentLoop.swift` | 改 | 超时竞速（取消优先判定、局部计数、内部消化转 blocked）；`TurnTimeoutError` |
| `Loop/CardRunner.swift` | 改 | answeredRequests/turnTimeout 透传 |
| `Loop/ContextPacket.swift` | 改 | 问答注入段 |
| `Tools/ToolDef.swift` | 改 | ask_user schema；`m1Tools`→`agentTools` |
| `Tools/BoardTools.swift` | 改 | askUser handler（校验 + suspend；事务失败→.error） |
| `Database/Records.swift` | 改 | UserRequestRecord/Kind/humanAnswer、AskUserAnswer、StaleUserRequestError |
| `Database/AppDatabase.swift` | 改 | 新 API 七个（见契约节） |
| `Feed/ActivityFeed.swift` | 新建 | FeedEntry 映射纯函数 |
| `Presentation/CompanionAnimState.swift` | 新建 | TurnPhase + 七态派生 |
| `App/AppStore.swift` | 改 | 事件作用域过滤、导航配合、feed/相位/瞬态/列表/答题/放弃转发 |
| `App/Views/RootView.swift` | 改 | 行动列表 + Destination 重构（.newMission/.mission） |
| `App/Views/TaskRunView.swift` | 改 | Destination 驱动判定、HSplitView、待答置顶、切换钮+脉冲、交付物分组、承接动效 |
| `App/Views/Components/CardRowView.swift` | 改 | 动画态头像、内联答题（needs_human_input 无重试）、琥珀高亮、点击开详情 |
| `App/Views/Components/CompanionAvatarView.swift` | 改 | 七态 + 失焦暂停 + reduceMotion 静态集 |
| `App/Views/Components/FeedView.swift` | 新建 | 气泡流 + 多 pending 输入区 |
| `App/Views/Components/AskUserPromptView.swift` | 新建 | 三题型答题组件 |
| `App/Views/Components/CardDetailInspector.swift` | 新建 | 详情面板 |
| `App/Views/Components/CampfireTheaterView.swift` | 新建 | 篝火小剧场 |
| 既有测试 | 改 | `serialGateNeverRunsTwoCards` 改写（测试 1）；`m1Tools` 更名跟进；`missingAssigneeBlocksReadyCard` 保持绿 |

## 测试要求（Orchestrator 类全部 tickInterval nil + waitUntilIdle，禁 sleep 轮询）

新增测试助手 **`GatedProvider`**（actor）：构造注入脚本；`streamTurn` 挂起直至放行；`waitUntilStarted(count: Int = 1)` 等第 N 次开流；`release()` FIFO 放行一个挂起流并回放下一脚本条目；暴露 `callCount`。测试 12 复用（永不 release + 毫秒级 timeout）。注意：门控挂起期间**不得**调 waitUntilIdle（会悬），测试须先 release 再等。

`OrchestratorTests.swift` 改/增：
1. `sameCompanionCardsStaySerial`（原 serialGate 改写：两卡同 assignee → run 区间不重叠）；
2. `distinctCompanionsRunConcurrently`（3 卡 3 伙伴 3 GatedProvider：waitUntilStarted×3 后逐个 release → 3 条 run 区间三重重叠）；
3. `mixedGatingDispatchesEagerly`（甲 2 卡 + 乙 1 卡：首轮并发甲1+乙；甲1 完成后甲2 才跑）；
4. `busyCompanionSkippedNotStarved`（甲忙时其 ready 卡不派发，甲空后自动补派）；
5. `cancelDuringConcurrentRunsTerminalizesAll`（并发 2 卡门控挂起 + 小 timeout 时放弃 → 全部终态化、run outcome 为 canceled **而非 blocked**——同时锚定 D4 取消优先规则、无幽灵重派）。

新建 `AskUserTests.swift`：
6. `askUserSuspendsCardAndPersistsRequest`；
7. `askUserValidationErrorsSelfHeal`（非法 kind / choice 缺 options / options 1 项 → .error，卡保持 running）；
8. `answerResumesWithQAInContext`（答 choice → 复跑首条消息含 prompt+选项文本 → 完成）；
9. `answerStaleRequestThrows`（放弃后作答 → Stale，卡保持 canceled）；
10. `answerGuardRejectsMismatchedRequest`（卡因 tool_failure blocked 时用旧 requestId 作答 → Stale，卡保持 blocked——锚定 D3 收紧 guard）；
11. `askingCompanionDoesNotBlockOthers`；
12. `multipleQARoundsAccumulate`（两轮问答 → 第三次复跑含两组问答按序）。

`AgentLoopTests.swift` 增：
13. `turnTimeoutRetriesOnceThenBlocks`（永不产出 + 毫秒 timeout → turnRetrying(超时)×1 → blocked("tool_failure")，callCount==2）；
14. `timeoutThenSuccessDoesNotAccumulate`（每轮首尝试超时、重试成功 ×2 轮 → completed——锚定局部计数语义）；
15. `turnCompletesUnderTimeout`（充裕 timeout 行为与 happy path 一致）。

新建 `FeedTests.swift`：
16. `feedMapsEventKindsToEntries`（映射表全 kind + 不该出现的 kind 断言不出现）；
17. `feedQuestionCarriesRequestId` + `feedCapsAtLimit`。

新建 `AnimStateTests.swift`：
18. `deriveMatrixCoversAllPriorities`（七态优先级矩阵，含「该伙伴卡不在本 mission → idle」的 D7 作用域用例）；
19. `humanAnswerRendering`（三题型 + 越界索引防御）。

`GoldenPathTests.swift` 增：
20. `twoCardMissionWithMidwayAskUser`（spec §15-4 完整形态：上游卡中途 ask_user → 作答 → 上游完成 → 下游冷启动首条消息**同时含**上游交接摘要与不含问答段——问答只注入提问卡自身；断言两卡 done、mission delivering）。

`DatabaseTests.swift` 增：
21. `eventsByMissionOrdered` / `missionsListOrderedDesc` / `suspendAndAnswerRoundTrip` / `pendingRequestsAcrossCards`。

预期总量 108 → 135± 全绿（keychain 真机绿）。

## 验证命令

- `swift run RunTests` 全绿（真机权威）；`swift build` / `swift run AgentLoopApp` 构建通过。
- UI 无自动测试；正式测试由用户按脚本执行。

## 用户正式测试脚本（交付时产出 `docs/superpowers/2026-07-05-m3-live-test.md`）

1. 三伙伴 + 工作目录，目标含独立子任务 → 观察 ≥2 伙伴同时「进行中」。
2. 目标写明「不确定处必须问我」→ 卡置顶琥珀高亮 + 动态流举手气泡 → 作答（试卡行与右栏两个入口各一次）→ 复跑产出与答案一致。
3. 动态流气泡与推进一致；小剧场 30s：敲打/打盹/举手与清单一致；失焦后动画暂停。
4. 详情面板：时间线/交接包/Run 历史/产物 + Finder reveal。
5. 收营 → accepted；侧栏行动列表切换历史行动不串台；右键放弃残留行动。
6. Reduce Motion 开启复跑第 3 步：头像、篝火、地图全部静态替代，无脉冲。
7. （可选韧性）执行中断网 >2 分钟：卡在两次超时后转「等你处理」而非永久卡死。

## 完成定义

1. 21 组新测试全绿、既有测试零回归（serialGate 改写除外）；`missingAssigneeBlocksReadyCard` 保持绿。
2. 不变量落点：per-companion 注册表（单锁权威，措辞如实）+ 卡粒度 DB guard；ask_user 持久门（含 D3 收紧 guard 与 D6 无重试入口）；每轮超时含取消区分。
3. 纯逻辑（feed 映射/动画派生/问答注入/humanAnswer）全在 Core 且有测试。
4. UI：行动列表 + 中央视图 + 右栏动态流三区成立、事件按 currentMissionId 过滤不串台、详情面板、待答置顶、小剧场、失焦暂停、reduceMotion 静态替代。
5. impl-report.md + verify.log + live-test 脚本齐全；plan 外零改动。
6. 用户正式测试通过后打 `m3` tag。

## 实现顺序（Codex 按序，每步测试先行）

1. UserRequestRecord + AppDatabase 七 API + 测试 21。
2. GatedProvider + Orchestrator per-companion 并发（两段式派发）+ kernel_error 落库 + 过期候选静默 + 测试 1–5。
3. ask_user 工具链 + answerUserRequest + 测试 6–12。
4. ContextPacket 问答注入（并入测试 8/12/20）。
5. 每轮超时 + 测试 13–15。
6. ActivityFeed + 测试 16–17；CompanionAnimState + 测试 18–19；金路径 20。
7. App 层：事件作用域过滤 + 导航状态机 + AppStore 扩展 + RootView/TaskRunView 重构 + FeedView/AskUserPromptView。
8. CardDetailInspector + 交付物分组 + 承接动效。
9. 动画七态 + CampfireTheaterView + 切换/脉冲/失焦/reduceMotion。
10. live-test 脚本；全量真机复跑。

## 已接受的残留风险（自审确认，不阻塞）

- 每轮超时的取消传播真机行为（URLSession bytes 对任务取消的响应）离线验不到——live-test 第 7 步兜底；URLSession 层 timeout 仍未配（M5）。
- UI 层无自动测试，布局/inspector/动画细节押在用户正式测试上，修复轮成本不可控。
- 多 mission 并行无全局预算节流（行动总额三选在 M5）；长挂行动 + 新行动并行的真实 API 成本靠行动列表可见性 + 用户放弃管理。
- 并发断言依赖 run 表时间戳排序（门控保证逻辑序，时钟回拨理论上可造伪失败，概率可忽略）。
- 每答一题冷重启前缀变化，prompt 缓存按次失效——预期内成本。
- kernel_error 落库「尽力而为」，DB 本身故障时错误不可见（与初衷的自噬边界，接受）。

## Open questions

（无。D1–D10 为待用户过目的已定决策。）
