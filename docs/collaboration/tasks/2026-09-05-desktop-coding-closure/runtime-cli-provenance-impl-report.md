# CLI cleanup provenance repair implementation report

## Status and frozen scope

Task 1 production implementation is complete for responsibilities-separated review. Runtime/compiler verification remains pending with the root task.

- Checkout: `/Users/muzi/Agent-loop`
- Branch: `codex/desktop-coding-closure-20260905`
- HEAD verified before editing: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- Production preimage SHA-256: `83da75b87a9816c84e72e99fd18d1789be59fbf2d1e4e95803fe74f067c5be40`
- Implemented production SHA-256: `08f56a49c3293d246d4d57e2bfc600ecc5e9461002940916b0c7acf6a1e8719e`
- Frozen covering test SHA-256 before and after this task: `f7089c930283b0277721f3642a31491fef458006a5b20266b7119f5422c681f3`
- Exclusive production source edited: `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`
- Additional artifact written: this report.

The existing dirty tree was preserved. This task did not edit the covering test, process backend, ModelLoop, public/package protocols, terminal authority model, task creation/priority, timeouts, schema, App, compiler settings, or any other source file.

## Retained RED evidence

The implementation was admitted against the reviewed combined RED evidence, not an anticipated result:

- PID 58119 completed all 069 scenarios in 5.529 seconds and failed only the new stubborn-direct expectation that the uncanceled consumer receive `process_group_still_alive`. The actual pre-fix stubborn value was not printed and is not claimed.
- PID 58651 completed its incremental build in 23.34 seconds, reached `P1F1D069_JOIN=cli-begin`, did not reach `cli-end`, and failed in 0.511 seconds with exactly one caught `CancellationError`. The two immediately preceding cancellation-caller expectations passed only after those callers caught the typed cleanup failure.

These are two distinct runs. The implementation does not claim either run proves the cause of historical PID 50925.

## Actual production changes

The complete frozen-source diff contains 56 added and 13 removed lines, limited to the five planned semantic regions:

1. `CliEngineAdapterGenerationV1` now owns one private optional `failureBeforeOuterCancellation` field. Its synchronous `recordFailureBeforeOuterCancellation(_:)` ignores `CancellationError` and, under the existing generation lock, records only the first non-cancellation failure while terminal authority is `.cancellation` and no outcome exists.
2. Generation `publishOutcome` now accepts `outerTaskIsCancelled` and returns the selected `Result<Void, any Error>`. Inside the same existing publication lock, it substitutes the saved exact-generation failure only when the incoming result is `CancellationError`, the outer task is canceled, and the saved failure exists. Otherwise it preserves the incoming success or error exactly. It assigns the selected result once to immutable outcome, clears the pending field, extracts waiters, resumes all continuations outside the lock with the selected result, and returns it.
3. Registry `publishOutcome` propagates the cancellation flag and returned selected result. Existing generation publication occurs before the registry retirement lock. The inapplicable-entry `return` remains closure-local, after which the method still returns the selected result.
4. The existing outer Task names its initially captured execution result `rawResult`, passes `Task.isCancelled` at publication, and uses the returned canonical result for both `continuation.finish(throwing:)` and `try result.get()`. The existing `outcomePublished` observer remains immediately after publication.
5. In the existing cleanup-owner branch, `resolveCancellation` records a nonnil `firstError` immediately before the unchanged `outerTask?.cancel()`. Process cleanup, error capture, internal cancel, generation-outcome wait, outer-task join/settlement, and original claimant `firstError` throw remain in their existing order.

## Invariant self-review

- State is stored on the exact generation object, not in an execution-ID map; a reused ID receives a new generation and cannot inherit the field.
- Recording requires cancellation authority and nil outcome. A terminal winner, late record, duplicate publish, or already immutable outcome is not rewritten.
- Only a canceled outer task's incoming `CancellationError` can be substituted. Genuine non-cancellation producer errors, natural success, prelaunch success, and terminal winners remain unchanged.
- The selected result is the single value stored in `outcome`, resumed to outcome waiters, returned through the registry, used to finish the outer stream, and returned/raised by the outer task.
- The cancellation owner still retains and throws its original local `firstError`; ignoring an inapplicable registration does not suppress claimant delivery.
- No continuation, callback, observer, or `Task.cancel` operation runs inside the generation lock. Generation publication still completes before registry retirement locking.
- Existing counts are unchanged between frozen and implemented production source: `Task {` 4/4, `Task.detached` 1/1, `outerTask?.cancel()` 1/1, `cancelProcess(generation:)` 1/1, `waitForOutcome()` 2/2, `markOuterTaskSettledForCancellation()` 3/3, and `continuation.finish` 13/13.
- No `OSLog` or `print` statement was added; both remain zero in this production file.
- Private call-site audit found one generation publication path, one registry publication path, one outer Task publication call, one record method, and one resolver record call. Both changed publication signatures are fully propagated.

## Verification pending

Per the brief, the writer ran no Swift command, compiler, test, OSLog query, sample, signal, process manipulation, database, App, package, or commit operation. The current hash and static diff are implementation evidence only, not a compile or runtime pass.

The root task still owns the responsibilities-separated actual-diff review, twelve-file manifest refresh, ordinary incremental build, one focused 069 run, both focused 065 cases against the matching executable, and every later full-suite/product/package/acceptance gate. The post-fix 069 evidence must reach the stubborn label, observe `process_group_still_alive`, pass the unchanged expectation and all remaining scenarios, or stop on the first concrete unexpected failure.

## Concerns

No static implementation blocker or scope deviation was found. Compilation and behavioral correctness remain unclaimed until root-owned review and runtime verification complete.
