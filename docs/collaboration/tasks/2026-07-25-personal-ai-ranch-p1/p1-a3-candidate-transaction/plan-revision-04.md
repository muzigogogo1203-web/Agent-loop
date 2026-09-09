# P1-A3 Bounded Harness/Evidence Correction — Revision 04

> Status: **PLANNING ONLY — responsibility-isolated plan review required**
>
> Date: 2026-08-10
>
> Authority: immutable Review03 `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2`

## 1. Purpose and exact scope

Revision04 closes only Review03's two P1 findings: the dedicated worker pair
can resume before both Foundation threads are finished, and the current
authoritative 657-test output is not stored in the task's required
`verify.log`.

Authorized changes are limited to:

- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`;
- task-local Revision04 red/green/verify/build/release evidence and reviews;
- promotion of the fresh authoritative run to the task's exact `verify.log`;
- an append-only Revision04 section in `impl-report.md`.

All Core/product/App bytes, every other test, Package files, dependencies,
runner, matrix script, schema, migration, prior plan/review, and prior evidence
are frozen. The Revision03 interleavings, complete-graph/mutation assertions,
two-Orchestrator 2/1/2 observation contract, and 657-test count must not be
weakened. No hashes or user-confirmation roundtrip are required. Any product or
Core change stops this correction.

## 2. Fixed dedicated-thread completion design

Keep the target-two `NSCondition` rendezvous and exactly two named Foundation
worker `Thread` instances. Replace the current worker-driven completion with
this exact ownership model:

1. Each worker performs its indexed synchronous candidate operation. On
   failure it records the aborting index and broadcasts so its rendezvous peer
   cannot remain blocked. It then stores exactly one indexed outcome. A worker
   must not validate the pair, inspect thread completion, install/resume a
   continuation, or dispatch completion work.
2. Retain both named worker handles. Construct and start exactly those two
   Foundation threads—no third Foundation thread and no cooperative `Task`,
   `Task.detached`, or task group.
3. A private serial `DispatchQueue` is the sole completion coordinator. After
   both workers are started, it waits until **both named handles** report
   `isFinished == true`. Waiting/polling occurs only on that dedicated GCD
   queue, never on the cooperative executor.
4. Only after both `isFinished` checks pass, the coordinator locks the state,
   validates that indexed outcomes 0 and 1 each exist exactly once, snapshots
   them in index order, and unlocks. Missing/duplicate outcomes fail loudly as
   an explicit harness error; they may not become default results.
5. Only that post-finish coordinator path resumes the single checked
   continuation, exactly once. The async test returns only from this
   continuation and validates/unwraps the two indexed outcomes as before.

The normal rendezvous still releases only when `arrivedIndices.count == 2` and
broadcasts to both workers. Every pre-rendezvous/peer failure still records an
abort and broadcasts. Completion-before-wait and wait-before-completion remain
safe, but neither may bypass the two `isFinished` checks.

## 3. Fail-closed sentinel revision

Extend the existing
`a3Revision02DebugObservationIsGuardedAndAdjacent` test; add no new `@Test`.
Its source checks must prove all of the following:

- target-two rendezvous is real: exactly two indexed `rendezvous` calls,
  `arrivedIndices.count == 2`, normal broadcast, abort recording, and abort
  broadcast;
- exactly two Foundation `Thread` constructions, two exact names, and two
  `.start()` calls exist in the dedicated helper;
- the private dedicated `DispatchQueue` completion coordinator checks
  `firstThread.isFinished` and `secondThread.isFinished` before outcome-pair
  validation and before the sole continuation `resume`;
- worker closures contain operation/rendezvous, abort, and indexed-outcome
  storage only; no continuation resume or completion coordination;
- the state/completion helper contains no path that resumes a continuation;
- the dedicated helper/coordinator contains no cooperative `Task`,
  `Task.detached`, task group, or third Foundation thread;
- the blocking rendezvous and dedicated state are confined to the direct
  database race helper and are absent from both Orchestrator tasks and the
  other canonical paths;
- the existing async actor `A3ObservationBarrier`, DEBUG observer adjacency,
  release sealing, manifest, and source-boundary assertions remain intact.

The sentinel must check structure/order and occurrence counts, not merely the
presence of unused token-bearing declarations.

## 4. Evidence order and gates

Implementation starts only after a responsibility-isolated Revision04 plan
review returns 0 P0 / 0 P1. Then execute in order:

1. **Targeted red:** first change only the sentinel and run its exact filter to
   `revision04-red-tests.log`. It must start only that test and fail only on the
   current missing post-`isFinished` coordinator/weak sentinel shape.
2. Implement only sections 2–3 in `DurablePlanningTests.swift`.
3. **Targeted green:** run the sentinel and each of the four canonical A3 tests
   separately into `revision04-green-tests.log`. Each selection must start and
   pass exactly once with no issue, crash, timeout, or unknown output.
4. Before replacing the stale standard evidence, preserve its historical
   655-test bytes as `revision04-predecessor-verify.log` and verify byte equality
   with the then-current `verify.log`.
5. **Authoritative full green:** run fresh unfiltered
   `swift run RunTests` with its complete stdout/stderr written **directly** to
   the task's exact `verify.log`. Require the terminal 657 tests / 7 suites
   pass, one start and one pass for the sentinel and every canonical A3 test,
   and no failure/hang/timeout/crash. A copied old run or partial output is not
   acceptable.
6. Only after validating that direct run, mirror its exact bytes to
   `revision04-verify.log` and require byte-for-byte equality. The report must
   name `verify.log` as the current authoritative gate and the versioned mirror
   only as the same-run archival copy.
7. Capture fresh successful App, DEBUG Core, and DEBUG TestSuite builds in
   `revision04-build.log`. Capture fresh release Core/TestSuite builds, zero A3
   seam symbols in release Core, required symbols in DEBUG Core, and existing
   source/symbol direction gates in `revision04-release.log`.
8. Require the unchanged 206-entry manifest, all frozen byte sentinels, the
   one-source-file Revision04 allowlist, no symlinks, and `git diff --check`.
   Prove every product/Core byte remains unchanged.
9. Append the exact correction and evidence results to `impl-report.md`,
   explicitly correcting Revision03's premature “both threads terminated”
   claim. Then obtain a fresh responsibility-isolated implementation rereview
   with 0 P0 / 0 P1 before independent A3 acceptance.

Any unexpected red, nonterminal targeted/full run, missing worker finish,
outcome mismatch, evidence-copy mismatch, build/symbol/scope failure, or need
to widen source scope stops. It does not permit a fallback or product patch.

## 5. Completion

Revision04 is complete only when both Review03 P1 findings are dynamically and
fail-closedly closed, `verify.log` itself contains the fresh terminal 657/657
run, its Revision04 mirror matches, every build/release/scope gate passes, and
the independent rereview reports 0 P0 / 0 P1. Until then A3 remains unaccepted,
R-03 remains open, and A4 remains closed.

Open questions: none.
