# Runtime diagnosis from the bounded instrumentation experiment

Status: a production scheduling defect is now measured at managed-drain and Board accept boundaries. The default full suite is still red. This report selects the next repair; it does not claim every runtime failure has one proven cause or that any repair is complete.

Only this report was written by this investigator. No builds, test runs, code changes, new samples, or app/data actions were performed.

## Evidence identity and result

- Parent RunTests PID: **85204**. Launch/end window recorded in `runtime-observed-process.txt`: 2026-09-05 23:16:14–23:17:12 local time.
- `runtime-observed.log:2277`: default concurrency, 1086 tests, 31 suites, 57.259 seconds, eight issues, exit 1.
- Two issues belong to one historical source-inventory test (`runtime-observed.log:179–180,730`): the approved diagnostic source adds a 103rd enumerated file. The parent handles that frozen-list update separately. It is not a runtime failure.
- The other six issues are 075, the two Board tests, the two CLI cancellation tests, and the shell timeout test. In this experiment, both CLI cancellation tests fail at **readiness**, not at the historical cleanup-timeout error (`runtime-observed.log:2144–2147`). Do not describe those errors as unchanged.
- `runtime-focused-events.ndjson` and the focused log establish an isolated 075 pass (35.680 seconds). It is a diagnostic control, not the acceptance gate.
- Event comparisons below use the emitted monotonic nanoseconds, not timestamps of log retrieval. All cited event line numbers refer to the retained NDJSON files, which can also contain metadata records.

## Definite cause: work did not start before the consumer's deadline

### 075 fails in the no-process live-drain ownership helper

Parent composition owner `93C83D31-28F8-4F6A-8EFF-36F016094165` finishes helper index 5, starts **index 6**, and never records index 6 completion (`runtime-observed-events.ndjson:15–16`). Index 6 is `p1f1d075AssertLiveDrainOwnership`, not CLI help capability probing. This helper creates pipes but no subprocess.

Drain owner `AA725125-AA39-46E3-B6EB-45618C2435C6` provides the causal sequence:

| Boundary | Monotonic nanoseconds | Evidence line |
| --- | ---: | ---: |
| stdout queued | 92326738613875 | 17 |
| stderr queued | 92326738647250 | 18 |
| join attempt 1 started | 92326738661375 | 19 |
| join attempt 1 timed out | 92327739715625 | 20 |
| join attempt 2 started | 92327739754166 | 21 |
| join attempt 2 timed out | 92328741087000 | 36 |
| stdout worker actually started | 92342262713125 | 39 |
| stdout EOF / finished | 92342262819166 / 92342262823166 | 40–41 |
| stderr worker actually started | 92342262827083 | 42 |
| stderr EOF / finished | 92342262847208 / 92342262849791 | 43–44 |

The two worker start delays are **15.524099 seconds** and **15.524180 seconds**. Both one-second join attempts expire before either worker starts. Once started, stdout reaches EOF in approximately 106 microseconds and stderr in 20 microseconds. Thus the failing second join is caused by worker admission/scheduling delay, not a surviving child, slow pipe read, or a process-group cleanup deadlock.

The focused control (`runtime-focused-events.ndjson:14–26`) starts the two workers after approximately 92 and 21 microseconds. Its deliberately expected first timeout occurs while writers are open; after closing writers, join attempt 2 succeeds in approximately 89 microseconds and helper index 6 completes. This confirms that removing the second timeout or extending its duration would conceal the observed scheduling defect.

Helper index 5 also takes 6.828830 seconds in the full run versus approximately 0.279 milliseconds in the focused control. It uses a task group around a synchronous lazy cell. This establishes workload sensitivity but does not identify the responsible executor owner; it is not necessary to guess that cause to repair the proven drain admission defect.

### Board stop waits for an accept callback which has never started

Board owner `D4C5BD16-D042-4755-AED2-610CF3F93FD6`:

- queued at `92329703935041` (`runtime-observed-events.ndjson:37`);
- stop begins at `92334706615750` (line 38);
- callback first starts at `92342262855208` (line 45), a **12.558920-second admission delay**;
- callback finishes 3.750 microseconds later (line 46);
- accept group joins at `92342263006625` (line 47).

