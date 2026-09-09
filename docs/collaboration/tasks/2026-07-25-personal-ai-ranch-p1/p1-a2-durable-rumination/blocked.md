# P1-A2 Control — R27 permanent rejection preserved；R28 measurement-boundary root-cause closure

> 状态：**R27 永久 REJECTED_CONTAMINATED — 唯一 full 651/652；Shell timeout 测量边界失败；无 later gates/END；R28 Measurement-Boundary Candidate Frozen；fresh driver/235-entry manifest/freeze present；Review28 pending；A2 blocked**
>
> 日期：2026-08-10
>
> 分支：`codex/personal-ai-ranch-p0`
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. A2 入口已经真实打开

本次独立 invocation 已只读复核：

- 冻结 Stage：
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
- 冻结 P1 总 Plan：
  `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0`
- A1b 最终 implementation Review：
  `APPROVED — 0 P0 / 0 P1`，报告 SHA-256
  `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`
- A1b 独立 acceptance：
  `ACCEPTED`，22/22 PASS，SHA-256
  `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`
- 当前 P1 控制索引精确为
  `A1b Accepted；R-01 Closed；A2 Entry Open / Not Started`。
- 当前 fully-expanded dirty worktree 与 A1b acceptance 基线逐字一致；
  `git diff --check` 通过。

因此 A2 entry gate 成立。但冻结索引同时要求 A2 先建立 decision-complete leaf
Plan 并通过职责隔离 plan Review；entry open 不是产品实施授权。

## 2. 当前冻结输入不能形成唯一、合规的 A2 实现

### B1 — “正在恢复”要求与允许文件互相冲突

冻结 Plan §3.3 要求：

> UI 的 reading/extracting/organizing 只投影真实 work phase event；重启后未知具体
> 模型阶段显示“正在恢复”，不虚构阶段。

但当前：

- `CodingRanchContracts.swift` 的 `RuminationStage` 只有
  `saved/reading/extracting/organizing`；
- `RuminationViews.swift` 固定按这四个阶段渲染；
- Adapter 在重启后没有内存 phase 时用 `?? .reading`，正在虚构 reading。

前两份必改文件均不在 A2 allowlist。leaf Plan 无权自行扩张冻结范围，也不能用
错误文案、标题拼接或继续伪装 `.reading` 来绕过要求。

### B2 — 唯一 Supervisor owner 被排除在 A2 allowlist 外

当前唯一 `DurableWorkSupervisor` 由 `Orchestrator.swift` 私有持有，并由它统一
负责 startup recovery、dispatch activation、emergency halt/resume、idle 与
bounded shutdown。该文件不在 A2 allowlist，App/Adapter 也无法访问私有实例。

若在 AppStore 另建 rumination supervisor，会产生第二个 pump、第二套
startup/halt/shutdown owner，并使全局停营、generation、lease renewal 和 late
terminal response 的责任分裂。若复用现有单一 supervisor，则必须修改
`Orchestrator.swift`。这项架构选择不能由 implementer 猜测。

### B3 — captured runtime 与 legacy repair 没有可执行的 resolver 合同

冻结 Plan 要求 `RuminationWorkInput(model,runtimeProfileId,pipelineVersion)`，
且 enqueue 时固定当前有效 profile。但没有冻结：

- rumination 使用哪个 exact resolver、是否复用 planning-named resolver；
- profile/model/catalog/credential/endpoint/CLI 的稳定失败码、重试分类与安全文案；
- restart 时必须只读 captured profile/model、禁止 current-default fallback 的
  preflight/claim 顺序；
- legacy `.ruminating` 且无 work 的行没有 captured profile/model 时，如何仍然
  恰好生成一个 repair work 并最终收敛。

当前 App `provider(model:)` 会重新读取当前默认 profile，多个读取使用 `try?`，
不满足 captured-profile 与 fail-visible 合同。

### B4 — command、状态机与 terminal contract 尚未冻结

现有 Stage/Plan 还不足以唯一决定：

- 正常 start/retry 的 idempotency key、trace ID、same-key replay/conflict；
- terminal failed/canceled 后用户 retry 如何生成新 work；
- 允许从 `queued|failed|needsReview` 中哪些状态启动；
- rumination 是否受持久全局 halt 控制，以及 halt 时 work/ingestion 的原子收口；
- transient/deterministic/exhausted failure 的固定映射、安全 diagnostics 与 usage；
- success `outputJson` 的 exact canonical shape，或明确为 nil；
- “真实 work phase event”使用进程内 supervisor event 还是持久 carrier；
- `commit(result:for:claim:database:)` 的 `database` 必须是同步 GRDB
  `Database` transaction helper，不能在 helper 内另开 `pool.write`；
- provider 已返回而 terminal persistence 失败时，如何在当前进程内保留 pending
  proposal、继续 lease 且不重复调用 provider；若进程随后死亡，A2 只允许
  adoption 后重新调用并保证最终 result/terminal commit 恰好一次，不得提前实现
  P1-F 的 durable provider-returned checkpoint。

这些决定直接影响幂等身份、费用、全局停营、数据原子性和用户可见恢复，超过 leaf
可以自行解释的机械细节。

### B5 — 八个测试名不是 decision-complete 的 A2 完成门

冻结的八个 named tests 当前均不存在。它们覆盖了主要 happy/failure race，但没有
冻结 exact input/canonical hash、captured-profile drift、resolver failure matrix、
有限重试、halt race、phase truth、terminal rollback、隐私净化、完整 build/matrix
与隔离 preview 证据。

A2 不引入 migration，但允许修改 `AppDatabase.swift`。因此 leaf 必须明确：

- 不新增或修改 schema、migration、DDL、trigger、Package target、RunTests graph；
- runner/script 保持 byte-identical；
- acceptance 前仍重跑双 SQLite 3.51/3.52 aggregate matrix，证明既有 v12 没有漂移。

## 3. 建议的最小 R12 有界修订

若牧场主授权 R12，只允许 planner：

1. 在冻结 Stage 的 durable-work/Rumination 合同和总 Plan 的 A2、A2 completion、
   migration/review gate 中关闭本文件 B1–B5；
2. 建立
   `p1-a2-durable-rumination/plan.md`，使 Open Questions 精确为空；
3. 将以下确定必需文件加入 A2 allowlist：
   - `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
   - `Sources/AgentLoopApp/CodingRanchContracts.swift`
   - `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
4. 冻结以下方向：
   - 全局只保留一个由 Orchestrator 持有的 `DurableWorkSupervisor`，不得创建第二
     production supervisor；
   - rumination 纳入同一 startup/halt/resume/idle/shutdown 与 generation owner；
     durable halt 下不得 claim、resolve 或调用 rumination provider；紧急停营把
     active rumination work 与 Ingestion 回退 `.queued` 原子收口，resume 不自动
     复活已 canceled work，之后由用户新命令重试；
   - 未知重启 phase 显式投影 `.recovering` / “正在恢复”；live phase 只来自真实
     supervisor phase event；
   - A2 不新增 phase schema 或 durable event kind，phase event 为进程内、可丢失
     的真实运行事件；重启丢失即回 `.recovering`；
   - enqueue/repair、success、terminal failure、cancel 分别使用现有 durable ledger
     的单一 GRDB transaction；stale claim/response 零业务写；
   - exact captured profile/model 不受之后默认设置变化影响；resolver 无 fallback，
     raw provider body、credential、account/OAuth 信息不进入 DB/log/UI；
     已验收的 `StrictPlanningProviderResolver` 只读复用且文件 byte-identical，
     rumination 的稳定错误映射由 A2 既有允许文件承担；
   - normal retry、legacy repair、global halt、failure/output/usage 和
     terminal-persistence recovery 语义在 leaf 中逐字段、逐顺序冻结；
5. 保留八个 frozen named tests，并增加 leaf 所需的 exact-key、resolver、retry、
   halt、phase truth、rollback、source-sentinel 与 preview gates；
6. 重新冻结 Stage、总 Plan、A2 leaf 的 exact hashes，产出 freeze evidence；
7. 由未参与修订的 reviewer 执行职责隔离 Review12。

## 4. R12 红线与继续门

R12 不授权：

- 修改任何产品代码或测试代码；
- 新增/修改 migration、schema、DDL、trigger、durable event kind；
- 修改 `Package.swift`、`Package.resolved`、`Sources/RunTests/main.swift`、
  migration runner/script 或 target graph；
- 修改 `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` 或改变已验收的
  strict planning provider-resolution 语义；
- 改变已验收 A1a/A1b planning 语义、证据、Review 或 acceptance；
- 创建第二 production supervisor；
- 提前实现 P1-F 的 provider dispatch/returned checkpoint；A2 的“完成一次”只指
  durable result/terminal commit 恰好一次，不承诺崩溃后 provider 只调用一次；
- 进入 A2 implementation、implementation Review、acceptance 或 A3；
- commit、push、merge、release、数据重置、外部操作或真实用户操作。

只有 Review12 在新冻结的 Stage、总 Plan、A2 leaf exact hashes 上判定
`APPROVED — 0 P0 / 0 P1` 后，A2 产品/测试实施门才可打开。Review 前继续禁止任何
A2 产品或测试代码修改。

## 5. R12 授权与预冻结新发现

牧场主已于 2026-07-27 明确回复“继续，授权”，授权第 3–4 节的最小 R12
修订。planner 在写入前执行 gate 反证时发现一个原授权内部无法同时成立的
control-tooling 矛盾，因此尚未修改 Stage、总 Plan、leaf 或产品/测试文件。

当前 migration matrix script：

- 路径：`scripts/verify-p1-migrations-sqlite-matrix.sh`
- SHA-256：
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`
- line 115 唯一硬编码：

```bash
expected_stage_hash="add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2"
```

R12 必须修改 canonical Stage，Stage SHA 必然改变；A2 completion 又必须运行该
script 的双 SQLite 3.51/3.52 matrix。但第 3–4 节同时要求 script byte-identical
并禁止修改它。若保持原字节，script 必在执行任何 matrix 前以
`frozen Stage hash drifted` 失败；不能靠临时替换 Stage、跳过 script 或复制一个
放宽版 verifier 冒充通过。

### R12-A 最小授权增量

只增加一个 control-tooling 例外：

- 将 `scripts/verify-p1-migrations-sqlite-matrix.sh` 加入 R12/A2 control allowlist；
- 唯一允许 delta 是把 line 115 的 `expected_stage_hash` 同步为最终经
  Review12 批准的 frozen Stage SHA-256；
- 除该 64-hex value 外，script 的 fixture、literal、linked lanes、断言、命令与
  全部其他 bytes 必须不变；
- `Sources/P1MigrationMatrixRunner/main.swift`、migration/DDL、Package graph、
  产品/测试逻辑仍 byte-identical；
- Stage/总 Plan/A2 leaf 与该单行 control delta 重新冻结后才执行 Review12；
  Review12 通过前继续禁止任何 A2 产品或测试代码实施。

## 6. 本次停止点

本次只执行了只读入口、代码拓扑、契约与 gate 审计，并创建本阻塞记录。没有修改
产品/测试代码，没有运行会写构建产物的测试或 build，没有 commit、push、merge、
release、数据重置或外部操作。

## 7. R12-A 授权与 blocker 关闭状态

牧场主随后明确回复“继续，授权”，批准 §5 的 R12-A 最小增量。planner 已据此：

- 只在 canonical Stage §6.4、§20–§22、§28，总 Plan §3.3/§10/§11/§18 与 A2
  leaf 中关闭 B1–B5；
- 把 Orchestrator、CodingRanchContracts、RuminationViews 加入 A2 exact
  allowlist，不增加其他产品/test文件；
- 冻结 single Supervisor、captured runtime、legacy repair、generic capability
  sealing、usage/failure、terminal proposal、startup/halt、phase truth、mutation
  fences、41 exact tests、dual matrix 与 isolated preview；
- 只允许 matrix script line 115 的 Stage hash value 同步，runner/fixture/
  migration/Package/RunTests与其他 script bytes不变；
- 创建 `plan.md` 与 `evidence/plan-freeze.md`，并更新 P1 control indexes。

因此原 B1–B5 与 control-hash 规划 blocker 已在 plan level 关闭；这**不等于**
Review12 批准，也不打开 implementation。只有职责隔离 Review12 在 freeze evidence
记录的 exact Stage/总 Plan/A2 leaf hashes 上判定
`APPROVED — 0 P0 / 0 P1` 后，A2 产品/测试代码实施门才可打开。此前本文件继续作为
hard stop；A2 implementation、implementation Review、acceptance 与 A3 均禁止。

## 8. Review12 immutable verdict 与 R12-B closure

职责隔离 Review12 已对 §7 的原 candidate 作出不可变结论：

- report：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12-p1-plan-review.md`
- SHA-256：
  `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3`
- verdict：`CHANGES REQUIRED — 0 P0 / 2 P1`
- 旧 freeze evidence：
  `evidence/plan-freeze.md`
- 旧 freeze SHA-256：
  `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5`

两项 finding 均属于已授权 B3/B4，不扩大 13+2 allowlist：

1. P1-1：原 provider API 在内部完成 parse，却要求 Supervisor 在 parse 前发
   organizing，同时又禁止 callback，因此无合法 owner/API handshake。
2. P1-2：legacy repair 未定义 durable halted × 三种 invalid startup snapshot。

R12-B 只做以下机械 closure：

- provider 唯一 API 改为返回 fileprivate-text 的 opaque
  `RuminationValidatedTurn`，并在返回前完成 exact-one-turn + usage validation；
- Supervisor 对 opaque turn 在 typed awaited phase sink 前后两次重验
  lifecycle/generation/token/OwnedEntry/current latest claim 与 DB durable
  ownership；第二次仍有效才无 await 同步调用唯一 pure parse API；
- 禁止语义精化为禁止 arbitrary provider/usage/optional callback、mutable usage、
  unowned Task 与第二 provider path；唯一 phase-only awaited sink 明确获准；
- legacy 冻结完整 running|halted × valid|profile unresolved|model unavailable|CLI
  unsupported 8-cell表。mode先线性化且 halted 绝对优先，四个 halted组合统一
  `emergency_halt_during_rumination` queued-attempt0→canceled、item queued/error
  nil、零 domain/attempt event、零 credential/resolver/provider；
- 总 Plan/A2 leaf 的 #27/#31/#35/#39 exact subcases同步上述合同，41 test names、
  allowlist、Open Questions与其余合同不变。

旧 Review12 与旧 `evidence/plan-freeze.md` 必须 byte-identical；新 evidence 唯一路径
为 `evidence/plan-freeze-r12b.md`。R12-A script例外仍只同步 line 115 Stage
64-hex，恢复最初 Stage值后必须恢复最初 script hash。只有职责隔离 Review12A 在
新 Stage/总 Plan/A2 leaf exact hashes上判定 `APPROVED — 0 P0 / 0 P1` 后，A2
implementation gate才可打开；此前继续禁止红测、产品/test改动、implementation
Review/acceptance与A3。

## 9. R12-B phase pre-audit finding 与 R12-C closure

R12-B phase pre-audit 没有创建报告文件，冻结结论为
`0 P0 / 1 P1 / 0 P2`。Legacy/mechanical audit clean；唯一 P1 是 Stage §6.4.9
已定义的 control/fatal 出口没有被现有 #27/#35 completion subcases 与 source gate
穷尽证明。

牧场主已授权同根因 R12-C 极窄修订。唯一 closure 为：

- #27 在 first/second revalidation 分别穷尽 lifecycle、suppression、fatal、
  generation、token、workId、ingestion、attempt、providerExited、pending
  proposal、current latestClaim、durable mode、work、kind、aggregate、Camp、
  item、version、lease owner、expiry expected loss；每格 exact control signal由
  owned task专门catch，且zero parse/attempt failure/retry/failure/proposal/domain
  event/business write，second-round已发phase由control changed/matching fence清除；
- #35 对同一矩阵锁 persisted matching visibility，并在两轮 validator分别注入
  DB read failure/invariant corruption；只允许 global fatal，zero parse且不进入
  provider failure/retry/proposal，已发phase同样清/fence；
- Stage completion与 source-range/order gate锁真实 handler两轮 actor/current
  latestClaim/durable graph顺序、control专门catch与global-fatal owner；substring、
  count-only或复制helper不算通过；
- #31、41 names、13+2 allowlist、架构/API、产品/test范围均不变。

