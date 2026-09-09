# Review12B — R12-D P1-A2 Independent Plan Review

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Reviewer：未参与 R12-D 修订的职责隔离 reviewer
>
> Verdict：**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**

## 1. 结论

R12-D 已关闭 Review12A 的 identity-bound live-phase invalidation 根因本身：

- Supervisor 的 set-in-flight handoff 不依赖跨 actor FIFO；
- matching identity 的 invalidation 有唯一 owner、first-reason-wins 与
  exactly-once delivery；
- global fatal/control 都先 revoke、await invalidation，再 cancel task；
- Orchestrator exact-match registry/tombstone 与 App clear-before-reload FIFO
  可以阻止旧 positive phase 覆盖新 generation。

但 R12-D 只冻结了 **live phase 的清除 carrier**，没有冻结 **durable projection
commit 后的最终 App refresh owner**。这在两条真实路径上形成缺口：

1. halt 必须先 invalidate live phase，之后才持久化 halted 与 rumination cleanup；
   matching changed event 因而可能只 reload 到仍 active 的 work，并显示
   `.recovering`。cleanup commit 后没有冻结第二次 rumination refresh。
2. cancel、terminal 或 retry 可以在第一条 `.set` 前完成；此时 registry 为空，
   exact invalidation按合同零 event，durable item/work 已改变但 App 收不到 refresh。

当前 candidate 不能唯一决定一个既保证最终 UI truth、又不误清新 generation 的
实现。implementer若自行补发 identity-less `ruminationChanged`、借导航重建/轮询
刷新、或把 `haltStateChanged`/command return 改成新 owner，都属于未冻结的并发与
UI owner决定。因此 A2 implementation gate仍不得打开。

## 2. Repository identity 与审查边界

| Field | Evidence |
|---|---|
| cwd | `/Users/muzi/Agent-loop` |
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| worktree | fully-expanded dirty A1a/A1b accepted baseline；未误报 clean |
| report preflight | 本报告路径不存在 |
| `git diff --check` | PASS，零输出 |

本 reviewer 未参与 R12-D Stage/Plan/leaf/blocker/index/freeze/script 修订。审查中
没有修改产品、测试、Package、migration、runner、script、candidate 或历史证据；
唯一写入是本报告。

这是 plan review，不是 A2 implementation Review、acceptance 或产品验证。遵守
冻结门，本 reviewer没有运行 tests、build、migration matrix 或 preview。

## 3. Governing inputs

已阅读或审计：

- repository `AGENTS.md`；
- `docs/collaboration/claude-codex-protocol.md`；
- master spec 的 P1/A2、failure/recovery、evidence、Goal 与阶段门；
- canonical Stage §6.4、§18.1、§20–§22、§28–§29；
- canonical total Plan §3.3、§10–§13、§18–§19；
- A2 leaf全文、A2 `blocked.md`、P1 Stage/Plan execution indexes；
- immutable Review12、Review12A 与 R12/R12-B/R12-C/R12-D freezes；
- 当前 13+2 future files、immutable boundaries、Supervisor/Orchestrator/App
  composition、phase consumer 与 halt/cancel source topology。

## 4. Frozen candidate 与历史 hashes

以下由 reviewer独立复算，均与 R12-D freeze逐字一致：

| Artifact | SHA-256 |
|---|---|
| canonical Stage `p0/p1-stage-spec.md` | `fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff` |
| canonical total Plan `p0/p1-plan.md` | `dc059ecb5db232179e84014991a65bfc6bcee3080aea6486ee3173ea4d581a8a` |
| A2 leaf `p1-a2-durable-rumination/plan.md` | `5afd02f97e94f9a8aa0406fc06c5a2011951640ab5492e1aaf3aaa0d26ef6f95` |
| A2 `blocked.md` | `0f47e935f29c993f8e0141efb5dd9e18683b2649fccb245c179343e3f6ff2ef8` |
| P1 Stage execution index | `e682a531e58ba046b9e6eab1873c5c023f56cae401ccba34c87420502346c052` |
| P1 Plan execution index | `eabdf5441fcbd1c4d87d9f1bcd7c9299fed6a93e81ecdfe8799c5ab958910ca6` |
| R12-D freeze | `9d4e3bfa2c244b925db9c3bdbde1d30cf86ad42f05453ca5bee9efb5d553c66b` |
| matrix script | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |

