# P1-A1b Independent Implementation Review01

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Reviewer：未参与实现的职责隔离 implementation reviewer

## 1. Scope 与独立性

本 reviewer 未参与 P1-A1b canonical 修订、R11 freeze、产品/测试实现、日志、
preview、matrix 或 implementer report。审查期间 canonical Stage、总 Plan、leaf、
Review11、A1a acceptance、产品、测试、Package、runner/script、控制索引、
`blocked.md` 与全部 implementer evidence 均保持只读；没有运行 App、migration、
测试、build 或其他会写入产品/构建状态的命令。唯一 repository 文件写入是本报告。

本报告是 implementation Review，不是 acceptance。由于存在两个 P1，A1b
acceptance 与 A2 继续关闭。

## 2. 独立复算的 frozen inputs、scope 与 evidence

以下 SHA-256 由本 reviewer 独立复算并与冻结/最终 evidence 逐字匹配：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| canonical Stage | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` | match |
| canonical 总 Plan | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` | match |
| A1b leaf | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` | match |
| R11 freeze evidence | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` | match |
| Review11 | `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` | `APPROVED — 0 P0 / 0 P1` |
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | match |

不可变入口也逐字匹配：

| 文件 | SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

本 reviewer 用 leaf §3 原生 manifest 行重新计算了当前全部 37 项；逐文件 hash
全部匹配 `scope-and-hashes.txt`，aggregate 为：

| Manifest | Entries | SHA-256 |
|---|---:|---|
| production | 13 | `f5dad4a5d4477e757ae4cd019f61151e2449be01e82cba7b3ffbbcc36338f7e8` |
| tests | 19 | `68c2185d483676e571d073ec3f41dcc1a65064260618e98b1d25537c2f7c3291` |
| runner / immutable | 5 | `8addcb922fcb45f2d4e28af2e070df038da3d40bd5c927c70135b0b198df45b5` |

当前 `git status --porcelain=v1 -z` hash 为
`e9ada2c5292cf3be9007967e34283e013ed5fdace29c8e1d160c720001b82c1a`，
匹配最终 scope evidence；`git diff --check`通过。11 个 R11 后 manifest
变化均在 leaf §3，26 项未变。`verify.log`、`build.log`、
`migration-matrix.log`、`preview.log`、`impl-report.md`、preflight、scope、
PNG 与 observation 的当前 hash 也全部匹配 `final-hashes.txt`。

## 3. 原始完成门审计

### 3.1 Tests、build、release 与 source gates

- leaf §12 独立提取为 115 个名称；当前 `AgentLoopTestSuite` 中每个都恰好定义
  一次，无缺失或重名。
- `verify.log` 完整保留 failure-first、R11 red、既有
  `slowActiveStreamDoesNotIdleTimeout` 波动、test-double red 与隔离复跑；
  最后两次完整当前态均为 609/609，通过时间分别为 42.565 秒与 44.100 秒。
- `build.log` 保留首次 zsh `status` 特殊变量失败；随后同一总 Plan Bash gate
  通过，最终 App build 也在 preview Keychain 修订后通过。
- 本 reviewer 独立重跑只读 source/symbol 检查：旧 split planning API、
  `planningTasks`、App direct bypass、public specialized planning API、generic
  planning fixture default、reactive re-suppress均零命中；fileprivate ledger
  owner恰好一个。
- DEBUG seam Core `1/1` guarded、test `3/3` guarded；当前 release Core object
  列表非空，`nm` 中无
  `injectOwnedSuccessProposalForTesting`。

这些证据是真实绿门，但不能覆盖 §5 的两个合同 finding。

### 3.2 SQLite matrix 与 Stage hash同步

`migration-matrix.log` 保留旧 Stage hash被 fail-fast拒绝的第一次运行；修订后
SQLite 3.51 与 3.52 的 linked/literal lanes均为 `matrix.result=pass`，
named `v12-durable` snapshot、double replay、FK、integrity、DDL、append-only
及 56/40/288 diagnostics全部通过。

