# M1.1 冒烟反馈修复 — 实现报告

## Changed files

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Provider/LLMProvider.swift`
- `Sources/AgentLoopCore/Provider/AnthropicProvider.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/CompanionEditorView.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/DMChatView.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`
- `Sources/AgentLoopTestSuite/CardRunnerTests.swift`
- `docs/collaboration/tasks/2026-07-04-m1-smoke-fixes/verify.log`
- `docs/collaboration/tasks/2026-07-04-m1-smoke-fixes/impl-report.md`

## What changed

- Added `AgentEvent.turnStarted` and `AgentEvent.turnRetrying`.
- Added AgentLoop per-turn retry for retryable transport/provider errors with 2s/4s backoff, transcript rollback support events, and loop/provider diagnostics logging without headers, request body, or API keys.
- Added human-readable `ProviderError.description`.
- Added CardRunner `run_error` diagnostic event before blocking failed runs, with only readable error text and completed turn count.
- Added AppStore activity timeline state, tool-name humanization, progress-note refresh on successful `add_progress_note`, retry activity rows, and readable failed text.
- Added TaskRunView activity timeline above transcript.
- Added companion edit load/save behavior preserving `id`, `createdAt`, `kind`, `campId`, and `toolsJson`.
- Added sidebar context-menu edit entry and DM chat toolbar edit entry, returning to the edited chat on save.
- Added five AgentLoop tests for transient retry success, retry exhaustion, unauthorized no-retry, turn-start event order, and provider error descriptions.
- Review 01 follow-up: added `AgentLoop.retryDelays` with product default `[.seconds(2), .seconds(4)]` and fast test delays for retry tests.
- Review 01 follow-up: added `CardRunner.retryDelays` with the same product default so the existing transport-error runner test can avoid real sleeps without changing app behavior.
- Review 01 follow-up: replaced the empty companion-editor save `catch` with visible red error text and stale-error clearing.
- Review 01 follow-up: added the `turnStarted` retry-attempt semantics comment requested in P3-1.

## Verification

- Build: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox` passed.
- Test command output saved to `verify.log`: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests > docs/collaboration/tasks/2026-07-04-m1-smoke-fixes/verify.log 2>&1`.
- Review 01 rerun output appended to `verify.log`: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests >> docs/collaboration/tasks/2026-07-04-m1-smoke-fixes/verify.log 2>&1`.
- Test result in this Codex sandbox: 75 tests discovered; 74 passed; 1 unrelated existing keychain test failed.
- Failing test: `keychainRoundTrip`, `KeychainError(status: -50)`.
- All five new tests passed.
- Latest appended run completed in 0.362 seconds; retry-sleep performance regression is fixed.

## Deviations

- Plain `swift build`/`swift run RunTests` could not run inside this execution sandbox before source compilation because SwiftPM/Clang attempted blocked cache and sandbox operations (`~/.cache/clang` write denied, then `sandbox-exec: sandbox_apply: Operation not permitted`). I reran with Clang module cache redirected to `/private/tmp` and SwiftPM sandbox disabled.
- Completion definition item "all tests green" is not met in this sandbox because of the unrelated keychain failure above. No source files outside the plan scope were modified to work around it.