旧 Review12、旧 `evidence/plan-freeze.md` 与
`evidence/plan-freeze-r12b.md` 必须 byte-identical；R12-C 新 evidence 唯一路径为
`evidence/plan-freeze-r12c.md`。Review12A 仍不得由 planner 创建；通过前继续禁止
产品/test实施、red tests、build/matrix/preview、implementation Review/acceptance
与A3。

## 10. Review12A immutable verdict 与 R12-D closure

职责隔离 Review12A 已对 R12-C exact candidate 作出不可变结论：

- report：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12a-p1-plan-review.md`
- SHA-256：
  `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`
- verdict：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`
- finding：第二轮 expected control loss 或 DB/invariant global fatal必须零业务写，
  因而 persisted active workId/attempt可保持不变；R12-C positive-only phase sink
  没有 identity-bound invalidation producer，matching persisted fence无法清除已经
  线性化的 organizing。

牧场主已授权只在该同一根因内执行 R12-D。唯一 closure 为：

- 保留一个 awaited callback与既有两个 process-local KernelEvent；callback payload
  从 positive-only emission改为 exact
  `RuminationPhaseCommand.set(identity,phase)|invalidate(identity,reason)`，identity
  精确为 ingestionId/workId/attempt，reason只允许controlLoss/globalFatal；不传
  raw/usage/result/Error/diagnostics，不增第二callback/schema/EventKind。
- Supervisor actor唯一
  `invalidateRuminationPhaseIfNeeded(identity:reason:) async` 在await前记录
  in-flight并revoke新set；若已有set sink in-flight则先等待该delivery返回，再发
  invalidate，不依赖跨actor FIFO。reentrant duplicates等待同一nonthrowing sink
  delivery，first safe reason wins且每identity exactly once；不得由Task、timeout
  或cancellation拥有。fatal格first winner为globalFatal，其余control格为
  controlLoss。
- production唯一 async `latchFatalAndInvalidateRumination` 聚合所有 fatal writer、
  `.fatal` classification、latch wrapper与 revoke-all path。顺序固定为捕获sorted
  live identities→revoke positive-set permission→await全部invalidation→才cancel
  provider/renewal task、remove/wake/return。同步planning compatibility path只能在
  mutation前证明零rumination，否则 exact capability error fail-fast。
- Orchestrator actor唯一持有 exact identity/phase registry与last-invalidated
  tombstone；matching invalidate才remove→tombstone→恰好一次既有
  `ruminationChanged`，repeated/stale/mismatch零event且不能清新generation。
  合法set先registry后phase emit；old set命中tombstone不能revive。
- App串行消费Orchestrator FIFO；matching changed先clear live phase再reload。
  persisted identity即使不变也投影recovering；restart registry/tombstone为空，
  `.ruminating`无live command同样recovering。terminal/retry/cancel/halt成功路径
  经同一invalidator，terminal persistence rollback不清phase。
- 现有#27/#35精确增加second-loss、DB/invariant、cancellation、duplicate
  exactly-once、stale/new-generation、positive revival、terminal/retry/cancel/halt
  registry clear与restart assertions；#31、41 names、13+2 allowlist不变。
- source gate必须解析真实handler/owner/registry/App consumer enclosing ranges与
  call order，证明one callback、unique invalidator、all fatal routes、
  capture→revoke→await registered set→await invalidate→cancel/return、no
  Task/cancellation early
  return、exact-match registry/tombstone与App clear-before-reload FIFO。

旧 Review12、Review12A、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md` 与 `evidence/plan-freeze-r12c.md` 全部
byte-identical；R12-D 新 evidence 唯一路径为
`evidence/plan-freeze-r12d.md`。planner不得创建下一报告；只有未参与 R12-D 的
职责隔离 reviewer 可写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12b-p1-plan-review.md`。
R12-D freeze当时要求Review12B在新Stage/总Plan/leaf exact hashes上判定零P0/P1
才可继续；其实际immutable verdict与后续停止门见§11。

## 11. Review12B immutable verdict 与 R12-E closure

职责隔离 Review12B 已对 R12-D exact candidate 作出不可变结论：

- report：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12b-p1-plan-review.md`
- SHA-256：
  `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`
- verdict：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`
- finding：R12-D 的 identity-bound invalidation能清已发live phase，但 durable
  terminal/retry/cancel在没有live phase时，以及halt bulk cleanup提交projection后，
  没有必达的最终App persisted-projection refresh owner；`haltStateChanged`也不能
  代替逐work rumination refresh。

牧场主已授权只在该同一根因内执行 R12-E。唯一 closure 为：

- 仍只保留一个 awaited callback、既有两个 KernelEvent cases、13+2 allowlist、
  41 test names与#31；不增schema/migration/DDL/EventKind、persistent phase/
  receipt、文件或第二owner。
- public `RuminationPhaseIdentity(ingestionId,workId,attempt)`允许attempt `0`，
  以覆盖queued user-cancel/halt commit；positive set/phase invalidation仍要求
  running/open attempt>=1。public
  `RuminationProjectionCommitIdentity(phaseIdentity,workVersion)`要求version>=1且
  只取Store transaction实际resulting work。
- 单一 command仍只有`.set(identity:phase:)`与
  `.invalidate(RuminationInvalidationMilestone)`；milestone exact cases为
  `.phase(identity:reason:)`与`.projectionCommitted(commitIdentity)`，phase reason
  仍只有controlLoss/globalFatal。
- success、deterministic/exhausted failure、transient retry、actual user cancel
  Store operation返回resulting work；halt cleanup返回sorted actual-canceled commit
  identities。Supervisor在commit后的同一actor turn、第一次await前reserve full
  identity；rollback/throw/no-active零reserve/milestone。
- phase/projection共用per-identity串行coordinator：projection-first时later phase
  等待且matching commit满足clear、零第二phase command；phase-first时later真实
  commit仍等待后发refresh且typed optional clear=nil。full identity exactly-once，
  same-work更高version合法，unseen lower或same-version/different-identity
  fail-fast。
- Orchestrator用full commit receipt与per-work最高version；exact registry匹配才
  remove/tombstone并在typed event带`.some(identity)`，empty/tombstoned/
  different-newer不改registry、带nil但仍发commit refresh。App单一MainActor
  listener先以同一DB snapshot验证phase；change只做typed exact clear，但总是串行
  reload persisted projection，background Camp不切换selected UI。
- emergency halt精确顺序为sorted pre-cancel phase clear→cancel provider/renewal→
  persist halted→planning cleanup→rumination cleanup返回sorted actual commits→逐个
  projection refresh→didCommit/`haltStateChanged`→return。cleanup失败不为未commit
  row发milestone，保持suppressed/recovering；`haltStateChanged`不是refresh owner。
- 只扩展现有#27/#35与source gate：live+phase-less success/failure/retry/cancel、
  retry V+1后cancel/halt V+2、duplicate/regression、rollback、halt前后failure、
  projection-first/phase-first、registry四态、typed optional clear、App
  same-snapshot/FIFO与所有milestone callsite/order；不新增test name。

旧 Review12、Review12A、Review12B、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`与
`evidence/plan-freeze-r12d.md`全部byte-identical；R12-E新evidence唯一路径为
`evidence/plan-freeze-r12e.md`。planner不得创建下一报告；只有未参与R12-E的
职责隔离reviewer可写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`。
Review12C在新Stage/总Plan/leaf exact hashes上判定
`APPROVED — 0 P0 / 0 P1`前，继续禁止产品/test实施、red tests、build/matrix/
preview、implementation Review/acceptance与A3。

## 12. R12-E follow-up finding 与 R12-F closure

R12-E candidate冻结后的有界审计（无Review12C报告）结论为
`0 P0 / 2 P1 / 1 P2`：

1. normal start/user retry transaction提交queued attempt-zero work后，没有
   final App persisted-projection refresh publisher；只在caller return前补await仍
   不够，因为Supervisor actor在await sink期间可重入，已有pump/timer/kick可能先
   claim新work。
2. active replay若从当前attempt/version合成projection milestone，会重复refresh，
   且running replay可能碰撞/清除新的live generation。
3. 进程在commit与process-local delivery间死亡没有持久outbox/receipt；这是P2，
   R12-F不扩大schema，只以restart persisted snapshot truth收口。

牧场主已授权R12-F，只关闭上述两个P1：

- Orchestrator只作public façade；唯一Supervisor actor执行absent preflight、
  specialized Store start、milestone与kick。Store使用既有
  `DurableWorkEnqueueResult`：`.inserted`只表示本次实际commit；
  `.replayed`只表示零写active replay。
- `.inserted`同步return后第一次await/reentrancy前，Supervisor验证resulting work为
  queued attempt0/exact `version=1`，并同时reserve full commit identity与process-local
  start-projection barrier。任一barrier存在时，所有已有pump/timer/kick/global
  claim入口对planning+rumination均零DB claim、零跨kind skip。sink delivery后才
  release barrier，再重读mode/work；只有running+active才kick。task cancellation
  不能跳过delivery/release。
- App preparation的`replay(ingestionId,workId)`绕过resolver/Store start；并发
  new-command transaction的Store `.replayed`是第二origin。两者统一进入同一
  Supervisor workId branch：original inserted delivery in-flight时只等待它；
  delivered或新进程无waiter时零等待/零第二milestone/event；绝不从current
  attempt/version构造identity。kick失败只可重试kick，不重发refresh。
- restart必须先经同一Adapter snapshot path成功加载目标ingestion所属Camp并标记
  ready，才enable该start/retry action；load failure保持disabled并显式失败，不能在
  无投影时清startup pending。active graph无本进程waiter/receipt时显示recovering；
  background Camp load不切selected Camp。
- start sink暂停时，立即user cancel/halt可提交严格更高version，但既有
  per-identity coordinator保证start `V`→control `V+1`；start恢复后重验，不复活/
  claim canceled work。preflight/conflict/rollback/throw固定零barrier/reserve/
  sink/kick。
- 只扩现有#1/#6/#11/#22/#33/#34/#35与真实source-range/order gate；41 names、
  #31、13+2 allowlist、一个callback、两个KernelEvent cases、schema/migration/
  DDL/EventKind均不变。

首次R12-F candidate独立预检（无Review12C文件）结论为
`0 P0 / 1 P1 / 1 P2`：

1. 如果当前进程完成target-Camp ready snapshot后，允许另一production进程写同一
   state root，则后者commit并死亡会让本进程replay在零milestone/零reload合同下
   保留stale projection；
2. new specialized insert已有更精确的`version=1`合同，不应放宽为`>=1`。

牧场主授权在同一R12-F范围选择既有可验证single-writer closure，而不扩大
event/replay refresh API：

- 当前产品同一state root只允许一个production writer。AppStore以
  `private let stateDirectoryLock: StateDirectoryLock`完整lifetime持锁，并在同root
  production唯一`AppDatabase(path:)`之前取得；`StateDirectoryLock`使用
  `flock(LOCK_EX|LOCK_NB)`，第二owner `EACCES|EAGAIN` fail-fast，deinit/process
  death释放。
- 因而snapshot ready后另一个production owner再commit的TOCTOU不可达；新owner
  只能在旧owner死亡/释放后取得lock、打开DB，再完成target-Camp snapshot ready
  才enable command。replay继续零milestone、零direct reload。
- `StateDirectoryLock.swift`与`SupportTests.swift`不进入13+2，按freeze hash保持
  byte-identical；source gate锁production `AppDatabase(path:)` callsite=1、
  lock-before-open与lifetime ownership，既有exclusive/release test必须全绿。
- `.inserted`与attempt-zero start full identity精确`workVersion=1`；specialized
  transaction不得二次推进new work version。未来CLI/硬件若写同一state root，
  必须另开stage设计cross-process coordination/outbox；A2禁止绕锁。

旧Review12/12A/12B与`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`、
`evidence/plan-freeze-r12d.md`、`evidence/plan-freeze-r12e.md`全部
byte-identical；R12-F新evidence唯一路径为`evidence/plan-freeze-r12f.md`。
planner不得创建Review12C。只有未参与R12-F修订的职责隔离reviewer可写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`。
其在R12-F exact hashes上判定`APPROVED — 0 P0 / 0 P1`前，继续禁止产品/test、
red tests、build/matrix/preview、implementation Review/acceptance与A3。

## 13. Historical Review12C approval and failure-first activation

职责隔离 reviewer 已在 R12-F exact candidate 上完成 Review12C：

- Stage SHA-256：
  `cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9`
- P1 总 Plan SHA-256：
  `79c9252048697a84c395c5bbdad2bd68495f07fec4a9294c5b6937b02d8e02ab`
- A2 leaf Plan SHA-256：
  `42ddb63dc73cd62514f09956b08378d397d146c2c5eba19c57a3950835bef2e3`
- Review12C：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`
- verdict：`APPROVED — 0 P0 / 0 P1`
- report SHA-256：
  `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`

本节只记录当时 Review 后的 historical control/blocker 状态激活，因而有意改变 R12-F freeze 中记录的
pre-activation blocker/control-index hashes；它不修改 canonical Stage、总 Plan、
A2 leaf、R12-F freeze evidence、matrix script或 Review12C 报告。

当时仅打开冻结 leaf 指定的首批五个 failure-first 测试：

1. `ruminationStartAndWorkAreAtomic`
2. `legacyRuminatingRowGetsOneRepairWork`
3. `ruminationCancelAndQueuedProjectionRollbackTogether`
4. `ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask`
5. `ruminationUnknownRestartRendersRecoveringWithoutInventingReading`

五项当时必须先在现有测试 API 上编译并被 runner 精确发现，且只能以各自冻结的
capability failure 失败。任何 compilation、discovery、fixture 或 unknown error
都会重新关闭当时的产品代码 gate并写回本 blocker。该历史质量门不覆盖
Review13/13A 后重新关闭的 current gate；当前仍禁止 A2 seam、测试与其他产品代码、
完整验证、implementation Review/acceptance与A3。commit、push、merge、release、
数据重置、外部操作和真实用户操作权限均未扩大。

## 14. Failure-first red quality gate passed

定向命令已运行并将完整输出保存到：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/red-tests.log`
- SHA-256：
  `97b965160adb1b317c76d5227312ceb6c185642cccff0482c40ab281d84e0f15`

机械结果：

- `RunTests` build complete；
- 五个 exact test names 各启动一次；
- 五个 `A2_RED_*` capability labels 各出现一次；
- 总计 `5 tests / 5 expected issues`；
- 零 compilation、discovery、fixture 或 unknown failure。

因此 failure-first red quality gate 已通过，冻结 13 个产品文件与两个测试文件内的
A2 实现门打开。其余 36 个 exact named tests 只可随已冻结 API/行为实现补齐；完整
tests/build/matrix/preview/scope gates、implementation Review/acceptance 与 A3 仍
关闭。commit、push、merge、release、数据重置、外部操作和真实用户操作权限未扩大。

## 15. Implementation coverage audit blocker and bounded R13 request

2026-07-27，A2 产品实现与 41 个 exact named tests 已可编译，首次完整
`swift run RunTests` 以 `652 tests / 7 suites` 全绿；App debug/Core release build、
SQLite 3.51/3.52 matrix 与 isolated preview 也已取得通过证据。但职责隔离的
completion-coverage 审计发现：这些绿色结果尚未满足冻结 leaf §9/§10 的 exact
finding-closure contract，因此不得进入 implementation Review。

已确认的 blocker：

1. `ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal` 当前只动态覆盖正常
   reading→extracting→organizing、projection commit 与 restart 零重发；没有在
   第一次/第二次 revalidation 逐格注入 lifecycle、suppression、fatal、
   generation、token、workId、ingestion、attempt、providerExited、pending
   proposal、current latestClaim 与十个 durable-graph loss，也没有完整证明
   control/global-fatal exactly-once invalidation、paused-set/cancellation/
   duplicate first-winner 和 two-way coordinator race。
2. `ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents` 当前主要是
   Orchestrator/App/Adapter 的静态 token 顺序；没有覆盖上述 loss 的 persisted
   visibility、两轮 DB read/invariant fatal、commit/version/rollback/halt/registry/
   background-Camp runtime matrix。
3. 现有 `codingRanchSourceRange` 只按 substring 切片，不屏蔽注释/字符串，也不
   证明 unique brace-enclosed owner；这不满足 leaf §10 明确要求的真实 enclosing
   source-range/order gate。既有 `PlanningTestFixtures.uniqueFunction` 可以在不改
   allowlist 外文件的前提下替换它。
4. `#31/#40/#41` 还需在既有名字内补齐 production callsite、Supervisor 端到端
   usage/accounting 与 status-only/work-only fence 维度；这些可在既有两个测试
   allowlist 文件内完成，不需要改变产品语义。