当前 matrix script 只把
`expected_stage_hash`同步为 Review11 Stage
`add941...`。本 reviewer在内存流中把它替换回 pre-R11 Stage
`d05452...` 后得到
`c085c13c072509f9b0a61c5d386841f70f8cf5b6d8bb5afedc6166f436536f93`，
与 R11 entering script hash精确相等。因此这是 leaf §3.3/Step 9 明确允许的
单行 Stage hash同步，不是 scope扩大。

### 3.3 Preview、Keychain root fix 与 test-double修订

accepted screenshot是可读的真实 1033×732 PNG，hash
`087eca5b5cb3ad8d5c9c7a02f5beb834e18e5aa3c626495662c7503202b3bceb`；
显示 `Coding 牧场`、`我的营地`、`营地管家，空闲` 与 `发起放牛`。日志保存了
fresh absolute DB root、进程环境、normal App Support open-file count为零、
主线程正常 event loop、标准 quit event 与进程退出。

首次 preview 的 OAuth Keychain main-thread block被真实采样；最终
`AppStore.swift` 对两个 OAuth presence read增加与既有 API/search read一致的
preview short-circuit，并把 preview OAuth session置空。该修改位于 leaf允许的
`AppStore.swift`，根因与重跑证据成立。

`terminalWaiterReturnsAfterDurableCancelWhileIdleWaitsForProviderExit` 的 test
double修订位于允许的 `CrashRecoveryTests.swift`。当前
`RecoveryIgnoringCancellationPlanningProvider.streamTurn`在返回 stream 前阻塞
Supervisor-owned provider Task本身，取消不会只终止一个 detached producer；
这是对 frozen cancellation-ignoring场景的同步修复，没有放宽 production
assertion。隔离复跑及之后两次全量绿门均已保留。

## 4. R11 四项合同

### R11-1 — Schedule numeric + non-finite preguard

通过。

- `ScheduleRecord`只对`lastFiredAt`使用`.timeIntervalSince1970`编码，其他
  Date保持`.deferredToDate`；decoder仍统一`.deferredToDate`。
- 三个真实 Schedule test覆盖 extreme finite INTEGER/REAL、legacy TEXT、新旧
  decode、exact reload/dedupe 与其他 Date继续TEXT。
- coordinator在构造 preparation、UUID、调用`selectRuntime`和claim前先检查
  `scheduledFireDate.timeIntervalSince1970.isFinite`；non-finite直接抛 exact
  typed error。finite checked-ms failure仍进入 preparation Result，claim winner
  后只写一次 missed，CAS/schema未变。

### R11-2 — running two-phase recovery / retry / control linearization

除 §5.2 的 wait-idle独立合同外，R11 startup/control合同通过。

- Supervisor从 suppressed `.initialized`进入`.recovering`；durable running
  只到 process-local `.recoveryReady + suppressed`，零 pump/timer/claim/provider。
- Orchestrator在 planning first phase之后完成 Card adoption、post-adoption gate、
  proposal healing、transition-token复验与 exact durable mode read；唯一
  `activateAfterOrchestratorRecovery()`再在 Supervisor actor内验证 lifecycle、
  suppression、fatal、halt cleanup与 durable running，才打开 gate并kick。
- first-phase与Card-only eligibility是两个互斥 Bool；失败重试按当前 lifecycle
  分流，production无` suppressForOrchestratorRecoveryFailure`。
- emergencyStop可消费`.recoveryReady`，shutdown可从四个 pre-shutdown状态进入；
  control清 eligibility/token，late activation/provider均由
  lifecycle/generation/token/CAS挡住。
- frozen R11 tests覆盖 first-phase完整重跑、Card-only重试、零伪造camp event、
  shutdown清first-phase token及emergencyStop清Card token。

### R11-3 — exact `LegacyPlanningHasCardsError` zero-write

