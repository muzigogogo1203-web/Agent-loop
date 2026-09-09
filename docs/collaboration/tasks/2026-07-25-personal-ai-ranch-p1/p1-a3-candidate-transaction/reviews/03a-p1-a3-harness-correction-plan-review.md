# P1-A3 Responsibility-Isolated Harness Correction Plan Review03A

> Date: 2026-08-10
>
> Reviewer: fresh responsibility-isolated Revision03 plan reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author the A3 leaf, Revision02 implementation, the
Revision03 plan, tests, logs, sample, or report. The review was read-only except
for this exact file. It did not run tests, builds, release gates, scripts, an
App, or UI and did not modify product, test, plan, manifest, evidence, or prior
review bytes.

The review checked the accepted A3 leaf, immutable Review02 findings, approved
Revision02B/02C boundaries, `plan-revision-03.md`, the current A3 helpers and
four canonical tests in `DurablePlanningTests.swift`, the partial
`revision02-verify.log`, and `revision02-hang-sample.txt`. This approval opens
only the bounded Revision03 failure-first test-harness correction. It is not A3
acceptance and does not open A4.

## 2. Root-cause audit

The Revision02 full run is correctly classified `HARNESS_REJECTED`. All four
canonical A3 tests started, none has a pass record, and the log has no terminal
test-run summary. The process sample repeatedly places a default-QoS
cooperative-executor thread in
`candidateConversionNeverLeavesUnlinkedMission -> a3Convert ->
R01PlanningResolver -> A3ResolveBarrier.enterAndWait`, while the runner also
has other cooperative tasks synchronously occupied. Therefore the green gate
cannot be inferred from the partial log, and adding or changing product code
would not address the observed failure.

Revision03 removes the starvation mechanism at its ownership boundary:

- all target-one A3 interleavings become finite synchronous mutations inside
  the already reviewed post-read/pre-writer `onResolve` point, with no wait for
  an async release;
- the only test that must hold two genuinely absent database callers uses
  exactly two dedicated Foundation threads, a target-two rendezvous released
  by the second dedicated thread, peer-abort broadcasting, indexed results,
  and one checked continuation awaited by the async test;
- the two-Orchestrator runtime row removes its synchronous resolver barrier
  and suspends only at the existing actor/checked-continuation
  `A3ObservationBarrier`, before either real tick or kick.

No synchronous A3 resolver wait remains on a Swift cooperative task. The
dedicated-thread helper's abort and two-completion requirements fail closed
rather than leaking one waiter when its peer errors. If any remaining run
still hangs, the plan requires a new sample and rejected artifact rather than
calling it green.

## 3. Evidence-preservation audit

The correction does not weaken the accepted A3 contract:

- the direct atomicity row still forces two absent preflights and retains exact
  one-insert/one-replay, shared-ID, first-trace, complete-graph, and three-event
  assertions;
- the combined winner-then-halt and winner-then-profile-drift rows retain the
  durable-gate/profile-fence ordering, resolver counts, writer baseline, exact
  winner graph, zero replay writes, and zero or pending runtime observations;
- the direct owner winner-before-profile-fence row remains one insert plus one
  replay without an async scheduling dependency;
- the real two-Orchestrator row still proves one complete graph and exact
  command-level `ensureTick=2`, `planningStarted=1`, `kick=2`. Allowing the
  replaying resolver to be zero or one reflects the two legal initial-read
  orderings; it does not relax database atomicity because the dedicated-thread
  row separately forces both preflights absent;
- the DEBUG observer remains actor/checked-continuation based, release-sealed,
  and adjacent to the real operations. Existing complete snapshots,
  `totalChangesCount`, 206-entry manifest, exact frozen-byte sentinels,
  call-chain guards, release/debug symbol direction, and 657-test count remain
  mandatory.

The source-sentinel-first red is appropriately bounded: it must be one selected
test failing on the current unsafe A3 harness shape, after which each canonical
test is run alone before the unfiltered authoritative suite. Unsupported
filtering, compilation drift, another test, timeout, partial output, or an
unknown diagnostic stops the gate.

## 4. Scope and execution-gate audit

Only `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` may change.
`Orchestrator.swift` and all other Core, App, test, package, runner, matrix,
schema, and migration bytes remain frozen. Revision03 adds no product seam,
public/package API, dependency or target edge, production branch, UI, or data
operation. The fresh allowlist/entry comparison, no-symlink check,
`git diff --check`, authoritative full test, App/debug/release builds, symbol
gate, report, implementation rereview, and independent acceptance remain
required in that order.

No ambiguity requiring a product decision or wider file scope was found.

## 5. Findings and verdict

- P0: 0
- P1: 0
- P2: 0

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

This approval authorizes only Revision03's test-sentinel red and the reviewed
one-file harness correction. Any Core/product change, new synchronous A3 wait
on a cooperative task, lost canonical assertion, failed/unknown gate, or
out-of-scope delta stops implementation. A3 remains unaccepted and A4 remains
closed until the fresh implementation rereview and independent acceptance
both pass.
