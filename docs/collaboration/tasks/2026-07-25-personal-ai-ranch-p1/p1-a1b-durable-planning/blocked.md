# P1-A1b Execution Control — A1b accepted

> 状态：**A1b Accepted；R-01 Closed；A2 Entry Open / Not Started**
>
> 日期：2026-07-27
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 入口与冻结输入

P1-A1a 已由职责隔离 Review 和独立 acceptance 判定 `ACCEPTED`。本文件完整保留
随后 R10/R11 blocker、冻结、Review 与 A1b implementation history。当前最终事实
是：A1b Review01 经有界根因修复后判定 `APPROVED — 0 P0 / 0 P1`，独立
acceptance 以 22/22 PASS 判定 `ACCEPTED`；R-01 已关闭，A2 仅
`Entry Open / Not Started`。

R10 前冻结输入（作为 blocker 发现时的历史基线）：

- Stage：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
  - SHA-256：
    `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190`
- P1 Plan：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
  - SHA-256：
    `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3`

本文件记录进入阻塞、R10/R11 关闭证据与最终 closeout；它不授权任何产品代码，
尤其不授权本次 invocation 创建或实施 A2。

## 2. 职责隔离只读审计结论

两路只读审计确认：

- 冻结 Plan §3.2 的 12 个生产路径覆盖当前全部直接生产调用点；
- 17 个现有测试路径与 2 个计划新建测试路径覆盖当前受影响调用点；
- `Package.swift` 与 `Sources/RunTests/main.swift` 不需要为 A1b 新测试修改；
- A1b 的 Supervisor、Store seam、error mapping、halt gate 与 shutdown 细节可在
  leaf Plan 内继续冻结；
- 但以下 7 个事项会改变冻结文件范围或公共数据/API 语义，不能由 leaf Plan
  自行解释。

## 3. 七个冻结契约 blocker

### R10-1 — A1b matrix gate 与允许文件冲突

冻结 Plan §10 要求 A1b 独立运行
`fresh/v7/v8/v9/v10/v11/v12-durable` predecessor matrix，§11 要求执行现有
matrix script；但 §3.2 的 A1b 允许文件没有 runner 和 script。

当前 runner 的 `Fixture.allCases` 与 script 参数/断言只到 v11。虽然 runner 会在
每个既有 fixture 上重开 v12 数据库并重复 migrate，但这不是 §10 明列的独立、
具名 `v12-durable` 来源 fixture，不能靠 leaf Plan 宣称等价。

最小修订：

- A1b test-only 允许文件增加：
  - `Sources/P1MigrationMatrixRunner/main.swift`
  - `scripts/verify-p1-migrations-sqlite-matrix.sh`
- 两者只允许增加具名 `v12-durable` replay fixture，并在 SQLite 3.51/3.52
  两条 linked lane 运行；
- 不修改 v12 DDL/literal、既有 fixture verdict、产品 target、`Package.swift`
  或 `Package.resolved`。

### R10-2 — `startMission` 没有冻结 idempotency key / trace ID 来源

冻结 Plan 的 `enqueueMissionPlanning` 要求 `idempotencyKey` 与 `traceId`，但
Orchestrator `startMission` 没有冻结这两个 required 参数及上游来源；与此同时，
A1b 必测又要求 same-key replay/conflict。

最小修订：

- `Orchestrator.startMission` 增加 required
  `idempotencyKey:String` 与 `traceId:String`；Orchestrator/DB 不得替换或现场
  重生成；
- AppStore 用户动作在创建 Task 前各生成一次 UUID command key 与 trace ID；
- Coding Ranch candidate 使用
  `mission-start:candidate:<draftId>:v1`；
- schedule fire 使用
  `mission-start:schedule:<scheduleId>:<checked-UTC-milliseconds>:v1`；
- confirmed proposal 使用
  `mission-start:proposal:<proposalId>:v1`；
- 每个入口一次捕获 exact runtime profile ID、planner model、key 与 trace，并传到
  durable transaction；同一入口的重试复用 command key。首次 work 的 trace 保持
  权威，replay 不覆盖。

### R10-3 — same-key “payload” 没有不可变身份

Stage §6.3 与 Plan §3.2 把 `PlanningWorkInput` 固定为
`plannerModel/runtimeProfileId/promptContractVersion` 三字段；goal、roster、
workspace、budget、camp 与 autonomy 不在 work input hash 内。Mission 的 budget
和 autonomy 之后可变，因此不能用当前投影证明原始开工 payload。

最小修订：

