# Observed1 CLI readiness: bounded read-only analysis

Status: boundary localized; child execution/read-loop root cause not established. No source edits, test runs, new observations, or process actions were performed for this analysis. This report does not clear the failed full integration gate.

## Evidence and identity

Inputs: `goal-foundation-runtime-observed1.log`, the complete 1,997 rows of `goal-foundation-runtime-observed1-events-admitted.ndjson`, and current `CliBackendTests.swift`, `CliProcessBackend.swift`, `RuntimeLifecycleDiagnostics.swift`. All event rows were parsed; selected owner records were sorted by their numeric `mono` nanoseconds, not log order or whole-test durations. Event references below are one-based admitted-NDJSON lines. Parent separately owns capture admission and source-freeze verification.

The output's execution/recorder association is at lines 2407–2409. Cleanup lines 2521–2522 and 2534 bind executions to actual child PIDs. Exactly one `cliSpawned` event for each actual PID identifies its Core owner:

| Execution suffix | Recorder owner | Actual PID/PGID | Core owner | Spawn event |
| --- | --- | --- | --- | --- |
| 347 | 76D0A18C-713E-4573-A315-E1C860176403 | 83966 | BB3C7449-15B5-4B14-A4E7-0127A931C2F8 | 1099 |
| 346 | BDB3B5D0-A896-4A23-8208-31EA3F86C2E4 | 83965 | 63D2050A-239C-4831-80C4-C12927AE846E | 1074 |
| 372 | C925FACA-9503-4F94-96CE-F84022ED1EA5 | 83963 | F3246036-FBD9-4AD5-B3A4-DBBFAC449628 | 1043 |

## Complete readiness path

All relative times below are milliseconds from that fixture's `cliFixtureReadyWaitStarted`. Its absolute `mono` is respectively **123986784950083**, **123986784220250**, **123986783321208** ns for 347/346/372. Rounded displays are not inputs to calculations.

| Stage | 347 ms | 346 ms | 372 ms |
| --- | ---: | ---: | ---: |
| Fixture launch called | -0.026208 | -0.030709 | -0.043167 |
| Core run queued | -0.015792 | -0.018459 | -0.022917 |
| Fixture launch returned | -0.011958 | -0.015000 | -0.015792 |
| Consumer queued | -0.010417 | -0.013000 | -0.014125 |
| Body started | -0.007542 | -0.010125 | -0.011167 |
| Ready await queued | -0.002708 | -0.008292 | -0.005875 |
| Ready wait started, value 3000 | 0 | 0 | 0 |
| Core run started | 76.471833 | 74.867333 | 50.298167 |
| Launch inputs validated | 77.284458 | 75.749625 | 51.291375 |
| Environment requested | 77.288292 | 75.754666 | 51.297167 |
| Environment ready | 77.290958 | 75.758041 | 51.300250 |
| Environment validated | 77.452833 | 75.932708 | 51.472333 |
| Board start called | 77.725917 | 76.221500 | 51.764250 |
| Board start returned | 77.888333 | 76.367666 | 52.002833 |
| Spawn preparation started | 77.891958 | 76.372083 | 52.007250 |
| posix_spawn called | 78.099958 | 76.576083 | 52.224208 |
| Spawned | 78.409083 | 76.956833 | 52.614750 |
| Suspended validation called | 78.412667 | 76.961166 | 52.619208 |
| Suspended validation returned | 78.456708 | 77.116166 | 52.777667 |
| Reap task queued | 78.463833 | 77.122500 | 52.782875 |
| Stdout task queued | 78.469500 | 77.128958 | 52.789667 |
| Stderr task queued | 78.472000 | 77.132291 | 52.792625 |
| SIGCONT called | 78.474375 | 77.135208 | 52.795792 |
| SIGCONT returned | 78.492500 | 77.157291 | 52.820708 |
| Consumer started | 78.510458 | 77.181875 | 52.845208 |
| Reap task started | 283.832375 | 106.061291 | 95.632667 |
| Stdout task started | 458.963625 | 284.487666 | 103.496458 |
| Stdout drain entered | 458.968958 | 284.495166 | 103.503125 |
| Stderr task started | 458.998333 | 284.532291 | 103.530208 |
| Finalize started (joins work, not a terminal event) | 459.025750 | 284.556625 | 103.553125 |
| Stdin finished | 459.028292 | 284.559291 | 103.555625 |
| First stdout bytes | absent | absent | 2957.448917 (6 bytes) |
| First stdout line yielded | absent | absent | 2957.477750 (enqueued=0) |
| Consumer first stdout received | absent | absent | 2964.359750 |
| Recorder first stdout recorded | absent | absent | 2964.367500 |
| Ready wait ended | 3046.639208 (outcome 3) | 3047.351833 (outcome 3) | 3048.203542 (outcome 0) |
| waitpid returned actual child | 3047.616000 | 3047.877458 | 3049.127458 |
| Stdout finished | 3056.237500 | 3056.980333 | 3088.568292 |
| Stderr finished | 3056.246083 | 3056.986625 | 3088.576375 |
| Server stop started | 3056.255125 | 3056.993541 | 3088.584042 |
| Server stop finished | 3056.568167 | 3057.304041 | 3088.887917 |
| Finalize finished | 3056.576542 | 3057.309291 | 3088.897417 |
| Recorder stream finished (success=0) | 3056.611917 | 3057.342708 | 3089.323417 |
| Consumer joined (success=0) | 3057.529042 | 3058.273041 | 3089.362458 |

