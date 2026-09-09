# CLI readiness boundary diagnostics implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. One bounded diagnostics-only task; parent owns compilation, the single paired observation run, and log extraction. No commit is authorized.

**Goal:** Attribute the reproducible three-second CLI readiness miss to a measured interval between test launch, process resume, stdout delivery, and recorder observation without changing the interval being tested.

**Architecture:** Extend the existing opt-in `RuntimeLifecycleDiagnostics` enum with fixed stages and numeric values. Reuse each execution's existing Core diagnostic UUID, publish its actual spawned PID, and join it to the test recorder UUID through existing fixture execution/PID evidence plus one opt-in test-only identity line. Add synchronous markers at existing boundaries; retain all task creation, await, read, cancellation, cleanup, and deadline behavior.

**Tech Stack:** Existing Swift 6, Swift Testing, OSLog, UUID + Int diagnostic schema, and `DispatchTime` monotonic timestamps already emitted by the logger.

**Spec / evidence:** `runtime-cli-fixture-cancellation.log`, `runtime-cli-fixture-cleanup-plan.md`, `runtime-base-analysis.md`, and the task directory's `spec.md`.

## Evidence and scope

The focused cancellation pair now fails reproducibly without a full-suite run: both readiness checks fail and the pair ends at **3.575 s**. The existing cleanup output identifies execution `…346` → actual PID `18904` and execution `…372` → actual PID `18905`, with **zero resource-observation failures** for both. The new forced-after-ready regression separately passed in the parent's run. The parent also reports the grandchild focused test passed in **0.642 s**, with zero resource-observation failures and its exact child absent afterward (`runtime-cli-fixture-grandchild.log`). These are different observations: cleanup success does not fix or explain readiness.

Current finalizer events are emitted after sequential awaits; they do not identify worker entry, actual `waitpid` return, or first output delivery. There is insufficient evidence to choose a native-thread change, task-pool explanation, or another runtime repair. This plan adds that evidence only.

## Global constraints

- Exactly three source files may change: `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`, `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`, and `Sources/AgentLoopTestSuite/CliBackendTests.swift`.
- No fourth source file, new dependency, execution/Board public API, new execution identity field, or global correlation registry is needed.
- Diagnostics remain disabled unless `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`. No new output or logging occurs by default. Do not change the existing environment gate, subsystem, category, log level, or `stage/owner/mono/value` format.
- Do not log stream contents, text, arguments, environment values, workspace paths, credentials, keys, Board tokens, or error descriptions. Allowed new values are fixed enum stages, random diagnostic UUIDs, the test fixture's validated execution UUID, actual child PID, byte count capped by the existing 4096-byte read, fixed outcome codes, and numeric syscall return/errno values.
- Do not add sleeps, yields, detached/native workers, task priorities, locks, waits, retries, cancellation calls, buffered output channels, new read calls, or process signals. Do not reorder existing async boundaries or resource ownership operations.
- Preserve all old assertions, the three-second readiness deadline and 20 ms recorder sleep, the grandchild 200 × 10 ms watcher, and every production grace duration. Do not replace the latest checked test cleanup with cancellation of the consumer.
- Every syscall error number must be captured before diagnostic code can modify `errno`. No logging occurs between a syscall and an existing uncaptured errno-dependent decision.
- Parent captures source preimages and hashes; the implementer does not build or test. Parent waits for the current Swift run to finish before authorizing source writes.

## Exact correlation contract

Use this evidence join, scoped to the actual parent RunTests process and invocation:

```text
test recorder UUID
  → opt-in test identity line containing recorder UUID + request.executionId
  → existing checked cleanup line containing executionId + continuedPIDs
  → new cliSpawned event containing Core owner UUID + actual spawned PID
  → all Core events using that same existing Core owner UUID
```

No relationship is inferred from chronological adjacency, similar durations, or UUID ordering. The new `cliSpawned` PID must match the existing actually observed successful `SIGCONT` PID; if that join is missing or ambiguous, report the missing identity edge instead of assigning events to a test by guesswork. Do not use historical PIDs for a later run.

In the logger, expose only a read-only `package static var isEnabled: Bool { enabled }` so the test-only identity print obeys the exact same gate. No logging overload is necessary. In `cliMechanicsRunOwned`, create one `let recorderDiagnosticId = UUID()`, pass it to the recorder's initializer, and print only under that gate:

```swift
if RuntimeLifecycleDiagnostics.isEnabled {
    print("CLI readiness identity recorder=\(recorderDiagnosticId.uuidString) execution=\(request.executionId)")
}
```

Keep this mapping print before launch, outside timed read/append loops. The existing cleanup evidence remains unchanged and is not newly gated.

## Task 1: Add only fixed, bounded readiness markers

