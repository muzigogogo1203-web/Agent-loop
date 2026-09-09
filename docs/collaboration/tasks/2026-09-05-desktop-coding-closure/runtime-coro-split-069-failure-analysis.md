# 069 focused runtime failure: read-only localization

Status: **not yet localized to a throwing statement; runtime gate remains red.** The strongest concrete candidate is the CLI half of `p1f1d069ExerciseSharedAdapterCleanup`, where cleanup failure can be replaced in the execution stream by outer-task cancellation. Current evidence does not establish that the new helper lifetime boundaries caused this failure. Do not alter cancellation expectations or accept this as an expected cancellation.

## Observed evidence

- Read current `AGENTS.md`, the split plan, split review, focused 069 output and process identity, all first 15 helper bodies, the associated cancellation fixtures and relevant adapter/start-gate paths. Used systematic-debugging's evidence-first workflow. No compiler, test, sampling, process signal, App, DB mutation, source change or subagent was run.
- Current test source SHA-256 is `e5a3ce4fae3ae1c0487ffe3c62b43360f49c7c6ef49ddf1d2d2538397ca2380e`; the existing review establishes exact whole-source reconstruction against the frozen preimage. I did not repeat that reconstruction.
- `runtime-coro-split-focused-069.log`: one test, one issue, `Caught error: CancellationError()` at the test declaration (`ExecutionEngineConformanceTests.swift:9448:6`), duration 0.480 seconds. The declaration location does not identify the throwing helper or await.
- `runtime-coro-split-069-process.txt`: PID 50925, focused skip-build command, exit 1. Parent reports the preceding ordinary compilation and both 065 tests succeeded; those facts do not clear 069.
- `runtime-coro-split-069-events.ndjson`, SHA-256 `4c7ea8449200079e1de3629dd4b26fb9bd4ecdfc13e5018aeb6b61f26dd6fd72`, contains 10 runtime-lifecycle records for PID 50925 and its RunTests image, then an extraction summary. Owners are `...692` attempt 1, `...693` attempts 1/2, and `...699` attempts 1/2. Last record is `haltActiveTaskStarted`, owner `...699`, monotonic `109204116506291`.
- These events prove entry into group 2, after group 1 returned. They do not prove group 2 completed, nor identify any later group. No stage prints exist before the first 15 helper calls; absence of those prints cannot distinguish groups 2–15.

## Concrete candidate: CLI stream error provenance

The group-3 model and CLI consumers catch only the intended `P1F1D069AdapterCleanupFailure`. The CLI consumer's task is joined with an unguarded `try await cliConsumer.value` at current line 5120. Thus a `CancellationError` from its stream propagates to the test declaration exactly as observed, even when both cancel callers returned their expected injected cleanup failure at lines 5118–5119.

Relevant chain in current source:

1. The CLI fixture creates and stores a stream continuation before pausing in its construction gate (`P1F1D069CliCleanupDriver.launch`, lines 2813–2819). The group releases construction and later releases its cleanup probe.
2. `P1F1D069CliCleanupCell.failCancellation` finishes that stream with `.cliProcess` and throws the same error (lines 2779–2785).
3. `CliEngineAdapter.resolveCancellation` catches `cancelProcess` failure into `firstError`, then **unconditionally** calls `outerTask?.cancel()` (production lines 4145–4150).
4. The outer CLI execution has cancellation checks immediately after launch returns and after stream iteration (lines 4486 and 4556). If cancellation reaches a check before the outer task observes the finished stream's injected error, its outcome becomes `CancellationError`; the outer stream is finished with that outcome by `execute`.
5. The cancellation owner still throws `firstError` at line 4160. Therefore both cancellation calls can correctly report `.cliProcess` while `cliConsumer.value` throws `CancellationError`.

This is an explicit race mechanism supported by source, **not proof it happened in PID 50925**. A nearby comparison is unusually relevant: the ModelLoop cancellation path already documents this exact error-substitution risk and cancels its outer task only when `firstError == nil` (`ModelLoopEngineAdapter.swift`, lines 739–748). That comparison strengthens investigation priority; it does not authorize copying the condition blindly, because CLI process-liveness and cleanup obligations must remain intact on cancellation failure.

## New-boundary and early error-path audit