provider gate、awaited phase sink 与 isolated DB mutation可以覆盖外部可控的
provider/phase/Store 时序；但 token、owned workId、providerExited、pending
proposal、current claim 等 actor-private loss 无法经当前 package API 逐格、安全且
不改变真实持久状态地注入。只用静态 source gate替代动态矩阵会违反冻结
leaf §9；用反射/unsafe mutation或新增 release-visible API同样不接受。当前冻结
Stage/总 Plan/leaf没有定义 A2 DEBUG test seam，implementer不能自行发明。

请求牧场主授权 R13，范围严格限定为：

- 只修订 Stage §6.4.9、总 Plan §3.3/§11 与 A2 leaf §9/§10，定义一个
  release binary 中不存在的、`#if DEBUG` + package visibility、one-shot、
  enum-closed 的 rumination authorization scenario seam；
- seam只允许在既有 `DurableWorkSupervisor.swift` 内，对已 owned 的 exact
  rumination work和 first/second revalidation checkpoint注入冻结清单中的 loss；
  不接任意 closure、Database/path/provider/token/raw row，也不直接调用 Store或
  伪造成功；
- 只扩现有 `#27/#35` 的表驱动动态矩阵，并把 `#31/#40/#41` 与真实
  `PlanningTestFixtures.uniqueFunction` source gate补齐；41 names、13+2 allowlist、
  target/package graph保持不变；
- 新增 release `nm` 零符号与 DEBUG caller-guard source gate；不得新增
  product/test file、schema/migration/DDL/EventKind、persistent phase、callback、
  KernelEvent case、production bypass或权限；
- 重新冻结 canonical Stage/总 Plan/leaf并执行职责隔离 R13 Plan Review。
  Review判定 `APPROVED — 0 P0 / 0 P1`前，不实施该 seam；通过后重新跑全部
  RunTests/build/release/matrix/source/hash/privacy/preview gates。

R13前，A2 implementation Review/acceptance、A3、commit、push、merge、release、
normal-data access/reset、外部操作与真实用户操作继续关闭。现有通过日志只作为
pre-R13 implementation evidence，不构成 A2 completion。

## 16. R13 authorization and bounded candidate freeze

2026-07-27，牧场主对 §15 的有界请求原话授权：

> 继续，授权

本授权只打开 planner 对 canonical Stage §6.4.9、总 Plan §3.3/§11、A2 leaf
§9/§10、两个执行控制索引与本 blocker/freeze evidence 的修订；不授权产品/test
代码、build/test/matrix/preview、Review/acceptance、Git写操作或A3。

R13 Candidate现已冻结为：

- release-absent matching-`#if DEBUG`、package-only、single-armed、one-shot、
  enum-closed rumination authorization scenario seam；
- exact checkpoints为`first|second`，exact losses为11个actor维、10个durable维与
  DB-read/invariant两维；actorAttempt与durableAttempt严格分离，每轮23格、总46格；
- arm只接当前already-owned exact `RuminationPhaseIdentity`并内部捕获token/
  generation；不接Database/path/provider/token/raw row/Error/closure；
- 两个consume hook都在真实actor gate与真实DB validator成功后：first在organizing
  前，second在awaited organizing后、service lookup/parse前；consume只throw到既有
  production catch，不直调Store/validator/invalidator/fatal owner/sink/handler；
- #27/#35动态46格、#31 production callsites、#40 Supervisor端到端usage/accounting、
  #41 status-only/work-only/neither，以及
  `PlanningTestFixtures.uniqueFunction` masked enclosing-range gate；
- release exact Supervisor object `nm -j | xcrun swift-demangle`零seam符号、DEBUG
  object反向存在、全部type/storage/helper/caller/test arm caller有matching
  `#if DEBUG`；
- 41 test names、13+2 allowlist、schema/migration/DDL/EventKind、persistent phase、
  callback、KernelEvent与Package/target graph不变。

精确hash、zero product/test drift与immutable predecessor证明见
`evidence/plan-freeze-r13.md`。职责隔离 Review13 判定
`APPROVED — 0 P0 / 0 P1`前，继续禁止seam/test implementation、A2 implementation
Review/acceptance、A3、commit、push、merge、release、normal-data access/reset、
外部操作与真实用户操作。既有绿色日志仍只作为pre-R13 evidence。

## 17. Review13 P1-01 and bounded R13A gate synchronization

职责隔离Review13在R13 exact hashes上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；immutable报告为：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13-p1-plan-review.md`
- SHA-256：
  `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`

唯一P1-01不是seam、矩阵或allowlist缺口，而是canonical header、current entry、
review writer、验证前置与完成门仍同时把Review12C当作当前权威，允许绕过R13
candidate review。

R13A只同步当前gate：

- Stage header与当前redline统一为R13A Candidate/Review13A Pending；
- total Plan header、§3.3 current entry/reviewer writer/implementation opening与§11
  统一指向`reviews/13a-p1-plan-review.md`及R13A exact hashes；
- leaf header、§1 current entry/stop、§10验证前置与§12完成门同义同步；
- Review12C保留为R12-F immutable approved predecessor，Review13保留为R13
  immutable changes-required predecessor；旧附录/Review文件不改。

R13A canonical hashes：

| Artifact | SHA-256 |
|---|---|
| Stage | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| total Plan | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| A2 leaf | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |

精确manifest与零product/test漂移见`evidence/plan-freeze-r13a.md`。Review13A判定
`APPROVED — 0 P0 / 0 P1`前，继续禁止DEBUG seam、#27/#31/#35/#40/#41测试、
其他产品代码实施、A2 implementation Review/acceptance、A3及全部既有Git/发布/
normal-data/外部权限。R13A不改seam合同、矩阵、41 names、13+2 allowlist、
schema/API/event/package边界、matrix script或旧Review。

## 18. Review13A P1-01 and bounded R13B control-only synchronization

职责隔离 Review13A 在 R13A exact canonical hashes 上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；immutable 报告为：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13a-p1-plan-review.md`
- SHA-256：
  `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580`

三份 canonical、seam、46 格矩阵、覆盖门与全部 sentinel 均已通过。唯一 P1-01
仍是本 blocker 与两个 control index 把 Review12C 的历史开门状态写成 current。

R13B 只把这些 control 文字降级为 historical，并把唯一 current gate 指向
`reviews/13b-p1-plan-review.md`：

- 三份 canonical 保持 R13A bytes 与 hashes 逐字不变；
- Review12C 只表示当时打开 failure-first gate，pre-R13 绿色日志不构成当前授权；
- Review13 与 Review13A 均保持 immutable changes-required predecessors；
- DEBUG seam、#27/#31/#35/#40/#41、其他产品代码、完整验证、implementation
  Review/acceptance 与 A3 在 Review13B `APPROVED — 0 P0 / 0 P1` 前全部关闭。

精确 control hashes、canonical/product/test/script 零漂移与 predecessor 证明见
`evidence/plan-freeze-r13b.md`。R13B 不修改 canonical、seam/矩阵、41 names、
13+2 allowlist、schema/API/event/package 边界、matrix script 或旧 Review。

## 19. Review01 P1-01 and authorized R14 clean-boundary disposition

Review13B最终在R13B exact control candidate上判定
`APPROVED — 0 P0 / 0 P1`：

- Review13B：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13b-p1-plan-review.md`
- SHA-256：
  `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`

随后R13 implementation、41-name/652-test/build/release/matrix/source/hash gates与
fresh isolated retry均完成；但第一次preview的Computer Use display-name lookup
自动启动installed `/Applications/AgentLoop.app` PID 74836，并实际打开normal
state root的`.agentloop.lock`、DB、SHM与WAL。该attempt与后续retry均完整保留。
没有incident前normal DB content hash，因此mutation只能记为`UNKNOWN`。

职责隔离implementation Review01：

- `reviews/01-p1-a2-review.md`
- SHA-256：
  `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`
- verdict：`CHANGES REQUIRED — 0 P0 / 1 P1`

整个R13 implementation/completion invocation现固定为
`REJECTED_CONTAMINATED`。旧成功retry不构成R14 green evidence，Review01、
`impl-report.md`与全部old logs/evidence/screenshot不得修改。

牧场主已授权R14仅作plan-level incident disposition与新的one-shot clean boundary：

- R14不授权任何产品/test修改，不访问、读取、hash、清理、恢复或重置normal root；
- 三份canonical已同义定义historical incident、zero-product/test-delta clean
  re-verification、distinct R14 artifacts、fail-once/no-retry规则、Review02与
  scoped acceptance wording；
- R14 exact canonical candidate为：

| Artifact | SHA-256 |
|---|---|
| Stage | `5a128120d8fc815c207c93dc06a9aa0c016f48ded275107564d1df6dae0d7f8b` |
| total Plan | `c8f6240eb6a5622390edf58278a8a2890c06f659077babe4667a10b9b4d4b028` |
| A2 leaf | `1f9e2ea7140bf9c0daa5ab7004897fd5a97e6386f64ae7e20a4a16b5c0c08665` |

职责隔离Review14随后只写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/14-p1-plan-review.md`，
SHA-256
`5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`，
verdict `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`。唯一P1-01是R14禁止
LaunchServices却没有冻结non-LaunchServices source/build→App bundle→signed
executable provenance。R14因此从未打开任何执行，也没有创建`r14-*` artifacts。

## 20. Review14 P1-01 and authorized R15 bundle-provenance closure

牧场主以“继续”授权R15只关闭上述同一P1。R15不修改产品/test/App scripts，不运行
test/build/matrix/source/preview，不启动App，也不访问normal root。三份canonical
同义冻结：

- BEGIN在任何执行前消费一次授权，但只记录frozen inputs、no-process、
  `r15-dev-bundle-v1`与planned fresh bundle/state roots；
- App build后、launch前依次写POST_BUILD/PRE_SIGN/LAUNCH_READY，证明SwiftPM
  executable/resources、unsigned copy、RanchArt 27-file manifest、inline
  Info.plist、single ad-hoc sign与post-sign executable/UUID/CDHash/bundle manifest；
- 不读取、复用、删除或覆盖现存`.build/AgentLoop.app`；禁止执行/截取
  `scripts/run-app.sh`与`scripts/package-app.sh`及所有LaunchServices路径；
- bootstrap/cold start顺序复用同一LAUNCH_READY bundle，只按exact path/own PID
  direct exec；任一provenance/isolation/技术门失败永久拒绝，同boundary零修补/retry；
- matrix script planning/Review期间逐字不变；未来只继承既有唯一Stage-hash临时
  delta并在matrix后mandatory恢复entry hash；
- distinct R15 artifacts、Review02与scoped acceptance继续保留R13 incident、
  mutation unknown与Review01，不得声称A2历史零访问。

R15 exact canonical candidate为：

| Artifact | SHA-256 |
|---|---|
| Stage | `e66fba4cca62a20fae155591384d426fac446eb2e0ccb510820f13fe8fe11289` |
| total Plan | `fc4ca360e2705e8ed3ce00b068c309536efd99f4ac6df2e8d6b1e7cc5606b75d` |
| A2 leaf | `42aeab70d6595358dd22b3474c459b4b05c7c42cf504e396d1e0342ff5398b6e` |

职责隔离Review15随后只写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`，
SHA-256
`fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`，
并判定`APPROVED — 0 P0 / 0 P1`。牧场主随后在新的用户turn授权一次R15 clean
re-verification；该授权已在BEGIN写入时消费。真实执行结果见§21，R15不再具有
current开门权。

## 21. R15 BEGIN false negative and authorized R16 closure

R15 invocation `r15-e20bac70-dead-4c21-8d42-541b0b8077b3`在Review12C hash
attestation处停止。helper记录的expected与actual均为
`db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`，却错误进入
mismatch分支；只读诊断确认两operand长度均为64且逐字相等。由此只能确认
**executor attestation false negative，而非仓库bytes drift**；更底层micro-trigger
未被现有证据复现，R16不得宣称已定位或用small fix修复。

R15永久失败证据为：

| Artifact / invariant | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`；plan approved |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；`REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight reserved gate logs | each zero bytes；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| R15 screenshot | absent |
| `/private/tmp/agentloop-r15-state.Zq6Jvm` | exists, non-symlink, empty |
| `/private/tmp/agentloop-r15-bundle.2xROcy` | exists, non-symlink, empty；planned App absent |

R15没有运行targeted/full test、build、matrix、source gate、bundle/sign或preview；
matrix Stage literal从未替换，产品/test/App scripts零delta，normal root没有被本轮
访问，Review02/acceptance没有打开。上述文件、缺失截图与两个roots全部immutable，
不得补写、清理、覆盖、重命名或供R16复用。

牧场主现已授权R16只关闭上述attestation风险类：

1. 只同步三份canonical、A2 blocked与两个P1 control surfaces，并新增reviewed
   `evidence/r16-begin.sh`、static `evidence/r16-entry.sha256`与
   `evidence/plan-freeze-r16.md`；不修改产品/test/App/matrix scripts；
2. driver只能在clean `/usr/bin/env -i`、
   `/bin/bash --noprofile --norc`中运行；外部caller与driver pre-BEGIN均以
   `/usr/bin/shasum -a 256 --strict -c`核对四个terminal anchors及static
   manifest，禁止动态expected map、自定义hash equality、zsh helper、profile、
   alias/function或silent fallback；
3. 无环信任链精确为
   `immutable inputs + r16-begin.sh → r16-entry.sha256 → plan-freeze-r16.md →
   Review16 → 后续新用户四-hash授权`。manifest不包含自身、freeze、Review16或
   runtime R16 artifacts；上游surfaces不反向嵌入后生成hash；
4. external caller与driver pre-BEGIN失败均零写入、不消费授权。只有driver
   exclusive-create`evidence/r16-clean-boundary.log`并立即写
   `authorization_consumed=true`才消费；其后任何失败永久
   `REJECTED_CONTAMINATED`且同boundary零retry；
5. R16使用全新`r16-*` execution artifacts与两个fresh roots，继承R15冻结的
   POST_BUILD→PRE_SIGN→LAUNCH_READY、same-bundle direct exec、matrix单值临时
   delta/mandatory restoration、normal-root isolation、Review02与scoped
   acceptance合同。

以下为R16当时冻结、现已immutable的exact canonical candidate：

| Artifact | SHA-256 |
|---|---|
| Stage | `053b66cb2328b25c81cb471509b90450e364583a48b41c4dabfd5eaa38874165` |
| total Plan | `1cbe04c36e13a45119120c817dde1f40548c97191651daf4d2f751a66619dcd6` |
| A2 leaf | `0bbc6ee512ce03f75be6ce5745ec2e866e70ecbfa011398e32d29984a88b7731` |

R16当时的下一动作仅允许由未参与R16修订、driver/manifest/freeze生成的职责隔离
plan reviewer核对最终六个surfaces、driver、static manifest、freeze、R15
immutable chain与fresh artifact contract，并只写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md`。

上述R16历史门在Review16 `APPROVED — 0 P0 / 0 P1`前禁止任何R16
targeted/full test、build、matrix、source gate、bundle assembly/sign或preview，
并禁止修改产品/test/App scripts、写Review02/acceptance、进入A3或执行
commit/push/merge/release/normal-data/外部/真实用户操作。Review16后来通过且用户
按`freeze, Review16, driver, manifest`顺序提供四个final hashes；实际R16仍在
pre-BEGIN零写入停止。本段当时的下一门仅见§22的R17/Review17；该历史文字不重新
开门，现行current gate仅见§29的R21/Review21。

## 22. R16 pre-BEGIN status-capture failure and authorized R17 closure

