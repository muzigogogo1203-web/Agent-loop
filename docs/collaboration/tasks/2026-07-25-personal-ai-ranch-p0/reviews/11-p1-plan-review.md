# Review11 — P1-A1b R11 Candidate Independent Plan Review

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Reviewer：职责隔离的独立 Review11 reviewer

## 1. Scope 与独立性

本 reviewer 未参与 R11 canonical 修订、freeze evidence 写入或预冻结
cross-audit。审查只针对本报告记录的 exact frozen inputs；唯一写入是本文件。
canonical Stage/总 Plan/leaf、两个 P1 execution index、blocker、freeze evidence、
产品、测试、Package、runner/script 与 implementation evidence 全部保持只读。

这是 plan review，不是 implementation Review 或 acceptance。当前 worktree 含有
R10/A1b 已存在的产品与测试修改，因此本报告不把 dirty worktree 误报为干净；零漂移
结论只来自冻结清单的逐文件复算。

## 2. Frozen inputs

以下 SHA-256 均由本 reviewer 独立复算，actual 与 expected 逐字一致：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| canonical Stage `p1-stage-spec.md` | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` | match |
| canonical 总 Plan `p1-plan.md` | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` | match |
| A1b leaf `plan.md` | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` | match |
| R11 freeze evidence | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` | match |
| A1b `blocked.md` | `57c13db969ba133dd0d387a88239aa72c2664572edf6f375f27c5eb86cad8cac` | match |

三份 canonical 文档均未嵌入自己的当前 hash。顶部状态均为 R11 Candidate
Frozen / Review11 Pending，且 Open Questions 精确为空。

两个 P1 execution index 也由本 reviewer 独立复算并核对内容：

| Index | SHA-256 | 内容核对 |
|---|---|---|
| `personal-ai-ranch-p1/stage-spec.md` | `31fe46538f49bd2539c2d510bd3796bdbc58d8b7a72422fc9e1eafbd5a06c647` | 指向三份正确 canonical hashes；Review11 Pending；A2 Closed |
| `personal-ai-ranch-p1/plan.md` | `845586c56fe22e60b4924217dd10894acc928723072ba5331bf286fa67212105` | 指向三份正确 canonical hashes；implementation gate关闭；Review10A仅为历史 predecessor |

## 3. Product/test freeze manifests

本 reviewer 按 leaf §3 的显式数组顺序，用原生 `shasum -a 256` 行并保留最终
换行，独立重算所有 37 个逐文件指纹及三个 aggregate。每个逐文件 hash 均与
freeze evidence §5.1–§5.3 一致：

| Manifest | Entries | Recomputed SHA-256 | 结果 |
|---|---:|---|---|
| production | 13 | `b7ddddadd04a68f676b125605c04d91cb6adee5f9c50835689cba58ccec90aab` | exact match |
| existing + new tests | 19 | `03da4e7bfbe18cf64148af879baf6df39662b8ee86c79a6f3f8341331c02abd0` | exact match |
| runner/script/Package/resolved/RunTests | 5 | `b2e07ddf612913a78c132cbf51350d49cb62eb51ba3207a0a2bd539423156b53` | exact match |

不可变指纹也逐字一致：

| 文件 | SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

写本报告前的
`git status --porcelain=v1 -z` SHA-256 为
`57d5d99e31248fa05093e6702129c6df8e02dcd4ae20168a72974d854faa1910`，
与 freeze evidence 一致。由此确认 R11 planning/freeze 期间没有产品、测试、
runner/script、Package 或 RunTests 漂移。

## 4. R11 root-cause audit

### R11-1 — Schedule extreme finite Date persistence

通过。三份 canonical 文档一致冻结：

- production allowlist 只新增既有 `ScheduleStore.swift`；
- `ScheduleRecord.databaseDateEncodingStrategy(for:)` 只把 `lastFiredAt` 编码为
  `.timeIntervalSince1970` numeric/Double；其他 Date 继续
  `.deferredToDate`；
- decoder 保持 `.deferredToDate`，兼容 legacy TEXT 与新 numeric epoch
  seconds；
- `lastFiredAt` storage class 接受 INTEGER/REAL，拒绝 TEXT/空串，不错误固定
  `typeof=REAL`；
- non-finite fire date 在 UUID、runtime selection、preparation Result 与 claim
  之前 typed fail-fast，selection count为零且完整零写；
- finite checked-milliseconds overflow 仍走现有
  `Result.failure → claim → missed`；
- schema、有效 finite slot、claim CAS、逻辑 `lastFiredAt` 值与 missed 语义均
  不变，ScheduleStore 不成为第二个 checked/claim owner。

对当前 GRDB 7 source 的只读核对确认 `.deferredToDate` decoder 本身同时支持
numeric epoch seconds 与既有日期 TEXT，计划所选 owner 与编码/解码边界可实现。

### R11-2 — Startup recovery two-phase activation

通过。计划不再依赖失败后的 reactive re-suppress，而是冻结了完整根因修复：

- Supervisor 初始化即 `dispatchSuppressed=true`，并新增仅 process-local 的
  `.recoveryReady`；
- `recoverOnStartup` 只完成 legacy repair、interrupted planning adoption 与
  exact durable-mode read；durable running 只进入
  `.recoveryReady + suppressed`，零 pump/timer/claim/resolver/provider；
