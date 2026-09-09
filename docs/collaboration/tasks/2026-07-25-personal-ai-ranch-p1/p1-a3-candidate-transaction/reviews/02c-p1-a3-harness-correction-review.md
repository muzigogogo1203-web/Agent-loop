# P1-A3 Responsibility-Isolated Harness Correction Review02C

> Date: 2026-08-10
>
> Reviewer: responsibility-isolated harness-correction reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and review boundary

This review was read-only except for this exact review file. It reviewed only
Revision02B section 7 and the immutable
`revision02-red-tests-harness-rejected.log`. It did not modify the plan,
manifest, rejected log, product, tests, scripts, or prior reviews, and it did
not run a test, build, matrix, source, bundle, preview, or UI command.

The question is narrow: whether the first attempted red is correctly rejected
as a harness failure, and whether a test-only actor-`await` correction can
produce a new authoritative red before any Core implementation begins.

## 2. Diagnostic classification

The first attempted red is correctly and permanently classified
**HARNESS_REJECTED**. It cannot open the Core/product implementation gate,
because its compiler output mixes the intended missing capability with
independent test-harness compile errors.

### Expected missing-seam diagnostics

The following diagnostics are the intended failure-first evidence:

- the missing `A3CandidatePostCommitObservationForTesting` type;
- the missing `armA3CandidatePostCommitObserverForTesting` method;
- the missing `clearA3CandidatePostCommitObserverForTesting` method.

The two “`nil` requires a contextual type” diagnostics at the observer closure
are compiler cascades from that same missing seam. The declared
`A3PostCommitObservationProbe.record` parameters already provide concrete
optional types. What is absent is the observer method and therefore its closure
signature/context. Those two diagnostics are not independent harness defects
and must not be patched separately before the seam exists.

### Independent test-harness diagnostics

The log also contains twelve independent actor/async errors in
`DurablePlanningTests.swift`:

- nine `DatabasePool.write` calls are async in their enclosing async tests but
  are missing `await`, at the rejected-log source locations 2049, 2062, 2289,
  2324, 2613, 2738, 2897, 3253, and 3306;
- three calls to actor-isolated `A3ObservationBarrier.release()` are missing
  `await`, at the rejected-log source locations 2821, 2950, and 3209.

These diagnostics do not depend on the missing Core seam. Therefore the first
run is not a clean failure-first red even though it also contains the expected
seam diagnostics.

The `writeWithoutTransaction` “no calls to throwing functions” item is a
warning, not a compile failure. It does not invalidate this classification and
is outside the authorized actor-`await` correction.

## 3. Approved bounded correction

Revision02B may proceed with exactly one harness correction:

1. Modify only `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`.
2. Add `await` to the nine identified async `DatabasePool.write` calls.
3. Add `await` to the three identified actor-isolated `release()` calls.
4. Do not change closure bodies, test setup, assertions, timing, interleavings,
   observer calls, optional arguments, helper behavior, or any other source.
5. Keep `Sources/AgentLoopCore/Kernel/Orchestrator.swift` at its frozen entry
   bytes. No Core/product implementation is authorized by this review.

If any identified call cannot be corrected by that mechanical actor-`await`
change alone, the correction must stop rather than widening scope.

## 4. Fresh authoritative-red gate

After the bounded test-only correction, run the same authoritative command once
and capture its complete output in a new `revision02-red-tests.log`. The
rejected log remains immutable and may not be renamed, overwritten, or reused
as red evidence.

The fresh run is a valid failure-first red only if all of these conditions hold:

- it fails on the reviewed missing observation seam/type/method capability;
- it contains none of the twelve actor/async harness errors above;
- it contains no unrelated compile, discovery, fixture, runtime, or product
  failure;
- any compiler cascade is directly rooted in the missing observer seam, such
  as the two contextual-`nil` diagnostics already classified above;
- the frozen Core file and all other Revision02 boundary gates remain exact.

Only that fresh, clean red opens Revision02B step 4 for the already reviewed
DEBUG-only Core seam. Any additional error keeps the Core/product gate closed
and requires another explicit review; it may not be explained away by the
rejected run.

## 5. Findings and verdict

No P0, P1, or P2 finding remains within this bounded Review02C question.

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

This approval authorizes only the twelve mechanical test-side actor-`await`
corrections and one fresh authoritative red run. It does not itself authorize
the Core seam, accept A3, close R-03, open A4, or authorize commit, push, merge,
release, data operations, external actions, or real-user actions.
