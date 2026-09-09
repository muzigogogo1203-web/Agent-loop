# CLI cleanup provenance — independent focused-evidence review

2026-09-06. **The bounded repair's focused gate is GREEN.** The ordinary build completed, all 069 scenarios passed with both shared-consumer joins complete and the actual stubborn-direct category `process_group_still_alive`, and both 065 process-cleanup cases passed with complete retained certificates. No focused evidence blocker remains. This is not full-suite, halt-repair, desktop/App, package, or user-acceptance approval.

Read both complete focused logs and process records, the implementation source review, matching twelve-file source manifest, and combined-RED entry amendment. Only this report was written. No source, compiler, test, process manipulation, OSLog extraction, database, App, or subagent action was performed by the reviewer.

## Build and run identity

| Run | Exact parent PID and retained window (PDT) | Result |
| --- | --- | --- |
| Ordinary incremental build plus focused 069 | 60855; 2026-09-06 05:13:54–05:14:23 | Build 20.41 s; 1 test / 1 suite, 6.297 s, exit 0 |
| Focused 065 against the built executable | 60926; 2026-09-06 05:14:55–05:15:14 | 2 tests / 1 suite, 18.375 s, exit 0 |

The first process record identifies `swift run --jobs 2 RunTests --filter p1f1_069`; its log explicitly compiles the changed CLI source and links/applies RunTests. The next identifies `swift run --skip-build RunTests --filter p1f1_065`. Both records contain all 12 manifest checks before and after: independently counted 24 OK entries per record, 12 unique paths, each appearing twice. These retained checks bind the source to the previously reviewed production hash `08f56a49c3293d246d4d57e2bfc600ecc5e9461002940916b0c7acf6a1e8719e` and unchanged covering-test hash `f7089c930283b0277721f3642a31491fef458006a5b20266b7119f5422c681f3`. There is no intervening source mutation in this manifested evidence. Existing compiler/linker warnings did not prevent product completion; no build failure is hidden by the test summary.

## 069 fulfills the amended post-fix requirements

Independent log parsing found all **21 unique scenario-entry markers**, both model and CLI join-end markers, and exactly one `P1F1D069_RESULT=stubborn-direct value=process_group_still_alive`. The unchanged expected-category assertion passed; the test continued through the complete matrix and ended with no issues.

This closes both retained RED boundaries in the focused run. PID 58651 previously stopped at the shared CLI consumer join with CancellationError after both cancellation callers received typed cleanup errors; PID 60855 reaches cli-end and passes the shared cleanup assertions. PID 58119 previously failed only the stubborn-direct expected category; PID 60855 now records the required actual category and passes that exact assertion. The older pre-fix stubborn actual label remains unknown and is not retroactively filled in.

The passed matrix also retains generation reuse, signal/direct cancellation distinctions, immediate/terminal winners, prelaunch/quarantine, shared cleanup delivery, exact claims, failure retry and recovery actions. These are behavioral observations against the reviewed one-file repair and frozen tests. They support the bounded cleanup-error provenance correction; they do not prove every concurrency schedule or identify the earlier historical PID 50925 failure's exact cause.

## 065 retains actual process-cleanup evidence

| Case | Fixture / execution | Exact child PID and process group | Test duration |
| --- | --- | ---: | ---: |
| Cancellation cleans process and commits once | D91EE9F6-33EE-461D-9131-CB51336016E2 / 00000000-0000-4000-8000-000000000065 | 60957 | 12.863 s |
| Forced failure still joins cleanup | 780C75A3-A844-4913-AF81-512C941C71B2 / 00000000-0000-4000-8000-000000000865 | 60967 | 5.511 s |

Both fixture records show readiness reached, successful exact-group SIGCONT/TERM/KILL attempts, cancellation success with status 137, stdout/stderr EOF, child reaped, and a successful stream join with matching exited status. Every recorded cleanup observation passes: correct cancellation identity, kill(pid, 0) and kill(-group, 0) return ESRCH, non-reaping waitid returns ECHILD, socket lstat returns ENOENT, registry active count is zero, and joined-stream exit evidence exists. Both end `cleanup-certified=true retained-root=none`; no failed observation is present.

The forced case explicitly records `body-error category=forcedFailure.afterReady` before cancellation and still completes its entire cleanup certificate and passes the dedicated test. This is the intended forced-error primary path with retained cleanup, not an unexplained production error being ignored. The process certificate supports actual child/group cleanup in these two cases; the separate stubborn fixture intentionally models process cleanup failure, where the repair must preserve failure and must not claim the process died.

## Disposition

The bounded source review plus these focused results satisfy the planned focused repair gate. No additional unchanged probe is requested. Retained 069 resources show about 29 GiB available and VM pressure level 1; root owns the fresh resource decision for a broader run. Those resource values are not causal proof about previous failures.

A new default full `swift run RunTests` is a separate authoritative gate and may reveal other issues. This report does not pre-approve its result, prove halt latency repaired, clear the prior combined run's four issues, authorize a commit/release, or equate focused tests with package/App/user acceptance. Root must account for the actual full-run outcome independently.