历史边界保持 byte-identical：

| Artifact | SHA-256 |
|---|---|
| Review12 | `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| Review12A | `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| R12/R12-A freeze | `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| R12-B freeze | `85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |
| R12-C freeze | `ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` |

Stage、total Plan与leaf状态均为
`R12-D Candidate Frozen；Review12B Pending；A2 Implementation Frozen`。
Open Questions分别在 Stage §29、Plan §19、leaf §13精确为 `无。`。

## 5. Mechanical、scope 与 immutable checks

### 5.1 R12-A script restoration

- current script line 115精确为当前 Stage hash；
- current script SHA-256：
  `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f`；
- 只把 line 115 value恢复成 R12-C Stage
  `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b`
  后，整份流精确恢复为
  `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0`；
- 只恢复成 original Stage
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
  后，整份流精确恢复为
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`；
- runner保持
  `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267`。

没有执行 matrix。

### 5.2 13 product + 2 test entry baselines

R12-D freeze列出的15个 hashes全部 exact：

| Path | SHA-256 |
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

total Plan与leaf的 allowlist均为13 product + 2 tests，unique、同路径同顺序。

### 5.3 Immutable boundaries

| Boundary | Result |
|---|---|
| `PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator lines 21–612 | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 SQL body | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

### 5.4 Exact names 与文档结构

- total Plan与leaf各提取41个 exact test names；
- 各自41 unique、每个反引号 token exact-once、两份有序列表无 diff；
- #31精确为
  `ruminationProviderUsesNoToolsAndProducesOneCanonicalResult`；
- Stage/Plan/leaf Markdown fences分别42/18/2，均为偶数；
- 三份 candidate CR与 trailing whitespace均为0；
- repo `git diff --check`通过。

## 6. Predecessor findings closure

### 6.1 Review12 P1-1 — opaque turn / organizing-before-parse

已关闭。R12-D继承 R12-B 的唯一
`produceValidatedTurn(ingestion:) -> RuminationValidatedTurn`，在返回前完成
exact-one-turn与usage验证；Supervisor在发送 organizing前后各做完整 owner/durable
revalidation，仍 valid才无 await同步调用唯一 `parseValidatedTurn`。不需要恢复旧
callback、第二 provider path或提前/延后伪造 organizing。

### 6.2 Review12 P1-2 — legacy halted × invalid snapshot

已关闭。Stage/Plan/leaf冻结完整 running|halted × valid|三种 invalid snapshot
8-cell表；halted绝对优先，四个 halted组合统一使用 emergency-halt terminal input、
canceled work、queued item、零 domain/attempt event与零 external call。

### 6.3 Review12A P1-1 — second-loss phase invalidation

live-phase invalidation根因已关闭：

- positive set在 await sink前登记 set-in-flight；
- invalidator在任何 await前 mark/revoke；
- control/fatal等待已登记 set返回，再发 matching invalidate；
- duplicate caller等待同一 delivery，first reason wins；
- global fatal owner先 capture sorted identities、revoke、await全部 invalidate，
  才 cancel/remove/wake/return；
- Orchestrator matching remove→tombstone→emit，stale/mismatch不清新 generation；
- App matching changed先clear live phase再reload，event consumer保持串行。

该 closure不等于 durable projection refresh closure；后者是本 Review12B §7 的
独立 plan-completeness finding。

## 7. Finding

### P1-1 — phase-less commit 与 halt post-cleanup 没有最终 App refresh owner

#### 7.1 Frozen contract evidence

Canonical Stage §6.4.9冻结：

1. Orchestrator `.invalidate` 只有在 registry 中
   `ingestionId/workId/attempt` exact-match时，才
   `remove → tombstone → emit(.ruminationChanged)`；
2. registry empty、repeated、stale或mismatch必须零 event，不能清新 generation；
3. App只在 matching `.ruminationChanged` 到达时 clear live phase再 reload；
4. terminal/retry/user-cancel transaction成功后才调用 invalidator；
5. halt/global fatal作为 control winner，必须先 invalidate，再 cancel task；
   emergency halt此后才持久化 halted、planning cleanup与 rumination cleanup。

Leaf §8重复同一顺序：terminal/retry/cancel commit后invalidate；halt/fatal先
invalidate后cancel；App changed clear-before-reload；empty/stale invalidate零 event。

