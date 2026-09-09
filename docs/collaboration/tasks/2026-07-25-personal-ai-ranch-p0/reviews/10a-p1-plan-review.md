# P1 Stage / Plan Independent Rereview — Review10A

> 日期：2026-07-26
>
> Reviewer：未参与 Candidate 2 planner 修订的职责隔离 Review10 reviewer
>
> 审查对象：R10 Candidate 2 Frozen 的 P1 Stage、总 Plan 与 A1b leaf Plan

## 1. Verdict

**APPROVED — 0 P0 / 0 P1.**

原 Review10 的两个 P1 均已在其既有 R10-6 / R10-1 根因内闭合：

1. `.planning` 已从九个 generic DurableWork mutation/dispatch API 及同名
   internal helper 封死，同时保留三个 read seam 和唯一 specialized
   provider/recovery/cancel owner；
2. 四入口行为已提取为 Core target 内的 package-only production coordinator，
   现有 `AgentLoopTestSuite` 可直接功能测试同一实现，并以五项 fail-closed
   source-range/order tests验证真实 App 委托；不需要修改 Package 或 RunTests。

本 approval 只打开 Candidate 2 hashes 上的 **P1-A1b implementation gate**。它不
批准 A1b 实现或 acceptance，不打开 A2，也不授权 commit、push、merge、release、
数据重置、外部操作或真实用户操作。

## 2. 独立性、写入边界与方法

Reviewer 未参与 Candidate 2 Stage、总 Plan、leaf、`blocked.md`、控制索引或
`r10a-freeze-validation.md` 的编写与修订，也没有修复 candidate。原 Review10
报告保持不可变。本次唯一 repository 写入是本报告：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10a-p1-plan-review.md`

本次是纯静态审查。没有运行 `swift run RunTests`、App build、migration matrix、
preview 或任何产品命令；没有修改 source、test、Package、script、冻结文档、旧
Review、数据库或外部状态。

审查基线：

- branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- 初始 `git status --porcelain=v1 -z` SHA-256：
  `ac72609e44ee52e57c43159977bd218cfc9bce37216eae1cd83bb9cb2347f7b0`
- 原 Review10 SHA-256：
  `acac1f5b09359f27a095acb12804a58daf6ac3d1250dc5fb7309699cd21851c1`

## 3. 精确冻结输入

Review 前独立复算：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| Candidate 2 Stage `p1-stage-spec.md` | `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6` | match |
| Candidate 2 total Plan `p1-plan.md` | `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61` | match |
| Candidate 2 A1b leaf `plan.md` | `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e` | match |
| A1a `acceptance.md` | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | match |
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` | match |

P1 Stage/Plan 控制索引、A1b `blocked.md`、leaf 与
`r10a-freeze-validation.md` 对 Candidate 2 hashes、rereview pending、implementation
closed 与 A2 closed 的引用一致。原 `reviews/10-p1-plan-review.md` hash未变化。

## 4. R10-P1-01 closure — generic planning capability

### 4.1 九个 API 与错误顺序

Stage `p1-stage-spec.md:550-568`、总 Plan `p1-plan.md:837-851` 与 leaf
`plan.md:456-490` 一致冻结公开空错误
`PlanningRequiresDurablePlanningCapabilityError`，并逐 API 关闭：

| Generic API | Candidate 2 fail-closed order |
|---|---|
| `enqueue` | kind-first；早于 time/JSON/hash/pool/SQL/UUID |
| `claimNext` | 既有 now/lease validation 后，pool/SQL 前整次拒绝 |
| `nextClaimableDate` | now validation 后，pool/read 前整次拒绝 |
| `cancelActive` | kind-first；早于 now/reason/pool/SQL/`noActiveWork` |
| `adoptInterrupted` | now validation 后，pool/SQL 前整次拒绝 |
| `renewLease` | now/lease validation、transaction fetch 后，CAS/update/event 前拒绝 |
| `complete` | now/output validation、fetch 后，CAS/update/event/closure 前拒绝 |
| `retryOrFail` | now validation、fetch 后，state/backoff/CAS/closure 前拒绝 |
| `cancel` | now/reason validation、fetch 后，already-canceled/state/version/closure 前拒绝 |

