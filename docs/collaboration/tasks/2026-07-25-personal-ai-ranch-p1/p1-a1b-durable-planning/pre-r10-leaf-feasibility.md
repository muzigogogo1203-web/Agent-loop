# P1-A1b Pre-R10 Leaf Feasibility Evidence

> 状态：**Read-only feasibility evidence — 非冻结 leaf Plan，非实施授权**
>
> 日期：2026-07-26
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 证据边界

本文件汇总 A1b 进入前的三路职责拆分只读审计：

1. AppDatabase / DurableWorkStore 原子事务与整数精度；
2. DurableWorkSupervisor lifecycle、lease、halt、wait 与 bounded shutdown；
3. PlanningProviderResolver、Planner、Orchestrator、AppStore、Coding Ranch 与
   MissionScheduler 接线。

审计未修改产品/测试代码，未建立可执行 leaf Plan，也未运行 A1b build/test。
当前冻结输入保持逐字不变：

- Stage：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
  - SHA-256：
    `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190`
- P1 Plan：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
  - SHA-256：
    `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3`
- A1a leaf Plan：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/plan.md`
  - SHA-256：
    `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb`
- A1a acceptance：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/acceptance.md`
  - SHA-256：
    `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032`

## 2. 总结论

在当前 repo truth 下：

- A1b 可继续复用 v12 schema，不需要新 migration；
- 冻结 Plan §3.2 的 12 个生产文件足以闭合实现；
- R10-1 只需把既有 matrix runner/script 加入 test-only 允许文件；
- 不需要修改 `Package.swift`、`Package.resolved`、`RunTests/main.swift` 或任何
  concrete Provider 文件；
- 已识别的冻结冲突完整收敛为 `blocked.md` 中 R10-1…R10-7；
- Supervisor、Store、Provider/App 三个审计域均未发现 R10-8。

这些结论只证明“R10 修订后可以写出不需要 implementer 临场做产品/架构决定的
leaf Plan”，不代表当前已经允许修订冻结输入或实施 A1b。

## 3. 待 R10 后写入 leaf Plan 的已审计合同

### 3.1 Command identity、same-key replay 与四个入口

`PlanningWorkInput` 保持冻结三字段：

- `plannerModel`
- `runtimeProfileId`
- `promptContractVersion = 1`

R10-3 增加的 `MissionPlanningStartIdentityV1` 应固定：

- goal；
- ordered companion IDs；
- workspace path；
- 按现行规则规范化并实际持久化的 budget；
- resolved non-null Camp ID；
- autonomy；
- 完整 `PlanningWorkInput`。

只用 `CanonicalJSONV1` 编码 identity。首写将它作为
`mission_created.payloadJson` 的规范 payload，并保留根级 `goal`。

固定命令顺序：

1. process-local dispatch gate；
2. same-key persisted identity/work-graph validation；
3. 仅 same-key absent 时做完整 provider preflight；
4. transaction 重读 exact profile ID/kind 并解析 exact Camp；
5. 原子写 Squad、Mission、events 与 work；
6. supervisor kick。

same-key replay 必须：

- 在 current credential/catalog/provider preflight 前完成；
- 相同 identity 返回原 `(missionId, workId)`，零写入；
- 不读取 current default，不覆盖首次 trace；
- profile 已删除或 credential 已失效时仍可返回原 IDs；
- conflict 优先于当前 credential/provider failure；
- dispatch 已 halted 时连 replay 也不得越过 dispatch gate。

四个入口的 key/trace：

| 入口 | idempotency key | 捕获规则 |
|---|---|---|
| 手动开工 | `mission-start:user:<UUID>:v1` | AppStore 创建 Task 前，在同一 MainActor turn 一次捕获 profile/model/key/trace/budget/autonomy |
| Coding Ranch candidate | `mission-start:candidate:<draftId>:v1` | 第一次 `await` 前捕获；enqueue 成功而 link 失败后的重试复用原 Mission |
| schedule | `mission-start:schedule:<scheduleId>:<checked-ms>:v1` | checked UTC milliseconds 与 profile/model selection 在现有 claim 前捕获为 Result |
| confirmed proposal | `mission-start:proposal:<proposalId>:v1` | proposal ID 派生 key；profile/model/trace 只捕获一次 |

