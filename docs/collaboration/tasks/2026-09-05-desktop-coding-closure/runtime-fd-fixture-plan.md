# 075 FD Fixture Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. The parent assigns implementation and independent review and remains the sole build/test owner.

**Goal:** Prevent 075's descriptor-reuse fixture from replacing another owner's FD while retaining its original drain/process/EBADF/second-close assertions.

**Architecture:** Self-exec the already built test runner into a distinct environment-selected 075 child that runs only the three FD-sensitive helpers. The parent awaits a native child owner; the child's sentinel allocator atomically acquires free slots and fails on occupied targets instead of replacing them.

**Tech Stack:** Swift 6, Foundation Thread, checked continuations, Darwin posix_spawn/waitpid/fcntl, existing Testing SPI runner.

**Spec:** `runtime-fd-fixture-diagnosis.md`, `runtime-repair-plan.md`, task `spec.md`. Direct RED evidence: `runtime-repair-full.log:1299`, `runtime-repair-full-crash.ips` and `runtime-repair-termination-system.log:5–8`.

## Global constraints

- Modify **only `Sources/AgentLoopTestSuite/CliBackendTests.swift`**. No production code, Package.swift, runner entry point, historical manifest or unrelated dirty changes.
- Parent captures the preimage and runs all builds/tests serially. Implementer performs no build/test/app launch. No commit, push, Provider calls or real data changes.
- Preserve all original one-second drain join limits, four-second surviving-group assertion, processGroupSurvived assertions, stop count, zero-worker/reaper checks, output checks, EBADF checks, managedPolicy on repeated finish and sentinel-survival checks.
- No skip, retry, timeout increase, suite serialization, swallowed cleanup error, guessed-PID/process-group kill, or unconditional dup2 into a released FD number.
- Existing 075/079 closed-stdio fixtures are otherwise unchanged. The new child mode must return before composition, help probing and closed-stdio recursion.
- Native child ownership is one thread and one direct child per invocation. Cancellation of the awaiting caller does not abandon the owned child or discard cleanup errors. No unbounded thread array or detached Swift Task wrapping a blocking wait.

### Task 1: Isolate and safely reclaim the descriptor fixture

**Files:** Modify/test `Sources/AgentLoopTestSuite/CliBackendTests.swift` only, specifically the private 075 fixture section, composition helpers 6–8, and the beginning of `p1f1_075CLIHelpCapabilityMismatchIsUnsupported`.

**Interfaces to add in that file:**

```swift
private enum P1F1D075FDChildMode: String, Sendable {
    case drain = "drain"
    case expectedFailure = "expected-failure"
}

private enum P1F1D075FDFixtureError: Error, Equatable {
    case invalidMode
    case invalidEvidence
    case descriptorOccupied(Int32)
    case systemCall(String, Int32)
    case childStatus(Int32, URL)
    case childTimeout
    case deliberateChildFailure
}

private func p1f1d075ClaimVacantDescriptor(
    source: Int32, target: Int32
) throws -> Int32
private func p1f1d075RunFDChild(mode: P1F1D075FDChildMode) async throws
private func p1f1d075RunFDChildBlocking(mode: P1F1D075FDChildMode) throws
private func p1f1d075RunFDChildBody(mode: P1F1D075FDChildMode) throws
```

- [ ] **1. Capture RED evidence and inspect the exact preimage.** Parent retains the current file and hash before implementation. Do not rerun unsafe dup2 to obtain another RED result: the faulting crash stack already proves the failure. Read the existing self-exec helpers at lines 2187–2273 and the composition/test entry at 3460–3575. Confirm only one call site executes each of the three FD-sensitive helpers after rerouting.

- [ ] **2. Replace destructive sentinel placement with atomic vacant-slot acquisition.** Keep ownership of an `open` result; if it already equals target, return it as the sentinel. Otherwise acquire the lowest free descriptor at or above target and require exact equality. The helper neither closes nor assumes ownership of source; its caller must close source exactly once. Its collision path owns and closes only the newly allocated descriptor. Suggested core:

```swift
private func p1f1d075ClaimVacantDescriptor(
    source: Int32, target: Int32
) throws -> Int32 {
    let acquired = Darwin.fcntl(source, F_DUPFD_CLOEXEC, target)
    guard acquired >= 0 else {
        throw P1F1D075FDFixtureError.systemCall("fcntl F_DUPFD_CLOEXEC", errno)
    }
    guard acquired == target else {
        guard Darwin.close(acquired) == 0 else {
            throw P1F1D075FDFixtureError.systemCall("close collision allocation", errno)
        }
        throw P1F1D075FDFixtureError.descriptorOccupied(target)
    }
    return acquired
}
```

In `p1f1d075AssertNoSecondDrainClose`, retain `source == target` handling and the existing sentinel array/defer. Replace only the unsafe duplication path with this helper, with checked source closure on both success and throw. Preserve the primary allocation error and record an additional closure error if both happen. Append only an actually owned target. Do not use a precheck followed by dup2; that still races.

