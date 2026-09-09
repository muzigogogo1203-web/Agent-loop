# 065 cold-stream owned cleanup implementation plan

> **For agentic workers:** Use `superpowers:executing-plans` for this single bounded task. Parent assigns one source writer, owns runtime verification, and obtains responsibilities-separated review. Do not create more agents from this task.

**Goal:** Preserve the 065 cold-stream behavior while ensuring every post-launch body error is retained through one actual cancellation and an uncancelled stream join before the fixture can be closed or removed.

**Architecture:** Keep the synchronous launch at the current call site. Run the original readiness body without consuming the stream; capture its result, then create one detached cleanup task that awaits cancellation and subsequently drains that same stream. Independently certify the exact fixture resources before checked teardown, and exercise the error branch with a real forced error after readiness.

**Tech stack:** Swift 6 strict concurrency, Swift Testing, existing `CliProcessBackend`, Foundation and Darwin. No package or production changes.

**Spec:** `runtime-cold-gate-analysis.md` in this directory; repository `AGENTS.md` and the parent's bounded cleanup assignment. The analysis establishes the lifetime hole, not the cause of the readiness miss.

## Global constraints and frozen scope

- Checkout `/Users/muzi/Agent-loop`; branch `codex/desktop-coding-closure-20260905`; HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`. Preserve all pre-existing dirty changes.
- Sole implementation source: `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`. Test-private additions only. Do not edit `CliBackendTests.swift`, backend, registry, Board server, runner, Package.swift, or lifecycle diagnostic enums.
- Keep `p1f1_065CancellationCleansProcessAndCommitsOnce` intact as the original inventory entry. Its production-signature, injected-signature, pre-registration-abort and main cancellation/terminal-commit branches remain in their current order and retain their current assertions. Only its shared `gateHarness` teardown guard and cold segment change. Do not extract, skip or rewrite the other branches.
- Keep synchronous `gateBackend.launch(gateRequest)` at the cold call site. The stream has no iterator or consumer before the actual cancellation call. Do not use the eager-consumer `cliMechanicsRunOwned` helper.
- Original command remains `trap '' TERM; : > "$1"; while :; do :; done`; readiness remains three seconds and throwing 10 ms polling. Do not prewarm the login environment, change executor priority, start a readiness watcher/consumer, relax assertions or add timing retries.
- Keep backend defaults: TERM grace 5 s, KILL grace 2 s, pipe drain 1 s. The forced-error fixture uses these same values.
- No production shutdown/performance repair, OS-log extraction, application/Provider use, real data, keys, network, commit/push or cleanup of historical PIDs/roots. Only parent executes approved runtime commands after writer release.
- Parent reported approximately 4.6 GiB free disk and pressure level 2 at assignment. This is a pressure-constrained entry, not permission for a full-suite repetition. Recheck the current resource boundary before the single focused observation.

## Evidence and APIs checked during preparation

Current preimage SHA-256:

| File | SHA-256 |
| --- | --- |
| ExecutionEngineConformanceTests.swift | `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f` |
| CliProcessBackend.swift | `20d5b42d7b768c6e3eb3f6c3ea770e358d7a328358ba7d1fa9da810a0241ed89` |
| CliBackendTests.swift, reference only | `7e1ef3fb5f3b1a37b72cd21c4f0204f3a4aa5be6a0e98b3caec2c4f5f5f54d58` |
| runtime-cold-gate-analysis.md | `e546c7931e0bbffaed1b4ab1cddd4926e3a5749055114dc136755bdc427003ad` |

Source provides these exact APIs:

```swift
gateBackend.launch(gateRequest) // AsyncThrowingStream<CliProcessFrameV1, Error>
try await gateBackend.cancel(executionId: gateRequest.executionId)
// -> CliProcessExitEvidenceV1, with pid, processGroupID, status,
// termSent, killSent, stdoutEOF, stderrEOF, childReaped
gateRegistry.activeCount // synchronous Int
try gateHarness.socketURL(executionId: gateRequest.executionId)
try gateHarness.checkedCloseDirectoryAuthority()
gateHarness.processInspector.signalSnapshot // [Int32], preserve its semantics
```

The existing CLI fixture uses `Darwin.kill(target, 0)`, checked socket `lstat`, and `Darwin.waitid(P_PID, id_t(pid), &information, WEXITED | WNOHANG | WNOWAIT)`. Copy those non-consuming observation patterns locally; do not import its private helpers or change their access level. The runner force-links `AgentLoopTestSuite` and Swift Testing discovers `@Test` methods automatically. A new method within the existing serialized execution suite needs no runner or singleton inventory source change; record the extra discovered test in the new verification report without rewriting historical inventories.

### Task 1: Own and certify the cold gate, including its forced-error path

**Files:** Modify only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`; create implementation report/diff/evidence under this task directory after source work. The relevant preimage sections are the 065 enum/inspector/harness near lines 173–636, gate backend near 806, and complete 065 method near 4984–5409.

