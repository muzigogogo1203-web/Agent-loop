# Runtime blocking-owner repair

**Goal:** Remove the measured shared-queue admission dependency for managed probe pipes and Board sockets, and suspend asynchronous CLI cleanup callers while Board joins complete.

**Spec:** `spec.md`. Causal evidence: `runtime-diagnosis.md`, `runtime-observed.log`, `runtime-observed-events.ndjson`. No more general diagnosis run is required before this increment.

## Global constraints

- Preserve all existing deadlines, assertions, process authority, framing, peer validation, cancellation, EOF/reap requirements, file-descriptor ownership, cleanup ordering and surfaced errors. No retries, fallback, QoS escalation or suite serialization are part of this repair.
- Keep opt-in lifecycle events at the same queue/start/finish/join boundaries. They now observe native worker scheduling where defaults change.
- Parent is the exclusive build/test owner. All original dirty changes remain. No commits, data operations, Provider calls or app launches.
- Bound native workers by existing ownership: two drain threads per started probe; one accept loop and at most one active handler per Board instance; a cleanup thread only while an asynchronous stop is joining. No global unbounded worker executor, polling supervisor or new source file.
- Do not change ShellTool, login environment capture, waitpid mechanics or readiness behavior speculatively. Reassess remaining failures after this cause-specific increment.

### Task 1: Repair measured admission and async join boundaries

**Modify only:**

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`, `EngineManagedProbeLiveDrainV1.startDrain` only.
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`, default scheduling and new asynchronous stop facade only.
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`, Board construction and its two stop call sites only.
- `Sources/AgentLoopTestSuite/BoardServerTests.swift`, default harness construction and focused async-stop regression only.

**Managed drain:** Replace the global-utility dispatch admission with `Thread(block:)`, give it a fixed diagnostic name for stdout/stderr and `.utility` quality of service, then start it. Keep group enter, worker registration, captured state/control/group/UUID, descriptor closure, polling, limit handling and group leave unchanged. Existing control/barrier is the lifetime/join authority. Two worker starts remain independent so a full stdout cannot block stderr. No thread is created before a valid `start` has acquired its existing barrier.

**Board default workers:** Keep the current test injection capability but make `acceptQueue` and `handlerQueue` optional with default nil. Nil means an explicit named native Thread at `.utility`, not a new DispatchQueue. A nonnil injected queue executes the existing closure on that queue. A small private scheduling function in this file may avoid repeating the three-line thread construction. Preserve all closure captures, true-entry diagnostics and deferred group leave. The existing accept connection slot remains the sole handler limit. Do not retain an array of unjoined threads or widen the backlog.

**Board async stop:** Add `package func stopAsync() async throws`. Use a checked throwing continuation and one native cleanup thread to execute the existing `stop()` and resume exactly once with its actual success/error. Never call blocking `stop()` directly inside a Task/Task.detached as the implementation: that still occupies a cooperative worker. Never abandon cleanup because its awaiting task was canceled. Keep synchronous `stop()` for existing synchronous ownership/testing paths. Concurrent async callers must join one in-flight stop, not launch one thread each: keep a short-lock-protected array of waiters and an in-flight flag on the existing owner; take the waiters and reset the flag before resuming them outside the lock. A later retry after completed failure invokes the real stop again, preserving retryable checked cleanup rather than caching a permanent failed Task. No lock is held while waiting on groups or resuming continuations.

**CLI integration:** Its Board constructor uses the production nil defaults. Both startup-failure cleanup and `finalize` await `stopAsync()`. Keep their current do/catch/first-failure sequencing and lifecycle events. Registration/finalization ownership stays unchanged; successful cancellation still requires reaped process, both EOFs and checked server/file cleanup.

**Harness integration:** The two general Board fixture constructors pass their optional queue arguments directly, instead of substituting global queues. The explicit utility defaults at the standalone Board-construction fixture also use production defaults unless that individual test actually requires a controlled queue. Preserve explicitly suspended/injected queues in start/stop/handler race tests. This is selecting the actual production path, not weakening test deadlines or assertions.

**Red evidence already observed:** The unchanged existing 075 composition test fails at the second one-second join before native repair; both pipe workers start 15.524 seconds late. Existing Board and CLI tests fail in the same default full execution. Keep those tests and their original assertions. They exercise the production paths being replaced and constitute the failure-before-repair evidence, not a compiler-only failure or a fabricated scheduler microbenchmark.

**Additional behavioral regression:** In `BoardServerTests`, exercise real `stopAsync` with a handler held at the existing controlled handler queue boundary. Multiple asynchronous stop callers must remain pending until the handler can complete; release it from independent async test work, then all callers observe the same cleanup result, the client receives EOF, the socket is removed and the server can be checked/closed again safely. Also cover a real checked socket cleanup failure propagating to all joined callers and a subsequent retry after restoring the fixture authority, if supported by the existing fixture. Use latches/continuations and existing socket test deadlines, not sleeps to guess ordering, private waiter-count access, or a new production hook. Existing red full-run evidence is the causal regression; this added test validates the new facade's join contract.

Independent plan review approved this scope (`runtime-repair-plan-review.md`). Include a canceled awaiting task in the async-stop regression: cancellation must not skip owned cleanup. Every regression failure path must release a suspended handler/queue before attempting client/harness teardown. A pre-call latch or Task.yield cannot prove that every caller has registered as an in-flight waiter; do not claim it does. Assert externally observable completion/EOF/socket/error behavior and inspect the short-lock registration algorithm separately.

- [ ] Parent captures post-instrumentation pre-change copies of the four files.
- [ ] Implementer applies only this scope, self-reviews and reports; no test/build command in parallel with parent.
- [ ] Parent builds/runs focused existing 075 + Board + relevant CLI/shell regression cases with the installed runner's already validated `--filter` form. Do not use `--help`: this standalone SPI runner ignores it and starts tests.
- [ ] Responsibilities-separated review checks thread bounds, continuation completion, lock discipline, existing injection controls and FD/error semantics.
- [ ] Apply the independently scoped historical-source successor update for the approved diagnostic source; preserve the original manifest.
- [ ] Parent runs default unfiltered `swift run RunTests`, retaining all output. Remaining runtime failures get their own exact evidence-selected analysis; no claim that all six must share this cause.

## Adjacent validation note

An attempted standalone runner `--help` inspection unexpectedly started tests because this runner directly invokes Testing SPI. Its console capture was incomplete and excessively slow, and the owned RunTests PID 87877 was stopped after verifying its image/parent and then freezing it and confirming it had no child process before TERM/CONT. This aborted run is not a formal experiment or acceptance result; the pipeline exit status is not its test status. Do not repeat unsupported flag probing or pipe test output through head. Existing successful exact `--filter p1f1_075CLIHelpCapabilityMismatchIsUnsupported` is the filter evidence. Required runs redirect complete stdout/stderr to a unique file and capture the actual exit status.
