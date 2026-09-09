# P1 Stage / Plan Independent Review — Review10

> 日期：2026-07-26
>
> Reviewer：未参与 R10 修订的职责隔离 Review10 reviewer
>
> 审查对象：R10 Candidate Frozen 的 P1 Stage、总 Plan 与 A1b leaf Plan

## 1. Verdict

**CHANGES REQUIRED — 0 P0 / 2 P1.**

Review10 不满足 A1b implementation entry gate。两个 finding 都是冻结合同尚未封口：
一个留下可绕过 durable halt 与 Mission projection 的 public `.planning` 写路径，
另一个使强制的 App 四入口功能测试无法在冻结的 SwiftPM target 图内执行。它们必须
先由 planner 有界修订、补测试门并重新冻结，再由新的职责隔离 review 复核。

本 verdict 不授权产品或测试实现、build、migration matrix、preview、A1b
acceptance、A2、commit、push、merge、release、数据重置、外部操作或真实用户操作。

## 2. Findings

### R10-P1-01 — generic `DurableWorkStore` 仍是未受 gate 的 `.planning` capability

**Severity：P1。对应 closure：R10-6 未闭合。**

冻结合同要求：

- Stage `p1-stage-spec.md:571-577` 把
  `enqueueMissionPlanning(...)` 定义为唯一 public 新开工 command；
- Stage `p1-stage-spec.md:778-784` 要求 ordinary planning
  enqueue/claim/next-due/renew/success/failure/overflow transaction 都验证 durable
  `dispatchMode == running`，halted 下只有 planning-specific single/bulk cancel
  可以写 terminal projection；
- 总 Plan `p1-plan.md:618-646` 删除旧 split planning public paths，并再次声明唯一
  public 新开工 API；
- leaf `plan.md:663-675` 要求 shared durable gate、claim identity 与
  Mission/Squad relation 同事务成立；
- leaf `plan.md:428-434` 又明确 `DurableWorkStore` 只新增
  `work(id:)` public seam，其余 planning primitives 保持 internal。

但 A1a 已冻结并实现的 public surface 精确包含 generic
`enqueue/claimNext/renewLease/complete/retryOrFail/cancel/cancelActive/
adoptInterrupted`（总 Plan `p1-plan.md:229-284`），并且冻结行为只把
`.campDeletion` 设为 reserved capability（`p1-plan.md:303-319`）。

当前源码与该 A1a 合同一致：

- `DurableWorkStore.swift:11-43` 的 public `enqueue` 接受 `.planning`；
- `DurableWorkStore.swift:125-145` 的 public `claimNext` 没有
  `kernel_control` gate；
- `DurableWorkStore.swift:256-345,418-445,545-577` 的 renew、terminal 与 cancel
  只通过 generic/non-deletion guard；
- `DurableWorkStore.swift:939-958` 的 `requireGenericKind` 只拒绝
  `.campDeletion`；
- `DurableWorkTests.swift:87-128,1591-1636` 还把 generic `.planning`
  enqueue/claim/retry 当成 A1a 正常路径。

因此，任何能 import `AgentLoopCore` 的 caller 仍可：

1. generic enqueue 一条 `.planning` work，而不原子创建/验证
   Squad、Mission、identity 与 planning projection；
2. 在 restored halt 后 generic claim、next-due 或 renew；
3. 用 generic complete/retry/cancel closure（包括 no-op closure）绕过
   planning-specific success/failure/cancel projection。

“现有生产入口会改走 specialized command”不是充分反证：旁路本身是 public，
且 candidate 没有 capability ban、访问级别变化、稳定错误或 negative test。
implementer 只能在“保留旁路”和“自行发明 breaking restriction/internal seam”
之间做未规划选择，违反 no-unplanned-decisions。

