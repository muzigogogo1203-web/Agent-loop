# CLI readiness — single paired observation analysis

**Bounded diagnostics task complete.** Independent source review passed; compilation succeeded; the single paired run completed with exact identity links and all expected successful-path timing markers. Both original cancellation tests passed, **2 tests / 1.260 s / exit 0**. This is a successful observation, **not a readiness behavior repair or an explanation of the preceding failed pair**. The earlier full-suite red gate is not cleared.

## Evidence and exact identities

Read the complete `runtime-cli-readiness-focused.log`, `runtime-cli-readiness-process.txt`, all **104 lifecycle events plus `{count:104, finished:1}` metadata**, and the three-source hash manifest. Independently ran the read-only manifest check: all three hashes match the source approved in `runtime-cli-readiness-review.md`. No test, build, app, process signal or extra runtime capture was performed by this analyst; only this report was written.

The captured command interval is **2026-09-06 01:16:28–01:17:44**, PID **21212**, with **69.84 s of compilation** inside that interval. It is not the test execution duration. The individual tests passed in **0.899 s** (346) and **1.259 s** (372); the complete pair took **1.260 s**.

| Test / execution suffix | Recorder UUID from explicit identity line | Actual continued child PID from checked cleanup | Core owner from `cliSpawned` with that PID |
| --- | --- | --- | --- |
| EscalatesAfterGrace / 346 | `5E901A44-BC3A-4E89-8F78-A6EC38E6A188` | **21998** | `EB62FFB6-A26D-4199-AA9C-F2338D396403` |
| ReturnsCheckedEvidence / 372 | `6DC5316B-819B-4C8E-813C-A29FCC79F3CE` | **21999** | `7486DC3C-2FED-4238-AC83-6021CD99CB54` |

Full execution IDs are `00000000-0000-4000-8000-000000000346` and `00000000-0000-4000-8000-000000000372`. Both identity joins are unique in PID 21212; no chronological adjacency was used to assign Core owners. Private Board owner UUIDs were not inferred from nearby Core events.

## Measured startup intervals

All durations below are **milliseconds**, computed by subtracting the retained integer `mono` values, then rounding for display. The launch-called anchors are **99601529489833** (346) and **99601529510458** (372). Both readiness-start markers have `mono=99601529670583`, `value=3000`. Display/log-line order is not used for subtraction.

| Interval | 346 | 372 |
| --- | ---: | ---: |
| Fixture launch-called → Core run-queued | 0.129 | 0.110 |
| Core run-queued → run-started | 0.115 | 0.114 |
| Run-started → inputs validated | 0.949 | 0.941 |
| Environment requested → returned | 0.003 | 0.004 |
| Environment returned → validated | 0.248 | 0.250 |
| Environment validated → Board start-called | 0.739 | 0.746 |
| Board start-called → returned | 0.473 | 0.491 |
| Spawn preparation-started → posix_spawn-called | 0.442 | 0.452 |
| posix_spawn-called → actual spawned PID | 0.410 | 0.391 |
| Suspended validation-called → returned | 0.180 | 0.170 |
| SIGCONT-called → inspector returned | 0.014 | 0.015 |
| Fixture launch-called → SIGCONT-returned | **3.777** | **3.751** |

The observed startup validations, environment return, Board start and process resume complete well before the three-second deadline in this run. SIGCONT-return markers agree with the separately observed successful continued PIDs; the call-return marker alone would not prove signal success.

## Worker admission, stdout and readiness