Review16随后只写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md`，
SHA-256
`71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`，
并判定`APPROVED — 0 P0 / 0 P1`。牧场主又在新的用户turn逐字提供并授权以下
R16 terminal anchors，顺序为`freeze, Review16, driver, manifest`：

| Artifact | Authorized SHA-256 |
|---|---|
| `evidence/plan-freeze-r16.md` | `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` |
| `reviews/16-p1-plan-review.md` | `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824` |
| `evidence/r16-begin.sh` | `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0` |
| `evidence/r16-entry.sha256` | `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e` |

R16真实尝试只到达pre-BEGIN：

1. zero-write external caller的四个terminal anchors全绿，110-entry static manifest
   为110/110 PASS；
2. driver pre-BEGIN重复的四anchor、manifest shape与110/110 strict check全绿，
   branch/HEAD及下列12个runtime paths absent检查也全绿；
3. `R16_PHASE=pre_begin_processes`后，第一个
   `/usr/bin/pgrep -x AgentLoop`正确返回“进程不存在”的`rc=1`；
4. driver虽在该状态捕获块执行`set +e`，但`set +e`只关闭errexit，不解除由
   `set -E`继承的全局`ERR` trap。trap在`r16_process_rc="$?"`与后续`case`前退出，
   因而把预期absence status误判为unexpected command failure；
5. 唯一授权消费点`evidence/r16-clean-boundary.log`从未exclusive-create，
   `authorization_consumed=true`从未写入。R16因此只能记录为
   `PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED`，不得写成BEGIN、retry成功或
   `REJECTED_CONTAMINATED`。

R16的12个runtime paths全部保持absent：

- `r16-targeted-tests.log`
- `r16-verify.log`
- `r16-build.log`
- `r16-migration-matrix.log`
- `impl-report-r16.md`
- `evidence/r16-clean-boundary.log`
- `evidence/r16-bundle-provenance.log`
- `evidence/r16-source-gates.log`
- `evidence/r16-hash-manifest.log`
- `evidence/r16-preview-bootstrap.log`
- `evidence/r16-preview-cold-start.log`
- `evidence/r16-preview-smoke.png`

`/private/tmp/agentloop-r16-state.*`与
`/private/tmp/agentloop-r16-bundle.*`也全部absent；R16 invocation ID、planned App、
fresh state root与fresh bundle parent均未生成。没有运行targeted/full test、build、
matrix、source gate、bundle assembly/sign或preview，没有修改产品/test/App/matrix
scripts，没有访问normal root，也没有打开Review02/acceptance或A3。R15全部文件、
absence、roots与失败事实继续immutable。

只修一个`pgrep`会留下同一根因。`r16-begin.sh`共有13个由
`set +e`/`set -e`包围、但仍暴露给全局`ERR` trap的status-capture blocks：

1. pre-BEGIN terminal-anchor pipeline；
2. pre-BEGIN static-manifest command；
3. `pgrep` process-absence command；
4. empty-directory `find` command substitution；
5. preserved R15 root `realpath` command substitution；
6. fresh root `realpath` command substitution；
7. post-activation terminal-anchor pipeline；
8. post-activation static-manifest command；
9. RanchArt regular-file `find` command substitution；
10. RanchArt path-transform pipeline command substitution；
11. RanchArt exact-path `diff`；
12. RanchArt nonregular-node `find` command substitution；
13. RanchArt regular-file-count pipeline command substitution。

牧场主已授权R17只关闭这个统一根因：

- 只同步三份canonical、A2 blocked与两个P1 control surfaces；
- 新增fresh `evidence/r17-begin.sh`、
  `evidence/r17-bash32-probes.sh`、static `evidence/r17-entry.sha256`与
  `evidence/plan-freeze-r17.md`；
- 13个status-capture blocks必须使用Bash 3.2-safe conditional capture；simple
  command与command substitution在`if`条件中捕获真实`$?`，pipeline必须在成功和
  失败分支的第一条语句立即复制完整`PIPESTATUS`。不得以`set +e`、`|| true`、
  silent fallback、只修`pgrep`或吞掉unexpected failure代替；
- probe必须以clean `/bin/bash --noprofile --norc`证明expected `rc=1`不触发
  `ERR` handler、command substitution保留stdout与真实rc、pipeline逐段状态不被后续
  command覆盖，且未保护的unexpected failure仍触发全局trap并保留真实rc；
- R16 freeze/Review16/driver/manifest及其pre-BEGIN absence事实全部immutable；
  R17使用全新的`r17-*` runtime paths、
  `/private/tmp/agentloop-r17-state.XXXXXX`与
  `/private/tmp/agentloop-r17-bundle.XXXXXX`，不得复用或补写R16路径。

R17无环信任链固定为：

```text
immutable predecessors + final six surfaces
  + r17-begin.sh + r17-bash32-probes.sh
  → r17-entry.sha256
  → plan-freeze-r17.md
  → reviews/17-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

115-entry `r17-entry.sha256`必须绑定R17 probe及R16
freeze/Review16/driver/manifest，但不包含自身、R17 freeze、Review17或任何
runtime `r17-*` artifact。Review17达到
`APPROVED — 0 P0 / 0 P1`只允许请求后续新的用户turn按
`freeze, Review17, driver, manifest`顺序逐字提供四个final SHA-256；probe由static
manifest传递绑定。Review17本身不执行任何门。

Review17通过并取得上述新四-hash授权前，继续禁止R17 external caller/BEGIN、
targeted/full test、build、matrix、source gate、bundle/sign、preview、产品/test/
App-script修改、Review02/acceptance、A3、commit、push、merge、release、
normal-data、外部与真实用户操作。

## 23. Review17 P1-01 and authorized R18 RanchArt preflight closure

职责隔离Review17只写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md`，
SHA-256
`c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`，
并判定`CHANGES REQUIRED — 0 P0 / 1 P1`。其唯一P1-01确认canonical Stage要求
RanchArt结构门在一次性授权消费前成立，但R17 leaf、freeze与driver把该检查放在
`authorization_consumed=true`之后；额外RanchArt节点因而可能在授权已经消费后才
被发现。Review17没有运行caller/BEGIN、targeted/full test、build、matrix、source
gate、bundle/sign或preview，没有修改产品/test/App scripts，也没有创建任何R17
runtime artifact/root。

R17 planning chain保持immutable：

| Artifact | Immutable SHA-256 |
|---|---|
| `evidence/r17-begin.sh` | `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f` |
| `evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199` |
| `evidence/r17-entry.sha256` | `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17` |
| `evidence/plan-freeze-r17.md` | `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` |
| `reviews/17-p1-plan-review.md` | `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe` |

R17从未得到Review17 approval或后续四-hash执行授权。以下12个R17 runtime paths
与`/private/tmp/agentloop-r17-state.*`、
`/private/tmp/agentloop-r17-bundle.*`全部保持absent：

- `r17-targeted-tests.log`
- `r17-verify.log`
- `r17-build.log`
- `r17-migration-matrix.log`
- `impl-report-r17.md`
- `evidence/r17-clean-boundary.log`
- `evidence/r17-bundle-provenance.log`
- `evidence/r17-source-gates.log`
- `evidence/r17-hash-manifest.log`
- `evidence/r17-preview-bootstrap.log`
- `evidence/r17-preview-cold-start.log`
- `evidence/r17-preview-smoke.png`

牧场主已授权R18只关闭Review17 P1-01，不改变产品架构、数据模型、allowlist、测试、
bundle语义或R15/R16/R17历史。R18必须满足以下单一根因合同：

1. `r18-begin.sh`只能定义一个phase-aware RanchArt verifier和一个immutable exact
   expected 27-path set；pre-consumption与post-activation两次检查必须调用同一
   verifier，不得复制两套算法或expected set；
2. 第一次调用是boundary exclusive-create与写
   `authorization_consumed=true`之前的**最后一个门**，必须以零repository write
   在119-entry static manifest已逐项核对27个RanchArt bytes后，重新读取source
   RanchArt，验证exact-path regular-file set、zero nonregular node与exact
   regular-file count=27；失败只能写console，保持授权未消费，不得创建任何R18 runtime
   path/root；
3. activation后、创建任何其他runtime artifact/root之前，第二次调用必须立即由
   同一verifier重新读取filesystem并把phase、exact-path/count/nonregular结构证据
   写入R18 hash log；结构证据落盘后，post-activation 119-entry static-manifest gate
   才另行逐文件重校27个RanchArt bytes，frozen
   derived-manifest constant只作identity记录，不由结构verifier另行重算。不得复用preflight
   boolean、临时snapshot或缓存结果；失败使整个invocation永久
   `REJECTED_CONTAMINATED`，不得在同一boundary重试；
4. 两次读取只收窄preflight→activation之间的TOCTOU窗口；R18不宣称原子filesystem
   lock、transaction或不存在剩余TOCTOU；任何未来需要原子锁的方案必须另开stage；
5. R17冻结的13个Bash 3.2 status-capture sites（2 pipeline、4 simple、7 command
   substitution）合同全部继承；immutable `r17-bash32-probes.sh`继续由R18 static
   manifest绑定，禁止复制或虚构`r18-bash32-probes.sh`。

R18 planning-only allowlist为六个current surfaces、`evidence/r18-begin.sh`、
`evidence/r18-entry.sha256`与`evidence/plan-freeze-r18.md`；未参与R18修订的职责隔离
reviewer唯一写`reviews/18-p1-plan-review.md`。119-entry static manifest精确等于
R17的115项，加上`r18-begin.sh`、immutable `r17-entry.sha256`、immutable R17
freeze与immutable Review17；它排除自身、R18 freeze、Review18及全部runtime
R18 artifacts。

R18无环信任链固定为：

```text
immutable predecessors + final six surfaces
  + r18-begin.sh + immutable r17-bash32-probes.sh
  → r18-entry.sha256 (119 entries)
  → plan-freeze-r18.md
  → reviews/18-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

Review18达到`APPROVED — 0 P0 / 0 P1`只允许请求后续新的用户turn按
`freeze, Review18, driver, manifest`顺序逐字提供四个final SHA-256。Review18与该
后续四-hash授权前，继续禁止external caller/BEGIN、targeted/full test、build、
matrix、source gate、bundle/sign、preview、产品/test/App-script修改、创建任何
`r18-*` runtime path或`/private/tmp/agentloop-r18-state.*`/
`/private/tmp/agentloop-r18-bundle.*`、Review02/acceptance、A3、commit、push、merge、
release、normal-data、外部与真实用户操作。

## 24. R18 pre-freeze blocker — exact R15 volatile roots are now absent

2026-08-02、在生成`r18-entry.sha256`、`plan-freeze-r18.md`或打开Review18之前，
只读symlink-aware复核确认以下两个exact R15 volatile paths均为`ABSENT`：

- `/private/tmp/agentloop-r15-state.Zq6Jvm`
- `/private/tmp/agentloop-r15-bundle.2xROcy`

R15 containment时已经写入repository的durable evidence仍保持原bytes：

| Artifact | Immutable SHA-256 |
|---|---|
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |

这些evidence只证明R15失败/containment当时两root被观察为canonical empty，不能证明
volatile `/private/tmp` paths从那时到现在连续存在。当前消失原因是`UNKNOWN`；没有证据
支持把它归因于reboot、OS cleanup、用户操作或任何agent。本轮没有agent删除、重建、
清理或复用这两个paths。

R18-A授权前的candidate SHA-256
`62568e234a17cc19e604e9321740077717dd588b55f2f3e7b7419d096aaa6302`
的`r18-begin.sh`仍要求两root继续存在且canonical empty，因此未来即使取得执行授权，
也会在pre-consumption、零repository write状态fail closed，并保持
`authorization_consumed=false`。职责隔离静态driver审计对该bytes判定
`PASS — 0 P0 / 0 P1 / 0 P2`；这不消除外部entry blocker。

禁止通过重建这两个paths来制造“持续保全”假象，也禁止静默放宽检查。安全的新合同
必须把历史观察与当前状态分开：`CANONICAL_EMPTY → ABSENT`是单向lifecycle；
`ABSENT`是tombstoned absorbing state，禁止`ABSENT → CANONICAL_EMPTY`。由于两个
exact paths已经被本轮观察为`ABSENT`，后续R18 freeze和driver必须要求它们继续
`ABSENT`；任何重新出现都代表重建或复用，即使是canonical empty directory也必须
fail closed。dangling/existing symlink、regular/special node、directory或
indeterminate同样拒绝。

`ABSENT`必须由`/private/tmp` parent enumeration成功且两个exact basenames均不存在
来证明，不能把probe failure当作absent；不得创建、删除、清理或复用任何R15 root。
pre-consumption只读分类必须保持零写入；新R18 evidence只记录
`pre_begin_observed_state=ABSENT`与`disappearance_cause=UNKNOWN`，不得写
`continuously preserved`。

该变更还会把R17继承的preserved-root `realpath` command-substitution capture一对一
替换为Bash 3.2-safe、联合两个exact basenames的parent-enumeration command-
substitution capture；现有empty-directory capture只继续服务fresh R18 roots，其他
capture blocks与immutable `r17-bash32-probes.sh`保持不变。修订后inherited合同仍为
`2P / 4S / 7C = 13`，另计既有R16/R17/R18 root-glob absence C后，driver总数仍为
`2P / 4S / 8C = 14`；R18 freeze与Review18必须同时核对“数量不变、其中一个C的职责
发生替换”，不能声称13 blocks逐字不变。无需新增probe文件，119-entry路径集合不变。
纯shell证明不宣称消除最后一次lstat之后的理论TOCTOU。

该入口合同变更当时超出“R18只关闭Review17 P1-01”的授权。在R18-A授权前：

- 不修改R15–R17 freeze/review/driver/logs或其历史结论；
- 不改变`r18-begin.sh`当前R15 root gate；
- 不生成`r18-entry.sha256`或`plan-freeze-r18.md`；
- 不打开Review18；
- 继续禁止全部execution gates以及产品/test/App-script修改。

当时的阻塞问题：是否补充授权R18-A，仅按上述tombstoned R15 volatile-root合同有界修订
current six surfaces与`r18-begin.sh`，随后生成路径集仍为119项但重算bytes后的
`r18-entry.sha256`、R18 freeze并执行职责隔离Review18；Review18通过且取得新的
四-hash授权前，继续禁止全部execution gates以及产品/test/App-script修改？

## 25. R18-A authorization — blocker resolved at plan level

牧场主随后以新的明确用户turn授权：

> 授权 R18-A，按 blocked.md §24 执行；Review18 通过并取得新四哈希授权前，继续
> 禁止全部执行门及产品/test/App-script修改。

因此§24的plan-level authority问题已关闭，但没有打开任何执行权限。R18-A只允许：

1. 在current six surfaces中把R15 containment时的historical canonical-empty观察与
   2026-08-02 current `ABSENT`事实分层；
2. 把两个exact paths冻结为absorbing tombstones，使用联合`/private/tmp` exact-
   basename parent-enumeration fail-closed proof；
3. 在`r18-begin.sh`中一对一替换preserved-root `realpath` C，保持inherited
   `2P / 4S / 7C = 13`、driver total `2P / 4S / 8C = 14`与immutable R17 probe；
4. 生成路径集合不变、重算final bytes的119-entry `r18-entry.sha256`和R18 freeze；
5. 由未参与修订的职责隔离reviewer唯一写Review18。

R15–R17 freeze/review/driver/logs及历史结论继续immutable。Review18必须核对
`r15_state_root_pre_begin_observed_state=ABSENT`、
`r15_bundle_parent_pre_begin_observed_state=ABSENT`、
`r15_state_root_current_absent=true`、`r15_bundle_parent_current_absent=true`、proof identity、
`disappearance_cause=UNKNOWN`、任何node重现/indeterminate parent enumeration均
fail closed，以及禁止`preserved_empty`/`continuously preserved`表述。Review18达到
`APPROVED — 0 P0 / 0 P1`仍不执行；只有其后的新用户turn按
`freeze, Review18, driver, manifest`顺序逐字给出四个final SHA-256，才可能打开
external caller。此前继续禁止全部execution gates、产品/test/App-script修改、
Review02/acceptance、A3、commit、push、merge、release、normal-data、外部与真实用户
操作。

## 26. Review18 P1-01 — newline pathname transport collision

