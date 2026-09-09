# CLI cleanup error provenance: bounded implementation proposal

Decision: a deterministic behavioral regression and a two-file repair are feasible. **Do not skip outer-task cancellation on cleanup failure.** Preserve the cleanup error in the exact CLI generation before requesting that internal cancellation, and use one atomically selected outcome for generation waiters, outer stream completion and the outer task result. This is a separate demonstrated-contract investigation; it must not be described as proving the cause of the earlier unlocalized 069 failure.

Current evidence: `runtime-coro-diagnostic-focused.log` ends with all 069 groups passing (test 10.407 seconds; run 10.408 seconds), with the parent's fixed phase observations only. That run is a non-reproduction. The previous `runtime-coro-split-069-failure-analysis.md` remains the historical failure analysis; no inference that its leading hypothesis was confirmed is warranted.

## Smallest deterministic RED already exists in the matrix

Reuse `P1F1D069StubbornCliCell` / `P1F1D069StubbornCliDriver` and the second generation of `p1f1d069ExerciseCliHandoffAndImmediateWinners`:

- `stream()` remains open and observes stream termination. It does not finish its continuation when `cancel` fails.
- `cancel()` increments its count and throws `CliProcessBackendError.processGroupStillAlive(Int32(attempt))`.
- The second `stubbornDirectConsumer` is never canceled by the test. Its cancellation goes through the real adapter's public cancellation API. The existing test already checks the cancellation caller gets `"process_group_still_alive"`, waits for stream termination, joins the consumer, and checks cancellation count and empty terminal sinks.
- Its consumer result is currently discarded (`_ = await stubbornDirectConsumer.value`, current line 5327). Replace that single discard with `#expect(await stubbornDirectConsumer.value == "process_group_still_alive")`. The existing result-label helper already recognizes this error.
- Before the production repair, the stream stays open until the adapter cancels its outer task. Stream iteration exits due to cancellation and/or reaches a cancellation check; the consumer receives `"cancellation"` instead of the requested original cleanup error. There is no producer completion race that can supply the expected cleanup error. This should yield a decisive assertion failure rather than a hang.
- Keep the first `stubbornSignalConsumer` unchanged: the test explicitly cancels that consumer, so asserting it receives a thrown cleanup error would change the requested consumer-cancellation semantics.

This is preferable to introducing a new fixture initially. If stronger associated-value evidence is required, a local typed outcome from the second consumer can also assert `.processGroupStillAlive(2)`; the existing label assertion plus counter is sufficient for the narrow regression. Do not rewrite the general label helper or add another test identity merely for this case.

An invalid-evidence/open-stream variant is a useful second case if needed after the minimal RED: `cancelRegisteredProcess` validates the returned evidence and throws `EngineDispatchConflictErrorV1` when evidence is incomplete. Its stream must still terminate through internal task cancellation, while the uncanceled consumer receives the validation error. That variant is not necessary to establish the initial RED because the existing stubborn driver already supplies the essential contract.

## Why omitting cancellation is unsafe

`CliProcessBackend.performCancellation` (line 1193) awaits registration, marks cancellation requested, cancels stdin work, then awaits `terminateProcessGroup` and bounded completion. Either operation may fail before stream-producing work settles. Separately, `cancelRegisteredProcess` (adapter line 4248) may receive a driver return and reject its evidence while a custom driver stream remains open. The existing stubborn fixture is the simplest concrete instance.

Therefore `if firstError == nil { outerTask?.cancel() }`, though present in the ModelLoop path for its different ownership contract, can make CLI cancellation wait forever in `generation.waitForOutcome()`. Keep the current internal cancellation, `waitForOutcome`, outer-task join, settled marker, owner settlement and registry retirement prerequisites. A failed process cleanup remains a failed cleanup; adapter task settlement does not prove the process died.

## Exact two-file design

