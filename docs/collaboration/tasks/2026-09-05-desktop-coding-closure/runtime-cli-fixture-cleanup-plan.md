# CLI mechanics fixture ownership cleanup implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Execute the single task below with parent-owned verification and independent review. No commit is authorized.

**Goal:** Ensure the three identified CLI mechanics tests join their launched stream and checked process cleanup on both successful and throwing test-body paths, without erasing the original failure.

**Architecture:** Construct the real backend stream synchronously before creating its consumer, so registration exists before any cleanup request. A small test-private lifetime helper retains one explicit cancellation task, captures the test-body result, and joins the uncancelled consumer before returning its real terminal result. Determine whether fixture files may be removed from actual process/reap/socket observations, not from a cancellation-request flag.

**Tech Stack:** Existing Swift 6, Swift Testing, Darwin process observations, and the real `CliProcessBackend`; no new dependency or production seam.

**Spec / evidence:** `runtime-base-analysis.md`, `runtime-base-full.log`, and the parent's `runtime-owned-test-cleanup-verified.log` in this directory; this is a bounded prerequisite of `spec.md`, not a readiness-cause fix.

## Global constraints

- Modify only `Sources/AgentLoopTestSuite/CliBackendTests.swift`; task reports and scoped preimages/diffs are the only other permitted writes.
- Preserve all three tests, their shell commands, their successful-path assertions, their existing grace values, the recorder's three-second readiness deadline, and the grandchild watcher’s 200 iterations with 10 ms sleep.
- Do not alter production cancellation, registry, scheduler, pipe readers, waiter admission, test-suite concurrency, or source-boundary manifests.
- Do not use `consumer.cancel()` as cleanup; cancelled stream termination starts fire-and-forget backend cleanup and can finish the consumer before that cleanup finishes.
- Do not add process-wide/group discovery and killing, direct test-side termination signals, cancellation retries, wider deadlines, serialization, or another deliberately leaked process as RED evidence.
- The existing observed leaks are meaningful RED: the completed run left the exact `c-346-B200` shell PID 10332 orphaned, and the parent separately verified and removed that and two older test-owned shell residues. Read the retained cleanup log for the authoritative identities and actual outcomes. Do not signal historical PIDs again.
- Parent owns all compiler/test invocations. No source writer during a parent Swift run. A focused pass is not full-suite acceptance. Do not repeat the full suite under unchanged pressure merely to validate this plan.
- If a checked cleanup remains unresolved, preserve both errors and the fixture path; retain its files and stop this work rather than guessing another PID or declaring cleanup complete.

## Current ownership facts

1. At current `CliBackendTests.swift:458–568`, both cancellation tests call `backend.launch(request)` inside `Task`, then throw from `waitForStdout` before `backend.cancel` and `consumer.value`. Their only defer removes the harness.
2. At `:258–323`, the grandchild watcher cancels its consumer and returns without joining it; its other branches also do not await the consumer.
3. `CliProcessBackend.launch` registers the execution synchronously in the stream builder, before starting its internal task (`CliProcessBackend.swift:357–384`). Moving just the cancellation call into a catch while leaving launch inside the consumer is insufficient: cleanup can receive `processNotRegistered`, then the consumer can subsequently register and launch a process.
4. `backend.cancel` finds that registration and waits for a shared cancellation task. Pending registration is awaited, cancellation waits for actual process completion, and `finalize` awaits reap/stdout/stderr and Board stop before publishing the stream’s terminal result (`:583–609`, `:1110–1121`, `:1123–1250`). Cancelling a consumer instead only invokes `requestStreamCancellation`, which starts an unjoined task (`:579–590`).
5. A completed execution is removed from the registry. Therefore `processNotRegistered` can race an already completed stream; it is not blanket proof of either successful cleanup or a leak. Classify only the exact matching execution ID, after joining the real consumer and checking its terminal result plus process/socket state.
6. A finalizer can report `pipeDrainIncomplete` after resource cleanup; that error is the expected subject of the grandchild test. It must remain visible and must not be converted into a success result. Other cleanup errors can also occur; actual process/reap/socket observations are required before deleting that fixture.
7. `awaitCompletion` is not a reliable independent hard containment bound: its throwing task group also owns a child awaiting the shared completion task. This plan does not promise a new bounded production join or solve a stuck finalizer. If joined cleanup hangs, retain evidence and report that separate production problem instead of detaching it again.

