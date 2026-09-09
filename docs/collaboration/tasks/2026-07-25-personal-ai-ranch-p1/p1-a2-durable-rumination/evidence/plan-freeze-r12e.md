# R12-E Plan Freeze Evidence

> 状态：R12-E Candidate Frozen；Review12C Pending；A2 Product/Test Code Frozen
>
> 日期：2026-07-27
>
> Owner：R12-E planner

本证据只冻结获授权的 Review12B P1-1 durable-projection final-refresh closure，以及
继承的 R12-A 单行 control delta。它不是职责隔离 Review、产品/测试
implementation、test/build/matrix/preview 结果或 acceptance。

## 1. Repository identity and immutable history

| Field | Value |
|---|---|
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| inherited worktree | fully-expanded dirty A1a/A1b accepted baseline；未清理、覆盖或归属用户/既有改动 |
| A1b implementation Review | `APPROVED — 0 P0 / 0 P1`；`8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` |
| A1b acceptance | `ACCEPTED`，22/22 PASS；`efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| immutable Review12 | `reviews/12-p1-plan-review.md`；`CHANGES REQUIRED — 0 P0 / 2 P1`；`f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| immutable Review12A | `reviews/12a-p1-plan-review.md`；`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| immutable Review12B | `reviews/12b-p1-plan-review.md`；`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5` |
| immutable R12/R12-A freeze | `evidence/plan-freeze.md`；`652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| immutable R12-B freeze | `evidence/plan-freeze-r12b.md`；`85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |
| immutable R12-C freeze | `evidence/plan-freeze-r12c.md`；`ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` |
| immutable R12-D freeze | `evidence/plan-freeze-r12d.md`；`9d4e3bfa2c244b925db9c3bdbde1d30cf86ad42f05453ca5bee9efb5d553c66b` |
| next review path | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`；freeze 时不存在 |

上述 historical artifacts 已直接复算并保持 byte-identical。R12-E 没有改写
predecessor verdict、manifest 或审查报告。

## 2. Review12B input snapshot and bounded finding

Review12B 直接复算的 R12-D candidate 为：

| R12-D artifact | SHA-256 |
|---|---|
| canonical Stage | `fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff` |
| canonical total Plan | `dc059ecb5db232179e84014991a65bfc6bcee3080aea6486ee3173ea4d581a8a` |
| A2 leaf Plan | `5afd02f97e94f9a8aa0406fc06c5a2011951640ab5492e1aaf3aaa0d26ef6f95` |
| A2 `blocked.md` | `0f47e935f29c993f8e0141efb5dd9e18683b2649fccb245c179343e3f6ff2ef8` |
| P1 Stage control index | `e682a531e58ba046b9e6eab1873c5c023f56cae401ccba34c87420502346c052` |
| P1 Plan control index | `eabdf5441fcbd1c4d87d9f1bcd7c9299fed6a93e81ecdfe8799c5ab958910ca6` |
| matrix script | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |

Review12B 的唯一 P1 是：R12-D 能清除已发 live phase，但 phase-less
success/failure/retry/cancel commit，以及 emergency-halt bulk cleanup commit
之后，没有必达的最终 App persisted-projection refresh owner；
`haltStateChanged` 也不刷新 Coding Ranch projection。R12-E 只关闭该同一根因；
没有重审或改写其他 A2 决定。