For each fixture the post-join evidence contains one exited frame, status 143, TERM=1, KILL=0, childReaped=1, stdoutEOF=1, stderrEOF=1, cancellation state=2 (success): events 1387–1404, 1392–1408, and 1421–1431 respectively. The missing first-byte/line/consumer/recorder events for 346/347 are absent over their entire joined stream, not just a truncated pre-timeout window.

## Independent signal join

Each signal call has a separate UUID. Joining its exact negative PID target, signal number, and result establishes actual group-directed calls, not merely an intended Core stage.

| Fixture | Initial SIGCONT signal owner | Target | Result/errno | SIGCONT result mono ns | TERM signal owner | TERM result mono ns |
| --- | --- | ---: | --- | ---: | --- | ---: |
| 347 | 14593D86-EF0F-4ACD-9035-23A2CCE18B4B | -83966 | 0/0 | 123986863438833 | 8CF87AD8-5FDB-4EC1-8E7D-5E65B9085283 | 123989831807208 |
| 346 | A49B5999-2C91-4597-AC24-1F0DD8C8054B | -83965 | 0/0 | 123986861373708 | 96E25D89-7D0A-4E51-ADFB-81BE23EDC187 | 123989831776041 |
| 372 | 1CF78DE6-A5E8-4116-A09D-5B547C757B73 | -83963 | 0/0 | 123986836137291 | FC7C8F59-13A2-40F1-A36F-15A6A5121968 | 123989831714125 |

Initial signal number is 19 (SIGCONT on this Darwin target); TERM is 15, with the same negative group targets and result/errno 0/0. Source `CliBackendTests.swift:751` calls `Darwin.kill(-processGroupId, signal)`. `CliProcessBackend.swift:931` uses `POSIX_SPAWN_START_SUSPENDED` and `POSIX_SPAWN_SETPGROUP`. A successful group signal syscall is not a direct observation that the child's initial suspended state was released or that its user code ran.

## Localized delay and limits

| Measured interval, ms | 347 | 346 | 372 |
| --- | ---: | ---: | ---: |
| Run queued → run started | 76.487625 | 74.885792 | 50.321084 |
| Run started → SIGCONT returned | 2.020667 | 2.289958 | 2.522541 |
| posix_spawn call → spawned | 0.309125 | 0.380750 | 0.390542 |
| Stdout queued → started | 380.494125 | 207.358708 | 50.706791 |
| SIGCONT returned → drain entered | 380.476458 | 207.337875 | 50.682417 |
| Drain entered → first bytes | unobserved | unobserved | 2853.945792 |
| SIGCONT returned → first bytes | unobserved | unobserved | 2904.628209 |
| Drain entered → readiness decision | 2587.670250 | 2762.856667 | 2944.700417 |
| SIGCONT returned → readiness decision | 2968.146708 | 2970.194542 | 2995.382834 |

