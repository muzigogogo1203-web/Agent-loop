# 065 cold-gate failure — bounded read-only analysis

## Conclusion

The retained failure proves that the cold-gate readiness file was absent at the test's final three-second check. It does **not** identify why the child had not published it. Source inspection does establish a separate test-lifetime defect: this throw skips explicit backend cancellation and stream joining, while the enclosing defer closes the socket-directory authority and removes the harness tree without waiting for the live backend.

The cold gate uses its own `ShellProcessRegistry()` and its own backend mechanics state. A direct shared-registry cancellation edge is not present in this fixture's construction, and the retained signal capture contains no path-2/shared-registry send. There are still shared environment/executor/host resources; their existence is not evidence that they caused this timeout.

One observed backend owner/PID is a plausible cold-gate candidate, **not a proven fixture identity**. That candidate was reaped; it must not be described as a confirmed living orphan. Its Board-stop/finalization completion is not present in the retained capture. No process signal or filesystem cleanup is authorized by these historical identities.

## Inputs and scope

Read current `ExecutionEngineConformanceTests.swift`, its 065 harness/inspector/backend construction and cold-gate segment; `CliProcessBackend.swift` launch, ownership, spawn, cancel and finalize paths; `ShellProcessRegistry.swift`; and the relevant Board stop/wake path. Used systematic-debugging to trace the thrown error back through the actual ownership boundaries, without proposing a readiness behavior change.

Retained run evidence:

- `runtime-combined-full.log:2314–2315`: `p1f1_065CancellationCleansProcessAndCommitsOnce` catches `coldGateReadinessTimedOut`, total test duration 23.300 s. The source location 4984 is the test declaration, not the throwing guard.
- `runtime-combined-full.log:2377–2378`: full run 1091 tests / 31 suites, 63.440 s, four issues. The Board/075 negative-child messages elsewhere in this log are not extra top-level issues.
- `runtime-combined-process.txt`: RunTests PID **33956**, start `2026-09-06 02:09:14`, end `02:10:18`, exit 1.
- `runtime-combined-events.ndjson`: 3294 JSON records, including one non-event metadata record; lifecycle events include the main RunTests and isolated test-child PIDs. Candidate analysis below uses processID 33956 only.
- `runtime-combined-resources.log`: pressure level 2 before/after; swap used 17973.06 MiB before / 17949.06 MiB after, free disk 4.0 GiB / 2.1 GiB. This is host context, not an attribution of the cold-gate failure.

No build, test, source edit, signal, App/Provider invocation, OS-log extraction, new agent or commit was performed. Only this report was written.

## Actual creation, launch and wait sequence

1. At `ExecutionEngineConformanceTests.swift:4985–4986`, `gateHarness` is created with label `gate`; `defer { gateHarness.remove() }` is installed immediately. Harness construction (`:453–563`) creates a unique `/tmp/al65-gate-<random>` root, workspace, a controlled executable wrapper that execs `/bin/sh`, authority objects and a harness-local process inspector. That pattern is a source fact, not a recovered concrete path from this run.
2. The same harness first exercises production-signature and injected-signature rejection, then a separate `abortHarness` exercises pre-registration-abort cleanup. Those operations precede the cold gate. Thus the test's 23.300 s total cannot be used as the cold-gate readiness interval.
3. At `:5235–5254`, the cold branch creates a new signature revalidator, **fresh** registry, backend and request. Its exact source execution ID is `00000000-0000-4000-8000-000000000065`. The controlled command installs an ignored TERM handler, creates its `cold-ready` argument path, then loops. This readiness condition is file publication, not stdout; lack of a stdout event alone is expected for this command.
4. `p1f1d065GateBackend` (`:806–819`) passes that fresh registry and the harness inspector into the real backend. Defaults remain TERM grace 5 s, KILL grace 2 s, drain grace 1 s. This is not a mocked process driver.
5. `coldGateStream = gateBackend.launch(gateRequest)` (`:5255`) runs the AsyncThrowingStream builder synchronously. Backend `launch` (`CliProcessBackend.swift:361–388`) creates an execution object, registers it by execution ID in the backend-local mechanics state, installs stream termination handling and schedules its existing `run` Task. No iterator needs to be started for launch to begin.
6. The run Task validates inputs/signatures, awaits the shared login environment, starts its Board server, spawns a new **suspended** process group, validates that group, registers `-processGroupID` in the supplied registry, starts reaping/draining tasks and calls the supplied inspector's SIGCONT method (`CliProcessBackend.swift:603–735`, `:910–1130`). It publishes registration and starts completion independently of the test's stream iteration.
7. The test creates a deadline three seconds after `launch` returns and polls `fileExists` with a throwing 10 ms sleep (`ExecutionEngineConformanceTests.swift:5259–5269`). The deadline includes launch-task scheduling, environment acquisition and child startup before file publication. It does not wait for or inspect stream failure during this interval.
8. Only after readiness succeeds does it explicitly await `gateBackend.cancel`, iterate the retained stream, and assert TERM sent, EOF, reaping, an exited frame, exact signature-call sequence and an empty registry (`:5271–5281`). The stream is intentionally still unconsumed until this cancellation. A future lifetime repair must preserve this cold-stream property.

