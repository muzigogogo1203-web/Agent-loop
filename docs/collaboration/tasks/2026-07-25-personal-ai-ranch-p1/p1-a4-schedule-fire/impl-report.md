# P1-A4 Schedule Fire — Implementation Report

> Date: 2026-08-11
> Status: Review02 bounded corrections and fresh technical gates complete; pending responsibility-isolated re-review and independent acceptance
> Authority: `plan.md`, `plan-revision-01.md`, and approved `reviews/01a-p1-a4-plan-review.md`

## Outcome

P1-A4 now owns scheduled Mission creation through one durable, replayable transaction boundary. An original slot either commits the complete started graph or one fixed failed-fire fact while atomically advancing the evaluation cursor. An explicit replay has a fresh global idempotency key, reconstructs and verifies its canonical payload, never moves the original cursor, and returns an existing winner only after binding the retained failed source, hashed runtime identity, durable work, and Mission identity into one validated graph.

Post-commit work is separated from durable truth. `MissionScheduler` commits first, then asks `Orchestrator` to wake already-committed planning work, and only then performs best-effort broadcast/notification. A wake, broadcast, or notification failure cannot rewrite a committed fire.

## Root causes closed

1. The pre-A4 claim-first schedule route could consume `lastFiredAt` before the Mission/work/event graph existed. The new ledger owner commits fire, cursor, Mission, Squad, planning work, identity, and canonical events in one database transaction.
2. The old day/week key and implicit local-time behavior were not a total slot identity. `ScheduleMath` now produces canonical v1 slot context and handles inclusive previous-fire, DST gap/fold, offset, calendar, and overflow behavior explicitly.
3. Replay previously had no durable payload identity or complete winner validation. A4 adds caller-built canonical replay payload/hash, fixed source restrictions, complete graph validation, and deterministic inserted/replayed/conflict outcomes.
4. Post-commit effects could obscure durable truth. Wake, guide broadcast, and notification are ordered after commit; caught effect failures are observable and cannot mutate fire/cursor state.
5. Startup catch-up could spin on a failed slot. The cursor advances for the original attempt, only the exact offline-miss code/message creates a current-process catch-up, and replay never advances the cursor.
6. The first implementation review proved that GRDB `TableRecord` itself exposed generic static and request-level update/delete APIs on the two intended fetch-only records. Both records now retain only `FetchableRecord`; every fire/cursor read uses explicit SQL and the fileprivate ledger remains the only writer.
7. The first implementation review also found that a replay winner could carry the correct payload hash while its internally self-consistent work/Mission runtime identity or retained source provenance differed from that payload. The shared winner validator now reloads and validates the failed original, rebuilds the complete payload without consulting current runtime/template state, and explicitly binds a started graph to the payload-derived `PlanningWorkInput`.

## Changed implementation files

The reviewed implementation partition is exactly these 13 paths:

1. `Sources/AgentLoopCore/Database/ScheduleStore.swift`
2. `Sources/AgentLoopCore/Database/AppDatabase.swift`
3. `Sources/AgentLoopCore/Work/DurableWork.swift`
4. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
5. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
6. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
7. `Sources/AgentLoopCore/Kernel/ScheduleMath.swift`
8. `Sources/AgentLoopApp/MissionScheduler.swift`
9. `Sources/AgentLoopTestSuite/ScheduleTests.swift`
10. `Sources/AgentLoopTestSuite/DatabaseTests.swift`
11. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
12. `Sources/P1MigrationMatrixRunner/main.swift`
13. `scripts/verify-p1-migrations-sqlite-matrix.sh`

The frozen 206-entry outside-partition manifest remains byte-exact. No Source, Package, RunTests, or script path outside this partition changed during A4.

## Verification evidence

| Gate | Result | Evidence |
|---|---:|---|
| Failure-first | Expected compile failures named only missing A4 schema/API/math behavior | `red-tests.log` |
| Canonical tests | 10 independent runs passed | `targeted-tests.log` |
| Affected tests | 10 independent runs passed | `targeted-tests.log` |
| Debug builds | Core, TestSuite, App passed | `build.log` |
| Release builds | Core, TestSuite, App passed | `build.log` |
| Migration matrix | Runner/build/syntax plus real and literal SQLite 3.51/3.52 lanes passed; all seven predecessors, replay/rollback, exact schema and diagnostic truth tables covered | `migration-matrix.log` |
| Source/scope gates | Manifest identity/bytes, exact 13-file complement, owner sentinels, obsolete API absence, DEBUG-only observer symbols, preview isolation source, six builds, migration terminal marker, and `git diff --check` passed | `source-gates.log` |
| Authoritative suite | Exactly 667/667 tests in 7 suites passed in one fresh unfiltered run | `verify.log` |
| Runtime preview | Two distinct cold isolated roots; each launch produced exactly one checkout executable, isolated DB/lock and seven isolated open files, zero normal-root matches, bounded liveness, graceful exit, and zero remaining process before the next launch | `preview.log` |