| Group | Boundary / cancellation evidence |
| --- | --- |
| 1 RoutingWinners | Each complete permutation loop already had its own root-cleanup defer. Outcomes are observed before loop exit. Existing unstructured wiring tasks were not moved across a loop boundary. Group 2 events prove this helper returned for this run. |
| 2 ActiveCancellationRegistry | Pending registration and joined cancellation tasks are awaited; retry/failure tasks are awaited; all checked registry entries are removed. The final gated task is explicitly canceled and joined in a `catch is CancellationError`. Its `open()` only returns for a canceled gate or throws a duplicate-open conflict; it does not throw CancellationError. This is not an evidence-supported failing-open candidate. |
| 3 SharedAdapterCleanup | Model and CLI consumer/cancel tasks are all joined within the same helper. No new boundary separates construction, cancellation or consumer joins. The direct CLI consumer join is the leading uncaught-cancellation candidate above. |
| 4 ModelClaimHandoff | Signal/reuse consumers and old-generation claim are awaited within the helper. Observer-created tasks capture their own lifecycle probe. Source gives no cross-helper reference to their adapter/fixture. |
| 5 CliHandoffAndImmediateWinners | Stubborn consumers and cancellation outcomes are joined; immediate-outcome loops stay intact. Existing nested immediate-CLI helper retains its gate-release defers. Label helpers convert unexpected errors into assertion values rather than propagating bare CancellationError. |
| 6 PrelaunchAndQuarantine | Claims, generation outcome and consumers are observed before helper exit; quarantine reuse remains within the helper. No added boundary occurs while a gate is intentionally held. |
| 7 GenerationBoundCleanup | Each nested helper joins both consumers and all relevant claims before returning; its model/CLI fixture captures stay within this caller. |
| 8 CompletionRegistry | Resolution tasks are joined, lifecycle consumed, removal authorized/performed and receipt awaited in one scope. The bare awaits can propagate errors, but source adds no cancellation of the test task. |
| 9 DispatchAdmission | Duplicate tasks both joined. Pre-begin cancellation applies only to `preBeginTask` and its value is joined with a CancellationError catch. Fixtures are unique temporary roots. |
| 10 BeginRegistrationLatch | Deliberately sleeping bind child is canceled by its supervisor; external cancel and execute tasks are joined before fixture exit. A supervisor failure to translate child cancellation could propagate at these joins, but there is no corresponding event evidence identifying this group. |
| 11 SettledPrimaryRetry | Primary/external tasks return typed labels and are joined; retry execute is directly awaited. Trigger and fixture remain scoped together. No moved boundary separates failed generation from retry. |
| 12 PostGateAndBindCancellation | Cancel and execute tasks are joined before final assertions. Both bind cases and per-loop cleanup remain intact. Unexpected cancellation from a coordinator could escape direct awaits, but the new helper does not add cancellation. |
| 13 ObserverAndFinalizerFailure | First coordinator execute completes before second scenario. Finalizer task is joined inside its expected-conflict catch; unexpected CancellationError could escape that catch, without current event attribution. |
| 14 CompletionRemovalBarriers | Barrier task/raw waiter and failure task/raw waiter are joined. Failed-removal registry intentionally retains one entry after joins. No blanket teardown was added; this retained object deserves awareness but no later helper consumes it. |
| 15 ObserverStoreFailure | Execute is already inside a broad catch; errors during setup may escape, but a cancellation thrown by execute itself cannot produce this sole propagated issue. The zero-observer assertion remains. |

`P1F1DCanonicalExecutionFixture.deinit` removes its own UUID-based root (`EngineExecutionStoreTests.swift:1633`); earlier destruction is a real semantic dimension of outlining, even with statement preservation. However, group 1's canonical fixtures were already inside a loop, group 2 has no such canonical fixture, and group 3 does not share one with group 2. No concrete prior-group cleanup action has been found that can cancel group 3's CLI task or the parent test task. Direct sequential async helper calls introduce suspension/lifetime changes but do not themselves request task cancellation. The shared CLI registry is process-wide, so lifetime alone also does not reset it; its entries' retirement is governed by generation/claim completion.

## Minimum next observation

Parent should first amend the diagnostic scope and add phase-only observation to the existing single test, preserving order and every assertion/error path. Suggested minimum targeted points are: after group 2 returns, before group 3, after its model consumer join, immediately before and after its CLI consumer join, and after group 3 returns. Record `Task.isCancelled` alongside these fixed phase names. Place join-adjacent observations after cancellation callers have already settled, so they do not redefine the producer/construction barrier. A tiny set of caller enter/returned markers for the remaining helpers can distinguish a later failure in the same run if group 3 passes.

Perform one parent-owned focused 069 diagnostic run with normal compilation and captured full output. If the last point is immediately before CLI consumer join, with both cancellation claims already asserted and the test task uncanceled, the error provenance above is localized enough to investigate the CLI producer outcome/cancellation ordering. If another point fails, follow that exact group instead. If the diagnostic run passes, treat it as a scheduling-sensitive observation, retain the failed run, and do not declare the race fixed.

No cancellation suppression, catch broadening, timeout increase, suite/filter/serialization change, fixture retention workaround, compiler-option change, or repeated uninstrumented retry is supported by this analysis. Production repair is pending actual localization and review of how failed cleanup preserves process ownership while delivering the original failure.
