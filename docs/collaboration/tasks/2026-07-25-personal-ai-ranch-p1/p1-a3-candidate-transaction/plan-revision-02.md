# P1-A3 Bounded Correction Plan — Revision 02

> Status: **REVISION 02B — Review02B approval preserved; test-harness correction pending Review02C**
>
> Date: 2026-08-10
>
> Branch / entry HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Authority: accepted A3 Revision 01 leaf, approved Review01A, and immutable
> Review02 `CHANGES REQUIRED — 0 P0 / 3 P1 / 0 P2`

## 1. Purpose, entry, and stop conditions

Revision 01 product code has no known P0, but Review02 blocks acceptance on
three missing evidence gates: dynamic post-commit dispatch/event observation,
two exact concurrency interleavings plus a true mutation observer, and the
fail-closed source boundary. This revision closes only those three findings.

Immutable Review02A is `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2`. This bounded
Revision 02A changes only the impossible single-Supervisor two-preflight race
and the six missing frozen-file identities; it does not rewrite that verdict.

The substitute correction planner was responsibility-separated from the new
implementation. It reduced the correction to two files after a read-only
architecture and test-seam audit. No hash echo or user roundtrip is required.
Implementation may begin only after a fresh responsibility-isolated reviewer
writes `reviews/02b-p1-a3-correction-plan-review.md` with
`APPROVED — 0 P0 / 0 P1`. Any ambiguity, unknown failure, out-of-scope delta,
or non-empty Open Questions stops the correction and keeps A3 acceptance and
A4 closed.

This revision grants no commit, push, merge, release, destructive or normal
user-data operation, payment, external communication, or real-user action.

## 2. Exact correction scope

Only these two product/test files may change:

1. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
2. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`

Entry identities are:

- `Orchestrator.swift`:
  `de215a23674fd724491459de319f84d18f8a62d96bd390c46769127e6fd8a9d0`;
- `DurablePlanningTests.swift`:
  `0988714b01dd3c82fe6c10de11b50d813a2798647ac66ec4c14f6a69b4a18b47`.

Task artifacts may additionally be created or updated only in this A3 task
directory: this plan, its review/re-review artifacts, the entry source
manifest, `revision02-red-tests-harness-rejected.log`,
`revision02-red-tests.log`, `revision02-verify.log`,
`revision02-build.log`, `revision02-release.log`, `impl-report.md`, and
`acceptance.md`.

The existing transaction/replay implementation in
`MissionDraftFactory.swift`, `DurableWork.swift`,
`DurableWorkSupervisor.swift`, `DurableWorkStore.swift`,
`AppDatabase.swift`, `CodingRanchStoreAdapter.swift`, and
`CodingRanchTests.swift` is frozen for this correction. There is no schema,
migration, EventKind, Package, target/dependency, RunTests, matrix-script,
public API, production package API, provider, UI, AppStore, or normal-data
change.

## 3. DEBUG-only post-commit observation seam

### 3.1 Closed observation type and single arm

Add one matching-`#if DEBUG` package-test-only observation surface in
`Orchestrator.swift`:

```swift
#if DEBUG
package enum A3CandidatePostCommitObservationForTesting:
    Sendable, Equatable
{
    case ensureTick
    case planningStarted
    case kick
}
#endif
```

The Orchestrator stores at most one armed, nonthrowing async observer:

```swift
(@Sendable (A3CandidatePostCommitObservationForTesting) async -> Void)?
```

Expose package-test-only `arm...ForTesting` and `clear...ForTesting` actor
methods under the same DEBUG guard. Arming while already armed fails fast with
an existing invalid-state error. The observer must never replace, suppress,
duplicate, catch, or alter the production action; it only records and may
suspend immediately before that action so tests can inspect the committed
pre-dispatch boundary. Outside an explicitly armed DEBUG test it is nil.

No new protocol, initializer parameter, production branch, fallback, default
success, or release symbol is allowed.

### 3.2 Exactly three call sites

In the existing candidate queued/retry branch, insert exactly these three
matching-DEBUG observations immediately before their real operations:

```text
observe ensureTick      -> ensureTickStarted()
if inserted:
  observe planningStarted -> emit(.planningStarted(...))
observe kick            -> try await planningSupervisor.kick()
```

