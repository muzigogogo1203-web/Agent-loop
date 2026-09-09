# P1-A1a Durable Work DDL + Store — Implementation Report

## Status

Implementation and implementer verification are complete and ready for an
independent implementation review. This report does **not** accept A1a and does
not authorize A1b.

R9 remained bounded to the accepted SQLite `NULL`/`UNKNOWN` root cause:

- the frozen Stage contains the six approved §18.1/§18.6 diagnostics wrappers;
- A1a implements only the three §18.1 v12 wrappers in the real migrator;
- §18.6/v16 remains owned by P1-E and was not implemented;
- the A1a test and migration runner gates exercise the frozen v12
  `56 + 40 + 288 = 384` normalized catalog, seven sentinels and nineteen legal
  controls on real and literal schemas.

No production planner, orchestrator, application workflow, UI wiring, A1b or
P1-E behavior was added.

## Frozen inputs

The final verification rechecked these accepted inputs:

- Stage:
  `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190`
- P1 Plan:
  `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3`
- A1a leaf Plan:
  `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb`
- `Package.resolved`:
  `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`

The matrix script now fails fast unless `Package.resolved` matches that exact
Review09 baseline before and after both SQLite lanes.

## Changed implementation files

The A1a implementation is confined to the ten files authorized by the frozen
leaf Plan:

