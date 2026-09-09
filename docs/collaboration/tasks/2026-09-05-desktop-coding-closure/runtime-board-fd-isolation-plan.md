# Board process-wide FD oracle isolation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans after independent plan review. One bounded test-isolation task; parent owns all Swift invocations. No commit is authorized.

**Goal:** Give the existing Board `< 10` descriptor-growth assertions a process boundary that excludes unrelated concurrently running suites, while retaining their real server operations and failure visibility.

**Source/evidence:** `runtime-recheck-full.log`; `Sources/AgentLoopTestSuite/BoardServerTests.swift:435,741–839,1693–1695`; existing owned child implementation at `CliBackendTests.swift:3740–4023`.

## Diagnosis: what isolation does and does not establish

The completed run remains red: **1090 tests / 61.428 s / three issues**. `boardServerStopWaitsForBlockedHandlerThenCloses` reports only final process-wide FD growth **35**, violating `< 10` (`runtime-recheck-full.log:2007`). No iteration's blocked-stop, resumed-stop, stop-error or client EOF assertion reports failure. This does not prove every Board resource was released; it also does not attribute those 35 descriptors to Board.

`BoardServerTests` already has `@Suite(.serialized)`, which serializes this suite's tests, not unrelated suites in the same RunTests process. Its counter enumerates **all `/dev/fd` entries** across a multi-second baseline/final interval. Other suites in this same log are running during that interval. The 100-iteration accept-loop sibling uses the same global oracle. Consequently, both tests' measurement scope is wider than the resource owner they purport to test; suite serialization cannot repair it.

Existing runtime events have Board owner UUIDs for queued/started/finished accept/handler work and stop/join stages. They do not identify every opened FD, its numerical lifetime, or a baseline/final owner inventory. Event counts alone cannot assign the observed delta to these two tests. There is no evidence here authorizing a production Board close-path change.

**Decision:** isolate each of the two FD-count tests in its own real RunTests child with exactly one selected original test body. This repairs the oracle's ownership boundary and keeps native production Board work. If the unchanged FD assertion still fails there, retain that child and its logs as a narrower leak/measurement repro; do not raise the threshold, retry until green, or claim isolation fixed a proven Board leak.

## Frozen constraints and file scope

- Preserve the original 20 blocked-handler iterations, 100 accept-loop iterations, all `0.1 s / 2 s / 5 s` waits/deadlines, bounded connection retry, stop/EOF/weak-reference/socket checks, and exact `< 10` growth threshold. No global suite serialization or production changes.
- The 20-loop fixture's intentionally suspended **injected handler queue** remains injected. Its accept worker uses the current production default native path. The 100-loop fixture retains both default production workers. Do not falsely describe the deliberately blocked handler as a native-worker admission test.
- Preserve each failure-path defer that resumes the suspended queue exactly once before closing clients and joining/closing its harness. Do not add descriptor-number replacement or `dup2` onto a probed arbitrary FD.
- Modify only `Sources/AgentLoopTestSuite/BoardServerTests.swift` and `Sources/AgentLoopTestSuite/CliBackendTests.swift`; generalize the existing runner in place at module-internal test visibility for reuse. Reports/preimages/diffs stay in this task directory. Do not add a new source file: `a3Revision02EntryBoundaryRemainsByteExact` enumerates all Sources and a new helper path would require an unrelated successor-boundary change.
- No change to Package.swift, Core logger/Board implementation, frozen production manifests, existing 075 drain/sentinel assertions, Provider use, or user data.
- Parent freezes both source preimages/hashes before the sole writer starts. Reuse existing helper behavior rather than adding a second 250-line spawn/ownership framework.

## Task 1: Reuse the reviewed owned self-exec runner and isolate both FD oracles

- [ ] **Extract, do not redesign, the existing child resource owner.**