修订必须逐个冻结 generic `.planning` 在
`enqueue/claimNext/nextClaimableDate/renewLease/complete/retryOrFail/cancel/
cancelActive/adoptInterrupted` 上的 fail-closed 行为、稳定错误和 specialized
internal owner，并增加证明 generic bypass 被拒绝而 planning-specific recovery、
provider path 与显式 cancel 仍可用的 named tests/source sentinels。一个可行方向是
像 `.campDeletion` 一样把 `.planning` 设为 generic write/dispatch reserved kind，
只保留明确允许的 read seam；具体选择属于 planner，而不是 implementer。

### R10-P1-02 — 强制 App 四入口测试在冻结 target 图中不可达

**Severity：P1。对应 closure：R10-1 的可执行验证闭环未闭合。**

leaf：

- 在 `plan.md:92-138` 只允许修改三个 App production files、既有
  `Sources/AgentLoopTestSuite` tests 和两个新 TestSuite files，并明确禁止改
  product target、`Package.swift`、`Package.resolved`；
- 在 `plan.md:1142-1152` 要求迁移 AppStore manual、Coding Ranch
  candidate/proposal 与 MissionScheduler 后运行对应入口 tests；
- 在 `plan.md:1181-1203` 强制命名测试覆盖：
  - manual 在创建 `Task` 前 capture profile/model/key/trace；
  - process-local pending command 的 failure/retry/clear 生命周期；
  - candidate post-enqueue link failure replay；
  - proposal first trace；
  - schedule selection/key/overflow/claim-CAS ordering。

当前 SwiftPM graph 却是：

- `Package.swift:45-49`：`AgentLoopTestSuite` 只依赖 `AgentLoopCore`；
- `Package.swift:51-55`：`AgentLoopApp` 是独立 executable target；
- `Package.swift:56-68`：test target 与 authoritative `RunTests` 也只依赖
  Core + TestSuite，不依赖 App target。

被测行为实际位于不可见的 executable target：

- `AppStore.swift:1468-1516` 的 manual snapshot / `Task` 边界；
- `CodingRanchStoreAdapter.swift:239-272` 的 candidate start→link 两步路径；
- `MissionScheduler.swift:220-255` 的 selection、claim 与 start 顺序。

所以当前允许的新 tests 只能 import public `AgentLoopCore`，不能 instantiate 或
调用上述 App types。把 Core durable command 测透不能功能证明 App callsite 的
capture-before-Task、pending lifecycle、post-link replay 或 schedule ordering。

最强反证是“抽出 public Core helper，在 TestSuite 测 helper，再让 App 委托”；
但 candidate 没有冻结该 helper 的 owner/API、App delegation proof 或允许的新
production path，而且这会扩大 public Core surface。另一条路是修改 Package target
dependency/test access，但 leaf 明确禁止。把 named functional tests 降为同构 Core
tests或源码字符串检查同样没有满足冻结语义。

修订必须选择并冻结一条可执行路径：要么授权并定义可测试的 App target graph，
要么在现有 allowlist 内定义 exact Core coordinator API、要求三个 App callsite
委托，并增加能证明真实 delegation/order 的 gate。对应 Package/visibility/scope
与 fingerprints 必须同步重冻，不能留给 implementer 决策。

## 3. 独立性、范围与方法

