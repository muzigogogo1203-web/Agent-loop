# Active ingestion deletion timestamp round-trip fix

## Root cause

The active-ingestion deletion transaction wrote a canonical millisecond
`occurredAt` value, then read it back through GRDB during committed-graph
validation. For modern timestamps, Foundation can decode SQLite's millisecond
text a few floating-point ULPs away from the original `Date`. The deletion
validator compared and hashed that raw decoded value as though it were the
exact contract value, rejected the otherwise valid graph as
`persistedGraphIntegrity`, and rolled the transaction back.

## Changed files

- `Sources/AgentLoopCore/Database/IngestionDeletionStore.swift`
  - Restore receipt, event, and outbox timestamps through
    `P1DTimestampV1.restorePersisted` before equality checks and command-hash
    reconstruction.
- `Sources/AgentLoopTestSuite/IngestionDeletionContractTests.swift`
  - Add a deterministic modern-millisecond regression covering the exact
    persisted-graph rejection.

## Verification

- Red: `p1e68aDeletionModernCanonicalEnvelopeCommitsPersistedGraph` returned
  `notCommitted(.persistedGraphIntegrity)` before the production change.
- Green: the same regression passed after the production change.
- A read-only SQLite backup of the user's live database reproduced the failure
  through `InputActiveIngestionDeletionPorts.live`; the same copied database
  passed through the complete live port after the fix. The real database was
  not mutated and still contained one source row and one result row.
- Focused authoritative run:
  `swift run RunTests --filter P1EIngestionDeletionContractTests` — 43/43
  passed. Full output: `focused-delete-suite.log`.
- Full authoritative run: `swift run RunTests` — 1086 tests executed; the
  deletion suite passed, while five unrelated parallel process/socket timing
  tests produced six issues. Full output: `verify.log`.
- Each affected parallel test passed when rerun alone:
  - `boardServerStopWaitsForBlockedHandlerThenCloses`
  - `boardServerStopWakesBlockedAcceptLoopAndReleasesListener`
  - `shellTimeoutTerminatesProcess`
  - `cliProcessBackendCancellationEscalatesAfterGrace`
  - `cliProcessBackendCancellationReturnsCheckedEvidence`
  Full output: `serial-reruns.log`.
- `scripts/run-app.sh` rebuilt, ad-hoc signed, and launched the real-data app.
  PID 71560 remained running; the new bundle passed `codesign --verify --deep
  --strict`; the post-launch fatal/assert/crash log query was empty.

## Deviations and authority

- No real deletion was executed after the fix. The user retains control of the
  destructive confirmation action in the relaunched app.
- No commit, push, merge, release, or destructive database operation was
  performed.

## 2026-09-05 correction to historical verification reporting

The original text above is retained as historical reporting, but its full-run
failure accounting and cause attribution are superseded by this correction.
`verify.log` records **six failing tests and six issues**, not five affected
tests:

1. `p1f1_075CLIHelpCapabilityMismatchIsUnsupported` — `processGroupSurvived`
2. `boardServerStopWaitsForBlockedHandlerThenCloses`
3. `boardServerStopWakesBlockedAcceptLoopAndReleasesListener`
4. `shellTimeoutTerminatesProcess`
5. `cliProcessBackendCancellationEscalatesAfterGrace`
6. `cliProcessBackendCancellationReturnsCheckedEvidence`

`serial-reruns.log` contains separate reruns for only the final five tests in
that list. It does not contain a separate rerun of
`p1f1_075CLIHelpCapabilityMismatchIsUnsupported`. Therefore the historical
full-run failures cannot be described, on those logs alone, as all separately
passing, unrelated to the change, timing-only, or solely environmental. The
original `verify.log` and `serial-reruns.log` remain unchanged.
