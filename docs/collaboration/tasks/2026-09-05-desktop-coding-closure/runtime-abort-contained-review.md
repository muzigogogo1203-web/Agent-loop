# Isolated abort465 ownership and diagnostic review

2026-09-09. This is a bounded runtime-validation record, not desktop acceptance.

## Source and application

Tasks 1–2 were independently accepted first; see `runtime-abort-owner-review.md`.
Fresh `runtime-abort-contained-entry.json` captured 309 inputs, manifest
`01f8015fae38219c62a4cbdd94351f904fce98a7b6dde8f40962178dad02b8db`,
and EEC preimage `40209eb1af8e23e5100ce337370613fca9525bf0145850d1b8fc137e05bc7175`.

Root and responsibilities-separated `forward_progress_review` read the complete
Task 3 patch `c00fd6837e70caba17c28916895ad1233a313ec8d06fcdb55584c9d11d1447dc`.
Review approved only EEC source application and an ordinary RunTests build.
The staged result matched `1777264cc81bd46c5ce22f9521cbed4551ac7094ebc031cf229f895182cf6251`;
single-file entry-relative diff `6201022411a312afb0e410fdc8ad820a1eee4bf2bf5ee8a51b9c6e73804b87a0`.
No Core, C helper, Package, wait-status, cleanup decision, timing budget or
unrelated fixture changes were made. Original abort assertions are byte-identical,
the old broad test loses exactly the moved block, and six regression bodies plus
nine existing owner/test/reader helpers remain frozen.

The reviewed test starts the native guard and awaits its acknowledgement before
launch, retains exact fresh kernel/file identity before the controlled gate,
shares one containment claim, and permits only revalidated positive-PID emergency
signals. The backend remains the sole normal terminator/reaper. Every owned join
and checked descriptor close precedes the explicit cleanup certificate; failure
invokes containment before assertions and retains the private fixture root.
Diagnostic failures are separate failures, never permission to skip cleanup.

## Build correction

Raw base: `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-abort-contained-20260909-20260909-69988-qgcu3f`.

`task3-build1`: owned/waited PID 72095, 10:50:11–10:50:29 +08, exit 1,
17.722192 s wall. Sole compilation error: Swift cannot import SDK macro
`PROC_PIDPATHINFO_MAXSIZE`. Complete log
`64f93b14df47ac1004e83a6fb3d949b6078295f669e67f8e9e53ed93b7392a5f`;
source manifest `fb0fcb6e2e788d323940aa32720b487e4c6e61e703c846f331d2e71b5fb95ebf`
and old runner/helper unchanged. No test ran.

Independent review verified SDK `sys/proc_info.h:749` defines the macro as
`4 * MAXPATHLEN`, and `sys/param.h:196` defines `MAXPATHLEN` as `PATH_MAX`.
It approved only `4 * Int(PATH_MAX)` plus its explanatory comment and one rebuild.
Corrected EEC: `37eeeab9427d80f9774a0f8cc33a9c6bf50e5b89df50c3f60c3c17d21506e6b8`;
entry-relative diff `ca81e2a9369c80ab54027775ebebc529b1822daffba2231119d0eeca8ecde878`.
All identity checks and capacity remain unchanged.

`task3-build2`: owned/waited PID 72384, 10:51:27–10:51:54 +08, exit 0,
26.923881 s wall / Swift 26.45 s. Root read the complete log
`9eb54ca5924090a871c150a8e2dd08d622db3989894c9380dbf0dc3a8bd1fe3d`;
only historical CLT/linker and two EEC warnings remain. Source manifest
`f355a99d3932bc7cbad4c50d93effcee1cd8748bcd542eaaee8f7bd0d3a86389`
was unchanged; runner `58577e8568ea23218a90c50950475af86db8044ac9a361e45eb1bde70941454f`,
helper `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2`.
`git diff --check` passed. This is ordinary compilation, not strict App or a test pass.

## One isolated process result

Independent review approved exactly one `capture-abort.rb … task3-build2.json abort1`
command, with wrapper `d208bfb9fbde1cb2ca4e5b5ba4cf44845142211a6a5daffb627de96a8496796c`.
It directly launched the pinned RunTests image with only
`p1f1_065AbortBeforeRegistrationOwnsAllLifetime`, retained stdout/stderr in an
exclusive regular file, and waited its exact PID before one scoped OSLog export.

`abort1`: owned/waited PID 73135, 10:53:06.037557–10:53:09.236692 +08,
exit 0, 3.199212 s wall. Complete log
`6e9a2ec3249d62ff3e64cdd03cdbad66ed9bef8bff8eb58e5e575a1eb40654e0`:
1 test / 1 suite / 0.798 s, every certificate field true. Source, runner and helper
were unchanged. Pinned Mach-O UUID `893cbf25-856e-3ed6-9b38-6033ed67211c`.

Fixture `E9A01D4B-E94E-4AD0-91D9-398347820BDF`, execution ending 465,
private root `/tmp/al65-pre-registration-abort-cc869224`: checked identity output
precedes the controlled gate. Exact child 73273 / PPID 73135 / PGID 73273 / UID 501,
start tuple 1788922388:443932, staged device 16777233 / inode 346578246 / expected
helper hash. Readiness observed at 169/3000 polls, 1000 μs interval, 0.70264425 s.
Normal signals were exactly `[SIGCONT, SIGKILL, SIGCONT]`, all syscall results 0.
Stream/cancellation preserve the expected injected primary error; publication
ordering, every owner/reader/waiter/guard join and checked shutdown/close pass.
Cleanup/socket paths are ENOENT; PID/group ESRCH; non-consuming waitid ECHILD;
registry empty, directory closed. No guard action, containment or diagnostic error.
Certified fixture teardown succeeded; root subsequently confirmed its exact path
absent. This removed only this newly owned temporary fixture, not user data.

## OSLog admission and explicit limitation

Collector owned/waited PID 73366, exit 0. Raw export
`915b5938bfae96c56fab9000557a203a6ac186178b542e176c499155de03608b`
contains 45 valid events plus count=45/finished=1. All 45 match exact parent PID,
both process/sender Mach-O UUIDs and paths, subsystem and category.

Admit rows 1–33 only. Rows 34–45 are retained but quarantined: timestamps
10:53:09.256369–10:53:09.258131 are 19.677–21.439 ms beyond the exact recorded
wait-return wall horizon. The window was not widened and the cause is not inferred.
The admitted prefix includes raw wait status 9, errno 0, returned child 73273,
and reap-joined value 0; this run does not show nonterminal wait-status confusion.
It does not establish the complete cleanup lifecycle through OSLog. Cleanup
acceptance rests independently on the checked direct certificate and assertions.

Responsibilities-separated review accepted Task 3's source/spec/test evidence with
that explicit OSLog limitation. No repeat is required. The capture wrapper never
sampled, elevated, discovered unrelated PIDs or killed a workload. The next bounded
integration, authoritative full suite, strict App, isolated desktop flow and local
candidate packaging remain separate gates.

Complete raw source/build/run/OSLog and subsequent integration records are archived
in `runtime-abort-contained-evidence/`: 25 verified files, manifest
`9fa969e7dce192cff66dcb9f7550a8c27337afeab8f0e8a0c10fa0989a5ce15d`.
No raw record was overwritten or trimmed. The subsequent integration result is
separately reported in `runtime-integration2-result.md` and remains RED.
