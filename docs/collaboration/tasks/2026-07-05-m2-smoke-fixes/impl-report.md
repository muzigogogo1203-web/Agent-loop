# M2 Smoke Fixes Implementation Report

## Changed Files

- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`

## Fix

- `AppStore.reloadMission` now dedupes `assigneeIds` preserving order before loading companions.
- `AppStore.reloadMission` now builds `cardCompanions` with `Dictionary(_:uniquingKeysWith:)` as defense in depth.
- `AppDatabase.companions(ids:)` now treats ids as an ordered set, deduping while preserving first occurrence, and still throws `RecordNotFoundError` for missing ids.
- Added regression test `companionsDedupesDuplicateIds` covering `[a, b, a] -> [a, b]`.

## Verification

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
- Full output: `docs/collaboration/tasks/2026-07-05-m2-smoke-fixes/verify.log`
- Result: 108 tests discovered; 107 passed; 1 failed.
- Failure: `keychainRoundTrip` failed with `KeychainError(status: -50)`, the known sandbox environmental failure.

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`
- Result: passed. Output appended to `verify.log`.

## Round 2: Anthropic Streaming Timeout Hotfix

### Changed Files

- `Sources/AgentLoopCore/Provider/AnthropicProvider.swift`
- `Sources/AgentLoopTestSuite/AnthropicProviderTests.swift`
- `docs/collaboration/tasks/2026-07-05-m2-smoke-fixes/verify.log`
- `docs/collaboration/tasks/2026-07-05-m2-smoke-fixes/impl-report.md`

### Fix

- Added streaming timeout constants for Anthropic provider defaults:
  - request timeout: `300`
  - resource timeout: `3600`
- Added a dedicated streaming `URLSession` built from `URLSessionConfiguration.default`.
- Default Anthropic provider construction now uses the dedicated streaming session instead of `URLSession.shared`.
- The existing injectable `session` initializer remains available for stubbed tests.
- Added `streamingSessionTimeoutDefaultsSupportSlowRelays` regression coverage.

### Verification

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
- Full output appended to `verify.log`.
- Final result: 109 tests discovered; 108 passed; 1 failed.
- Failure: `keychainRoundTrip` failed with `KeychainError(status: -50)`, the known sandbox environmental failure.
- New test `streamingSessionTimeoutDefaultsSupportSlowRelays` passed.

- Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`
- Result: passed. Output appended to `verify.log`.

### Notes

- Swift does not allow a `private static` property to be referenced directly from a public initializer default argument. To keep the streaming session private and preserve no-session default construction behavior, the implementation adds a no-session public initializer that delegates to the injectable initializer with the private streaming session.
- The timeout constants are package-scoped so `AgentLoopTestSuite` can assert them without making them public API.
