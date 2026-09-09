# Review12A — R12-C P1-A2 Plan Review

> Reviewer：职责隔离 independent reviewer（未参与 R12/R12-A/R12-B/R12-C 修订）
>
> 日期：2026-07-27
>
> Review 类型：严格只读、evidence-driven plan review
>
> 结论：**CHANGES REQUIRED**
>
> Findings：**0 P0 / 1 P1 / 0 P2**

## 1. Verdict

R12-C candidate 的 hashes、R12-A 单值 script delta、13+2 allowlist、41 exact
test names、immutable manifests、legacy 8-cell、opaque provider/parse handshake
和后续 Review/acceptance/A3 gates 均已独立复算或审计。

但 R12-C 新增的第二轮 phase-loss completion contract 仍缺一个必要 owner/API：
`organizing` 已发出后，global fatal、DB read failure 或 graph invariant
corruption 按合同不得做业务写；持久 work 因而仍可保持同一个 active
`workId/attempt`。冻结的 persisted matching fence 会继续接受已经发出的 phase，
而唯一新增 sink 只能发送正向 `reading|extracting|organizing`，没有 fatal/control
invalidation carrier。当前 candidate 因此无法同时满足 Stage §6.4.9、test #27/#35
与“除 phase sink 外不得新增 callback”三项约束。

所以：

- Review12A 不打开 A2 implementation gate；
- A2 产品代码、测试、red tests、implementation evidence、implementation Review、
  acceptance 与 A3 继续冻结；
- planner 必须先对本报告 P1 做新的有界根因修订、重新冻结并接受职责隔离复审。

## 2. Repository identity and review boundary

只读入口实测：

| Field | Evidence |
|---|---|
| cwd | `/Users/muzi/Agent-loop` |
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| worktree | fully-expanded dirty A1a/A1b accepted baseline；包含既有 tracked modifications 与 untracked A1a/A1b/P1 artifacts |
| report preflight | `reviews/12a-p1-plan-review.md` 不存在 |
| `git diff --check` | PASS，零输出 |

本 Review 没有运行 `swift run RunTests`、build、migration matrix、preview 或任何
产品 implementation gate；这些动作在 Review12A 前被明确禁止。本 Review 也没有
修改产品、测试、Stage、Plan、leaf、freeze、control index、blocker、script、
implementation evidence、acceptance 或其他文件。唯一写入是本报告。

## 3. Governing inputs read

已完整阅读或按任务要求审计：

- repository `AGENTS.md`；
- `docs/collaboration/claude-codex-protocol.md`；
- master spec 的 P1/A2、failure/recovery、evidence、Goal protocol 与阶段门；
- canonical Stage §6.4、§18.1、§20–§22、§28–§29；
- canonical total Plan §3.3、§10–§13、§18–§19，并审计完整 P1 sequence/gates；
- A2 leaf 全文；
- A2 `blocked.md`、P1 Stage/Plan control indexes；
- immutable Review12、R12/R12-A freeze、R12-B freeze 与 R12-C freeze；
- 当前 13+2 future files、immutable files、AppDatabase migrator block、Stage
  §18.1 literal；
- 当前 Supervisor、Orchestrator、Rumination service/parser、strict resolver、
  ingestion/App/UI 与测试 source-fixture 拓扑。

## 4. Candidate and predecessor hashes

以下均由 reviewer 直接执行 `shasum -a 256` 复算：

| Artifact | SHA-256 | Result |
|---|---|---|
| canonical Stage | `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` | exact |
| canonical total Plan | `3dfaf7806a0f1be5c7592a25ce98dfb4c866cd9120ed38a17c3eb751db7eee6b` | exact |
| A2 leaf Plan | `db0085b9fdb63266a4bdf6f3bb77ba2d4c307bce01b74b268a37c6b52aa7bd07` | exact |
| P1 Stage control index | `870eec359be86a710c51e6fd25476601df2f3abaa7ee412de7f5fc17fa2554b2` | exact |
| P1 Plan control index | `824a19d13154d0e0c2ec29a9118669d884ea372a2465f40318d1bdf64f900f4d` | exact |
| A2 `blocked.md` | `1268c8071aba6f5cc3286b91f7cfc1315cebafc8c64dd019d6aa5c973abf0a28` | exact |
| R12-C freeze | `ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` | exact |
| matrix script | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` | exact |
| immutable Review12 | `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` | exact |
| immutable R12/R12-A freeze | `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` | exact |
| immutable R12-B freeze | `85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` | exact |

入口历史也保持一致：

| Artifact | SHA-256 |
|---|---|
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` |
| A1b leaf | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` |
| A1b implementation Review | `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` |
| A1b acceptance | `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| R11 freeze | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` |
| Review11 | `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` |

## 5. R12-A script restoration proof

Reviewer 直接核对：

- line 115 精确为
  `expected_stage_hash="2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b"`；
- current script SHA-256 为
  `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0`；
- 只在内存流中把该行 value 恢复成旧 Stage
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
  后，整份流的 SHA-256 精确恢复为
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`。