1. `Package.swift`
2. `Sources/AgentLoopCore/Database/AppDatabase.swift`
3. `Sources/AgentLoopCore/JSON/CanonicalJSON.swift`
4. `Sources/AgentLoopCore/Work/DurableWork.swift`
5. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
6. `Sources/P1MigrationMatrixRunner/main.swift`
7. `scripts/verify-p1-migrations-sqlite-matrix.sh`
8. `Sources/AgentLoopTestSuite/DatabaseTests.swift`
9. `Sources/AgentLoopTestSuite/CanonicalJSONTests.swift`
10. `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

Task evidence written by the implementer:

- `verify.log`
- `build.log`
- `preview-smoke.png`
- this `impl-report.md`

The worktree also contains accepted P0/spec documentation work from the
long-running ranch task. It was not reverted or treated as part of this A1a
implementation.

## Test-first R9 evidence

Before changing the v12 DDL, the expanded
`ddlRejectsEveryInvalidWorkAttemptEventErrorStatePair` test failed against the
old constraints:

- work: actual `19/37`, expected `18/38`;
- attempt: actual `19/21`, expected `10/30`;
- event: actual `19/269`, expected `17/271`;
- all seven `NULL`/`UNKNOWN` sentinels were accepted;
- twelve exact `UNKNOWN` oracle mismatches were reported.

After applying `CHECK (COALESCE((...), 0))` to the three v12 diagnostics
constraints, the targeted test passed `1/1`.

The test suite still contains exactly the frozen 69 A1a test names:

- Database: 3
- Canonical JSON: 10
- Durable Work: 56

## Migration matrix

Both linked SQLite lanes passed:

- system SQLite 3.51.0;
- Homebrew SQLite 3.52.0, with the runtime version and source ID required to
  match the corresponding CLI exactly.

Each lane ran the same real GRDB migrator for:

- fresh;
- v7;
- v8 Coding Ranch;
- v9 Evercamp;
- v10 runtime profiles;
- v11 CLI kinds.

Each lane also created an independent v11 database and applied the 187-line
frozen Stage §18.1 literal whose SHA-256 is
`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2`.

Every real and literal diagnostics scope executed 384 actual candidate inserts
under isolated savepoints and obtained:

- work `56 = 18 accepted / 38 CHECK rejected`;
- attempt `40 = 10 / 30`;
- event `288 = 17 / 271`;
- sentinels `7 = 0 / 7`;
- controls `19 = 19 / 0`.

Unexpected constraint classes are rethrown; only
`SQLITE_CONSTRAINT_CHECK` counts as an expected illegal-row rejection.

Following the independent preflight finding, the shared catalog now captures a
single equatable health state before and after its outer rollback:

- all three durable row counts;
- `PRAGMA foreign_keys`;
- every stably ordered `PRAGMA foreign_key_check` row;
- every `PRAGMA integrity_check` result, required to equal exactly `["ok"]`.

The before/after states must be identical. Real fixtures also repeat the health
gate after append-only checks, before printing their FK/integrity pass lines.
Literal fixtures repeat it at their final state.

Rollback, replay, DDL, guard, backfill, append-only and
`Package.resolved` gates all passed. The final runner and script hashes are:

- runner:
  `dddd1ef320ca591493387f7f90f9be4d1b663f141821fd9bc6e80f49551bf8c5`
- script:
  `41777ea24e60914734fa4e9c2fbe9bd334cf2bcd1dbbd9abd10494984d470c56`

## Authoritative verification

Complete command output is preserved rather than replaced by summaries:

- `swift run RunTests`
  - two earlier high-parallel full runs each exposed a different existing
    `IdlePatternProvider` exhaustion failure;
  - each affected test passed immediately in isolation;
  - a later exact full run passed `492/492`;
  - after the final runner/script preflight revision, the current exact full
    run again passed `492/492` in 12.560 seconds.
- `swift build --product AgentLoopApp`: passed in 7.04 seconds.
- `swift build --product P1MigrationMatrixRunner`: passed.
- `scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`:
  passed.
- `bash -n scripts/verify-p1-migrations-sqlite-matrix.sh`: passed.
- `git diff --check`: passed.
- `git status --short --branch`: captured in `verify.log`.

The earlier intermittent failures are retained in `verify.log`; they were not
deleted or relabeled as passing. No product fix was made for them because they
were unrelated to A1a, passed in isolation, and the final current full run is
green.

## Isolated App preview

The required smoke test used:

```text
AGENTLOOP_STATE_DIR=/private/tmp/agentloop-a1a-preview.2Wc0jy scripts/run-app.sh --preview
```

Evidence confirms:

- process:
  `/Users/muzi/Agent-loop/.build/AgentLoop.app/Contents/MacOS/AgentLoop`;
- environment:
  `AGENTLOOP_UI_PREVIEW=1` and the independent state root above;
- every open state file belonged to that root;
- visible degraded injection:
  preview mode disables Keychain reads and scheduling, so the UI displayed the
  expected no-model state;
- A1a itself adds no production/UI failure path, consistent with its frozen
  ledger/store-only boundary;
- screenshot: `preview-smoke.png`;
- Computer Use 原始截图流是 JPEG；原始 bytes 保存在
  `preview-smoke-source.jpg`，并已无损保留画面内容转码为与扩展名一致的
  `preview-smoke.png`；
- the isolated process exited cleanly after capture.

No normal state root or real credential was read or modified.

## Deviations and residual observations

- There was no deviation from the frozen product/data/dependency design.
- The independent preflight found one P1 evidence gap. It was closed only in
  the authorized runner by adding the before/after health snapshot described
  above.
- The matrix build intentionally uses SwiftPM's ignored
  `.build/checkouts/GRDB.swift/SQLiteCustom/src` mirror to resolve GRDB's pinned
  SQLiteLib submodule without network drift. The script fails fast if it is
  absent. This is a nonblocking local-environment prerequisite, not a product
  dependency or a passing fallback.
- The SQLite 3.52 link emits a warning that the Homebrew dylib was built for a
  newer macOS deployment version. The binary launches, reports the exact
  expected 3.52 version/source ID and passes every gate; the warning is retained
  in `verify.log`.
- Review01 发现最初的 `preview-smoke.png` 实际使用 JPEG 编码。原始 bytes 已改用
  `.jpg` 扩展名留存，并生成真实 PNG；该 evidence hygiene P2 已关闭，不改变截图
  内容、进程或隔离状态证据。
- Under the frozen canonical-number input limits, the 512-byte output cap is a
  redundant defense and cannot be independently reached after all earlier
  token/coefficient/exponent limits succeed. The implementation retains and
  structurally tests the cap; no invalid fixture was fabricated to claim
  otherwise.

## Handoff gate

A1a remains **not accepted**. Review01 has independently inspected the current
implementation, full evidence, frozen fingerprints and scope and recorded zero
P0/P1. The current and only next gate is a separate acceptance owner writing
`acceptance.md`. A1b remains closed until acceptance passes.