通过。源码 exact type为
`package struct LegacyPlanningHasCardsError: Error, Sendable, Equatable`，只含
固定 package `code`与空 package initializer。running legacy Mission有Card时，
检查发生在该 Mission transaction任何insert前；测试直接比较
Mission/Card/planning-work/event完整快照、exact reflected type与code。

### R11-4 — matching DEBUG seam复用生产 failure owner

通过。唯一 DEBUG package seam只接收owned work ID与`PlanResult`，从owned entry
读取token/generation并调用与真实 provider completion相同的
`acceptProviderProposal → pendingTerminalProposal →
attemptPendingTerminalProposal`。unknown/unowned、late terminal、provider
重呼、resolver重调与generation/CAS均有断言；unexpected fallback转换为同源
deterministic failure且零Card/fallback/completed event。release无该符号。

## 5. Findings

### P1-1 — required preview实际写入共享 UserDefaults，违反 frozen red line

**证据**

- leaf §4.13 明确写明“不修改、打印或测试真实 Keychain/UserDefaults”
  （`plan.md:204`），完成门又要求isolated preview全绿。
- accepted preview只传入新的`AGENTLOOP_STATE_DIR`与
  `AGENTLOOP_UI_PREVIEW=1`（`preview.log:72-86`）。observation自己明确承认
  shared UserDefaults domain未隔离，且不主张零读写
  （`preview-observation.md:60-68`）。
- 这不是抽象“可能写”。`AppStore.init`在preview分支前无条件执行
  `UserDefaults.standard.set(..., forKey:"apiAuthScheme")`
  （`AppStore.swift:420-446`）。
- 同一个fresh preview DB随后用`ProfileScopedDefaults()`的默认
  `UserDefaults.standard`构造`RuntimeProfileBootstrap`
  （`AppStore.swift:446-470`）。fresh DB必定seed一个新profile；bootstrap随后
  必调`copyLegacyModelDefaults`（`RuntimeProfileBootstrap.swift:45-65`），而
  `ProfileScopedDefaults`对该新profile的四个missing keys执行真实`set`
  （`ProfileScopedDefaults.swift:110-148`）。

因此“没有通过UI故意改 preference”不能满足 red line；accepted preview已沿确定
调用链写入正常共享 defaults domain，并可能给每个临时 profile留下孤儿 keys。
normal App Support open-file count为零也不能证明 UserDefaults隔离。

**必须修复**

修复严格限于 leaf §3：只可改允许的`AppStore.swift`及允许的测试/evidence。
UI preview必须把启动路径中 AppStore直接 defaults访问、传给
`ProfileScopedDefaults`/bootstrap的defaults，以及reload所达的defaults统一路由到
与正常用户domain隔离的preview store；normal运行继续使用现有standard domain。
不得修改 allowlist外的`RuntimeProfileBootstrap.swift`、
`ProfileScopedDefaults.swift`或`run-app.sh`。如果无法在该边界内做到，必须停止并
请求新的有界计划授权，不得用observation免责声明放宽合同。

**必需 regression / 重跑**

1. 在允许测试文件加入 deterministic regression/source-order gate，证明preview
   路径不会调用normal-domain write，并证明fresh profile bootstrap接收isolated
   preview defaults；测试不得读取、打印或diff真实用户defaults。
2. 重新用全新DB root和全新隔离defaults root/domain运行
   `scripts/run-app.sh --preview`，证据必须记录两类隔离边界、可见状态、截图与退出，
   且不得检查或输出normal defaults内容。
3. 重跑`swift run RunTests`、最终App build、source/hash/scope gates并更新全部
   implementer logs/report/hashes；旧失败证据继续保留。

### P1-2 — suppressed Supervisor无条件报告idle，跳过当前 queued/due work

**证据**

- leaf §9.5 的 exact合同是
  `waitUntilIdle()`等待owned Tasks为空且“当前queued/due work为零”，只允许
  future `retryScheduled`不阻塞（`plan.md:1328-1334`）。