职责隔离 Review18 唯一写入
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/18-p1-plan-review.md`，
SHA-256
`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`，
并判定 `CHANGES REQUIRED — 0 P0 / 1 P1`。Review18 没有运行 external caller、
`r18-begin.sh`/BEGIN、test、build、matrix、source、bundle/sign 或 preview，也没有
修改产品/test/App scripts 或创建 R18 runtime artifact/root。

唯一 P1-01 位于 `r18-begin.sh` 的 RanchArt structure verifier：真实 pathname 先经
`find -print` 变成 newline-delimited text，再进入 Bash command substitution、
`sed/sort/diff/wc -l`。macOS filename 允许 LF；因此一个 basename 为
`PixelBarnDay.png\nPixelBarnNight.png` 的 regular file 可以被解释为两个 expected
text lines，并替代两个缺失的 expected nodes。stable contaminated tree 因而可能在
pre-consumption verifier 中假绿、消费 one-shot authorization，再由 post-activation
119-entry content manifest 永久拒绝。该问题不是 §28.5 已诚实披露的 observation
之后 TOCTOU；它是 verifier 同一次稳定读取中的 non-injective serialization。

Review18 同时独立确认：R18 six surfaces、driver、probe、manifest、freeze identities
精确；119/119 strict manifest、R17 115 + exact four path set、R17 current 恰好六面
mismatch/其余 109 unchanged、R15 historical-empty/current-ABSENT tombstone、13/14
capture inventory、current absence、无环链与零产品/test/App-script delta均通过。
因此 R18/R18-A candidate 只因上述 P1-01 未获 approval；其 freeze、Review、driver、
manifest 四个 hashes 仅为失败审计链，永不构成执行授权：

- freeze：`62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`；
- Review18：`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`；
- driver：`911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；
- manifest：`71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`。

## 27. R19 authorization — lossless NUL pathname transport

planner 随后在新的用户交互中提出精确有界授权：只按 Review18 P1-01，把 RanchArt
actual direct-child enumeration 改为单一
`find -P ... -print0 | Bash 3.2 read -r -d ''` lossless pipeline；同步 six surfaces、
current capture inventory、fresh R19 driver、123-entry manifest、freeze 与隔离
Review19；允许仅内存、零文件写入的 Bash 3.2 pathname micro-probes；Review19 与
后续四-hash用户授权前继续禁止全部执行门与产品/test/App-script修改。牧场主紧接着
明确回复：

> 继续，授权

因此 R19 planning authority 已打开，但没有打开 execution authority。精确边界是：

1. planner 只修改 current six surfaces，并新增 `evidence/r19-begin.sh`、
   `evidence/r19-entry.sha256`、`evidence/plan-freeze-r19.md`；未参与这些修订的职责
   隔离 reviewer 唯一新增 `reviews/19-p1-plan-review.md`；
2. R18 driver/manifest/freeze/Review18 全部 immutable；R19 manifest 精确继承 R18
   119-path coverage且无删除，只增加 R19 driver、immutable R18 manifest、R18
   freeze 与 Review18，共 123 项；six surfaces 更新后，旧 R18 manifest 必须恰好
   six mismatch、其余 113/119 unchanged；
3. R19 只有一个 phase-aware verifier 与一个 27-name ASCII expected array。actual
   universe 必须由 `find -P` 无损枚举全部 direct children，包括 dotfiles、symlink、
   dangling symlink、directory 与 special nodes；NUL stream 不得进入 `$()` 或任何
   line transport；
4. inline Bash 3.2 validator 必须完整 drain stream，检测 partial final record，以
   `LC_ALL=C`、关闭 `nocasematch` 后比较 enumeration 返回的 actual basename bytes，
   使用 27-slot seen map 与 directory-entry count，并逐 actual node证明
   `-f && ! -L`。missing、extra、case variant、LF/CR/control name、Unicode confusable、
   dotfile或nonregular均fail closed；失败日志不得 raw serialize未验证pathname；
5. 旧 RanchArt `1S + 4C` 五个 capture blocks由一个 NUL pipeline `1P`替换。R19
   current core inventory必须诚实更新为`3P / 3S / 3C = 9`，另计覆盖
   R16/R17/R18/R19 fresh-root glob的一个C后driver total为
   `3P / 3S / 4C = 10`；immutable `r17-bash32-probes.sh`保持原bytes，不新增probe
   artifact；
6. pre-consumption调用继续是boundary exclusive-create前最后一个fallible
   precondition；post-activation在hash log后立即重读。两次都使用同一lossless算法，
   成功后才可按已证明等于safe expected ASCII的固定顺序写exact-set evidence；独立
   123-entry content manifest仍在post structure后执行；
7. R19必须使用全新12个`r19-*`/report paths与
   `/private/tmp/agentloop-r19-state.*`、`/private/tmp/agentloop-r19-bundle.*`，并在
   pre-BEGIN保全全部R16/R17/R18 runtime absence与R15 absorbing tombstones；
8. Review19达到`APPROVED — 0 P0 / 0 P1`仍不执行。只有其后的新用户turn按
   `freeze, Review19, driver, manifest`顺序逐字给出四个final SHA-256并明确授权，
   才可能打开一次clean external caller；此前继续禁止caller/BEGIN、test、build、
   matrix、source、bundle/sign、preview、产品/test/App-script修改、Review02/
   acceptance、A3、commit、push、merge、release、normal-data、外部与真实用户操作。

## 28. R19 authoritative full-test rejection and R20 planning authorization

Review19最终以
`4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`
判定`APPROVED — 0 P0 / 0 P1`。牧场主随后按顺序提供R19 freeze
`d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f`、Review19、
driver `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d`、
manifest `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`
并授权execution。R19 invocation成功BEGIN且41/41 A2 tests通过，但唯一一次未过滤
`swift run RunTests`为651/652；唯一失败是`slowActiveStreamDoesNotIdleTimeout`，
`AgentLoopTests.swift:611`，`idle script exhausted`。boundary永久
`REJECTED_CONTAMINATED`，不得重跑。build/release、matrix、source、bundle/sign、
preview与END未运行；产品/test零漂移。11个实际artifacts、缺失screenshot及
`/private/tmp/agentloop-r19-state.dNgUXh`、
`/private/tmp/agentloop-r19-bundle.49xVDm`两个real non-symlink empty roots全部
immutable，不得补写、删除、清理或复用。

planner随后提出R20 planning-only exact scope；牧场主在紧接的新turn回复：

> 继续，授权R20

该回复只授权紧邻的R20 planning proposal，不是execution authority。精确边界：

1. planner只同步current six surfaces并新增`evidence/r20-begin.sh`、
   `evidence/r20-entry.sha256`、`evidence/plan-freeze-r20.md`；职责隔离reviewer唯一写
   `reviews/20-p1-plan-review.md`；
2. future implementation仅可修改`AgentLoop.swift`与`AgentLoopTests.swift`。private
   factory+single generic `IdleWatchdog<C: Clock>`复用真实算法；public init不变，
   production默认`ContinuousClock`；仅`#if DEBUG` package generic initializer以exact
   external label`idleClockForTesting`注入。test type精确`ManualAgentLoopClock`，
   NSLock+unique waiter+checked continuation、锁外resume、cancel/advance exactly-once；
3. 五项exact tests为`slowActiveStreamDoesNotIdleTimeout`、
   `turnTimeoutRetriesOnceThenBlocks`、`timeoutThenSuccessDoesNotAccumulate`、
   `cancelWinsOverIdleTimeout`、`turnCompletesUnderTimeout`。cancel case先cancel并等待
   cancellation barrier确认waiter移除/恢复，再advance；覆盖cancel-before-register与
   register-before-cancel，不宣称simultaneous tie；
4. 禁止timeout/interval放大、`.serialized`、skip/filter、RunTests并发修改、failure
   retry、script-step复制、吞错、fake watchdog、public/release test seam；
5. 140-entry manifest继承R19 123项并增加R20 driver、R19 manifest/freeze/Review19、
   11个actual R19 artifacts及两个source baselines。pre-edit 140/140；post-edit exact
   138 unchanged + two authorized mismatches；
6. R20使用fresh 12个`r20-*`/report names与`agentloop-r20-{state,bundle}.*` roots；
   R19 evidence/roots永久只读；
7. Review20与后续按`freeze, Review20, driver, manifest`顺序的新四hash授权前，继续
   禁止caller/BEGIN、任何test/build/matrix/source/bundle/sign/preview、两个source/
   test修改、Review02/acceptance、A3及commit/push/merge/release/normal-data/外部/
   真实用户操作；
8. future execution只运行一次未过滤full RunTests；失败永久stop。full全绿后从同一
   log机械审计原41+新增5为46/46并写targeted log，不运行filter/第二次test。

## 29. R20 release-build rejection and R21 planning-only authorization

Review20以
`e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`
判定`APPROVED — 0 P0 / 0 P1`。牧场主随后在新用户turn按顺序提供R20 freeze
`0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07`、Review20、
driver `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`、
manifest `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`
并授权clean execution。R20 invocation
`r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`成功到达`BEGIN_ATTESTED`；只修改冻结的
两个文件，最终SHA-256为：

- `AgentLoop.swift`：
  `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`；
- `AgentLoopTests.swift`：
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。

唯一一次未过滤`swift run RunTests`为652/652、7/7 suites全绿；同一日志机械审计
46/46 exact names全绿。debug App build、fresh bundle、single ad-hoc sign、
POST_BUILD/PRE_SIGN/LAUNCH_READY全部通过。随后冻结命令
`swift build -c release --product AgentLoopCore`返回1：SwiftPM明确警告
`AgentLoopCore`是automatic product并退化为default-target graph，继而在release
configuration编译`AgentLoopTestSuite`；test caller仍传入仅在`#if DEBUG`存在的
`idleClockForTesting` initializer，报`extra argument 'idleClockForTesting' in call`。

R20 boundary已永久写入：

```text
status=REJECTED_CONTAMINATED
phase=release_core_build
reason=release_AgentLoopCore_build_failed_rc_1
exit_code=1
retry_same_boundary=false
```

release/debug symbol gates、matrix、source/privacy/final hash gates、preview与END均未运行；
没有重跑、原地修补、补写空日志或创建Review02/acceptance。R20的652/652、46/46与
LAUNCH_READY是immutable partial evidence，不能把整个R20 invocation洗绿。

R20实际11个repository runtime artifacts、缺失的`screenshot`与两个retained roots
全部immutable。state root
`/private/tmp/agentloop-r20-state.3QwlQa`是real non-symlink empty directory；bundle
parent `/private/tmp/agentloop-r20-bundle.30V5RH`是real non-symlink directory且direct
child精确为保留的`AgentLoop.app`，不能误写为empty。保留App的executable SHA-256为
`d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`，Info.plist为
`5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`，signed bundle
manifest identity为
`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。不得覆盖、
追加、删除、清理、移动、重命名、重新签名、启动或复用这些artifact/root/App。

牧场主随后逐字授权R21 planning-only，只关闭同一个
`SwiftPM automatic-product fallback + DEBUG caller/callee configuration mismatch`
根因。本轮planning authority精确为：

1. 只同步current六面（其定义已经包含A2 leaf与本blocker）；
2. 新增BEGIN-only `evidence/r21-begin.sh`、155-entry
   `evidence/r21-entry.sha256`与`evidence/plan-freeze-r21.md`；
3. 由未参与R21修订、driver/manifest/freeze生成的职责隔离reviewer唯一写
   `reviews/21-p1-plan-review.md`；
4. R20 `AgentLoop.swift`最终bytes必须保持精确不变；future implementation唯一允许
   在`AgentLoopTests.swift`增加三对matching direct `#if DEBUG/#endif`：第一对包围
   `ManualAgentLoopClock`、`ControlledIdleProviderError`、
   `ControlledIdleProvider`、`AgentEventProbe`、`OneShotGate`；第二对只包围
   `startControlledLoop`；第三对只包围从`turnTimeoutRetriesOnceThenBlocks`至
   `turnCompletesUnderTimeout`的五个exact tests。不得移动、删除、重排或修改任何
   既有逻辑、空白或其他bytes；
5. future source gate必须证明TestSuite source恰有三对direct DEBUG regions、无nested
   conditional、`#else`或`#elseif`，11个冻结token全部位于guard内；机械移除这六行
   directive后的SHA-256必须精确恢复R20 final test hash
   `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`；
6. release Core gate精确改为
   `swift build -c release --target AgentLoopCore`；另加独立
   `swift build -c release --target AgentLoopTestSuite`，证明regular test target的
   release graph本身可编译。禁止`--product AgentLoopCore`与default graph fallback；
7. exact constructed object paths必须来自SwiftPM同configuration的canonical
   `--show-bin-path`，禁止`find -quit`挑第一个、搜索替代object或固定共享`/tmp` nm
   文件。release `AgentLoop.swift.o`的`idleClockForTesting` count必须为0、debug必须
   大于0；release `AgentLoopTests.swift.o`的上述六个helper token与五个test token
   各自必须为0、debug各自必须大于0。`nm -j | xcrun swift-demangle`任一端失败、
   空输出、object缺失/非regular/symlink/路径布局漂移或count异常均fail closed；
8. R21 static manifest完整继承R20 140 paths且不删除，并增加R21 driver、immutable
   R20 manifest/freeze/Review20与11个R20 runtime artifacts，共155项。六面同步后，
   immutable R20 manifest对current filesystem必须恰好132 unchanged + six-surface与
   两个R20 implementation files共8 mismatch；R21 implementation前155/155，guard
   实施后必须154 unchanged + `AgentLoopTests.swift`唯一authorized mismatch，Core仍
   匹配entry hash；第二个mismatch立即失败；
9. R21使用全新12个`r21-*`/report paths与
   `/private/tmp/agentloop-r21-state.*`、`/private/tmp/agentloop-r21-bundle.*`。driver
   在授权消费前后都重证R19与R20 containment；R20 signed App必须由all-node NUL
   validator锁exact 36 nodes（6 directories + 30 regular files）、逐文件hash并只从固定
   safe literals复算signed manifest，禁止`-type`缩小universe或序列化actual pathname，
   失败只记录四段safe numeric statuses。capture inventory按ERR-trap-facing outer
   unique parent blocks计数，inline validator子状态不重复计数；current core精确为
   `8P / 4S / 8C = 20`，计R16/R17/R18/R21
   fresh-root-glob C后driver total `8P / 4S / 9C = 21`；R20的15/16只作immutable历史；
10. future R21仍只允许一次未过滤`swift run RunTests`；R20的652/652不替代R21 full
    run。full绿后才从同一log机械提取46/46。随后唯一顺序为debug App build → fresh
    bundle assembly/sign及LAUNCH_READY → pre-release guard-shape/strip source sub-gate →
    target-exact release gates → 四object gates → matrix → remaining source/privacy/
    final-hash gates → same-bundle preview → END；每步fail once，任一失败永久拒绝本
    boundary且不得重试、补丁或换object/root。

本轮不允许运行external caller、`r21-begin.sh`/BEGIN、任何test/build/matrix/source/
bundle/sign/preview，不允许现在实施上述test guard，也不允许修改`Package.swift`、
产品逻辑、public/package API、target/dependency/package edge、schema/migration或其他
产品/test/App/RunTests/matrix script。Review21达到`APPROVED — 0 P0 / 0 P1`本身仍
不执行；只有其后的新用户turn按`freeze, Review21, driver, manifest`顺序逐字提供四个
final SHA-256并明确授权，才可能打开一次fresh R21 caller。Review02、acceptance、A3、
commit、push、merge、release、normal-data、外部与真实用户操作继续关闭。

## 30. R21 pre-BEGIN stop and authorized R22 bounded disposition

