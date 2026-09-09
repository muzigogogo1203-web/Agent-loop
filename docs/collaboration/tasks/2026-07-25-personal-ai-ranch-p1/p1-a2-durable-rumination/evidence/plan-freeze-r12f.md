# R12-F Plan Freeze Evidence

> 状态：R12-F Candidate Frozen；Review12C Pending；A2 Product/Test Code Frozen
>
> 日期：2026-07-27
>
> Owner：R12-F planner

本证据只冻结获授权的 normal start/user-retry durable-projection closure，以及继承
的 R12-A 单行 control delta。它不是职责隔离 Review、产品/测试 implementation、
test/build/matrix/preview 结果或 acceptance。

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
| immutable R12-E freeze | `evidence/plan-freeze-r12e.md`；`2f9f3c494ab2d37c3d503f1ec65e97013d5edd2f08f9f300f15928145924c431` |
| next review path | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`；freeze 时不存在 |

上述 historical artifacts 已直接复算并保持 byte-identical。R12-F 没有改写
predecessor verdict、manifest 或审查报告。

## 2. R12-E snapshot and bounded finding

R12-E predecessor 精确为：

| R12-E artifact | SHA-256 |
|---|---|
| canonical Stage | `59f52f7d7d08889afb12b4524f67152ea0ca59fe240300cf798d6ab526738935` |
| canonical total Plan | `767a9604d1a10a819db73fee730d02c312b1e759161ba506ff3ca7223c51b16b` |
| A2 leaf Plan | `1f93ebb1d8ddfb55249021fd0288ce3cba203781c96a025abe7ffb4c20da0f7e` |
| A2 `blocked.md` | `3cdaae2d44c63e0469fb4be1a4566a763cf40bf416ab9472c06247dccaccb6cc` |
| P1 Stage control index | `057a602a5ec043726af0dfa052bb8a8dee6072deb00787a9966ae1d22df1dbef` |
| P1 Plan control index | `ff49f45856d728eb50e81158ce4dcf9b38026e877bcda538bb64cac55de3ff64` |
| matrix script | `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |

R12-E 后续有界设计审计（无 Review12C 文件）为
`0 P0 / 2 P1 / 1 P2`：

1. normal start/user retry transaction 已提交 queued attempt-zero work，却没有
   final App persisted-projection refresh publisher；
2. 只在 caller return 前补 awaited refresh 仍不充分：Supervisor actor 可在 sink
   await期间重入，已有 pump/timer/kick可能先 claim；
3. active replay若从 current attempt/version合成milestone，会重复refresh，running
   replay还可能exact-match并清真实live phase；
4. commit与process-local delivery之间的进程死亡不能在禁止持久outbox/receipt的
   A2范围内提供跨进程event exactly-once，这是未扩张的P2。

牧场主授权R12-F只关闭两个P1；P2以durable row + restart persisted snapshot truth
收口，不新增schema/checkpoint。

首次R12-F candidate独立预检（仍无Review12C文件）随后给出
`0 P0 / 1 P1 / 1 P2`：

1. 若允许另一production进程在当前进程target-Camp snapshot ready后写同一state
   root，后者commit并死亡会使零milestone/零reload replay保留stale projection；
2. new specialized insert合同应从`version>=1`收紧为exact `version=1`。

获授权closure选择现有、可验证的production single-writer invariant，不扩大
event/replay refresh API：AppStore lifetime-held `StateDirectoryLock`以
nonblocking exclusive `flock`先于同root唯一production `AppDatabase(path:)`；
second owner fail-fast，旧owner死亡后新owner必须重走startup snapshot ready。
因此该跨进程TOCTOU在当前产品不可达；未来CLI/硬件同root writer须另开stage设计
coordination/outbox。inserted与attempt-zero start identity同步收紧exact
`workVersion=1`。

