# Halt pre-cancellation diagnostic supplement implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for this single bounded task after independent review. Parent owns source admission, preimages, compilation, observations and acceptance. This document authorizes no worker execution, new agent, commit or release.

**Goal:** Divide the measured **863.437 ms** `haltCoordinatorCalled` → `haltCancellationPersistenceCalled` gap into observable coordinator, synchronous state-read, completion-registry, installed cancellation-task, observer and resolver boundaries without changing cancellation behavior.

**Architecture:** Append synchronous, opt-in event calls at existing statements and branches in Orchestrator. Use the existing canonical execution UUID helper and existing logger; preserve all asynchronous seams, captures and ownership tokens. Keep the existing later active-cleanup task markers distinct from the earlier installed cancellation task.

**Tech Stack:** Swift 6 actors and Tasks; GRDB synchronous pool read; existing RuntimeLifecycleDiagnostics UUID/stage/integer/monotonic event format.

**Spec:** `runtime-halt-diagnostics-plan.md` and `runtime-combined-halt-analysis.md` in this directory, both read completely. This supplement narrows the next source change to two existing files and supersedes the earlier plan's next-full-run sequencing for this step.

## Global constraints and evidence

- Modify only `Sources/AgentLoopCore/Kernel/Orchestrator.swift` and `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`. No fixture, UI, schema, new source file or source-boundary amendment.
- Preserve every existing await, Task, return, throw, catch, loop, task priority, cancellation, closure capture, ownership token and statement ordering. Do not extract closures, add callbacks/hooks, introduce async helpers or duplicate DB reads. No waitpid change, timeout increase, suite serialization or cancellation/persistence reordering.
- New events use `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`, closed stage cases, an existing canonical execution UUID and the fixed integer codes below. No reason, raw execution string, error, SQL, path, provider or user text; no synthetic UUID for invalid input.
- Reuse `haltExecutionDiagnosticEvent`; do not change its canonical UUID/gate behavior. At method entry it emits only for a canonical UUID; it does not replace, move or add throwing domain validation. The measured target was already validated by runtime cancel. Default-off returns before UUID parsing and adds no DB access, Task or decision input.
- Preserve all previous halt markers and fixture identity mappings. A new success-return marker is reached only after success. No new catches or defer-based unconditional success markers.
- The combined run was 1091 tests / 31 suites / 4 issues / exit 1. The target persistence operation itself took 16.962 ms; the unresolved 863.437 ms precedes it. Active-cleanup Task queue/start is later and cannot explain the earlier gap. Neither DB starvation, a deadlock, nor executor exhaustion is established.
- Reported preparation resources were about 4.6 GiB available / VM pressure 2. They permit this document preparation, not an assumption that another full run is safe. Parent owns a fresh resource check; do not rerun the full suite under unchanged pressure/disk constraints.

## Task 1: Instrument only the existing pre-persistence path

**Files:** Modify the two files above. No test edits or new tests. Existing target: `emergencyStopCancelsRunningBeforeWaitingForPlanner` in `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`.

**Interfaces:** Consume the existing `haltExecutionDiagnosticEvent(_:executionId:value:)`, `RuntimeLifecycleStage`, `claimCancellation`, `installCancellation`, and `EngineExecutionCancellationStateV1.resolve`. Produce only additional fixed stage cases and synchronous calls to the unchanged helper. No signature changes.

- [ ] **1. Parent freezes the two preimages and obtains source ownership.** Preserve all existing dirty changes. Read the independent plan review before editing. If approved cold-helper cleanup overlaps these files, parent applies the two reviewed changes under one source owner and reviews their combined diff before its single compile/focused cycle.

- [ ] **2. Append these exact stages to `RuntimeLifecycleStage`.** Keep all existing cases and logger implementation unchanged.

```swift
case haltCoordinatorEntered, haltCoordinatorStateLoadCalled, haltCoordinatorStateLoadReturned
case haltStateReadCalled, haltStateReadBodyEntered, haltStateReadBodyReturned
case haltCoordinatorTerminalPath
case haltClaimCancellationCalled, haltClaimCancellationEntered
case haltClaimCancellationSelected, haltClaimCancellationReturned
case haltInstalledCancellationQueued, haltInstalledCancellationStarted
case haltInstalledGateOpenCalled, haltInstalledGateOpenReturned
case haltInstalledGateWaitCalled, haltInstalledGateWaitReturned
case haltCancellationObserverCalled, haltCancellationObserverReturned
case haltCancellationResolveCalled, haltCancellationStateEntered
case haltCancellationStateSelected, haltCancellationResolverCalled
```

- [ ] **3. Insert coordinator and synchronous read markers.** Source anchors below refer to current code read on 2026-09-06; use symbols/statements if line numbers move.