牧场主给出的R21 exact terminal anchors依次为freeze
`82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4`、Review21
`13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b`、driver
`c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`、manifest
`d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`。clean external caller
核对四锚与155/155成功；`r21-begin.sh`随后在`pre_begin_r19_containment`以70 fail closed。
R21 boundary、hash log、其余12 runtime paths、UUID及两个fresh roots均未创建，故事实只能是
`PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — ZERO WRITE`。这次授权未被消费；禁止补写、
继续或重跑R21。Core/TestSuite仍精确为R20 final
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`/
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。

根因不是R21计划的release guard，而是volatile historical root状态已变化：R19 exact state/
bundle roots及R20 exact state root现为ABSENT；R20 exact bundle仍只可按实际验证结果分类。
牧场主授权R22仅关闭该同一根因，并把standing Goal明确为“不需要哈希值每步确认，继续完整
落地”。因此本轮允许且只允许planner同步六面，创建fresh `r22-begin.sh`、159-entry
`r22-entry.sha256`与`plan-freeze-r22.md`；职责隔离reviewer之后唯一写
`reviews/22-p1-plan-review.md`。Review22通过前不运行driver或任何execution gate，不修改产品/
test/App scripts。

R22 disposition逐字为：

1. R19 state/bundle及R20 state从historical canonical empty进入原因UNKNOWN的
   `ABSENT_TOMBSTONE`，ABSENT absorbing；以`-e || -L`bookends和完整NUL-safe
   `/private/tmp` top-level enumeration验证，任何variant/reappearance都失败；
2. R20 bundle只允许verified retained保持或单向absent。retained必须重新通过canonical
   parent、exact child、36-node all-node set、30 hashes、aggregate及strict codesign；验证
   failure不能被reclassify为disappearance；first-observed state不可被重复pre覆盖，同一次
   initial/late bookend不接受retained→absent；
3. R22 driver必须在authority消费前后重证R21 12 paths与historical root globs absent，并保留
   R21 zero-write；只有本进程exclusive-create boundary成功才消费，EEXIST零append；设ACTIVE
   后立即恢复signals，partial initialization/signal永久rejected并补写recovery authority
   evidence，消费后的第一批只读动作立即复证R21/R19/R20；
4. manifest为`159 = R21完整155 + R22 driver + R21 manifest/freeze/Review21`；旧R21 manifest
   对六面变化精确149 pass + 6 mismatch，R22 implementation前159/159，之后158+Test唯一；
5. R22 fresh runtime只能用12个`r22-*`/report paths与两个`agentloop-r22-*` roots，不能复用
   R19–R21 names或覆写任何历史artifact；
6. Review22必须由未参与R22 planner writes的独立reviewer唯一写，正文含唯一exact
   `Verdict: APPROVED — 0 P0 / 0 P1`行且无其他`Verdict:`行，machine block含12项authority/reviewer/hash/branch/HEAD/count
   self-attestation。该block仅提供local consistency，不冒充human anti-rewrite；
7. Review22零P0/P1后，agent先确认无更新用户turn撤销standing authority，再自动计算
   Review22 SHA并只把这一参数交给driver；无需再次要求用户回传四hash；
8. 产品delta仍仅为`AgentLoopTests.swift`三对/六行matching DEBUG directives，Core与其余
   product/test/App-script bytes不变；执行/完成/Review02/acceptance顺序见Stage §28.9与leaf
   §13，任一failure永久拒绝且不得retry。

Review22通过前继续禁止caller/BEGIN、RunTests、build、matrix、source gate、bundle/sign、
preview、产品/test/App-script修改、Review02/acceptance与A3。即使Review22通过，standing
authority也不扩大commit/push/merge/release、normal-data、外部或真实用户权限；这些继续关闭。

## 31. Review22 partial-skeleton blocker and authorized R23 bounded disposition

职责隔离Review22 SHA
`bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5`
的唯一结论为`CHANGES REQUIRED — 0 P0 / 1 P1`。它没有approval machine block，因而R22
没有caller、BEGIN、execution gate、runtime write、fresh root或产品/test/App-script修改；
R22 authority未消费，12 paths与`agentloop-r22-*` globs保持ABSENT。R22六面、driver
`55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713`、
manifest `57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8`、
freeze `839a46ad50d8bb943240267679e5878613d7ee42b5664106b4dc5b0a3dc1a8bf`
与Review22均为immutable predecessor。

Review22反复只读观察到R20 bundle parent/App present，但App只有六个historical directories、
零files，Info.plist/executable/CodeResources与27项art均absent，codesign rc1。该状态既不是
R22 verified-retained，也不是bundle absent，故R22 deterministic pre-BEGIN stop是plan
blocker而不是产品/release根因。牧场主授权R23只关闭这一同一根因：同步六个current control
surfaces并新增`r23-begin.sh`、随后`r23-entry.sha256`与`plan-freeze-r23.md`；Review23通过前
仍禁止全部execution gate和产品/test/App-script修改。

R23 bounded disposition逐字为：

1. 固定38-bit order为R20 exact parent、App与原36-node顺序；Review22 baseline固定为
   `11101011100000000000000000000000000010`。首个A前先比baseline→A；之后只允
   LATEST→A→B逐bit 1→0。FIRST保存首个A，LATEST保存B。
2. 单capture必须full-NUL-drain top-level、exact child与App subtree；subtree validator在
   同一drain内直接输出mask/counts，随后末端重证parent/App presence/type/realpath/shape。
   read/find/hash/type/shape/status失败fatal，不能编码为deletion。
3. CAPTURE/counts是诊断working registers，A/B capture会在比较前reset/mutate，失败时可
   保留incomplete/A/B staging；它们不是accepted lifecycle state。所有比较先于
   FIRST/LATEST与accepted mode-B commit；失败时只保证这些已接受值保持pair开始前状态。
   in-process assignment临界段只把HUP/INT/TERM变为defer-only，全部FIRST/LATEST、final
   CAPTURE/count normalization与accepted mode-B赋值后立即恢复fail handlers并按deferred
   signal永久拒绝。active failure记录safe global baseline/FIRST/LATEST及诚实的diagnostic
   CAPTURE staging。
4. current signed claim仅在all-one、36/6/30、aggregate与strict codesign全过时合法；当前
   baseline使该分支不可达，partial只能引用historical hashes。不得恢复、删除、清理、移动、
   重签或以任何方式修改R20 root。
5. manifest精确
   `163 = complete R22 159 + R23 driver + R22 manifest + R22 freeze + Review22`；planner
   六面后R22 manifest为153+six mismatches，R23实施前163/163，实施后162+Test唯一。
6. R22 12 paths/roots在pre、final-pre、immediate-post、post-root持续ABSENT；R23只用fresh
   12 paths及`agentloop-r23-*` roots。capture inventory冻结为`8P / 4S / 13C = 25`。
7. Review23由未写R23 planner artifacts的职责隔离reviewer唯一写，只有一个exact approved
   verdict与12-line machine block，authority mode为
   `standing_goal_automatic_after_review23`、count 163。批准且Goal未撤销后automatic caller
   只传Review23 SHA，无新用户hash echo。
8. future source delta与gate order零变化：TestSuite三对/六行DEBUG directives，然后唯一
   full RunTests、46/46、debug bundle、target-exact/four-object、matrix/source、preview、
   END；任一failure永久拒绝。

R23不提供filesystem transaction、filesystem lock或atomic snapshot，也不证明
inode/hardlink、xattr或resource fork不变，不能消除TOCTOU；完全发生并消失在两个capture
可见窗口之外的短暂节点可能不被观察到。本文的“原子”只指所有比较通过后，当前进程一次性
提交FIRST/LATEST变量。若未来要求原子文件系统保证，必须另开stage并重新Review。

R23 planner scope之外的caller/BEGIN、RunTests、build、matrix、source/bundle/sign/preview、
guard实施、Review02/acceptance、A3、commit/push/merge/release、normal-data、外部及真实用户
操作全部继续关闭。

## 32. R23 shell-carrier rejection and authorized R24 bounded disposition

R23在approved freeze内完成BEGIN与唯一source delta；唯一full-test process完整输出652/652，
但负责status capture的外层wrapper实际是zsh，`${PIPESTATUS[@]}`未定义，故Swift/tee rc均未
捕获。R23按freeze fail closed并永久`REJECTED_CONTAMINATED`，没有46/46、build、bundle、
release、matrix、source、preview或END。十个logs、`impl-report-r23.md`、两个exact empty roots、
planned App/executable及screenshot absence均冻结；失败后一次stdout-only strip/hash诊断已在
report披露但不构成formal gate。

R24授权只关闭同一Bash carrier根因，边界如下：

1. source delta=0；Core/Test current hashes固定，禁止再改产品/test/App/Package/matrix script；
2. 178-entry manifest完整继承R23 163 paths并只加R24 driver、R23 manifest/freeze/Review23、
   十个R23 runtime logs与final report；entry/mutation前/matrix恢复后/END为178/178。仅既有matrix
   script line115 Stage-hash窗口为177+script唯一mismatch；所有路径mandatory恢复，失败只能
   恢复并永久reject；source delta=0只指产品/test/App与永久script bytes；
3. R23 roots用fixed two-bit baseline11、full top-level NUL universe、exact empty present branch、
   A/B `BASELINE/LATEST→A→B`只1→0与defer-signal commit；erosion cause UNKNOWN，unchanged写
   NOT_OBSERVED；继承R20 38-bit、R19 tombstone及R16–R18/R21/R22 zero-write；
4. clean caller明确使用system Bash 3.2，unset BASH_ENV/ENV/CDPATH。BEGIN后full-test pipeline
   必须在同一reviewed driver内运行，then/else第一句复制完整PIPESTATUS，shape 2、numeric、
   UNKNOWN→component rc→captured flag，只有0/0与唯一652/652继续；verify log冻结SHA/bytes；
5. Review24由未写R24 planner artifacts的独立reviewer只写Review24，唯一approval verdict与
   12-line machine block，count 178；standing Goal允许批准后automatic caller，无hash echo；
6. handoff后才按same-log 46/46、debug bundle、formal strip、target/four-object、matrix/source、
   same-bundle preview、final lifecycle、END推进；每个Bash-only capture必须显式Bash 3.2；
7. 任一失败永久reject，不retry、不patch、不清理、不换root/object；Review02/acceptance/A3、
   commit/push/merge/release/normal-data/外部/真实用户继续关闭。

R24不提供filesystem transaction/lock/atomic snapshot，也不证明inode/hardlink/xattr/resource
fork不变或消除capture窗口外TOCTOU；变量commit只约束in-process accepted state。

Review24通过前禁止caller/BEGIN、任何test/build/matrix/source/bundle/sign/preview及R24 runtime
write。若发现超出同一shell-carrier根因的新架构、数据、依赖、产品或测试决策，必须写回本
文件并停止，不能用R24扩大权限。

## 33. R24 final single-process clean-execution contract

本段是六个控制面的同一份最终 current override；它取代本轮较早的 R24 `handoff`、普通
`mv`、`kill -0` ownership 与 boundary 忽略信号措辞，但不改写 R15–R23 immutable 历史。
R24 仍是 source delta 0：Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`；178-path manifest
方程、R23 的 156 unchanged + 7 expected mismatches、R23 163 paths + 15 additions、
R20/R23/R15 历史与 zero-write red lines 全部保持。R24 manifest 排除自身、freeze、Review24、
12 个 R24 runtime paths、两个 fresh roots，以及 invocation-owned hidden publish stages。

1. caller 只可用冻结的 clean `env -i` 与 system Bash 3.2 调用 driver，并只传 Review24 SHA。
   从 BEGIN、唯一 full test、全部 mechanical gates、两次 preview 到 END 必须在同一个 reviewed
   Bash process 内完成，不存在 caller continuation 或 handoff。canonical cwd/self、exact env、
   branch/HEAD、Review24 machine block、178/178、predecessors 与 source hashes 在 preflight 和
   final pre-BEGIN 重证。BEGIN boundary 使用 defer-only HUP/INT/TERM window 与 O_EXCL；成功后先
   `BOUNDARY_ACTIVE=true`、恢复 fail traps并立即消费 deferred signal。EEXIST 只 pre-BEGIN fail，
   不 append、不消费 authority；成功消费后的任一普通 signal/failure永久
   `REJECTED_CONTAMINATED`。

2. driver 独占创建 fresh verify log，并在同一顶层 Bash 运行唯一 unfiltered
   `swift run RunTests | tee`；then/else 第一条都复制 exact two-element `PIPESTATUS`，随后在
   defer-only commit 中写 Swift rc、tee rc、`status_captured=true`。只允许 `0/0`、唯一
   `652/652`、7 suites/0 failures 与 same-log 46/46 继续。之后顺序固定为 debug build → fresh
   signed bundle → guard strip → target-exact Core/TestSuite release → four object symbol gates →
   matrix 177+1 window及mandatory restore → source/privacy → same-bundle preview → final reproof →
   staged report/END。matrix backup、mutated stage、restore stage各有独立 OWNED flag，只能在各自
   O_EXCL成功后置true；禁止预删，copy/write只落到owned path，成功publish/cleanup即清flag；
   EEXIST保留unowned path并reject。success/error/signal只按exact ownership恢复或清理；恢复失败
   只能继续containment并永久reject。

3. R24 fresh state/bundle roots初始都必须 exact real non-symlink empty。current phase 只允许：
   `empty`；`bundle_ready`；`preview_live` 时 state exact
   `{.agentloop.lock, agentloop.sqlite, agentloop.sqlite-shm, agentloop.sqlite-wal}`；
   `preview_quiescent` 时 exact base two，且 WAL/SHM 必须成对同时 absent 或同时为 regular file，
   禁止 extra。R23 two-bit baseline `11`与R20 38-bit universe继续以完整 A/B capture只允
   1→0；R15 exact tombstones、alternate identities与全部 predecessor zero-write逐门 fail closed。

4. fresh bundle 使用 invocation-unique合法 `CFBundleIdentifier`，signed `Info.plist` 只带 exact
   `LSEnvironment` 的 isolated state root 与 preview=1；bootstrap 与 cold 都直接执行同一个 exact
   signed executable，显式传两项 env、stdin `/dev/null`、PID 只取 `$!`，不得用 `open`、display
   name、bundle-id fallback或 `pgrep` 建立 ownership。launch 前将 signals 改成 defer-only，覆盖
   fork、`$!` assignment、PPID/lstart capture；identity commit后恢复 fail traps并消费 deferred。
   containment与正常 Quit 都以两轮稳定 `jobs -pr`/`jobs -ps` running+stopped membership为 Bash
   active-job gate；TERM/KILL 前即时再验 `PPID==driver $$`，已 commit 时还须 exact `lstart`。
   pre-exec command mismatch只作诊断，不能阻止已证明 owned child的containment；active set absent
   才消费 cached `wait`，禁止用 `kill -0` 对可能已复用的 OS PID 作 kill authorization。

5. bootstrap B01–B06 exact flow 为 onboarding → `进入我的营地` → dashboard 唯一 feed hero且
   `查看全部` 0 → App menu → 唯一 `Quit AgentLoop` → Quit；随后只在 isolated DB 事务安装
   `a2-preview-ingestion-recovering` / `a2-preview-work-recovering` fixture，标题`隔离恢复验证`、
   raw text `A2 isolated synthetic rumination fixture`、ruminating attempt 1、queued attempt 0/
   max 4、canonical input/trace/idempotency/nullables/FK/integrity均 exact。cold C01–C09 为
   dashboard `查看全部 1`唯一 → inbox fixture/`查看进度`唯一 → recovering detail；C05 exact
   metrics 是标题1、`保存原文，已完成` 2、`正在恢复，正在进行` 3、后三阶段0；C06只复制 C05
   已有 screenshot URL 到 exact raw path，不再读取 UI 或执行 UI action；随后 menu/Quit。
   每个观察使用完整 app path、full state、`disableDiff=true`、nonce exact reply、unique label
   count；坐标与 fallback 禁止，B06/C09 后不得再调 UI。

6. screenshot raw file先验 magic/bytes/SHA；normalization stage必须在 evidence 同目录以
   invocation path O_EXCL 创建并标记 owned，`sips`只写该 owned path，随后完成 PNG header/IHDR、
   dimensions、full decode/MIME/SHA。publish 前即时重证 fixed final absent，使用 `mv -n`，且
   stage absent、final regular non-symlink、final SHA等于 staged SHA才发布成功。no-op/EEXIST
   只能清本 invocation owned stage，绝不覆盖或删除 unowned final；成功后 raw/stage清理，failure
   的 isolated raw保留为 contaminated evidence。

7. `impl-report-r24.md`同样先写 task 同目录 invocation-owned O_EXCL hidden stage，完成内容、
   privacy、type 与 SHA 后才发布。final 前即时 absent，`mv -n`后必须 stage absent、final regular
   non-symlink且 exact staged SHA；active failure只可删除 owned stage，或在 END 尚未 commit 且
   published final仍匹配 exact staged SHA时删除，绝不删除 unowned/tampered final。report publish
   window 的 deferred signals在 postconditions 后恢复 normal traps并立即永久reject。唯一
   commit-wins 例外只从随后 fresh tiny END-append window 开始：一次写入以 `status=END`、
   `result=PASS`结尾的完整 block；成功后同一 simple command设置 `END_COMMITTED=true` 与
   `BOUNDARY_ACTIVE=false`，再清 traps。END 前或 append failure都清理未提交 PASS report并写
   `REJECTED_CONTAMINATED`；END commit后不得再追加 rejected。

