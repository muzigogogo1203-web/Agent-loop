# Combined CLI failure attribution

2026-09-06. Read the complete relevant captured event groups and actual launch/harness code; no source change. Full run: parent 33956, `runtime-combined-full.log`, 1091 tests / 63.440 s / four outer issues / exit 1. `runtime-combined-events.ndjson` retains 3293 lifecycle events plus metadata from parent and five owned FD children. All nine frozen source hashes match. Expected negative FD child issues are not outer failures.

## Exact identity and timeline

Milliseconds below are relative to each fixture's existing three-second readiness timer, not whole-test duration.

| Test | Recorder UUID | Core UUID | Continued PID | Run entry | SIGCONT returned | stdout drain entered | First bytes | Readiness result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 346 | BB6D5457-BC49-44CE-8F5C-E99D754288A5 | 0203AA76-0BD0-4897-B3AE-885B9676DDD3 | 34184 | 90.122 | 92.625 | 581.196 | none captured | timeout at 3005.535 |
| 372 | 491DAFF2-8FE6-4A96-AFD7-547A90CB4AA9 | 741C89F6-0EB0-4996-BF96-79AA3381ECD8 | 34182 | 87.097 | 91.382 | 483.735 | none captured | timeout at 3006.777 |
| 347 | BF5B0D77-B200-4C04-B50E-F3ECE944D739 | DA34C281-8813-4642-BBB4-C58D7C414388 | 34181 | 40.582 | 43.438 | 117.379 | 2741.866 | ready at 2842.688 |

The full log joins fixture execution IDs to continued PIDs; `cliSpawned` joins those PIDs to Core UUIDs; retained cancellation evidence joins recorder UUIDs to PIDs. No adjacency-only correlation is used.

## Actual signal evidence

Each signed target and syscall result is joined by its own signal operation UUID. Targets -34184 and -34182 each have one successful fixture SIGCONT, then one successful fixture SIGTERM only **after** their readiness timeout (3005.688 and 3007.038 ms). Their waitpid returns follow, at 3005.908 / 3007.354 ms. Both cancellation records and single exited frames carry decoded status 143; TERM/reap/EOF flags are true and KILL false. This status is not raw wait status and alone cannot distinguish signal death from exit(143).

Target -34181 gets its fixture TERM after successful readiness, then KILL; evidence and single exited frame have decoded status 137 and all TERM/KILL/reap/EOF flags true. The forced-body-error test passes because it retains that error and certifies cleanup.

All eleven captured signal groups have complete fixed fields: ten fixture path-0 calls and one unrelated non-shared path-1 TERM to positive PID 34183. No shared path-2 signal is captured. The measured failure therefore provides **no support for changing these fixtures to private registries as a readiness fix**. Absence in capture is not a general proof that shared-registry interference can never occur.

All four mechanics fixtures (including 152 / PID 34174) report zero resource-observation failures. Subsequent read-only ps/pgrep found none of PIDs/groups 34174, 34181, 34182 or 34184. No manual signal or deletion was performed.

## Remaining boundary and next narrow observation

Reader admission precedes both failures by over two seconds; no first bytes appear even during joined cleanup. This is not evidence that changing reader admission alone fixes readiness. The two failing children terminate promptly on cleanup TERM, while 347 reaches ready and needs KILL as specified. Actual child instruction entry and the interval between reader polling iterations remain unmeasured.

The real harness does not directly launch the system shell: it creates a staged `#!/bin/sh` wrapper which then executes `/bin/sh` with the original arguments. Source inspection establishes this extra interpreter/exec boundary, not that it caused these delays. Do not remove that boundary, change production scheduling, increase deadlines, serialize suites or introduce a fake ready marker based solely on these timestamps.

A useful next experiment is one narrow pair run with the same source/deadlines and at most two one-second **read-only samples of newly observed direct child PIDs**, matched to the new RunTests parent and exact c-346/c-372 staged fixture command. Retain identity/time and sample errors, and label sampling as diagnostic rather than acceptance evidence. No signals, relaunch-on-failure loop or unchanged full rerun. Host pressure is level 2 and free disk only 2.1 GiB after this run; further full runs are not justified under unchanged conditions.