Schedule 在 A1b **不改变既有 slot claim 语义**。selection/timestamp 可以在 claim
前只读捕获，但失败仍要在既有 claim 成功后走当前 missed 路径，不能提前进入
A4 的新 schedule-fire transaction，也不能留下无限重试同一 slot 的窗口。

nil Camp 保留现有“解析默认 Camp”兼容语义，但解析必须确定性：

- replay 对当前已存在的 resolved Camp 做逐字比较；
- 新 key 的 provider preflight 先完成；
- 随后在同一个 enqueue transaction 内按稳定顺序解析/必要时创建默认 Camp，
  再生成 identity 与 Mission/work IDs；
- default Camp、Squad、Mission 或 work 任一步失败必须一起回滚。

### 3.2 Provider resolver 与 Planner retry 边界

公共 resolver contract 保持：

```swift
public protocol PlanningProviderResolver: Sendable {
    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider
}
```

App concrete resolver 的权威来源：

- official API：raw `cachedCatalog + manualModels`；
- custom API：raw profile-scoped `modelChoices + manualModels`，禁止
  `modelChoices(fallback:)`；
- ChatGPT OAuth：只用 static catalog，并要求 primary token 与固定 secondary
  account；
- CLI：固定拒绝。

验证顺序固定为 profile → CLI → catalog → model membership → primary account →
primary credential → OAuth secondary credential → endpoint → provider construction。
Keychain 读必须 fail-if-interaction-required，并区分 not-found 与其他 OSStatus。
所有持久 message 使用 code 对应的静态安全摘要，不保存 raw provider body/Error、
credential 或 account ID。

Planner-layer error mapping候选：

| 来源 | code | disposition |
|---|---|---|
| `URLError` | `planning_transport_error` | transient |
| HTTP 429/5xx、overload exhausted | `planning_provider_unavailable` | transient |
| malformed stream | `planning_provider_malformed_response` | transient |
| unauthorized | `planning_provider_unauthorized` | deterministic |
| 其他 HTTP/API error | `planning_provider_http_error` / `planning_provider_api_error` | deterministic |
| 未分类 Error | `planning_provider_failed` | deterministic |

`CancellationError` 不构造 failure，由 cancel/halt owner 收口。

“Planner 无 transport retry”只删除 `Planner.providerTurn` 自己的 loop/sleep。
一个 durable attempt 最多调用一次 initial `streamTurn`，仅 schema invalid 时再调用
一次 correction `streamTurn`。Concrete Provider 在单次 stream call 内已有的
429/5xx retry、OAuth refresh 或 stream fallback 保留；adapter 最终抛错后才进入
5/30/120 秒 durable backoff。不得为改变这一点扩大到 concrete Provider 文件。

### 3.3 AppDatabase / Store 原子事务

| Command | 待冻结的事务合同 |
|---|---|
| `enqueueMissionPlanning(..., planningProviderResolver:)` | replay-first；新命令 preflight；单一 transaction 重读 profile/Camp/replay 后写 Squad、Mission、`mission_created`、`plan_started`、planning work |
| `commitPlanningSuccess` | 验证 latest claim、dispatch、Mission/Squad/roster/proposal；同一 transaction 写 exact usage、Cards、goal/rollup/events 并关闭 attempt/work |
| `recordPlanningAttemptFailure` | 参数使用 typed `PlanningAttemptFailure`，同时携同源 `Usage?` 与 `DurableWorkFailure`；usage 与 retry/fail 同一 transaction |
| planning overflow terminal command | 写 exact overflow evidence，并原子关闭 attempt/work/Mission；不经过普通 `usageJson` |
| `cancelPlanning` | work cancel、attempt/event、Mission failed/event 同一 transaction；同 reason replay 不重复写 |
| halt bulk cancel | 一个整体 transaction 取消全部 active planning 并失败对应 Mission；任一点失败全部回滚 |
| `repairLegacyPlanningMissions` | Mission ID 排序、逐 Mission transaction；可解析者 enqueue；不可解析者建 attempt=0 terminal work 且零 attempt row |