The largest unresolved interval is **after the successful initial group SIGCONT and stdout-drain entry, before the first positive read**. The failed fixtures have no observed first-positive-read endpoint; their drain→deadline intervals are censored no-byte-observation windows, not measured child-startup times. Reader task admission adds a real 207–380 ms for the failed cases but does not explain the subsequent 2.59–2.76 s without first bytes.

372's successful downstream chain is small by comparison: bytes→yield 0.028833 ms, yield→consumer 6.882000 ms, consumer→recorded 0.007750 ms. Recorder→wait decision is 83.836042 ms. The ready was recorded before the nominal 3 s deadline, although the task evaluated its final condition at 3048.204 ms. `waitForStdout` accepts an already-recorded matching frame after leaving the loop; this run did not demonstrate a frame first arriving after the deadline being accepted. For 346/347 outcome 3 explicitly establishes deadline expiry without a matching frame and without a completed stream/error, rather than an earlier producer failure.

The complete successful EOF evidence plus no first-byte event means no positive stdout read occurred at any time for 346/347. It rules out an isolated line-yield/consumer/recorder backlog as the explanation for their ready failure. It does **not** instrument child execution/write timing or every read attempt: `drainPipe` logs neither EAGAIN nor its sleep/wakeup schedule. Entry alone cannot prove sustained reader service. No evidence here identifies loader, kernel, disk, CPU, scheduling, pipe polling, or group-resume semantics as the root cause.

The 143/TERM-without-KILL result is compatible with 346/347 not reaching their ignore-TERM shell trap, which precedes `printf ready`; it is supporting context, not a sampled child-state proof. 372 intentionally has a different script (`printf ready; exec /bin/sleep 30`) and expects ordinary TERM termination. Its success on the **same negative-group initial signal path** prevents claiming that group signaling universally fails to resume these fixtures. Conversely, its success does not verify initial-suspend behavior for the two failed children.

## Next bounded probe proposal, not executed

The evidence now warrants probing **actual child initial-resume/execution state versus stdout read service**, not another unchanged full run and not a timeout/concurrency fix.

1. Preserve the exact staged executable, argv, spawn flags, pipe arrangement, ownership checks, load/deadline policy, and group-directed TERM/KILL cleanup. Predeclare a bounded comparison whose only behavioral variable is the **first SIGCONT target**: validated leader PID versus validated process group. Do not send a later leader SIGCONT as an automatic rescue; that would destroy the failure observation and broaden the command behavior being measured.
2. Observe only newly spawned, identity-checked direct children belonging to that run (actual PID/PPID/PGID/start identity and staged executable). Capture a bounded state/sample between SIGCONT success and first bytes/deadline. A signal return of zero and parent-side `continuedGroups` membership are not child-state observations. A process state alone may not fully expose Mach initial suspension, so preserve the actual sample/state data and its uncertainty.
3. If child state does not settle the boundary, use a separately approved diagnostics-only read-service probe recording monotonic read-attempt/outcome and requested versus actual sleep/wakeup gaps (bounded numeric counts, errno, byte counts; no payload or secrets). This distinguishes repeated EAGAIN from a reader that entered but did not run again. Do not replace the shell with an instrumented executable and call that the same reproduction.
4. Predetermine the observation limit and retain both successes and failures. Leader-target success alone would be an association, not proof of a universal fix. If the group child remains suspended while the comparable leader-target child runs and reader service is established, that would materially strengthen the specific initial-resume hypothesis. If both are executing while first bytes lag, the group-target hypothesis would weaken and the child-write/read-service boundary remains the target.

Any probe implementation or source correction requires a separate grant/review. No conclusion in this report authorizes changing production initial-resume semantics, removing KILL assertions, raising readiness deadlines, retrying to green, or accepting A1/A2 progression. The 065 cold fixture and its compound assertion are outside this report's assignment and are not classified as a proven early-publication leak.