Extract the process-owning mechanics/evidence emission from `p1f1d075RunFDChild{Blocking}` into module-internal shared functions **in the same CliBackendTests.swift file**. This is a bounded in-place reuse, not a second implementation or general-purpose subprocess framework. Keep one native utility thread + checked continuation, current executable resolution, `/usr/bin/env` self-exec, exclusive log creation, checked normalized FD ownership, spawn attributes/actions, exact-child poll/kill/reap, error aggregation and full evidence emission. A small request supplies only fixed test filter/mode keys, expected completion bytes and containment duration; executable choice is always the current RunTests image.

```swift
struct OwnedSelfExecTestRequest: Sendable {
    let label: String
    let filter: String
    let modeEnvironmentKey: String
    let mode: String
    let evidenceEnvironmentKey: String
    let expectedEvidence: Data
    let containment: Duration
}
func runOwnedSelfExecTest(_ request: OwnedSelfExecTestRequest) async throws
```

All callers use fixed source-owned labels, filters and environment keys, never user-supplied arguments. Keep the existing 075 caller as a thin adapter with **15 s** containment, its existing mode/evidence environment keys, exact selected test and `live-drain\nsurviving-run\nsurviving-abort\n` completion bytes. Its intentionally failing child still throws `deliberateChildFailure`; its existing negative regression still requires nonzero status and that literal marker. Only its caught process-owner error type changes to the shared child-status error where needed. Keep FD sentinel/descriptor-occupied errors and assertions local; no broad rename of unrelated 075 code.

The shared process error carries actual PID, raw status and retained log/evidence paths. Preserve primary plus setup/close/reap/read/output failures. A log/evidence read failure cannot suppress the other file. The output lock only keeps emitted evidence blocks intact; it must not serialize child execution or entire tests.

- [ ] **Enforce the inherited child safety and evidence contract.**

1. Create a unique fixture directory; open child log with `O_CREAT | O_EXCL | O_CLOEXEC`, mode `0600`; normalize only that owned FD to `>= 3` with `F_DUPFD_CLOEXEC` if needed. Checked actions give child `/dev/null` stdin and the same owned log description for stdout/stderr; close its auxiliary FD and use `POSIX_SPAWN_CLOEXEC_DEFAULT`.
2. No global `setenv`; put only the request's fixed mode/evidence assignments in the child argv. Preserve parent's diagnostic opt-in environment. No descendant processes are launched by a Board child body.
3. Consume parent log/action/attribute ownership once. Poll/reap **only the exact successfully spawned direct child PID**. Preserve immediate errno capture and existing `EINTR` handling. `ECHILD` clears signal authority and reports unconfirmed reap; it is not success.
4. On failure/containment timeout, re-confirm the still-unreaped direct child with `waitpid(..., WNOHANG)` before signalling; never signal after ownership is lost/reaped, never signal a process group, and join exact-child cleanup before returning. Retain the existing failure aggregation on kill/reap errors.
5. Success requires raw status zero **and exact completion evidence**. An empty filter/zero-test success, skipped body, recursion, wrong phase or missing evidence must fail. Emit complete child stdout/stderr, mode/PID/raw status and completion bytes before deleting only the successful fixture directory. All failures retain their complete logs/evidence and report their paths.

The inherited runner's termination/reap limitations must stay visible; do not replace its checked failure with an unjoined cleanup task. This extraction is independently reviewable against the previous 075 implementation.

- [ ] **Wrap the two exact Board tests; retain their bodies.**

Change only these `@Test` entry methods to `async throws` wrappers:

```text
boardServerStopWaitsForBlockedHandlerThenCloses
boardServerStopWakesBlockedAcceptLoopAndReleasesListener
```

Extract their current synchronous bodies into private static functions within the same suite. The ordinary parent branch awaits the shared runner with the exact respective test-name filter, `AGENTLOOP_BOARD_FD_CHILD_MODE`, and `AGENTLOOP_BOARD_FD_CHILD_EVIDENCE`. Modes are `blocked-handler`, `accept-loop`, and the regression-only `blocked-handler-leak-proof`. Containment is **60 s per Board child**, separate from and not replacing/increasing any original per-iteration deadline. Containment failure remains red and is not proof all iterations ran.

