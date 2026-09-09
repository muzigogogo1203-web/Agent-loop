# Runtime baseline diagnosis — 2026-09-05

Status: the default full suite remains red. Investigation has narrowed the shared scheduling/cleanup boundary; no runtime root cause is yet proven and no implementation repair is claimed.

This investigation inspected source and existing logs without spawning test fixtures, building, or changing code/data. Its sole write is this report. The parent task ran the full suite and six isolated checks. Source locations below refer to the current dirty working tree in `/Users/muzi/Agent-loop`, whose existing changes belong to the user.

## Observed evidence

The historical `docs/collaboration/tasks/2026-09-01-active-ingestion-deletion-timestamp-roundtrip/verify.log` ended with 1086 tests, 31 suites, and six issues (line 2274). Today's `verify.log` reproduced exactly those six test names and error classes, ending with 1086 tests, 31 suites, six issues, and 47.542 seconds (line 2275). The parent reports no competing Swift/app process before the run; that excludes a competing build as the observed explanation, not scheduling contention inside RunTests.

| Test | Today's full-run observation | One isolated run |
| --- | --- | --- |
| `p1f1_075CLIHelpCapabilityMismatchIsUnsupported` | Bare `processGroupSurvived`; 11.243 s; `verify.log:1311,1335` | Pass, 36.869 s; `focused-reruns.log:2–12` |
| `boardServerStopWaitsForBlockedHandlerThenCloses` | Connection refused; 2.133 s; `verify.log:2140–2141` | Pass, 2.206 s; `focused-reruns.log:14–26` |
| `boardServerStopWakesBlockedAcceptLoopAndReleasesListener` | receiveTimedOut; 5.002 s; `verify.log:2198–2199` | Pass, 0.244 s; `focused-reruns.log:28–40` |
| `shellTimeoutTerminatesProcess` | Measured execute duration 7.477 s exceeds 5 s; `verify.log:2207–2209` | Pass, 0.784 s; `focused-reruns.log:42–52` |
| `cliProcessBackendCancellationEscalatesAfterGrace` | processCleanupFailed("process did not exit within kill grace"); 28.437 s; `verify.log:2213–2214` | Pass, 1.024 s; `focused-reruns.log:54–64` |
| `cliProcessBackendCancellationReturnsCheckedEvidence` | Same cleanup error; 28.437 s; `verify.log:2212,2215` | Pass, 0.709 s; `focused-reruns.log:66–76` |

The focused commands each used `swift run RunTests --no-parallel --filter <one test>` and exited 0. These are diagnostic contrasts, not a replacement completion gate. They change both test concurrency and co-running workload; they do not identify which change matters. No further isolated green hunting is needed.

## What the error labels actually localize

### 075 does not establish a surviving process group

`Sources/AgentLoopTestSuite/CliBackendTests.swift:3466–3482` runs twelve composition checks before the named help capability behavior. `p1f1d075AssertLiveDrainOwnership` has no child process: it creates two pipes, deliberately expects the first `finish()` to time out while writers remain open, closes writers, and calls `finish()` again (`3033–3081`). The second call at line 3079 can propagate the historical bare error.

`Sources/AgentLoopCore/Kernel/Orchestrator.swift` uses `processGroupSurvived` for different boundaries: leader reap deadline (`7750–7761`), a group still present after leader exit (`7852–7856`), group-absence deadline (`7919–7938`), and drain join timeout (`7991–8005`). The live-drain join waits one second (`8120–8128`) for utility-queue workers (`8138–8140`). The current error output lacks the failed composition stage, join attempt, worker state, and PID/PGID.

Closed-stdio subprocess failure is translated to a fixture `.status(status)` error by `CliBackendTests.swift:2255–2262`. Later `CliHelpProbeV1.run` translates unknown errors to `.mechanics` (`Sources/AgentLoopCore/Loop/CliEngineAdapter.swift:1603–1606`). These wrappers further favor an outer composition-stage explanation for the bare error, without identifying its precise throwing call.

### Board failures precede stop

`boardServerStopWaitsForBlockedHandlerThenCloses` connects its two clients at `BoardServerTests.swift:615–616`, before the stop operation at `622–629`. The connect helper retries Connection refused for two seconds (`1532–1540`); the listener backlog is one (`Sources/AgentLoopCore/Loop/BoardToolServer.swift:455`). The error demonstrates that a connection was not admitted within the retry interval. It does not prove why the accept loop did not make progress.