- 当前`isIdleNow()`在owned为空、pump为空且无halt cleanup后，只要
  `dispatchSuppressed`就直接返回true
  （`DurableWorkSupervisor.swift:1864-1873`），完全不查询当前queued/due
  planning。
- running startup first phase完成后会合法处于
  `.recoveryReady + suppressed`，此时DB可以有当前queued planning等待Card
  recovery/activation。调用`waitUntilIdle()`会假完成，即使当前工作并非future
  retry。
- frozen named test
  `waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot`
  先完成activation再验证future retry
  （`CrashRecoveryTests.swift:842-889`），没有覆盖
  `.recoveryReady + suppressed + due queued`，因此609/609不能关闭此合同缺口。

**必须修复**

修复严格限于允许的
`Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`与允许测试文件。
`dispatchSuppressed`不得成为blanket idle shortcut：

- `.recoveryReady + durable running`必须仍区分current queued/due与future retry；
- restored halted且atomic cleanup已完成时仍可正确成为idle；
- halt cleanup pending、owned provider、pump及fatal/read failure现有语义不得
  放宽，也不得新增polling、sleep或第二ledger owner。

**必需 regression / 重跑**

1. 在允许的`CrashRecoveryTests.swift`加入deterministic actor-continuation
   regression：Supervisor完成running first phase但尚未activation且存在due queued
   planning时，`waitUntilIdle`不得完成；activation并terminalize后才完成。
2. 同一回归组继续证明future retry不阻塞，并证明restored-halted完成atomic cleanup
   后不会被错误挂住或latch fatal；不得使用真实sleep/polling。
3. 重跑该组targeted tests、完整`swift run RunTests`、App/release build、
   DEBUG release-symbol gate、全部source gates、SQLite matrix、isolated preview、
   `git diff --check`与37-entry manifests；更新完整日志、scope、impl-report及final
   hashes后再做新的职责隔离implementation Review。

## 6. Findings summary 与 verdict

- P0：0。
- P1：2。
- A1b acceptance：继续关闭。
- A2：继续关闭。

CHANGES REQUIRED — 0 P0 / 2 P1

## 7. Independent re-review — Review01 bounded repairs

> 日期：2026-07-27
>
> Re-reviewer：原职责隔离 implementation reviewer
>
> 初始 Review01 SHA-256：
> `05ac137b93c94e04d51cbd72cf24d047b321a55beaaa24c56dcf16eca563a4a3`

### 7.1 独立性与判定边界

本节保留前述初始 Review01 原文与 `0 P0 / 2 P1` 历史结论，只对当前精确源码和
implementer 在该结论后的有界修复作独立复审。re-reviewer 未参与四个修复文件、
日志、evidence 或 implementer report 的写入；本轮唯一 repository 文件写入仍是
本 Review01。未修改产品、测试、Plan、日志、evidence、`acceptance.md`、控制索引
或 Git 状态，亦未 commit。

独立复跑没有重定向或追加到 implementer-owned 日志。当前 `.build` 中执行了
focused/full tests、App build、release Core build 与 release object `nm`；
SQLite matrix 与 App preview 不重跑，以免改写 owner evidence或重新操作产品
进程。二者改由本 reviewer 对完整原始日志、当前输入 hash、截图格式/像素和源码
边界逐项复核。初始 finding 之后的产品/测试修复精确限于：

- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopTestSuite/CrashRecoveryTests.swift`
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`

四项都在 leaf §3 allowlist。用初始 Review01 时保存的四个旧 file hash替换当前
manifest对应行，独立重建得到 production
`f5dad4a5d4477e757ae4cd019f61151e2449be01e82cba7b3ffbbcc36338f7e8`
与 tests
`68c2185d483676e571d073ec3f41dcc1a65064260618e98b1d25537c2f7c3291`，
精确等于初始 Review01 记录的两个 aggregate；runner/immutable 前后均为
`8addcb922fcb45f2d4e28af2e070df038da3d40bd5c927c70135b0b198df45b5`。
因此 Review01 后可归属的 byte delta 确为上述四文件，没有 out-of-allowlist
repair change。