| Existing location | Exact insertion and value |
| --- | --- |
| Coordinator `cancel(executionId:reason:)`, approximately :2385 | First statement: `haltCoordinatorEntered` using argument `executionId`, before unchanged reason validation. |
| Same method, `let execution = try loadExecutionAnyState(executionId)` | Immediately before: `haltCoordinatorStateLoadCalled`; immediately after: `haltCoordinatorStateLoadReturned`, value `execution.state == .running ? 0 : 1`. |
| `loadExecutionAnyState`, approximately :2886 | After its existing validation do/catch, immediately before its unchanged `return try contextResolver.database.pool.read`: `haltStateReadCalled`. First statement inside existing read closure: `haltStateReadBodyEntered`. After existing fetch/identity/redaction guard succeeds and immediately before its unchanged `return execution`: `haltStateReadBodyReturned`. All use existing `executionId`; no added capture list. |
| Coordinator existing `if execution.state != .running` branch | First statement: `haltCoordinatorTerminalPath`, value 1. Retain direct terminal persistence, `observeTerminalReceipt`, early return and their errors unchanged. This branch does not reach the existing resolver-persistence event. |
| Immediately around the existing `let claimed = try await completionRegistry.claimCancellation(...)` | `haltClaimCancellationCalled` before the declaration; `haltClaimCancellationReturned` after its entire expression, using `execution.id`. Both value 0. Keep the `makeHandle` closure and nested resolver closure text and captures unchanged. |

These are ordinary insertions, for example:

```swift
haltExecutionDiagnosticEvent(.haltCoordinatorStateLoadCalled, executionId: executionId)
let execution = try loadExecutionAnyState(executionId)
haltExecutionDiagnosticEvent(
    .haltCoordinatorStateLoadReturned, executionId: executionId,
    value: execution.state == .running ? 0 : 1
)
```

`haltStateReadCalled` → body entry brackets pool-read admission, not a proven DB lock. Body entry → body return includes the fetch and guards. Body return → coordinator load return includes pool-return overhead. These markers may also occur for other callers of this helper; correlate only the explicit target execution and recorded enclosing coordinator call. Do not claim invocation pairing when same-owner calls overlap.

- [ ] **4. Mark claim admission and exact selection.** In `claimCancellation`, approximately :1427, insert `haltClaimCancellationEntered` as first statement, before unchanged execution/reason validation. For each existing successful branch, insert `haltClaimCancellationSelected` after its existing `entries[executionId] = entry` and before its existing return, using these codes:

| Code | Existing branch |
| --- | --- |
| 1 | Existing attempt with `authorizedReceipt != nil`. |
| 2 | Existing attempt with `phase == .terminalOwned`. |
| 3 | Existing cancellation child whose `origin == .primary`. |
| 4 | Existing cancellation child whose `origin == .external`. |
| 5 | Existing `.cancellationRunning` attempt with no child and matching reason. |
| 6 | Newly installed external cancellation on an existing primary attempt. |
| 7 | Newly installed standalone external cancellation owner. |

For codes 3/4 use `entry.attempt?.cancellation?.origin == .primary ? 3 : 4` only in the existing `entry.attempt?.cancellation != nil` branch, after its reason guard; this is a fixed diagnostic branch classification, not new control flow. For codes 6/7 emit `didInstallStandaloneOwner ? 7 : 6` immediately after `entries[executionId] = entry` following `installCancellation`, before unchanged `installed.primaryToCancel?.cancel()` and gate open. The selected marker does not mean gate open or method return succeeded.

At both existing `try await installed.gate.open()` sites, in `claimCancellation` and `requestCancellationFromPrimary`, add `haltInstalledGateOpenCalled` immediately before and `haltInstalledGateOpenReturned` immediately after the await, inside the existing do. Use fixed value **0 external / 1 primary** respectively. Keep catch cancellation/rethrow unchanged. A return marker means the existing awaited call returned; it is not the exact internal instant the gate opened.

- [ ] **5. Mark the existing installed cancellation Task.** In `installCancellation`, approximately :1633–1715, insert `haltInstalledCancellationQueued` immediately before the existing `let task = Task {`; insert `haltInstalledCancellationStarted` as its first statement. All this step's events use `executionId` and value `origin == .external ? 0 : 1` to distinguish external and primary-origin tasks. Both values already occur in the existing Task capture footprint; add no owner object, token, capture list or Task.

Inside its existing do, add `haltInstalledGateWaitCalled/Returned` immediately around `try await gate.waitUntilOpened()`, then `haltCancellationObserverCalled/Returned` immediately around the existing `await self.cancellationCommandObserver(executionId)`. Preserve that observer call even when its configured closure is empty; do not change its initialization or install a diagnostic callback.

