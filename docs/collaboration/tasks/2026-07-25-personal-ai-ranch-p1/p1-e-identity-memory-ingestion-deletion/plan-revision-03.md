# P1-E Plan Revision 03 — Close the final event-scope compatibility roots

> Date: 2026-08-26  
> Scope: final bounded E5 compatibility correction after Revision 02  
> Authority: base P1-E plan §§3, 8–12; canonical P1 plan §7; canonical Stage
> §§14–15, 18.6, 19, 26–27; user instruction to proceed independently without
> Claude  
> Frozen history: `plan.md`, Revisions 01–02, Review01, Review01a, Review01b,
> and `verify-red.log` remain byte-immutable and are not rewritten

## 1. Trigger and reproduced red frame

Revision 02 removed the dominant v16 compatibility failures. A single filtered
recheck of every unique test name recorded in immutable `verify-red.log` ran
109 current tests in seven suites and retained 25 issues:

```text
temporary_log=/tmp/p1e-red-frame-recheck.fgkNsA
tests=109
suites=7
issues=25
command_status=1
sha256=641eee9552e92d2244040da6e0c4235451e35bcbd418d4d7492259f584d5e80d
```

Three A3/A4 frozen-entry issues in that frame were a stale successor-boundary
sentinel and are already independently green in the two-test recheck. The 22
remaining issues reduce to exactly three roots:

1. all schedule replay/bit/storage failures come from `EventRecord.createdAt`
   using GRDB's millisecond UTC-text encoding while `schedule_fire.createdAt`
   stores the exact epoch `Double`;
2. BoardTools fixtures pass a nonexistent `run-1`, which the v16 reference
   graph correctly rejects as `event_run_dangling`;
3. Orchestrator's established empty-string global-kernel sentinel is routed
   through the Camp reference graph and therefore cannot persist its event.

Two additional Schedule fixtures are independently invalid under v16: one
ordinary-deletes a referenced companion and one raw-inserts an unscoped event.
Neither authorizes trigger, foreign-key, resolver, or assertion weakening.

## 2. Exact effective allowlist

The executable `scope-allowlist.txt` is revised from 98 to exactly 102 unique
newline-delimited paths. Its effective SHA-256 is:

```text
1e94456880e52d584fde94503e4159902f8889d5b16e6933fb6e6545e4ff69c9
```

Revision 03 adds exactly two existing test paths and two task artifacts:

```text
Sources/AgentLoopTestSuite/BoardToolsTests.swift
Sources/AgentLoopTestSuite/ScheduleTests.swift
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-03.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01c-p1-e-compatibility-plan-review.md
```

The two source/test pre-images are frozen before Revision 03 writes:

| File | SHA-256 |
|---|---|
| `BoardToolsTests.swift` | `a191a5c9b2706b699ee2410be1470aeaf3182d01acb7682a5ecab2f234aeac42` |
| `ScheduleTests.swift` | `e4fcaa1adf9ce7a5d75858549c9eb3f51032816b74008370249b07f92cc8e5e8` |

The NUL-safe serializer from the base plan, after excluding the exact 102
paths, freezes the effective outside boundary at:

```text
dirty_total=592
allowlisted_present_count=93
outside_count=499
outside_manifest_v1=206148164535b7e48b1fc64ec564c4bf5ff9b86981ec12509c9d43b7fd9243a9
```

The first two counters may increase only when the currently clean Board test
and the two new task artifacts become present/dirty. The outside count/hash may
not change.

## 3. Decision-complete correction map

### 3.1 Exact event timestamp storage

`EventRecord` in the already-allowed `Records.swift` gains only
`databaseDateEncodingStrategy(for:)`. `createdAt` uses
`.timeIntervalSince1970`; every other column retains `.deferredToDate`.
Decoding remains GRDB's deferred strategy so historical text rows remain
readable. No migration, replay-validator relaxation, manual event SQL, time
rounding, or tolerance is permitted.

### 3.2 Exact dual-scope kernel-error rule

`LegacyEventScopeResolverV1` gains a distinct exhaustive `kernelError` rule:

1. `missionId == ""` is the existing explicit global sentinel. It resolves
   global only when `cardId`/`runId` are nil and payload contains none of
   `campId`, `missionId`, `cardId`, `runId`, `ingestionId`, `noteId`,
   `scheduleId`, or `templateId`; otherwise it fails closed.