因此 frozen event只证明“某个 exact live phase被移除”，不保证“每个 durable
projection commit之后都发生一次最终 reload”。

#### 7.2 Reachable failing executions

**Halt with a live registry**

1. persisted item/work仍 active，Orchestrator registry存在 organizing；
2. halt winner先 matching invalidate；
3. Orchestrator立即 emit changed，App clear并reload；
4. 因 rumination cleanup尚未执行，App合法读到同一 active work并显示 recovering；
5. Supervisor随后cancel task、持久化 halt并把 item/work原子收口为 queued/canceled；
6. candidate没有冻结 cleanup commit后的第二个 rumination refresh。

结果可以永久停在 recovering，直到偶然导航重建或手动刷新。

**Phase-less successful transition**

1. user cancel可在第一条 phase set前获胜；resolver deterministic/terminal或retry
   transition也可在 live registry建立前完成；
2. specialized transaction成功改变 durable work/item；
3. invalidator收到 exact identity，但 registry empty；
4. 合同要求零 event；
5. App没有 durable projection refresh carrier，仍可显示旧 queued/ruminating/
   recovering/failed projection。

这不是不可达 race，也不能由 tombstone或 persisted work/attempt matching解决；
matching只控制 phase event是否可见，不主动刷新 durable事实。

#### 7.3 Current-source feasibility evidence

- current `Orchestrator.emergencyStop()` 在全部持久化/cleanup完成后已有
  `.haltStateChanged(true)`；
- current `AppStore.handleKernelEvent(.haltStateChanged)` 只更新 halt state并
  reload mission list/current mission，没有 reload Coding Ranch dashboard/inbox；
- current `CodingRanchStoreAdapter.cancelRumination`只执行 cancel，不 reload；
- current detail view在 cancel成功后 close；依赖 view/navigation生命周期重建不是
  durable、可测试或冻结的 refresh owner。

允许文件足以实现多种不同方案，但 candidate没有选择并冻结其中任何一种。尤其不能
让 implementer简单无条件补发 identity-less `ruminationChanged`：Orchestrator actor
在 await期间可重入，新 generation可能已经建立；无身份 changed可能误清新 phase，
正好破坏 R12-D 刚冻结的 stale/mismatch安全性。

#### 7.4 Required bounded closure

Planner必须在同一 R12-D phase/UI 根因内有界冻结：

- terminal/retry/cancel在有 live phase与无 live phase两种情况下，durable commit后
  最终 App refresh的唯一 owner与 exact order；
- halt中 pre-cancel invalidation与 post-cleanup final refresh的唯一 owner/order，
  包括 persistence/cleanup failure时不得伪装 queued；
- refresh与新 generation并发时的 identity/order fence，不能用无条件 identity-less
  event误清新 phase；
- App consumer/command completion路径如何保持串行，禁止靠 unowned Task、轮询、
  导航重建或手动刷新；
- 在既有 exact tests与 real enclosing-range/order source gate中加入
  phase-less cancel/terminal/retry、halt pre/post commit、stale/new-generation
  race与最终 persisted UI projection断言。

Reviewer不替 planner选择 `haltStateChanged`、command completion、扩展 carrier或
其他具体 owner。任何方案仍须保持 one Supervisor、one rumination sink、
identity-bound invalidation、no schema/EventKind、13+2 allowlist与 R12-D 其余红线，
除非牧场主另行授权扩大范围。

### Finding summary

- P0：0。
- P1：1。
- P2：0。

## 8. Commands deliberately not run

本 Review没有运行：

- `swift run RunTests` 或 targeted/red tests；
- `swift test`；
- `swift build`、App build或release build；
- SQLite 3.51/3.52 migration matrix；
- preview、UI smoke或产品进程；
- commit、push、merge、release、数据重置或外部操作。

只执行了只读源码/文档审计、Git identity/status、SHA-256与manifest复算、script
输入流 restoration、allowlist/test-name/structure检查及 `git diff --check`。

## 9. Gate

Review12B未批准 R12-D candidate。A2 product/test implementation、red tests、
implementation evidence、implementation Review、acceptance与 A3继续冻结。

只有 §7 P1经获授权的有界修订、重新冻结，并由未参与修订的职责隔离 reviewer在新
exact hashes上给出 `APPROVED — 0 P0 / 0 P1` 后，才能重新评估 A2 implementation
gate。

## 10. Verdict

CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2