There is no observation in running/succeeded/failed/canceled, before the
database command commits, after a database/actor gate error, or on any manual,
proposal, schedule, rumination, generic-work, or card path.

The existing post-database order remains frozen:

```text
database result
  -> current work read
  -> durable mode read
  -> aggregate identity validation
  -> process + durable running validation
  -> work-state switch
  -> three observed real operations above
```

The async observation is a test-only pause, not a second production
revalidation or execution owner. Tests do not mutate durable/work state while
paused at this boundary.

### 3.3 Release and anti-fake gates

The tests must source-check that:

- enum, storage, arm, clear, helper, and all three callers are inside matching
  DEBUG regions;
- the candidate function contains exactly one real `ensureTickStarted()`, one
  real candidate `emit(.planningStarted(...))`, and one real
  `planningSupervisor.kick()` in the reviewed branch;
- each observation immediately precedes its corresponding real action;
- the observer is not invoked from another function and cannot throw or return
  a substitute result.

Release `AgentLoopCore` object symbols contain zero A3 seam tokens. DEBUG Core
objects contain the seam. Release `AgentLoopTestSuite` must compile with all
seam-only helpers/calls behind matching DEBUG guards.

## 4. True write observer and complete graph snapshot

Add a test helper that reads GRDB `Database.totalChangesCount` from the
DatabasePool's serialized writer connection. Baselines are taken only after
all scenario setup writes and while no planning pump is active. The exact
delta rules are:

- replay and every validation/conflict/rejection path: `delta == 0`;
- the injected work-insert rollback: writer total changes must increase,
  proving the partial write path was entered, while the complete persisted
  business graph remains byte-for-byte equal because the transaction rolled
  back;
- a legitimate inserted transaction has a positive delta and exact expected
  graph; later dispatch mutations are outside the pre-dispatch zero-mutation
  checkpoint.

This observer is distinct from row reads and catches same-value updates and
write-then-rollback attempts. Scenario-owned profile or durable-control setup
writes occur before the corresponding baseline; they are never mislabeled as
candidate business writes.

Extend `A3BusinessSnapshot` with the durable-attempt count and every field
needed to compare the complete Candidate, Mission, Squad, work, row counts,
all events, first trace, timestamps, state, attempt, and version. For a queued
replay that is allowed to wake work, compare the complete snapshot and writer
counter while the DEBUG observer is paused at `.ensureTick`, before the real
tick/kick. Dispatch after that checkpoint is deliberately not called a replay
transaction mutation.

## 5. Exact canonical test closure

Keep the same four canonical test names. They become async where needed. Direct
AppDatabase calls may remain only to seed an initial winner, advance a fixture
to a durable state, or commit the independent concurrent winner. Every
post-commit dispatch/event assertion must enter through the real Orchestrator;
call-chain source sentinels continue to prove the Adapter and Coordinator
owners.

### 5.1 `candidateConversionRollsBackWhenWorkInsertFails`

Cover all existing rows plus the missing combined race. Each Orchestrator
failure has zero observations and no in-memory start event/tick/kick:

1. injected work insert failure: positive writer-attempt delta, but exact
   persisted graph rollback;
2. provider preflight failure: writer delta 0;
3. durable halt after preflight: pause after the scenario-owned halt write,
   baseline, release, durable-not-running error, writer delta 0;
4. profile deletion, non-CLI kind drift, and CLI drift after preflight: pause
   after the scenario-owned profile write, baseline, release, invalid-state
   error, writer delta 0;
5. existing winner followed by durable halt: replay cannot cross the initial
   durable gate, resolver 0, writer delta 0;
6. exact missing interleaving:

```text
Orchestrator loser reads absence and pauses in provider preflight
  -> direct-DB concurrent winner commits one complete graph
  -> durable mode changes to halted
  -> capture winner graph + writer baseline
  -> release loser
  -> loser write transaction fails durable-not-running before winner replay
```

Row 6 requires loser resolver exactly 1, no later resolver call, zero
observation, writer delta 0 after the halt baseline, and the winner graph
unchanged.

### 5.2 `candidateConversionReplayReturnsOneMission`

