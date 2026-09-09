# Review12C — R12-F P1-A2 Independent Plan Review

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Reviewer：未参与 R12-F 修订的职责隔离 reviewer
>
> Verdict：**APPROVED — 0 P0 / 0 P1**

## 1. 结论

R12-F candidate 已把 Review12、Review12A、Review12B 以及 R12-E follow-up 的
P0/P1 根因闭合为一套可执行且可验证的 A2 合同：

- normal start 与 failed user retry 只有 Supervisor actor 是 command owner；
  Store 实际插入的 queued attempt-zero `version=1` work 是 start projection
  identity 的唯一来源；
- `.inserted` 返回后，在同一 actor turn、第一次 await/reentrancy 前完成 full
  identity reservation 与 process-local global-claim barrier；
- barrier 覆盖 pump、timer、kick 与 global FIFO claim 的全部入口，期间对
  planning 与 rumination 都是零 DB claim、零跨 kind skip；delivery 完成后才
  release、重读 durable mode/work 并 conditional kick；
- preparation replay 与 Store transaction-race `.replayed` 都按 `workId`
  归一；只等待本进程原始 inserted delivery，禁止从 current attempt/version
  合成 identity，delivered/restart 固定零第二 sink/event；
- process-death freshness 由当前产品已经存在的 single-writer
  lock-before-DB-open 边界与 command-enable 前 target-Camp persisted snapshot
  ready gate共同闭合；未来 CLI/硬件同 root multi-writer 明确属于另一 stage；
- live phase 与 durable projection 共用一个 awaited typed sink，并由
  per-identity coordinator 串行；start `V` 与 reentrant cancel/halt `V+1`、
  retry `V+1` 与 cancel/halt `V+2`、commit-first 与 control/fatal-first 两向
  race 都有唯一顺序；
- terminal/retry/cancel/halt 的 durable commit refresh 由 full resulting
  commit identity 唯一发布；App 以一个 listener 直接 await handler，按同一
  snapshot校验、typed exact clear、always serial reload，background Camp 不导航。

未发现需要 implementer 自行决定的架构、数据模型、依赖、schema、EventKind、
callback、文件范围或 completion-gate 缺口。Findings 为
**0 P0 / 0 P1 / 0 P2**。

因此 Review12C plan gate通过。只要 implementer 启动前再次核对本报告与 R12-F
exact hashes、single-writer entry invariant及 scope manifest均未漂移，即可按
A2 leaf从 failure-first tests开始实施。A2 completion、implementation Review、
acceptance 与 A3 gate仍保持原样，不能因本 Review 自动越过。

## 2. Repository identity 与审查边界

| Field | Evidence |
|---|---|
| cwd | `/Users/muzi/Agent-loop` |
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| worktree | fully-expanded dirty A1a/A1b accepted baseline；未误报 clean |
| report preflight | 本报告路径在写入前不存在 |
| `git diff --check` | PASS，零输出 |

本 reviewer 未参与 R12-F Stage/Plan/leaf/blocker/index/freeze/script 修订。审查中
没有修改产品、测试、Package、migration、runner、script、candidate、控制索引、
blocker、历史证据或 implementation artifact；唯一写入是本报告。

这是 plan review，不是 A2 implementation Review、acceptance 或产品验证。遵守
冻结门，本 reviewer没有运行 red tests、`swift run RunTests`、build、SQLite
matrix、preview 或产品进程。

## 3. Governing inputs

已阅读或静态审计：

- repository `AGENTS.md`；
- `docs/collaboration/claude-codex-protocol.md`；
- master spec全文，特别是 P1/A2、failure/recovery、证据、Goal 与阶段门；
- canonical Stage §6.4、§18.1、§20–§22、§28–§29；
- canonical total Plan §3.3、§10–§13、§18–§19；
- A2 leaf全文、A2 `blocked.md`、P1 Stage/Plan execution indexes；
- immutable Review12、Review12A、Review12B；
- R12/R12-A、R12-B、R12-C、R12-D、R12-E 与 R12-F freezes；
- 当前 13+2 future files、immutable boundaries、single-writer lock、
  Supervisor/Store/Orchestrator/App composition、provider/parse、Feed/Ingestion、
  Camp archive、phase consumer、halt/cancel及测试 source topology。

## 4. Frozen candidate 与历史 hashes

以下由 reviewer独立复算，均与 R12-F freeze逐字一致：