- [ ] **3. Add a meaningful occupied-target regression using two owned descriptors.** Open source and target `/dev/null` descriptors, retain their ownership until teardown and call the helper with the already occupied target. Require `.descriptorOccupied(target)`, then require F_GETFD succeeds on both original descriptors. The helper may allocate/close a higher temporary descriptor but must leave the occupied target untouched. This test deliberately owns the target; it never manipulates another test's FD. Close both originals with checked results. Name it `p1f1d075FDClaimRejectsOccupiedTargetWithoutClosingIt` so focused selection can include it.

```swift
#expect(throws: P1F1D075FDFixtureError.descriptorOccupied(target)) {
    _ = try p1f1d075ClaimVacantDescriptor(source: source, target: target)
}
#expect(Darwin.fcntl(target, F_GETFD) >= 0)
#expect(Darwin.fcntl(source, F_GETFD) >= 0)
```

- [ ] **4. Implement the child-only body and early routing.** Add `AGENTLOOP_075_FD_CHILD_MODE` and `AGENTLOOP_075_FD_CHILD_EVIDENCE` environment keys. At the very beginning of the existing 075 test, if the mode key exists, require a known enum value and the evidence path, run the child body, and return. No defaulting an invalid mode to a normal test.

```swift
let environment = ProcessInfo.processInfo.environment
if let rawMode = environment["AGENTLOOP_075_FD_CHILD_MODE"] {
    guard let mode = P1F1D075FDChildMode(rawValue: rawMode) else {
        throw P1F1D075FDFixtureError.invalidMode
    }
    try p1f1d075RunFDChildBody(mode: mode)
    return
}
```

For `.expectedFailure`, throw `.deliberateChildFailure`; do not write completion evidence. For `.drain`, invoke the three original helpers in sequence, unmodified except the safe allocator from step 2. Move their existing diagnostic start/completed pairs (values 6, 7, 8) into the child body with one child diagnostic UUID. After each returns, accumulate its phase name, and after all return write exactly `live-drain\nsurviving-run\nsurviving-abort\n` to the evidence file with checked I/O. An evidence marker alone does not constitute passing: the Testing runner must exit zero, so nonthrowing `#expect` failures still propagate. Remove the three direct helper invocations from the parent composition and replace their contiguous section with `try await p1f1d075RunFDChild(mode: .drain)`. Other composition steps, especially 0–5 and 9, stay intact.

- [ ] **5. Implement the native child owner and awaitable facade.** Model executable validation/C-string vectors on the existing 075 self-exec helper, but use the checked Darwin spawn-attribute/FD-isolation seam in `Orchestrator.swift:8465–8565,8640–8670` (also present in `CliProcessBackend.swift:831–913`). Initialize `posix_spawnattr_t` and file actions, track which were initialized, check every setup result, set `Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)`, pass the attributes to posix_spawn, and check destruction of both initialized objects on all paths. The new child needs neither suspended launch nor a process group. It must not inherit unrelated concurrent-test DB/socket FDs or pipe write ends, which could keep other tests' EOFs open.

Spawn the exact current executable with `--filter p1f1_075CLIHelpCapabilityMismatchIsUnsupported` and the explicit mode/evidence environment. Do not mutate process-global environment. `/usr/bin/env` may be used with the existing vector helper; it execs the runner in the same owned PID. No shell string. Create the unique log **once** in the parent with `O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC`, mode `0o600`. Check creation and keep its owned FD at or above 3 (normalize by allocating a descriptor at least 3 and closing the original if necessary). Use explicit child file actions: addopen stdin on `/dev/null` read-only, adddup2 of that same owned log FD to stdout, adddup2 of that same FD to stderr, then addclose of the auxiliary log FD. Both child outputs must share one open file description and offset; do not separately open the pathname twice. These dup actions assign only the spawned child's standard descriptors, unlike the prohibited replacement of released FD numbers in the live parent fixture.

Check every file-action result. Close the parent's log FD exactly once immediately after successful spawn, and close it on every pre-spawn failure too. If parent log closure or spawn-object destruction fails after spawn, the child is already owned and must undergo checked termination/reap before returning the setup/cleanup error. The mode/evidence fixture directory and log are fresh per child; no inherited directory is deleted.

The outer facade uses `withCheckedThrowingContinuation` and a single `Thread` named `AgentLoop.test.fd-child`, QoS utility. Its closure calls the blocking helper, captures `Result<Void, Error>` and resumes once, including when the awaiting task has been canceled. It has no Task.detached or cancellation shortcut:

```swift
private func p1f1d075RunFDChild(mode: P1F1D075FDChildMode) async throws {
    try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let worker = Thread {
            let result: Result<Void, any Error>
            do {
                try p1f1d075RunFDChildBlocking(mode: mode)
                result = .success(())
            } catch {
                result = .failure(error)
            }
            continuation.resume(with: result)
        }
        worker.name = "AgentLoop.test.fd-child"
        worker.qualityOfService = .utility
        worker.start()
    }
}
```