`claimNext`、`nextClaimableDate`、`adoptInterrupted` 的 mixed-kind contract 也已闭合：
参数 validation 完成后、dedupe 前按 caller 原数组顺序扫描，第一个
`.planning` / `.campDeletion` 决定对应 typed error；不得筛除、排序后继续。

最强反证是“public wrapper 拒绝，但同名 internal helper 仍可旁路”。Candidate 2
明确要求 public 与 internal helper 使用同一 ban，并禁止 specialized commands 调用
generic helper；generic cancel 对 terminal planning 也必须先抛 capability error，
不能走 `alreadyCanceled`。implementer不再需要自行选择访问控制、错误类型或验证
优先级。

### 4.2 Specialized owner、read seam 与恢复/halt

leaf `plan.md:480-487` 与 Stage `p1-stage-spec.md:787-796` 固定：

- `activeWork`、`latestWork`、`work(id:)` 是唯一允许的 planning read seams；
- `DurableWorkStore.swift` 恰有一个
  `fileprivate enum PlanningDurableWorkLedgerOwner`；
- 同文件 AppDatabase specialized extension 是唯一 raw ledger transaction边界；
- Supervisor只能调用 AppDatabase specialized commands 与 Store read seams；
- provider lifecycle、single/bulk cancel、legacy repair和
  `adoptInterruptedPlanning` 全部使用同一 owner。

generic ban 没有破坏 restored-halt recovery：

- leaf `plan.md:955-962` 要求 interrupted adoption只走
  `adoptInterruptedPlanning`，在 local suppressed、无 pump/timer 时执行；
- restored halted 随后由同一 atomic emergency bulk cleanup收口 adopted rows；
- leaf `plan.md:1101-1128` 保持 legacy repair → specialized adoption → durable
  mode read，整个 recovery 期间零 provider dispatch；
- single/bulk cancel仍可在 halted 下执行，而 ordinary provider mutation继续要求
  durable running。

因此原 Review10 指出的 public enqueue/claim/renew/terminal/cancel 绕过已被同一个
sealed owner模型关闭，没有以破坏 recovery 或 halt control为代价。

### 4.3 可执行测试门

总 Plan `p1-plan.md:1117-1126` 与 leaf `plan.md:1452-1461` 要求：

- generic kind APIs pool/SQL 前拒绝；
- 三个 list API 的两种 reserved order与 validation priority；
- target APIs 在 mutation/idempotent branch/closure 前拒绝；
- planning read seams保持；
- specialized provider、adoption与 halted single/bulk cancel正路径。

已有 `AppDatabase.pool` 是 public，测试可 direct-seed planning target rows，而无需
通过已封死的 generic enqueue。A1a generic state-machine fixtures改用普通 kind；
DDL diagnostics与 direct-seeded planning read/negative fixtures保留。

leaf `plan.md:1573-1614` 另提供：

- generic test fixture不得默认 `.planning`；
- specialized API不得变 public；
- unique fileprivate ledger owner必须恰好一个；
- App direct bypass和旧 split API必须零命中。

功能测试被明确设为九 API fail-closed的主证据，sentinel不是替代品。原 P1 所要求的
negative tests、specialized positive tests 与 source boundary全部存在。

## 5. R10-P1-02 closure — App entry test reachability

### 5.1 当前 target 图无需修改

当前 `Package.swift:45-68` 仍是：

- `AgentLoopTestSuite` 依赖 `AgentLoopCore`；
- `AgentLoopApp` 是独立 executable target；
- `AgentLoopCoreTests` 与 `RunTests` 依赖 Core + TestSuite。

Candidate 2 没有再要求 TestSuite import App target。总 Plan
`p1-plan.md:610-748` 与 leaf `plan.md:492-624` 把 immutable DTO 与
`@MainActor package final class PlanningEntryCoordinator` 精确放入已经允许的
`Orchestrator.swift`。每个 DTO stored property与逐字段 initializer都要求
`package`，不是不可跨 module 的 internal synthesized initializer，也不是扩大
外部 API 的 public helper。

这条 target strategy 有当前仓库事实支持：