In `boardServerStopWakesBlockedAcceptLoopAndReleasesListener`, the only receive is `client.hello` at `BoardServerTests.swift:659`, before stop at `661`. The client receive timeout is five seconds (`1601–1602`), producing `receiveTimedOut` at `1690–1694`. The server's hello path parses and writes synchronously (`BoardToolServer.swift:678–688`); it does not await a Swift task. Pure Swift cooperative-executor starvation alone is therefore an incomplete explanation of this failure.

The Board suite already has `.serialized` (`BoardServerTests.swift:383`). Other suites and top-level tests still run alongside it.

### CLI cancellation reports full-finalization delay

`Sources/AgentLoopCore/Loop/CliProcessBackend.swift:1111–1121` first terminates the group, then races the completion task against `killGrace`. Completion includes stdin completion, leader reap, stdout/stderr drain, another group check, synchronous Board stop, and cleanup-file removal (`1124–1177`). The explicit surviving-group error is separately emitted at `1263–1266`. The observed error cannot be treated as proof that a child remained alive after SIGKILL.

`awaitCompletion` (`1744–1765`) races `task.value` against a sleeping timeout in a structured task group. Exiting the group still waits for its children; cancelling the child awaiting an independent task's value does not cancel that independent task. This code can report a timeout only after the underlying completion eventually settles. It is a concrete boundedness concern, not proof of the stage that delayed these runs.

### Shell duration excludes environment prewarming

`Sources/AgentLoopTestSuite/ShellToolTests.swift:123–127` awaits login environment before starting the elapsed timer. Thus total test duration and the measured 7.477 seconds are different intervals. Only the elapsed assertion failed; the timeout message/output and empty registry assertions did not report failure. `Sources/AgentLoopCore/Tools/ShellTool.swift:59–69` signals the leader and then awaits all output; its output reader uses a blocking utility-queue read (`83–88`). A descendant retaining a pipe is a separate possible production risk, not demonstrated by this log.

## Strongest falsifiable hypothesis

**Shared utility-dispatch workers are occupied by blocking I/O, delaying newly enqueued accept, drain, and output-reader jobs. Blocking operations on Swift workers add pressure and can delay the continuations needed to release those resources.** This is a code-supported mechanism and the leading hypothesis, not a measured root cause.

The concrete shared dependency is:

1. CLI launches place both Board accept and handler loops on `DispatchQueue.global(qos: .utility)` (`CliProcessBackend.swift:655–656`). The failing Board harness uses that same global QoS (`BoardServerTests.swift:307–310`). Accept blocks in `accept()` and handlers block in `read()` (`BoardToolServer.swift:528–529,645–649`). Tool calls can additionally wait synchronously for an async executor via a semaphore (`724–733`).
2. Managed probe pipe drains also run on global utility (`Orchestrator.swift:8140`) and keep a worker while polling (`8168–8194`). Shell output readers use the same QoS (`ShellTool.swift:85–86`). Login-shell capture also uses it (`Sources/AgentLoopCore/Support/ShellProcessRegistry.swift:114–135`), which could explain delayed prewarming, but its enqueue/start time was not recorded.
3. A delayed Board accept job can leave backlog full; a delayed handler can leave hello unanswered. A delayed managed-drain job can expire its one-second join even after writers close. A delayed shell output-reader job can postpone return after the shell has already exited. These fit all four boundaries without requiring process-group survival.
4. CLI finalization calls `server.stop()` synchronously (`CliProcessBackend.swift:1170`), and stop waits for accept/handler groups (`BoardToolServer.swift:330–333`). It can therefore await those same delayed utility jobs after the child and pipes have completed. A timing trace must determine whether this is the actual delayed stage.
5. Independently, CLI reaping uses `Task.detached` with blocking `waitpid(...,0)` (`CliProcessBackend.swift:976–979`). Some concurrency fixtures deliberately block NSCondition while release work is async: `ExecutionEngineConformanceTests.swift:177–187,2083–2093,3082–3106`; `DurablePlanningTests.swift:373–378,7393–7408`. These are candidate executor occupiers; no stack capture establishes their simultaneous presence at failure.

Do not count every semaphore as a Swift-pool defect. Some race fixtures already use explicit Threads and suspend their async caller with a continuation, e.g. `ScheduleTests.swift:910–953` and `DurablePlanningTests.swift:1924–1935`. Also, MCP production transport uses utility blocking reads, but the examined MCP tests predominantly use fake transports; there is no evidence yet that MCP contributed here.