- [ ] **Step 1: Freeze reviewed inputs and retain the existing behavioral RED.**

Parent reviews this plan before granting the writer exclusive source ownership. At writer entry copy the exact source preimage to `runtime-cold-gate-cleanup-before/ExecutionEngineConformanceTests.swift`, record its hash and the approved plan hash, and verify the branch/HEAD. Preserve the surrounding dirty baseline. No runtime may overlap source ownership.

Use the retained `runtime-combined-full.log:2314–2315` `coldGateReadinessTimedOut` and analysis's traced skipped cancellation/join as the pre-fix behavioral RED. This proves a failing body follows the unsafe lifetime path; it does not prove a surviving orphan, nor provide current signal authority. Do not intentionally run the old path or add an unowned failing reproduction to produce a fresh red log. The real forced-error regression below runs only after owned cleanup is installed. State this explicit retained-RED exception in the implementation report.

- [ ] **Step 2: Add the smallest cold-specific lifetime helper and actual result carrier.**

Introduce the following test-private interfaces and control flow. The body receives no cancellation handle, so there is exactly one explicit backend cancellation on every path, whether readiness/body succeeded or threw. Do not add optional cancellation or a second retry. Keeping the actual stream result separate retains a launch/stream failure that would otherwise be obscured by readiness timeout.

```swift
private struct P1F1D065ColdIdentity: Sendable {
    let fixtureId: UUID
    let executionId: String
    let rootPath: String
}

private struct P1F1D065ColdCleanupResult: Sendable {
    let cancellation: Result<CliProcessExitEvidenceV1, any Error>
    let stream: Result<[CliProcessFrameV1], any Error>
}

private struct P1F1D065ColdOwnedReport: Sendable {
    let body: Result<Void, any Error>
    let cleanup: P1F1D065ColdCleanupResult
}

private func p1f1d065RunOwnedColdStream(
    stream: AsyncThrowingStream<CliProcessFrameV1, Error>,
    backend: CliProcessBackend,
    executionId: String,
    identity: P1F1D065ColdIdentity,
    body: @Sendable () async throws -> Void
) async -> P1F1D065ColdOwnedReport {
    let bodyResult: Result<Void, any Error>
    do {
        try await body()
        bodyResult = .success(())
    } catch {
        bodyResult = .failure(error)
    }
    // Created only after the readiness body settles; never cancel this task.
    let cleanup = Task.detached { () -> P1F1D065ColdCleanupResult in
        let cancellation: Result<CliProcessExitEvidenceV1, any Error>
        do {
            cancellation = .success(
                try await backend.cancel(executionId: executionId)
            )
        } catch {
            cancellation = .failure(error)
        }
        // No iteration exists before the actual cancel attempt settles.
        var frames: [CliProcessFrameV1] = []
        let streamResult: Result<[CliProcessFrameV1], any Error>
        do {
            for try await frame in stream { frames.append(frame) }
            streamResult = .success(frames)
        } catch {
            streamResult = .failure(error)
        }
        return P1F1D065ColdCleanupResult(
            cancellation: cancellation, stream: streamResult
        )
    }
    return P1F1D065ColdOwnedReport(
        body: bodyResult, cleanup: await cleanup.value
    )
}
```

`Task.detached` isolates the cleanup task's cancellation state from a cancelled caller; parent cancellation may throw from the body sleep but cannot cancel this consumer. The task is explicitly joined and retains the backend/stream until the real join completes. No throwing operation may escape between launch and report return: all throwing body work is inside the supplied body and all cleanup throws enter their actual `Result`. The helper must not throw, use `try?`, call `consumer.cancel()`, race a timeout and abandon a task, or trust stream `onTermination` as cleanup. It does not claim a new hard bound on production completion; a stuck join remains an observable blocked boundary with the root retained.