8. evidence 只允许声称所有已观察 preview processes 为 exact isolated direct children、normal
   root observed-open count为0、未观察到replacement；不得声称覆盖未观察区间、filesystem
   transaction/lock、零 preference write或绝对没有 TOCTOU。invocation-unique UserDefaults
   onboarding write必须在report披露。Review24仍须职责隔离、唯一 `APPROVED — 0 P0 / 0 P1`
   与唯一12-line machine block（standing Goal automatic/no hash echo、three hashes、branch/
   HEAD、count 178）。Review24与新 freeze/manifest完成前继续禁止 caller/BEGIN、所有 execution
   gates、Review02/acceptance/A3及任何产品/test/App/permanent-script修改；commit/push/merge/
   release、normal-data、外部沟通与真实用户操作始终未授权。

## 34. R24 guard-parser rejection and authorized R25 bounded disposition

本段是六个控制面的同一份最终 current override；它不改写 R15–R24 immutable
历史，只把 R24 已证明的 harness false negative 与 R25 的唯一修订路线设为 current。
R25 的 source/product/test/App/permanent-script delta 精确为 0；Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`，matrix script 固定
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R25 不重新解释、
补写、清理、删除、重命名或复用任何 R24 evidence/root。

1. R24 freeze `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、
   Review24 `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、
   driver `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`
   与 178-entry manifest
   `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`
   均 immutable。R24 唯一 BEGIN 内的 authoritative Swift/tee rc 是 `0/0`，terminal
   `652/652`、7 suites/0 failures、same-log `46/46`、debug build、fresh signed bundle 与
   `LAUNCH_READY`均通过；随后 guard gate 以
   `reason=core_guard_shape_1:1::0:1:1`、phase `guard_shape_and_strip`、exit 70
   永久 `REJECTED_CONTAMINATED`。这些 partial green 既不等于 END，也不得替代 R25 的
   full rerun、Review02 或 acceptance。

2. 同一根因是 awk 未初始化数字在字符串拼接时渲染为空：Core parser 的 `bad` 实际为数值
   0，却输出 `1:1::0:1:1`；未到达的 TestSuite parser 具有同样潜在输出
   `3:3:6::0:1`。R25 只做 render-only numeric closure，不改变任何 predicate、token、
   guard line、source byte、test logic、build command、API、schema、migration 或产品语义：
   Core 六字段 `opens/closes/bad/depth/token/guarded`、TestSuite 六字段
   `opens/closes/directives/bad/depth/ok`均以 `+ 0`输出；same-log 顶层七个计数
   `run_started/test_started/test_passed/suite_started/suite_passed/failure_markers/summary`
   同样以 `+ 0`输出；matrix 两个 line scanner 只把 diagnostic
   `count/line`渲染为 `(count + 0):(line + 0)`。逻辑条件与失败语义逐字保持。

3. Core 与 TestSuite guard parser 各只有一个 pure helper。preflight 与 final pre-BEGIN
   都复用同一 helper，必须在 authority consumption、verify-log 创建和 full test 前分别得到
   exact `1:1:0:0:1:1`与`3:3:6:0:0:1`；active
   `guard_shape_and_strip`再次调用同一 helper，不复制第二套 parser。任何空字段、非 exact
   output、read failure 或 source drift 都在对应边界 fail closed；pre-BEGIN failure保持
   零 repository write且不消费 authority，BEGIN 后 failure永久reject。

4. R24 的十个既有 runtime files由 R25 逐一以 exact SHA、regular/non-symlink type和关键
   boundary事实重证：唯一 rejection、captured `0/0`、652/652、46/46、launch-ready、
   matrix restore-attempt count 0、matrix未mutation、无preview owned process、无END。
   `r24-migration-matrix.log`、source、bootstrap与cold logs是合法zero-byte historical
   artifacts；`impl-report-r24.md`与`r24-preview-smoke.png`必须继续 absent。R24 state root
   `/private/tmp/agentloop-r24-state.Qko2Y3`与bundle root
   `/private/tmp/agentloop-r24-bundle.OPfuVv`只作为historical observation，不是R25运行输入。

5. R24 root lifecycle固定39-bit universe：state root、bundle parent、App与exact 36个
   descendants（6 directories、30 regular files），planning baseline为39个`1`。present
   state必须exact canonical empty；present bundle/App/node必须exact identity、type与每文件hash，
   无extra/symlink/special/wrong type/hash；full 36-node set另须aggregate
   `1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e`、
   strict codesign与CDHash
   `17bd20ada27ef9e69d0de007b49c53d01ddf48a6`。每次observation完整A/B双capture，
   `BASELINE/LATEST→A→B`只允1→0；FIRST/LATEST/accepted-B只在全部比较通过后的同一
   defer-signal commit写入，0→1、alternate、indeterminate或substitution永久reject。R25从不
   mutate/clean这些roots；R23 two-bit、R20 38-bit、R15 tombstones及所有zero-write
   predecessor gates继续保留。该观察不提供filesystem transaction/lock，不证明inode/hardlink、
   xattr/resource fork或消除TOCTOU；未观察区间不能外推。

6. R25 static manifest精确为`192 = R24 178 + 14`：完整R24 path set，加fresh R25 driver、
   immutable R24 manifest/freeze/Review24及十个R24 runtime files。六面同步后旧R24 manifest
   必须精确`172 unchanged + 6 expected control-surface mismatches`；TestSuite不再是mismatch。
   manifest排除自身、R25 freeze、Review25、12个R25 runtime paths、两个fresh roots与全部
   invocation-owned hidden stages。entry、每个mutation边界、matrix restore后与END必须
   `192/192`；唯一matrix窗口只允许`191 unchanged + matrix script 1 expected mismatch`，
   三个independent OWNED flags、O_EXCL、no-pre-delete、owned-stage replacement/exact
   restoration与fail-once
   containment合同全部继承且不放宽。

7. R25 caller只可用冻结的clean `env -i`与system Bash 3.2调用fresh
   `r25-begin.sh`，只传自动计算的current Review25 SHA。R25使用全新的12个runtime names、
   `agentloop-r25-state.*`/`agentloop-r25-bundle.*` roots、invocation ID、bundle identifier、
   hidden stages与boundary；不得复用R24 root、bundle、binary、verify log或测试结论。从BEGIN、
   唯一unfiltered `swift run RunTests | tee`及即时two-element `PIPESTATUS` capture、
   same-log 46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、
   four-object gates、191+1 matrix/restoration、source/privacy、same-bundle bootstrap/cold
   preview、staged report到END，必须在同一个reviewed Bash process内完整重跑，禁止handoff、
   caller continuation、重跑、patch-on-failure或换root/object。

8. R24 final contract中的O_EXCL boundary与deferred-signal consumption、fresh-root phase/type
   gates、direct `$!` launch、stable Bash jobs + PPID/lstart containment、禁止以`kill -0`
   授权kill、exact B01–B06/C01–C09 UI与isolated fixture、screenshot/report `mv -n`
   no-clobber publish、
   privacy/source gates以及唯一tiny END commit-wins window全部逐字继承。R25 evidence只能声称
   已观察process为exact isolated direct child、已观察normal-root open count为0且未观察到
   replacement；不得声称覆盖未观察区间、绝对无TOCTOU或zero preference write，且report必须
   披露invocation-unique UserDefaults onboarding write。

9. Review25必须职责隔离：reviewer不得写R25六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/25-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line `R25_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review25`、`reviewer_write_scope=review25_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest三hash、固定
   branch/HEAD与`manifest_count=192`。Review25通过且无更新user turn撤销standing Goal后，
   root agent自动计算Review25 SHA并调用冻结caller，不再要求用户echo hashes。

10. R25 manifest、freeze与独立Review25完成前，caller/BEGIN、test/build/matrix/source/
    bundle/preview及任何产品/test/App/permanent-script修改继续禁止。只有R25 exact END及全部
    technical gates通过后，才可由新的职责隔离reviewer写`reviews/02-p1-a2-review.md`；只有
    Review02零P0/P1才打开独立acceptance，A3及以后slice始终关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。


## 35. R25 preview rejection and authorized R26 bounded disposition

本段是六个控制面的同一份 current override；它不改写 R15–R25 immutable 历史，只把
R25 已证明的 Bash `ERR` trap/status-capture 根因与 R26 唯一有界路线设为 current。
R26 的 source/product/test/App/Package/schema/migration/permanent-script delta 精确为 0；Core、
TestSuite 与 matrix script bytes 分别继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R26 不重新解释、
补写、清理、删除、重命名或复用任何 R25 evidence/root。

1. R25 freeze `8e6d97aca80591f544b40a8b645c01f1c5624f0f120d5ac12cedf37b94ffbeca`、
   Review25 `65b738e9c977e97ec6acdfbadad938d43ff97213c42e3b56297e67998dec237e`、
   driver `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`与
   192-entry manifest
   `462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba`均
   immutable。R25 唯一 BEGIN 内 full test 是 captured Swift/tee `0/0`、terminal
   `652/652`、7 suites/0 failures；same-log `46/46`、debug build、fresh signed bundle、
   guard/strip、Core/TestSuite target-exact releases、four-object symbols、SQLite 3.51/3.52
   matrix restore、source/privacy/final hashes与pre-preview `192/192`均通过。R25 未收到任何
   UI challenge，未写 screenshot/report，且无 END，因此永久 `REJECTED_CONTAMINATED`，不得
   替代 R26 full rerun、Review02 或 acceptance。

2. R25 在 `preview_bootstrap_direct_start`依次留下三个 rejection blocks：child substitution
   内 `/usr/bin/pgrep -x "${r25_name}"` rc 1、同一 child function 的显式
   `return "${r25_rc}"` rc 1，随后 root caller 因 app 已被 child containment终止而以
   `preview_command_read_failed_bootstrap_ready` exit 70。根因不是产品、bundle、SQLite、UI或
   process identity失败，而是全局 `set -E`把 root `ERR` trap继承进 command-substitution
   subshell；child将预期 absent/transient nonzero误当成 root failure并执行root-owned cleanup。
   R25 final containment最终reap exact child，AgentLoop/AgentLoopApp均不存在，但三次reject与
   no-END事实不可合并、删除或美化成一次成功边界。

3. R26 的唯一 causal fix 位于 fresh `r26_err_trap`最前：先保存真实`$?`与
   `${BASH_COMMAND}`，随后在任何日志、active/pre-BEGIN failure或cleanup之前执行
   `if (( BASH_SUBSHELL != 0 )); then trap - ERR; exit "${r26_status}"; fi`。child只把原始
   status传播给root caller，绝不执行active/pre-BEGIN containment；root shell
   `BASH_SUBSHELL == 0`时仍逐字走原 fail-fast 路径。禁止增加child-local `EXIT` trap、全局
   关闭ERR、`|| true`、吞错、改caller分类或packet/fallback旁路。该一处root fix统一覆盖
   exact-name absent/caller、`pgrep -P` no-child、launch identity `ps` retry、startup
   readiness `ps/lsof`、signal authorization/live-proof与quit-wait `ps` disappearance；
   rc > 1、malformed、duplicate、unexpected payload与identity mismatch仍fail closed。

4. final pre-BEGIN必须通过一个静态guard/inventory门与八类system Bash 3.2 micro-probes。
   静态门证明guard在root cleanup之前、全driver无`EXIT` trap，并把同根nested capture精确
   清点为15个`/bin/ps`、2个`/usr/bin/pgrep`、3个`/usr/sbin/lsof`。micro-probes必须证明：
   legacy形态产生两次child cleanup；fresh guard下exact-name absent、exact-name present、
   no-child、transient ps retry、transient lsof safe subset与rc 2 indeterminate分别保留原rc/
   payload且child active side-effect为0；最后raw未捕获`x="$(false)"`向root传播并恰好触发
   一次root fail-fast。任何probe/inventory/guard-order偏差在BEGIN前零repository-write停止且
   不消费authority。

5. R25 的十个实际runtime files继续以exact SHA、regular/non-symlink type及关键boundary
   事实重证：targeted、verify、build、matrix、boundary、bundle、source、hash、bootstrap与
   cold logs分别固定为
   `538cf3ff68d95318ab7da9dc7a685648f4c7651668ca0c6fcf4dc35c8a48e532`、
   `9a0d772ac0f36cf56b2340c741d237dfbc2a4a6a9ecd4314bb5b95319f7b8b5f`、
   `cc50f7f484bb397052dae2be64307361e99255fd27169648cb4ac36aa75dd703`、
   `7c0e55705520fe79281e7a38b409177515f00fedc89eb8c8bf68fc0f4f74dca9`、
   `2d1dabc7872b31b7d330700c0979857563af84491ff39391b3bf9279ff50c0d4`、
   `5bdfdad577d4f9c0c029463c59cf442b83122939f76e59c435e89371e682e3d5`、
   `8d995eeb44fbccd42d9f83a0b64088d35f326ac8dd0051198327320ca2f0466f`、
   `bba9e1ffd51e2f8fb066d00226fc18f9e4f66b9c32f1917129522b471706564a`及
   两个empty SHA。`impl-report-r25.md`与`r25-preview-smoke.png`必须继续absent；任何R26
   evidence不得声称R25到达UI或END。

6. R25结束后，一次职责隔离evidence audit用SQLite read-only URI打开了R25 WAL-mode state
   database；它未改repository、bundle、normal-data或用户root，但可能更新`-shm`，且缺少
   before hash/mtime，故R25 state root从此明确标记
   `POST_REJECTION_READ_PROBE_CONTAMINATED`。R26对R25 state root
   `/private/tmp/agentloop-r25-state.fs7Cz2`与bundle root
   `/private/tmp/agentloop-r25-bundle.Ozi6d3`只允许coarse two-bit root-entry lstat/type A/B
   observation：baseline `11`，每轮完整A/B，仅允许equality或1→0，0→1、alternate、symlink、
   wrong type或indeterminate拒绝。本项的alternate只指这两个exact path的root-entry shape不是
   约定real directory；固定two-bit universe不扩张到parent/glob扫描，也不声称检测same-type
   inode replacement。严禁进入、枚举、hash、open或clean任一R25 root/descendant，
   严禁把R25 state contents/hash当作original terminal evidence或R26运行输入；FIRST/LATEST/
   accepted-B仍只在全部比较通过后同一defer-signal commit。R23、R24、R20 lifecycle与R15
   tombstones继续按既有合同观察。

7. R26 static manifest必须精确为`206 = R25 192 + 14`：完整R25 path set，加fresh R26
   driver、immutable R25 manifest/freeze/Review25及十个实际R25 runtime files；R25 driver已在
   old 192内，不得重复。六面同步后旧R25 manifest分区必须精确
   `186 unchanged + 6 expected control-surface mismatches`。R26 manifest排除自身、R26
   freeze、Review26、12个fresh runtime/report paths、两个fresh roots与全部invocation-owned
   hidden stages。entry、mutation边界、restore后与END必须`206/206`；唯一matrix窗口只允许
   `205 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、三OWNED flags、
   exact restoration与fail-once containment均不放宽。

8. R26使用全新12个runtime names、`agentloop-r26-state.*`/
   `agentloop-r26-bundle.*` roots、invocation ID、bundle identifier、hidden stages与boundary。
   从BEGIN、唯一unfiltered `swift run RunTests | tee`及即时two-element`PIPESTATUS`、same-log
   46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   205+1 matrix/restoration、source/privacy、same-bundle B01–B06/C01–C09 preview、staged
   screenshot/report到tiny commit-wins END，必须在同一reviewed Bash 3.2 process完整重跑。
   禁止复用R25 root/binary/log/result，禁止handoff、caller continuation、retry、patch-on-failure
   或换root/object；UI evidence claim继续限制为observed intervals，不外推绝对无TOCTOU、绝对
   zero normal-root open或zero preference write。

9. Review26必须职责隔离：reviewer不得写R26六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/26-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line`R26_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review26`、`reviewer_write_scope=review26_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
   `manifest_count=206`。Review26通过且无更新user turn撤销standing Goal后，root agent自动
   计算Review26 SHA并调用冻结caller，不要求用户echo任何hash。