Stop spends **7.556385 seconds** waiting for a queued callback, not a running accept syscall. The callback starts within 29 microseconds of the second delayed drain worker and immediately terminates because stop already happened. The common utility scheduler admission boundary is directly measured.

The previous unchanged-binary `runtime-sample-later.txt:273–297` showed a cooperative worker inside `boardSocketClientDistinguishesTimeoutFromEOF` cleanup, blocked at `BoardToolServer.stop` / `acceptGroup.wait` for all 72 samples. That stack supports the synchronous-wait dependency. It is from a different run and is not used to assign the current UUID to a named test.

### CLI finalization delays are independently attributable to the same Board admission boundary

For CLI owner `6C302B88-F587-4971-BB71-A45F1D6F7445`, the finalizer has observed a reaped leader and successful stdout/stderr EOF before entering server stop (`runtime-observed-events.ndjson:126–129`). Board owner `11BF1BBE-F43E-4D82-951C-821F5BDC10F6` receives stop immediately afterward (line 130). It does not start its accept callback until line 242, finishes immediately, and both finalizers settle.

| CLI owner | Associated Board owner, inferred from adjacent stop timestamps | Server stop duration | Evidence |
| --- | --- | ---: | --- |
| `6C302B88-F587-4971-BB71-A45F1D6F7445` | `11BF1BBE-F43E-4D82-951C-821F5BDC10F6` | **6.692631 s** | lines 126–130,242–254 |
| `205BE242-D10B-48D9-98E3-B49FEAFFEC28` | `FA3CC5AE-E7E2-4710-8D85-E16233F63B6C` | **4.674057 s** | lines 137–142,233–241 |
| `3740F82F-49BE-4B6E-A568-2A586514916C` | `BC341F56-0DAA-4350-8C4B-6CB779A8E52A` | **5.822905 s** | lines 131–136,244–256 |

The first two CLI owners finish successfully after this wait. The third already has stderrEOF=false before stop, and ultimately fails; do not attribute that prior EOF failure to server.stop. The CLI-to-Board association is an inference from nested synchronous calls and immediately adjacent timestamps, because the diagnostic schema does not emit an explicit cross-owner mapping. Each owner's own queue and duration measurement is direct evidence.

Several Board owners show another admission-delay cluster of approximately 8.25–8.37 seconds, followed by nearly simultaneous starts around monotonic `92350760...`. Other Board owners start in tens of microseconds during the same run. The defect is inconsistent forward progress of long-lived blocking I/O submitted to shared scheduling, not universally slow socket operations.

## Conclusions that are not established

- The exact Darwin/libdispatch policy producing the admission delay is unmeasured. Earlier samples did **not** show a utility pool filled with running blocking I/O; they showed cooperative/GRDB activity and parked workqueue threads. Do not describe thread-pool exhaustion as proven.
- The two current CLI readiness failures are not mapped to diagnostic UUIDs. Two finalizers begin and have no subsequent reap event, but without an explicit identity map that cannot establish why a particular test's stdout-ready deadline expired.
- ShellTool and login capture were not instrumented in this experiment. Their global-utility blocking readers remain plausible related owners, but this trace does not prove the shell timeout's exact stalled interval.
- A real descendant or process-group survival bug elsewhere is neither proven nor ruled out. The measured 075 failure involves no process, and the two successful finalizers already observed complete process/pipe evidence.
- OSLog instrumentation changes execution cost. The measured 15.5-second queue delay is nevertheless between explicit enqueue and actual callback-entry events, and the unchanged-source run previously exposed the same drain/Board boundaries. It cannot be dismissed as an imprecise test timer.

## Selected bounded repair

Repair the **execution ownership and synchronous waiting boundary**, not its time limits. No additional general diagnostic run is required before implementing this increment.