**Interfaces consumed:** the current logger's `event(_:owner:value:)`; `CliProcessExecution.diagnosticId`; real `posix_spawn`, `waitpid`, and stream continuation; `CliMechanicsFrameRecorder` and `cliMechanicsRunOwned`.

**Interfaces produced:** new fixed enum cases; the logger's read-only gate accessor; one private `diagnosticOwner: UUID` parameter on `drainStdout`; one test-private immutable recorder diagnostic UUID. No changes to `CliProcessBackend` launch/cancel initializers or protocol.

- [ ] **Step 1: Freeze and review the diagnostics boundary.**

Parent saves preimages of the three files and their hashes. Use the failed paired log above as the repro evidence; a compile error for a missing enum case is not a behavioral RED. There is no speculative behavior fix to test-drive in this task. Record every added stage/value meaning below in the implementation report and check all call sites against that fixed vocabulary.

- [ ] **Step 2: Add logger enum stages and the opt-in gate accessor.**

Append the following cases; retain every existing case:

```swift
case cliRunQueued, cliRunStarted, cliLaunchInputsValidated
case cliEnvironmentRequested, cliEnvironmentReady, cliEnvironmentValidated
case cliBoardStartCalled, cliBoardStartReturned
case cliSpawnPreparationStarted, cliPosixSpawnCalled, cliSpawned, cliSpawnFailed
case cliSuspendedValidationCalled, cliSuspendedValidationReturned
case cliReapTaskQueued, cliReapTaskStarted, cliWaitpidReturned, cliWaitpidError
case cliStdoutTaskQueued, cliStdoutTaskStarted, cliStdoutDrainEntered
case cliStdoutFirstBytes, cliStdoutFirstLineYielded
case cliStderrTaskQueued, cliStderrTaskStarted
case cliSIGCONTCalled, cliSIGCONTReturned
case cliFixtureLaunchCalled, cliFixtureLaunchReturned
case cliFixtureConsumerQueued, cliFixtureConsumerStarted
case cliFixtureBodyStarted, cliFixtureFirstStdoutReceived
case cliFixtureFirstStdoutRecorded, cliFixtureStreamFinished
case cliFixtureReadyAwaitQueued, cliFixtureReadyWaitStarted, cliFixtureReadyWaitEnded
case cliFixtureConsumerJoined
```

All unlisted values below are `0`. Do not repurpose an existing finalizer stage as worker-entry evidence.

- [ ] **Step 3: Mark the existing Core run, spawn, and reap boundaries.**

Every event uses the existing `CliProcessExecution.diagnosticId`:

| Stage | Exact placement / value |
| --- | --- |
| `cliRunQueued` | In `start()`, immediately before its existing `Task { [self] ... }`; registration already exists. |
| `cliRunStarted` | First statement of `run()`, before validation. |
| `cliLaunchInputsValidated` | Immediately after `try validateLaunchInputs()` succeeds. |
| `cliEnvironmentRequested` / `cliEnvironmentReady` | Immediately before / after the existing `await LoginShellEnvironment.shared.environment()`. No LoginShellEnvironment file change. |
| `cliEnvironmentValidated` | Immediately after existing environment merge/Board-field preparation and `try validateEnvironment(environment)` succeed. |
| `cliBoardStartCalled` / `cliBoardStartReturned` | Immediately before / after existing `try boardServer.start()`. These do not pretend to be its private Board owner UUID. |
| `cliSpawnPreparationStarted` | First statement of `spawn(environment:server:)`, before existing pipe/action/attribute setup. |
| `cliPosixSpawnCalled` | Immediately before the existing `request.spec.command.withCString` / `posix_spawn` call block. |
| `cliSpawnFailed` | Inside the existing `guard code == 0` failure branch, value `Int(code)`; preserve the same throw. |
| `cliSpawned` | Immediately after that guard succeeds, value `Int(pid)` from actual `posix_spawn`; no synthetic/future PID. |
| `cliSuspendedValidationCalled` / `cliSuspendedValidationReturned` | Immediately before / after existing `validateSuspendedImage`, value `Int(pid)`. |
| `cliSIGCONTCalled` / `cliSIGCONTReturned` | Immediately before / after the existing `processInspector.send(signal: SIGCONT, processGroupId: ...)`, value actual group/PID. The latter means the inspector call returned; match the fixture's actual successful continuation evidence. |

In `spawn`, copy `let diagnosticOwner = diagnosticId` once into a local UUID for worker captures. Do not capture/retain `self` solely for diagnostics or modify existing task lifetime.

Add `cliReapTaskQueued` immediately before creating the existing detached reap task, and `cliReapTaskStarted` as its first statement. Keep that task detached, keep its blocking wait exactly as-is, and use this terminal-return instrumentation shape:

```swift
let result = waitpid(childPID, &rawStatus, 0)
let waitError = result < 0 ? errno : 0
if result == childPID {
    RuntimeLifecycleDiagnostics.event(
        .cliWaitpidReturned, owner: diagnosticOwner, value: Int(result)
    )
    reapState.markExited()
    return CliProcessReapResult(
        status: Self.decodeWaitStatus(rawStatus), failure: nil
    )
}
if result < 0, waitError == EINTR { continue }
RuntimeLifecycleDiagnostics.event(
    .cliWaitpidReturned, owner: diagnosticOwner, value: Int(result)
)
if result < 0 {
    RuntimeLifecycleDiagnostics.event(
        .cliWaitpidError, owner: diagnosticOwner, value: Int(waitError)
    )
}
// Retain the existing detail selection, markExited, and failure return here.
```

The existing trailing code remains exactly:

```swift
let detail = result < 0
    ? "waitpid failed"
    : "waitpid returned an unexpected child"
reapState.markExited()
return CliProcessReapResult(status: nil, failure: detail)
```

Only the final non-`EINTR` result is logged; interrupted waits retain their existing retry rule without per-interruption log volume. `cliReapTaskStarted → cliWaitpidReturned` includes the wait and any existing EINTR loop; it is not a separate measurement of runnable time.

- [ ] **Step 4: Mark stdout admission, first data, and actual first yield.**

Place `cliStdoutTaskQueued` immediately before the existing detached stdout task and `cliStdoutTaskStarted` as its first statement. Add `diagnosticOwner` to that closure's existing explicit capture list, and pass it through the sole private `drainStdout` call. Mark `cliStdoutDrainEntered` as that function's first statement. Do not introduce a new task or change `await Self.drainStdout(...)`.

Inside `drainStdout`, add two local Boolean diagnostic latches initialized to false. In its existing synchronous `onData` callback, before appending to `lineBuffer`, emit `cliStdoutFirstBytes` once with `value: data.count`, then set that latch. This marks the first successful nonempty read delivered to the synchronous callback (after the existing bounded Data copy); it is **not** a timestamp of when the child wrote. Do not edit `drainPipe`, its backoff, its buffers, or its reads for this task.

At both existing stdout `continuation.yield` sites (newline and final unterminated line), capture the return of the **same single** existing call, and emit `cliStdoutFirstLineYielded` only for the first call after it returns:

```swift
let yieldResult = continuation.yield(
    .stdoutLine(String(decoding: line, as: UTF8.self))
)
if !didLogFirstLine {
    didLogFirstLine = true
    let outcome: Int
    switch yieldResult {
    case .enqueued: outcome = 0
    case .dropped: outcome = 1
    case .terminated: outcome = 2
    @unknown default: outcome = 3
    }
    RuntimeLifecycleDiagnostics.event(
        .cliStdoutFirstLineYielded,
        owner: diagnosticOwner, value: outcome
    )
}
```

For the final-line site, retain its original `String(decoding: lineBuffer, as: UTF8.self)` expression and its original `lineBuffer.removeAll()` position. Do not add an extra yield, decode a line twice, log the associated `.dropped` payload, or change how a yield result affects control flow: the captured disposition is diagnostic only. The first-line marker means the continuation returned its actual disposition, not that an actor already received the line.

Add `cliStderrTaskQueued` / `cliStderrTaskStarted` around the existing stderr task creation/entry as well. This identifies whether that sibling is admitted; there is no stderr content, first-byte, or drain-function instrumentation because the target readiness signal is stdout. No stdin change is needed.

- [ ] **Step 5: Mark fixture consumption, actor delivery, and the unchanged deadline.**

The recorder gains `nonisolated let diagnosticId: UUID` initialized by a test-private `init(diagnosticId: UUID)`. Only `cliMechanicsRunOwned` currently constructs this recorder. It uses the single UUID from the correlation section; no await is added just to fetch identity.

In that helper add these markers, all owned by `recorderDiagnosticId`:

- `cliFixtureLaunchCalled` / `cliFixtureLaunchReturned` immediately around the current **synchronous** `let stream = backend.launch(request)`.
- `cliFixtureConsumerQueued` immediately before its current consumer `Task`; `cliFixtureConsumerStarted` as that task's first statement.
- A consumer-local first-stdout latch: after `for try await frame in stream` returns the first `.stdoutLine`, emit `cliFixtureFirstStdoutReceived` before the existing `received.append(frame)` / `await frames.append(frame)`. Never log the line and never insert another actor call.
- `cliFixtureBodyStarted` immediately before the existing `try await body(frames, cancellation)`.
- `cliFixtureConsumerJoined` immediately after the existing `let streamResult = await consumer.value`, value `0` for success or `1` for failure. No error formatting.