For queued, running, retry-scheduled, succeeded, failed, and canceled:

- direct replay with a fresh incoming trace returns the original IDs, performs
  zero provider preflight and writer mutations, adds no start event, and
  preserves the complete graph and first trace/timestamps/state/attempt/version;
- every canonical same-key conflict except trace throws
  `DurableWorkReplayConflictError`, with resolver 0, writer delta 0, complete
  graph unchanged, and zero runtime observations;
- an Orchestrator replay dynamically proves:
  - queued/retry: exactly one `ensureTick`, zero `planningStarted`, and one
    `kick`, with the complete zero-mutation snapshot captured while paused
    before the real dispatch;
  - running and all terminal states: zero observations and writer delta 0.

Add the concurrent-winner/profile-fence table for profile deletion, non-CLI
kind drift, and CLI drift:

```text
Orchestrator loser reads absence and pauses in its only preflight
  -> direct-DB winner commits with its first trace
  -> mutate/delete current profile
  -> capture complete winner graph, all resolver counts, and writer baseline
  -> release loser
  -> loser replays winner before the absent-profile fence
  -> pause loser at observed ensureTick before dispatch
```

At the pause, require byte-for-byte work trace/timestamps/state/attempt/version,
Candidate/Mission/Squad/event/attempt/row counts, writer delta 0, loser resolver
1, winner resolver 1, no replay preflight, and observations consisting only of
the pending `ensureTick`. After release, require replayed IDs and final runtime
counts `ensureTick=1`, `planningStarted=0`, `kick=1`.

### 5.3 `candidateConversionNeverLeavesUnlinkedMission`

Run the two absent callers through two independently recovered Orchestrator /
DurableWorkSupervisor instances that share the same `AppDatabase`. A single
Supervisor cannot be used: candidate conversion is a synchronous Supervisor
actor method, so blocking its first resolver would prevent the second call
from entering and deadlock the preflight barrier. Each Orchestrator uses its
own resolver and observer, and both provider preflights meet at the existing
two-party barrier.

After the database race returns one insert and one replay, the two DEBUG
observers feed one shared test probe. That probe holds both calls at
`.ensureTick`, after each Orchestrator has independently re-read the current
queued work and durable-running mode but before either kick.

At that boundary require one Candidate/Mission/Squad/work/three-start-event
graph, one first trace, no orphan, one inserted and one replay result pending,
and exactly two preflight resolver calls. After release, require the same IDs,
one `.inserted` plus one `.replayed`, and runtime counts:

```text
ensureTick = 2
planningStarted = 1
kick = 2
```

The two independent Supervisor pumps may race after release; this test counts
the two command-level wake invocations required by Revision 01, not two
provider executions. Both Orchestrators are shut down at the end of the row.

### 5.4 `candidateWithWrongCampCowFailsBeforeWrites`

Both mismatched and nil `companion.campId` cases run through a recovered
Orchestrator. Each resolves the absent provider exactly once, then fails before
IDs/writes with writer delta 0, exact graph unchanged, and zero runtime
observations.

## 6. Fail-closed source boundary

The immutable Revision02 entry manifest is
`revision02-entry-source-manifest.sha256`, with exactly 206 sorted unique
regular-file entries: every file under `Sources/` outside the original nine
A3 files, plus `Package.swift`, `Package.resolved`, and the P1 matrix script.
Its identity is
`3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`.

Review02 already independently established that the current boundary contains
only the expected A3 source changes plus the accepted predecessor
`ShellToolTests.swift` delta. The Revision02 test sentinel now locks that
adjudicated boundary. It must:

- verify the manifest identity, exact 206 count, sorted order, unique paths,
  regular-file/no-symlink shape, and exact equality with a fresh enumeration;
- hash every manifest entry and require exact current-byte equality;
- reject any new, deleted, renamed, symlinked, or changed outside-nine source,
  test, App, package, dependency-lock, runner, or matrix file.

Independently pin these six exact entry bytes inside the allowlisted test:

| Boundary | SHA-256 |
|---|---|
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

The full `AppDatabase.swift` identity is the migration/DDL sentinel. No prose
hash table substitutes for the executable manifest gate.