- [ ] **Step 3: Capture fixture-local actual signal identities without changing signal behavior.**

Add a lock-protected test-private record to `P1F1D065ProcessInspector`:

```swift
private struct P1F1D065SignalObservation: Sendable {
    let signal: Int32
    let group: Int32
    let target: Int32
    let result: Int32
    let errorNumber: Int32
}
// Add within the inspector:
// private var observedSignals: [P1F1D065SignalObservation] = []
// func signalObservations() -> [P1F1D065SignalObservation]
// { lock.withLock { observedSignals } }
```

At each of the two existing `Darwin.kill(-processGroupId, signal)` sites in `send`, evaluate the syscall once, capture errno immediately (`0` when successful), append the exact immutable record under the existing lock, and use the captured values in the unchanged existing `result == 0 || errorNumber == ESRCH` guard. Preserve `signals.append`, the injected-resume gate ordering, polling and thrown errors exactly. Do not turn accepted ESRCH into a successful continuation observation. Derive the cold PID only from actual successful SIGCONT records for that harness; never use the inspector's broad snapshots as an identity source.

For immediate safe diagnostics, add `private var coldIdentity: P1F1D065ColdIdentity?` to the inspector and `func configureColdDiagnostics(_ identity: P1F1D065ColdIdentity) throws`. Its lock-protected setter rejects a non-nil existing context by throwing a new `.coldDiagnosticsAlreadyConfigured` case in the existing fixture-error enum, then stores the identity. Configure before launch. Log that identity once before launch. Only when configured, print each actual signal record with fixture UUID/execution ID, signal, signed target, return and errno. The earlier gate signature branches make no signal calls, and the separate abort/main inspectors do not opt into this logging. Use only safe fixture-generated IDs/path and integer fields. No token, command/argv, stdin, environment, stdout or stderr payload, raw error description or request interpolation.

Use small phase messages in the cold call site/helper for launch-called/returned, readiness-start/end with the observed Bool, cancel-start/result, stream-join-start/result and decoded `.exited` status. Include the same fixture UUID/execution ID. Implement them as test-private diagnostic prints (optionally gated by existing `RuntimeLifecycleDiagnostics.isEnabled`); no production enum or logger edits. Successful cancellation result logs use the actual evidence PID/group/status/EOF/reap flags. Error logs include a controlled error category/type, not arbitrary interpolated error values. After join, print the final signal snapshot and resource observation outcomes even if diagnostic phase logging is disabled, making retained-root evidence useful in an ordinary focused log. Correlate to existing backend `cliSpawned` only by the observed real PID, not relative time. Do not claim a Board-server-owner mapping from that PID alone.

- [ ] **Step 4: Assess the actual cleanup and guard exact checked teardown.**

Add a test-private `P1F1D065ColdCleanupError: Error, CustomStringConvertible` with `primary: (any Error)?`, labelled cleanup failures retaining their actual error objects, and `retainedFixturePath: String?`. The primary is the exact body error object; do not replace it by the cleanup error. Its printable description identifies the controlled primary marker/timeout when known, otherwise only `String(reflecting: type(of: error))`, with labelled operation/result/errno fields and the exact retained fixture path. Do not interpolate arbitrary backend/stream error descriptions. A body failure alone still fails the ordinary cold gate after successful cleanup.

Add `p1f1d065AssessColdCleanup(report:harness:registry:socketURL:executionId:removalAllowed:) -> P1F1D065ColdCleanupError`, with `removalAllowed` as `inout Bool`. It collects all observations independently, with no early throw, before setting removal permission. Required certification:

```swift
private func p1f1d065AssessColdCleanup(
    report: P1F1D065ColdOwnedReport,
    harness: P1F1D065MechanicsHarness,
    registry: ShellProcessRegistry,
    socketURL: URL,
    executionId: String,
    removalAllowed: inout Bool
) -> P1F1D065ColdCleanupError
```