- `Distiller.swift:116-121` 已存在 package-access `ParsedNote/parseNoteJSON`；
- `DistillerTests.swift:11-44` 已由同一个 `AgentLoopTestSuite` target直接调用；
- `CanonicalJSONTests.swift:18-25` 已使用 `#filePath` 定位并读取真实 Core源码。

所以 package coordinator 与 source-file test均可在现有 authoritative RunTests
图中编译/执行，不需要改 `Package.swift`、`Package.resolved` 或
`Sources/RunTests/main.swift`。

### 5.2 同一 production coordinator 与四入口 owner

leaf `plan.md:1180-1183` 要求 AppStore在 Orchestrator构造后只创建一个 coordinator，
保存 required property，并把同一实例 required-inject 给 MissionScheduler；跨文件
adapter extension使用 AppStore同一 property。Coordinator不持有 AppStore，因而该
共享没有引入反向 App依赖或新的 target cycle。

四入口职责已冻结：

- manual（`plan.md:1197-1217`）：
  Task前同一 MainActor turn捕获完整 snapshot/key/trace；失败保留 pending；成功按
  completed command compare-and-clear，旧 Task迟到不能清新 pending；
- candidate（`plan.md:1219-1228`）：
  第一次 await前捕获 runtime/key/trace；真实
  `MissionDraftFactory.existingMissionId → startMission → linkConverted` 两步全部
  委托 coordinator，link失败后 same key replay原 Mission；
- schedule（`plan.md:1230-1252`）：
  checked milliseconds 与 throwing runtime selection先形成同一 Result，再走既有
  claim；loser零 missed，winner的 selection/start failure恰写一次 missed，且不改
  A4 schema/CAS/`lastFiredAt`；
- proposal（`plan.md:1254-1265`）：
  Task前只读 capture proposal ID/runtime/key/trace；Orchestrator继续拥有
  CAS/attach/revert/heal，并验证 actual proposal ID。

这些依赖都已在 Core：`MissionDraftFactory`、Schedule records/store、
AppDatabase/GRDB 与 Orchestrator。Coordinator不需要修改或 import allowlist外的
App-only类型。

### 5.3 十项功能测试 + 五项真实 App source tests

总 Plan `p1-plan.md:1073-1095` 与 leaf `plan.md:1409-1430` 明确：

- 从 `manualMissionStartCaptures...` 到
  `a1bSchedulePathDoesNotCreate...` 的十项测试直接调用同一个 production package
  coordinator，不是同构 mock；
- 后五项分别验证 manual、candidate、proposal、schedule和全局 direct-start
  零旁路；
- `PlanningTestFixtures.swift` 从 `#filePath` 定位 package root；
- scanner以固定函数签名截取真实 App函数，跳过 Swift注释/字符串并做 balanced
  braces；
- missing、duplicate、unbalanced、parse failure或 token order错误立即失败；
- scanner验证唯一 coordinator call、capture-before-Task/await顺序和 direct call
  零命中，不是简单 substring存在性测试。

leaf `plan.md:1585-1594` 还禁止三个 App文件直接调用
`orchestrator.startMission/confirmSquadProposal`，禁止 MissionScheduler direct
`claimScheduleFire`，禁止 adapter direct `linkConverted`。App build是单独完成门，
因此 source-order tests与编译门共同覆盖“测试真实 Core behavior”和“真实 App委托”
两个证据层。

原 Review10 的最强反证——TestSuite无法触达 App executable behavior——已被
“package production coordinator功能测试 + fail-closed真实 App source-range/order
tests”组合精确消解，没有改 target graph或扩大 public Core surface。

## 6. 授权范围与新风险复核

Candidate 2 的实质修订保持在授权根因内：

- Stage 新合同位于 §6.2.2 generic failure/capability 与 §6.3 planning owner/entry；
- 总 Plan 新合同位于 §3.2 A1b、§10 migration gate与 §11 verification；
- R10-P1-01 是 R10-6 durable Supervisor/halt capability旁路的同根封口；
- R10-P1-02 是 R10-1 可执行 matrix/entry verification的同根测试架构；
- leaf、`blocked.md`、控制索引和 R10A evidence只同步上述执行合同与状态。

没有新增 migration、schema、dependency、target、产品/测试文件、concrete Provider
改造、A3 Candidate transaction或 A4 schedule claim语义。Coordinator是 package
而非 public；新 public error仅用于既有 public generic Store API fail-closed。
`Package.swift`、resolved、RunTests、v12 literal和 A1a acceptance/verdict保持不变。