## 3. Canonical R12-F candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `79c9252048697a84c395c5bbdad2bd68495f07fec4a9294c5b6937b02d8e02ab` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `42ddb63dc73cd62514f09956b08378d397d146c2c5eba19c57a3950835bef2e3` |
| A2 `blocked.md` | `1b6e4b54b03ca9bbe2d76b54c106f3a2d931bbc7adc84106ed39039c74e9dc91` |
| P1 Stage control index | `c6b61b9862e3980b3020f32a65395f2e3fa1030c2f1b5b3632187dcaa43856d0` |
| P1 Plan control index | `b4cb7fad819b7bb92f922b79f81a929b845d020f211852f21e5bccbdddcec5c4` |
| matrix script | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467` |

Canonical Stage §29、总 Plan §19 与 A2 leaf §13 的 Open Questions 均精确为
`无。`。三份正文状态均精确为
`R12-F Candidate Frozen；Review12C Pending；A2 Implementation Frozen`。本
evidence 不把自身 hash 写回控制索引，因此没有自指 hash 环。

## 4. Unique start owner and exact Store outcome

唯一 public flow 是：

`Orchestrator façade → single DurableWorkSupervisor start owner → specialized Store`

Orchestrator、App、Adapter和Service不得直接调用specialized Store start、发布
projection或先行kick。Supervisor唯一拥有absent preflight、Store transaction、
post-commit delivery与conditional kick。

Store复用已存在的`DurableWorkEnqueueResult(work,disposition)`，不新增第二start
outcome type：

- 只有本次transaction实际提交queued work、item ruminating、checked generation
  increment和error clear，才返回
  `work=<resulting work>, disposition=.inserted`；
- resulting work必须exact为
  `kind=.rumination,aggregateType=ingestion,aggregateId=<ingestionId>,
  state=queued,attempt=0,version=1`；specialized transaction不得二次推进new work
  version；
- same-key/完整active graph为
  `work=<original work>, disposition=.replayed`且整次operation零写；
- preflight/same-key conflict/rollback/throw固定零barrier、零reservation、零sink、
  零event、零kick。

两种replay origin归一为同一Supervisor workId branch：

1. App preparation `replay(ingestionId,workId)`：绕过resolver和specialized Store；
2. concurrent new-command在transaction重验时由Store返回`.replayed`。

二者都不能从replay时的current attempt/version构造
`RuminationProjectionCommitIdentity`。

## 5. Start barrier, replay, restart, and immediate control

`.inserted` transaction同步return后，Supervisor在同一actor turn、第一次await或
actor reentrancy前原子完成：

1. validate exact kind/aggregate/ingestion/queued/attempt-zero/resulting version；
2. 从resulting work构造attempt-zero full projection identity；
3. reserve既有唯一projection publisher；
4. 登记Supervisor-owned process-local start-projection barrier。

统一global FIFO claim入口在任何DB claim前检查全部barrier。任一存在时：

- planning与rumination都零DB claim；
- 不得跳过rumination head去claim planning或其他work；
- existing pump、timer、concurrent kick与actor reentrancy均不能绕过。

Supervisor awaited调用既有单一nonthrowing sink；task cancellation、
`Task.isCancelled`、`CancellationError`或early return不得跳过delivery。sink返回后
才release barrier，再重读durable mode和current work；只有仍running+active才
kick/return。若control已经canceled/halted该work，零stale kick/claim。

`.replayed`本次零commit，因此：

- original inserted delivery仍in-flight时，只按workId等待Supervisor保存的原
  delivery；
- delivery已完成、或新进程没有waiter/receipt时，零等待、零第二sink/event；
- kick失败只可由同key replay重试kick，不能重发projection；
- running/retryScheduled replay永不合成current-version milestone，不能清live phase
  或产生same-version/different-identity冲突。

restart时不声称跨进程event exactly-once。App必须先经同一Adapter persisted
snapshot path成功加载**目标ingestion所属Camp**并标记ready，才enable该ingestion
的start/retry action；load failure保持disabled并显示既有显式load failure，不能在
无projection时清startup pending。active graph在空registry/waiter/receipt的新进程
精确显示`.recovering`；background Camp readiness只更新对应cache，不切selected
Camp。

该restart freshness还以当前产品同一state root single-writer为entry/red line：
AppStore的`private let stateDirectoryLock`完整lifetime持有同一appSupport root，
`StateDirectoryLock(directoryURL:appSupport)`成功发生在production source tree
唯一`AppDatabase(path:<same-root>/agentloop.sqlite)`之前。锁使用
`flock(LOCK_EX|LOCK_NB)`，`EACCES|EAGAIN` second owner fail-fast，deinit/process
death unlock/close。故不存在current owner ready后另一production owner再commit的
TOCTOU；下一owner取得锁、打开DB后仍必须先完成target-Camp snapshot ready。
replay继续零milestone、零direct reload。

start `V` sink暂停时，reentrant actual user cancel/halt可以提交同work严格更高
`V+1`；既有per-identity coordinator保证sink顺序严格为start `V`→control `V+1`、
最大并发1。start恢复后重验，不复活/claim canceled work。新generation使用新
workId；旧event只reload当前snapshot，不清新live identity。same-version/different
identity继续在sink/event前fail-fast。

## 6. Preserved event/API boundary and completion gates

R12-F 保留R12-E的唯一callback：

`onRuminationPhase: @escaping @Sendable (RuminationPhaseCommand) async -> Void
= { _ in }`

command仍只有`.set(identity:phase:)`与
`.invalidate(RuminationInvalidationMilestone)`；milestone仍只有
`.phase(identity:reason:)`与`.projectionCommitted(commitIdentity)`。
`RuminationChange`仍只有`.phaseInvalidated(identity)`与typed
`.projectionCommitted(commitIdentity,invalidatedPhaseIdentity:)`；KernelEvent仍
只有两个process-local rumination cases。没有新增schema/migration/DDL/EventKind、
persistent phase/receipt、callback、KernelEvent case或文件。

41个exact test names保持41/41 unique，总Plan与leaf逐项同序；#31名称和
provider/parse语义不变。产品allowlist保持13/13 unique同序，test allowlist保持2/2
unique同序。只扩现有#1/#6/#11/#22/#33/#34/#35：

- inserted exact identity与transaction→reserve+barrier→delivery→release→re-read→
  conditional kick，其中inserted exact `version=1`；
- paused sink下existing pump/timer/kick零DB claim、零FIFO skip；
- 两种replay origin、workId-only waiter、delivered/restart零第二event；
- target-Camp ready-before-command与load-failure-disabled；
- AppStore lifetime-held lock-before-唯一production DB open、second-owner
  fail-fast/release以及两个lock文件byte-identical；
- start `V`→cancel/halt `V+1`；
- rollback/conflict零barrier/reserve/sink/kick；
- Adapter completion仍零refresh owner。

source-range/order gate必须解析真实Supervisor start owner、Store call、全部global
claim入口、projection publisher、Orchestrator façade/registry与App readiness/event
consumer。substring/count-only或复制helper不算通过。

## 7. R12-A exact control delta

| Check | Result |
|---|---|
| script path | `scripts/verify-p1-migrations-sqlite-matrix.sh` |
| original baseline SHA-256 | `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| R12-C predecessor SHA-256 | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| R12-D predecessor SHA-256 | `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |
| R12-E predecessor SHA-256 | `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |
| final R12-F candidate SHA-256 | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467` |
| only authorized value | line 115 `expected_stage_hash="cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9"` |
| R12-E restoration | replacing final value with R12-E Stage `59f52f7d7d08889afb12b4524f67152ea0ca59fe240300cf798d6ab526738935` yields exact R12-E script SHA `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |
| R12-D restoration | replacing final value with R12-D Stage `fdf93470e8c3bb16f3dbe6453c577aac278ff0937a3a7283cc98f786675901ff` yields exact R12-D script SHA `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f` |
| R12-C restoration | replacing final value with R12-C Stage `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` yields exact R12-C script SHA `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| original restoration | replacing final value with original Stage `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` yields exact original script SHA `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| runner | byte-identical `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |

除line 115的单个64-hex value外，script fixture、literal、linked lanes、
assertions、commands与其他bytes不变。本freeze没有执行matrix。

## 8. Zero A2 product/test drift

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

没有修改产品或测试代码，没有新增test name/file、product file或权限。

## 9. Immutable manifests

| Immutable boundary | SHA-256 / assertion |
|---|---|
| `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `Sources/AgentLoopCore/Rumination/RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/AgentLoopCore/Support/StateDirectoryLock.swift` | `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363` |
| `Sources/AgentLoopTestSuite/SupportTests.swift` | `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator block（lines 21–612） | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 SQL literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

没有新增/修改schema、migration、DDL、trigger、EventKind、Package/target graph、
RunTests、strict resolver、RuminationResult/Materializer、StateDirectoryLock、
SupportTests或matrix runner；两个lock文件不在13+2 allowlist。

## 10. Freeze checks and next gate

R12-F实际写入范围只有：

- canonical Stage与总Plan；
- A2 leaf、A2 `blocked.md`与本R12-F evidence；
- 两个P1 execution control indexes；
- matrix script line 115的单个Stage hash value。

Freeze只执行read-only/static checks：

- predecessor/current/allowed/immutable SHA-256复算；
- 41/41 exact-name count、unique与总Plan/leaf逐项diff；
- #31名称/语义抽查；
- 13+2 allowlist path/count/order；
- Open Questions、status与Review12C path absent；
- Stage §18.1 literal/AppDatabase migrator boundary；
- script R12-E/R12-D/R12-C/original restoration proof；
- `git diff --check`；
- start barrier、两种replay origin、target-Camp readiness、immediate control与
  source-range/order gate的有界静态自审；
- production `AppDatabase(path:)` callsite=1、AppStore lock acquisition
  before-open与lifetime ownership、lock source语义/immutable hashes；
- 首次独立预检`0 P0 / 1 P1 / 1 P2` finding及single-writer/exact-version closure
  后的职责隔离复核。

planner最终自审与未参与修订的独立预检closure复核均为
`0 P0 / 0 P1 / 0 P2`。本freeze没有运行product tests、red
tests、build、SQLite matrix或preview，也没有创建Review12C、implementation
evidence、implementation Review或acceptance。

下一动作只能由未参与R12-F修订的职责隔离reviewer在§3 exact hashes上创建
`reviews/12c-p1-plan-review.md`。其verdict为
`APPROVED — 0 P0 / 0 P1`前，A2 product/test code、red tests、implementation
evidence、implementation Review/acceptance与A3继续禁止。