1. Exactly one successful SIGCONT record, with positive group, signed target `-group` and return zero. That group is the actual PID candidate for this cold fixture.
2. The real cancellation result succeeds with positive `pid`, `processGroupID == pid == observedGroup`, `childReaped`, `stdoutEOF` and `stderrEOF`. Preserve the actual cancellation failure if any; this narrow cold gate does not need the generic CLI helper's `processNotRegistered` race exemption. Missing or failed cancellation leaves teardown disabled.
3. `Darwin.kill(pid, 0)` and `Darwin.kill(-pid, 0)` each return `-1` and captured `ESRCH`. Record each failure, including permissions or PID reuse, rather than signalling it. These probes send only signal zero.
4. Non-consuming `waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT)` returns `-1/ECHILD`. Retry only EINTR. Never replace this by a reaping `waitpid`, omit WNOWAIT, or poll liveness until it passes.
5. Checked `lstat` of the exact precomputed Board socket returns `-1/ENOENT`; `registry.activeCount == 0`. Do not substitute `fileExists` or registry count alone for certification.
6. The actual joined stream succeeded and contains an `.exited` frame. Retain every failed joined-stream result as its own labelled cleanup failure, even if cancellation returned the same error. Preserve decoded exit statuses in the report/log; do not print buffered payload frames.

Only when all six conditions pass may `removalAllowed` become true. Zero successful continuation, mismatched identities, live or waitable child/group, socket presence, any syscall uncertainty, cancellation error or stream error retains the exact root and reports the failed condition. A pre-spawn error may conservatively retain a root because actual PID/reap evidence is unavailable; do not guess a PID or assert spawn absence from an empty registry. The primary failure never participates in deciding whether already-certified resources can be removed.

Add `P1F1D065MechanicsHarness.removeChecked() throws` for the converted cold gate/new regression only. It calls `checkedCloseDirectoryAuthority()` if the existing lock-protected `directoryAuthorityClosed` is false, then removes the exact `root` with throwing `FileManager.removeItem`. If closing fails, retain/report the root and stop teardown; if removal fails, retain/report that failure. Keep old `remove()` and every unrelated caller untouched. A checked close must never run while lifetime/resource certification is disallowed.

At original gate harness creation replace only its defer:

```swift
var gateRemovalAllowed = true // prelaunch setup still receives checked cleanup
defer {
    if gateRemovalAllowed {
        do { try gateHarness.removeChecked() }
        catch { Issue.record(error) }
    } else {
        Issue.record("retained 065 gate fixture: \(gateHarness.root.path)")
    }
}
```

This guard protects the shared gate root during its cold branch. It does not claim to repair lifetime paths in the other 065 harnesses. Their code and assertions remain outside this bounded change.

- [ ] **Step 5: Convert the original cold segment without changing its success contract.**

Precompute the exact socket URL and configure safe diagnostic identity before launch. Immediately before the existing synchronous launch set `gateRemovalAllowed = false`; no await intervenes. Keep the existing cold ready URL/deadline construction order after `launch`. Then pass that exact stream into the helper and place the original readiness loop/guard in its body, capturing the already-computed deadline:

```swift
let coldSocketURL = try gateHarness.socketURL(executionId: gateRequest.executionId)
let coldIdentity = P1F1D065ColdIdentity(
    fixtureId: UUID(), executionId: gateRequest.executionId,
    rootPath: gateHarness.root.path
)
try gateHarness.processInspector.configureColdDiagnostics(coldIdentity)
gateRemovalAllowed = false
let coldGateStream = gateBackend.launch(gateRequest)
let coldGateReadyURL = gateHarness.root.appendingPathComponent("cold-ready")
let coldGateReadyDeadline = ContinuousClock.now.advanced(by: .seconds(3))
let report = await p1f1d065RunOwnedColdStream(
    stream: coldGateStream, backend: gateBackend,
    executionId: gateRequest.executionId, identity: coldIdentity
) {
    while !FileManager.default.fileExists(atPath: coldGateReadyURL.path),
          ContinuousClock.now < coldGateReadyDeadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    guard FileManager.default.fileExists(atPath: coldGateReadyURL.path) else {
        throw P1F1D065MechanicsFixtureError.coldGateReadinessTimedOut
    }
}
```

Run Step 4 assessment immediately after this nonthrowing report returns. If its primary or cleanup failures are present, throw the aggregate with the original primary retained. Otherwise use `try report.cleanup.cancellation.get()` and `try report.cleanup.stream.get()` to bind `gateEvidence` and `gateFrames`. Keep all existing cold success assertions exactly: TERM, both EOFs, child reaped, exited frame, signature sequence `[.cli, .boardBridge]`, empty registry. Then continue to the existing main harness branch without modifying it.

- [ ] **Step 6: Add one bounded real forced-error-after-readiness regression.**