## Task 1: Checked lifetime for the three mechanics tests

**Files:**

- Modify/test: `Sources/AgentLoopTestSuite/CliBackendTests.swift`: the three named tests, narrow additions to their recorder/inspector/harness helpers, and one new forced-error regression.
- Create report: this task directory's `runtime-cli-fixture-cleanup-impl-report.md`.

**Interfaces consumed:**

```swift
CliProcessBackend.launch(_ request: CliProcessLaunchRequestV1)
    -> AsyncThrowingStream<CliProcessFrameV1, Error>
CliProcessBackend.cancel(executionId: String) async throws
    -> CliProcessExitEvidenceV1
CliMechanicsProcessInspector.send(signal: Int32, processGroupId: Int32) throws
CliMechanicsHarness.remove() // existing legacy callers remain unchanged
```

**Test-private interfaces produced:**

```swift
private actor CliMechanicsCancellationOwner {
    init(backend: CliProcessBackend, executionId: String)
    func cancel() async -> Result<CliProcessExitEvidenceV1, any Error>
    func resultIfRequested() async
        -> Result<CliProcessExitEvidenceV1, any Error>?
}

private struct CliMechanicsOwnedStreamReport {
    let body: Result<Void, any Error>
    let cancellation: Result<CliProcessExitEvidenceV1, any Error>?
    let stream: Result<[CliProcessFrameV1], any Error>
}

private func cliMechanicsRunOwned(
    backend: CliProcessBackend,
    request: CliProcessLaunchRequestV1,
    body: @Sendable (
        CliMechanicsFrameRecorder, CliMechanicsCancellationOwner
    ) async throws -> Void
) async -> CliMechanicsOwnedStreamReport

// Recorder additions; keep waitForStdout's semantics and deadline unchanged.
CliMechanicsFrameRecorder.completedResult()
    -> Result<[CliProcessFrameV1], any Error>?
CliMechanicsFrameRecorder.finish(result: Result<[CliProcessFrameV1], any Error>)

// Inspector addition: observations of this instance's actual successful SIGCONT sends.
CliMechanicsProcessInspector.continuedProcessGroups() -> [Int32]

// New checked variant, used by the three converted tests and the new regression only.
CliMechanicsHarness.removeChecked() throws
```

- [ ] **Step 1: Freeze the preimage and preserve the behavioral RED.**

Parent captures the current one-file preimage/hash and confirms the ongoing Swift invocation ended before an implementer writes. Cite the concrete orphan evidence above in the implementation report. Do not run the old failing path again to produce another orphan. The new regression is first added using the real lifetime helper introduced below; a compiler error for a missing helper is not behavioral RED.

- [ ] **Step 2: Add one synchronous-registration, single-cancel, joined-consumer owner.**

Implement the cancellation actor with these exact semantics. It retains the first result, including a failure; cleanup does not launch a second cancellation attempt.

```swift
private actor CliMechanicsCancellationOwner {
    private let backend: CliProcessBackend
    private let executionId: String
    private var task: Task<Result<CliProcessExitEvidenceV1, any Error>, Never>?

    init(backend: CliProcessBackend, executionId: String) {
        self.backend = backend
        self.executionId = executionId
    }

    func cancel() async -> Result<CliProcessExitEvidenceV1, any Error> {
        if let task { return await task.value }
        let backend = backend
        let executionId = executionId
        let created = Task {
            do {
                return Result<CliProcessExitEvidenceV1, any Error>.success(
                    try await backend.cancel(executionId: executionId)
                )
            } catch {
                return Result<CliProcessExitEvidenceV1, any Error>.failure(error)
            }
        }
        task = created
        return await created.value
    }

    func resultIfRequested() async
        -> Result<CliProcessExitEvidenceV1, any Error>?
    {
        guard let task else { return nil }
        return await task.value
    }
}
```

