# Halt ordering and cancellation-observer diagnostics plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans after independent review. Diagnostics only; parent owns all Swift execution. No commit is authorized.

**Goal:** Measure where the full-run one-second cancellation observer loses time: before runtime cancellation, inside its DB/composition/coordinator path, during cancellation-task admission, or between provider termination and the fixture actor's counter update.

**Evidence:** `runtime-recheck-full.log` reports `emergencyStopCancelsRunningBeforeWaitingForPlanner` failing `runningWasCanceledBeforePlannerReleased`; `runtime-halt-focused.log` reports the same code passing in **0.374 s**. Neither proves a deadlock or justifies an ordering/timeout change. The current logs lack correlated timestamps for the boundaries below.

## Source facts and constraints

- `Orchestrator.emergencyStop` first awaits `planningSupervisor.suppressForEmergencyStop()`, then begins `.halting`; `isHalted` becomes true at that transition, before dispatch-mode persistence and runtime cancellation (`Orchestrator.swift:12045–12127`). Entry tasks are explicitly cancelled/joined only after the runtime-cancel loop.
- `EngineExecutionRuntimeV1.cancel` is in the same file (`:10157`): profile DB read → registry composition → coordinator cancel. Coordinator resolution persists cancellation, calls the active-execution registry, and waits its cleanup lifecycle. Its registered cleanup closure cancels/joins the consumption task (`:2460–2515`, `:2620–2627`).
- Model-loop adapter/driver cleanup subsequently propagates through its real owned task/stream chain (`ModelLoopEngineAdapter.swift:706–752`, `CardRunner.swift:559–581`). Those files are inspected context, **not edit scope**. Their internal subinterval remains unresolved if the new outer markers are insufficient.
- `HaltHangingProvider` marks its cancellation counter only after stream `onTermination` cancels its producer task, that task catches `CancellationError`, and its actor accepts `markCanceled()` (`HaltAndCooldownTests.swift:789–838`). A one-second counter miss alone is not proof the cancellation request never happened.
- Preserve every task, actor hop, await, loop, cancellation, grace, existing `try?`, return and assertion. Keep the one-second observer, 10 ms sleep, `isHalted` yield loop and original planner gate release order. No behavior fix, scheduler guess, worker replacement, extra sleeps, task priority change, or suite serialization.
- Modify exactly `Core/Observability/RuntimeLifecycleDiagnostics.swift`, `Core/Kernel/Orchestrator.swift`, and `TestSuite/HaltAndCooldownTests.swift` under Sources/AgentLoop*. No new file, schema or source-boundary amendment.
- All new output uses the existing `AGENTLOOP_RUNTIME_DIAGNOSTICS=1` gate, fixed enum stages, UUID owner and integer value. No error strings, source/provider text, reason strings, SQL payloads, paths, credentials or model names.

## 1. Correlation without a new asynchronous seam

Add `package nonisolated let haltDiagnosticId = UUID()` to Orchestrator. This is an immutable diagnostic identity, not a constructor option, dispatch identity or state-machine input. Its events use this owner. Do not use `dispatchTransitionToken` as the owner because it changes during the method.

For runtime/coordinator/active-cleanup events use the **actual canonical execution UUID** as owner. Existing canonical validation stays unchanged. A private file-local event helper may parse the already validated executionId and call the logger only when enabled; it must not invent a replacement UUID, throw a new execution error, or log an invalid raw string.

Give `HaltHangingProvider` and `HaltGate` optional immutable `nonisolated let diagnosticId: UUID?`, default `nil`; target test alone supplies a random UUID to each constructor. Other fixture callers stay unchanged. No setters, observer callbacks, new awaits or synchronization primitives.

In the target test, after its existing `await gate.waitUntilEntered()` and **before** scheduling stop, run an opt-in synchronous read of actual `engine_execution.id` for `runningIds.cardId`, `state = 'running'`, `redactedAt IS NULL`. Require exactly one canonical UUID for correlation, then print a fixed identity line containing only test name, orchestrator UUID, execution UUID, provider UUID and gate UUID. The actual table/columns are declared in `Database/Records.swift:529+`; no guessed global execution selection.