使用的只读证明命令等价于：

```bash
perl -pe 'if ($. == 115) {
  s/2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b/add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2/
}' scripts/verify-p1-migrations-sqlite-matrix.sh | shasum -a 256
```

因此 R12-A 仍是单个 64-hex value delta；runner、fixture、literal、linked lanes、
assertions、commands 与其他 script bytes 未发现漂移。

## 6. Future-file and immutable manifests

### 6.1 13 product + 2 test future files

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

R12-C freeze 所列 15 个 hashes 全部 exact。Stage/total Plan 与 leaf 的 product
allowlist 均为 13/13 unique、同路径同顺序；test allowlist 均为 2/2 unique、同路径
同顺序。

### 6.2 Immutable files and boundaries

| Boundary | SHA-256 / result |
|---|---|
| `PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| migration matrix runner | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator lines 21–612 | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 SQL body lines 3277–3463 | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

未发现 schema、migration、DDL、trigger、EventKind、Package/target/dependency、
RunTests、strict resolver、RuminationResult/Materializer 或 runner drift。

## 7. Exact-name, Open Questions, and gate audit

Reviewer 用 heading-bounded parser 从 total Plan 与 leaf 各抽取 numbered list：

- 两份均为 41 names；
- 两份均为 41 unique；
- 每个 name 在其所在文档反引号 token 中 exact-once；
- 两份逐项同顺序；
- #27、#31、#35、#39 仍是既有 exact names，没有 alias、新 test name 或新 test file。

Open Questions：

| Document | Exact final value |
|---|---|
| Stage §29 | `无。` |
| total Plan §19 | `无。` |
| A2 leaf §13 | `无。` |

Review/acceptance/sequence gate 保持关闭且无歧义：

1. Review12A 零 P0/P1 才能打开 A2 implementation；
2. implementer 只能写 13+2 产品/测试文件与列明 task evidence；
3. 完整 `swift run RunTests`、App build、release Core、双 SQLite matrix、
   A1b source/release/DEBUG regressions、privacy/source/hash gates和 isolated preview
   后，才可进入独立 implementation Review；
4. implementation Review 零 P0/P1 后才可交给独立 acceptance；
5. A2 acceptance 前不得进入 A3；
6. commit、push、merge、release、normal-data access 与权限扩大仍禁止。

## 8. Findings

### P1-1 — 第二轮 fatal/control loss 后的 live phase 没有 invalidation owner/API

#### Contract contradiction

Stage §6.4.9 当前同时要求：

1. `organizing` 通过唯一 awaited phase sink 在线性化点发出，然后才做第二轮完整
   actor + durable ownership revalidation（Stage lines 1280–1295）。
2. 第二轮 `fatal` expected-loss 以及 validator 的 DB read failure / invariant
   corruption 都必须 zero parse；后两类还必须 latch global fatal，并且全部不得写
   attempt failure、retry、proposal、domain event 或 business write
   （Stage lines 1312–1329；leaf lines 354–372）。
3. 即使 organizing 已发，所有这些格仍必须由 persisted matching
   `workId/attempt` fence 与 `ruminationChanged`/control changed 清除，不留下 visible
   stale phase（Stage lines 1320–1329）。
4. 唯一新增 callback 被钉死为
   `onRuminationPhase(RuminationPhaseEmission) async`；emission 只能携带正向
   `reading|extracting|organizing`。除该 phase-only sink 外不得新增 callback
   （Stage lines 1264–1279；total Plan lines 1443–1449）。
5. 明确要求清 App live phase 的 owner list 只有 terminal/retry/cancel/halt
   （Stage lines 1340–1341），不含 global fatal、DB read failure 或 invariant
   corruption。

这五项不能同时成立。第二轮 fatal/DB/invariant 失败按合同零业务写，所以 durable
work 可以继续是原 active row，`workId/attempt` 不变；persisted matching fence
因此不会拒绝已经收到的 organizing event。与此同时，global fatal 不是一个
cancel/halt/terminal commit，没有必然的 `ruminationChanged` producer。

#### Current-source feasibility evidence

当前源码与上述缺口一致，而不是已经存在可复用的 owner：

- `DurableWorkSupervisor` 当前只持有同步
  `onMissionChanged: @Sendable (String) -> Void`；没有 typed rumination changed/fatal
  invalidation sink（Supervisor lines 126–163）。
- `latchFatal` 只设置 fatal/suppression、取消 pump/owned tasks、记安全日志并唤醒
  waiters；它不通知 Orchestrator/App，也不改变 durable work
  （Supervisor lines 1764–1779）。
- `KernelEvent` 的 emitter 由 Orchestrator actor 持有；当前唯一 Supervisor callback
  被接到 `planningMissionChanged`，并通过 `Task` 发送 mission event，不是可复用的
  awaited rumination invalidation channel（Orchestrator lines 276–289）。
- App 的冻结规则只按 persisted active `workId/attempt` 接受或拒绝 live phase；
  global fatal 本身不改变这两个字段。

因此 implementer 若照现有 candidate 实施，只能四选一，而四项都违反冻结合同：

- 留下 stale `organizing`，让 #27/#35 与 UI truth gate 失败；
- 增加未冻结 callback/event/clear API，违反唯一 callback 与 no-unplanned-decision；
- 为 fatal 写 terminal/control业务状态，违反 zero business write/global-fatal
  语义；
- 用 timeout、隐式 task completion、刷新巧合或弱化测试清 UI，属于 paper-over，
  不能证明线性化和 exact owner。

#### Required bounded closure

planner 必须在下一轮有界修订中冻结一个可执行的、typed、ordered live-phase
invalidation owner/API，使第二轮 expected control loss 与 DB/invariant global fatal
在不伪造业务终态的前提下，必然清除已线性化 phase。修订必须同步 Stage、total
Plan、leaf、#27/#35 exact assertions、source-range/order gate、source-compatible
initializer规则与 freeze hashes；或者明确收窄第二轮 matrix，但不能保留当前
“必须清除”与“没有 producer”并存的合同。

Reviewer 不替 planner 选择具体 API/架构。新 candidate 仍需职责隔离复审。

## 9. Other audited areas

除 P1-1 外，本轮没有发现其他 P0/P1/P2：

- Review12 P1-1 已由 opaque `RuminationValidatedTurn`、
  `produceValidatedTurn`/`parseValidatedTurn`、Supervisor-owned awaited
  organizing-before-parse handshake 与两次 revalidation 在 plan level关闭；
- Review12 P1-2 已由完整 running|halted × valid|三类 invalid 8-cell 表关闭；
  halted 对四种 snapshot 均优先生成 emergency-halt canceled、零 external/domain/
  attempt event；
- B1 recovering UI、B2 single Supervisor/global FIFO、B3 captured identity/strict
  resolver、B4 generic seal/terminal proposal、B5 complete verification evidence
  均有 owner、allowlist 与 named gates；
- #31 仍锁 one streamTurn、exact-one-turn、tools empty、opaque-before-parse、
  one parse 与 exact usage；
- source-compatible defaults 被限制在既有 non-rumination tests；production AppStore
  snapshot与 Orchestrator phase sink均要求显式传入，并有 source sentinel，未发现
  current-default或 no-op production bypass；
- 13+2 allowlist 可以承载 start/legacy/store/supervisor/App/UI/mutation-fence工作；
  没有发现需要 schema、EventKind、Package、runner、RunTests 或额外 test file；
- full verification、A1b regressions、matrix、privacy、isolated preview、
  implementation Review、acceptance 与 A3 gate均完整保留。

这些 clean 项不抵消 P1-1，也不构成 implementation 授权。

## 10. Final gate state

**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**

R12-C exact candidate 不能打开 A2 implementation gate。A2 产品/测试、red tests、
implementation evidence、implementation Review/acceptance 与 A3 继续禁止，直到：

1. P1-1 获有界根因修订；
2. Stage/total Plan/A2 leaf/control evidence 重新冻结；
3. 未参与修订的职责隔离 reviewer 在新 exact hashes 上给出
   `APPROVED — 0 P0 / 0 P1`。