- 定义 immutable `MissionPlanningStartIdentityV1`：
  - `goal`
  - ordered `companionIds`
  - `workspacePath`
  - 当前规则接受并实际持久化的 `budgetTokens`
  - resolved non-null `campId`
  - `autonomy`
  - 完整 `PlanningWorkInput`
- 只使用 `CanonicalJSONV1` 生成 canonical bytes；首写把该 object 作为
  `mission_created.payloadJson` 的规范 payload，保留根级 `goal`；
- same-key replay 必须在生成任何 Squad/Mission/work UUID 前读取原 work/Mission
  event，逐字验证 identity、work input/hash、camp 与固定 `maxAttempts=4`；
- 全部相同返回原 `(missionId,workId)` 且零新写；任一不同抛
  `DurableWorkReplayConflictError`；
- `traceId` 明确排除在 payload identity 外，replay 不覆盖首次 trace。

### R10-4 — 完整 resolver preflight 没有可实现的 owner

Stage §6.3 要求在任何新 Mission 业务写之前完整 resolve provider；Plan 又把该责任
放在 `enqueueMissionPlanning`，但其固定参数没有 resolver。AppDatabase 不能安全
自行构造 OAuth token refresher，也不能回读 current default。

最小修订：

- `enqueueMissionPlanning` 增加 required
  `planningProviderResolver:any PlanningProviderResolver`；
- 方法先只读查询 same-key work：已存在时必须完整验证 persisted identity/work graph；
  same-payload replay 直接返回首次 `(missionId,workId)`，不依赖当前 credential/catalog，
  不重跑 provider，也不产生写入；冲突优先抛 `DurableWorkReplayConflictError`；
- 仅 same-key absent 的新命令在 `pool.write` 之前读取 exact profile snapshot、完整
  resolve 并丢弃短生命 provider；
- transaction 在任何业务 insert 前重读 exact profile ID，并要求 kind 与 preflight
  snapshot 相同；缺失、CLI 或 kind drift 全部零业务写；若并发 winner 已插入同 key，
  transaction 复用同一 identity/work graph validator，same payload 返回 winner，
  conflict 回滚；
- Orchestrator 把 initializer 持有的同一 resolver 传入，固定顺序为：
  dispatch gate → identity/replay validation → full resolver preflight →
  enqueue transaction → supervisor kick；
- 禁止 compatibility overload、current-default lookup 或 catalog/credential fallback。

### R10-5 — fallback event 语义自相矛盾

Stage §6.3 同时要求 success transaction “写显式 fallback event”，又要求 P1
`fallbackReason` 必须为 nil，否则抛 `unexpected_planning_fallback`。当前文字无法
确定 nil 是否要写 `plan_fallback(reason:null)`。

最小修订：

- `commitPlanningSuccess` 在任何 mutation 前要求
  `result.fallbackReason == nil`；
- nil 时不写 `plan_fallback`；
- non-nil 抛稳定码 `unexpected_planning_fallback` 且零写入；
- success 固定写一条含三个 checked usage counter 的 `planning_tokens` 与一条
  `plan_completed`；
- failure-injection 的 fallback 点指 nil-policy guard，不代表必须落 fallback event。

### R10-6 — durable Supervisor 启动与持久停营合同冲突

Stage §6.3 与 Plan §3.2 把启动顺序固定为 legacy repair → interrupted-work
adoption → supervisor start/kick；Plan 又把 `startIfNeeded` 定义为创建 pump，
但没有给 Supervisor 冻结 paused/quiescent 状态，也没有要求 planning 的
claim/renew/terminal transaction 与 `kernel_control.global.dispatchMode` 原子互斥。
照字面实施会让持久化 `halted` 的冷启动重新 claim provider，或让停营后的迟到
provider response 写入 tokens/Cards。

这与已经验收的停营合同冲突：restored halt 必须零 kernel/provider dispatch；
`emergencyStop` 和 halted 冷启动都必须把遗留 planning 用
`emergency_halt_during_planning` 原子收口为 terminal work + failed Mission；
cleanup 失败必须保持 halted 并阻断 resume。

最小修订：

- Supervisor 持有独立于 lifecycle 的 process-local `dispatchSuppressed`
  门闩；初始化即 suppressed。持久化 halt 失败时，本进程仍必须保持 suppressed，
  不能因 SQLite 仍为 running 而重开 provider。
- `recoverOnStartup` 固定先做 legacy repair 与 interrupted planning adoption，
  随后读取 exact durable dispatch mode：
  - `running` 才允许 start pump/kick；
  - `halted` 必须对全部 active planning 执行与
    `cancelPlanning(..., reason:"emergency_halt_during_planning")` 相同的
    work terminal + Mission failed transaction；全部成功后 Supervisor 进入
    running-but-quiescent，且不建 pump/timer、不 claim、不 resolve/call provider；
  - 任一 cleanup 失败保持 fail-closed、保留可重试证据，且 `resume` 不得先把
    durable mode 改为 running。