| Interval / outcome | 346 | 372 |
| --- | ---: | ---: |
| Reap task queued → started | 0.030 | 0.040 |
| Stdout task queued → started | 0.079 | 0.043 |
| Stderr task queued → started | 0.071 | 0.063 |
| Stdout task started → drain entered | 0.004 | 0.003 |
| Fixture consumer queued → started | 0.083 | 0.076 |
| Caller ready-await queued → actor wait-started | 0.007 | 0.004 |
| Fixture launch-called → first stdout bytes | **583.219** | **998.366** |
| SIGCONT-returned → first stdout bytes | **579.442** | **994.615** |
| First bytes → first yield returned | 1.028 | 0.035 |
| First yield → fixture received first stdout | 0.016 | 0.017 |
| Fixture received → recorder appended first stdout | 0.016 | 0.007 |
| Recorder appended → readiness wait-ended | 23.023 | 15.871 |
| Readiness wait-started → wait-ended | **607.122** | **1014.135** |
| First-byte count / yield disposition / readiness outcome | 6 / enqueued (0) / matched (0) | 6 / enqueued (0) / matched (0) |

Both readers entered promptly, and both consumers and recorder awaits were admitted promptly. The longest measured interval before first stdout in this run is after SIGCONT and before the first positive-read callback. That interval combines child startup/write timing, subsequent read-loop execution/backoff and callback scheduling. There is no child-write timestamp or per-read trace here, so it cannot be assigned to one of those causes. First-byte means callback delivery after the read/data copy; first-yield means the original yield returned its disposition; the distinct received/recorded markers establish later consumer and actor progress.

The readiness end markers are `99602136792416` (346) and `99602543805083` (372), both outcome 0. Their intervals are about **607.303 ms / 1014.295 ms from fixture launch-called**, versus **607.122 ms / 1014.135 ms from the actual readiness-start marker**. Keep those anchors distinct. The start marker follows deadline construction and is not an independent copy of its exact clock instant. The recorder's existing polling sleep can contribute to the observed append-to-match interval; this capture does not isolate that contribution from wakeup latency.

## Reap, join and cleanup ordering

For 346, reap-worker entry → terminal `waitpid` return is **663.549 ms**; for 372, **1010.953 ms**. These are blocking-wait intervals, not task admission delays. Both terminal waits return the exact owned PID with no wait-error event. They occur **60.018 ms** and **0.421 ms** after their corresponding matched readiness end. Under the unchanged test body, explicit cancellation follows that successful ready await. Thus this run does **not** exhibit first output arriving only after a failed readiness wait and its cleanup request.

Both Core finalizers, stdout/stderr EOF stages, Board-stop returns, recorder stream finishes and joined consumers report successful outcomes. Fixture launch-called → consumer-joined is **746.198 ms** (346) and **1108.391 ms** (372). These are narrower intervals than whole-test times, which also include setup and post-join checks.

The complete focused output reports zero resource-observation failures for fixtures `c-346-D8F4` / PID 21998 and `c-372-52D2` / PID 21999. With the reviewed source and passing tests, that includes exact PID/group ESRCH, non-consuming waitid/ECHILD, socket ENOENT, matching identities and original cancellation evidence/signature assertions. No defer cleanup error was recorded. The parent additionally reports both PID/groups absent afterward; the analyst did not perform a separate live process check.

## Interpretation and next gate

This one measured pair establishes timely startup, admitted readers/consumer, successful stdout delivery before the unchanged deadline, and checked cleanup **for this invocation**. It does not identify the missing interval in the earlier uninstrumented failing pair. The source change adds diagnostics only, and instrumentation can affect scheduling. The parent also reports VM pressure now **1**, compared with the earlier retained **2**, while swap remains around **16 GB**; this analyst did not take a new resource snapshot. Those changed conditions further prevent attributing the result solely to logging or to any particular environmental mechanism.

The diagnostic completion criteria are satisfied: source approval, compilation, exactly one paired observation, complete retained identity/timing evidence and no new cleanup errors. No production behavior change is selected from this passing run. A new full-suite gate, if the parent proceeds based on documented changed pressure and the accumulated scoped repairs, is a separate bounded decision requiring its own resources, frozen hashes, full output and actual result. The historical 1089-test / 22-issue full run remains red until superseded by that evidence.
