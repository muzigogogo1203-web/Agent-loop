# CLI signal attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this one bounded task after parent approval; the parent assigns implementation and independent review.

**Goal:** Retain actual cancellation/exit evidence even when readiness fails, and distinguish fixture-owned signals from registry-issued signals to that exact process/group.
**Architecture:** Extend the existing opt-in fixed lifecycle logger at two existing signal call sites and the already-joined fixture report. Do not change process behavior, registry ownership, or readiness scheduling; this is diagnosis, not a readiness repair.
**Tech Stack:** Swift 6, Darwin kill/errno, existing UUID + Dispatch uptime nanosecond logger, authoritative RunTests.
**Spec:** `runtime-recheck-cli-analysis.md` in this task directory and the parent's bounded signal-diagnostic request; that request narrows the earlier report's proposed raw-wait-status extension to three files initially.

## Global Constraints

- Sole source scope: the three files below; preserve every original CLI 346/372/347/152 assertion, command, deadline, cleanup path and earlier FD-child 075 behavior. No manifest, production backend, Orchestrator, first-read/wake, reaper or timeout changes.
- Preserve synchronous launch, retained cancellation task, exactly-once existing cancellation-result await, uncancelled consumer join, primary/cleanup aggregation and evidence-before-deletion. No extra tasks, actors, locks, sleeps, awaits, signals, retries, probes or registry injection.
- Preserve `terminateAll` snapshot + clear under its existing lock, unlock before iteration, unsorted Set iteration and exactly one existing SIGTERM per entry. Record failures without changing its existing return/control semantics.
- All additions use `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`, existing subsystem/category/notice level and fixed `stage/owner/mono/value` format. Only fixed numeric codes, actual PID/group/signal/status/errno/flags and ephemeral UUIDs; no command, path, environment, output bytes, error descriptions or secrets.
- Logging adds observation overhead; do not claim literally identical timing. Capture syscall errno immediately before any logging; never interpret stale errno after a successful syscall.
- No implementation or runtime commands during plan review. No commit, providers, apps, process signals or new agents by the reviewer. Parent owns the sole later combined observation.

### Task 1: Attribute signals and retain the failed-body report

**Files:** Modify `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` (fixed stages/helpers), `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift` (`terminateAll` only), `Sources/AgentLoopTestSuite/CliBackendTests.swift` (`CliMechanicsProcessInspector.send` and joined `cliMechanicsRunOwned` report only).
**Interfaces:** Consume existing `event(_:owner:value:)`, `isEnabled`, `CliProcessExitEvidenceV1`, `CliProcessFrameV1`, and `resultIfRequested()`; add only the two package diagnostic helpers below. No public API or lifecycle contract change.

- [ ] **Step 1: Freeze inputs and retain the known red evidence.** Parent/writer save the three preimages and source manifest before editing; current SHA-256 values, respectively: `42ab4d8d418b6ebfc54d7c5d125fa17b0980250754558dbe80387cc9249d03c1`, `753469a932406c56a0dd696f046acb0c5b6179f56cb0a5a194a737c3efc64154`, `0a0821f7f9d283290c6db9b7f7a1723385228a63c7ef34fa0b89a69de5875f7d`. Retain the existing full recheck: 346 no positive stdout, readiness 3020.788 ms, exact wait return 0.199 ms later; 347/372 passed. Do not rerun to reproduce before adding the missing evidence.

- [ ] **Step 2: Add fixed signal stages and gated helpers.** Add enum cases `processSignalPath`, `processSignalTarget`, `processSignalNumber`, `processSignalResult`, `processSignalErrno`. Path codes: 0 = fixture inspector, 1 = non-shared registry, 2 = shared registry; target is the signed argument actually passed to kill, never its absolute value. Add these helpers inside the existing diagnostics enum:
```swift
package static func signalWillSend(target: Int32, signal: Int32, path: Int) -> UUID? {
    guard isEnabled else { return nil }
    let owner = UUID()
    event(.processSignalPath, owner: owner, value: path)
    event(.processSignalTarget, owner: owner, value: Int(target))
    event(.processSignalNumber, owner: owner, value: Int(signal))
    return owner
}
package static func signalDidSend(owner: UUID?, result: Int32, errorNumber: Int32) {
    guard let owner else { return }
    event(.processSignalResult, owner: owner, value: Int(result))
    event(.processSignalErrno, owner: owner, value: result == 0 ? 0 : Int(errorNumber))
}
```
Each syscall gets its own UUID, including concurrent calls and failures. `processSignalNumber` precedes the call and `processSignalResult` follows it; these bracket the syscall, not an invented exact kernel timestamp.

- [ ] **Step 3: Instrument the two existing calls, without moving their ownership logic.** In fixture `send`, insert the first line before the existing kill and the last line immediately after its existing errno capture; keep the existing ESRCH guard and successful-SIGCONT `continuedGroups.append` unchanged:
```swift
let diagnostic = RuntimeLifecycleDiagnostics.signalWillSend(target: -processGroupId, signal: signal, path: 0)
let result = Darwin.kill(-processGroupId, signal)
let failure = errno
RuntimeLifecycleDiagnostics.signalDidSend(owner: diagnostic, result: result, errorNumber: failure)
```
In `terminateAll`, leave the lock/snapshot/clear/unlock block intact. Replace only the existing loop body's kill with:
```swift
let diagnostic = RuntimeLifecycleDiagnostics.isEnabled
    ? RuntimeLifecycleDiagnostics.signalWillSend(target: pid, signal: SIGTERM, path: self === Self.shared ? 2 : 1)
    : nil
let result = kill(pid, SIGTERM)
let failure = errno
RuntimeLifecycleDiagnostics.signalDidSend(owner: diagnostic, result: result, errorNumber: failure)
```
No UUID allocation or logging inside the registry lock; shared-instance comparison occurs only when diagnostics are enabled. Do not instrument register/unregister, signal-0 existence checks or other LoginShellEnvironment code.