The owner helper must follow this control flow, without a throwing escape between stream creation and consumer join:

```swift
private func cliMechanicsRunOwned(
    backend: CliProcessBackend,
    request: CliProcessLaunchRequestV1,
    body: @Sendable (
        CliMechanicsFrameRecorder, CliMechanicsCancellationOwner
    ) async throws -> Void
) async -> CliMechanicsOwnedStreamReport {
    let frames = CliMechanicsFrameRecorder()
    let cancellation = CliMechanicsCancellationOwner(
        backend: backend, executionId: request.executionId
    )
    // This line must remain outside Task: it establishes registration now.
    let stream = backend.launch(request)
    let consumer = Task {
        var received: [CliProcessFrameV1] = []
        let result: Result<[CliProcessFrameV1], any Error>
        do {
            for try await frame in stream {
                received.append(frame)
                await frames.append(frame)
            }
            result = .success(received)
        } catch {
            result = .failure(error)
        }
        await frames.finish(result: result)
        return result
    }

    let bodyResult: Result<Void, any Error>
    do {
        try await body(frames, cancellation)
        bodyResult = .success(())
    } catch {
        bodyResult = .failure(error)
    }
    if await frames.completedResult() == nil {
        _ = await cancellation.cancel()
    }
    // Never replace this with consumer.cancel() or an unawaited cleanup Task.
    let streamResult = await consumer.value
    return CliMechanicsOwnedStreamReport(
        body: bodyResult,
        cancellation: await cancellation.resultIfRequested(),
        stream: streamResult
    )
}
```

Recorder `finish(result:)` stores that actual result, sets `didFinish`, and derives its existing `storedError` from the failure case. `completedResult()` returns the stored result. Preserve the existing `finish(error:)` API for unrelated callers if any remain; do not reset a finished recorder or invent successful frames. The report contains the value returned by the actual joined consumer, not a `consumerJoined` Boolean.

- [ ] **Step 3: Add non-destructive resource observations and explicit error aggregation.**

In the existing inspector, add a lock-protected `[Int32]` of successful `SIGCONT` sends. Append the exact `processGroupId` only when the existing actual `Darwin.kill(-processGroupId, SIGCONT)` returned zero. Do not record on `ESRCH`, do not change the existing sending/error semantics, and do not record unrelated PIDs from its `snapshots()` enumeration. Each inspector instance belongs to one harness. Expose an immutable snapshot with `continuedProcessGroups()`.

After `cliMechanicsRunOwned` returns, perform these actual checks before permitting `harness.removeChecked()`:

1. Exactly one positive process group was observed, and it equals the cancellation evidence PID/processGroupID when cancellation returned evidence. If no successful continuation was observed (for example, a prelaunch failure), report missing cleanup evidence and retain the fixture; do not guess a PID from the global child list.
2. The exact observed PID no longer exists: `Darwin.kill(pid, 0) == -1` with the immediately captured `errno == ESRCH`.
3. The exact process group no longer exists: `Darwin.kill(-pid, 0) == -1` with immediately captured `errno == ESRCH`.
4. The exact former child is no longer waitable: use **non-consuming** `waitid(P_PID, id_t(pid), &information, WEXITED | WNOHANG | WNOWAIT)`. Require `-1` and immediately captured `ECHILD`; retry only a syscall interrupted by `EINTR`, not a liveness outcome. Never use a reaping `waitpid` probe: a reused PID must not cause a test to steal another owner's child. `WNOWAIT`, `WEXITED`, and `waitid` are present in the local macOS SDK's `sys/wait.h`.
5. The harness Board socket is absent; use checked `lstat` and require `ENOENT`, not `fileExists` as the new cleanup-certification check. Existing successful-path `#expect` assertions remain as well.

