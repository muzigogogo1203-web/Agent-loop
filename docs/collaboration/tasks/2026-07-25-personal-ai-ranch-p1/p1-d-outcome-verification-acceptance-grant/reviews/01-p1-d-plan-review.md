# P1-D Plan Review — Review01

> Date: 2026-08-25  
> Reviewer: current Codex implementation owner, separate read-only pass  
> Process note: the user explicitly directed Codex to proceed without Claude
> or delegated agents; this is a disclosed self-review and is not represented
> as independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

approved_plan_sha256=3b34e4f699a568d2be5cf345dfa260615d29c5708fd21b29772c723858598acf

## 1. Review scope and authority

I reviewed the exact 597-line Revision 1 plan against the accepted master
spec, canonical P1 stage §5/§8/§10/§12–§13/§18.5/§19–§23, canonical P1 plan
§6/§10/§11, P1-C acceptance, current source ownership, Package target
direction, and the complete dirty-worktree boundary.

The plan is placeholder-free. Its exact test manifest contains 80 unique names
numbered 1–80. Stage §18.5 is 515 SQL lines, 14 tables, 14 explicit indexes,
8 triggers, and SHA-256
`0fa300dd5c90e12a90b7cf3f9f0eb84af07f4d9bbc36f869123bdda236214cbb`.
Adding its 40 explicit/automatic indexes to the accepted v14 checkpoint gives
the planned 55-table / 134-index / 16-trigger v15 checkpoint.

## 2. Entry and scope evidence

The NUL-safe serializer was independently rerun with the plan's exact existing,
new, derived-carrier, and task-artifact allowlist:

```text
dirty_total=503
allowlisted_present_count=12
outside_count=491
outside_manifest_v1=53b8f84867ab0445da2a772bbf20f7fb9c4bedc397100337a4854e266fbf12ab
```

All 14 new product/test paths are absent. `git diff --check` passes. Protected
Stage/P1 plan/master/P1-C/Package/RunTests/P1-C domain hashes match the plan.

Existing allowlist pre-images:

| File | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `3a393821dc86d8ac9bdf89cff48453ed1866919c7dfcdf443e597a96737b878b` |
| `Sources/AgentLoopCore/Database/Records.swift` | `b64a642db225533cd1d67a3441fd334312e10855f2e4190028dee4713c498671` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `594062914ee9b90df9672a633f9ddff6384607290c82d48464cdc2f3dde2019c` |
| `Sources/AgentLoopCore/Tools/ApprovalGate.swift` | `ef004ab0e97b72a536a161fb0041f7bbfa02d380dd9e884df76f4c1e8b9fd57b` |
| `Sources/AgentLoopCore/Tools/ApprovalPolicy.swift` | `9a14735b72352a7cf64abe7024afde941fadcdf1b07b33af5dff536edd182ca2` |
| `Sources/AgentLoopCore/Tools/ToolExecutor.swift` | `fdfc8e53fca920f5654f2e80a8a710728a21cd77dde45bdd670b9c30f55d78d1` |
| `Sources/AgentLoopCore/Tools/BoardTools.swift` | `3089a71a1d19435e723ceefe1e1eeeb5fa9897b7ca8f5bb5624c175a3e576cdf` |
| `Sources/AgentLoopCore/Tools/FileTools.swift` | `102f11b72c0c4c003834a162a2a3d76c18fd49de7a222ed49e63bd5ba8821e34` |
| `Sources/AgentLoopCore/Tools/ShellTool.swift` | `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf` |
| `Sources/AgentLoopCore/Tools/WebFetchTool.swift` | `97f172ea7bca0fb470d7953fef004ed1e6f4f881c16c630a1decc6b2c6d8ccc3` |
| `Sources/AgentLoopCore/Mcp/McpToolBridge.swift` | `32b81a39cbf259f3d5b3c07b7ab853c5f919b9d1b3fda996ea6dea8ad8e19b7d` |
| `Sources/AgentLoopCore/Database/DomainEventStore.swift` | `e41f3f9b0a06d7bdba5d8afb7cd9e0308ae46298dd58aa48ee27f688f9f26db5` |
| `Sources/AgentLoopCore/Domain/GoalController.swift` | `f2580c7393d9a9c1eef8455964ed0b3b3772ab438cd5c2d55471a68f53f7cfd8` |
| `Sources/AgentLoopCore/Loop/CardRunner.swift` | `d350e83f263248117fb70e49171fa1bbc2b473d0c034378e978b0c17ae3be020` |
| `Sources/AgentLoopCore/Loop/BoardToolServer.swift` | `fc778c9dd50b3a4ea8a60315503ef5542dd709c68aa3c222ebabc07a6d00f2db` |
| `Sources/AgentLoopCore/Loop/CliProcessBackend.swift` | `665113119e2e107ece677c52fce60262fdea821438e391ded0fa9ad846739ce1` |
| `Sources/AgentLoopApp/AppStore.swift` | `96eab76cf727c81d2bcfbfae6c9eb5aa352c5c1f7452ccac370659e80b8f983a` |
| `Sources/AgentLoopApp/CodingRanchContracts.swift` | `93e925354509f897722d0b7572ff6baa3be9c65f2c45245f1e6f17348dc0f9e0` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `c3fcbc5479920968c10aa7f40827aac67e4d8676f72b09f64ba286436c616b23` |
| `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift` | `db9c34abbcbbcb013824d1ee884b103ec46e2325eacb242158124d159d3409d9` |
| `Sources/AgentLoopTestSuite/OrchestratorTests.swift` | `c4fd495567e97abcf5d4a92445cbf3194047168388d30dcf2a4facbaa418ba56` |
| `Sources/AgentLoopTestSuite/ApprovalGateTests.swift` | `615148fce8f0e065af1eb4965b7c400321006a38261e8481fb43e7f43aaff974` |
| `Sources/AgentLoopTestSuite/ApprovalPolicyTests.swift` | `479805713e6a2f73172965bd929152d4dc545b7e37178a104f1f454269fb2866` |
| `Sources/AgentLoopTestSuite/BoardToolsTests.swift` | `a191a5c9b2706b699ee2410be1470aeaf3182d01acb7682a5ecab2f234aeac42` |
| `Sources/AgentLoopTestSuite/ToolExecutorTests.swift` | `106f88eb95a46134514d2d0a56a4c583860fd4cc30aea8e76f411798e84b073c` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `ef010fb358e0ecd84ffd1a4941c761341e6732edf2c5ab8d52cad049019bf4b9` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `2b4be14c268560aaf254a3026c70b27c208f30f6e1a1c99048382ec898dde97f` |

