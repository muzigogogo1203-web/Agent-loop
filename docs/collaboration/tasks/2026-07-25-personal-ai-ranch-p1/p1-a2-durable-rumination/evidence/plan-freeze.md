# R12 / R12-A Plan Freeze Evidence

> 状态：Candidate Frozen；Review12 Pending；A2 Product/Test Code Frozen
>
> 日期：2026-07-27
>
> Owner：R12 planner

本证据只冻结 A2 planning candidate 与 R12-A control delta，不是独立 Review、
implementation、test/build/matrix 结果或 acceptance。

## 1. Repository identity

| Field | Value |
|---|---|
| branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| inherited worktree | fully-expanded dirty A1a/A1b accepted baseline；未清理/覆盖用户改动 |
| A1b implementation Review | `APPROVED — 0 P0 / 0 P1`；`8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` |
| A1b acceptance | `ACCEPTED`，22/22 PASS；`efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |

## 2. Canonical R12 candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `14a6f003e9aa59e2a00e04a878e9fa9bfda8a666ef26a4093dbca1c0f4d35637` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `01c19e54b06b91d716b98bfbada21984a735807c1673b7815e03b5fd3535416d` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `55140ca98a37b34d004ce4704cfaf427ce6b87f0f9f04062257453b398387206` |
| P1 Stage control index | `8d2aeb304ec08e107b3c360deeb48c66cb1e552086d0509534b5cdea1cbac580` |
| P1 Plan control index | `5f9a9f2f3656fc2f021c10ad43d0d82b2afb93a4c945fd701c0cc4033934cf05` |
| A2 `blocked.md` | `44949d4bcb3c0761a4d8267a36e9d2c17133b26be120cbfcb2ee6ace07eacafc` |

Canonical Stage §29、总 Plan §19 与 A2 leaf §13 的 Open Questions 均精确为
`无。`。本 evidence 之后若 control index 或 blocker 仅为修正本 manifest 中的
自指 hash 而改变，必须重新冻结；当前没有这种授权。

## 3. R12-A exact control delta

| Check | Result |
|---|---|
| script path | `scripts/verify-p1-migrations-sqlite-matrix.sh` |
| old baseline SHA-256 | `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5` |
| final candidate SHA-256 | `9c44660a341f3c56d9156c98947fcad4ccd0d9635834bc2eb8e3ac476bc8afaf` |
| only authorized value | line 115 `expected_stage_hash="14a6f003e9aa59e2a00e04a878e9fa9bfda8a666ef26a4093dbca1c0f4d35637"` |
| restoration proof | replacing that 64-hex with old Stage `add94117...66a2` yields exact old script SHA `b51129...5be5` |
| runner | byte-identical `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |

因此 R12-A 没有改变 fixture、literal、linked lanes、assertions、commands 或任何
其他 script bytes。Review12 必须自行复算；本 proof 不替代 reviewer judgement。

## 4. Zero A2 product/test drift at freeze

以下 hashes 与 R12 只读入口逐字一致，证明 planner 未实施 A2：

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

## 5. Immutable manifests

| Immutable boundary | SHA-256 / assertion |
|---|---|
| `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `Sources/AgentLoopCore/Rumination/RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator block | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

没有新增/修改 schema、migration、DDL、trigger、EventKind、Package/target graph、
RunTests、strict resolver、RuminationResult/Materializer 或 matrix runner。

## 6. Candidate scope and next gate

R12/R12-A 实际写入范围只有：

- canonical Stage、总 Plan；
- A2 leaf、A2 blocker status、本 freeze evidence；
- 两个 P1 execution control indexes；
- matrix script 的单个 Stage hash value。

未运行 product test/build/matrix/preview，因为 Review12 是其 named predecessor；
也未写 `reviews/12-p1-plan-review.md`。下一动作只能由未参与 R12 修订的 reviewer
复算本 manifest、逐项审查 B1–B5/R12-A 与 exact contracts。其 verdict 为
`APPROVED — 0 P0 / 0 P1` 前，A2 product/test code、implementation evidence、
implementation Review/acceptance 与 A3 继续禁止。