- planning claim、lease renew、success/failure terminal proposal 都必须在其
  SQLite transaction 内要求
  `kernel_control.global.dispatchMode == running`；missing/corrupt/halted 均零
  provider-path 写入。控制面的 cancel transaction 明确允许在 halted 下执行。
- `emergencyStop` 进入 Supervisor 的第一个 actor turn、任何 `await` 之前，先设置
  suppressed、停止 pump/next-due/renewal、禁止 owned attempt terminal commit 并
  向本地 provider Task 传播 cancellation；随后持久化 halted，并在一个整体
  SQLite transaction 中对全部 active planning 执行上述 projection-atomic
  cancel。halt 持久化或 planning cleanup 任一失败时，本进程仍保持 suppressed，
  错误可见且 resume 被阻断；不得因等待不合作 provider 才开始 Card/进程清理。
- `resume` 在 durable mode 仍为 halted 时先完成/重试全部 planning cleanup；
  只有 cleanup 全成功后才原子切换为 running、打开 Supervisor dispatch gate 并
  kick 一次。
- generation gate 与 durable dispatch gate 必须共同覆盖
  halt-after-response、halt-vs-claim、halt-vs-renew、halt-vs-terminal-proposal；
  任一 loser 零 tokens/Cards/重复 terminal event。

### R10-7 — usage overflow 无法用现有 failure shape 诚实收口

Stage §6.2.2 把 `DurableWorkFailure.usageJson == nil` 唯一定义为“本 attempt
没有可计量 provider turn”，非 nil 又只能保存三个 `0...Int64.max` counter。
Stage §6.3 同时要求以下已经发生 provider turn 的情况走 deterministic
`UsageOverflowError` 并 terminalize：

- correction turn 与已累计 turn usage 的任一字段合计溢出；
- exact attempt usage 与 Mission 既有 `spentTokens` 合计溢出。

这些 exact operands 各自可表示，但其 aggregate 不能放入 `Usage`、SQLite
`INTEGER` 或现有 usage object。使用 nil 会说谎；写 `Int.max` 是饱和；只记
overflow 前 prefix 会漏掉已消耗 turn；先让 success transaction 抛错再走普通
failure transaction 还会对同一 usage 二次溢出。leaf Plan 无权自行选择其中任何
一种不诚实语义。

最小修订：

- 增加 planning-only `PlanningUsageOverflowEvidenceV1` 与
  `planning_usage_overflow` event kind；evidence 保存 exact representable
  operands、稳定 reason 与排序后的 `overflowFields`：
  - turn aggregate：prior accumulated Usage + incoming turn Usage；
  - Mission projection：existing Mission spent + exact attempt Usage。
- evidence 只用 private typed Codable + `CanonicalJSONV1` 生成 canonical bytes
  并直接插入 Event；不得经过 `JSONValue.number(Double)`。
- 增加 planning-only overflow terminal command；它不构造虚假的
  `DurableWorkFailure.usageJson`，而是在单一 transaction 内验证 latest claim、
  planning work、Mission 与 durable dispatch gate，写 overflow evidence，
  以稳定码 `usage_overflow` 关闭 attempt/work、把 Mission 置 failed 并写终态
  events。
- overflow path 不写 `planning_tokens`、不改 `spentTokens`、不 retry、不建 Card、
  不返回 success；Mission 原有 exact `spentTokens` 保持不变，未折叠 usage 由
  overflow event 作为权威证据。
- 必测两轮 aggregate overflow、`input+output` overflow、existing-spent 累加
  overflow、failure-injection 全回滚，以及大于 `2^53` 但未超过 Int64 的 exact
  event round-trip。

## 4. R10 边界与继续门

R10 若获授权，只允许：

1. 修订冻结 Stage §6.2.2、§6.3 与 Plan §3.2、§10、§11 中上述七项；
2. 建立 A1b leaf Plan，把已审计的 Supervisor/Store/Orchestrator/App/test 细节完整
   冻结；
3. 更新 hashes 和 freeze evidence；
4. 由未参与本轮修订的 reviewer 执行职责隔离 Review10。

R10 不允许：

- 修改任何产品代码或测试代码；
- 改 v12 schema、迁移名称、既有 A1a evidence 或 acceptance；
- 进入 A1b implementation、A1b acceptance、A2 或其他 slice；
- 修改 Rumination、Candidate transaction、Schedule claim 语义；
- commit、push、merge、release、数据重置、外部操作或真实用户操作。