Reviewer 未参与 R10 Stage、总 Plan、leaf、`blocked.md`、控制索引或 freeze
evidence 的编写与修订，也没有修复 candidate。唯一 repository 写入是本报告：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10-p1-plan-review.md`

本次是纯静态、只读产品审查。没有运行 `swift run RunTests`、App build、migration
matrix、preview 或任何产品命令；没有修改 source、test、Package、script、冻结文档、
数据库或外部状态。

审查基线：

- branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- 初始 `git status --porcelain=v1 -z` SHA-256：
  `ac72609e44ee52e57c43159977bd218cfc9bce37216eae1cd83bb9cb2347f7b0`
- worktree 已含 P0/P1/A1a 的既存长期差异；本 review 没有接管、回滚或把它们当作
  A1b 验证通过。

## 4. 冻结输入与控制引用

Review 前独立复算：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| frozen Stage `p1-stage-spec.md` | `36420de83e30043665c72d8ad8f0cf6ed98e930df296327c9f2d19bc9a72e62e` | match |
| frozen total Plan `p1-plan.md` | `e89f7e972f665a49f1bd07bd4921ad86e6ce595429344718639ef0688f8b32af` | match |
| A1b leaf `plan.md` | `bb5aa2cd5e7eb7e0cfcbd472b63382d4e5d0a0afd6d4e195737772e82f8c35be` | match |
| A1a `acceptance.md` | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | match |

当前 P1 `stage-spec.md`、P1 `plan.md`、A1b `blocked.md`、A1b leaf 与
`r10-freeze-validation.md` 对 R10 candidate hashes、Review10 pending 状态、
implementation closed gate 的引用一致。A1a acceptance 仍是历史已通过证据，
没有被本 review 当作 A1b 结果。

## 5. R10-1…R10-7 closure 复核

| Blocker | Review10 disposition |
|---|---|
| R10-1 matrix allowlist / entry tests | **未完全关闭**。runner/script 与 named `v12-durable` lane 已冻结，但 App 四入口 mandatory tests 在当前 target graph 不可执行；见 R10-P1-02。 |
| R10-2 key / trace | 文档层面关闭。四入口 key、first trace 与 manual pending lifecycle 已精确定义；其真实验证仍受 R10-P1-02 阻塞。 |
| R10-3 immutable identity / replay | 关闭。canonical identity、replay-first、work graph、first trace 与 resolver-before/after 边界一致。 |
| R10-4 resolver owner | 关闭。唯一 resolver owner、catalog/credential authority、absent-only preflight 与 transaction profile-kind recheck 已冻结。 |
| R10-5 fallback | 关闭。nil 零 event；non-nil success command 零写并由 deterministic failure owner 携同源 usage 收口。 |
| R10-6 Supervisor / halt | **未完全关闭**。specialized Supervisor、restored halt、legacy repair/adoption、late callback、fatal/pending 与 bounded shutdown 合同本身一致；但 public generic `.planning` capability 可绕过这些 shared gates；见 R10-P1-01。 |
| R10-7 usage overflow | 关闭。typed same-origin evidence、negative usage、exact Int64 projection、overflow terminal owner 与 `>2^53` tests 一致。 |

R10 freeze evidence §5 记录的 mode-aware legacy repair 对抗闭包也已静态复核：
transaction 内 mode read 是线性化点；halted workless Mission 使用 attempt=0
queued→cancel atomic control mutation；running commit 与随后 halt bulk cleanup
的 owner/ordering 不矛盾。该 R10-8 候选本身已关闭，不另计 finding。

## 6. API、边界与静态可实施性

除两个 findings 外，以下关键 shape 在冻结文档与当前调用面之间一致：

- `PlanningWorkInput` 固定 profile/model，worker 不回读 current default；
- replay 在 credential/catalog/provider construction 前返回 first IDs/trace；
- Planner 单 provider turn，无 Planner-owned retry/fallback；
- MissionScheduler closure 固定为 throwing `(runtimeProfileId, plannerModel)`，
  selection 在 claim 前 capture，但 failure 仍经过既有 claim/missed owner；
- Candidate 保持 start→link 两步且只靠 deterministic key 修复 link replay；
- proposal 不提前修改 A2/A3 CAS/heal owner；
- success/failure/overflow/cancel/halt 的 planning-specific projection 由同一 SQLite
  transaction owner；
- Supervisor 的 suppressed gate、generation、lease renewal、late result permission、
  restored halt cleanup、resume ordering与 bounded shutdown shape没有显式矛盾；
- legacy repair profile/model snapshot 明确由 App 注入 Core，执行时不动态读默认。

现有 direct production callsites 均位于 frozen production allowlist。没有发现为
迁移 `createMissionShell`、`recordPlanningTokens`、`recordPlanFallback`、
`planMission`、`Orchestrator.startMission` 或 initializer 而必须修改的 allowlist
外 direct caller。也没有发现必须修改 provider conformer、A2/A3 transaction、
schedule CAS、v12 DDL/literal 或新 dependency 的第三个 P0/P1。

## 7. Fingerprints、结构与 hygiene

Review 前逐文件复算的 production/test/test-only/Package hashes与
`r10-freeze-validation.md:92-139` 全部一致：

- 12 个 production entries：10 个 hash match，Supervisor/Resolver 仍 `ABSENT`；
- 17 个既有测试：17/17 hash match；
- 新 `DurablePlanningTests.swift`、`PlanningTestFixtures.swift`：均 `ABSENT`；
- matrix runner、script、`Package.swift`、`Package.resolved`、`RunTests/main.swift`：
  全部 hash match。

为便于复核，按“清单顺序；存在文件为 `shasum -a 256` 输出，不存在为
`ABSENT  path`”拼接后的 manifest hashes为：

| Manifest | SHA-256 |
|---|---|
| production 12 entries | `44f0104b82a23d8b1db7c8110fc340a9b777d104df8e71438b1b3a58711be3f7` |
| existing + new tests 19 entries | `4678484e4a4eaadfaaf60f8d3e721d26e0426499b541cb3533e309865387534c` |
| runner/script/Package/resolved/RunTests 5 entries | `90174bf00f8955f5df387ea35ff3c08f9e726adeade1dfee54109be72eafe65d` |

结构检查：

| 文件 | code fences | balanced | trailing whitespace |
|---|---:|---|---:|
| frozen Stage | 42 | yes | 0 |
| frozen total Plan | 16 | yes | 0 |
| A1b leaf | 32 | yes | 0 |
| A1b `blocked.md` | 0 | yes | 0 |
| R10 freeze evidence | 4 | yes | 0 |

报告写入前 `git diff --check` 通过。最终 hash/status/hygiene 复算见本报告 §9。

## 8. Continue gate

由于存在 2 个 P1：

1. A1b implementation 继续关闭；
2. planner 只能在 R10-1/R10-6 根因范围内修订 generic planning capability 与
   App-entry test architecture；
3. 修订后必须同步 Stage、总 Plan、leaf、`blocked.md`、控制索引、freeze evidence、
   hashes 与受影响 fingerprints；
4. 新 candidate 必须再次经过职责隔离的 independent review，且只有
   `APPROVED — 0 P0 / 0 P1` 才能打开实现。

## 9. 最终复算

报告主体写入后独立复算结果：

- branch/HEAD 仍为
  `codex/personal-ai-ranch-p0` /
  `02334ec8d21533be81d93d39191bc7d9b9c24f7f`；
- Stage、总 Plan、A1b leaf、A1a acceptance 四个 hashes 仍分别为
  `36420de...62e`、`e89f7e...2af`、`bb5aa2...35be`、`070a2b...0032`，
  与 §4 完整值一致；
- production、tests、misc 三个 manifest hashes仍分别为
  `44f010...e3f7`、`467848...534c`、`90174b...65d`，与 §7 完整值一致；
- `git status --porcelain=v1 -z` SHA-256 仍为
  `ac72609e44ee52e57c43159977bd218cfc9bce37216eae1cd83bb9cb2347f7b0`；
  因整个 task tree 在基线即为 untracked parent，porcelain 折叠显示该目录，故本报告
  不改变该 status fingerprint；报告路径已单独确认存在；
- frozen Stage / total Plan / leaf fences仍为 `42/16/32` 且全部成对；
- 本报告 trailing whitespace 为 0；最终 `git diff --check` 通过。

未发现报告以外的 Review10 写入或 candidate/product/test/Package drift。最终
verdict保持：

**CHANGES REQUIRED — 0 P0 / 2 P1.**