| Artifact | SHA-256 |
|---|---|
| canonical Stage `p0/p1-stage-spec.md` | `cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9` |
| canonical total Plan `p0/p1-plan.md` | `79c9252048697a84c395c5bbdad2bd68495f07fec4a9294c5b6937b02d8e02ab` |
| A2 leaf `p1-a2-durable-rumination/plan.md` | `42ddb63dc73cd62514f09956b08378d397d146c2c5eba19c57a3950835bef2e3` |
| A2 `blocked.md` | `1b6e4b54b03ca9bbe2d76b54c106f3a2d931bbc7adc84106ed39039c74e9dc91` |
| P1 Stage execution index | `c6b61b9862e3980b3020f32a65395f2e3fa1030c2f1b5b3632187dcaa43856d0` |
| P1 Plan execution index | `b4cb7fad819b7bb92f922b79f81a929b845d020f211852f21e5bccbdddcec5c4` |
| R12-F freeze | `d88c14815b08aaa9187ae4053b33c8bfa45b1b03b0f2d2d61adf24e76bebbf41` |
| matrix script | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467` |

历史边界保持 byte-identical：

| Artifact | SHA-256 |
|---|---|
| Review12 | `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| Review12A | `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| Review12B | `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5` |
| R12/R12-A freeze | `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| R12-B freeze | `85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |
| R12-C freeze | `ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` |
| R12-D freeze | `9d4e3bfa2c244b925db9c3bdbde1d30cf86ad42f05453ca5bee9efb5d553c66b` |
| R12-E freeze | `2f9f3c494ab2d37c3d503f1ec65e97013d5edd2f08f9f300f15928145924c431` |

R12-E predecessor snapshot也独立复算并与 R12-F freeze一致：

| Artifact | SHA-256 |
|---|---|
| R12-E Stage | `59f52f7d7d08889afb12b4524f67152ea0ca59fe240300cf798d6ab526738935` |
| R12-E total Plan | `767a9604d1a10a819db73fee730d02c312b1e759161ba506ff3ca7223c51b16b` |
| R12-E leaf | `1f93ebb1d8ddfb55249021fd0288ce3cba203781c96a025abe7ffb4c20da0f7e` |
| R12-E blocker | `3cdaae2d44c63e0469fb4be1a4566a763cf40bf416ab9472c06247dccaccb6cc` |
| R12-E Stage index | `057a602a5ec043726af0dfa052bb8a8dee6072deb00787a9966ae1d22df1dbef` |
| R12-E Plan index | `ff49f45856d728eb50e81158ce4dcf9b38026e877bcda538bb64cac55de3ff64` |
| R12-E matrix script | `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b` |

Stage、total Plan与leaf状态均精确为
`R12-F Candidate Frozen；Review12C Pending；A2 Implementation Frozen`。
Open Questions分别在 Stage §29、Plan §19、leaf §13精确为 `无。`。

## 5. Mechanical、scope 与 immutable checks

### 5.1 R12-A script restoration

- current script line 115精确为当前 R12-F Stage hash；
- current script SHA-256为
  `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467`；
- 只把 line 115 value恢复成 R12-E Stage后，整份流精确恢复为
  `3f35fb3760ec92cc5438bd995c65970943d193e8625854f12e63bc23e9ce045b`；
- 恢复成 R12-D Stage后，整份流精确恢复为
  `dbd4c80785205757b7288a4c529bb9835bf82343b21e7313b798dfb52102652f`；
- 恢复成 R12-C Stage后，整份流精确恢复为
  `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0`；
- 恢复成 original Stage后，整份流精确恢复为
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`。

runner保持
`db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267`。
没有执行 matrix。

### 5.2 13 product + 2 test entry baselines