只有 Review10 在新冻结 hashes 上判定零 P0/P1 后，A1b 产品实施门才可打开。

## 5. R10 有界修订结果

牧场主已明确授权 R10。Planner 仅在第 4 节授权边界内完成七项冻结契约修订、建立
A1b leaf Plan 并重新冻结：

| 冻结输入 | SHA-256 |
|---|---|
| Stage | `36420de83e30043665c72d8ad8f0cf6ed98e930df296327c9f2d19bc9a72e62e` |
| P1 总 Plan | `e89f7e972f665a49f1bd07bd4921ad86e6ce595429344718639ef0688f8b32af` |
| A1b leaf Plan | `bb5aa2cd5e7eb7e0cfcbd472b63382d4e5d0a0afd6d4e195737772e82f8c35be` |

冻结与范围证据：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r10-freeze-validation.md`
- 三份冻结文档的 Open Questions 均精确为“无。”；
- Stage/Plan/leaf code fences 分别为 42/16/32，均平衡且无 trailing whitespace；
- `git diff --check` 通过；
- 产品、测试与 Package 路径保持 R10 进入指纹；本轮未运行产品测试或 build。

冻结前对抗审计曾把 halted legacy repair 的 mode-read 顺序标为候选 R10-8；它属于
R10-6 同一 restored-halt 根因，并已通过 mode-first linearization、halted
attempt=0 原子取消与并发 halt 测试合同关闭。冻结前最终只读审计未留下新的
P0/P1 blocker，但不替代职责隔离 Review10。

当时七项 blocker 的首轮 candidate 修订已完成，原 `Blocked` 状态解除到
`Review10 Pending`；产品与测试实施门保持关闭。

## 6. Review10 findings 与 Candidate 2

职责隔离 Review10 在第 5 节三个首轮 hashes 上判定
`CHANGES REQUIRED — 0 P0 / 2 P1`。不可变报告：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10-p1-plan-review.md`
- SHA-256：
  `acac1f5b09359f27a095acb12804a58daf6ac3d1250dc5fb7309699cd21851c1`

两项 finding 没有扩大 R10：

| Finding | 同根 closure |
|---|---|
| R10-P1-01：generic `DurableWorkStore` 可绕过 planning durable/halt/Mission owner | R10-6：九个 generic mutation/dispatch API 封口、typed error、dual-reserved 顺序、唯一 fileprivate specialized owner 与 adoption/tests/sentinels |
| R10-P1-02：App 四入口功能测试在当前 target graph 不可达 | R10-1：已允许 `Orchestrator.swift` 内 package-only coordinator/DTO，App 单实例接线，TestSuite 直接功能测试与真实 App source-range/order tests；Package/RunTests 不变 |

Candidate 2 冻结输入：

| 冻结输入 | SHA-256 |
|---|---|
| Stage | `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6` |
| P1 总 Plan | `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61` |
| A1b leaf Plan | `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e` |

重新冻结与零代码漂移证据：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r10a-freeze-validation.md`
- generic seal 与 App entry reachability 两路预冻结只读 crosswalk 均为
  `APPROVED — 0 P0 / 0 P1`；
- 产品、测试、Package 与 RunTests manifests 均保持 Review10 进入指纹；
- 本轮没有运行产品 test/build/matrix/preview。

Candidate 2 冻结时状态为 `Review10 Rereview Pending`，产品与测试实施门继续关闭。
只有未参与
planner 修订的职责隔离 reviewer 在上述 Candidate 2 精确 hashes 上给出
`APPROVED — 0 P0 / 0 P1`，A1b implementation 才能打开；A2 继续关闭。

## 7. Review10A approval

职责隔离 Review10A 已完成：

- 报告：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10a-p1-plan-review.md`
- verdict：`APPROVED — 0 P0 / 0 P1`
- SHA-256：
  `a268725470996d04db109b4caeb378fdfa64b66abd85b6f7ac55ecb420956bfe`
- Candidate 2 Stage/Plan/leaf hashes、旧 Review10、三组产品/test/Package manifests、
  `42/16/34` fences 与 hygiene 全部匹配；
- 未运行产品 test/build/matrix/preview，报告外零写入。

因此 R10 文档 blocker 已关闭，A1b implementation gate 已打开。implementer 只能
按 frozen leaf §3 allowlist与 §11 顺序实施、验证和写 owner 证据；任何 red/unknown、
范围漂移、Package/RunTests 变化或新架构决定立即重新阻塞。A2 继续关闭，直到 A1b
independent acceptance 为 `ACCEPTED`。

