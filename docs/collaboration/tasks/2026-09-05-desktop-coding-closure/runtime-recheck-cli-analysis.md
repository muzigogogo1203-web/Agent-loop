# Full recheck — exact CLI failure boundary

The new full run completed **1090 tests / 31 suites / 61.428 s / 3 outer issues / exit 1** (`runtime-recheck-full.log:2321`). The remaining CLI failure is **346 readiness**, with successful checked cleanup. The evidence now localizes it after process resume and reader entry, before any recorded positive stdout callback. It does **not** establish a scheduler, child-startup, signal-interference or environmental root cause.

## Evidence boundary and identity joins

Read the full recheck result lines, process record and all CLI events from the **2433-event** capture. The actual parent is PID **22458**, command interval **01:20:41–01:21:44**. The expected-failure child 22524 is a deliberate nested regression, not a fourth outer failure. The source manifest independently checks **all seven files OK**. Resource files show pressure level **1** before the run and at the later post-run capture; the parent additionally reports level 1 during the run. This does not establish a cause or make current timings interchangeable with either preceding run.

| Execution | Recorder UUID from explicit identity line | Continued PID | Core owner from exact matching `cliSpawned` PID | Result |
| --- | --- | ---: | --- | --- |
| 346 | `1F417654-54EF-45EF-AAB2-DE3E1B00BA81` | 22645 | `89ECAC0B-F5D1-4C97-B39E-0539C2A020BE` | readiness failure |
| 372 | `3A96A557-7BE4-49BA-9607-53BD8A56B8E3` | 22641 | `FE64D371-500E-45B3-A39E-F1229BB579E1` | pass |
| 347 | `280D39B5-9D23-45AA-88A4-0956B2EAE69E` | 22643 | `7F0FFB1C-4315-4692-9DA8-5CDD84BF5BEC` | forced-error cleanup pass |
| 152 | `3886A6F3-C145-48FE-A7F4-7F111D70A49E` | 22634 | `BF8DE317-4501-4D16-8D9F-3790DA997AF9` | held-grandchild-pipe pass |

Full execution IDs use `00000000-0000-4000-8000-000000000` followed by the listed three-digit suffix. These joins use the retained identity and checked-cleanup lines, not chronology. All four report **0 resource-observation failures** (`runtime-recheck-full.log:2198–2239`). The parent also verified exact PID/groups absent afterward; this analyst performed no live process checks.

## Failing 346 timeline, compared with the two ready successes

Durations below are **milliseconds**, calculated from full integer monotonic values. For 346, launch-called is **99819289177750** and readiness-start is **99819289233250**. No duration includes prewarm/setup before those anchors.

| Measured interval / stage | 346 failed | 372 passed | 347 passed |
| --- | ---: | ---: | ---: |
| Core run queued → started | 110.247 | 106.759 | 109.227 |
| Core environment requested → returned | 0.003 | 0.004 | 0.003 |
| Core run started → SIGCONT returned | 2.965 | 2.500 | 4.270 |
| Fixture launch-called → SIGCONT returned | 113.239 | 109.279 | 113.506 |
| Reap task queued → started | 347.107 | 20.370 | 26.084 |
| Stdout task queued → started | 347.339 | 30.275 | 350.697 |
| Stderr task queued → started | 347.386 | 30.332 | 350.745 |
| Readiness-start → stdout task started | 460.507 | 139.501 | 464.139 |
| Readiness-start → first stdout bytes | **not recorded** | 2470.476 | 2781.296 |
| Readiness-start → wait-ended | **3020.788, outcome 3** | 2492.547, outcome 0 | 2790.359, outcome 0 |
| Wait-ended → exact waitpid returned | **0.199** | 0.402 | 55.370 |
| Reap task started → waitpid returned | 2560.720 | 2363.359 | 2706.207 |
| Fixture launch-called → joined consumer | 3084.560 | 2573.958 | 2886.422 |

For 346 the stdout drain entered at **99819749742333**, about **460.509 ms** after readiness-start (`runtime-recheck-events.ndjson:2167–2168`). It has no `cliStdoutFirstBytes`, first-yield, consumer-first-stdout or recorder-first-stdout event anywhere in the capture. Readiness ends at **99822310021500**, outcome **3**: deadline reached without the expected frame or stream finish (`:2314`). The owned wait then returns PID 22645 at **99822310220708** (`:2315`), followed by stdout/stderr EOF success, successful finalizer, recorder finish and joined consumer (`:2316–2328`). Thus the captured failure is not a dropped yield, delayed recorder receipt after an observed yield, or an already-terminated stream misclassified as a timeout. No first output is recorded even during the subsequent cleanup.