1. **Managed probe drains:** run the two owned blocking pipe workers on explicit named native Threads rather than global utility callbacks. Retain the existing bounded polling, stop flag, byte limits, descriptor ownership, worker accounting, join attempts, and cleanup errors. Each worker must close its own descriptor exactly once and publish completion on every path. Keep the measured queued/started/completed events so the next full run verifies admission improvement.
2. **Board accept and handler owners:** give the live blocking accept loop and active handler independent native-thread execution. They cannot share one serial executor because accept can block indefinitely while a handler needs to run. Preserve the existing one-active-connection rule, peer validation, listener-generation checks, stop wakeup, shutdown-before-close contract, and group completion. Preserve **explicit test scheduling overrides** for the tests which intentionally suspend accept/handler queues; adjust generic fixture defaults to select the live owner, rather than silently leaving tests on the rejected global scheduler. A renamed DispatchQueue targeting the same global root is not an adequate ownership change.
3. **Async Board stop seam:** retain the synchronous stop contract for existing synchronous callers and FD lifecycle tests, but add an async entry point for asynchronous runtime callers. It must execute the entire potentially blocking stop/wakeup/join on an explicit blocking owner and resume a checked continuation with the unchanged result. Convert the two asynchronous production call sites in `CliProcessBackend.swift` (launch-error cleanup currently line 686 and finalization currently line 1213) to await it. Cancellation of the awaiting caller must not cancel mandatory cleanup or lose a failure. Do not implement this seam as `Task.detached { try stop() }`, which returns the blocking work to the Swift pool.

The async seam is necessary even with independent accept/handler Threads: Board's handler executes a ToolExecutor Task and then waits on a semaphore. If a Swift worker synchronously waits for handler completion while future Swift work is required to complete that handler, independent I/O threads alone leave a dependency on cooperative worker availability. The awaiting runtime caller must suspend. No need to rewrite the Board protocol, tool executor, or terminal arbitration to address this boundary.

The existing blocking `waitpid(...,0)` inside a detached Swift task is another explicit boundary violation. It can be moved to the same narrow native blocking-work mechanism while preserving its existing Task/result facade, but it is **not** the measured cause of the two successful finalizers' stop delays. If included, document it as directly related executor isolation and validate its cancellation/reap contract; do not claim this trace proves it caused readiness failures. Avoid broad migration of unrelated provider/database/test execution in this increment.

Thread lifetime must be bounded by active owned work, not implemented as a growing global pool. Document the per-active-execution thread count, record zero active owners after complete teardown, and retain failure propagation. Do not raise QoS, increase grace periods, remove lifecycle joins, reduce database coverage, or serialize the entire suite.

## Regression and acceptance for this repair

- The repeated default full-run failure is the existing red reproducer; there is no need to add a brittle CPU/thread-saturation test.
- Retain 075's real open-writer timeout, second-join success, surviving-group stop, worker-zero, and descriptor-close checks. Retain Board's 20/100-iteration lifecycle loops and explicit suspended-queue tests, which assert meaningful ownership behavior.
- Add one narrowly scoped async-stop regression if the new seam is introduced: use a controllable async tool handler; wait for handler entry; start async stop; prove a peer Swift task can release the handler; then require stop to return with original handler/accept completion and socket ownership evidence. Use a condition/continuation handshake, not an arbitrary sleep or machine-saturation threshold. A bounded watchdog is only failure containment and must report the stalled phase.
- Give the two Board looping tests a reliable throwing-path cleanup owner if their implementation is touched: resume suspended test queues before joining, close clients, then stop/close the harness while preserving the primary error. Their current success-only cleanup can amplify a test failure into retained accept ownership. This is not the cause of the earlier no-process 075 failure.
- Run the existing relevant process/drain/Board tests once to catch ownership regressions, then **one default-concurrency full suite** with diagnostics enabled. Retain the complete stdout/stderr and same fixed-schema trace. The measured owners should start promptly enough for the unchanged contracts and finish with matching cleanup evidence; the suite itself must pass. A focused pass alone is not acceptance.
- If residual shell/readiness failures remain, use the retained event boundaries to select their actual next owner. Do not replace them with a blanket timeout adjustment or claim that all six causes were proven here. Report and repair any residual causal boundary before the installable-candidate gate.

Independent review should specifically inspect native Thread capture lifetimes, continuation exactly-once completion, stop from cancelled tasks, concurrent stop compatibility, wakeup failure propagation, test override semantics, and FD close/identity ordering before accepting the repair.