## 8. R11 implementation-discovered contract blockers

R10 implementation、一次完整 `swift run RunTests` 与三份职责隔离只读审计共同确认：
当前不是单一红测，而是四个冻结输入没有给出合法实现边界的合同缺口。计数为
`0 P0 / 4 P1`。这些缺口必须先由 planner 有界修订、重新冻结并经 Review11
`APPROVED — 0 P0 / 0 P1`；implementer 不得直接发明答案。

### R11-1 — Schedule extreme finite Date persistence

Failure-first/full-suite 证据稳定复现：

- frozen leaf §12.1 要求
  `scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission`；
- §10.4 要求 finite Date 的 checked UTC milliseconds 超出 `Int64` 时仍先沿用
  `claimScheduleFire` 占有 slot，再恰好写一次 missed；
- 测试 Date 为 `10_000_000_000_000_000` epoch seconds；
- GRDB 默认 Date TEXT encoder 经 Foundation formatter 得到空字符串，
  `claimScheduleFire` 提交 `lastFiredAt=""`；
- 随后稳定失败：
  `could not decode Date from database value "" - column: "lastFiredAt"`。

这不是时序或断言问题。替换日期、跳过 reload、把 overflow 当成未 claim、放宽断言，
或在 `Orchestrator.swift` 复制 Schedule SQL/CAS，都会改变冻结语义或制造第二 owner。
根因位于 leaf §3.1 未允许的
`Sources/AgentLoopCore/Database/ScheduleStore.swift`。

R11 必须冻结：

1. 只把 `ScheduleStore.swift` 增加到 A1b 生产 allowlist；
2. `ScheduleRecord.databaseDateEncodingStrategy(for:)` 只对 `lastFiredAt` 使用
   GRDB `.timeIntervalSince1970` numeric/Double encoding；其他 Date 继续
   `.deferredToDate`；
3. 解码继续使用 `.deferredToDate`，同时兼容既有
   `yyyy-MM-dd HH:mm:ss.SSS` TEXT 与新 numeric epoch seconds。禁止把 decoder
   改成 `.timeIntervalSince1970`，否则旧 TEXT 会被 SQLite numeric coercion
   静默误读；
4. `DATETIME` 的 NUMERIC affinity 可将无小数 Double 保存为 INTEGER，所以
   storage class 允许 INTEGER/REAL，禁止 TEXT/空串，不得固定 `typeof=REAL`；
5. 只有 finite `scheduledFireDate` 定义有效 slot。
   `PlanningEntryCoordinator.fireSchedule` 必须在生成 UUID、调用
   `selectRuntime`、构造 preparation `Result` 与调用 `claimScheduleFire` 之前检查
   `scheduledFireDate.timeIntervalSince1970.isFinite`；non-finite 直接抛现有
   package `InvalidSchedulePlanningFireTimeError`，runtime selection 调用数为零，
   Mission/work/event/`lastFiredAt` 全部零写。ScheduleStore 不把 non-finite
   转成 missed，也不成为第二个 checked/claim owner；
6. finite 但 milliseconds 超 `Int64` 才进入现有
   `Result.failure → claim → missed` 合同；
7. claim CAS、slot 判断、missed event 与 schema 不变。

最小命名测试：

- `scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes`
- `scheduleLegacyTextLastFiredAtRemainsReadable`
- `scheduleDateEncodingChangesOnlyLastFiredAt`
- `nonFiniteScheduleFireFailsBeforeClaimWithoutWrites`

### R11-2 — Startup recovery must activate planning only after Card recovery

冻结 Stage/Plan 当前要求 running-mode Supervisor 先打开 local gate/pump，再执行
Card orphan adoption。当前实现因此只能在 Card adoption 失败后调用
`suppressForOrchestratorRecoveryFailure()` 重新关闭。该 reactive re-suppress
不是根因修复：在两次操作之间，due planning 已可能 claim、resolve、调用 provider
或提交终态。

R11 必须把 startup 改成两阶段 activation：

1. Supervisor lifecycle 新增仅存在于进程内的 `.recoveryReady`，不新增持久状态。
   `recoverOnStartup` 只完成 legacy repair、interrupted planning adoption 与 exact
   durable-mode read；mode=running 时进入
   `lifecycle=.recoveryReady + dispatchSuppressed=true`，零
   pump/timer/claim/resolver/provider；
2. Orchestrator 再完成 Card orphan adoption、proposal healing，并重验 transition
   ownership 与 durable mode；
