# M3 Implementation Report

## Changed files

- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Kernel/KernelDefaults.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- `Sources/AgentLoopCore/Tools/ToolDef.swift`
- `Sources/AgentLoopCore/Tools/BoardTools.swift`
- `Sources/AgentLoopCore/Feed/ActivityFeed.swift`
- `Sources/AgentLoopCore/Presentation/CompanionAnimState.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/Components/CardRowView.swift`
- `Sources/AgentLoopApp/Views/Components/CompanionAvatarView.swift`
- `Sources/AgentLoopApp/Views/Components/AskUserPromptView.swift`
- `Sources/AgentLoopApp/Views/Components/FeedView.swift`
- `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`
- `Sources/AgentLoopApp/Views/Components/CampfireTheaterView.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/AskUserTests.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`
- `Sources/AgentLoopTestSuite/FeedTests.swift`
- `Sources/AgentLoopTestSuite/AnimStateTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/ToolExecutorTests.swift`
- `docs/superpowers/2026-07-05-m3-live-test.md`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/verify.log`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/impl-report.md`

## Test results

- Ran `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`; full output saved to `verify.log`.
- Initial M3 result: 133 tests ran. 132 passed; `keychainRoundTrip` failed with `KeychainError(status: -50)`, matching the known environmental sandbox failure in the task instructions.
- Ran `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`; output appended to `verify.log`.
- Result: build passed.

## Fix round for `reviews/01-claude-review.md`

### Additional changed files

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Feed/ActivityFeed.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/Components/FeedView.swift`
- `Sources/AgentLoopApp/Views/Components/CampfireTheaterView.swift`
- `Sources/AgentLoopApp/Views/Components/CompanionAvatarView.swift`
- `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`
- `Sources/AgentLoopTestSuite/AskUserTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/FeedTests.swift`
- `docs/superpowers/2026-07-05-m3-live-test.md`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/verify.log`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/impl-report.md`

### Fix summary

- Restored and implemented the theater acceptance items: planning guide + unfolding map, fire sparks 3-dot cycle, unified reduce-motion/inactive-window pause, and static reduce-motion map/no-pulse live-test checks.
- Added deadline-based idle timeout, slow-active-stream coverage, and cancellation-priority coverage.
- Removed the in-mission finished-state "新行动" reset trap.
- Fixed app event reload ordering and removed mission-list reloads from card stream events.
- Added duplicate-card-safe feed mapping and blocked-card-gated pending request visibility with coverage.
- Added card titles to pending feed prompts, interaction-resetting theater pulse, cached card inspector DB reads, answer reconcile-on-read-failure, feedNotice clearing, stale candidate debug logging/commentary, and deterministic open-run cancellation marking.
- Re-anchored ask_user/golden choice assertions on unique option text that is not present in prompts.
- Added `cancelDuringArmedTimeoutLeavesCardReady` to anchor cancellation-vs-idle-timeout precedence through CardRunner DB side effects.

### Fix-round verification

- Appended three fix-round `RunTests` runs to `verify.log`.
- First fix-round run exposed the new `cancelWinsOverIdleTimeout` test expectation needed to account for `AsyncThrowingStream` consumer-cancellation semantics; the test was corrected to call `Task.checkCancellation()` after iteration.
- Final `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`: 138 tests ran. 137 passed; only `keychainRoundTrip` failed with `KeychainError(status: -50)`, the known environmental sandbox failure.
- Final `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`: passed; output appended to `verify.log`.

## Notes and deviations

- No intentional product, architecture, schema, or dependency decisions beyond the plan.
- `cancelMissionDoesNotDispatchReadyCardDuringRunnerShutdown` was adjusted so both cards use the same companion. The previous different-companion setup contradicted M3 per-companion concurrency; the test still covers the original no-ghost-dispatch-during-cancel intent for the only remaining gated case.
- UI verification is build-only in this sandbox. The formal rendered/live checks are captured in `docs/superpowers/2026-07-05-m3-live-test.md` for user execution.
- Fix round: no remaining product/architecture deviations. The only remaining verification failure is the known keychain `status -50` sandbox issue.

- Post-fix Level-0 adjustment by Claude (declared): slowActiveStreamDoesNotIdleTimeout timing constants enlarged (25ms/80ms → 150ms/600ms, 7 events) — the tight absolute margins false-failed deterministically under full-suite parallel load on fast hardware while passing in isolation; semantics preserved (total stream 1050ms > timeout proves deadline reset).
