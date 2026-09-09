# A1 administrator attempt2 — independent implementation review

Date: 2026-09-07  
Scope: the two-file launcher delta plus the new ordinary-user selector regression only  
Spec verdict: **PASS**  
Quality verdict: **PASS**  
Entry verdict: **APPROVED FOR EXACTLY ONE OBSERVED2 AUTHENTICATION/WORKLOAD/CAPTURE ATTEMPT**

This does not approve actual capture scope/content, a runtime root cause, a product repair, or A1/A2/product acceptance. Any observed2 outcome consumes the renewed authorization and requires separate evidence review.

## Frozen review inputs

- Correct 12-line task brief `.superpowers/sdd/goal-foundation-runtime-admin-attempt2-plan/task-1-brief.md`, SHA-256 `1507a675be2aee39d70d1d028d16ab0423b3f5d0e827832b93f4fec93b0cd4af`, read completely.
- Implementer report SHA-256 `1411cb22d5a899848537ab8c956f25ff95133174ba07b6eb8671935fc47c8ad2`, read completely.
- Actual 225-line delta `goal-foundation-runtime-admin-attempt2-implementation.diff`, SHA-256 `f3e1067dbb0e2fb3b1206f50745ddb1521c7d460fb801ae8500ab5e1700d84ea`, read completely. It changes only Ruby/AppleScript and adds the 164-line regression.
- Current implementation hashes match the handoff: AppleScript `e71c166d01e19fc0da074dd94aa9279d2743e60af7e773fb32c4a9ffcd7f083d`; Ruby runner `78388665f655783ff0af408f3818b696555496240716874821aa0c7cd9c7d854`; selector check `acd8a81d8c56b2310983b571e59f809050dcb3747ffad0e06c4247981e4a1349`.
- Unchanged accepted C remains `8d1a9a1a7a3f6be783844cef2590da9d73777a08bf7cfea77d0e3dee5f04fabd`; its compiled helper, capture rules and C20 checks are outside this delta and were not reopened.

## Implementation assessment

The correction addresses the observed launcher defect at its source. AppleScript adds only `exec ` to the ordinary selector shell command. The shell is therefore replaced by the fixed helper rather than retained as a `/bin/bash` or `/bin/sh` bridge. The production Ruby guard now requires the selected fixed-helper generation's immediate parent to equal the complete pinned osascript identity (`pid`, `ppid`, UID, PGID and birth) and path `/usr/bin/osascript`. It adds no shell-image fallback, wildcard, alternate helper, or target relaxation.

The privilege boundary remains byte-scoped: the AppleScript's administrator preflight, hard-coded helper path/SHA, final privileged SHA gate and capture command are untouched by the selector change. C, numeric ticket, seven data arguments, target eligibility, exact spindump argv, byte framing, stream/exit admission and finite cleanup are unchanged.

Ruby now writes `main_error` with nanosecond wall time, class and message to its already synced metadata stream immediately upon catching the main exception and before ensure cleanup. It retains the prior accumulated error and final command statuses. This closes the observed misleading delay without altering success criteria or cleanup authority.

The fixed execution name and location advance only from consumed observed1 to newly authorized `goal-foundation-runtime-admin-observed2`. The AppleScript SHA embedded in the runner matches the reviewed final script. Old/unknown names and a wrong helper still fail before artifacts/authentication. Observed1 remains immutable; observed2 was absent at review time. The existing fixed O_EXCL claim therefore enforces exactly one renewed session, and cancellation, failure, miss, empty capture or RED will consume it.

## Ordinary-user regression assessment

The new check exercises live process identity rather than accepting a text-only proof:

- It reads the actual AppleScript, requires exactly one match for each of the two fixed administrator statements, removes/replaces each exactly once, rejects any remaining `with administrator privileges` or `do shell script captureCommand`, and passes only the resulting in-memory string to `/usr/bin/osascript -e`. It neither edits nor executes the privileged original.
- The real selector construction and seven fields remain. The dummy launcher is a fresh owned direct child blocked solely on a controller pipe, creates no children and never executes RunTests. Closing the pipe is the only release; no process signal exists in the check.
- The assertion pins helper marker birth/image and live osascript generation, then requires the helper's immediate parent to be that exact osascript. It explicitly permits neither `/bin/bash` nor `/bin/sh`.
- Cleanup uses bounded WNOHANG waits for the controller's dummy and osascript children and a bounded exact-generation absence observation for the selector. Missing reap/absence becomes `cleanup_incomplete` or `cleanup_errors`, not success. It also requires the real selector `refused/launcher` result and rejects capture events.

The retained RED is meaningful: selector check PID 33547 exited 1; the live helper PID 33557 had `/bin/bash` PID 33556 as parent instead of osascript PID 33554. Dummy and osascript were reaped, selector became ESRCH, `cleanup_errors=[]`, and the variant preflight recorded one auth replacement, one capture replacement and zero remaining privilege phrases.

The unchanged check then produced a real GREEN after the two-file correction: PID 34207 exited 0 in 0.367 seconds. Its raw `process.ndjson` shows helper PID 34216 directly parented by exact osascript PID 34214 with matching full identity and `/usr/bin/osascript` path. Dummy PID 34212 was reaped exit 0; osascript was reaped exit 1 after the expected selector refusal; selector then returned ESRCH; `assertion_failure=null` and `cleanup_errors=[]`. `selector.ndjson` contains the expected `refused/launcher` and no capture activity.

Root evidence additionally records Ruby syntax PID 34221 exit 0, AppleScript compile-only PID 34226 exit 0, and observed1/unknown-prefix/wrong-helper refusals PIDs 34227/34233/34239 each exit 1. Before/after three-file pins are identical, observed1 location SHA remains `f9b8be652a03100cb62e887765eaf4b985be9851c3f5be6fec77d6c89b0b374f`, and no observed2 artifact was created. These are nonprivileged entry checks; they do not prove future privileged capture success.

## Findings and entry boundary

- P0: none.
- P1: none.
- P2: none.

No harmful issue was found in the scoped delta. Root may execute only the exact fixed observed2 command once after reading this complete review and rechecking the frozen 305 inputs plus helper/observer/runner/script/RunTests/spindump hashes. No fallback bridge, alternate prefix, second target or retry is approved. The actual attempt must retain authentication/readiness timing, target generation, report process scope, raw streams, true statuses, cleanup joins and before/after hashes for a fresh independent evidence review.

No probe, compile, authentication, test, workload, sample, signal, source edit, Provider/data action, or process mutation was performed by this reviewer. This review artifact is the only write.