- Orchestrator 完成 Card orphan adoption 与 proposal healing并在 activation
  前后重验 transition token；
- 唯一 internal `activateAfterOrchestratorRecovery()` 在 Supervisor actor 内重验
  lifecycle、suppression、fatal、halt cleanup、generation/control条件及 exact
  durable running DB fence，随后在无 suspension 的同一线性化段打开 gate并只
  kick一次；
- `emergencyStop` 先赢时在同一 actor turn把 `.recoveryReady` 消费为
  `.running + suppressed + haltCleanupPending`，不打开 gate；shutdown可从
  `.initialized|.recovering|.recoveryReady|.running` 收口；
- control winner 清除两类 eligibility 与当前 attempt token；activation先赢时，
  后到 control 仍走既有 suppression、durable transition 与 bulk cleanup；
- durable-running startup retry只有两个互斥分支：
  1. `.initialized + first-phase retry eligibility` 重跑完整 Supervisor recovery，
     然后继续 Card recovery；
  2. `.recoveryReady + Card-retry eligibility` 只重试
     Card adoption/healing/activation，不重复 planning repair/adoption；
- 两路均要求 exact durable running、无 control/halt cleanup pending、当前
  transition token有效；durable halted或已被 control清除的状态不得借用 carve-out；
- `suppressForOrchestratorRecoveryFailure` 明确要求从最终生产路径删除。

该合同给出了 Card recovery failure、activation内部失败、stale retry、halt持久化
失败和 shutdown/emergencyStop 竞态的 owner、可重试证据与失败状态，没有留下
dispatch窗口或用临时 durable transition掩盖问题。

### R11-3 — Typed legacy-with-Cards failure

通过。exact type冻结为
`package struct LegacyPlanningHasCardsError: Error, Sendable, Equatable`，只含
`package let code = "legacy_planning_has_cards"` 与 `package init() {}`；没有
public API、missionId或额外 payload。running legacy Mission含 Card时必须直接抛
该 typed error，并以 Mission/Card/work/event 完整 transaction snapshot证明零写。

### R11-4 — Narrow DEBUG unexpected-fallback seam

通过。唯一授权 seam 为 matching-`#if DEBUG package`
`injectOwnedSuccessProposalForTesting(workId:result:)`：

- 只接收 owned work ID 与 `PlanResult`；
- nonexistent/unowned entry typed fail-fast；
- token/generation 从既有 owned entry读取；
- 复用生产 provider-completion → pending proposal →
  `attemptPendingTerminalProposal` → failure owner路径；
- 继续经过 generation/token/latest-claim gates，不直调 Store、不重呼 provider；
- 调用方测试/helper同样受 matching `#if DEBUG` 保护；
- release Core symbol absence是硬门，Package/target graph不变。

## 5. Cross-document consistency 与 same-root fixes

通过：

- Stage §6.2 lifecycle枚举、Stage §6.3、总 Plan §3.2与A1b leaf
  §4/§5.5–§5.6/§8.2/§8.5/§9–§12/§15–§16 对四个R11根因一致；
- Stage、总 Plan、leaf 的11个R11最小命名测试完全相同，且每个名字在每份
  canonical文档中恰好出现一次；
- recovery-retry event test明确含first-phase完整重跑与Card-only重试两个子场景；
  stale-control test明确覆盖shutdown清first-phase token和emergencyStop清Card
  token；
- 总 Plan与leaf allowlist精确一致：13个production、19个test、2个
  runner/script；`Package.swift`、`Package.resolved`、`RunTests`不在可改范围；
- Stage/总 Plan/leaf Markdown fences分别为42/18/36，均为偶数；三文件
  trailing whitespace与CR计数均为0；
- 总 Plan §11提取的Bash代码通过`bash -n`；可执行gate均有
  `set -euo pipefail`，`assert_rg_absent`区分status 1与真实`rg`错误，
  release object list要求非空，`nm`失败显式传播，release symbol search也只把
  status 1视为no-match；
- 总 Plan §11没有`|| true`。leaf §14含`|| true`的旧块被明确标记为
  non-executable inventory，并由总 Plan §11声明为唯一可执行source gate；
- Review11只重新打开A1b implementation，不替代implementation Review或
  acceptance；A2、commit、push、merge、release、外部操作与真实用户动作仍关闭；
- R11不授权migration/schema、持久recovery state、`schedule_fire`、claim CAS/
  valid-slot/missed语义、release-visible test API、第二owner、真实sleep/polling、
  `try?`、Package或target graph变化。

## 6. Commands deliberately not run

遵守 Review11 freeze gate，本 reviewer没有运行：

- `swift run RunTests` 或任何单项Swift测试；
- `swift build`、release build或App build；
- SQLite 3.51/3.52 migration matrix；
- App preview、UI smoke或任何产品进程；
- commit、push、merge、release或外部操作。

本次只执行了只读文件/源码检查、SHA-256与manifest复算、Git状态读取、静态
name/structure/sentinel检查，以及不执行命令体的`bash -n`语法解析。

## 7. Findings

- P0：无。
- P1：无。

## 8. Verdict

APPROVED — 0 P0 / 0 P1
