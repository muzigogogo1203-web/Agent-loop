# R12-C Plan Freeze Evidence

> 状态：R12-C Candidate Frozen；Review12A Pending；A2 Product/Test Code Frozen
>
> 日期：2026-07-27
>
> Owner：R12-C planner

本证据只冻结获授权的 phase completion/source-gate P1 closure 与既有 R12-A
control delta，不是职责隔离 Review、implementation、test/build/matrix 结果或
acceptance。

## 1. Repository identity and immutable history

| Field | Value |
|---|---|
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| inherited worktree | fully-expanded dirty A1a/A1b accepted baseline；未清理/覆盖用户改动 |
| A1b implementation Review | `APPROVED — 0 P0 / 0 P1`；`8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` |
| A1b acceptance | `ACCEPTED`，22/22 PASS；`efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| immutable Review12 report | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12-p1-plan-review.md`；`CHANGES REQUIRED — 0 P0 / 2 P1`；`f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| immutable R12/R12-A freeze | `evidence/plan-freeze.md`；`652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| immutable R12-B freeze | `evidence/plan-freeze-r12b.md`；`85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |

旧 Review12、旧 freeze 与 R12-B freeze 均已复算并保持 byte-identical；R12-C
没有改写 predecessor verdict 或 manifest。

## 2. R12-B predecessor snapshot

| R12-B artifact | SHA-256 |
|---|---|
| canonical Stage | `886f4f9dbf57eedcf832318b2a1818833a21b28f9cd04494bcfb9a8a549680f8` |
| canonical total Plan | `e637e3ada4c7262df00d83076a1af684394c326a2016ba5c98af27277caba729` |
| A2 leaf Plan | `3bf1459d46bc262f7138f3097ffc59013c8bab25ac3bb64f6bf7360be78ca262` |
| A2 `blocked.md` | `e288469e6eb6c03f7dccc6f8d922d76222a398469b0f427d51c14a6ceb56aff1` |
| P1 Stage control index | `4bbc650f4e6ba38c4f1043386959d52a48ead08a6fe1ceb6afd280a2d9708709` |
| P1 Plan control index | `f41f9d87f1dcfcb71355263dc2c7825156426eef1cb4971e194c0da636f8346e` |
| matrix script | `34a25e6b586daa0674b18674e3c474707fabf811754654affaeba140b43d8f40` |
| R12-B freeze evidence | `85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |

R12-B phase pre-audit 没有创建报告文件；其冻结结论是
`0 P0 / 1 P1 / 0 P2`，legacy/mechanical audit clean。

## 3. Canonical R12-C candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `3dfaf7806a0f1be5c7592a25ce98dfb4c866cd9120ed38a17c3eb751db7eee6b` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `db0085b9fdb63266a4bdf6f3bb77ba2d4c307bce01b74b268a37c6b52aa7bd07` |
| P1 Stage control index | `870eec359be86a710c51e6fd25476601df2f3abaa7ee412de7f5fc17fa2554b2` |
| P1 Plan control index | `824a19d13154d0e0c2ec29a9118669d884ea372a2465f40318d1bdf64f900f4d` |
| A2 `blocked.md` | `1268c8071aba6f5cc3286b91f7cfc1315cebafc8c64dd019d6aa5c973abf0a28` |

Canonical Stage §29、总 Plan §19 与 A2 leaf §13 的 Open Questions 均精确为
`无。`。本 evidence 不把自身 hash 写回 control index，因此没有自指 hash 环。

## 4. Phase pre-audit finding closure

R12-C 没有改变 Stage §6.4.9 的架构/API，只把已冻结出口变成不可绕过的完成门：

- 现有 test #27 在 first/second revalidation 分别穷尽 20 类 expected loss：
  lifecycle、suppression、fatal、generation、token、workId、ingestion、attempt、
  providerExited、pending proposal、current latestClaim、durable mode、work、kind、
  aggregate、Camp、item、version、lease owner、expiry；
- 每格必须抛 exact `RuminationPreParseAuthorizationLostError`，由 owned provider
  task 专门 catch，且 zero parse、zero `RuminationAttemptFailure`、zero
  retry/failure/pending-or-terminal proposal/domain event/business write；first
  zero phase，second 已发 phase由 control changed/persisted matching fence清除；
- 现有 test #35 在两轮 validator 分别注入 DB read failure 与 invariant corruption，
  四格都只 latch global fatal、zero parse，不进入 provider failure/
  `RuminationAttemptFailure`/retry/proposal；second 已发 phase同样清/fence；
- fail-fast source-range/order gate解析真实 handler、owned-task catch、validator与
  global-fatal owner enclosing ranges，锁两轮 actor/current latestClaim/durable
  graph 同序、control专门catch不落 failure mapper、DB/invariant只进global fatal；
  substring/count-only、复制helper或未锁 owner/call order均失败。

#31 保持逐字不变；总 Plan 与 leaf 的 41 names 各 41 unique且逐字同序，13 个
product + 2 个 test allowlist 路径/顺序逐字相同。没有新增 test name/file、API、
架构或权限。

## 5. R12-A exact control delta

| Check | Result |
|---|---|
| script path | `scripts/verify-p1-migrations-sqlite-matrix.sh` |
| old baseline SHA-256 | `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| final R12-C candidate SHA-256 | `a34fbd70e78ab6f52e00542b8822d8c7203a240996e2e462109e496421c69be0` |
| only authorized value | line 115 `expected_stage_hash="2d427a66e10184a78b922d5993efe8850c8fd0972045d18c9d69d3a566019c6b"` |
| restoration proof | replacing that 64-hex with original Stage `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` yields exact old script SHA `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| runner | byte-identical `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |

因此 script 的 fixture、literal、linked lanes、assertions、commands 与全部其他
bytes 均未改变。Review12A 必须自行复算；本 proof 不替代 reviewer judgement。

## 6. Zero A2 product/test drift at freeze

以下 hashes 与 R12-B freeze 逐字一致，证明 planner 未实施 A2：

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

## 7. Immutable manifests

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
| Stage §18.1 literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

没有新增/修改 schema、migration、DDL、trigger、EventKind、Package/target graph、
RunTests、strict resolver、RuminationResult/Materializer 或 matrix runner。

## 8. Candidate scope and next gate

R12-C 实际写入范围只有：

- canonical Stage、总 Plan；
- A2 leaf、A2 blocker status、本 R12-C freeze evidence；
- 两个 P1 execution control indexes；
- matrix script line 115 的单个 Stage hash value。

没有创建 `reviews/12a-p1-plan-review.md`，也未运行 product test/build/matrix/
preview。下一动作只能由未参与 R12-C 修订的 reviewer 复算本 manifest，并对
phase completion/source-gate closure与继承的 R12-B/R12-A 合同执行职责隔离
Review12A。其 verdict 为 `APPROVED — 0 P0 / 0 P1` 前，A2 product/test code、
red tests、implementation evidence、implementation Review/acceptance 与 A3
继续禁止。