Add `@Test func p1f1_065ColdGateForcedFailureStillJoinsCleanup() async throws` inside the same serialized `ExecutionEngineConformanceTests` suite. Use a fresh `P1F1D065MechanicsHarness(label: "cold-error")`, local `ShellProcessRegistry()`, the normal fixture revalidator, `p1f1d065GateBackend`, execution ID `00000000-0000-4000-8000-000000000865` (not found in the inspected source), token `"8"`, and the identical cold command with its own `cold-ready` path. This is an independent fixture and does not extend the original method's pre-registration/signature setup. Configure its own fixture UUID and checked-teardown guard before launch.

Use the same synchronous launch, post-launch deadline and ownership helper. After the real 3 s / 10 ms readiness guard, require one successful SIGCONT observation, positive PID, `Darwin.getpgid(pid) == pid`, and `Darwin.kill(pid, 0) == 0`, then throw a new test-private `P1F1D065ColdForcedFailure.afterReady`. These `#require` calls and marker throw occur inside the owned body. The body must not request cancellation itself. Example addition to the readiness body:

```swift
let continued = harness.processInspector.signalObservations().filter {
    $0.signal == SIGCONT && $0.result == 0
}
try #require(continued.count == 1)
let pid = continued[0].group
try #require(pid > 0)
try #require(Darwin.getpgid(pid) == pid)
try #require(Darwin.kill(pid, 0) == 0)
throw P1F1D065ColdForcedFailure.afterReady
```

After the helper joins, run the identical six-condition assessment. In addition require actual `termSent` and `killSent` evidence, the original signature sequence, an exited frame, and matching positive PID/group. Catch any thrown evidence assertion and append it as a cleanup verification error while retaining the original primary. Accept the deliberate marker only when the aggregate's primary is exactly `.afterReady`, every cleanup condition passed and no cleanup error remains. A readiness timeout, cancellation error, stream error or assertion failure must fail with its actual retained evidence, never be recast as the expected forced marker. The guarded defer records checked close/removal failure as an additional test issue.

Keep runtime coverage bounded to the existing success path and this one real forced-error path. No additional unmanaged RED process, global kill, shortened backend grace, synthetic process-driver substitute or timeout expansion. Parent-cancellation safety follows the detached joined cleanup construction and is a review requirement; this plan does not claim a separate real cancellation-injection test.

- [ ] **Step 7: Release source and run one parent-owned focused observation after review.**

Writer emits `runtime-cold-gate-cleanup-impl-report.md` and a scoped before/after diff, records source hashes, `git diff --check`, preserved timing/assertions, retained-RED exception and unresolved concerns, then releases source ownership. Do not commit. Parent/reviewer statically verify every post-launch throw is inside ownership, cancellation occurs once, stream remains cold until cancel, unsafe teardown is disabled and other 065 branches are unchanged.

Parent then runs the single focused command, which should discover exactly the original 065 method and the new regression:

```text
swift run RunTests --filter p1f1_065
```

Capture complete stdout/stderr and the actual exit code in one unique task-directory log; preserve the approved source/plan hashes before and after. Do not run a separate uncontained old RED, concurrent runtime lanes, or the full suite here. Inspect the output to confirm both named tests actually executed; a zero-test run is not evidence. Retain the fixture-ID→execution-ID→actual signed signal-target→cancellation-PID/group→joined decoded exit-result joins and readiness start/end Bool, plus all absence/reap/socket/registry outcomes and any retained root. Existing backend diagnostics may be captured only through the parent's separately approved mechanism; this plan does not authorize OS-log extraction.

On a focused failure, blocked join, changed pressure boundary or uncertified fixture: preserve the exact evidence, do not rerun repeatedly, do not close/remove the unsafe root, and stop for a bounded next diagnosis. A stuck detached task is not permission to abandon ownership or signal an unverified historical PID. Any intervention needs current exact ownership and separately established authority. The non-implementing reviewer must review the actual diff and complete focused output before acceptance.

## Completion boundary

The change is acceptable only when both focused tests execute successfully, prove actual cleanup, preserve the old 065 mechanics assertions, and receive independent review. This clears only the known cold-gate lifetime defect. It does not establish why readiness originally missed three seconds, make all production completion paths bounded, fix other 065 harness lifetimes, or clear the existing red full-suite/runtime delivery gate. A full `swift run RunTests` remains a separate later gate under the recorded host-pressure rule.