3. 全部成功后，唯一 actor-isolated internal
   `activateAfterOrchestratorRecovery()` 才能线性化 activation。它原子要求：
   lifecycle 为 `.recoveryReady`、仍 suppressed、无 fatal、无 halt cleanup
   pending，并在方法内部重读 durable mode 仍为 running；满足后才切
   lifecycle=`.running`、打开 gate、创建唯一 pump/timer 并 kick 恰好一次；
4. Card recovery 失败时 durable mode 保持 running、Supervisor 从未激活；该
   failure handling 不新增 planning terminal write、halt bulk cleanup 或
   `camp_halted/camp_resumed`。此前合法提交的 legacy repair/adoption 事实不回滚、
   不重复；
5. Orchestrator 在 Card adoption + proposal healing 后、调用 activation 前后都
   必须重验 transition token；activation 内部的 durable-mode read 是最终 DB fence；
6. emergencyStop 与 shutdown 都可从 `.recoveryReady` 进入；shutdown还可从
   `.initialized|.recovering` 直接进入`.shuttingDown`并清除全部startup retry
   eligibility/token。`suppressForEmergencyStop()` 在`.initialized|.recovering`
   固定抛`SupervisorRecoveryRequiredError`且零状态 mutation，因此不算control
   winner。合法control与activation以Supervisor actor顺序为线性化点：
   - `suppressForEmergencyStop()` 先取得顺序时，必须在同一个 actor turn、任何
     internal await 前把 `.recoveryReady` 消费为
     `.running + dispatchSuppressed=true + haltCleanupPending=true`，checked 推进
     generation并停掉/撤销所有本地 dispatch ownership；这是 control-only
     conversion，不得开 gate/pump。这样后到 activation 必因 lifecycle gate
     失败，并可原样复用既有
     `didCommitEmergencyPlanningCleanup`/halted resume 路径；
   - shutdown 先取得顺序时从当前非终态 lifecycle直接进入 `.shuttingDown`；
   - 任一 control winner 同时使当前 running-startup first-phase retry
     eligibility、Card-retry eligibility 与当前 attempt transition token全部失效；
     即使 durable halt 持久化失败，后续也不得误走任一 durable-running startup
     retry；
   - activation 先取得顺序时，后到 control 继续沿既有 suppression、durable
     transition 与 bulk cleanup 合同收口，不能让 stale recovery 覆盖 control
     状态；
7. 显式 `resume()` 对 durable-running startup failure 只有两个互斥的
   process-local retry 分支；二者都要求 exact durable mode仍为running、无 control/
   halt cleanup pending，且本次 retry attempt 的 transition token有效：
   - Supervisor第一阶段失败并回到`.initialized`时，只有
     first-phase retry eligibility为true才可由`resume()`重跑完整
     `recoverOnStartup`；legacy repair/interrupted adoption按既有幂等合同执行，
     成功进入`.recoveryReady`后再继续Card recovery；
   - Supervisor已在`.recoveryReady`时，只有Card-retry eligibility为true才走
     R11新增 carve-out，仅重试未完成的 Card adoption、proposal healing 与
     activation，不得重复planning repair/adoption；
   两个分支都不得伪造durable transition。durable-halted startup/cleanup failure或
   任一control已清除eligibility/token时继续走既有control/recovery路径，禁止套用
   durable-running retry；
8. lifecycle仍为`.recoveryReady`且startup eligibility/token仍有效的内部
   activation failure保持错误可观察、suppressed且可重试；已被control改变的
   lifecycle/generation/eligibility/token loser必须保留control-owned state并失败，
   不得还原`.recoveryReady`或再走startup carve-out。当前 post-failure
   re-suppress hook 不作为最终合同。

最小命名测试：

- `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`
- `startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition`
- `explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce`
- `startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent`
- `staleStartupRecoveryCannotActivateAfterConcurrentControlTransition`

其中 recovery-retry event test必须覆盖两个子场景：
`.initialized + first-phase retry eligibility`完整重跑并继续activation，以及
`.recoveryReady + Card-retry eligibility`只重试Card/healing/activation；两者都零
camp halt/resume event。stale-control test必须分别覆盖shutdown清除first-phase
eligibility/token与emergencyStop清除Card eligibility/token。

### R11-3 — `legacy_planning_has_cards` needs an observable typed error

Stage 与 leaf 要求 running legacy Mission 含 Card 时以固定
`legacy_planning_has_cards` fail-closed；但当前 Store 只抛无 payload 的
`InvalidDurableWorkStateError`，测试无法观察固定 code。