An additional failure-amplification risk exists in the two looping Board tests: their `harness.close()` is on the success path (`BoardServerTests.swift:637,664`), with no per-iteration throwing-path close. Once an accept loop has entered, the method invocation can retain its server while blocked in accept. A pre-stop throw may therefore leave resources active within this test process and influence later tests. Whether it happened in the observed failure is unmeasured. This could amplify the first Board failure but cannot explain the earlier 075 failure by itself.

## Next bounded diagnostic increment

Use one instrumented default-concurrency full-suite run. Preserve today's baseline logs and source hashes. Do not change queue choice, timeout duration, test serialization, cleanup ordering, or assertion strength in the diagnostic increment. Do not run fixtures concurrently with that run.

Add a narrow opt-in diagnostic observer with monotonic timestamps and numeric execution/test correlation identifiers. Record stages and errors without commands, tokens, environment values, or user data. Keep event storage bounded and recording short; do not route the diagnostic observer through global utility or a Swift actor whose scheduling is under investigation. A small synchronized event buffer can be dumped after each target's failure; overflow must be explicit. The collector should not hold a lock across I/O or invoke arbitrary callbacks while holding runtime locks.

Record only these boundaries:

- **Board:** accept queued, accept job actually started, accept returned/errno, peer validation result, handler queued/started, hello read/write completed, stop entered, accept group joined, handler group joined, socket closed. Include active and queued job counts, per-test loop iteration, and accept/handler QoS. Preserve fd ownership identity so reused descriptor numbers are not mistaken for the same resource.
- **075:** entry/exit/failure of each composition helper; each live-drain attempt; queued versus actually started workers; worker EOF, close, leave; join begin/end/timeout; actual group-existence and reap results only when a real process exists. The current `activeWorkerCount` increments before enqueue (`Orchestrator.swift:8138–8140`), so it cannot distinguish a queued worker from a running one; use a separate started event/counter.
- **CLI:** registration published, cancellation entered, group signal/check results, reap job queued/started/completed with status, stdout/stderr EOF, finalize stage transitions, Board stop begin/end, timeout fired, and cancellation returned. This separates OS process survival from delayed finalization and delayed error publication.
- **Shell/environment:** environment capture queued/started/finished; execute start, process PID/exit observed, timeout decision, TERM/KILL outcome, output reader queued/started/EOF, execute return. This distinguishes timer delay from reader scheduling and pipe inheritance.

For the same single run, collect at most two short native stack samples of the exact RunTests PID, from an external observer process: one around the early 075 drain window and one during the later Board/CLI failure window. Trigger the second from the recorded Board target entry if feasible; the historical timing is only a guide. Record monotonic start/end and sample overhead, plus a bounded read-only process snapshot with PID/PPID/PGID/state. Avoid an unbounded polling sampler. No process termination or app/data actions belong in this diagnostic run.

Classify results using the following falsifiers before choosing a repair:

| Hypothesis | Supporting observation | Falsifying / redirecting observation |
| --- | --- | --- |
| Utility job starvation | Failed operation's enqueue-to-start delay consumes its deadline, while sampled utility workers remain blocked in accept/read/poll/waits | All relevant jobs start promptly; delay occurs after data is ready or inside a specific handler/lock |
| Swift worker starvation contributes | Samples show cooperative workers blocked in waitpid/condition/group waits while recorded ready continuations start late | Cooperative work progresses normally and only utility jobs are late; repair focus stays on utility scheduling/ownership |
| Actual child/group survives | Same owned PID/PGID persists after checked signals; reap/EOF incomplete and OS state confirms it | Group absent and child reaped well before timeout; investigate finalize stage instead |
| Board failure leaks amplify later tests | Failed iteration leaves active accept/handler ownership after test exit | Ownership is released on the observed failure path; do not use this as the causal story |
| Shell descendant retains output | Reader starts promptly but EOF waits on a traced descendant that still owns the pipe | Reader starts late and immediately sees EOF, or timer itself fires late |

After this one diagnostic run, identify the first stalled owner and make the smallest repair to that shared ownership/scheduling boundary. Preserve real group cancellation, EOF, reap, socket-close, and terminal evidence. If necessary, isolate deliberately blocking fixture work from cooperative workers using an established owner/continuation pattern; do not globally serialize the suite. If proof remains insufficient, report the exact missing boundary and stop the repair claim rather than proposing a timeout increase. Any behavior-changing repair needs its own scoped reproducer and the default full-suite gate afterward.

## Scope and completion

Current conclusion: repeatable workload-sensitive failures, six isolated passes, no proven production root cause. The next deliverable is one bounded stage/queue/stack evidence bundle and a causal diagnosis. There is no authorization in this note to commit, push, release, alter user data, or claim that UI acceptance or the runtime baseline is complete.
