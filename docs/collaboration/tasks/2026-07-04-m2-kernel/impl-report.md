# M2 Kernel Implementation Report

## Changed Files

- `Sources/AgentLoopCore/Kernel/KernelDefaults.swift`
- `Sources/AgentLoopCore/Kernel/Planner.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/BoardCardTransactions.swift`
- `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Provider/LLMProvider.swift`
- `Sources/AgentLoopCore/Provider/AnthropicProvider.swift`
- `Sources/AgentLoopCore/Provider/MockProvider.swift`
- `Sources/AgentLoopCore/Chat/ChatService.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/Components/CardRowView.swift`
- `Sources/AgentLoopTestSuite/MissionRollupTests.swift`
- `Sources/AgentLoopTestSuite/PlannerTests.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/ColdStartTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/AnthropicProviderTests.swift`
- `Sources/AgentLoopTestSuite/MockProviderTests.swift`
- `docs/superpowers/2026-07-04-m2-live-smoke.md`

## Verification

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
- Full output: `docs/collaboration/tasks/2026-07-04-m2-kernel/verify.log`
- Result: 104 tests discovered; 103 passed; 1 failed.
- Failure: `keychainRoundTrip` failed with `KeychainError(status: -50)`, the known sandbox environmental failure from the task instructions.

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`
- Result: passed. Output appended to `verify.log`.

## Notes / Deviations

- `AppDatabase.migrator` is exposed as `public static var` instead of `internal` because `AgentLoopTestSuite` is a regular library target importing `AgentLoopCore`, not an `@testable` test target. This keeps the required v1-only migration test executable without changing package layout.
- Orchestrator tick startup is lazy on first actor API call instead of installed directly in `init`; Swift 6 actor initialization disallows assigning a self-capturing `Task` during the initializer. `tickInterval: nil` test behavior is unchanged.

## Fix Round 1 — Claude Review 01

### Fixes Applied

- P1-1: Added `Orchestrator.cancelling` guard. `cancelMission` marks the mission as cancelling before awaiting runner shutdown, and `reconcile` skips dispatching a candidate whose mission is cancelling. Added `cancelMissionDoesNotDispatchReadyCardDuringRunnerShutdown`.
- P2-1: Added `reconcilePending` coalescing. Concurrent reconcile calls now set a pending bit while one reconcile is active, and the active reconcile drains pending work before exiting.
- P2-2: Changed `AppDatabase.companions(ids:)` to throw `RecordNotFoundError` on missing ids. Reconcile now blocks ready cards whose assignee cannot be resolved with `other / 负责伙伴不存在或未指派` and emits `kernelError`. Added `companionsMissingIdThrows` and `missingAssigneeBlocksReadyCard`.
- P2-3: Changed `cancelMission` card terminalization to use db-level `transitionCard(... .canceled, eventKind: "card_canceled", ...)`, preserving the state-machine corridor and event write path.
- P3-2: Added an equal-value guard before updating `AppStore.cardLatest` during streaming.

### Additional Note

- To implement P2-2's requested ready-card block behavior through the existing db-level `blockCard` path, `CardStatus.canTransition` now permits `ready -> blocked` for kernel-detected dispatch faults.
- P3-1 was skipped because the generic reconcile catch path does not always have a reliable mission id without restructuring the transaction error flow; the new missing-assignee path does emit a mission-scoped `kernelError`.

### Verification

- Appended rerun: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
- Result: 107 tests discovered; 106 passed; 1 failed.
- Failure: `keychainRoundTrip` failed with `KeychainError(status: -50)`, the known sandbox environmental failure.
- Appended rerun: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`
- Result: passed.
