# Residual shell / CLI I/O contingency map

Scope: read-only source and retained-evidence analysis; only this report was written. No code, build, test, app, data, or runtime capture actions. Source facts below describe the checkout inspected after the Board/drain ownership repair. The parent is repairing the independently proven FD fixture defect; no post-repair full-run result is assumed here.

## Evidence boundary

- `runtime-diagnosis.md` proves admission delays for managed drains and Board accept callbacks in the earlier run. It explicitly does not establish the shell/readiness cause.
- `runtime-observed.log:2144–2145` records both cancellation tests failing at `process did not become ready`; cancellation evidence assertions were not reached.
- `runtime-observed.log:2211` records shell measured elapsed **8.366406166 s > 5 s**. Its whole test duration is 35.841 s (line 2216); these durations measure different intervals.
- Focused success and a later full run stopped by the unrelated FD fixture defect do not determine whether these residual failures still exist. The next completed default full run is the selection gate.

## Confirmed source boundaries

| Owner / phase | Actual execution and lifetime boundary | Source |
| --- | --- | --- |
| Shell environment | `execute` awaits shared login environment before spawning and before constructing the command timeout deadline. | `Sources/AgentLoopCore/Tools/ShellTool.swift:34,55` |
| Shell output | An `async let` eventually submits `readDataToEndOfFile` to global utility via a continuation. Queue admission, blocking read, and continuation resumption are separate intervals. Output is awaited even after timeout/kill. | `ShellTool.swift:50,68,83–89` |
| Shell termination | Swift task polls `Process.isRunning` with 50 ms sleeps, sends TERM to the direct process, waits 300 ms, then sends KILL if still running. There is no process-group signal or separately bounded output join in this path. Registry removal happens on return via defer. | `ShellTool.swift:44–68` |
| Login capture | Single-flight cache uses a detached task; real capture submits a global-utility callback containing process launch, blocking output read, and `waitUntilExit`. A global-default delayed callback sends TERM at five seconds after successful launch; it is not a forced KILL or EOF deadline. | `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift:85–146` |
| CLI prelaunch | The async run performs synchronous input/authority validation, executable hashing, Board start, and suspended spawn/image validation before SIGCONT. These phases are currently not separately timestamped. | `Sources/AgentLoopCore/Loop/CliProcessBackend.swift:602–662,711–764,956–969,1675–1739` |
| CLI reap | `Task.detached` executes blocking `waitpid(childPID,…,0)` until exit and marks `reapState`. It remains a cooperative-executor blocking boundary in this checkout. Spawn-error cleanup also calls potentially blocking `waitpid` synchronously when no registered group exists; it selects WNOHANG only when signaling failed and the group remains live. | `CliProcessBackend.swift:975–996,1076–1084,1528–1560` |
| CLI pipe workers | Detached stdout/stderr tasks read descriptors explicitly configured O_NONBLOCK. EAGAIN/EWOULDBLOCK suspends with 10→100 ms backoff. They are not the same blocking-read mechanism as ShellTool. After reap is observed, grace limits drainage; each worker closes its own descriptor. | `CliProcessBackend.swift:828–830,1002–1022,1821–1941` |
| CLI publication | Readers are created before SIGCONT; registration and stdin-gate opening follow successful spawn. `ready` in the tests means a decoded stdout line received by an actor, not `.ready` in backend registration. | `CliProcessBackend.swift:1002–1047,663–673,1323–1333`; `Sources/AgentLoopTestSuite/CliBackendTests.swift:884–899` |
| CLI finalization | Finalizer awaits stdin, reap, stdout, stderr in order, then group termination and async Board stop. Existing `cliReaped` / pipe-finished events are emitted after those awaits, not when the worker first finishes. Both runtime Board cleanup sites now use `stopAsync`. | `CliProcessBackend.swift:686,1123–1223` |
| CLI completion race | Cancellation awaits registration, signals the group, then races completion against kill grace using a task group. Canceling the group does not itself cancel the separately owned completion task; joining the child that awaits its value can still wait for cleanup. | `CliProcessBackend.swift:1110–1121,1797–1819` |

## Existing test and observability seams

- `shellTimeoutTerminatesProcess` warms shared login **before** its elapsed timer (`ShellToolTests.swift:123–127`). Its 8.366 s failure therefore does not directly include cold login capture. Launch, timeout-loop scheduling, child termination, reader admission/EOF, and resume latency remain inside the measured interval.
- Both CLI cancellation tests likewise prewarm login before creating consumers (`CliBackendTests.swift:482,535`). `waitForStdout` starts a three-second deadline, polls every 20 ms, and returns a generic readiness error unless the recorder already has a terminal error. The deadline includes launch-task admission, prelaunch checks, SIGCONT, child output, drain-task scheduling, stream delivery, and recorder execution.
- On readiness throw, these tests leave before `backend.cancel` and `await consumer.value`; their defer only removes the harness. A retained consumer/process is a possible failure amplifier, not evidence that it caused the initial readiness miss.
- Real CLI mechanics tests cover held grandchild pipe, final unterminated line, cancellation TERM/KILL, reaped leader, EOF, signature checks, and socket cleanup. `CliMechanicsHarness` injects inspector/signature behavior and supplies a stable executionId.
- `CliPipeDrain` exposes read/clock/sleep/exit seams tested for backoff and grace (`CliBackendTests.swift:351–451`), but the live backend uses its separate private `drainPipe`; those helper tests do not by themselves validate live worker admission or readiness delivery.
- Login capture injection plus actor barriers verifies one capture for 20 concurrent callers (`ShellToolTests.swift:187–230`). That test bypasses real zsh/global-queue capture. ShellTool has an injected registry and timeout, but no reader/scheduler/process seam.
- `RuntimeLifecycleDiagnostics.swift:5–36` provides opt-in monotonic `stage`, opaque `owner`, and integer `value` through OSLog. Its current schema covers Board/drains and CLI finalizer phases; ShellTool/login have no events, and CLI launch/reap-worker/readiness delivery lacks admission events and explicit cross-owner mapping.

## Conditional hypotheses and minimal missing evidence

1. **If shell alone remains slow:** utility reader admission is a candidate because it retains the proven earlier scheduling class. Delayed timeout polling, child/descendant-held writer, or continuation resumption are competing explanations. Capture one opaque shell owner; execute/launch/deadline/TERM/KILL/process-exit, reader queued/started/EOF/resumed, and return timestamps; include signal result/errno, PID, byte count, and cancellation flag. No command text or output body is necessary.
2. **If readiness remains red:** map test identity/executionId → CLI diagnostic owner → Board owner, then capture launch queued/started, authority-check completion, spawn PID/PGID, SIGCONT result, stdout-worker queued/started/first-byte/first-line-yield, and recorder first-line/deadline events. These separate prelaunch delay, worker scheduling, child behavior, and consumer delivery without guessing. Record observed deadline start/end; do not infer a child failed to write from a missing recorder line.
3. **If reap/cleanup remains slow:** capture reap-task queued/started, waitpid entered/returned with result/errno, and worker-level EOF/close timestamps. Existing finalizer events can lag actual completion because of sequential awaits. A reader's terminal reason should distinguish EOF, grace, cancellation, read errno, and close errno; current booleans collapse these cases.
4. **If cold login remains implicated outside the prewarmed interval:** record cache-hit/in-flight/new-capture status, queued/started, process launch, watchdog scheduled/fired/signal result, EOF, waitUntilExit returned, and continuation resume. Never emit environment keys/values, login output, tokens, or secrets.

This map does not select a production change. Retain the original full-suite contract and timeout values; use only a surviving failure and its newly attributable interval to select the next bounded repair.