1. **`Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`**: first add only the second-consumer result assertion described above. Parent runs and retains RED on unchanged production. Existing phase diagnostics and all other expectations/order/barriers remain.
2. **`Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`**: add a private, generation-scoped pending failure for the cleanup owner's internal outer-task cancellation. Under `CliEngineAdapterGenerationV1`'s existing lock, record the first non-cancellation cleanup error only while cancellation owns terminal authority and no outcome is published. Perform this registration immediately before `outerTask?.cancel()` in `resolveCancellation` (current lines 4145–4150), after catching `cancelProcess` failure. Do not run `Task.cancel`, callbacks or continuation resumes while holding this lock.
3. Change private generation outcome publication to choose the canonical `Result` **inside the same lock that publishes it**. For an incoming `.failure(CancellationError())` from an outer task that is canceled, with this generation's registered internal-cancellation failure, select `.failure(savedCleanupError)`. Otherwise preserve the incoming result exactly. In particular, never replace a genuine non-cancellation producer error, success, or an already published outcome. Existing duplicate-publication precondition stays.
4. Return that selected `Result` from generation publication through private `CliEngineAdapterTaskRegistryV1.publishOutcome`. Resume the generation's outcome waiters with that exact selected result. In `execute`'s outer task, use that return value for `continuation.finish(throwing:)` and `try result.get()`, not the raw captured result. The existing `.outcomePublished` observer stays after publication. Returning the selected value prevents three disagreeing error surfaces.
5. Pass the outer task's cancellation state into selection (or capture it immediately at the publication call) so an unrelated provider-thrown CancellationError on an uncanceled outer task is not relabeled. Registration marks a request to perform this owner's internal cancellation; it is not proof the producer itself completed cleanup. State remains exact-generation private and cannot carry to a reused execution ID.

Suggested private naming can make the narrow intent explicit, e.g. `recordFailureBeforeOuterCancellation` and `publishOutcome(..., outerTaskIsCancelled:)`. A new general error framework, public API, enum for product outcomes or registry keyed only by execution ID is unnecessary. Validate any private API changes against all call sites, rather than introducing a separate normalize-then-publish sequence.

## Atomicity and winner rules

- **Cleanup failure registered first, internal cancel reaches outer task:** publication sees both the registered cause and an incoming canceled-task CancellationError; all result surfaces receive the original cleanup failure.
- **A genuine producer error is already captured or wins publication:** preserve it even if cleanup subsequently fails. Cancellation callers keep their existing `firstError` behavior; an unrelated producer failure is not rewritten simply to force identical text everywhere.
- **Natural success or terminal winner wins:** preserve success/terminal behavior. `.terminalWinner` does not register a cleanup-owner cancellation cause. Registration must not modify terminal authority or republish an outcome.
- **Failure registration races with publication:** both use the same generation lock. A published result is immutable; late registration is inapplicable and must not mutate it. A raw CancellationError can only be substituted at its initial publication, never retroactively.
- **Multiple cancellation claims:** they already share one owner; retain that structure. The saved failure is per generation and first-write only. Do not launch another owner or add task wrappers.
- **Cancellation timing:** store the failure before invoking cancel, outside-lock cancellation follows immediately, and selection is conditional on the outer task being canceled. This is sufficient for the intended internal cancellation path. It must not be claimed to distinguish every possible simultaneous provider-thrown CancellationError from an internal one; preserving all actual non-cancellation outcomes is the important hard boundary here.

## Early stream completion audit

Several existing `executeTask` paths finish the outer continuation before `publishOutcome`: successful prelaunch abort, normal completion and `submitFailure`'s terminal-sink error handling. A later finish cannot replace an already delivered result. **Do not try to repair that by publishing the cleanup error directly from `resolveCancellation`; that would return to consumers before the outer task has settled.**

For the narrow proposed substitution path, `executeTask` throws CancellationError without first finishing the outer continuation: the cancellation catch rethrows, and the outer `execute` task owns error finishing after outcome publication. Non-cancellation errors under cancellation authority also rethrow. Therefore the minimal targeted selection is effective for the stubborn/open-stream regression without centralizing every finish site.

Existing successful/terminal-sink finish paths should remain untouched and retain their results. A proposal that starts replacing `.success` with saved cleanup failure would conflict with these early finishes and expand the contract; do not implement it under this bounded change. The whole immediate-winner/prelaunch/quarantine/late-generation matrix is necessary regression coverage for this point.

## Verification and review boundary

Parent owns all compilation/runtime actions. Retain: one focused 069 RED with only the new behavioral assertion, independently reviewed two-file production change, then the focused 069 matrix and both 065 cases under normal settings. Preserve cancellation counts, stream termination, joins, terminal-sink assertions, immediate winners, exact generation reuse and retained claim barriers. The authoritative full `swift run RunTests` and unresolved halt work remain separate acceptance gates.

No source or runtime actions were performed for this proposal. Only this artifact was written. The historical PID 50925 CancellationError remains unlocalized unless additional evidence independently connects it to this now-testable error-provenance defect.