In `CliMechanicsFrameRecorder.append`, retain `frames.append(frame)` and emit `cliFixtureFirstStdoutRecorded` immediately after the first actual `.stdoutLine` append, using one actor-isolated Boolean latch. This is an actual recorder mutation marker, not a consumer-request marker. In `finish(result:)`, emit `cliFixtureStreamFinished` after its existing `didFinish = true`, value `0` for success / `1` for failure.

At the existing `waitForStdout("ready")` call in **each of the two cancellation tests and the forced-after-ready regression**, emit `cliFixtureReadyAwaitQueued` immediately before the existing `try await` call, owned by `frames.diagnosticId`. This disambiguates caller-side actor admission from the recorder's own deadline start; keep the actual awaited method unchanged.

Instrument `waitForStdout` with this shape. Keep the original deadline expression, loop, guard, and thrown errors:

```swift
let deadline = ContinuousClock.now.advanced(by: .seconds(3))
RuntimeLifecycleDiagnostics.event(
    .cliFixtureReadyWaitStarted, owner: diagnosticId, value: 3000
)
var diagnosticOutcome = 4
defer {
    RuntimeLifecycleDiagnostics.event(
        .cliFixtureReadyWaitEnded, owner: diagnosticId, value: diagnosticOutcome
    )
}
while !frames.contains(.stdoutLine(expected)),
      !didFinish,
      ContinuousClock.now < deadline
{
    try await Task.sleep(for: .milliseconds(20))
}
guard frames.contains(.stdoutLine(expected)) else {
    if let storedError {
        diagnosticOutcome = 1
        throw storedError
    }
    diagnosticOutcome = didFinish ? 2 : 3
    throw CliProcessBackendError.processLaunchFailed("process did not become ready")
}
diagnosticOutcome = 0
```

Codes: `0` matched expected frame; `1` stored stream error; `2` stream finished without the expected frame; `3` loop reached its deadline without the frame/finish; `4` a throwing escape from the unchanged sleep before classification. Do not use the diagnostic value to change an error or decide success. The start event occurs immediately after the real deadline is created; report the observed marker interval rather than claiming the logger has an independent copy of the clock's deadline instant.

- [ ] **Step 6: Source review, one parent-owned paired observation, and attribution report.**

Parent first reviews the three-file scoped diff for unchanged task/await/read/cancellation/timeout semantics and privacy, then compiles and runs **one** paired observation with full unique stdout/stderr logging:

```text
AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests --filter cliProcessBackendCancellation
```

Capture the actual parent RunTests PID and run start/end, actual exit code, source hashes, and complete OSLog events from `com.muzi.agentloop` / `runtime-lifecycle` for that process and interval. Retain the full CLI output containing both identity mappings and existing checked cleanup evidence. A failing pair is useful diagnostic evidence and remains red. If it passes with instrumentation, report that observed outcome and possible observation sensitivity; do not claim this diagnostics-only change fixed readiness or run repeatedly until a preferred result appears.

For each exactly joined execution, report timestamp differences and boundary ordering for:

1. Fixture launch-called → Core run-queued → Core run-started: synchronous launch/registration versus internal run-task admission.
2. Run-started → input validation → environment request/return → environment validated → Board start-called/returned → spawn preparation → actual spawn → suspended validation → SIGCONT-called/returned.
3. Actual first stdout bytes / first yield relative to SIGCONT and the existing three-second recorder deadline; first-byte timing alone cannot separate when the child writes from when its reader is scheduled.
4. Reap/stdout/stderr queued → worker started; stdout task-started → drain-entered; reap-started → actual terminal `waitpid` return. Do not label a blocked wait's duration as admission delay.
5. Core first yield disposition → fixture first stdout received → recorder first stdout recorded → readiness end; queued actor await → actual deadline start is a separate interval.
6. If first output appears only after readiness fails and checked cancellation occurs, retain that exact ordering. It is evidence about the blocked interval, not automatically proof of any particular scheduler mechanism.

Use full `mono` values for within-run comparisons, not sorted display timestamps alone. A missing phase or identity edge remains an explicit evidence gap. Check existing post-run resource observations still report zero failures; any new cleanup error blocks acceptance. No full-suite run is required for this observation task.

## Completion / stop rule

The diagnostics task is complete when its source-only independent review passes, it compiles, and the one paired observation has a complete retained identity/timing report. A compiler/capture failure blocks completion and must be reported precisely. This task does not clear the failed runtime gate. Select any behavior repair only from the resulting measured boundary and a separately reviewed bounded plan; do not preselect a Thread conversion, raise a timeout, change suite concurrency, or infer that every outstanding failure shares this cause.