对 API shape、same-key replay、resolver owner、usage/fallback exactness、
Supervisor pending/fatal ownership、legacy mode linearization、halt/resume、
bounded shutdown、Candidate/proposal/schedule边界再次静态交叉检查，未发现由
Candidate 2 引入的第三个 P0/P1。

## 7. Fingerprints、结构与 hygiene

按不可变 Review10 §7 相同算法独立复算：

| Manifest | SHA-256 | 结果 |
|---|---|---|
| production 12 entries | `44f0104b82a23d8b1db7c8110fc340a9b777d104df8e71438b1b3a58711be3f7` | match |
| existing + new tests 19 entries | `4678484e4a4eaadfaaf60f8d3e721d26e0426499b541cb3533e309865387534c` | match |
| runner/script/Package/resolved/RunTests 5 entries | `90174bf00f8955f5df387ea35ff3c08f9e726adeade1dfee54109be72eafe65d` | match |

Supervisor、Resolver、`DurablePlanningTests.swift` 与
`PlanningTestFixtures.swift` 仍为 `ABSENT`。这证明 Candidate 2 planner修订期间未
提前实施产品或测试。

结构检查：

| 文件 | code fences | balanced | trailing whitespace |
|---|---:|---|---:|
| Candidate 2 Stage | 42 | yes | 0 |
| Candidate 2 total Plan | 16 | yes | 0 |
| Candidate 2 A1b leaf | 34 | yes | 0 |
| R10A freeze evidence | 2 | yes | 0 |
| 原 Review10 | 0 | yes | 0 |

报告写入前 `git diff --check` 通过。

## 8. 非阻塞文档观察

leaf `plan.md:54-57` 把“Candidate 2 hashes已重新冻结”这一已经成立的事实排在
“尚未成立”标题下；同文件下一句、§0 hash控制、三张 hash表、控制索引与 R10A
evidence都明确表明 refreeze 已完成、唯一未成立的是 rereview approval。这是可由
上下文唯一解读的标题归类笔误，不改变任何 API、owner、测试或 implementation gate，
因此不计 P0/P1，也不要求修改本次 frozen candidate。后续获得独立文档修订授权时可
顺手更正。

## 9. Continue gate

Review10A 零 P0/P1 后，下一步只允许：

1. implementer在 leaf §3 allowlist内按 §11 顺序实施 A1b；
2. 先复算 Candidate 2 hashes与进入 fingerprints；
3. 保存 failure-first、authoritative tests、App build、双 SQLite matrix、隔离
   preview、scope/hash与完整日志；
4. 再经过职责隔离 A1b implementation Review 与 independent acceptance。

任何 red/unknown result、allowlist drift、Package/RunTests变化、generic planning
旁路、App direct start/claim、未闭合 recovery/halt或 evidence缺失都立即重新关闭
当前 slice。A1b acceptance前 A2继续关闭。

## 10. 最终复算

报告主体写入后独立复算：

- branch/HEAD仍为
  `codex/personal-ai-ranch-p0` /
  `02334ec8d21533be81d93d39191bc7d9b9c24f7f`；
- Candidate 2 Stage/Plan/leaf与 A1a acceptance hashes仍精确匹配 §3；
- 原 Review10 SHA-256 仍为
  `acac1f5b09359f27a095acb12804a58daf6ac3d1250dc5fb7309699cd21851c1`；
- production/tests/misc manifests仍精确匹配 §7；
- `git status --porcelain=v1 -z` SHA-256 仍为
  `ac72609e44ee52e57c43159977bd218cfc9bce37216eae1cd83bb9cb2347f7b0`。
  整个 task tree在进入时已由 porcelain折叠为 untracked parent，因此新增本报告不
  改变该 fingerprint；报告路径已单独确认存在；
- Stage/Plan/leaf fences仍为 `42/16/34`且成对，三文件和本报告 trailing
  whitespace均为0；
- 最终 `git diff --check` 通过。

没有报告外 Review10A 写入或 frozen/product/test/Package drift。最终 verdict保持：

**APPROVED — 0 P0 / 0 P1.**
