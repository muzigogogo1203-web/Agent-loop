# Independent review — runtime blocking-owner repair plan

Decision: **APPROVE for implementation**, with the implementation and validation requirements below. No additional architecture decision or general diagnosis run is needed before this scope starts. This is plan approval, not acceptance of an implementation or test result.

Reviewed `runtime-repair-plan.md` against the measured queue delays and current Board/drain/CLI source. This reviewer did not implement the proposed repair and performed no build, test, sample, source edit, or application action. This review file is the sole write.

## Why the scope is justified

The measured defect is admission delay before managed-drain and Board accept callbacks start. Moving these blocking owners off the shared global queue directly addresses that boundary; increasing a grace period would not. Native utility Threads preserve the intended QoS without pretending that a named queue reserves a thread. The plan correctly leaves ShellTool, login capture, and waitpid unchanged until residual evidence selects them.

The async stop seam is necessary alongside native I/O workers. `BoardToolServer.stop()` waits for handler completion, while a handler can synchronously wait for future ToolExecutor Task work. Moving only the handler would still allow a Swift caller to block the cooperative worker needed by that future work. The planned checked continuation suspends that caller while the existing synchronous stop contract executes on a blocking owner. Converting the two CLI call sites is the complete production call-site set found in this source snapshot.

The four-file scope is sufficient. Keeping optional injected queues is an explicit test scheduling policy, not an error-swallowing fallback. Preserve all individual tests that intentionally suspend their supplied queues; generic fixture defaults should exercise the new production owner.

## Required implementation details

1. **Publish one async stop attempt atomically.** Append the continuation and decide whether to launch under the same short lock. Set in-flight before unlocking. Start the native Thread only after unlocking. Otherwise two callers can both launch a cleanup thread or a completion can race registration.
2. **Capture the complete result before releasing the attempt.** The cleanup owner must retain the server until `stop()` has returned/thrown. Under the same lock, take and clear the current waiter array and reset in-flight; unlock; then resume every captured waiter with that one `Result<Void, Error>`. A caller registered after reset belongs to a new attempt and must not receive the prior result accidentally. Neither group waits nor continuation resumption belongs inside the state lock.
3. **Preserve retry/error semantics exactly.** Do not cache success/failure as a permanent Task and do not normalize a real error into success. A later stop retry must execute the real checked cleanup. Existing `cleanupLock` already serializes `unlinkOwnedSocket`; do not remove it when adding the async attempt state. Existing synchronous stop callers can overlap async stop without creating a second async waiter registry or changing FD ownership.
4. **Keep native owner captures and completion equivalent.** Accept's closure retains its existing weak-self behavior and captures the immutable diagnostic UUID separately. Handler keeps its existing strong capture. Drain keeps its state/control/group/UUID captures. Every existing defer must still close/report/leave in the same order. A scheduling helper must accept `@Sendable` work and must not introduce main-actor isolation or an unstructured Swift Task. No lock may be held across Thread start or task continuation delivery.
5. **State the precise worker bound.** One active accept owner and one active handler operation per Board instance are existing logical bounds. The old handler can be in its close/defer tail when the next connection claims the slot; this is not proof of a strict maximum of one simultaneously alive OS thread. Do not add a new queue/semaphore just to force that stronger bound. No thread may remain blocked after the corresponding group has joined, and no unbounded array of Thread objects is needed.

The planned flag reset before resuming captured waiters is valid: stop has already completed. A later native cleanup attempt may start while the previous Thread is delivering results, but at most one attempt performs the blocking stop at a time. Do not describe that short delivery overlap as a second in-flight cleanup join.

## Required regression precision

- Include a **cancelled async waiter** in the controlled-handler regression. Once an async stop has demonstrably begun (the existing observable socket shutdown/EOF boundary can establish this), cancel that caller, release the handler using independent async work, and require cleanup and the original success/error to reach all waiters. Cancellation must neither strand the continuation nor bypass cleanup. This is a small addition to the proposed test, not a new production hook.
- The held handler queue must be released on every throwing/assertion-failure path before any synchronous cleanup join. Close clients and explicitly observe cleanup results. Avoid a defer that itself deadlocks behind the still-suspended queue.
- The existing socket-replacement fixture supports the real error/retry scenario: preserve the original socket under its moved name, install a replacement to make identity-checked unlink fail, require all callers to observe the failure, remove the replacement and restore the original identity, then retry. Do not close the directory authority before retry. Verify the replacement identity was untouched by the failed attempt.
- Do not use a pre-call latch or `Task.yield()` as proof that every caller has already registered in the private waiter list. Those establish scheduling opportunity, not registration. Behavioral tests can establish that overlapping calls all receive the real result and cancelled callers do not break cleanup; the short-lock publication/take invariant is also reviewed directly in the implementation. Do not add a private waiter-count hook merely to claim stronger test observability.
- Keep the original open-writer, join, socket ownership, and full-run thresholds. A focused pass is intermediate verification. Acceptance requires the default unfiltered authoritative suite plus independently reviewed ownership/error semantics.

## Other observations

The existing two looping Board tests have success-only harness closure on some throw paths. This is an adjacent failure-amplification concern, but the approved four-file plan does not require a broad rewrite of those existing loops to fix the measured admission defect. The new regression must have complete teardown; if the implementer touches old teardown, show it as a separate narrowly explained diff and preserve primary errors.

The historical source-inventory successor update should remain a separate exact change admitting the one approved diagnostic file. No new production helper file is required for this repair. The accidental SPI `--help` execution is not a gate; the parent must finish and account for its owned run before any build starts, as the plan already states.

Proceed with the bounded implementation and responsibilities-separated diff review. Remaining runtime failures must retain their concrete names/errors and get evidence-selected follow-up; neither this plan nor the diagnosis claims that all six failures are already solved.