R11 必须冻结一个 package typed error：
`LegacyPlanningHasCardsError: Error & Sendable & Equatable`，只有 package
initializer 与固定 `code == "legacy_planning_has_cards"`，不增加 public API、
missionId 或额外 payload；并要求该分支零 DB 写。命名测试必须直接断言 error
type、exact code、Mission/Card/work/event 前后完整 transaction 快照不变。

### R11-4 — unexpected fallback test has no authorized production seam

Stage/Plan 冻结
`unexpectedPlanningFallbackTerminalizesThroughFailureOwner`，但生产 Supervisor
固定调用只能返回 `fallbackReason=nil` 的 durable Planner；真正 failure owner
又是 private，因此现有 API 无法构造该路径。

R11 必须只授权一个 `#if DEBUG package`
`injectOwnedSuccessProposalForTesting(workId:result:)` seam：

- 只接收 `ownedWorkId + PlanResult`，不暴露任意 `PlanningTerminalProposal`、
  token 或 generation；
- entry 不存在/不 owned 时 typed fail-fast；
- 内部读取既有 owned token/generation，并复用生产 provider-completion →
  pending proposal → `attemptPendingTerminalProposal` 路径；
- 仍通过 generation/token/latest-claim gate，不得直接调用 Store、绕过
  transaction、重呼 provider；
- seam 与调用它的 `@Test`/helper 必须放在匹配的 `#if DEBUG` 中。SwiftPM debug
  Core/TestSuite/RunTests 使用同一 package identity并定义 `DEBUG`；release Core
  不得包含该符号，Package/target graph 不变。

命名测试必须证明 unexpected fallback 连同同一个 typed Usage 由 failure owner
deterministic terminalize，且不写 fallback event、不重呼 provider。

## 9. Existing in-scope R10 implementation gaps

下列 `0 P0 / 5 P1` 是现有 A1b allowlist 与已冻结语义内的实现/测试欠账，不需要
R11 扩权，但必须等 Review11 通过后再继续，并在 independent implementation Review
前全部关闭：

1. §12.2 缺
   `claimRevalidatesExactCapturedProfileModelAndCredentials` 与
   `deletedOrUnsupportedCapturedProfileTerminalizesExistingWork`；六个
   `...WithoutWrites` 目前只测 resolver，尚未证明 Mission/work/event 零写；
2. §12.3 缺 negative-first-turn、negative-correction、两组 overflow evidence 与
   unexpected fallback 的精确语义测试；现有 >2^53 与 turn-overflow 测试未覆盖
   冻结事实；
3. §12.4 的 R10 原有三十个 Supervisor/recovery/halt/shutdown 命名测试只存在
   两个；R11-2 另新增五个，当前合计三十五个。现有 shutdown test 还使用真实
   sleep/clock，必须改为可控时间与 latch；
4. `legacy_planning_model_unavailable` 已实现但完全未测；
5. halted startup cleanup 失败后 Supervisor 回到 `.initialized`，现有
   durable-halted `resume()` 不会重新 recovery，形成不可恢复 liveness bug。修复
   必须沿既有“cleanup failure 可观察且可重试”合同，不改变 durable 语义。

两个 P2 强化项同时保留：

- `legacyPlanningRepairUsesExactlyOneDefaultOnly` 的 `>1` corruption fixture 只能在
  test DB 临时删除 `runtime_profile_one_default` partial unique index 后构造；
- 补 `LegacyPlanningTerminalInputV1` invalid version/code codec tests。

## 10. Minimal R11 authority and red lines

R11 planner 只可：

1. 有界修订三份 canonical 文档各自唯一顶部状态行；
   有界修订 canonical Stage §6.3，以及 Stage §6.2 中唯一一处 lifecycle 枚举；
   有界修订总 Plan §3.2/对应 implementation/test gate 与
   A1b leaf §0–§4、§5.5–§5.6、§8.2、§8.5、§9、§10、§11、§12、§15、§16；
   Stage §6.2 只补 `.recoveryReady`，leaf §4 只同步 R11-1 的 `lastFiredAt`
   encoding carve-out；
   §5.5 仅同步 R11-1 已授权的 non-finite pre-guard 顺序，修复其入口总述与
   §10.4 的同根矛盾，不扩大 API、文件或产品语义范围；
2. 纳入 R11-1 至 R11-4 的精确范围、API、测试与 stop conditions；
3. 同步以下两个 P1 execution index、更新三份 canonical hashes：
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` 与
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md`；
4. 写
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`；
   它只记录 planner freeze 证据，不得自称 Review；
5. 由未参与 R11 修订的职责隔离 reviewer 只读复算全部输入，唯一写入
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`。

