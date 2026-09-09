# P1-A3 Leaf Plan — Candidate Atomic Conversion

> Status: **REVISION 01 — Review01 0 P0 / 2 P1 preserved; implementation blocked pending Review01A**
>
> Date: 2026-08-10
>
> Branch / entry HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Authority: accepted master spec, P1 Stage §6.5, canonical P1 Plan §3.4, and accepted P1-A2 acceptance

## 1. Entry, scope, and stop conditions

P1-A2 is `ACCEPTED` and opens only P1-A3. A3 exists solely to close R-03: the
current `PlanningEntryCoordinator.startCandidate` performs
`existingMissionId -> Orchestrator.startMission -> linkConverted`, so a failure
after Mission/work commit can leave an unlinked Mission.

Immutable Review01 is `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2`. This bounded
Revision 01 closes only P1-01 (terminal replay/first trace) and P1-02 (durable
mode/profile fences); it does not rewrite that verdict. Implementation may
begin only after a fresh responsibility-isolated reviewer writes
`reviews/01a-p1-a3-plan-review.md` with `APPROVED — 0 P0 / 0 P1` under the
standing Goal. Any ambiguity, scope drift, unknown failure, or non-empty Open
Questions must be recorded in `blocked.md` and work must stop. A3 does not
authorize commit, push, merge, release, destructive data operations, normal
user-data access, public communication, or real-user actions.

Planning fallback history only: Claude Code planning failed twice with OAuth
401; a substitute planner was interrupted after an unobservable stall and
made zero repository writes. These are neither a product blocker nor a Review
or approval result.

## 2. Exact implementation allowlist

Only these nine product/test files may change during implementation:

1. `Sources/AgentLoopCore/Product/MissionDraftFactory.swift`
2. `Sources/AgentLoopCore/Work/DurableWork.swift`
3. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
4. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
5. `Sources/AgentLoopCore/Database/AppDatabase.swift`
6. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
7. `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
8. `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
9. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`

Task artifacts may additionally be created only under this task directory:
`red-tests.log`, `verify.log`, `build.log`, `impl-report.md`, `acceptance.md`,
`blocked.md`, and `reviews/`. No schema, migration, `EventKind`, `Package.swift`, target or
dependency edge, AppStore, RunTests, matrix script, or other product/test/App
file may change.

## 3. Frozen API and ownership

### 3.1 Package-only command/result

Add in `DurableWork.swift`:

```swift
package struct CandidatePlanningStartCommand: Sendable, Equatable {
    package let draft: CodingRanchMissionDraft
    package let goal: String
    package let companionId: String
    package let workspacePath: String?
    package let budgetTokens: Int
    package let autonomy: MissionAutonomy
    package let planningInput: PlanningWorkInput
    package let idempotencyKey: String
    package let traceId: String
}

package struct CandidatePlanningStartResult: Sendable, Equatable {
    package let missionId: String
    package let workId: String
    package let disposition: DurableWorkEnqueueDisposition
}
```

Both receive package initializers. No new `public` or `package` protocol, no
new target edge, and no new schema/API surface is permitted.

### 3.2 One call chain

The only candidate start path is:

```text
CodingRanchStoreAdapter
  -> PlanningEntryCoordinator.startCandidate
  -> Orchestrator.convertCandidateAndEnqueuePlanning
  -> DurableWorkSupervisor.convertCandidateAndEnqueuePlanning
  -> AppDatabase.convertCandidateAndEnqueuePlanning
  -> PlanningDurableWorkLedgerOwner (same Database transaction)
```

Freeze these signatures/access levels:

```swift
// Orchestrator.swift
package func captureCandidate(
    draft: CodingRanchMissionDraft,
    runtime: PlanningEntryRuntimeSelection
) -> CapturedCandidateMissionStart

package func startCandidate(
    _ captured: CapturedCandidateMissionStart,
    goal: String,
    companionId: String,
    workspacePath: String?,
    budgetTokens: Int,
    autonomy: MissionAutonomy
) async throws -> String

package func convertCandidateAndEnqueuePlanning(
    _ command: CandidatePlanningStartCommand
) async throws -> CandidatePlanningStartResult

// DurableWorkSupervisor.swift
package func convertCandidateAndEnqueuePlanning(
    _ command: CandidatePlanningStartCommand
) throws -> CandidatePlanningStartResult