Capture all observation failures as typed test-private errors with operation, PID/execution ID where applicable, and errno. These operations must send only signal **0**. A PID reuse or permission error is a failed observation, not authority to signal or reap it. Do not poll until a failing observation happens to pass.

Add a test-private aggregate with `primary: (any Error)?` and `cleanupFailures: [any Error]`, preserving the original body error object. Its description should list the primary and every cleanup failure plus the retained fixture path when removal is not allowed. Do not collapse errors to generic `unexpected error` or use `try?`.

Failure classification must be explicit:

- Any body failure remains the primary failure, including readiness, watchdog, assertion throws, cancellation failure, and the regression's deliberate marker.
- Successful cancellation evidence must retain all current assertions. Its `childReaped`, stdout/stderr EOF, positive PID, and matching group are evidence, not substitutes for the independent observations above.
- A cancellation failure is a cleanup failure, even when the stream later terminates; preserve the error. Only exact `processNotRegistered(request.executionId)` may be recognized as an already-completed-stream race, and only **after** all five observations pass and the joined stream has its allowed real terminal result: normal completion containing an `.exited` frame for cancellation tests, or the actual `pipeDrainIncomplete` failure for the grandchild test. If the body itself failed at an explicit cancellation call, retain that body failure regardless of this cleanup-race classification.
- A failed joined stream is also retained, except the explicitly expected `CliProcessBackendError.pipeDrainIncomplete` in the grandchild test. It is still present in the report for that test to assert. No other stream error is allowed. If it is the same error also returned from explicit cancellation, preserving both labelled observations is acceptable; suppressing either path's distinct error is not.
- Zero continuation observations, live child/group, waitable child, socket remaining, or observation syscall failure leaves removal disallowed. Report/retain the exact harness path. Never return a pass because a consumer or cancellation request merely finished.

Implement `removeChecked()` as a narrow new variant: attempt socket-authority close and exact harness-directory removal, retaining both errors in the aggregate if both fail. Keep `remove()` and its unrelated callers unchanged in this task. In the converted tests, replace the current unconditional defer with a guard initialized to safe removal before launch, set to **disallow** removal immediately before `cliMechanicsRunOwned`, and set back to allow only after the actual observations pass. In the defer, call `removeChecked()` in `do/catch` and record its actual error with `Issue.record(error)`; if removal is disallowed, record the retained fixture path instead. This ensures a setup error before launch also gets checked cleanup, while a body error after successful process cleanup still removes its fixture. A cleanup error recorded by defer does not replace a thrown primary error.

- [ ] **Step 4: Convert exactly the three existing tests.**

For each cancellation test, keep its harness/request/backend construction and login-environment prewarm unchanged. Replace its local consumer with `cliMechanicsRunOwned` and this body:

```swift
let report = await cliMechanicsRunOwned(backend: backend, request: request) {
    frames, cancellation in
    try await frames.waitForStdout("ready")
    _ = try await cancellation.cancel().get()
}
```

Perform Step 3's resource checks and error aggregation, then extract the report's successful cancellation evidence and execute every old evidence/signature/socket assertion. Do not permit a nil cancellation result to pass. Preserve `50 ms / 1 s / 1 s` for the escalation test and `1 s / 1 s / 1 s` for the checked-evidence test.