The reader entered with roughly **2.56 seconds still remaining** before the observed timeout. Admission consumed part of the budget but does not explain all of it. In particular, **347 uses the same TERM-ignoring shell command and the same grace values**, and its stdout task entered at nearly the same point in its readiness window. It nevertheless recorded six bytes and an enqueued first line at about 2.78 seconds, then matched ready and passed the real after-ready termination regression. That is direct counterevidence against attributing 346 solely to the approximately 350 ms reader-task admission delay.

For the passing streams, positive-read callback → yield-return is **0.021 ms** (372) and **0.024 ms** (347); yield-return → recorder mutation is **0.053 ms** and **0.026 ms**. Their larger pre-read gaps therefore do not come from these later measured delivery stages. But first-byte time still combines child startup/write timing with read-loop execution: reader entry is not a first-read syscall marker, and the current logger does not show negative-read outcomes, sleep/wakeup intervals, child-write time, raw child exit status or who sent each signal.

The **0.199 ms** 346 wait return after readiness failure is notable next to the **55.370 ms** 347 wait return after its matched-ready marker. It is consistent with different termination state/timing, but the capture records only returned PID, not raw/decode exit status or TERM/KILL flags on the failed body. Do not infer that 346 installed its TERM trap, died from TERM, was already exiting, or was externally killed from that timing alone. Its original post-ready escalation assertions were not reached.

## Grandchild 152 counterevidence

152 passed its actual `pipeDrainIncomplete`, cleanup and signature contracts, despite a **39.918-second whole-test duration**. Its exact run-task admission was **8924.110 ms**, followed by a **23647.420 ms** environment await; it does not prewarm login before launching as the cancellation tests do. Its spawned process resumed about **32574.484 ms** after fixture launch. Those setup intervals must not be called its 50 ms drain grace or compared to the cancellation recorder's three-second window.

Its stdout worker admission was **108.113 ms**; the first stdout callback occurred **1839.434 ms** after SIGCONT. The actual wait returned PID 22634 and the stderr completion reported non-EOF as expected; finalizer/stream failure was preserved and the test passed (`events:2258–2275`). This supplies useful positive cleanup evidence, not proof that all reader or startup timings are bounded under every concurrent run.

## Shared registry hypothesis: source possibility, not observed causation

The shared-state edge is real: CLI constructors default to `ShellProcessRegistry.shared` (`CliProcessBackend.swift:318,336`); successful spawn registers the **negative process-group ID**; `ShellProcessRegistry.terminateAll()` snapshots and clears every entry and calls `kill(entry, SIGTERM)` (`ShellProcessRegistry.swift:34–42`). Both `Orchestrator.emergencyStop` and `shutdown` call that shared method (`Orchestrator.swift:12181,13071`). Therefore a concurrent test's orchestrator can in principle signal another test's registered CLI process group, bypassing that CLI fixture inspector.

This capture has **no terminateAll snapshot/target/result events, no sender identity for TERM/KILL, and no raw wait status**. The emergency-stop assertion's position in the combined text log cannot establish whether any such call occurred while 22645 was registered, nor whether its target snapshot included that group. The fast post-timeout wait return alone is not that proof. Do not label the remaining three issues a shared-registry failure without an actual registry target and signal ordering.

## Smallest next step

Keep the ownership repair, three-second deadline, commands and concurrency intact. The next bounded attribution should first retain evidence that is currently discarded on a failing body: **actual cancellation `termSent`/`killSent`/reap flags and the joined exited-frame status**, plus a fixed raw-status/decoded-exit marker at the already instrumented wait return. This distinguishes a child that never reached its TERM trap from one that was force-killed later, without changing process behavior.

To test the specific shared-registry hypothesis, add narrowly scoped opt-in fixed markers around the **actual existing terminateAll snapshot targets and signal syscall results**, correlated by the actual negative PID and monotonic time; preserve errno before logging and emit no command/env/token data. Retain actual CLI-owner signal calls in the same vocabulary so a registry signal can be distinguished from owned post-timeout cancellation. A marker that merely says "emergencyStop started" is insufficient. If no external signal to the affected group is observed, proceed to a bounded first-read outcome and existing read-sleep resume marker, rather than converting the reaper or blaming the child from a reader-entry timestamp.

An isolated `ShellProcessRegistry()` is already injectable, so if cross-test shared termination is demonstrated, the smallest repair is **fixture-owned registry injection for these mechanics executions**, with production emergency-stop semantics preserved and separate isolation regression coverage. Treat this as a conditional repair, not a verified readiness fix now. No new full run should be used simply to hope for a preferred result; choose one reviewed bounded diagnostic covering the missing signal/exit edge.

The other two outer issues remain separate: provider cancellation was not observed within the emergency-stop test's own waiting boundary, and the Board blocked-handler test measured a process-wide FD delta of 35. Neither the source-wide FD count nor current CLI timing assigns their root cause. Full acceptance remains red. This analyst wrote only this report and ran no tests, builds, providers, apps, process signals or extra captures.