The blocking helper alone owns spawn, polling, termination and reap. Poll only its returned PID with `waitpid(pid, &status, WNOHANG)`, retry EINTR, sleep 10 ms on the native owner between running observations, and use a **15-second whole-child watchdog**. This is a new child-containment cap (roughly one plus two four-second helper bounds and startup allowance), not a change to any existing assertion deadline. At expiry, send SIGKILL to that still-owned, unreaped direct PID and reap it with EINTR-aware waitpid before returning `.childTimeout`; the child body spawns no subprocesses. Never signal after a successful reap or ECHILD.

An unexpected wait error must not fall through to a plain throw that abandons a live child. Preserve it as the primary error and enter checked owned-child cleanup: retain the exact spawned PID, attempt termination only while unreaped-child ownership remains established, and complete EINTR-aware reap. ECHILD invalidates signaling authority and must surface explicitly as unresolved/unconfirmed child ownership, with PID/error/log paths; do not claim this owner reaped the child. If another wait/kill error prevents establishing termination/reap, surface that unresolved ownership together with the primary error, retain evidence, and fail the gate. Do not silently reinterpret an error as completion or send a signal to a potentially reused PID.

On normal completion require raw status zero and the exact phase evidence for `.drain`; a signal/nonzero status becomes `.childStatus(status, logURL)` and missing/wrong evidence becomes `.invalidEvidence`. **Before any successful fixture-directory removal, read the complete child log and evidence with checked I/O and emit their full contents into the parent test output**, bracketed by markers containing the mode, child PID, raw status and original paths. Emit the exact phase-marker bytes, not merely a summary. Use a test-private short output lock if needed to keep each emission contiguous; it must not serialize test execution or child waits. Parent verification retains the entire parent stdout/stderr, so the child evidence remains available after cleanup. A read/output failure blocks successful removal and retains the original files. Never tell the parent to inspect a deleted successful log.

On failures, emit all available child diagnostics and retain the original log/evidence directory for inspection. Record the child PID so the parent can extract lifecycle events for both parent and child. The expected-failure regression must also emit full diagnostics before its checked cleanup. Close all spawn-action/log/temporary descriptor ownership on both success and failure, recording secondary cleanup errors without replacing the original failure.

- [ ] **6. Add real child-failure propagation coverage.** Add `p1f1d075FDChildFailureReachesParent` as an async test. Invoke `p1f1d075RunFDChild(mode: .expectedFailure)` and require a nonzero `.childStatus(status, logURL)`, rejecting success, timeout, evidence error or another error type. The child early branch throws before any FD helper and returns nonzero through the real Testing runner. This verifies status propagation rather than merely checking a fabricated result value. Read the returned log and require it contains `deliberateChildFailure` before treating that status as the intended failure, then remove only `logURL.deletingLastPathComponent()` (the helper-created unique fixture directory) with checked cleanup. Record cleanup failures. This prevents an unrelated child crash from passing the negative-path test.

- [ ] **7. Review the one-file diff and publish the implementation report.** Verify `dup2` is absent from this sentinel helper, all original assertions/counts/deadlines remain, only one child runs the three helpers per composition, invalid child modes fail, child recursion is impossible, and the continuation resumes once after child cleanup or an explicitly reported unresolved-ownership failure. Confirm checked CLOEXEC_DEFAULT attributes/actions; one exclusively created log open description shared by child stdout/stderr; exactly-once parent log closure; no signaling after ECHILD/reap; and complete child log/phase evidence emitted before successful temp-directory removal. Save changed ranges, deviations, pre/post hash and pending verification in the task implementation report. No commit.

- [ ] **8. Parent-only focused verification and independent review.** Parent runs `swift run RunTests --filter p1f1d075FD` (allocator + failure propagation), then `swift run RunTests --filter p1f1_075CLIHelpCapabilityMismatchIsUnsupported`, each with complete stdout/stderr and actual exit status retained. In the retained parent output, inspect the embedded full child log, mode/PID/raw status and exact three phase markers; confirm the selected original test executed and no tests were skipped. Do not rely on a successful tempdir after the helper has removed it. Review source independently before proceeding. A child assertion failure must appear as a parent failure, and the occupied-target regression must leave both owned originals valid.

- [ ] **9. Parent-only full acceptance gate.** Once focused checks and independent review pass, run the default unfiltered authoritative `swift run RunTests`, retain complete output/exit status and collect lifecycle events for recorded parent **and child** PIDs. Require actual suite completion, original drain/Board/CLI/shell contracts and no guarded-FD crash. A passing child or focused test does not clear this gate. Diagnose any residual failure from its own evidence without widening deadlines, serializing the suite or claiming every old runtime issue had this cause.

## Review boundary

The crash provides sufficient RED evidence; do not intentionally reproduce the unsafe unowned dup2. This plan introduces no authority to alter the frozen runner or production cleanup. The parent will independently review this concrete plan before execution. Implementation and full acceptance are still pending.
