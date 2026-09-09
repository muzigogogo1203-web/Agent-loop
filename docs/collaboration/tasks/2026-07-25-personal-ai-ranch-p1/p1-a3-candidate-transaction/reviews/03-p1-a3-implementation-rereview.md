# P1-A3 Responsibility-Isolated Implementation Re-Review 03

> Date: 2026-08-10
>
> Reviewer: fresh responsibility-isolated A3 implementation rereviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author the A3 leaf, Revision02/03 plans, implementation,
tests, evidence, or implementer report. The review was read-only except for
this exact file. It did not rerun tests or builds and did not modify product,
test, plan, manifest, evidence, or report bytes.

The review read the accepted A3 leaf, immutable Review02, approved Review02B
and Review02C, approved Revision03 plan and Review03A, current A3 product/test
bytes, the Revision02 rejected logs and process sample, every Revision03
red/green/full/build/release log, the 206-entry manifest, and
`impl-report.md`. This review is not acceptance, does not close R-03, and does
not open A4.

## 2. Independently confirmed evidence

The main implementation and most correction evidence are real:

- the candidate start path has one atomic database owner, replay-first winner
  validation, durable/profile fences, and no legacy conversion/link bypass;
- the Revision02 hang sample places the unsafe synchronous A3 resolver barrier
  on a cooperative-executor thread. Current A3 code removes that barrier from
  cooperative tasks and retains the async checked-continuation post-commit
  observer;
- the selected Revision03 red starts only the source sentinel and terminates
  with the two expected harness-shape issues; the five selected green runs each
  start and pass their one requested test;
- `revision03-verify.log` has one terminal unfiltered result: **657 tests in 7
  suites passed after 43.419 seconds**. Each canonical A3 test and the source
  sentinel has exactly one start and one pass in that log;
- App, DEBUG Core/TestSuite, and release Core/TestSuite builds all complete.
  Existing objects independently show zero A3 seam tokens in release and
  nonzero A3 seam symbols in DEBUG;
- the manifest identity is
  `3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`.
  All 206 entries verify, fresh enumeration is exactly equal, the 12 frozen
  A3/red-line identities match, no `Sources` symlink exists, and
  `git diff --check` passes;
- all frozen product files match their reviewed bytes. Revision03 source drift
  is confined to `DurablePlanningTests.swift`; `Orchestrator.swift` remains at
  `f28331248a8ba50b641018456e3bbbc0e81e75111756a8ad2d11af9571f4088b`.

No P0 product defect was found. The two blockers below are exact completion and
evidence-contract failures.

## 3. Blocking findings

### P1-01 — The current authoritative output is not saved to the required task `verify.log`

`AGENTS.md:23` is a hard repository rule: the full authoritative
`swift run RunTests` output must be saved to the task directory's exact
`verify.log`. The accepted A3 leaf §9 also names that exact file.

The current task `verify.log` ends with **655 tests / 7 suites** and has SHA-256
`8eba08f8dd64f7999e24c2c0f90baac960db4c1ac077e42fe13c9abb4bc88eeb`.
It predates Revision02/03 and therefore does not execute the current 657-test
harness or prove either correction. The fresh complete run is valid, but it is
saved only as `revision03-verify.log`, whose terminal result is 657/657.

Revision03 §2 and §4 expressly authorized the versioned evidence file. That
preserves useful revision history, but it does not silently waive the
higher-level hard rule or turn a stale 655-test `verify.log` into current
authoritative evidence. Conversely, the implementer could not refresh
`verify.log` without exceeding Revision03's exact artifact allowlist. This is
therefore a real bounded-plan/evidence conflict, not a test failure and not
something this reviewer may repair.

**Required closure:** approve a bounded evidence revision that preserves the
historical 655-test identity and writes a fresh, complete current unfiltered
run to the exact task `verify.log`; update the report to identify that file as
the current authoritative gate. Unknown, partial, copied-without-provenance, or
nonterminal output remains blocking.

### P1-02 — The dedicated-thread completion contract and its fail-closed sentinel are incomplete

Revision03 §3.3 fixes the harness design precisely: resume one checked
continuation when both Foundation threads terminate, and return only after both
threads have finished. Current `A3DedicatedThreadCandidateRaceState.complete`
resumes the continuation at `DurablePlanningTests.swift:729-730` from inside
the second Foundation thread's closure. That call occurs before the closure
returns at lines 776-777 or 789-790. The helper does not retain the thread
handles or verify `isFinished`, so the awaiting task can return while the final
thread is still unwinding. `impl-report.md:204-207` consequently overstates the
evidence when it says the continuation resumes only after both threads
terminate.

Revision03 §3.5 separately requires the existing sentinel to fail closed on a
target-two rendezvous, abort/broadcast, indexed completion, checked
continuation, and confinement of the blocking rendezvous to the dedicated
thread helper. The assertions at `DurablePlanningTests.swift:4149-4170` check
only broad tokens such as the state type, two thread starts, `abortedBy`,
`indexedOutcomes`, and `withCheckedContinuation`. They do not require the two
indexed `rendezvous` calls, `arrivedIndices.count == 2`,
`condition.broadcast()`, completion after both threads finish, or exclusive
use of that blocking state by the dedicated-thread path. The sentinel can stay
green after removing the actual target-two release/broadcast while leaving the
otherwise unused token-bearing state in the file.

The present implementation does remove the observed cooperative-executor
starvation and the canonical runtime/database tests pass, so this is not a P0.
It is nevertheless a mandatory fixed-design and fail-closed regression gap,
the same class of missing executable evidence that blocked Review02.

**Required closure:** in a bounded test-only revision, make helper completion
provably wait for both Foundation threads to finish (or use an independently
reviewed equivalent with the same guarantee), and extend the existing source
sentinel to enforce the exact target-two, abort/broadcast, indexed-completion,
checked-continuation, no-Task, and confinement requirements. Preserve every
canonical interleaving/assertion, then regenerate the targeted and full
authoritative evidence and all affected build/release/report gates.

## 4. Counts and next gate

- P0: 0
- P1: 2
- P2: 0

Final verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**.

A3 acceptance remains prohibited, R-03 remains open, and A4 remains closed.
Only a bounded correction followed by a fresh responsibility-isolated
implementation rereview at 0 P0 / 0 P1 may open independent acceptance.