## 3. Architecture review

The plan has one owner for each mutable truth:

- OutcomeStore owns Contract/Goal link/Outcome/Verification/Acceptance/metric
  transitions and a P1-D DomainEventStore transaction graph;
- ApprovalGrantStore owns all Grant/use/receipt writes and refunds;
- DeliveryCoordinator is fixed to `system:delivery:v1` and Store revalidation;
- AcceptanceWorkflowController commits but never navigates;
- AppStore updates after a committed return, and LiveHosts navigates after that;
- ExternalOperationWorkflowCoordinator is the only async adapter owner and is
  injected through an explicit Core port into both model/CLI paths.

The three extra Loop carriers are necessary to avoid a global singleton,
Application→Core dependency inversion violation, DB service locator, or direct
adapter fallback. Their propagation-only limit and source gate make the scope
bounded. The matrix carriers are required by canonical §10. The
GoalController marker extension preserves accepted P1-C bytes.

The plan closes all identified silent-failure paths: approval hash cannot fall
back to empty bytes, malformed decisions cannot disappear through `try?` or
`compactMap`, absent external ports/registries fail closed, and all Application
reads are revalidated under Store transaction/CAS.

## 4. State, security, and recovery review

- Outcome transitions exactly reproduce §12.2, including five new-version
  sources and accepted-only invalidation to invalidated.
- Reducer semantics require every group and one deterministic Coding pass;
  producer/verifier independence and stale hash/version evidence fail closed.
- Acceptance hard guards derive immutable/history facts before policy lookup;
  policy schema has no override escape.
- Return/revoke/invalidation/new version reverse the single metric and reopen
  Goal/Mission without optional future-table hooks.
- Grants bind Camp/Card/tool/input/capability/time/actor and conservative live
  nonReplayable tools to a single-use user decision.
- Dispatch intent precedes external call; adapter acceptance follows the
  return; only typed adapter no-effect can refund; user resolution consumes.
- Startup recovery precedes dispatch. NonReplayable ambiguity stops; safe
  classes require exact registry/key/operation authority.
- Receipt JSON persists hashes/refs only, and DEBUG UI seams are release-zero.

P1-E/F1 types and migrations are expressly absent. No open product decision,
unbounded review, external authority, or destructive operation is hidden in
the plan.

## 5. Findings and decision

- P0: 0
- P1: 0

The P1-D implementation gate is open for D1 tests only. D2–D4 product writes
remain gated by their own preserved red frames and preceding batch green.

verdict=APPROVED — 0 P0 / 0 P1