10. R26六面、fresh driver、exact 206-entry manifest与freeze均已冻结；Review26此刻仍absent，
    caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及任何产品/test/
    App/Package/permanent-script修改继续禁止。只有manifest/freeze完成并由独立Review26零P0/P1
    批准后才自动执行；只有R26 exact END及全部technical gates通过后才可创建独立Review02；
    只有Review02零P0/P1才打开A2 acceptance，A3及以后slice仍关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。

## R27 current override — compound-if status capture root-cause closure

本段是六个 current control surfaces 的 byte-identical override。R15–R25 历史继续
immutable；R26 也永久保留为 `REJECTED_CONTAMINATED`。R27 不重新解释、补写、清理、删除、
重命名或复用任何 R26 evidence/root，且 source/product/test/App/Package/schema/migration/
permanent-script delta 精确为 0。Core、TestSuite 与 matrix script bytes 继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。

1. R26 predecessor 四锚固定为 freeze
   `0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb`、Review26
   `8d9cc6b3acaeda72204b1a71f209996344215b61747b8c516d7afbf067880ba9`、driver
   `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d`与206-entry manifest
   `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d`。R26 唯一 BEGIN
   已 captured Swift/tee `0/0`、terminal `652/652`、7 suites/0 failures；same-log `46/46`、
   debug build、fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   SQLite 3.51/3.52 matrix restore、source/privacy/final hashes及pre-preview `206/206`均通过。

2. R26 到达真实 same-bundle bootstrap preview，B01–B06 的六个 challenge 与六个 result
   全部 PASS；B06 后 App 已正常退出。随后在 `preview_bootstrap_direct_start`以唯一
   `quit_wait_job_table_indeterminate_bootstrap_0`拒绝。cold log empty；C01–C09、fixture、
   screenshot、impl report与END均未发生，因此上述结果不能替代R27 full rerun、Review02或
   acceptance。R26 final containment后exact child已reap，且无残留AgentLoop/AgentLoopApp。

3. 唯一根因是Bash 3.2 compound-`if` status语义：生产路径精确五处采用
   `if r26_preview_active_job_exact; then ...; fi`后再读`$?`。当helper真实返回1（stable
   `ABSENT`）时，无`else`且未执行then-body的compound `if`自身状态为0，故caller读到0并误报
   indeterminate；这不是job-table classification、UI、process identity、bundle或产品错误。
   R27只把这五处改为`else`分支第一语句立即保存`r27_job_rc="$?"`。其余8处既有explicit-else
   capture、helper的0/1/2分类、signal/kill/wait/containment算法及所有fail-closed边界逐字保留。

4. 为关闭R26 evidence audit指出的P1可观测性缺口，job-table helper只新增三个安全global
   diagnostics：last previous state、last latest state与returned rc；state值只来自
   `UNOBSERVED/RUNNING/STOPPED/ABSENT/TRANSITION`，rc只来自`UNSET/0/1/2`，绝不保存或输出
   任意jobs/ps/lsof payload。正常quit log必须记录真实job rc与state pair；rejection boundary
   必须记录containment后的latest diagnostic。诊断不改变任何classification、retry、signal、
   cleanup或acceptance语义，rc 2继续indeterminate fail closed。

5. 两轮final pre-BEGIN（均在caller/BEGIN及任何repository write前）各自依次执行既有
   ERR-subshell static guard与八类Bash 3.2 probes，再执行fresh compound-if static gate与
   Bash 3.2 probes。fresh static gate必须证明production helper精确13 calls/13 immediate
   else captures、上述五个causal sites精确存在、production中`fi`后或同一行后读`$?`为0，
   diagnostics assignment只属于安全enum。fresh probes必须证明rc 0、rc 1、rc 2逐字捕获，
   rc 1 diagnostics为stable absence，rc 2 diagnostics与classification保持fail closed，并以
   legacy no-else probe证明helper rc 2会被compound `if`错误映射为0。任何偏差pre-BEGIN零写入
   停止，且不消费standing Goal authority。

6. R26十个runtime files必须以regular/non-symlink type、exact SHA与exact bytes重证，顺序为
   boundary `814ad7bfc50dfa6e5de65b10f470c8dee3bdbfed3ee2532776ad7011658b2280`
   /14381，hash `7041b3fc36c6fcc5a0686d9deb95cb4c6738425579f62b904dfbcd83aebf3198`
   /6063，verify `212a205b2baaf8d052513f148199ea8679ab625d0d607255e58a2d6807b61ea8`
   /96130，targeted `24b321736976667737b38eefcd79c11ecfc90322b9a495e63d7f6fcf52436fea`
   /4718，build `068e012ddb71725eac797c2b76f56972a403048ff0fed5010a7d14ad0ffc6fc6`
   /729，matrix `124b28b317581ea19b7647dfa084ebc7e3c3394fe02c9a40fd80d2de20006932`
   /44058，bundle `c5604214b12c265fe0100a500491a08eeff7ab95d543b753d2ee433ad459d906`
   /2661，source `58c90e5840c6c14d529ecb53f1b6ada95d2707a4b99d4c18fedee1c253767b76`
   /2998，bootstrap `d10ee7940284ccb289ba48a40284e3c539f421054e39718b02d7a94499b53733`
   /6557及cold empty SHA/0 bytes。`impl-report-r26.md`与`r26-preview-smoke.png`必须absent；
   boundary的BEGIN/652/652/46/46/launch/source/206/206/B01–B06/rejection/no-END关键事实必须重证。

7. R27对R26 state root `/private/tmp/agentloop-r26-state.JlHsbi`与bundle root
   `/private/tmp/agentloop-r26-bundle.mCj70H`只允许按此固定顺序对两个exact root entries执行
   `os.lstat` A/B，baseline为`11`；只接受real directory或absent，允许equality或1→0，拒绝
   0→1、symlink、wrong type与indeterminate。固定two-entry universe不扩张到parent/glob扫描，
   也不声称检测same-type inode replacement。严禁进入、枚举、hash、open、clean或复用任何
   R26 root/descendant；FIRST/LATEST/accepted-B仍只在整轮比较通过后的defer-signal窗口提交。

8. R27 static manifest必须精确为`220 = R26 206 + 14`：完整R26 path set，加fresh R27
   driver、immutable R26 manifest/freeze/Review26及十个R26 runtime files；R26 driver已在old
   206内不得重复。六面同步后old partition必须`200 unchanged + 6 expected control-surface
   mismatches`。manifest排除自身、R27 freeze、Review27、12个fresh runtime/report paths、
   两个fresh roots与全部invocation-owned hidden stages。normal/restore/END为`220/220`；唯一
   matrix窗口为`219 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、
   ownership与exact restore/fail-once containment不放宽。

9. R27使用全新12个runtime names、`agentloop-r27-state.*`/`agentloop-r27-bundle.*`、
   invocation ID、bundle identifier、hidden stages与boundary；从BEGIN、唯一unfiltered full
   test及即时two-element `PIPESTATUS`到same-log、build、release/object/matrix/source/privacy、
   B01–B06/C01–C09、staged screenshot/report与tiny commit-wins END，仍须在同一reviewed Bash
   3.2 process完整重跑。禁止复用R26 root/binary/log/result、handoff、caller continuation、
   retry、换root/object或patch-on-failure；UI claim仍只限observed intervals。

10. Review27必须职责隔离：reviewer不得写六面、driver、manifest或freeze，唯一repository
    write为`reviews/27-p1-plan-review.md`；正文只允许一个`Verdict: APPROVED — 0 P0 / 0 P1`
    及唯一12-line `R27_MACHINE_BLOCK`，authority mode为
    `standing_goal_automatic_after_review27`、scope为`review27_only`、
    `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
    `manifest_count=220`。Review27通过且standing Goal未撤销后，root agent自动计算review SHA
    并调用冻结caller，不要求用户echo hash。

11. R27六面、fresh `r27-begin.sh`、exact 220-entry manifest与R27 freeze均已冻结；Review27、
    所有R27 runtime/report/root/stage仍absent pending。独立Review27批准前，
    禁止caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及产品/test/
    App/Package/schema/migration/permanent-script修改。只有R27 exact END及全部technical gates
    通过后才可创建独立Review02；只有Review02零P0/P1才打开A2 acceptance，A3及以后仍关闭。
    commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、外部操作与
    真实用户操作均未授权；任何超出本段的决策必须重新进入有界修订与职责隔离review。

## R28 current override — Shell timeout measurement-boundary root-cause closure

本 override 是六个 control surface 的唯一 current R28 入口；此前全部 R15–R27 历史与
immutable evidence 保留且不得重解释、补写、清理、删除或用后继结果替代。

1. R27 clean invocation 已永久 `REJECTED_CONTAMINATED`。四个 immutable anchors 为：

   - freeze `6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41`；
   - Review27 `74d20ed9909ba576beaba86659672c423686a7f798adf5bfbc6929607f606e5f`；
   - driver `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d`；
   - manifest `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e`。

   R27 的十个 actual runtime files 均为 immutable regular non-symlink evidence：

   | Runtime evidence | Bytes | SHA-256 |
   |---|---:|---|
   | `r27-targeted-tests.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-verify.log` | 96,330 | `6279dadbdfbd37d6fb6730fbf037a0d0dfd40fbfab8acb4f91b01967f79297ea` |
   | `r27-build.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-migration-matrix.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-clean-boundary.log` | 8,066 | `f7807793b9cea03b0611af134918380cd4521d687fe0a3bb1e4c2955dd874310` |
   | `evidence/r27-bundle-provenance.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-source-gates.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-hash-manifest.log` | 3,091 | `01b8cb95805e52703fb394d56b8c38f344286a02ed7b7a443ed886b2ed6c3a21` |
   | `evidence/r27-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

   `evidence/r27-preview-smoke.png` 与 `impl-report-r27.md` 均 absent。R27 只有唯一
   unfiltered authoritative full test：651/652，唯一 issue 为
   `shellTimeoutTerminatesProcess()` 的 elapsed assertion；targeted、build、release、
   object、matrix、source、privacy、bundle、UI、screenshot、report 与 END 均未发生。
   Exact predecessor roots 仅为 `/private/tmp/agentloop-r27-state.rc7ama` 与
   `/private/tmp/agentloop-r27-bundle.6Q3UjM`；fixed exact-root `lstat`-only baseline
   固定为 state=1、bundle=1，即 `11`。R28 只允许对这两个已解析 exact pathname 做 fixed
   `lstat` lifecycle observation；绝不进入、枚举、打开、读取或哈希任何 descendant，也绝不
   把 root contents 当作 R28 input。

2. R27 的同一根因被精确限定为 measurement-boundary contamination。现有
   `shellTimeoutTerminatesProcess()` 在调用 `tool.execute` 前启动 `ContinuousClock`；而
   `ShellTool.execute` 会先 `await LoginShellEnvironment.shared.environment()`，再
   `process.run()`，真正的 command deadline 在环境解析与 process start 之后建立。
   Login-shell capture 自身有合法的 5 秒 safety guard，command timeout 为 300ms，终止 grace
   仍为 300ms；因此 cold environment capture 加 command timeout/grace 合法超过测试的 5 秒
   wall-clock ceiling。R27 实测 elapsed 为 5.13908825 秒，只有 `< .seconds(5)` 这一断言
   记录 issue；这不证明 ShellTool 的 300ms command deadline 失效。

3. R28 唯一允许的实施文件为
   `Sources/AgentLoopTestSuite/ShellToolTests.swift`。其 exact pre-patch SHA-256 必须为
   `c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`。只允许在
   `shellTimeoutTerminatesProcess()` 内、现有 `let clock = ContinuousClock()` 的正前方
   新增且只新增以下一行：

   ```swift
   _ = await LoginShellEnvironment.shared.environment()
   ```

   Exact final SHA-256 必须为
   `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`。
   从 final bytes 删除且只删除这一条 exact newline-terminated line 必须恢复 exact pre-patch
   SHA；这就是 mandatory strip proof。既有 `< .seconds(5)`、300ms timeout、300ms grace、
   error/message/output/registry assertions、函数位置与其余 bytes 全部不变。

4. `Sources/AgentLoopCore/Tools/ShellTool.swift` 必须保持 SHA-256
   `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf`；
   `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift` 必须保持 SHA-256
   `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`。
   禁止提高或删除 threshold，禁止修改 timeout/grace，禁止为 environment 引入 injection、
   single-flight、public/package API 或产品逻辑，禁止修改 test order/filter，禁止 retry、
   sleep、重复 full run 或其他产品/test/App/Package/schema/migration/permanent-script 改动。
   Login-shell capture single-flight 只登记为 P2 后续候选，不属于 R28。

5. 实施顺序固定为：先同步本六面、生成 fresh R28 driver、exact 235-entry manifest 与
   R28 freeze；再由职责隔离 reviewer 执行 Review28；Review28 exact approval 后，root agent
   才能用 `apply_patch` 在 pre-BEGIN 窗口应用第 3 项 exact one-line change。若 pre-patch
   SHA、唯一上下文、final SHA 或 strip proof 任一不符，必须 fail closed 且不得 BEGIN。
   Frozen driver 不得写源码；它只在内部重新证明 final SHA、strip proof、两个 immutable
   product hashes 与 phase-aware manifest，然后由同一个 reviewed Bash 3.2 process 完成
   BEGIN 至 terminal END 的 full chain。

6. R28 static manifest 必须精确为 `235 = R27 220 + 15`。十五个 additions 只能是：fresh
   R28 driver；immutable R27 manifest、freeze、Review27；十个 R27 runtime files；以及
   `ShellToolTests.swift` pre-patch baseline。六面同步后相对旧 R27 manifest 的 partition
   必须为 `214 unchanged + 6 expected control-surface mismatches`；应用 one-line 后该 old
   partition 仍必须为 `214 + 6`。R28 pre-patch gate 为 `235/235`；实施后正常 phase 只能是
   `234 unchanged + 1 ShellToolTests mismatch`；matrix mutation window 只能是
   `233 unchanged + 1 ShellToolTests mismatch + 1 owned matrix-script mismatch`；exact
   restore 与 END 只能回到 `234 + 1`。任何额外 missing、addition、type drift 或 mismatch
   都必须拒绝。Manifest 排除自身、R28 freeze、Review28、fresh R28 runtime/report paths、
   两个 fresh roots与全部 invocation-owned hidden stages；既有 O_EXCL、no-pre-delete、
   ownership、no-clobber publication、exact restore 与 fail-once containment 不放宽。

7. R28 必须使用全新 runtime/report names、`agentloop-r28-state.*`、
   `agentloop-r28-bundle.*`、invocation ID、bundle identifier、hidden stages 与 boundary。
   同一 Bash process 必须运行唯一 unfiltered `swift run RunTests` 并得到 full 652/652、
   same-log exact 46/46、debug build、release Core/TestSuite targets、debug/release object
   symbol gates、migration matrix、source/privacy、bundle provenance、B01–B06、C01–C09、
   staged screenshot、implementation report 与 tiny commit-wins END。禁止复用 R27 root、
   binary、log 或结果，禁止 handoff、caller continuation、换 root/object、patch-on-failure
   或任何 retry；UI claim 仍只限 observed intervals。

8. Review28 必须职责隔离。Reviewer 不得写六面、driver、manifest、freeze、source 或
   runtime evidence，唯一 repository write 为
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/28-p1-plan-review.md`。
   Review 必须只含一个 `Verdict: APPROVED — 0 P0 / 0 P1` 与唯一 machine block，并绑定
   current six-body identity、freeze、driver、manifest、branch、HEAD、
   `authority_mode=standing_goal_automatic_after_review28`、`scope=review28_only`、
   `user_hash_echo_required=false`、`manifest_count=235`。Review28 通过且 standing Goal
   未撤销后，root agent 自动执行 exact pre-BEGIN patch 与 frozen caller，不要求用户 echo
   hash。

9. Review28 exact approval 前，禁止 one-line implementation、caller/BEGIN、test、build、
   matrix、source、bundle、preview、Review02、acceptance 及任何其他产品/test/App/Package/
   schema/migration/permanent-script 修改。只有 R28 exact END 与全部 technical gates 通过后
   才能创建职责隔离 Review02；只有 Review02 零 P0/P1 才打开 A2 acceptance。A3 及以后仍
   关闭。Commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、
   外部操作与真实用户操作均未授权；任何超出本 override 的架构、依赖、语义、测试或证据
   决策都必须重新进入有界修订与职责隔离 review。