Store 只需增加最小读取 seam `work(id:)`；claim 后必须比对 returned work state/version
与 latest claim，再读取 immutable `inputJson/aggregateId`。A1b 可复用现有
`complete`、`retryOrFail` 与 `cancel` 的 transaction-only static commands；新增的
halt bulk cancel 与 overflow deterministic-fail primitive 保持 internal。

`PlanningAttemptFailure.usage` 语义：

- nil：没有完成任何可计量 provider turn；
- non-nil 全零：完成了可计量 turn，但 provider 报告三个 counter 均为零；
- 第一轮已完成、correction provider 抛错：保存第一轮 exact usage；
- aggregate/projection overflow：不得伪装成 nil，必须走 R10-7 专用路径。

### 3.4 整数精度与 overflow

`JSONValue` 把数字保存为 `Double`，大于 `2^53` 会失真。因此以下 payload 一律使用
private typed Codable → `CanonicalJSONV1.encode` → direct `EventRecord` insert：

- `MissionPlanningStartIdentityV1`；
- `planning_tokens`；
- `PlanningUsageOverflowEvidenceV1`；
- 任何含 token/budget/checked milliseconds 的 A1b evidence。

`missionSpendBreakdown` 改用 typed Int/Int64 decode 与 checked sum。正常口径保持：

- `Mission.spentTokens += inputTokens + outputTokens`；
- `cacheReadTokens` 原值只保存在 token event；
- nil usage 不写 token event；
- non-nil 全零 usage 仍写标准零值 event；
- negative usage 在任何 SQL 前拒绝；
- 禁止 saturation。

R10-7 的 overflow path 固定：

- stable code `usage_overflow`；
- evidence 保存 exact representable operands、scope 与排序后的 overflow fields；
- canonical event kind `planning_usage_overflow`；
- 不写 `planning_tokens`，不改 `spentTokens`，不 retry、不建 Card、不写 fallback；
- 同一 transaction 关闭 attempt/work 并把 Mission 置 failed；
- failure injection 必须让 evidence 与全部终态 mutation 一起回滚。

正常 planning usage 超过 Mission budget 但没有整数溢出，不走 overflow path：
exact 入账并建卡后，现有 reconcile 预算门写 `mission_budget_exhausted`、阻止 Card
派发并等待既有预算三选。

### 3.5 Supervisor

生命周期保持：

```text
initialized → recovering → running → shuttingDown → shutDown
```

另有独立 process-local `dispatchSuppressed`，不是第六种 lifecycle state：

- 初始化 suppressed；
- recovery 失败回到 initialized 且继续 suppressed，可安全重试；
- recovery 只成功一次；
- running 时 `startIfNeeded` 幂等；
- shutdown 后 start/recover/kick 全部 typed fail；
- 不可恢复 Store error 进入可观察 fatal latch、关闭派发并恢复 waiters。

每个 owned attempt 至少保存 task token、generation、Mission ID、latest claim、
provider Task、唯一 renewal timer 与 terminal-commit permission。核心规则：

- 一个 supervisor 只有一个 pump 和一个 next-due timer；
- 一个 work 一个 detached provider Task；
- claim 循环到无 due work，未来 retry 只设置最早 timer，不轮询；
- lease 60 秒，每 15 秒续租；terminal commit 只用 latest claim；
- stale renew 只取消 exact matching task，不得误删替代 token；
- callback 清理权限与 DB 写权限分开；
- actor gate 与同步 transaction write 之间不得有 `await`；
- DB/store error 不得 `try?`，running row 留给重启 adoption。

halt/recovery：

- cold-start running：legacy repair → adoption → unsuppress → start/kick；
- cold-start halted：repair/adoption 后保持 suppressed；一个整体 transaction
  收口全部 active planning；成功后 running-but-quiescent，零 pump/timer/provider；
- halt 第一 actor turn、任何 await 前先 suppress、停止 pump/timer/renewal、
  禁止 terminal commit 并 cancel provider；
- durable halt 或 cleanup 失败仍保持 local suppressed，resume 被阻断；
- resume 先在 halted 下重试 cleanup，再切 durable running，最后 unsuppress + kick；
- claim、renew、success/failure terminal transaction 都同时校验 durable mode；
- 显式 cancel 是唯一允许在 halted 下写 planning terminal projection 的控制路径。

等待/关停：