Insert `haltCancellationResolveCalled` immediately before the existing `result = .success(try await cancellationState.resolve(...))` statement, after both existing optional standalone-owner and lifecycle awaits. Do not pull the resolve expression into a new local or change the result/catch/primary-join/finishCancellation block. Observer returned → resolve called intentionally aggregates these optional existing lifecycle preparation awaits; if that residual is large, report it as unresolved preparation, not cancellation-state actor delay.

Representative exact insertion pattern:

```swift
haltExecutionDiagnosticEvent(
    .haltInstalledGateWaitCalled, executionId: executionId,
    value: origin == .external ? 0 : 1
)
try await gate.waitUntilOpened()
haltExecutionDiagnosticEvent(
    .haltInstalledGateWaitReturned, executionId: executionId,
    value: origin == .external ? 0 : 1
)
```

- [ ] **6. Mark cancellation-state selection and resolver admission.** In `EngineExecutionCancellationStateV1.resolve`, approximately :661, first statement emits `haltCancellationStateEntered` using existing `handle.executionId`. Preserve its reason validation, assignment and guards. Add `haltCancellationStateSelected` code 1 inside the existing `if let resolvedReceipt` immediately before its unchanged return; code 2 inside the existing `if resolutionInFlight`, before its unchanged continuation return; code 3 after the existing resolver guard succeeds and before `self.resolver = nil`. Expanding the single-line cached-return block for insertion is allowed; its original return and order remain identical.

Immediately before the existing `let receipt = try await resolver(handle, proposedReason)` inside its do, emit `haltCancellationResolverCalled` using `handle.executionId`, value 0. No return marker is needed because the next existing `haltCancellationPersistenceCalled` marks entry to the resolver's persistence body. Keep the existing resolver ownership clearing/restoration, waiter continuations and error propagation byte-for-byte other than these insertions.

- [ ] **7. Freeze and independently review the two-file diff.** Parent/writer records pre/post hashes and a concise implementation report. Reviewer checks source calls are synchronous opt-in-only inserts; enum additions are closed; no new task/capture ownership; every original await/task/return/throw/guard/catch stays in order; state-read return expression and all fixture assertions/deadlines remain unchanged. Any needed source-boundary expansion stops this supplement before execution.

- [ ] **8. Parent performs one compile plus one focused observation, combined with approved cold cleanup.** After reviews and a fresh resource decision, use the parent's existing compile workflow once, then the existing opt-in target `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run --skip-build RunTests --filter emergencyStopCancelsRunningBeforeWaitingForPlanner` once, provided the compile produced that executable. Capture complete stdout/stderr, exit status, exact RunTests PID, source hashes and lifecycle events with existing tooling. A compile that does not produce RunTests cannot justify `--skip-build`; parent must choose the compile command that produces it before starting this cycle. No worker runs Swift or extracts OSLog. Do not repeat for a preferred result. Focused pass checks instrumentation integration only; full runtime gate remains red. No new full run under unchanged high pressure.

## Interpretation and completion

Use target execution UUID `28DDA3B5-2950-472B-86BE-295951875755` only for the retained combined run; use the actual existing fixture identity mappings from any new run. Filter by exact parent PID and run window. Never assume a repeated test uses an old UUID.

For a newly installed cancellation, compare coordinator-called → entered; state-load and internal read boundaries; claim caller → actor entry → selection; installed Task queue → start → gate wait return; observer call → return; lifecycle preparation residual; resolve caller → cancellation-state entry/selection → resolver called → existing persistence called. Report actor-call intervals as admission plus any intervening synchronous work indicated by markers, not as proof of a particular executor problem. Gate-wait duration combines gate availability and continuation scheduling. Caller claim return may occur after the installed Task has progressed; these are overlapping branches, not one additive chain.

Codes 1/2 at claim selection are terminal/reconciled reuse and need no new installed task. Codes 3/4/5 reuse existing cancellation/outcome work; inspect that work's already recorded origin, and do not infer its queue time from a later claim. Primary-origin tasks can run independently of coordinator external cancellation. State codes 1/2 also reuse cached/in-flight resolution and do not call a new resolver. Missing markers prove neither failure type nor a blocked actor: invalid identity, original error, branch selection, dropped capture and ambiguous overlapping same-owner invocations remain explicit limitations. Do not create an invocation ID or counter to paper over ambiguity.

This document is complete when its exact placements and constraints receive independent plan review. Implemented diagnostics are complete only after separate source review, compilation and a retained, sufficiently correlated focused observation; an incomplete capture is reported as incomplete. Neither completion means the halt behavior is fixed, all four prior issues share a cause, or desktop/runtime acceptance is green. Any behavior repair or later broader run needs a separate evidence-backed parent decision.
