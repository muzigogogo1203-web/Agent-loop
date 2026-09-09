# R12-D Plan Freeze Evidence

> 状态：R12-D Candidate Frozen；Review12B Pending；A2 Product/Test Code Frozen
>
> 日期：2026-07-27
>
> Owner：R12-D planner

本证据只冻结获授权的 Review12A P1-1 identity-bound live-phase invalidation
closure与既有 R12-A 单行 control delta。它不是职责隔离 Review、产品/测试
implementation、test/build/matrix/preview结果或 acceptance。

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
| immutable R12/R12-A freeze | `evidence/plan-freeze.md`；`652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| immutable R12-B freeze | `evidence/plan-freeze-r12b.md`；`85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |
| immutable R12-C freeze | `evidence/plan-freeze-r12c.md`；`ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` |
| next review path | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12b-p1-plan-review.md`；freeze时不存在 |

上述五个 historical artifacts 已直接复算并保持 byte-identical。R12-D 没有改写
predecessor verdict、manifest或审查报告。

## 2. Review12A input snapshot and bounded finding

Review12A 直接复算的 R12-C candidate 为：

| R12-C artifact | SHA-256 |
|---|---|
| canonical Stage | `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` |
| canonical total Plan | `3dfaf7806a0f1be5c7592a25ce98dfb4c866cd9120ed38a17c3eb751db7eee6b` |
| A2 leaf Plan | `db0085b9fdb63266a4bdf6f3bb77ba2d4c307bce01b74b268a37c6b52aa7bd07` |
| A2 `blocked.md` | `1268c8071aba6f5cc3286b91f7cfc1315cebafc8c64dd019d6aa5c973abf0a28` |
| P1 Stage control index | `870eec359be86a710c51e6fd25476601df2f3abaa7ee412de7f5fc17fa2554b2` |
| P1 Plan control index | `824a19d13154d0e0c2ec29a9118669d884ea372a2465f40318d1bdf64f900f4d` |
| matrix script | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |

Review12A 的唯一 P1 是：第二轮 expected control loss 或 DB/invariant global fatal
要求零业务写，persisted active workId/attempt 因而可保持不变；R12-C
positive-only phase sink没有 identity-bearing invalidation producer，不能必然清除
已经线性化的 organizing。R12-D 只关闭该同一根因；没有重审或改写其他 A2决定。

## 3. Canonical R12-D candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `dc059ecb5db232179e84014991a65bfc6bcee3080aea6486ee3173ea4d581a8a` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `5afd02f97e94f9a8aa0406fc06c5a2011951640ab5492e1aaf3aaa0d26ef6f95` |
| A2 `blocked.md` | `0f47e935f29c993f8e0141efb5dd9e18683b2649fccb245c179343e3f6ff2ef8` |
| P1 Stage control index | `e682a531e58ba046b9e6eab1873c5c023f56cae401ccba34c87420502346c052` |
| P1 Plan control index | `eabdf5441fcbd1c4d87d9f1bcd7c9299fed6a93e81ecdfe8799c5ab958910ca6` |
| matrix script | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |

Canonical Stage §29、总 Plan §19与 A2 leaf §13 的 Open Questions均精确为
`无。`。三份正文状态均精确为
`R12-D Candidate Frozen；Review12B Pending；A2 Implementation Frozen`。本
evidence不把自身hash写回控制索引，因此没有自指hash环。

## 4. Identity-bound ordered invalidation closure

R12-D 冻结的唯一 command/callback为：

- exact identity：`ingestionId:String,workId:String,attempt:Int`；
- exact reasons：`controlLoss|globalFatal`；
- exact commands：
  `set(identity:phase:)` 与 `invalidate(identity:reason:)`；
- exact sink：
  `onRuminationPhase: @escaping @Sendable (RuminationPhaseCommand) async -> Void
  = { _ in }`。

该 command不携带raw text、usage、result、Error/string diagnostics、DB record或
业务terminal事实。所有positive phase与invalidation共用该一个awaited callback；
没有第二callback、unowned Task、persistent phase、schema或EventKind。

Supervisor actor是唯一command owner：

1. positive set在await前登记exact identity set-in-flight；
2. unique invalidator在任何await前mark in-flight并revoke后续set；
3. 若已有set sink in-flight，先用checked continuation等待它返回，再发
   invalidate，不依赖跨actor mailbox FIFO；
4. reentrant duplicate等待同一nonthrowing delivery，first safe reason wins，
   exact identity只deliver一次；
5. ownership/control、terminal/retry/cancel/halt/shutdown映射
   `controlLoss`；DB/invariant/其他global fatal映射`globalFatal`；#27的actor
   fatal格复用global-fatal first winner，不产生第二controlLoss emission；
6. cancellation、timeout或task completion不能拥有或跳过delivery。

唯一production fatal writer精确为
`latchFatalAndInvalidateRumination(_:operation:workId:) async`。所有fatal state
writer、`.fatal` classification、`latchFatal`/`latchReadFailure`与revoke-all
wrapper必须route/await该owner，或在任何mutation前证明零
active/owned/set-in-flight/live rumination并fail-fast。exact order为：

`capture sorted identities → revoke set/terminal/generation permission → mark
invalidation → await registered set-in-flight → await sorted invalidate → cancel
provider/renewal tasks → remove/wake/return/throw`。

terminal/retry/user-cancel只在业务transaction成功后invalidate；rollback保留
适用的pending proposal/live phase。halt/fatal/shutdown先invalidate再cancel task；
halt后续persistence/cleanup失败仍保持suppressed/recovering。

## 5. Registry, FIFO, restart, and completion gates

Production Orchestrator actor唯一持有process-local exact identity/phase registry与
每ingestion至少last-invalidated tombstone：

- legal set先更新registry再emit phase；
- matching invalidate才remove→tombstone→恰好一次既有
  `ruminationChanged(ingestionId:)`；
- repeated/empty/stale/mismatched invalidate为零event且不能清新generation；
- tombstoned old positive set不能revive。

Supervisor的set-in-flight handoff保证set sink调用先于matching invalidate sink调用。
Orchestrator在actor上同步mutation/emit，App串行消费AsyncStream；matching changed
先clear live phase再reload，consumer不另起Task重排。Restart registry/tombstone从
empty开始；persisted `.ruminating`无本进程matching set只能显示`.recovering`/
`正在恢复`。Global fatal保持durable work/item/attempt/result逐字不变，但
invalidation后相同persisted identity也只能recovering。

现有41个test names保持41/41 unique、总Plan/leaf逐项同序；#31仍精确为
`ruminationProviderUsesNoToolsAndProducesOneCanonicalResult`，其one streamTurn、
tools empty、opaque-before-parse、one parse与exact usage语义未改。R12-D只扩展
现有#27/#35 assertions与source-range/order gate，覆盖：

- 两轮expected loss与DB/invariant fatal；
- fatal/globalFatal与其他controlLoss first-winner mapping；
- paused set→revoke→wait set return→invalidate；
- duplicate exactly-once与cancellation不能跳过；
- stale/mismatched/new-generation与old positive revival；
- terminal/retry/cancel/halt registry clear、rollback与restart recovering；
- all fatal/revoke callsites和default-no-op production bypass；
- Orchestrator exact-match remove/tombstone/emit与App clear-before-reload FIFO。

Fail-fast source gate必须解析真实handler、owned task catch、validator、unique
invalidator、fatal/control owner、Orchestrator registry handler与App consumer的
enclosing ranges与call order；substring/count-only、复制helper或未锁owner/order
不算通过。

一轮未参与正文修订的只读preflight在最新稳定bytes上得到
`0 P0 / 0 P1 / 0 P2`。该preflight没有创建review报告，也不替代Review12B。

## 6. R12-A exact control delta

| Check | Result |
|---|---|
| script path | `scripts/verify-p1-migrations-sqlite-matrix.sh` |
| original baseline SHA-256 | `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| R12-C predecessor SHA-256 | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| final R12-D candidate SHA-256 | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |
| only authorized value | line 115 `expected_stage_hash="fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff"` |
| R12-C restoration | replacing final value with R12-C Stage `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` yields exact R12-C script SHA `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| original restoration | replacing final value with original Stage `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` yields exact original script SHA `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| runner | byte-identical `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |

因此script的fixture、literal、linked lanes、assertions、commands与全部其他bytes
未改变。本freeze没有执行matrix；Review12B必须自行复算该proof。

## 7. Zero A2 product/test drift

以下15个hashes与Review12A/R12-C entry逐字一致，证明R12-D planner未实施A2：

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

总Plan与leaf的product allowlist均为13/13 unique、同路径同顺序；test allowlist均为
2/2 unique、同路径同顺序。没有新增test name、test file、product file或权限。

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

没有新增/修改schema、migration、DDL、trigger、EventKind、Package/target graph、
RunTests、strict resolver、RuminationResult/Materializer或matrix runner。

## 9. Freeze checks and next gate

R12-D 实际写入范围只有：

- canonical Stage与总Plan；
- A2 leaf、A2 `blocked.md`与本R12-D evidence；
- 两个P1 execution control indexes；
- matrix script line 115的单个Stage hash value。

Freeze只执行read-only/static checks：

- predecessor SHA-256复算；
- current candidate/allowed/immutable SHA-256复算；
- 41/41 exact-name count、unique与总Plan/leaf逐项diff；
- #31 exact name/语义抽查；
- 13+2 allowlist path/count/order；
- Open Questions与status；
- Stage §18.1 literal/AppDatabase migrator boundary；
- script R12-C/original restoration proof；
- trailing-whitespace/diff-check与Review12B path absent；
- 一轮职责隔离只读preflight `0 P0 / 0 P1 / 0 P2`。

本freeze没有运行product tests、red tests、build、SQLite matrix或preview，也没有
创建Review12B、implementation evidence、implementation Review或acceptance。

下一动作只能由未参与R12-D修订的职责隔离reviewer在§3 exact hashes上创建
`reviews/12b-p1-plan-review.md`。其verdict为
`APPROVED — 0 P0 / 0 P1`前，A2 product/test code、red tests、implementation
evidence、implementation Review/acceptance与A3继续禁止。