Check the child mode **before** creating another child. Valid matching mode runs the appropriate original body directly, then writes exact completion bytes `blocked-handler:20\n` or `accept-loop:100\n` to its supplied evidence path; invalid/mismatched mode throws. Normal parent socket-unavailable behavior may retain the existing guard, but a launched child that cannot bind must throw and omit completion evidence, not skip to apparent success. Verify the evidence path is the validated absolute path supplied by the runner. A child executes one test only; there is no child-wide suite or second hidden self-exec path.

Do not change which queue is passed to `makeBoardHarness`. Keep every original assertion and defer. For the FD assertion only, capture a throwing baseline/final count and assert `finalCount - baseline < 10`; print the exact same measured baseline/final/delta with fixed mode/PID for diagnosis. Replace this suite's current `(try? contentsOfDirectory(...).count) ?? 0` helper with a throwing `fileDescriptorCount() throws -> Int`: a failed count must not fabricate zero. No new probe descriptors remain open across a measurement.

- [ ] **Prove failure propagation and that a real FD leak still fails.**

Keep the existing 075 occupied-target and failing-child regressions. Add `boardFDIsolatedLeakStillFailsParent`: run the exact blocked-handler child in regression mode, retaining the same 20-loop body and original `< 10` assertion. Immediately **after** its baseline count, a narrow test-only injection opens 32 distinct owned `/dev/null` descriptors with `O_CLOEXEC`; hold them across the final measurement, then checked-close them in defer on every path. The ordinary mode injects none. Do not overwrite/reuse guessed FDs, bypass assertions, or leave descriptors leaked after the child exits.

The negative parent regression must require: nonzero actual child status; the original FD assertion appears as failed in the full test output; the logged measured delta is `>= 10`; exact completed `blocked-handler:20\n` evidence is present. This proves it failed on the retained process-wide oracle after all 20 iterations, not merely on a mode typo or launch failure. Any other ownership/evidence/cleanup error remains a failing regression, not expected success. Only after reading/verifying full negative evidence may the regression remove its own failed-fixture directory, matching the existing 075 negative-test pattern.

Record the injection mode in fixed diagnostic output, not as real product activity. No new failure is injected into production Board.

- [ ] **Parent-owned verification and independent review.**

After source writer release, parent captures complete stdout/stderr and actual exit codes for:

```text
swift run RunTests --filter p1f1d075FD
swift run RunTests --filter p1f1_075CLIHelpCapabilityMismatchIsUnsupported
swift run RunTests --filter boardFDIsolatedLeakStillFailsParent
swift run RunTests --filter boardServerStopWaitsForBlockedHandlerThenCloses
swift run RunTests --filter boardServerStopWakesBlockedAcceptLoopAndReleasesListener
swift run RunTests --filter a3Revision02EntryBoundaryRemainsByteExact
```

The expected failing **nested** leak/075 child is not the outer test result. Verify the complete outer summary, child raw status, phase evidence and original assertion logs. For each positive Board child require the expected loop count/evidence, zero status and original `< 10` assertion green; no claim that a lower FD count proves all production resource ownership everywhere.

Independent reviewer checks the mechanical runner extraction, old 075 behavior, unchanged 20/100 bodies/deadlines/assertions, child recursion guard, no leaked setup FDs, and deliberate FD-growth failure propagation. The next already required parent-owned full concurrent gate remains necessary; no suite concurrency override. Retain all child PID evidence so optional existing OSLog capture can include those exact PIDs, not just the parent.

## Stop / completion rule

If either isolated positive child remains red, stop this repair at its measured evidence: distinguish FD-growth failure from shutdown/deadline/worker failure before proposing a next change. Isolation is complete only after the focused gates and independent review pass; it does not clear the two other issues in `runtime-recheck-full.log` or authorize calling the whole runtime gate green.