## 3. Canonical R12-E candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `59f52f7d7d08889afb12b4524f67152ea0ca59fe240300cf798d6ab526738935` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `767a9604d1a10a819db73fee730d02c312b1e759161ba506ff3ca7223c51b16b` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `1f93ebb1d8ddfb55249021fd0288ce3cba203781c96a025abe7ffb4c20da0f7e` |
| A2 `blocked.md` | `3cdaae2d44c63e0469fb4be1a4566a763cf40bf416ab9472c06247dccaccb6cc` |
| P1 Stage control index | `057a602a5ec043726af0dfa052bb8a8dee6072deb00787a9966ae1d22df1dbef` |
| P1 Plan control index | `ff49f45856d728eb50e81158ce4dcf9b38026e877bcda538bb64cac55de3ff64` |
| matrix script | `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |

Canonical Stage §29、总 Plan §19 与 A2 leaf §13 的 Open Questions 均精确为
`无。`。三份正文状态均精确为
`R12-E Candidate Frozen；Review12C Pending；A2 Implementation Frozen`。本
evidence 不把自身 hash 写回控制索引，因此没有自指 hash 环。

## 4. Durable projection milestone closure

R12-E 保留唯一 callback：

`onRuminationPhase: @escaping @Sendable (RuminationPhaseCommand) async -> Void
= { _ in }`

command 仍只有：

- `.set(identity:phase:)`
- `.invalidate(RuminationInvalidationMilestone)`

milestone 精确为：

- `.phase(identity:reason:)`，reason 只有 `controlLoss|globalFatal`
- `.projectionCommitted(RuminationProjectionCommitIdentity)`

public `RuminationPhaseIdentity` 精确携带
`ingestionId,workId,attempt`；attempt nonnegative 并允许 `0`，用于 queued
user-cancel/halt projection commit。positive set 和 phase invalidation 另要求
running/open attempt `>=1`。public `RuminationProjectionCommitIdentity` 精确携带
`phaseIdentity,workVersion`；workVersion `>=1` 且只能取 Store transaction 返回的
resulting `DurableWorkRecord.version`，不得从 expectedVersion、旧 claim 或手工
`+1` 猜测。

Store success、deterministic/exhausted failure、transient retry 与 actual user
cancel 均返回 resulting work；halt cleanup 返回按 work ID 排序的 actual-canceled
commit identities。Supervisor 在 commit 后同一 actor turn、第一次 await 前
reserve full commit identity，revoke committed claim/generation 的后续
set/terminal permission，等待 registered set-in-flight，再 await 同一 sink。
rollback/throw/invariant/no-active 均为零 reservation、零 milestone。

projection delivery 按完整 `(phaseIdentity,workVersion)` exactly-once：

- exact duplicate 只等待原 delivery，零第二 sink/event；
- 同 workId 更高 version 合法并顺序 delivery；
- retry `V+1` 后 cancel/halt `V+2` 必须得到两次 refresh；
- 已处理低版本 replay 幂等；unseen lower version 或
  same-version/different-identity 在 sink/event 前 fail-fast；
- receipt 不得降格为 `Set<RuminationPhaseIdentity>`。

每个 phase identity 的 set、phase invalidation 与 projection milestone 共用一个
actor-isolated delivery coordinator，两个 helper 不得并发调用 sink：

- projection-first：later control/global phase caller 等待 projection；matching
  projection 满足 phase-cleared obligation，零第二 phase clear；
- phase-first：later 真实 projection 等待 phase delivery 后仍发 refresh，typed
  `invalidatedPhaseIdentity=nil`；
- 两向均先 register、后 await，不得互等、递归 continuation、Task 或依赖 executor
  FIFO。

## 5. Event, App, halt, and completion gates

既有 `KernelEvent` 仍只有两个 process-local rumination cases：

- `ruminationPhase(ingestionId:workId:attempt:phase:)`
- `ruminationChanged(RuminationChange)`

public `RuminationChange` 只含：

- `.phaseInvalidated(identity)`
- `.projectionCommitted(commitIdentity,invalidatedPhaseIdentity:)`

Orchestrator 持有 exact phase registry/tombstone、full commit receipt 与 per-work
highest version。phase invalidation 只有 exact registry match 才 remove/tombstone
并 emit；stale/empty/mismatch 为零 phase event。projection commit 对 full identity
exactly-once：exact registry match 时 remove/tombstone并带 `.some(identity)`；
empty/tombstoned/different-newer registry 逐字不动、带 `nil`，但仍必须 emit commit
refresh。

AppStore live map 保存 exact identity+phase；唯一 lifecycle MainActor listener 用
一个 `for await` 直接 await handler。phase event 先以同一次 DB snapshot 重验 item
仍 ruminating 且 active work running/exact identity，才 overlay live phase。
change 只按 typed exact identity clear；nil、old version 或 old generation 不能清
new live phase。无论是否 clear，handler 都 serial reload persisted projection，
并只保留仍匹配 snapshot 的 live entry。background Camp 只更新 loaded-camp cache，
不得切 selected Camp；Adapter command completion 不得成为第二 refresh owner。

Emergency halt 的唯一顺序为：

`sorted pre-cancel phase clear → cancel provider/renewal → persist halted →
planning cleanup → rumination cleanup returns sorted actual commits → awaited
projection deliveries → didCommit/haltStateChanged → return`

persist/cleanup 失败不为未 commit row发布 milestone，保持
suppressed/recovering；queued attempt-zero commit合法，no-active 不得伪造。
`haltStateChanged` 只报告 durable halt state，不能兼任 rumination refresh owner。
shutdown 没有 DB projection commit，因而不得伪造 projection milestone。

现有 41 个 test names 保持 41/41 unique，总 Plan/leaf 逐项同序；#31 名称与
provider/parse 语义不变。R12-E 只扩展现有 #27/#35 和 source-range/order gate，
覆盖 live/phase-less terminal/failure/retry/cancel、`V+1→V+2`、duplicate/
regression、rollback、halt 前后 failure、projection-first/phase-first、registry
四态、typed optional clear、App same-snapshot/FIFO、全部 milestone callsite 与
no-Task/no-bypass。

一轮未参与正文修订的只读 preflight 在最新稳定 bytes 上得到
`0 P0 / 0 P1 / 0 P2`。它逐项核对 queued attempt0、full-version去重、one
callback/two KernelEvent/public payload、双向串行无死锁、old commit/new live、
halt exact order、rollback零milestone、#27/#35/source gates、41 names 与 13+2
allowlist。该 preflight 没有创建 Review 报告，也不替代 Review12C。

## 6. R12-A exact control delta

| Check | Result |
|---|---|
| script path | `scripts/verify-p1-migrations-sqlite-matrix.sh` |
| original baseline SHA-256 | `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| R12-C predecessor SHA-256 | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| R12-D predecessor SHA-256 | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |
| final R12-E candidate SHA-256 | `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |
| only authorized value | line 115 `expected_stage_hash="59f52f7d7d08889afb12b4524f67152ea0ca59fe240300cf798d6ab526738935"` |
| R12-D restoration | replacing final value with R12-D Stage `fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff` yields exact R12-D script SHA `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |
| R12-C restoration | replacing final value with R12-C Stage `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` yields exact R12-C script SHA `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| original restoration | replacing final value with original Stage `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` yields exact original script SHA `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| runner | byte-identical `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |

因此 script 的 fixture、literal、linked lanes、assertions、commands 与全部其他
bytes 未改变。本 freeze 没有执行 matrix；Review12C 必须自行复算该 proof。

## 7. Zero A2 product/test drift

以下 15 个 hashes 与 Review12B/R12-D entry 逐字一致，证明 R12-E planner 未实施
A2：

| Allowed future A2 file | Freeze SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `2a78ce6764d680618db4cd63669261a0d65b1c8235af7744bd83dc52f5779cf7` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `e1991b398299898f5582e0826efa345bac501afd998e2f695af6e81ef539aa79` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `f0057c41d572b4e653c482a4cd9caf3d5dc9cd45acea48e9a6c250c4018a39af` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `d6478b05158697120c60c21466b68aec0a1675bf825d0fce0db277bb7f84966b` |
| `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift` | `0f2d87f1f7e91ee985689a6e88d4a5bd1a0c6f7a7874705f4f83dc4574f740fb` |
| `Sources/AgentLoopCore/Ingestion/FeedService.swift` | `1637b4c6c95a9761f18b53f8024555d040f9316dca0de58d2d5fc57b7589ff21` |
| `Sources/AgentLoopCore/Rumination/RuminationService.swift` | `c8017a64401b3f71e00fcbaf0b871c9854a6127e1774dcb15d904f4c86299a58` |
| `Sources/AgentLoopCore/Rumination/RuminationParser.swift` | `80420d32709974fafcada2e6cb8cc71444792a2440c70c7901c514465ab1e8e3` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `1fd816c703823f01d38af448a0e9b9e745966a8b26119bf4646d788cfcadd03d` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `149a0497790bf62f5ab459f31e94cf52e5c467816846fe29211a7dcc411c4f18` |
| `Sources/AgentLoopApp/AppStore.swift` | `2eb60d210bfc6d59c60afa4a2b272811af9b5b4ab8e674ceea397687799adf33` |
| `Sources/AgentLoopApp/CodingRanchContracts.swift` | `b404005688e1802ad476b4c72e00863fb4f71a42255be1a700338e4dadbe05ee` |
| `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift` | `12ad0856f5cfc640f770d09230b72077ce83c91ce526f1a8c4b2e734a1fc6e4e` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `ab7b9e7a9c51a74199bcbd2871a4adfa1c939f8df6228f645ac9bd9f5c16598b` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `2f3367fa38ee1b8528eb7aab61d64399ca008a632bd47bdf9e60a821dc46f6e5` |

总 Plan 与 leaf 的 product allowlist 均为 13/13 unique、同路径同顺序；test
allowlist 均为 2/2 unique、同路径同顺序。没有新增 test name、test file、product
file 或权限。

## 8. Immutable manifests

| Immutable boundary | SHA-256 / assertion |
|---|---|
| `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `Sources/AgentLoopCore/Rumination/RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator block（lines 21–612） | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 SQL literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

没有新增/修改 schema、migration、DDL、trigger、EventKind、Package/target graph、
RunTests、strict resolver、RuminationResult/Materializer 或 matrix runner。

## 9. Freeze checks and next gate

R12-E 实际写入范围只有：

- canonical Stage 与总 Plan；
- A2 leaf、A2 `blocked.md` 与本 R12-E evidence；
- 两个 P1 execution control indexes；
- matrix script line 115 的单个 Stage hash value。

Freeze 只执行 read-only/static checks：

- predecessor SHA-256 复算；
- current candidate/allowed/immutable SHA-256 复算；
- 41/41 exact-name count、unique 与总 Plan/leaf 逐项 diff；
- #31 exact name/语义抽查；
- 13+2 allowlist path/count/order；
- Open Questions 与 status；
- Stage §18.1 literal/AppDatabase migrator boundary；
- script R12-D/R12-C/original restoration proof；
- trailing-whitespace/static consistency 与 Review12C path absent；
- 一轮职责隔离只读 preflight `0 P0 / 0 P1 / 0 P2`。

本 freeze 没有运行 product tests、red tests、build、SQLite matrix 或 preview，
也没有创建 Review12C、implementation evidence、implementation Review 或
acceptance。

下一动作只能由未参与 R12-E 修订的职责隔离 reviewer 在 §3 exact hashes 上创建
`reviews/12c-p1-plan-review.md`。其 verdict 为
`APPROVED — 0 P0 / 0 P1` 前，A2 product/test code、red tests、implementation
evidence、implementation Review/acceptance 与 A3 继续禁止。