### 7.2 Frozen authority、当前 Git 与 manifest

本 reviewer 再次从当前文件独立复算：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| canonical Stage | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` | match |
| canonical 总 Plan | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` | match |
| A1b leaf | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` | match |
| R11 freeze evidence | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` | match |
| Review11 | `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` | `APPROVED — 0 P0 / 0 P1` |
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | match |

当前 branch 为 `codex/personal-ai-ranch-p0`，HEAD 为
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。写本节前
`git status --porcelain=v1 -z` SHA-256 为
`e9ada2c5292cf3be9007967e34283e013ed5fdace29c8e1d160c720001b82c1a`，
与最终 scope evidence一致；`git diff --check`通过。

按 leaf §3 顺序用原生 `shasum -a 256` 行独立复算当前全部 37 项；每个逐文件
hash均匹配 `evidence/scope-and-hashes.txt`：

| Manifest | Entries | 独立复算 SHA-256 |
|---|---:|---|
| production | 13 | `c311118ebf9f8ae5f999e4b7e46b353f2377aef7f8e66873152de36c0e708562` |
| tests | 19 | `3142499b7e1ce6bb48f8f5cdb135dce2658dcb51b30c7b67d7e5c673cf2139b2` |
| runner / immutable | 5 | `8addcb922fcb45f2d4e28af2e070df038da3d40bd5c927c70135b0b198df45b5` |

`Package.swift`、`Package.resolved` 与 `Sources/RunTests/main.swift` 仍分别为
`577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d`、
`d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`
与
`70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`。

### 7.3 Finding disposition

#### P1-1 — preview shared UserDefaults：已关闭

当前 `AppStore.swift` SHA-256 为
`2eb60d210bfc6d59c60afa4a2b272811af9b5b4ab8e674ceea397687799adf33`。
根因修复在任何 AppStore defaults读写前先执行
`let appDefaults = Self.makeUserDefaults()` 并保存为 required
`userDefaults`：

- normal mode仍返回 `.standard`；
- `AGENTLOOP_UI_PREVIEW=1` 返回 unique PID + UUID suite的
  `ProcessLocalPreviewUserDefaults`；
- 当前 AppStore/Core 实际使用的 `object/set/remove/string/integer/bool/
  stringArray` surface全部覆写到同一 `NSLock` 保护的进程内 dictionary，类内没有
  `super.`或 normal-domain调用；
- 同一个 `appDefaults` 在首次 direct `string/set`、fresh-profile
  `RuntimeProfileBootstrap`之前就注入 `ProfileScopedDefaults`，并继续流向
  resolver、scheduler、reload、catalog、persistence与 OAuth state；
- AppStore生产源码无 `UserDefaults.standard`、
  zero-argument `ProfileScopedDefaults()`或`ModelCatalogService()`旁路。

新增 regression
`uiPreviewUsesProcessLocalDefaultsBeforeBootstrapAndReload` 位于允许的
`DurablePlanningTests.swift`，使用真实 AppStore source-range parser验证上述构造、
注入和 reload/catalog路径；它不读取、打印、导出或 diff normal defaults内容。
本 reviewer独立运行包含该测试的 focused gate为 5/5，通过；当前全量复跑也通过。
该实现关闭了初始 finding 指出的确定性 normal-domain bootstrap写，不以
observation免责声明代替修复。

accepted preview原始证据也与当前源码一致：

- fresh root：
  `/private/tmp/agentloop-a1b-review01-preview.sy7T0L`
- PID：`51258`
- exact env：`AGENTLOOP_UI_PREVIEW=1`及上述
  `AGENTLOOP_STATE_DIR`
- isolated DB/WAL/SHM/lock全部在fresh root，normal App Support open count为0
- 可见 `Coding 牧场`、`我的营地`、`基础牛，空闲`、`发起放牛…`与无模型说明，
  无blocking credential/error prompt