R11 明确禁止：

- 在 Review11 通过前继续任何产品代码或测试实施；
- 新增 migration/schema/持久 recovery state/`schedule_fire`；
- 改 Schedule claim CAS、有效 finite slot、`lastFiredAt` 或 missed 产品语义；
- 用 post-failure re-suppress、临时 durable halt、bulk cancel或伪造 camp event
  代替两阶段 activation；
- 新增 release-visible test API、第二 planning/Schedule owner、真实 sleep/轮询、
  `try?`、测试放宽；
- 修改 Package.swift、Package.resolved、RunTests，或进入 A1b implementation
  Review、acceptance、A2。
- 修改 master spec、A1a Plan/acceptance/review、旧 R10/R10A freeze evidence、
  Review10/Review10A 报告，或覆盖任何旧 review。

## 11. Pre-R11 read-only boundary review

未参与本次 blocker 修订的只读 reviewer 已交叉核对最新 §8–§10 与 canonical
Stage/总 Plan/leaf、当前 Swift API 和 SwiftPM debug/release 条件：

- 初审：`CHANGES REQUIRED — 0 P0 / 4 P1`；
- blocker 边界按四项 finding 收紧后复审：
  `APPROVED — 0 P0 / 0 P1`；
- 该结论只证明 **R11 授权边界可执行且最小**，不是 R11 freeze、Review11、
  implementation Review 或 acceptance；
- 未取得牧场主明确 R11 授权前，§10 的文档编辑门与全部产品/test gate 继续关闭。

## 12. R11 Candidate freeze

牧场主已于 2026-07-27 明确授权 R11。Planner只在§10 controlling bounded
authority内完成修订并重新冻结：

| 输入 | SHA-256 |
|---|---|
| canonical Stage | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` |
| canonical 总 Plan | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` |
| A1b leaf Plan | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` |
| R11 freeze evidence | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` |

冻结证据：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`

两路预冻结只读 cross-audit 都在上述三份 canonical exact hashes上判定
`APPROVED — 0 P0 / 0 P1`；它们不替代职责隔离 Review11。Review11的唯一写入为
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`。
该报告已对上述 exact hashes 给出 `APPROVED — 0 P0 / 0 P1`，SHA-256 为
`f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671`。
因此 A1b 产品/测试 implementation 与 frozen leaf 要求的验证命令已重新打开；
implementer 只能在 §3 allowlist 和当前 task owner 产物内继续。Review11不替代
implementation Review 或 acceptance；A2、commit、push、merge、release、数据
重置、外部操作与真实用户操作继续关闭。

## 13. Final A1b closeout

本节只追加最终控制事实；§2–§12 的 blocker、R10、Review10/10A、R11 与
Review11 历史全部保持原样，不被本节追溯改写。

### 13.1 Review01 bounded closure

职责隔离 implementation Review01 的首轮历史结论是
`CHANGES REQUIRED — 0 P0 / 2 P1`，首轮 SHA-256 为
`05ac137b93c94e04d51cbd72cf24d047b321a55beaaa24c56dcf16eca563a4a3`。
两个 finding 均在 A1b frozen leaf allowlist 和原合同内按根因有界关闭；首轮原文
与 `0/2` 结论继续保存在同一不可替代报告中。

最终 Review01：

- path：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/reviews/01-p1-a1b-review.md`
- verdict：`APPROVED — 0 P0 / 0 P1`
- SHA-256：
  `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`

### 13.2 Independent acceptance

独立 acceptance owner 在 exact final Review01 与 frozen authority 上逐项核对
A1b leaf §15：

- path：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/acceptance.md`
- status：`ACCEPTED`
- completion gates：22/22 PASS
- SHA-256：
  `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`

该判定关闭 R-01。它不关闭 R-02 或任何后续风险项。

### 13.3 Frozen hash stability and next entry

closeout 后三份 frozen authority 继续保持：

| 输入 | SHA-256 |
|---|---|
| canonical Stage | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` |
| canonical 总 Plan | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` |
| A1b leaf Plan | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` |
| Review11 | `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` |

因此 A1b 状态为 `Accepted`，R-01 为 `Closed`，A2 为
`Entry Open / Not Started`。A2 入口只可由未来一次独立 Codex invocation 使用；
本次 closeout 不创建 A2 leaf、不作 A2 架构或数据决定、不运行 A2 gates、不修改
或授权 A2 产品/测试代码，也不表示 A2 已实施、已验收或获得完整授权。

commit、push、merge、release、数据重置、付款、公开沟通、外部操作和真实用户操作
权限均未扩大。