If this diagnostic read fails or yields missing/ambiguous/invalid identity, emit `haltFixtureIdentityMissing` with fixed numeric code and continue the original test unchanged. Do not log the error or silently assign an owner. The observation report is incomplete until the identity gap is resolved; a functional test pass does not waive it. Default-off execution performs no extra DB read/print.

## 2. Core markers in the existing Orchestrator file

Append fixed stage cases below to RuntimeLifecycleStage; retain its format/gate and all old cases. Unless specified, value is zero. Mark successful returns only after the existing operation succeeds; add `...Failed` value 1 in the **existing** catch where listed, without replacing/reclassifying its original error. No new catch around an operation solely to modify its propagation is needed.

| Owner | Stages and exact existing placement |
| --- | --- |
| Orchestrator UUID | `haltStopEntered`: first statement of emergencyStop, before phase switch. |
| Orchestrator UUID | `haltSuppressCalled`, `haltSuppressReturned`: around the existing supervisor await. |
| Orchestrator UUID | `haltTransitionPublished`: immediately after `beginTransition(.halting)` returns. |
| Orchestrator UUID | `haltPersistenceCalled`: before the existing dispatch-mode persistence do; `haltPersistenceReturned`: after `haltPersistencePending = false`; `haltPersistenceFailed`: first diagnostic in its existing catch. No raw error is newly logged. |
| Orchestrator UUID | `haltRunningSnapshot`: after the existing snapshot assignment, value snapshot.count; `haltRuntimeResolved`/`haltRuntimeResolveFailed`: in the existing runtime-resolution success/catch branches. |
| Execution UUID | `haltRuntimeCancelCalled`, `haltRuntimeCancelReturned`, `haltRuntimeCancelFailed`: immediately around each existing runtime.cancel await and in its existing catch. |
| Execution UUID | `haltRuntimeEntered`: after existing canonical validation in EngineExecutionRuntimeV1.cancel; `haltProfileReadCalled/Returned`, `haltCompositionCalled/Returned`, `haltCoordinatorCalled/Returned`: around its three existing stages. No reordered read or composition. |
| Execution UUID | `haltCancellationPersistenceCalled/Returned`: around `store.requestCancellation` in coordinator resolveCancellation. |
| Execution UUID | `haltActiveCancelCalled/Returned`: around its existing `await activeExecutions.cancel`. |
| Execution UUID | `haltActiveTaskQueued/Started`: immediately before and first statement inside the existing `Task { try await action() }` in `cancelLiveExecution`. Capture a value copy of the method's validated executionId and existing attempt for diagnostics; do not capture the actor or add a task. |
| Execution UUID | `haltConsumptionCancelCalled`: directly before the existing `consumption.cancel()` in the registered cancelAndAwait closure; `haltConsumptionJoined`: after its existing `try await consumption.value`. |
| Entry generation UUID | `haltEntryTaskCancelCalled`: before each existing `entry.task.cancel()`; `haltEntryTaskJoinCalled/Returned`: around its existing `await entry.task.value`. Use entry.generationID, not loop index. |
| Orchestrator UUID | `haltPlanningCleanupCalled/Returned`: around the existing cancelAllPlanning + didCommitEmergencyPlanningCleanup block; `haltStopReachedEnd`: immediately before the existing final firstError throw check, value firstError == nil ? 0 : 1. This is not an unconditional success marker. |

For the target entry, correlate its generation UUID without another API: in emergencyStop, only when diagnostics are enabled, print one fixed mapping `orchestrator UUID / entry.generationID / parsed canonical execution UUID` from the **existing** running snapshot. Do not print card/mission data or unvalidated strings. An entry without an execution ID has no runtime-cancel edge; emit fixed `haltEntryUnbound` owned by that generation instead of guessing.