- main thread位于正常`NSApplication` event loop，无`SecItemCopyMatching`
- 截图是独立验证的true RGB PNG，1190×732，SHA-256
  `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8`
- Command-Q 后 PID退出，shell-only检查无剩余 AgentLoop进程，未再运行post-quit
  UI probe

#### P1-2 — suppressed idle shortcut：已关闭

当前 `DurableWorkSupervisor.swift` SHA-256 为
`e1991b398299898f5582e0826efa345bac501afd998e2f695af6e81ef539aa79`。
`isIdleNow()` 现在按冻结合同依次要求：

1. `owned.isEmpty`、`pumpTask == nil`且`haltCleanupPending == false`；
2. lifecycle为`.recoveryReady|.running`；
3. 只有`dispatchSuppressed`且durable mode精确为`.halted`才直接idle；
4. 其余情况读取当前`now`与specialized
   `nextClaimablePlanningDate(now:)`；nil或future retry为idle，当前queued/due
   返回non-idle。

因此`.recoveryReady + suppressed + durable running`不再被blanket shortcut
吞掉；missing/corrupt/read failure仍通过`wakeIdleWaitersIfPossible`的既有
`latchReadFailure` fail-closed。restored halted只有在atomic cleanup完成、owned/
pump/cleanup全部为空后才走halted direct-idle。

新增
`suppressedWaitUntilIdleDistinguishesDueFutureRetryAndHaltedCleanup`
用actor continuation与受控clock/provider覆盖三个确定性子场景：

- running first phase完成但未activation且有due queued work时，先观察ledger read，
  waiter不完成；activation后provider仍owned时也不完成，terminal后才完成；
- suppressed durable-running future retry立即idle，不建timer、不调provider；
- restored halted完成atomic cleanup后idle，work为canceled，无timer/provider。

本 reviewer独立 focused复跑同时覆盖既有future-retry、running-startup与halted
startup邻接测试，5/5通过；全量复跑中该regression亦通过。初始P1-2已按根因关闭，
没有polling、sleep或第二ledger owner。

### 7.4 Tests、build、source 与 matrix gates

本 reviewer在当前精确源码上独立执行：

- `swift run RunTests --filter
  'uiPreviewUsesProcessLocalDefaultsBeforeBootstrapAndReload|
  suppressedWaitUntilIdleDistinguishesDueFutureRetryAndHaltedCleanup|
  waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot|
  runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes|
  haltedStartupRunsCleanupWithoutPumpTimerOrProvider'`
  → 5/5，0 issue；
- `swift run RunTests`
  → 611 tests / 5 suites，42.810秒，0 issue；
- `swift build --product AgentLoopApp`
  → pass；
- `swift build -c release --product AgentLoopCore`
  → pass；
- total Plan source gates、review新增preview-defaults bypass gate与
  `git diff --check`
  → 全部pass。

leaf §12测试名由当前冻结leaf独立提取为
`115 required / 115 unique / 115 exact_once / bad=0`。matching DEBUG gate为
Core `1/1`、`DurablePlanningTests.swift + PlanningTestFixtures.swift`
`3/3`；把其他允许测试文件也纳入时全部TestSuite引用为`5/5` guarded。当前release
Core的86个object由`nm`独立检查，无
`injectOwnedSuccessProposalForTesting`符号。

保存的 `verify.log` 当前 SHA-256 为
`7c1f54412ae2de8009ad305f2a238555076bea4c62684ad1fad7d355c192b43e`；
其最后exact-source full run为611/611，且保留focused 5/5、115/115与source gates。
`build.log` SHA-256
`6d81f9dc894443203bb5a4e2c3e13346babfd8f7aa30727270a4e320256075dd`
保留早期zsh readonly `status` wrapper失败；随后相同Bash gate及Review01后
App/release build、DEBUG counts与release symbol检查均通过。该历史wrapper错误没有
被删掉或冒充通过。