## Ownership and timeout-cleanup guarantee

At the observed readiness guard failure, the explicit cancellation at line 5271, stream iteration at 5275 and all following cold-gate evidence assertions are skipped. An earlier `Task.sleep` throw would similarly escape this segment. There is no catch/finally-style asynchronous cleanup owner for this cold branch.

Backend ownership is substantial but is **not a checked test cleanup guarantee**: mechanics state retains the execution; the execution retains its request/authority/continuation and mechanics owner; `run` and finalization own their tasks. Stream `.cancelled` termination can schedule `requestStreamCancellation()`, but that method starts an unjoined Task and catches its cleanup error (`CliProcessBackend.swift:578–587`). Throwing from the test is not an explicit awaited backend cancellation. This report does not assume when ARC or stream termination runs, or that it never runs.

Harness `remove()` (`ExecutionEngineConformanceTests.swift:626–636`) only checks/closes its directory authority, recording an issue on close failure, then uses `try? removeItem(at: root)`. It neither cancels/joins the backend nor proves PID/group/reaping/socket absence. File deletion failure is suppressed. Destruction of that directory before backend completion can itself invalidate outstanding cleanup dependencies.

There is a concrete downstream risk: Board stop wakes an accept-loop-owned listener by connecting to its **socket path**, then waits for the accept group (`BoardToolServer.swift:395–449`). Removing the harness tree/socket before this stop can make that wake path unavailable. `wakeAcceptLoop` (`:1017–1058`) treats ENOENT as a non-error return; that return alone cannot prove a blocked accept was awakened. This is a source-level consequence of premature fixture teardown, not a proven cause of the original readiness timeout or a proven explanation of the candidate's missing stop-completion event.

Therefore the correction target justified by current source evidence is **fixture lifetime/cleanup ownership**, not longer readiness waits or changed production launch behavior. No new unsafe reproduction should be launched simply to reconfirm the already-observed throwing path before a bounded ownership plan is reviewed.

## Safe observed identities and correlation limits

The backend's diagnostic owner is a fresh private UUID (`CliProcessBackend.swift:532`), unrelated to request execution ID. No backend owner→execution-ID mapping is printed here. The 065 harness also does not print its concrete root, process-group history or readiness observation. Its inspector retains signal `(number, group)` tuples internally, but the public assertion snapshot returns only signal numbers; it does not use the newly added per-syscall signal logger.

Source-derived identity: the cold request's execution ID ends in `...0065`. **No matching execution ID, `p1f1d-065-cold-gate` label or concrete `al65-gate` root appears in the supplied lifecycle event messages.** The raw full log also supplies no 065 fixture identity line. An actual cold-gate PID or directory cannot be recovered with certainty from these inputs.

Observed candidate only: backend owner **B2563D83-5FC4-4CAF-BB4C-6DA3CB12E020**, child PID **34193**, emitted by RunTests **33956**. Its order after another backend's pre-registration-shaped abort and before later suite activity is compatible with the source sequence; compatibility is not a direct identity join. The execution suite itself is serialized (`ExecutionEngineConformanceTests.swift:4342`), but other suites and backend instances still run concurrently.

Candidate timeline from `runtime-combined-events.ndjson:2920–2945`, `:3126–3130` (wall clock `2026-09-06 -0700`; relative time is computed from its `mono` run-queued event):

| Event | Wall time | Seconds after run queued | Meaning |
| --- | --- | --- | --- |
| `cliRunQueued` | 02:10:03.738568 | 0 | Backend start Task queued. |
| `cliRunStarted` | 02:10:03.761825 | 0.023256 | Task entered. |
| `cliEnvironmentRequested/Ready` | 02:10:03.763205 / .763209 | 0.024638 / 0.024642 | This candidate's environment await returned in about 3.625 microseconds. |
| `cliSpawned`, value 34193 | 02:10:03.764873 | 0.026306 | Actual spawned PID for this owner. |
| `cliSIGCONTReturned`, value 34193 | 02:10:03.765048 | 0.026481 | Inspector call returned, not proof of readiness or even a logged syscall success. |
| `cliStdinFinished`, value 0 | 02:10:03.937816 | 0.199249 | Parent's stdin operation completed; not proof the child consumed it or ran the trap. |
| `cliWaitpidReturned`, value 34193 | 02:10:06.739010 | 3.000441 | This actual child was reaped by its backend. |
| `cliReaped`, value 0 | 02:10:06.739034 | 3.000466 | Reap result contains a decoded status, **not** necessarily exit status zero. The status value itself is absent. |
| `cliStdoutFinished/cliStderrFinished`, both 0 | 02:10:06.840376 / .840380 | 3.101806 / 3.101813 | Both readers reported EOF. |
| `cliServerStopStarted` | 02:10:06.840390 | 3.101824 | Entered Board-stop await. No `cliServerStopFinished` or `cliFinalizeFinished` for this owner occurs in the capture. |