No marker means an awaited/throwing phase did not return or was not entered; do not infer failure type from absence. If a terminal early return occurs, the original control flow remains unchanged and must be distinguished from `haltStopReachedEnd` in analysis.

## 3. Target fixture markers: actual signal, actor mutation and deadline

In the target test, all caller-side markers use orchestrator.haltDiagnosticId:

- `haltFixtureStopQueued` immediately before its existing stopping Task; `haltFixtureStopTaskStarted` as that Task's first statement before awaiting emergencyStop.
- `haltFixtureHaltedObserved` after the unchanged `while !(await orchestrator.isHalted)` loop.
- `haltFixtureCancelObserveQueued` before the existing `await runner.waitUntilCanceled()`; `haltFixtureCancelObserveReturned` after, value actual Bool ? 1 : 0. Preserve the subsequent `#expect` exactly.
- `haltFixtureGateOpenQueued` immediately before existing `await gate.open()`; `haltFixtureStopJoined` after existing `try await stopping.value`. No extra await or early gate release.

Inside the optional-instrumented hanging provider, use its UUID:

- `haltProviderTermination`: first statement of existing onTermination closure, value 0 for `.cancelled`, 1 for `.finished` (never its associated error); retain unconditional `task.cancel()` immediately after the marker.
- `haltProviderTaskCancelReturned`: after that same task.cancel call.
- `haltProviderCancellationCaught`: first statement of existing `catch is CancellationError`, before `await self.markCanceled()`.
- `haltProviderCancellationRecorded`: in `markCanceled`, immediately after `cancellations += 1`, value the actual count. Never move the increment out of its actor.
- `haltProviderWaitStarted`: immediately after constructing its existing deadline in waitUntilCanceled; `haltProviderWaitEnded`: after the unchanged polling loop, value cancellations > 0 ? 1 : 0, immediately before the unchanged return. The target uses the existing default one second; do not recompute/change the timeout. These markers separate actor admission and polling delay from the caller's wait request.

Inside the optional-instrumented gate, use its UUID: `haltPlannerGateEntered` after existing `entered = true`; `haltPlannerGateOpened` after the existing `opened = true` and waiter-resume/remove loop completes. Keep the existing suspend continuation and open ordering unchanged. Do not infer the gate was released from a caller-queued marker alone.

## 4. Verification and one complete observation

Parent freezes preimages, waits for the sole source writer, reviews the three-file diff, then compiles/runs the target with complete stdout/stderr. A focused diagnostic pass only checks instrumentation integration; retain any different result without retrying to obtain a preferred outcome. All three provider-counter, card/run/mission/event and shutdown assertions remain authoritative.

The next full concurrent run is permitted only after the already assigned Board isolation and CLI/halt observability pass their required reviews; do not repeat the unchanged full run now. Parent captures actual RunTests PID/time/source hashes, full output/exit code and complete lifecycle events, retaining the exact fixture identity mappings. Default-off source check confirms no new logging, fixture DB read or state-decision dependency.

Report these intervals using `mono` and the explicit identity joins: request queue→Task entry→Orchestrator entry; suppress→halting→persistence; actual isHalted observation→one-second provider wait; runtime profile read→composition→coordinator→cancellation persistence→active task queue/entry→consumption cancel; provider termination→task cancel return→catch→actor counter; entry cancel/join; actual gate open. Compare their order with the unchanged observer deadline, not whole-test duration.

If delay lies between consumption cancellation and provider onTermination, the adapter/driver/AgentLoop inner chain remains an explicit missing measurement and requires a later scoped probe; do not assert which nested task caused it. If cancellation was requested promptly but markCanceled or its observer ran late, report that distinction. If persistence/composition/active-action admission was late, report that measured boundary without guessing executor exhaustion. No timing observation by itself authorizes reordering emergencyStop.

Completion requires independent source review, compilation, and retained correlated observation evidence. A missing owner edge or unmeasured interval is a reported diagnostic gap, not a fixed halt bug or a cleared runtime gate.
