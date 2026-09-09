# Independent review — runtime blocking-owner repair

Decision: **APPROVE the scoped implementation for continued validation. No blocking source findings.** This is not full runtime acceptance: the default unfiltered authoritative suite and post-repair lifecycle evidence remain required.

This reviewer did not implement the repair, run builds/tests, launch an app, or alter source. The only write is this review. Reviewed the repair plan, independent plan review, runtime diagnosis and `.superpowers/sdd/runtime-repair-plan/task-1-report.md`. Compared exactly the four authorized source files against `runtime-repair-before/Sources/...`, not against the repository's much larger dirty baseline. The parent explicitly authorized the small throwing-path cleanup additions in the retained 20/100-iteration Board tests.

## Ownership and scheduling

- `Orchestrator.swift:8176`: the drain diff only changes dispatch admission to a named utility native Thread. Barrier acquisition still precedes both starts; group entry and active-worker registration precede scheduling. State/control/group/diagnostic captures, byte limits, nonblocking reads, polling, stop observation and errors are identical to the preimage. Each closure owns its descriptor locally; its defer closes once, publishes worker completion and leaves the group in the original order. There remain two independently scheduled drain owners per started probe.
- `BoardToolServer.swift:329,349,637`: production nil defaults select named utility native Threads; nonnil injected queues execute the same sendable closures. Accept retains the original weak-self/group/diagnostic capture, and handler retains the original strong-self/group/diagnostic capture. Actual-entry and deferred completion events remain at the same boundaries. The single claimed connection slot and accept ownership checks are unchanged. No thread pool or retained Thread array was introduced.
- The bound is one accept operation and one claimed active handler operation per Board instance. A previous handler may still be completing its release/close/defer tail when another connection claims the slot; this is not a strict count of simultaneously alive OS threads. The handler group still includes those tails, so stop joins their FD closure and reported failures.

## Async stop correctness

`BoardToolServer.swift:365` publishes each continuation and the in-flight flag under the same short state lock. Only the caller that changes the flag launches the native cleanup owner, after releasing the lock. That owner strongly retains the server while invoking the unchanged synchronous stop. It captures the actual success/error, atomically takes and clears all current waiters and resets the flag, then resumes each captured continuation once outside the lock.

Registration during an attempt enters its waiter batch. Registration after the atomic take/reset begins a new real attempt. Neither case can lose or duplicate a continuation. A new attempt may overlap the old thread's result-delivery tail, but cannot overlap its blocking stop operation. The existing separate cleanup lock remains intact for synchronous/async checked-unlink overlap. There are no group waits, Thread starts or continuation resumptions inside the state lock.

No cancellation handler abandons a waiter or cancels cleanup; a canceled caller still receives stop's actual result. Failures are not permanently cached, so a later call performs real checked cleanup again. `stop()`, signal/wakeup, accept-before-handler join ordering, active FD shutdown versus owner closure, socket identity verification and first-error behavior are unchanged.

`CliProcessBackend.swift:681,1208` awaits the new facade at both authorized cleanup call sites. Construction selects the production defaults. Pre-registration failure aggregation, finalization's original first-failure sequencing, process reap/EOF evidence, registry/file cleanup ordering and lifecycle events remain unchanged. No waitpid, readiness or ShellTool repair is claimed by this diff.

## Regression and failure cleanup

`BoardServerTests.swift:643` genuinely awaits stopAsync while a queued handler is held. Second-connection rejection establishes ownership of the first slot; active-client EOF and listener closure establish that stop began. Independent async work releases the handler after one caller is canceled. All three completion results are checked, along with EOF, socket removal and repeated cleanup. The replacement-socket argument requires the real identity-mismatch error and preserved sentinel, restores the original socket identity, and verifies a successful later retry.

Arrival latches do not prove all three callers registered in one internal batch, and the test/report correctly avoid that claim. The atomic coalescing invariant is established by the implementation review above; the test checks observable results for overlapping calls. Its two-second latch watchdog reports a phase-specific failure rather than being used as an ordering sleep.

The regression's outer defer releases the handler before clients or synchronous harness teardown, attempts socket restoration when needed, and records restoration/cleanup failures without replacing the primary thrown error. The retained 20-iteration loop now resumes its queue exactly once before throwing-path joins and closes owned clients; the 100-iteration loop similarly retains throwing-path client/harness cleanup. Original loop counts, assertions and deadlines are preserved. Explicit controlled-queue race tests remain injected; generic fixtures select production defaults.

## Validation status and limits

Inspected the parent's `runtime-repair-board-focused.log`: fresh Swift compilation completed, both `replaceSocket` arguments passed, and the Board suite reports **12 tests in one suite passed in 7.811 seconds**. The parent reports exit 0. This reviewer did not execute that run. At review time the parent is serially running the remaining approved focused source/CLI/shell/075 checks; their results are not inferred here.

The default unfiltered `swift run RunTests` with retained complete output and lifecycle diagnostics remains pending. Acceptance still requires that result and evidence of post-repair admission/teardown. This source approval does not establish that all previously observed shell/readiness failures share this cause, nor that thread/FD teardown has been verified under full-suite load. Any residual failure must retain its exact evidence and block the corresponding acceptance gate.

Reviewed SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `515db34be2fe282497d6cbf44d300efa51de49d85c862368c2dce4ba52abce68` |
| `Sources/AgentLoopCore/Loop/BoardToolServer.swift` | `33f7c9017e86d964e8ffc1ae387820a6aac0bed4543d3eab016af5cd27c5d079` |
| `Sources/AgentLoopCore/Loop/CliProcessBackend.swift` | `f6e5ebff4bba307462edbe2092d10d55e8a50f95005cfc01b007e2590fb4cff1` |
| `Sources/AgentLoopTestSuite/BoardServerTests.swift` | `d31bc45ade3d2b3d3c02b7b420a2dffe77700746781470cdb06b1675c5455ebb` |