- `waitUntilIdle` 等 owned/pump 清空且无当前 due work；未来 retry 不阻塞；
- `waitUntilTerminal` 只在 durable succeeded/failed/canceled 返回；
- terminal waiter 可在 durable cancel 后返回，idle 仍等待不合作 provider 退出；
- 使用 checked continuation + cancellation handler，禁止 10ms DB polling；
- shutdown 第一个 actor turn先进入 shuttingDown、checked generation +1、停止
  pump/timer、禁止 commit、cancel renewal/provider；
- 不用 structured TaskGroup 与不合作 provider 做 deadline race；
- 用 actor continuation + 独立 deadline Task，返回 sorted unique
  `uncooperativeWorkIds`；
- deadline 后不 await provider；迟到 callback 全部被 lifecycle/generation/token
  gate 拒绝；
- shutdown 不修改 ledger，未退出 row 留给下一进程 adoption。

## 4. 测试门补充

冻结清单之外，leaf Plan 至少还应钉住：

### Replay / resolver

- replay 在 credential/catalog preflight 前；
- profile 删除后 replay 仍返回原 IDs/trace；
- replay 不调用 provider factory；
- preflight 与 transaction 之间 profile kind drift 零写；
- official/custom/OAuth catalog 隔离；
- Keychain not-found/read-failure 分离；
- provider construction typed failure；
- App/candidate/proposal key、trace 与 profile/model capture 不漂移。

### Schedule

- checked milliseconds overflow 不进入 Mission start；
- profile/model selection 失败按既有 claim + missed 语义收口；
- A1b 不创建 A4 schedule-fire transaction，不改变 slot claim CAS。

### Store / exactness

- identity/token/overflow payload 大于 `2^53` 仍逐字精确；
- nil usage 与 explicit zero usage；
- negative usage 零写；
- success/failure/cancel/legacy/halt bulk/overflow 每个 mutation 点全回滚；
- replay 保留首次 trace；
- planning success 超预算后 Cards 已建立但零 Card dispatch。

### Supervisor / halt / shutdown

- one pump/one timer、latest-claim renewal；
- halted startup 零 provider 且 cleanup 原子；
- halt persistence/cleanup failure 均保持 suppressed；
- halt-after-response 零 tokens/Cards；
- resume 只在 durable running 后 kick 一次；
- missing/corrupt kernel control fail closed；
- stale renew 只取消 exact token；
- idle/terminal waiter 差异；
- cancellation-ignoring provider 下 shutdown bounded，report sorted；
- shutdown 后迟到 provider/renew callback 零写；
- next process adoption exactly once。

### Migration matrix

- runner 新增具名 `v12-durable` source fixture；
- script 在 SQLite 3.51 与 3.52 linked lane 都运行该 fixture；
- schema/literal/既有 fixture verdict 不变。

## 5. 明确禁止的 leaf 实现捷径

- 不从裸 `DurableWorkFailure.usageJson` 建第二套 JSON parser；
- 不修改 `CanonicalJSON.swift` 来绕过 typed `Usage?`；
- 不让 A1b token/identity evidence 经过 `JSONValue.number(Double)`；
- 不给 `LLMProvider` 增无默认 requirement 或新增 `ProviderError` case；
- 不修改 concrete Provider 内部 retry；
- 不复用含 `try?`/default/catalog/endpoint fallback 的旧 App
  `provider(model:)` 作为 authoritative planning preflight；
- 不保留 compatibility overload 或在 Core 读取 current default；
- 不改变 Candidate transaction 或 Schedule claim 语义；
- 不把 fallback card 带入 durable planning；
- 不用饱和、prefix usage 或虚假 nil 收口 overflow；
- 不用 structured TaskGroup 等待 cancellation-ignoring provider；
- 不在 Review10 通过前修改任何产品/测试代码。

## 6. 继续门

下一步仍是取得用户对 `blocked.md` R10-1…R10-7 的有界修订授权。获授权后才可：

1. 只按七项修订 Stage/Plan；
2. 把本文件中的候选合同整理成可执行 A1b leaf Plan；
3. 更新 hashes/freeze evidence；
4. 交由未参与修订的 reviewer 执行职责隔离 Review10。

Review10 在新 hashes 上判定零 P0/P1 前，A1b implementation、acceptance、A2 与其他
产品代码继续关闭。