R12-F freeze列出的15个 hashes全部 exact：

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
| `StateDirectoryLock.swift` | `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363` |
| `SupportTests.swift` | `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386` |
| `PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| migration matrix runner | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator lines 21–612 | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 SQL body | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

未发现 schema、migration、DDL、trigger、EventKind、Package/target/dependency、
RunTests、strict resolver、RuminationResult/Materializer、lock或runner drift。

### 5.4 Exact names 与文档结构

- total Plan与leaf各提取41个 exact test names；
- 各自41 unique、两份有序列表无 diff；
- #31精确为
  `ruminationProviderUsesNoToolsAndProducesOneCanonicalResult`；
- Stage/Plan/leaf Markdown fences分别42/18/2，均为偶数；
- 三份 candidate trailing whitespace与 CR计数均为0；
- repo `git diff --check`通过。

## 6. Adversarial contract review

### 6.1 Normal start、retry 与 global claim barrier

冻结顺序可在线性化：

1. Orchestrator只调用 Supervisor normal-start façade；
2. Supervisor在无 active/replay graph时完成 strict preflight；
3. specialized Store transaction重验并返回既有
   `DurableWorkEnqueueResult`；
4. 只有 `.inserted` 的 exact queued attempt-zero `version=1` resulting work可
   构造 full commit identity；
5. Store同步返回后、Supervisor同一 actor turn第一次 await前完成 identity
   reserve与global claim barrier；
6. await唯一 nonthrowing sink；
7. release barrier，重读 durable mode/work，仅 running+active时 conditional kick。

当前 `DurableWorkSupervisor` 的 DB claim是actor内同步调用，已有 pump在 claim
transaction中时 start不能同时进入actor；start先进入时又会在第一次让出actor前建立
barrier。因此不存在 commit后、barrier前被同进程 claim的窗口。R12-F还把
barrier check钉在 runPump、timer wake、kick及所有 specialized global claim入口，
不会通过“跳过rumination、先claim planning”绕开。

start sink暂停时 reentrant user cancel/halt可以提交更高 version，但与 start
projection共用同一 identity coordinator，所以严格 `V → V+1`。start恢复后重验
非active或halted，固定零复活、零claim。sink为 nonthrowing awaited owner，
cancellation不能绕过required delivery/release。

### 6.2 两种 replay origin

App preparation `replay(ingestionId,workId)`明确绕过 resolver与 Store start；
Store transaction-race `.replayed`则从 normal command到达。二者都进入 Supervisor
同一 `workId` branch：

- original inserted delivery仍在本进程 in-flight时只等待该 delivery；
- delivery已完成时零等待；
- process restart没有 waiter/receipt时零等待；
- 三种情况都禁止从 current attempt/version构造identity、reserve receipt或发
  synthetic event/direct reload。

因此 active work在等待期间发生 claim、retry或control version推进，也不会让 replay
错误伪造“当前版本已投影”。freshness由原始 delivery或restart persisted snapshot
分别承担，owner没有重叠。

### 6.3 Process-death gap 与 single-writer boundary

当前 source静态证明：

- AppStore以 `private let stateDirectoryLock` 持有锁至完整lifetime；
- init先创建state root并调用
  `StateDirectoryLock(directoryURL: appSupport)`；
- 成功后才调用production source tree唯一
  `AppDatabase(path: <same-root>/agentloop.sqlite)`；
- lock使用 `flock(LOCK_EX | LOCK_NB)`；
- `EACCES|EAGAIN`第二owner fail-fast；
- deinit执行unlock与close；
- immutable test
  `stateDirectoryLockRejectsSecondFileDescriptionAndReleases`覆盖第二fd拒绝与释放后
  replacement成功。

新进程只有取得锁后才能开DB，并且 target ingestion所属 Camp 的 persisted
snapshot成功load并标记ready后才enable start/retry。由此，“旧进程死亡后commit
存在但process-local event不存在”由新owner snapshot显示 `.recovering`，而不是靠
replay伪造event。当前产品不存在另一个production writer在ready之后跨进程commit的
TOCTOU。

未来 CLI/硬件若要写同一个state root，必须另开stage设计cross-process
coordination/outbox；R12-F没有声称A2已支持multi-writer，也没有修改、缩短或绕过
现有lock。这是明确的future boundary，不是当前A2 P0/P1。

### 6.4 Phase/projection coordinator 与 terminal paths

Review12A/Review12B 的两个独立根因已闭合：

- positive set在sink前登记set-in-flight；invalidator先revoke后等待已登记set，
  再发exactly-once phase invalidation；
- global fatal/control capture sorted identities，revoke permission，await全部
  invalidation，之后才cancel provider/renewal task；
- terminal/retry/user-cancel/halt cleanup与normal inserted start都只从Store
  resulting work构造full projection commit identity；
- phase-less commit也会发布projection refresh；
- live phase commit exact-match时clear+tombstone并在event带`.some(identity)`；
  empty/tombstoned/different-newer时不清registry、typed optional为nil，但仍发
  commit refresh；
- retry `V+1`后cancel/halt `V+2`发两个递增refresh；exact duplicate零第二
  sink/event且不吞更高version；unseen lower与same-version/different-identity在
  sink前fail-fast；
- commit-first暂停projection sink时later phase invalidation等待matching commit；
  phase-first暂停phase sink时later commit等待后仍发一次nil-clear refresh；
  两向最大sink concurrency为1且没有互等owner。

opaque validated turn、exact usage、organizing-before-parse、两轮 owner/durable
revalidation、专用 control signal与 global-fatal invalidation也保留 R12-D/E完整
合同。没有重新引入旧 `try? fail`、mutable usage、第二provider path或unowned
callback。

### 6.5 Halt、startup 与既有 Card lifecycle

rumination相对顺序精确为：

`sorted phase clear → cancel provider/renewal → persist halted → planning cleanup
→ rumination actual commits → projection deliveries → didCommit/haltStateChanged
→ return`。

cleanup失败不为未commit row伪造milestone；queued attempt-zero actual cleanup
commit合法；no-active固定零projection。`haltStateChanged`不兼任rumination refresh。

当前 Orchestrator 已有 Card task cancellation、orphan adoption、MCP stop与process
cleanup。Stage继续要求Orchestrator保有既有Mission/Card收哨职责；A2允许修改
Orchestrator并没有删除这些步骤。required rumination phase/commit milestones可在
现有control sequence中加入，同时让既有Card/MCP cleanup继续位于最终
`haltStateChanged`/return之前；不需要改Card文件、改变Card语义或扩大allowlist。

startup仍是 legacy planning repair → planning adoption → legacy rumination repair
→ rumination adoption → durable mode；running只到recoveryReady，既有Card
adopt/heal后统一activate。halted先planning bulk cleanup，再rumination cleanup。
这些顺序与现有single Supervisor两阶段activation兼容。

### 6.6 App projection、readiness 与 mutation fences

当前App已有一个lifecycle-owned MainActor `kernelEventsTask`和单一
`for await event in stream`；允许文件足以把handler改为async/direct await，而不
新增listener、observer、polling或case内Task。

冻结App规则可以唯一实现：

- phase event先由Adapter在同一次DB read snapshot读取Camp、item与active work；
- 只有item ruminating、work running且workId/attempt exact时overlay live；
- phase invalidation/projection optional identity只做typed exact clear；
- change event无论clear与否都serial reload persisted projection；
- reload后只保留仍匹配snapshot的live identity；
- background Camp只更新其cache，不切selected Camp；
- empty restart registry/tombstone显示`.recovering`，没有`?? .reading`；
- command completion不成为第二refresh owner。

当前 `FeedService.discard`、Adapter ingestion delete与
`AppDatabase.setCampArchived`都有允许范围内的transaction入口，可在同一transaction
加入active rumination fence。target-Camp load/ready状态、显式load failure与按钮
disable也可在 `AppStore`、Adapter、Contracts及Rumination view四个允许文件内实现，
不需要新增文件或App target dependency。

## 7. Completion-gate sufficiency

total Plan与leaf的41 exact tests及subcases共同覆盖：

- atomic start/replay/retry、version1 identity、barrier与两种replay origin；
- crash adoption、legacy 8-cell、resolver与captured runtime；
- provider/usage/parse、lease、retry、terminal proposal；
- phase set/invalidate、projection receipts、two-way race、halt/cancel与global fatal；
- App same-snapshot matching、recovering、background Camp、single listener；
- mutation fences、generic capability seal、global FIFO、startup suppression；
- single-writer lock-before-DB-open、second owner fail-fast与replacement acquisition。

source-range/order gate要求解析真实 enclosing handler/owner/call order，而不是
substring计数；hash manifest、A1b regressions、全量authoritative RunTests、App
build、release Core、双SQLite matrix、privacy/source gates与isolated cold-start
preview全部仍是completion前置。

在“不修改schema/EventKind/target graph、不新增test file/App test dependency”的
范围内，上述证据门足以发现scope drift、owner旁路、顺序错误、stale identity、
synthetic replay、lock drift与UI freshness回归。没有发现必须在实施前增加的新
P0/P1 test name、文件或architecture decision。

## 8. Findings

### P0

无。

### P1

无。

### P2

无。R12-F预检提出的future multi-writer风险已被明确限制为另一stage；当前A2由
既有且可验证的single-writer production contract闭合，没有把风险静默吞掉。

## 9. Commands deliberately not run

遵守 Review12C predecessor gate，本 reviewer没有运行：

- `swift run RunTests`或任何targeted/red Swift测试；
- `swift build`、App build或release build；
- SQLite 3.51/3.52 migration matrix；
- App preview、UI smoke或任何产品进程；
- commit、push、merge、release、数据重置或外部操作。

本次只执行只读文件/源码检查、Git identity/status读取、SHA-256与manifest复算、
R12-A输入流 restoration proof、allowlist/test-name机械对照、Markdown/static
structure检查与 `git diff --check`。

## 10. Gate

**APPROVED — 0 P0 / 0 P1**

Review12C允许在以下入口事实仍成立时开始 A2 failure-first implementation：

1. Stage：
   `cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9`；
2. total Plan：
   `79c9252048697a84c395c5bbdad2bd68495f07fec4a9294c5b6937b02d8e02ab`；
3. A2 leaf：
   `42ddb63dc73cd62514f09956b08378d397d146c2c5eba19c57a3950835bef2e3`；
4. R12-F freeze、blocker、control indexes、13+2 baselines、immutable hashes、
   lock-before-DB-open/source opener count与worktree scope均无漂移。

该授权只打开leaf规定的failure-first implementation gate，不代表A2完成、Review
通过或acceptance。任一red test不是预期能力失败、compile/discovery error、未知
失败、hash/scope/lock drift、A1b regression、matrix/preview失败或implementation
Review P0/P1都必须写A2 `blocked.md`并停止。A2 acceptance前不得进入A3；commit、
push、merge、release、normal-data access与权限扩大仍未授权。
