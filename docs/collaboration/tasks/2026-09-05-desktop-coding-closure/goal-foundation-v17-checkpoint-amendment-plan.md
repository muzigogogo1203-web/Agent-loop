# A1 amendment — preserve the V17 historical registration checkpoint

Status: proposed bounded owner correction; independent review required before implementation. This amends only the inaccurate source-inspection claim in the original A1 plan and its brief about `P1ECampLifecycleMigrationTests`; it does not change the desktop migration or the historical V16/V17 contracts.

## Actual failure and root cause

The required unchanged compatibility run `goal-foundation-migration-compat-v16.log` (SHA-256 `ad5552ca4f1901557178443babc7b079782f14b32bc9b18d6d5edc737630e3d9`) ran PID78022:13tests/1suite/1.076s/one issue/exit1. Twelve tests pass. `p1e01V16MigrationIsImmediateSuccessor` reads the complete current migration list, then checks V15→V16 adjacency, V16→V17 adjacency, and V17 equals the last index. The new legal additive migration makes that last expectation18versus19. The original A1 plan's statement that this test does not assume V17 is latest is factually wrong. Root read the actual source at lines282–289 and confirmed the precise failure; this is not a migration rollback or schema regression.

The authoritative preimage of `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift` is SHA-256 `0be4efc3a864edce266b95d8b0bb2c74abec5c466b472bf122132698bf45f609`. Existing approved AppDatabase migration and OutcomeContractTests remain frozen. The compatibility batch stopped at this real failure (`&&`); its planned P1D run did not execute and must not be reported as passing.

## Smallest bounded correction

Change only setup in `p1e01V16MigrationIsImmediateSuccessor`:

```swift
let allMigrations = AppDatabase.migrator.migrations
let desktop = try #require(allMigrations.firstIndex(of: "desktop-goal-workflow-v1"))
let migrations = Array(allMigrations.prefix(desktop))
// Existing v15/v16/v17 lookups and all three expectations remain unchanged.
```

Add a short dated comment identifying the frozen V17 prefix. This cutoff is the concrete reviewed desktop successor, not V17 itself: a spurious migration between V17 and desktop still violates the unchanged last-index assertion. Missing desktop registration fails explicitly; earlier adjacency is still checked. Future additions after desktop no longer rewrite the historical V17 checkpoint. The separately approved desktop migration suite continues to validate the real current head, exact new DDL, fresh/upgrade identity, ledger append and rollback. No count is increased merely to obtain GREEN and no historical assertion is removed.

## Scope and gates

- Add only this one existing test path to the current A1 allowlist (original eight paths plus the separately approved five narrative-domain paths become fourteen total). No new source file or source-inventory exclusion is added. This file is already an exact historical P1-E path; frozen manifests, source lists and count/hash assertions must remain unchanged.
- Capture the exact whole-file preimage. Keep the prior failure log intact. Independent plan review must confirm the fixed-prefix mechanism before source edit.
- Root implements only the setup/comment hunk, then runs the complete `P1ECampLifecycleMigrationTests` suite with305frozen inputs and complete outputs. The missing P1D compatibility run follows separately. Existing fullA1 acceptance remains closed until all original read/retention and integration requirements are done.
- A responsibilities-separated reviewer compares the actual preimage, confirms unchanged original expectations/remaining file, verifies focused GREEN, and pins the one admitted file hash. Existing diff-packaging guards may accept only that exact reviewed amendment hash, never a broad exclusion.
- Record the factual erratum and this amendment in the current progress/implementation ledger. Original frozen plan/brief bytes remain historical approved inputs; this reviewed amendment explicitly supersedes their single incorrect inspection claim.

No product direction, privacy/permission boundary, database schema, Provider use, application state, commit, push or release authority is changed. All tests use isolated fixture state. An unexplained failure or another affected path must be reported, not hidden by this correction.