For the grandchild test, use the same helper; its body retains the current 200 × 10 ms watcher against `frames.completedResult()`. Replace only its early `consumer.cancel(); Issue.record(...); return` with a typed thrown watchdog error. Retain the exact shell command and 50 ms drain grace. On an actual result, require failure with `pipeDrainIncomplete`; success becomes a typed thrown `held pipe cleanup was reported as certain` error, and an unexpected failure is rethrown unchanged. After the helper returns, require the joined report's stream to contain that same expected failure, perform the actual resource observations, and retain both existing socket/signature assertions. There is no consumer cancellation in any branch.

- [ ] **Step 5: Add the real forced-error regression.**

Add `cliProcessBackendFixtureFailureStillJoinsRealCleanup` using a new unique harness identity (for example `"347"`, verified absent when drafting). Use the real staged `/bin/sh` and exactly the escalation test's TERM-ignoring command and grace configuration. Prewarm login as the existing tests do. Run the same lifetime helper; after real `waitForStdout("ready")`, require the inspector's single observed PID to be positive, have `getpgid(pid) == pid`, and pass `Darwin.kill(pid, 0) == 0`, then throw a typed `CliMechanicsForcedBodyFailure.afterReady` marker without asking the body to cancel.

```swift
let report = await cliMechanicsRunOwned(backend: backend, request: request) {
    frames, _ in
    try await frames.waitForStdout("ready")
    let groups = harness.processInspector.continuedProcessGroups()
    try #require(groups.count == 1)
    let pid = groups[0]
    try #require(pid > 0)
    try #require(Darwin.getpgid(pid) == pid)
    try #require(Darwin.kill(pid, 0) == 0)
    throw CliMechanicsForcedBodyFailure.afterReady
}
```

The deliberate error happens after a real live child is observed, and the helper—not the test body—must terminate it.

Before treating that marker as the expected primary failure, require actual cancellation success with `termSent`, `killSent`, `childReaped`, both EOF fields, and matching positive PID/group. Require the returned joined consumer result to succeed and contain an `.exited` frame. Perform all five actual resource observations from Step 3; preserve and fail on any additional cancellation/stream/resource/harness cleanup error. Assert the aggregate still carries the exact `.afterReady` primary error and no cleanup failures. Do not merely assert a local `cancelCalled`, `didFinish`, or `consumerJoined` flag.

If readiness fails instead of reaching the deliberate marker, the regression must still run the same cleanup path and fail with that real readiness error; it must not reinterpret it as the expected marker. Do not add a timer extension or a fake process implementation to make it pass.

- [ ] **Step 6: Parent-owned focused verification and independent review.**

After the sole source writer releases ownership, parent runs each command with complete unique stdout/stderr logs and captures the actual exit code:

```text
swift run RunTests --filter cliProcessBackendFixtureFailureStillJoinsRealCleanup
swift run RunTests --filter cliProcessBackendCancellation
swift run RunTests --filter cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe
```

Expected: the new forced-error regression passes while proving real TERM/KILL, reap, EOF, consumer completion, and process/socket absence; both original cancellation tests retain their original assertions; the grandchild test still proves `pipeDrainIncomplete`. Log the actual continued PID and execution ID in this fixture's evidence (no token, environment, argv payload, or broad process dump). On any failure, keep the full primary and cleanup evidence and the exact retained fixture path; do not claim readiness fixed.

Parent checks a scoped diff against the frozen preimage, the four targeted tests, all preserved deadlines/assertions, and confirms no new trap-loop process survives from these verification runs by the exact new evidence identity. A non-implementing reviewer must approve the source diff and complete logs. A full `swift run RunTests` remains a separate later gate, subject to the already recorded environmental-pressure stop rule.

## Completion / stop rule

This repair is complete only when the focused evidence and independent review prove the identified tests no longer abandon owned work on a throwing body, and the old mechanics assertions remain intact. It does **not** clear the existing full-suite red gate, attribute the three-second readiness miss, or establish that all production cleanup paths are bounded. If the helper cannot finish joining a real backend execution or cannot prove resource absence, report that precise underlying boundary and retain evidence; do not add guessed cleanup authority or remove the fixture anyway.
