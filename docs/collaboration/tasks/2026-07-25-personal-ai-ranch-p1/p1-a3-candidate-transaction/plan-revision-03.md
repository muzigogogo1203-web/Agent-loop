# P1-A3 Test-Harness Correction Plan — Revision 03

> Status: **PLANNING ONLY — responsibility-isolated plan review required**
>
> Date: 2026-08-10
>
> Scope: one test file; all Core/product bytes remain frozen

## 1. Why Revision03 exists

The Revision02 unfiltered 657-test rerun is permanently classified
**HARNESS_REJECTED**, not green and not a product failure. Its
`revision02-verify.log` has no terminal test-run summary or canonical A3 pass.
The immutable `revision02-hang-sample.txt` places a cooperative-executor thread
inside `A3ResolveBarrier.enterAndWait()` from the resolver callback in
`candidateConversionNeverLeavesUnlinkedMission` (entry source line 3053),
while the async release-side continuation cannot obtain an executor thread.

The root cause is the test harness: synchronous `NSCondition.wait()` barriers
were entered from `Task`/`Task.detached` cooperative-executor work. The product
does not need a new seam. The existing async `A3ObservationBarrier` is safe: it
suspends with checked continuations and must remain the post-commit observation
mechanism.

The rejected verify log and sample remain immutable historical evidence. The
existing Revision02 build/release logs remain useful facts, but cannot satisfy
Revision03 because the authoritative full run never completed.

## 2. Exact scope and red lines

The only source file that may change is:

- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`.

`Sources/AgentLoopCore/Kernel/Orchestrator.swift` is frozen at the current
Revision02 implementation bytes. Every other Core, App, test, package,
dependency-lock, runner, matrix, schema, and migration file is also frozen.
The existing 206-entry manifest and the Revision02 exact-byte source sentinel
remain authoritative and must pass unchanged.

Revision03 may create only its plan/reviews and these task-local evidence
files: `revision03-red-tests.log`, `revision03-green-tests.log`,
`revision03-verify.log`, `revision03-build.log`, `revision03-release.log`, and
the Revision03 append-only section of `impl-report.md`.

There is no public/package API, product behavior, observer seam, schema,
migration, dependency, target edge, runner, matrix-script, UI, or App change.
No hash echo or user-confirmation roundtrip is required. Any need to change
Core/product bytes stops this correction as out of scope.

## 3. Exact test-only correction

### 3.1 Remove the unsafe cooperative-executor barrier

Delete `A3ResolveBarrier` and all five current A3 uses. No synchronous wait may
remain directly inside an A3 `onResolve` closure launched by `Task` or
`Task.detached`. Remove the two `Task.detached` conversions from the direct
two-caller row.

Do not change `R01PlanningResolver`, the production resolver protocol, or
`A3ObservationBarrier`. Non-A3 historical gates are outside this correction.

### 3.2 Deterministically inject the three single-loser interleavings

Replace each target-one resolver barrier with synchronous work performed in the
resolver's existing `onResolve` callback. This callback runs only after the
outer candidate read returned `.absent` and before the outer writer
transaction begins, so it is the exact deterministic interleaving point.

1. **Concurrent winner then halt priority**
   (`candidateConversionRollsBackWhenWorkInsertFails`): inside the loser
   resolver, commit the direct-database winner, transition durable mode to
   halted, then capture the winner result, complete graph, and writer baseline
   in the existing locked-box style. Let the same Orchestrator call continue
   directly. It must fail with the durable-not-running error before replaying
   the winner, with loser/winner resolver counts 1/1, zero runtime observation,
   zero writes after the captured baseline, and the winner graph unchanged.

2. **Concurrent winner then profile deletion/kind/CLI drift**
   (`candidateConversionReplayReturnsOneMission`): inside each loser resolver,
   commit the direct-database winner with its first trace, perform the selected
   profile mutation, and capture the full winner graph, writer baseline, and
   winner result. The outer Orchestrator call may use a `Task` only to pause at
   the existing async post-commit observer. At that pause it must prove replay
   precedes the profile fence, zero replay writes, exact winner preservation,
   resolver counts 1/1, and pending observations `ensureTick=1`,
   `planningStarted=0`, `kick=0`; after release require the replayed IDs and
   final counts 1/0/1.

3. **Direct owner winner-before-profile-fence row**
   (`candidateConversionNeverLeavesUnlinkedMission`): inject the direct winner
   and profile deletion from `onResolve`, store the winner, then let the outer
   synchronous database call continue without a task or barrier. Preserve its
   one-insert/one-replay, first-trace, exact IDs, graph, event, and resolver
   assertions.

All injected database mutations are finite synchronous operations executed
after the outer read connection has returned and before the outer writer has
started. They do not wait for an async continuation and therefore do not
recreate the starvation bug.

### 3.3 Preserve the true two-absent database race on dedicated threads

The direct atomicity row must remain a real two-caller/two-preflight race. Move
only these two synchronous `a3Convert` calls to an encapsulated private test
harness with the following fixed design:

- create exactly two Foundation `Thread` instances; do not use `Task`,
  `Task.detached`, a task group, or the cooperative executor for either call;
- use a private target-two `NSCondition` rendezvous only inside the two
  dedicated thread resolver callbacks. The second arrival releases both
  threads; no async task is responsible for release;
- add an abort state that broadcasts if either thread fails before or during
  rendezvous, so its peer cannot remain blocked;
- collect both indexed `Result<CandidatePlanningStartResult, Error>` values in
  a lock-protected completion object and resume exactly one checked
  continuation when both threads terminate. Completion-before-wait and
  wait-before-completion must both be supported;
- the async test task only awaits that checked continuation; it never blocks a
  cooperative thread. The helper returns only after both Foundation threads
  have finished and propagates an indexed failure without leaking a thread.

Keep the existing assertions: both resolvers are called exactly once, results
share IDs, dispositions are exactly one `.inserted` and one `.replayed`, the
single Candidate/Mission/Squad/work graph is fully linked, only one first trace
wins, and the three start events each occur once.

### 3.4 Replace the two-Orchestrator preflight barrier without weakening runtime evidence

For the DEBUG two-Orchestrator row, remove only the synchronous resolver
barrier. Launch both existing Orchestrator tasks normally against the shared
database and keep the shared async `A3ObservationBarrier(target: 2)`. Both calls
must pause after their database result and current-work/durable-mode reads but
before either real tick/kick.

The database race has two legal preflight orderings, so freeze these exact
resolver assertions instead of forcing an unsafe schedule:

- the resolver belonging to the eventual `.inserted` result is exactly 1;
- the resolver belonging to the eventual `.replayed` result is either 0
  (it observed the initial winner) or 1 (it observed absence and lost inside
  the write transaction);
- each resolver is at most 1 and their total is exactly 1 or 2.

At the observer boundary retain the exact single complete graph, equal
pre-dispatch snapshots, positive inserted writer delta, no attempts, no orphan,
and two pending `ensureTick` observations. The evidence resolver-count multiset
must be either `[0, 1]` or `[1, 1]`. After releasing the async barrier, require
shared IDs, exactly one inserted/one replayed result, and real command-level
runtime counts `ensureTick=2`, `planningStarted=1`, `kick=2`; then shut down
both Orchestrators.

This decomposition does not weaken the concurrency contract. Section 3.3
forces two genuinely absent preflights through the database linearization
window, while this row independently proves the real Orchestrator behavior for
every legal database-race ordering. The former synchronous barrier had coupled
those two evidence layers in a scheduler-dependent way.

### 3.5 Extend the existing source sentinel; add no test count

Extend `a3Revision02DebugObservationIsGuardedAndAdjacent` rather than adding a
new `@Test`. It must fail closed on all of the following:

- `A3ResolveBarrier` is absent;
- the four canonical A3 test bodies contain no direct synchronous resolver
  wait and `candidateConversionNeverLeavesUnlinkedMission` contains no
  `Task.detached`;
- the dedicated-thread race helper contains Foundation-thread start,
  target-two rendezvous, abort/broadcast, indexed completion, and checked-
  continuation tokens, and contains no Swift `Task` construction;
- the blocking rendezvous is private to that dedicated-thread helper and is
  not referenced from either Orchestrator task;
- `A3ObservationBarrier` remains actor/checked-continuation based and is the
  only A3 barrier used from cooperative tasks.

Keep all existing DEBUG adjacency, release sealing, manifest, call-chain, and
boundary assertions intact. Because an existing test is extended, the full
suite remains exactly 657 tests / 7 suites.

## 4. Failure-first and verification order

Implementation may start only after a responsibility-isolated Review03A gives
this plan 0 P0 / 0 P1. Then execute in this exact order:

1. **Fresh targeted red:** change only the existing source sentinel first and
   run
   `swift run RunTests --filter a3Revision02DebugObservationIsGuardedAndAdjacent`
   into `revision03-red-tests.log`. It must terminate nonzero with that one test
   failing only because the current unsafe A3 barrier/Task shape remains. Do
   not rerun the known-hanging unfiltered Revision02 bytes. Unsupported filter,
   another started test, compile failure, timeout, or another diagnostic stops.
2. Implement only sections 3.1–3.4 in `DurablePlanningTests.swift`.
3. **Targeted green:** rerun the source sentinel, then each of the four exact
   canonical A3 test names separately, appending complete output to
   `revision03-green-tests.log`. Each command must terminate successfully with
   exactly its selected test starting and passing once and no issue/error.
4. **Authoritative full green:** run unfiltered
   `swift run RunTests > revision03-verify.log 2>&1`. Require a terminal
   `657 tests / 7 suites` pass, one start and one pass for every canonical A3
   test, no hang/timeout/crash, and no failure or unknown output.
5. **Fresh build:** capture in `revision03-build.log` successful
   `swift build --product AgentLoopApp`, DEBUG `AgentLoopCore`, and DEBUG
   `AgentLoopTestSuite` builds.
6. **Fresh release:** capture in `revision03-release.log` successful
   `swift build -c release --target AgentLoopCore` and
   `swift build -c release --target AgentLoopTestSuite`, zero A3 observer-seam
   symbols in release Core objects, required seam symbols in DEBUG Core
   objects, and the existing DEBUG-region/source-direction checks.
7. Require the unchanged 206-entry manifest, all frozen Revision02 byte
   sentinels, the one-source-file Revision03 allowlist, no symlinks, and
   `git diff --check` to pass. A fresh comparison must prove Orchestrator and
   every other product/test/App source remained at Revision03 entry bytes.
8. Append exact red/green/full/build/release results and the immutable
   Revision02 `HARNESS_REJECTED` classification to `impl-report.md`.
9. Obtain a fresh responsibility-isolated implementation rereview with
   0 P0 / 0 P1 before A3 acceptance. A3 remains unaccepted and A4 remains
   closed until that rereview and the independent acceptance gate pass.

If any targeted or full run hangs, sample it before termination, preserve the
raw output as a new rejected harness artifact, and stop. A timeout, partial
pass list, successful build, or old Revision02 evidence is never a green test
result.

## 5. Completion gate

Revision03 is complete only when every synchronous A3 resolver rendezvous is
either eliminated through deterministic `onResolve` injection or confined to
the two dedicated Foundation threads; the direct two-absent race, all required
winner/halt/profile interleavings, complete graph/mutation assertions, and real
Orchestrator 2/1/2 observations remain intact; all fresh gates in section 4
pass; and the independent rereview reports 0 P0 / 0 P1.

## 6. Open questions

None. A test-only solution is sufficient; Core/product modification is neither
needed nor authorized.
