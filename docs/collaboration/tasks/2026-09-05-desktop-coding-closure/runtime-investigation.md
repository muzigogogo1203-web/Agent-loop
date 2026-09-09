# Runtime investigation record

Status: diagnosis in progress; no runtime repair has been accepted.

## Evidence boundary

The original full run had six failures. The single sampled diagnostic (`runtime-before.log`) had seven; sampling perturbed timing, including one newly failing grandchild-pipe test. Early samples show synchronous database migration work on cooperative threads. A later sample shows a cooperative thread inside BoardToolServer.stop waiting for the accept group. Neither sample shows the corresponding utility accept/drain worker actively executing. A stack sample cannot reveal the complete pending queue inventory.

Current hypothesis: an owner synchronously waits for work enqueued on the shared Dispatch runtime that has not started under load. This is not yet a confirmed local cause. Opt-in events distinguish queue, actual entry, finish and join boundaries. Observed CLI await completion is not the timestamp of the OS reap/EOF itself. Parent PID and launch window must exclude child test processes.

## Primary reference context

- [Apple DispatchQueue documentation](https://developer.apple.com/documentation/dispatch/dispatchqueue) states that non-main queues use system-managed threads and warns about blocking concurrent tasks and excessive thread creation.
- [Swift concurrency runtime maintainer explanation](https://forums.swift.org/t/deadlock-when-using-dispatchqueue-from-swift-task/66058/25) describes the shared underlying worker pool and why blocking a cooperative task on not-yet-running Dispatch work can prevent forward progress.

These references explain why the hypothesis is plausible, not proof that this app has that exact failure. No fix is selected from documentation alone. Do not assume a renamed private queue guarantees an independent thread; do not fill the machine with unbounded threads as a substitute for ownership design.

## Compiler preflight

The first instrumentation compile failed before any test executed because a newly multi-statement function retained an implicit-return expression. `runtime-diagnostics-compile-red.log` records this. Independent review found one P1; the implementer is correcting it. This compiler attempt is not counted as a runtime experiment.