Because the 206-entry manifest deliberately excludes all nine original A3
files, also pin the other six Revision02-frozen original A3 files (the seventh,
`AppDatabase.swift`, is already pinned above):

| Revision02-frozen file | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Product/MissionDraftFactory.swift` | `f33e53d3d795cd913f722d1c5e3f71f5800b97083a9101db27514bcc566d0e26` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `49b61c58c07886904fdb16a1a4076081789749645459696f412e85ac672785ee` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `cf6ece2fdd22842d093ea51b461e10bc4d1099360400d9ff254b0e457ff19d39` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `4f2ab03002fbb113784e9586fc20a17bdd580b18aa954432562fbf0d5c728fa9` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `42ccc982acee797a3f53e754763b606a51e46944cc38cdfc97278f631c4589d0` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `38d20527135ace5035fc387daeead71f66a5798e4d4c090d9bb16cc03491b192` |

The executable sentinel therefore partitions the correction exactly: 206
outside-nine files plus these seven frozen original-A3 files must remain at
entry bytes; only `Orchestrator.swift` and `DurablePlanningTests.swift` may
change.

## 7. Failure-first, verification, and evidence order

1. Freeze this plan, manifest, Review02, and the two correction entry files.
2. Obtain responsibility-isolated Review02B with 0 P0 / 0 P1.
3. Change only `DurablePlanningTests.swift`; run authoritative
   `swift run RunTests > revision02-red-tests.log 2>&1`. It must fail only on
   the missing reviewed DEBUG observation capability. The first attempted run
   is immutably classified `HARNESS_REJECTED`: besides the expected missing
   seam it found test-only missing-`await` actor calls and their derivative
   type-context errors. Its raw output is preserved in
   `revision02-red-tests-harness-rejected.log`; it grants no product
   implementation gate. After Review02C, correct only those test-harness
   compile errors, rerun the same authoritative red command to a fresh
   `revision02-red-tests.log`, and require that clean red to contain only the
   reviewed missing seam/type/method capability. Any remaining unrelated
   compile, discovery, fixture, or product failure stops again.
4. Add only the reviewed Orchestrator DEBUG seam.
5. Run `swift run RunTests > revision02-verify.log 2>&1`; every test must pass,
   with one start and one pass for each canonical A3 test.
6. Run and preserve in `revision02-build.log`:
   - `swift build --product AgentLoopApp`;
   - DEBUG Core/TestSuite build sufficient for object inspection.
7. Run and preserve in `revision02-release.log`:
   - `swift build -c release --target AgentLoopCore`;
   - `swift build -c release --target AgentLoopTestSuite`;
   - release Core object scan: zero A3 seam symbols;
   - DEBUG Core object scan: required A3 seam symbols present;
   - matching DEBUG-region and source-order/occurrence gates.
8. Require the 206-entry manifest, six exact-byte sentinels, two-file
   correction allowlist, no-symlink gate, and `git diff --check` to pass.
9. Append a Revision02 section to `impl-report.md` with exact changed files,
   red/final/build/release results, every Review02 finding closure, manifest
   result, and deviations (expected none).
10. A fresh responsibility-isolated reviewer writes
    `reviews/03-p1-a3-implementation-rereview.md`. Any P0/P1 blocks acceptance.
11. Only after Review03 is `APPROVED — 0 P0 / 0 P1` may a fresh independent
    owner write `acceptance.md`, close R-03, and open only A4.

## 8. Completion gate and red lines

A3 Revision02 is complete only when all exact canonical dynamic matrices,
writer-mutation gates, combined races, source manifest, authoritative full
suite, App build, release Core/TestSuite builds, symbol/source guards, scope
gate, Review03, and independent acceptance pass.

The following fail closed immediately:

- a changed transaction/replay implementation outside the two files;
- a seam available in release, callable outside DEBUG tests, or capable of
  replacing a production action;
- a runtime count inferred only from source tokens;
- a zero-write claim based only on equal final row values;
- a queued/retry snapshot taken after real kick/provider dispatch;
- an omitted profile-drift or halt/winner interleaving;
- manifest count/path/hash/symlink drift;
- any final test/build/symbol failure or unknown output;
- any attempt to accept A3 or start A4 before Review03 and acceptance.

## 9. Open Questions

None.
