# P1-A1b Pre-R11 Read-only Revision Map

> 状态：**Authorization Pending — read-only map only**
>
> 日期：2026-07-26
>
> Branch：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

本文件把 `blocked.md` §8–§10 的已验证 R11 边界映射到准确文件、章节、hash
顺序和 reviewer 职责。它不是 R11 授权、candidate freeze、Review11 或产品
implementation evidence。

## 1. 当前冻结输入

| 输入 | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6` |
| canonical total Plan `p1-plan.md` | `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61` |
| A1b leaf `plan.md` | `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

## 2. 获授权后唯一可编辑的规划文件

Canonical 三件套：

1. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
2. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
3. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/plan.md`

Execution indexes：

4. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md`
5. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md`

Control evidence：

6. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`
7. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/blocked.md`

职责隔离 reviewer 的唯一写入：

8. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`

## 3. Canonical edit anchors

### Stage §6.3

- Schedule：Coordinator non-finite pre-guard、finite checked-ms overflow
  claim → missed、`lastFiredAt` numeric write 与 legacy TEXT/numeric decode；
- fallback：唯一 matching-`#if DEBUG` owned-success-proposal seam；
- legacy：`LegacyPlanningHasCardsError` exact code 与完整零写快照；
- startup：显式 process-local `.recoveryReady`、两阶段 activation、内部
  durable-mode fence、control actor linearization、durable-running Card retry；
- 保持 schema、claim CAS、valid finite slot、missed、DDL/literal不变。

### Total Plan §3.2 与 implementation/test gates

- A1b 生产 allowlist 只增加
  `Sources/AgentLoopCore/Database/ScheduleStore.swift`；
- 同步四个 R11 合同、completion definition、命名测试和 Review11 predecessor；
- §10 `v12-durable` 只同步新 Stage hash，不改 fixture/DDL/literal；
- §11 保持 Package/RunTests fingerprints、完整 suite、matrix 与 sentinels 硬门。

### A1b leaf

- §0–§2：R11 authority、freeze evidence、Review11 pending 与职责隔离；
- §3.1：增加 `ScheduleStore.swift`；
- §4：仅允许 `lastFiredAt` 持久编码改变，不改 value/CAS/slot/missed/schema；
- §5.6：activation API 与 narrow DEBUG seam；
- §8.2/§8.5：fallback failure owner 与 legacy typed error；
- §9：`.recoveryReady`、activation/control 线性化、halted 与 running retry 分流；
- §10：Orchestrator 顺序与 Schedule finite/non-finite 分流；
- §11/§12：实施顺序与全部命名测试；
- §15/§16：Review11、完成门与 stop conditions。

## 4. R11 必须新增或强化的测试

Schedule：

- `scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes`
- `scheduleLegacyTextLastFiredAtRemainsReadable`
- `scheduleDateEncodingChangesOnlyLastFiredAt`
- `nonFiniteScheduleFireFailsBeforeClaimWithoutWrites`

Startup：

- `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`
- `startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition`
- `explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce`
- `startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent`
- `staleStartupRecoveryCannotActivateAfterConcurrentControlTransition`

Legacy/fallback：

- `legacyPlanningWithCardsFailsClosedWithExactTypedErrorAndZeroWrites`
- `unexpectedPlanningFallbackTerminalizesThroughFailureOwner`

## 5. 无循环 freeze / review 顺序

1. 记录当前 product/test/script/Package manifests；
2. 只修订 canonical 三件套，不在其中写自己的 hash；
3. 执行 `diff --check`、Markdown fence/trailing、Open Questions 与 cross-document
   静态检查；
4. 按 Stage → total Plan → leaf 计算三份 SHA-256；
5. 写 `r11-freeze-validation.md`，再把三 hash 写入两个 pre-review execution
   indexes 与 `blocked.md`；freeze evidence 不写自身 hash；
6. 计算 freeze evidence hash；
7. 未参与修订的 reviewer 只读复算全部输入，唯一写
   `reviews/11-p1-plan-review.md`；
8. 计算 Review11 hash；
9. 若 verdict 为 `APPROVED — 0 P0 / 0 P1`，只更新两个 index 与 blocker control
   status；不得再改 canonical 三件套；
10. 若有 finding，不覆盖 Review11；新 candidate/evidence/review 使用新后缀。

## 6. 不可编辑范围

R11 planning/freeze/Review11 期间不得修改：

- 任何产品、test、runner/script、verify/build log 或 implementation report；
- Package.swift、Package.resolved、RunTests；
- master spec、A1a Plan/acceptance/review；
- 旧 R10/R10A freeze evidence、Review10/Review10A；
- commit、push、merge、release、A1b implementation Review/acceptance 或 A2。

## 7. Pre-authorization verdict

独立只读边界复审在四项 P1 修正后为：

`APPROVED — 0 P0 / 0 P1`

它只说明 R11 的待授权范围已达到最小、完整、可实现且无明显内部冲突；用户明确授权
仍是编辑 canonical Stage/Plan/leaf 的唯一入口条件。