// DurableWorkStore.swift, extension AppDatabase
package func convertCandidateAndEnqueuePlanning(
    _ command: CandidatePlanningStartCommand,
    planningProviderResolver: any PlanningProviderResolver
) throws -> CandidatePlanningStartResult
```

`CapturedCandidateMissionStart` stores the immutable `CodingRanchMissionDraft`,
runtime selection, key, and trace. `captureCandidate` keeps the deterministic
key `mission-start:candidate:<candidateId>:v1` and generates one trace before
the Adapter's first `await`. The Coordinator creates `PlanningWorkInput`, builds
the command, and delegates exactly once. It performs no DB read/write.

The Orchestrator applies its existing running/recovery gates. The Supervisor
applies its existing dispatch/compatibility gates and passes its existing
resolver to AppDatabase. After AppDatabase returns, the same start path must
re-read the current work and durable dispatch mode before any tick/kick:

- only current `.queued` or `.retryScheduled` plus durable `.running` must
  ensure the tick and invoke `kick()` exactly once for that completed command
  call; `kick()` retains its own actor gates and may coalesce the pump;
- current `.running`, `.succeeded`, `.failed`, or `.canceled` performs no tick
  and no kick;
- `.inserted` may emit the existing in-memory planning-start notification only
  after commit and the same queued/running revalidation;
- `.replayed` never emits a new persistent or in-memory start event. A queued
  or retry-scheduled replay wakes the existing work only through the above
  conditional path; running and terminal replay return directly.

No provider dispatch, tick, start event, or kick occurs before commit, after a
failed/rolled-back transaction, across durable halt, or for a terminal replay.

`Orchestrator.startMission` remains unchanged for manual, confirmed-proposal,
and schedule entry paths. A3 must not reroute or change their behavior.

## 4. Replay-first provider boundary

`AppDatabase.convertCandidateAndEnqueuePlanning` follows the existing planning
ledger pattern, without nesting `enqueueMissionPlanning` inside `pool.write`.
The initial DB read order is exact:

1. require persisted `kernel_control.global.dispatchMode == running`;
2. look up the deterministic planning-work key; if a winner exists, run the
   shared complete-graph validator and return `.replayed`;
3. only for an absent key, fetch the exact `RuntimeProfileRecord` whose primary
   key is `planningInput.runtimeProfileId`; missing or CLI profile fails before
   provider resolution. This DB record is the immutable read snapshot used by
   the later write fence.

Only after an absent snapshot succeeds, call
`resolvePlanningProvider(profileId:model:)` outside the write transaction with
the captured `planningInput.runtimeProfileId` and `planningInput.plannerModel`.
The resolver returns only an `LLMProvider`; it does not return, construct, own,
or refresh the DB profile snapshot, and it may not select a default profile or
model. Resolver failure produces zero business writes/events and no dispatch.

A winner found after the durable-running gate replays before any profile,
catalog, credential, endpoint, or provider check. Replay is therefore
independent of their current availability, but it never crosses a durable halt
gate. The incoming trace is required nonblank only when the absent path is
eligible to insert. It is deliberately not part of replay identity: replay
never compares it with `work.traceId`, never overwrites it, and returns the
original Mission/work while preserving the first trace, timestamps, attempt,
state, and version byte-for-byte.

## 5. Single-transaction validation and writes

The fileprivate ledger owner in `DurableWorkStore.swift` owns the one GRDB
transaction. Its write order is exact:

1. re-require persisted durable dispatch mode `.running`;
2. re-check the deterministic key; a concurrent winner uses the same replay
   validator immediately, before the absent-path profile fence;
3. only while still absent, re-read the exact current profile ID, require its
   kind to equal the initial DB snapshot kind, and require non-CLI; missing,
   replaced-ID/kind drift, or CLI conversion fails before IDs/writes;
4. run the following eight candidate/source/residency checks in order;
5. only after every fence/check succeeds, validate nonblank incoming trace,
   generate IDs, and perform the atomic writes.

The eight checks are exact:

1. candidate exists and `candidate.id == draft.candidateId`;
2. candidate type is `.mission`;
3. candidate status is `.accepted`, with `missionId == nil` (unless the exact
   replay winner was already validated);
4. `candidate.ingestionId == draft.ingestionId` and that ingestion exists in
   the same candidate Camp;
5. exactly one matching source link exists for the ingestion and its
   `campNoteId == draft.noteId`;
6. source note exists and `note.campId == candidate.campId == draft.campId`;
7. Camp exists and is not archived;
8. companion exists, its `campId` is non-nil, and it equals the candidate Camp.

There is no default-Camp or nil-residency fallback. Missing records use the
existing `RecordNotFoundError`; invalid state/identity/residency uses existing
fail-fast state/conflict errors. None may be caught and converted to success.

After all fences/checks, the same transaction creates exactly one Squad, one Mission,
one queued attempt-zero planning work, updates the candidate to `.converted`
with that Mission ID, and writes exactly one each of `missionCreated`,
`planStarted`, and `actionCandidateConverted`. The work uses canonical
`PlanningWorkInput` JSON/hash, aggregate `mission/<missionId>`, candidate key,
first trace, Camp, and the existing max-attempt/version conventions. Mission,
Squad, work, candidate update, and all three events commit or roll back
together. Failure injection at work insert must leave all of them absent and
the candidate accepted/unlinked.

## 6. Exact replay-conflict graph

The shared validator accepts a work in every `DurableWorkState` — `.queued`,
`.running`, `.retryScheduled`, `.succeeded`, `.failed`, and `.canceled` — when
the immutable start graph remains intact. It does not require the current
Mission to remain `.planning`, the Camp to remain unarchived, or the work to
remain attempt-zero/version-one after legitimate execution progress. It checks
all of these against the incoming command and one another, except incoming
trace which is intentionally ignored on replay:

- one planning work with the exact key, kind, aggregate type, max-attempt
  convention, canonical input bytes/hash, Camp, and persisted first trace;
- one Mission and one Squad linked by `work.aggregateId == mission.id` and
  `mission.squadId == squad.id`;
- Squad Camp, ordered member list `[companionId]`, workspace, and Mission goal,
  budget/autonomy match the canonical persisted start identity;
- candidate is `.converted`, links that Mission, and retains the command's
  ingestion/Camp/type identity;
- the exact ingestion source link and note still identify the command's source
  note and Camp;
- exactly one canonical `missionCreated`, one `planStarted`, and one
  `actionCandidateConverted`; the converted payload identifies the candidate
  and ingestion. Exactly-one applies only to those three start-event kinds;
  valid later retry, terminal, card, run, usage, or other domain events are
  allowed and are not included in a total-event-count equality.

Any same-key payload, candidate link, source graph, Mission/Squad/work, input
hash, or one of the three start-event mismatches throws
`DurableWorkReplayConflictError`. A changed incoming trace alone is never a
conflict; goal, source draft identity, cow, workspace, budget, autonomy,
profile/model, or any other canonical command change under the same key is a
conflict. The validator never
repairs, relinks, inserts an event, or chooses another Mission. Concurrent
callers therefore return one Mission/work or one explicit conflict, never two
Missions and never an unlinked Mission. Replay in every state is zero mutation
and preserves persisted trace/timestamps/state/attempt/version. Terminal replay
also performs zero provider resolution, start-event emission, tick, and kick.

## 7. Remove all bypasses; preserve other routes

Delete `MissionDraftFactory.existingMissionId`, public `linkConverted`, and the
legacy public `convert` implementation. Migrate their existing tests to the
new command; do not retain private/package variants capable of creating or
linking a Mission outside the atomic ledger owner. `MissionDraftFactory.draft`
remains the read-only source identity builder.

The Adapter synchronously loads that core draft and captures it with runtime,
key, and trace before its first `await`; after composing the UI goal it calls
only Coordinator `startCandidate`. It must never call Orchestrator or
AppDatabase directly. Manual/proposal/schedule semantics and all accepted
A1a/A1b/A2 behavior remain byte-for-byte or behaviorally unchanged as their
allowlisted shared files require.

## 8. Failure-first tests and source sentinels

Before product implementation, add and run these exact tests as capability
failures, preserving output in `red-tests.log`:

- `candidateConversionRollsBackWhenWorkInsertFails`
- `candidateConversionReplayReturnsOneMission`
- `candidateConversionNeverLeavesUnlinkedMission`
- `candidateWithWrongCampCowFailsBeforeWrites`

The four canonical test functions contain the following deterministic case
tables; no case may be omitted or replaced by a loose aggregate assertion:

- `candidateConversionReplayReturnsOneMission` iterates all six work states.
  Each row uses a fresh incoming trace, keeps the immutable start graph intact,
  permits unrelated later events, and proves the original Mission/work,
  first trace, timestamps, state, attempt, and version are unchanged;
  resolver=0, DB mutations=0, new start events=0. `.queued` and
  `.retryScheduled` assert one conditional dispatch wake only after current
  work + durable-running revalidation; `.running` and all three terminal states
  assert tick=0/kick=0. The same table changes each canonical command field
  under the same key (excluding trace) and requires
  `DurableWorkReplayConflictError`, resolver=0, writes/events/tick/kick=0.
- That replay test also deterministically pauses after absent provider
  preflight, commits a concurrent winner, then removes or changes the profile
  before releasing the first caller. The first caller must revalidate durable
  running, replay the winner before the absent-profile fence, preserve the
  winner's first trace/timestamps/version, and add zero rows/start events;
  resolver counts prove only the original absent preflight ran and no replay
  resolution occurred.
- `candidateConversionRollsBackWhenWorkInsertFails` retains the injected
  work-insert rollback and adds: resolver/preflight failure; durable halt
  between successful preflight and write; exact profile deletion; and profile
  kind/CLI drift between read snapshot and write. Every row asserts exact
  resolver count, zero Squad/Mission/work/candidate mutation/start events,
  accepted/unlinked candidate, tick=0, and kick=0. The halt row also proves a
  concurrent winner cannot replay across the durable halt fence.
- `candidateConversionNeverLeavesUnlinkedMission` races two absent callers and
  proves one complete candidate/Mission/Squad/work/three-start-event graph,
  one first trace, one insert disposition plus one replay disposition, no
  orphan, and dispatch counts consistent with current queued-state
  revalidation.
- `candidateWithWrongCampCowFailsBeforeWrites` covers both mismatched and nil
  `companion.campId`, with exact resolver, row/event, tick, and kick counts and
  zero writes after the profile/provider fences.

All count assertions distinguish DB reads from mutations: replay and rejection
may perform the specified fence/current-state reads, but perform zero DB
mutation. Start-event counts filter only `missionCreated`, `planStarted`, and
`actionCandidateConverted`; later event kinds remain allowed.

Add fail-closed source sentinels in the allowlisted tests proving:

- Coordinator candidate source contains one call to
  `convertCandidateAndEnqueuePlanning` and no `existingMissionId`,
  `startMission`, or `linkConverted` call;
- Adapter captures before its first `await` and delegates only to Coordinator;
- no callable `MissionDraftFactory` conversion/link bypass remains;
- no atomic method invokes public `enqueueMissionPlanning` from inside its
  write transaction;
- `Package.swift`, `EventKind.swift`, migrations, RunTests, matrix scripts, and
  files outside the nine-file allowlist have no A3 delta.

## 9. Verification, reporting, review, and acceptance

Implementation order is fixed:

1. record entry status/baselines and add only the four failure-first tests and
   source sentinels;
2. run the authoritative suite once for the red phase and confirm failures are
   limited to the four missing A3 capabilities; otherwise stop;
3. implement the DTO/call chain/replay-first atomic owner and remove bypasses;
4. run `swift run RunTests > verify.log 2>&1` and require every test green;
5. run `swift build --product AgentLoopApp > build.log 2>&1` and require exit 0;
6. write `impl-report.md` with exact changed files, red/final results,
   transaction/replay/source-sentinel evidence, and deviations (expected none);
7. a responsibility-isolated implementation reviewer writes
   `reviews/02-p1-a3-implementation-review.md`; any P0/P1 blocks acceptance;
8. only after Review02 is `APPROVED — 0 P0 / 0 P1` may an independent owner
   write `acceptance.md`. `ACCEPTED` closes R-03 and opens only P1-A4.

Any red final test, build failure, silent fallback, row/event count mismatch,
out-of-scope delta, unresolved review finding, or missing evidence blocks A3
and A4. Do not retry by weakening assertions or patching evidence.

## 10. Open Questions

None.