The full capture includes later main-process events through 02:10:14.771183, but absence remains an incomplete completion observation, not proof of a particular hang or error. Reaping near three seconds is suggestive timing only: the exact cold deadline/guard/removal phases and this execution's exit status were not recorded.

Parent separately reports a later read-only `ps -p 34193` found it absent. That is compatible with the retained reap and is **not** a missing fixture-identity join, process-group absence certificate, or cleanup authority. Do not signal 34193 or delete any guessed `/tmp/al65-*` directory. Unknown retained roots require current exact ownership and cleanup-completion evidence; a historical label or reused PID cannot supply it.

## Independent versus shared edges

- **Independent, established by source:** cold `gateRegistry` is not `.shared`; backend mechanics registration and execution-ID namespace are private to that backend; harness root, directory authority, revalidator and inspector are fixture-local. The shared registry does not acquire this PID through the cold-gate code path.
- **Actually shared, not causal proof:** `LoginShellEnvironment.shared`, process-wide executor/dispatch resources, operating-system process and file resources, and the pressure-constrained host. The candidate above has a short environment await; that measurement cannot be relabeled a proven cold-gate interval without the missing owner join.
- **Retained signal evidence:** 11 signal-call owners appear: 10 path-0 fixture-inspector calls, one path-1 nonshared-registry call, zero path-2 shared-registry calls. The path-1 call targets positive PID 34183, not the candidate 34193. It must not be reassigned to this gate.
- **Signal coverage gap:** `P1F1D065ProcessInspector.send` (`ExecutionEngineConformanceTests.swift:399–439`) performs its own `Darwin.kill(-group, signal)` and accepts ESRCH as return success. It is not the instrumented `CliBackendTests` inspector. Thus no processSignal record for 34193 does not prove that no signal was sent, and `cliSIGCONTReturned` does not distinguish syscall success from ESRCH.

The available evidence supports neither a shared-registry kill diagnosis nor a general production launch/ready-file cause. The cold test's unconsumed stream also means an underlying launch/exit error can be hidden behind the file-only readiness timeout until a real stream join is performed.

## Next bounded check / planning boundary

Recommend a separately approved **test-only cold-gate lifetime correction plan** before another real cold-gate execution:

1. Preserve synchronous launch, the unconsumed-until-cancel cold property, the original three-second/10 ms readiness checks and all success assertions. Retain the actual primary readiness error; do not turn cleanup into a pass or replace it with a generic error.
2. Own exactly one backend cancellation result and an uncancelled stream join on success and every throw after launch, before closing the directory authority/removing the root. Check actual PID/group/reaping/socket/registry outcomes; retain/report the owned root when cleanup cannot be certified. Do not replace these with registry-count-only or `try?` cleanup.
3. Add a bounded real forced-error-after-readiness regression under that same ownership, so the failure branch itself proves cleanup. Avoid an additional unmanaged RED process. No production grace, scheduling, priority, task-pool or suite-serialization change is justified.
4. During the next parent-owned single focused observation, retain fixed test execution-ID/fixture-owner/actual signed signal-target joins, exact syscall result/errno from this inspector, readiness start/end Bool, and the actual joined decoded exit result. Avoid payload/secret logs. Join backend `cliSpawned` to the test via the observed PID rather than timing guesses; keep Board-server identity as a separate unresolved edge unless explicitly mapped.

This is a proposed next boundary, not an approved implementation plan or source ownership assignment. No plan/source work is started by this report. The startup/file-publication cause still requires correlated evidence after safe lifetime ownership is in place.

## Integrity and release

Current read source hashes:

- `ExecutionEngineConformanceTests.swift`: `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f`.
- `CliProcessBackend.swift`: `20d5b42d7b768c6e3eb3f6c3ea770e358d7a328358ba7d1fa9da810a0241ed89`.
- `ShellProcessRegistry.swift`: `6fb67675a2291443fc2dfdec1212fa9edd2e5c8ecd8fb79b22b2010035ca3323`.
- `BoardToolServer.swift`: `33f7c9017e86d964e8ffc1ae387820a6aac0bed4543d3eab016af5cd27c5d079`.

Evidence hashes: full log `8ebd486da4fd1366eff835e99ffcbb5a4de77d74fd68ae8d7e04d79cc07fca75`; event capture `6837c7547d9cebf361e462b9ffecd93b6b5e46bc04038ac5a8d71fc732129a88`.

The combined run's nine-file `runtime-combined-source.sha256` includes the backend/registry/Board source hashes above, but does **not** include `ExecutionEngineConformanceTests.swift`. The latter is the current read hash, not a claimed run-time pre/post hash from that wrapper. Include it in the next scoped freeze.

**Read-only analysis is complete; `runtime-cold-gate-analysis.md` document ownership is released. Source ownership remains with parent.** Runtime acceptance is still red.
