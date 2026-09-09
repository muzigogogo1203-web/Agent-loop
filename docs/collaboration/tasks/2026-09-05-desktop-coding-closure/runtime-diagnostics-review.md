# Runtime diagnostics independent review

Verdict: CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2.

Scope: the five-file `runtime-diagnostics.diff`, Task 1 brief and source report, and Global Constraints in `runtime-diagnostics-plan.md`. Inspected current surrounding Board accept/stop, probe drain, and CLI finalize code. Reviewed diff SHA-256: `c902251f5301a630fdbce33b1cb4e5bd0d071ed772523144d51c9cebd2db6067`.

## Required correction

- **P1 — Restore the return from probe drain finish.** `Sources/AgentLoopCore/Kernel/Orchestrator.swift:8155`: adding `let diagnosticId = diagnosticId` makes `finish()` a multi-statement function, so `try barrier.join(...)` no longer implicitly returns `EngineManagedProbeCapturedOutputV1`. The instrumentation does not compile. Change this statement to `return try barrier.join(...)`. Parent-produced `runtime-diagnostics-compile-red.log:134` confirms the missing-return compiler error; the adjacent unused-result warning has the same cause. The build failed before any focused test executed.

## Static specification and quality assessment

Apart from the compile blocker, the reviewed diff conforms to the fixed instrumentation scope:

- The sink is disabled unless `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`. `.notice` OSLog uses the required subsystem/category and only a closed stage enum, random UUID, monotonic uptime nanoseconds, and integer values. No command, token, path, environment contents, descriptor, error text, or user text is emitted; no stdout/stderr sink is introduced.
- Board accept and handler events occur at enqueue, actual callback entry, and deferred callback completion. The accept UUID capture is independent of weak self. Existing weak accept ownership, strong handler ownership, group entry/leave order, signalStop, waits, socket cleanup, and error propagation remain intact.
- Probe drain retains utility dispatch, both original workers, descriptor ownership/close handling, worker counts, cancellation checks, and the one-second join wait. Worker event values consistently identify stdout as 0 and stderr as 1; join values use the existing retry boolean for attempts 1/2. The closure captures the UUID value without retaining the drain owner. The required return correction restores the original result propagation.
- CLI finalize retains stdin/reap/stdout/stderr await order, termination/unregistration, Board stop, file cleanup, and first-failure precedence. Stdin and server-stop outcomes are logged on both success and catch paths. The finalize defer marks success only after evidence construction. No error is swallowed or replaced by instrumentation. These timestamps describe observed await completions, not the OS reap/EOF instants.
- All ten existing composition calls remain in order with unchanged arguments and throwing behavior, bracketed by indices 0 through 9. No assertions, timeout, wrapper, or failure handling changes appear.
- No new queue, thread, actor, explicit lock, observer closure, timeout, serialization, provider, persistence, or authority change appears. Logging and UUID generation add ordinary diagnostic overhead; static review cannot establish zero timing perturbation.

## Acceptance boundary

This reviewer did not build, run tests, launch the app, or edit source. Only this report was written. The implementation report's source completion does not establish compilation or runtime acceptance. After the return correction, parent must complete the planned compile/focused test and actual-PID OSLog visibility gate before the default-parallel diagnostic run. No runtime causality or log-delivery claim is approved by this review.

## Fix 1 re-review

Source-review verdict: APPROVED — the single P1 is addressed; 0 remaining P0 / P1 / P2 in this scoped review. Build and runtime acceptance remain PENDING parent evidence.

Inspected `runtime-diagnostics-fix1.diff`, the updated Task 1 report, and current `EngineManagedProbeLiveDrainV1.finish()`. The only source correction is the explicit `return try barrier.join(...)` at line 8155; other delta entries are diff timestamps/context. This restores the original returned value and propagates the original thrown errors without changing the diagnostic closure, wait, retry, result construction, or ownership. No new issue is introduced by that line.

Corrected full diff SHA-256: `525b9958d85735709a59a42bb622d8a331d76115ee052017ca6b450593a3a9cf`. Parent reported compilation plus exact 075 verification running under `/tmp/agentloop-runtime-focused.vkpWJd`; this review does not claim that run passed. The final parent output will be recorded in `runtime-focused.log`. No builds, tests, app launches, or source edits were performed by this reviewer during re-review.
