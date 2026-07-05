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