The build log contains the environment's existing unknown-driver-flag notice and two pre-existing `BoardServerTests.swift` weak-variable warnings. None is introduced by an A4 path.

## Verification-discovered race and correction

The first final full-suite candidate reached all 667 tests but exposed one real test-isolation race in `broadcastFailureDoesNotRewriteStartedFire`. The failed fixture showed the work already `running` at attempt 1/version 2; its claim preceded the direct durable-halt event by about 41 ms. Recovery had asynchronously launched an initial pump, while the A4 wake harness returned before that pump proved idle. Under full-suite load, that pump could claim a newly inserted test work item before the separate halt transaction. The wake gate itself remained correct: provider, event, and DEBUG observer counts were all zero.

The root fix is test-only and inside the reviewed allowlist: after `recoverAndReconcile()`, the shared A4 wake harness now awaits `orchestrator.waitUntilIdle()`. This uses the supervisor's own event-driven idle contract (`pumpTask == nil`), not sleep, polling, retry, or product fallback. All 20 independent tests, six builds, source gates, and the fresh 667-test suite were rerun after the correction.

## Review02 findings and bounded correction

The first responsibility-isolated implementation review returned `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2` in `reviews/02-p1-a4-implementation-review.md`. Both counterexamples were reproduced with regressions before the product correction: the declarations still inherited GRDB mutation APIs, and two canonical but identity-mismatched replay graphs were accepted.

The bounded correction changed only four already reviewed A4 paths:

- `ScheduleStore.swift` removes `TableRecord` from fire/cursor records and replaces its three query-interface reads with explicit read-only SQL.
- `DurableWorkStore.swift` replaces the remaining four TableRecord-only reads, reloads the retained source in the shared replay-winner validator, reconstructs the full payload from retained provenance, and distinguishes original, selected-replay, and unavailable-replay graph expectations explicitly.
- `DatabaseTests.swift` folds the fetch-only regression into the existing canonical test. It uses a positive compiler control for raw-SQL reads and a fail-closed negative `swiftc -typecheck` probe proving `deleteAll`, `updateAll`, and request `filter(...).deleteAll` are unavailable.
- `ScheduleTests.swift` folds two valid-but-different corruption cases into the existing replay canonical test: coherent work/Mission runtime drift and coherent retained-source provenance drift. Both require the exact frozen integrity/conflict error, zero provider resolution, unchanged writer `totalChangesCount`, and preserved first winner/source records.

No new `@Test` function, schema, dependency, target, public/package API, current-state winner dependency, or provider call was added. The existing read-winner and concurrent commit-winner paths continue to call the same strengthened validator. After this correction, all 10 canonical and 10 affected tests, six builds, dual SQLite migration matrix, strengthened source gates, fresh 667-test suite, and two isolated previews were rerun from the final bytes and passed.

## Deviations and authority

- No product, schema, API, dependency, or target decision deviated from the reviewed plan.
- Post-implementation corrections were limited to the deterministic test-harness idle barrier and the two root-cause fixes required by Review02. The former changes no product behavior; the latter close the reviewed ledger ownership and replay identity defects without expanding A4's product surface.
- No `Package.swift`, `Package.resolved`, `Sources/RunTests/main.swift`, P1-B–P6 path, or unrelated user change was modified by A4.
- No commit, push, merge, release, destructive/normal-user-data operation, payment, public communication, external action, or real-user action occurred.
- `scripts/run-app.sh` was executed unmodified in preview mode and did not open the normal AgentLoop state root.

## Review handoff

The Review02 correction is ready for a fresh responsibility-isolated re-review. A4 must remain unaccepted until that review reports zero P0/P1 and a separate acceptance owner verifies all evidence and writes `ACCEPTED`, closing R-04.
