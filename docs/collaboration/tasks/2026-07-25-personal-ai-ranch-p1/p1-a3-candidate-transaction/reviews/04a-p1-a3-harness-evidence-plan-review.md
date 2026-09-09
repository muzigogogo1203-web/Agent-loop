# P1-A3 Responsibility-Isolated Revision04 Plan Review04A

> Date: 2026-08-10
>
> Reviewer: fresh responsibility-isolated Revision04 plan reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author the A3 implementation, current harness, source
sentinel, Revision04 plan, tests, evidence, or implementer report. The review
was read-only except for this exact file. It did not run tests, builds, release
gates, scripts, the App, or UI, and it did not modify product, test, plan,
manifest, prior review, or evidence bytes.

The review read `AGENTS.md`, the immutable Review03, the current dedicated
race harness and source sentinel in `DurablePlanningTests.swift`, the accepted
Revision03 design and Review03A for inherited constraints, and
`plan-revision-04.md`. This approval opens only the bounded Revision04
test/evidence correction. It is not A3 acceptance and does not open A4.

## 2. Review03 P1-02 closure audit

Revision04 fixes the exact premature-completion defect rather than adding a
timing delay or another cooperative waiter:

- the two existing workers remain exactly two named Foundation `Thread`
  instances and both handles are retained;
- workers are restricted to their indexed synchronous operation,
  rendezvous/abort behavior, and exactly one indexed outcome store. They may
  not inspect thread completion or own a continuation;
- one private serial `DispatchQueue` is the sole completion coordinator. Its
  executable path must observe both `firstThread.isFinished == true` and
  `secondThread.isFinished == true` before it validates or snapshots outcomes
  and before the sole continuation resume;
- therefore the continuation cannot resume from either worker closure while
  the second worker is still unwinding, which is the exact Review03 defect;
- waiting is confined to the dedicated GCD queue. A third Foundation thread,
  `Task`, `Task.detached`, task group, or any synchronous wait on the Swift
  cooperative executor is expressly forbidden;
- target-two release remains `arrivedIndices.count == 2` plus broadcast, while
  every pre-rendezvous/peer failure records its aborting index and broadcasts,
  so neither worker can leak when its peer fails;
- after both real thread-finish observations, indices 0 and 1 must each have
  exactly one outcome. A missing or duplicate outcome is an explicit harness
  error. A precondition-only trap, forced unwrap, overwritten duplicate, or
  synthesized/default result would not satisfy the reviewed plan.

Completion-before-poll and poll-before-completion are both covered by the
same post-finish coordinator path. No alternate resume owner or fallback path
is permitted, so the one checked continuation has a single, auditable owner.

## 3. Fail-closed sentinel audit

Revision04 materially strengthens the existing sentinel without changing the
657-test count. It requires occurrence counts, ownership/confinement, and
execution order rather than broad whole-file token presence:

- exactly two indexed `rendezvous` calls, the target-two count check, normal
  broadcast, abort recording, and abort broadcast must be in the live
  dedicated harness/state paths;
- exactly two Foundation thread constructions, both exact names, and both
  starts must belong to the dedicated helper;
- the extracted completion-coordinator path must place the two actual
  `isFinished` observations before outcome-pair validation and before its sole
  `resume` occurrence;
- worker closures are checked to exclude continuation/completion ownership,
  while the state/completion helper is checked to contain no continuation
  resume path;
- the dedicated helper is checked to exclude cooperative tasks, task groups,
  and a third Foundation thread;
- the blocking state/rendezvous is confined to the direct database race
  helper and excluded from both Orchestrator tasks and all other canonical A3
  paths;
- the independent async actor observation barrier, DEBUG adjacency, release
  sealing, manifest, and frozen source-boundary assertions remain mandatory.

The plan's requirement that these checks prove structure/order and occurrence
counts, rather than accept unused token-bearing declarations, also makes the
sentinel non-self-referential. Concretely, implementation must count/order
tokens in masked, extracted implementation bodies (using the existing
`PlanningTestFixtures` facilities or an equivalent bounded extraction).
Sentinel string literals, comments, or broad raw-file `contains` matches do
not satisfy section 3. Exact thread-name checks may inspect the raw body of the
extracted dedicated helper because that range excludes the sentinel itself;
structural token checks must use its masked body. This is a direct consequence
of the plan's stated fail-closed contract, not an additional design choice.

## 4. Review03 P1-01 and evidence-chain audit

The required authoritative evidence path is now unambiguous:

1. Before replacement, the historical 655-test `verify.log` bytes are
   preserved as `revision04-predecessor-verify.log` and proven byte-identical
   to the then-current frozen predecessor.
2. A fresh unfiltered `swift run RunTests` writes complete stdout/stderr
   directly to the task's exact `verify.log`. Copying a prior run into that
   path, using partial output, or promoting a nonterminal run is prohibited.
3. The direct run must terminate with 657 tests in 7 suites passing, with one
   start and one pass for the sentinel and each canonical A3 test and no
   failure, hang, timeout, crash, or unknown output.
4. Only after validation may those exact new bytes be mirrored to
   `revision04-verify.log`, with byte equality required. `verify.log` remains
   the authoritative gate; the versioned file is only its archival mirror.
5. Fresh targeted red/green, App/DEBUG/release builds, symbol direction,
   manifest/frozen-byte/symlink/scope gates, `git diff --check`, and the
   append-only report correction remain required before rereview.

This preserves both provenance directions: the replaced 655-test predecessor
remains immutable evidence, while the repository-mandated path contains the
fresh current run itself rather than a provenance-ambiguous copy.

## 5. Scope and stop conditions

Only `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`, the enumerated
task-local Revision04 evidence/review artifacts, the exact task `verify.log`,
and an append-only Revision04 report section may change. All Core/product/App,
other test, Package, runner, matrix, schema, migration, prior plan/review, and
prior evidence bytes remain frozen. Existing canonical interleavings and
assertions may not be weakened.

Any unexpected targeted red, missing real thread-finish observation,
non-explicit outcome mismatch, self-satisfying sentinel, alternate
continuation resume, cooperative wait, third thread, evidence mismatch,
nonterminal full run, widened source scope, or failed build/symbol/scope gate
stops implementation. It does not authorize a fallback or product patch.

## 6. Findings and verdict

- P0: 0
- P1: 0
- P2: 0

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

Revision04 may proceed only within this reviewed boundary. A3 remains
unaccepted, R-03 remains open, and A4 remains closed until the fresh
responsibility-isolated implementation rereview and independent acceptance
both pass.