2. `missionId == nil` with no reference-graph evidence resolves global.
   A nil mission with real card/run/payload evidence keeps the existing strict
   reference-graph resolution.
3. a nonempty mission keeps the existing strict reference-graph resolution.
   Missing references, cross-Camp evidence, or dangling rows still fail.

The existing `globalKernel` rule for halt/resume is unchanged. Kernel errors
are not globally downgraded, and `appendKernelErrorEvent`'s observable logging
behavior is not hidden behind a fallback.

Without adding test declarations, extend the existing P1-E tests:

- `p1e35LegacyEventAppendScopeFirst` proves runtime empty-sentinel kernel
  errors write scope first as `global/NULL`;
- `p1e09LegacyEventScopeExhaustiveBackfill` inserts a legal v15
  empty-sentinel kernel error, migrates v15 to v16, and proves the same scope.

The existing mission-scoped kernel-error tests remain the Camp-scope guard.

### 3.3 Exact Board fixture repair

In `makeBoardFixture`, replace the raw card transition with
`db.startRun(cardId: ids.cardId, runId: "run-1")`. This creates the real Run
and transitions the card atomically. Keep the fixed ID and all existing
completion/artifact/progress assertions. Do not weaken dangling-run rejection
or change production BoardTools.

### 3.4 Exact Schedule fixture repairs

1. The missing-companion validation fixture updates
   `mission_template.companionIdsJson` to a canonical array containing one
   nonexistent ID. It does not delete a referenced companion.
2. `scheduleFiredEventMarksScheduledOrigin` creates its deliberately
   projection-invalid event through `appendLegacyEventAndScope` with canonical
   `{}` and the same mission/time, then asserts `invalidScheduledOrigin` using
   the returned event ID. It does not raw-insert or use malformed JSON.

### 3.5 Frozen successor sentinels

Update only the P1-E exact allowlist expectations in
`DurablePlanningTests.swift`:

- SHA is the 102-line hash above and exact count is 102;
- A4 raw P1-E intersection is 33, while its successor set and unaffected count
  remain unchanged because BoardTools was already P1-D scope;
- A3 raw P1-E intersection is 35, while its successor set and live count remain
  unchanged because BoardTools was already P1-D scope and Schedule was already
  an A4 historical exclusion.

No historical manifest or frozen prior-stage artifact is rewritten.

## 4. TDD order and evidence gates

1. Freeze this revision and Review01c before product/test compatibility writes.
2. Preserve `verify-red.log` and the recheck above. Extend the two existing
   kernel tests first and capture their source-unchanged red result in a unique
   temporary log; existing Schedule, Board, and Orchestrator failures are the
   red evidence for their exact roots.
3. Apply timestamp encoding and the dual-scope kernel rule separately; run the
   smallest owning tests after each root.
4. Apply only the three fixture corrections and the exact successor-sentinel
   update. Run their owning tests.
5. Run every current test corresponding to the 112 unique names in the first
   red frame, explicitly mapping renamed declarations rather than silently
   dropping them. Zero issue is the compatibility gate.
6. Run the four Revision-02 load-sensitive observations standalone three times
   each. No retry-only source change is authorized.
7. Re-run the exact 90-test P1-E gate, source/scope gates, build, and both
   SQLite matrix lanes.
8. Run authoritative unfiltered `swift run RunTests` with pipefail and full
   stdout/stderr in `verify.log`; command and tee must both exit zero.
9. Update `impl-report.md`, perform independent Codex implementation review,
   and write acceptance only when every gate is green.

## 5. Narrow completion gate

Revision 03 is complete only when:

- base plan plus Revisions 01–03 and the 102-line allowlist have an independent
  Codex plan review with `APPROVED — 0 P0 / 0 P1` before implementation;
- all named Schedule, Board, global-kernel, backfill, and successor-boundary
  tests pass without weakened assertions;
- all current successors of the first red-frame tests pass;
- the P1-E 90-test gate, authoritative full suite, build, source/scope gates,
  and both migration lanes pass;
- the outside boundary remains exactly 499 with the frozen manifest;
- no P1-F1/F2 behavior, migration v17, forbidden external action, or path
  outside the effective allowlist is changed.

Until then P1-E remains not accepted and P1-F1 remains closed.