`migration-matrix.log` SHA-256 为
`ffcf40be8b243a6c0ac877e22af4f838ec48bce3a4877247e8133c5e3bdae63f`。
完整原始日志先保留旧Stage hash的fail-fast，随后至少一整轮当前hash上的
SQLite 3.51.0 + 3.52.0 linked/literal运行均以
`p1_migration_matrix.result=pass`收口。每条linked lane包含
`v12-durable` snapshot/double-replay、replay、FK、integrity、DDL、
append-only，real/literal diagnostics精确为56/40/288，sentinel 0/7、
control 19/0；负例SQLite错误保留且各lane最终`matrix.result=pass`。
当前Stage、script、runner、AppDatabase与Package.resolved hashes逐字匹配该通过
运行输入。Review01四文件修复没有触及matrix owner。

### 7.5 Preview deviation disposition

首个Review01修复preview PID `50856`的隔离、UI、截图与退出本来通过；但退出后的
Computer Use app-state调用自动启动了无两项preview env的normal PID `51012`。
本 reviewer不把该过程解释为“零normal-domain访问”：既然normal AppStore可访问
normal preference domain，而没有检查normal contents，就不能证明该短进程没有
到达任何normal初始化。正确处置是：

- PID `51012`由exact PID立即终止且已退出；
- 没有读取、打印或保存defaults/Keychain内容；
- 该次run整体明确rejected，不能支持preview gate；
- 后续accepted retry从无AgentLoop进程开始，使用新fresh root与preview env；
- accepted retry退出后只做shell process检查，不再调用会自动拉起App的UI工具。

这是被完整保留、未掩盖且未污染accepted retry的历史自动化偏差，不是当前源码
root cause，也不使accepted preview、当前hash或当前tests失真。没有持续进程、
秘密泄漏、未解释产品改动或需靠该run成立的完成门；因此本偏差不留下P0/P1。
独立acceptance仍可记录它，但不得把rejected run重新算作绿证据。

### 7.6 Final hash inputs、findings 与 verdict

本 reviewer独立复算的implementer-owned final inputs为：

| Artifact | SHA-256 |
|---|---|
| `verify.log` | `7c1f54412ae2de8009ad305f2a238555076bea4c62684ad1fad7d355c192b43e` |
| `build.log` | `6d81f9dc894443203bb5a4e2c3e13346babfd8f7aa30727270a4e320256075dd` |
| `migration-matrix.log` | `ffcf40be8b243a6c0ac877e22af4f838ec48bce3a4877247e8133c5e3bdae63f` |
| `preview.log` | `044e0658f88bfd0ce9989cd4c666f6101e291ed78aca18597dec053b5645974e` |
| `impl-report.md` | `b2b8d45d54fcda80ec1fcb298166742d82262bede853a81ce57816c2751f8293` |
| `evidence/preflight.txt` | `da37444e1326c3f0b86b2d01742585bab177fa0e21ff7c778ef3ff7875d2bc37` |
| `evidence/scope-and-hashes.txt` | `9d4a65dbb290f974a5f68404c4ba7d2a33335657476ef241f968adf2824ecf4d` |
| `evidence/preview-observation.md` | `8f672debd80319c6a8c5e53f5103da96f73bb3188e27877ceb72e1efe49f1c55` |
| `evidence/preview-smoke.png` | `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8` |
| `evidence/final-hashes.txt` | `a8a231f4bfe177ea881ab596cb222f0a906557077c2cb7f513186f116f1298e7` |

`evidence/final-hashes.txt`由implementer拥有，按职责隔离只记录初始Review01
`05ac137...`，明确不自含自身hash，也不能预写本最终re-review hash；该边界正确，
本节没有反向修改implementer evidence。

- P0：0。
- P1：0；初始P1-1与P1-2均已关闭。
- A1b acceptance：尚未执行，本Review只打开独立acceptance。
- A2：继续关闭，只有independent acceptance为`ACCEPTED`后才可打开。

APPROVED — 0 P0 / 0 P1