- [ ] **Step 4: Emit the actual joined report on success AND failed readiness.** Add enum cases `cliFixtureCancellationState`, `cliFixtureCancellationPID`, `cliFixtureCancellationGroup`, `cliFixtureCancellationStatus`, `cliFixtureTermSent`, `cliFixtureKillSent`, `cliFixtureChildReaped`, `cliFixtureStdoutEOF`, `cliFixtureStderrEOF`, `cliFixtureExitFrameCount`, `cliFixtureExitFrameStatus`. After the existing consumer-joined event, hoist the return expression's existing single await into a local; emit the following gated values, then return the unchanged body/stream plus that exact `cancellationResult`:
```swift
let cancellationResult = await cancellation.resultIfRequested()
if RuntimeLifecycleDiagnostics.isEnabled {
    let state: Int
    switch cancellationResult {
    case nil: state = 0
    case .some(.failure): state = 1
    case .some(.success(let e)):
        state = 2
        let fields: [(RuntimeLifecycleStage, Int)] = [
            (.cliFixtureCancellationPID, Int(e.pid)), (.cliFixtureCancellationGroup, Int(e.processGroupID)),
            (.cliFixtureCancellationStatus, Int(e.status)), (.cliFixtureTermSent, e.termSent ? 1 : 0),
            (.cliFixtureKillSent, e.killSent ? 1 : 0), (.cliFixtureChildReaped, e.childReaped ? 1 : 0),
            (.cliFixtureStdoutEOF, e.stdoutEOF ? 1 : 0), (.cliFixtureStderrEOF, e.stderrEOF ? 1 : 0)
        ]
        for (stage, value) in fields { RuntimeLifecycleDiagnostics.event(stage, owner: recorderDiagnosticId, value: value) }
    }
    RuntimeLifecycleDiagnostics.event(.cliFixtureCancellationState, owner: recorderDiagnosticId, value: state)
    if case .success(let received) = streamResult {
        let statuses = received.compactMap { frame -> Int32? in
            if case .exited(let status) = frame { return status }; return nil
        }
        RuntimeLifecycleDiagnostics.event(.cliFixtureExitFrameCount, owner: recorderDiagnosticId, value: statuses.count)
        if let status = statuses.first { RuntimeLifecycleDiagnostics.event(.cliFixtureExitFrameStatus, owner: recorderDiagnosticId, value: Int(status)) }
    }
}
```
State 0 means no cancellation requested, 1 actual failure (no invented flags), 2 actual evidence; successful-stream count 0 is distinct from stream failure, already reported by consumer-joined outcome. Log only first exited status plus count, never silently assume exactly one. Both statuses are existing **decoded** statuses, not raw wait status: 143 alone cannot distinguish normal exit(143) from SIGTERM. Raw wait instrumentation requires a separately reviewed fourth-file expansion if these observations remain insufficient.

- [ ] **Step 5: Freeze and independently review the entire scoped diff.** Writer records pre/post hashes and report, then releases source. Parent/reviewer verifies only these three source files changed for this task, no ordinary-path new allocation or logs, unchanged snapshot semantics, immediate errno snapshots, unchanged send guards/SIGCONT record, one existing await, exact result/error retention and unchanged assertions/deadlines. Board changes belong to their separate reviewed task. Source approval is not runtime acceptance.

- [ ] **Step 6: Parent performs one combined observation only after Board correction and both source reviews.** Parent freezes combined hashes, captures resources, and runs the existing authoritative `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests` workflow once with complete stdout/stderr, process identity and unified-log capture retained in unique task artifacts; verify hashes and existing exact-PID/group cleanup afterward. Do not introduce another standalone full run or change test concurrency/filters to seek green. Build failure or review failure stops before the runtime observation.

- [ ] **Step 7: Analyze with exact identity and bounded claims.** Within the actual RunTests process, join recorder UUID → existing execution identity → actual cancellation/continued PID/group → matching Core `cliSpawned` PID; join each signal UUID internally before matching its signed target and monotonic bracket to that group's lifetime. Compare 346 with 347/372 and retain 152 cleanup evidence. A path-2 successful signal to the actual registered group proves a shared-registry signal attempt succeeded, not which Orchestrator/test called it or sole readiness causation. ESRCH/error is not successful delivery; missing/incomplete logs are not proof no signal occurred. Read decoded statuses and flags together; never infer installed TERM trap from elapsed time alone.

**Stop/completion:** The diagnostic task is complete when reviewed source and that one preserved observation/analysis exist, even if the full gate stays red. If no attribution is established, report the exact remaining gap; no automatic first-read logging, registry isolation repair, timeout increase or repeat full run. A demonstrated cross-test signal permits proposing a separately reviewed fixture-owned registry repair; it does not authorize it here. Parent retains the full acceptance gate.
