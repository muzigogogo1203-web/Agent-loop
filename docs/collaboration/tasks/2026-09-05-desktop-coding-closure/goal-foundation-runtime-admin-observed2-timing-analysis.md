# Observed2 independent same-run timing analysis

Reviewed 2026-09-08. Scope: existing approved text capture, native observer, admitted RunTests OSLog, pinned source and same-run test outcomes. This is an independent analysis, not capture/privacy acceptance or runtime-gate acceptance. No workload, sampling, authentication, process signal, product change or Git mutation was executed for this review.

## Finding and corrected test identity

The exact CLI-347 child was observed in `AppleSystemPolicy::evaluateScript` → `waitForEvaluation` in all 10 stack snapshots of the 2026-09-07 01:11:44.098–01:11:45.099 +0800 report. It subsequently produced output, satisfied readiness, and completed checked TERM/KILL/reap/EOF cleanup. This is evidence of a named OS script-evaluation wait during that one launch, with subsequent recovery; it does not identify the cause inside the evaluator or establish its full duration.

**CLI-347 is `cliProcessBackendFixtureFailureStillJoinsRealCleanup()`, which passed after 67.105 seconds.** CLI-346 is `cliProcessBackendCancellationEscalatesAfterGrace()`, which passed after 67.417 seconds. These names and identities are fixed by the same-run source, not neighboring lines in concurrent test output: `CliBackendTests.swift:596–600` and `471–475`; `test.log:2331–2340`. The initial proposed CLI-347/67.417-second association was incorrect.

CLI-347 deliberately throws `afterReady`, then requires the owned cleanup path to succeed (`CliBackendTests.swift:630–682`). The expected injected body failure is not a readiness failure. Readiness succeeded in **2.688898542 seconds**; its 3000 ms budget did not expire. The authoritative full invocation nevertheless remained RED: **1130 tests, 33 suites, 92.866 seconds, 5 parent issues, exit 1**, in four other tests (`test.log:2548`, `process.log:8–12`).

## Evidence identity and clocks

All raw filenames below resolve under the exact directory `RAW`:

`/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-admin-goal-foundation-runtime-admin-observed2-20260907-34931-1glsvj9`

`TD` is `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-09-05-desktop-coding-closure`; source paths resolve under `/Users/muzi/Agent-loop`. Every `file:line` reference is to the complete hashed file in the manifest below. Mutable result/checkpoint documents written concurrently by the root agent are not review inputs.

- `TD/goal-foundation-runtime-admin-observed2-location.json:1` fixes RAW and launcher 34931. `identity.log:5` identifies workload PID 34975, birth `1788714636.236924`, UID 501, initially `/usr/bin/swift`; `process.log:8–10` records the exact default `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests` invocation. All 2062 admitted OSLog records have PID 34975 and `/Users/muzi/Agent-loop/.build/arm64-apple-macosx/debug/RunTests`, image UUID `8E982BC0-419A-3428-816B-6DA7A53D8DBD`.
- `test.log:2269` maps execution `00000000-0000-4000-8000-000000000347` to recorder **`0EBA592E-8F84-4B4D-83FA-0FCC35051CEC`**. `events-admitted.ndjson:1391–1392` maps that recorder to PID/PGID **35430**. Backend owner **`CAEB4112-8274-400C-8EB3-74D1B026C990`** records spawned PID 35430 at line 1077 and returned `waitpid` PID 35430 at line 1358. The join therefore has explicit PID links at both ends; temporal adjacency alone is unnecessary.
- `observer.log:648–649` admits PID 35430, PPID 34975, UID 501, PGID 35430, birth **`1788714703.497530`**, image `/bin/sh`, fixture `c-347-201D`, and its staged executable. `selector.ndjson:1–3` and `apple.log:1` independently use the same birth and parent. `sample-stdout.log:52–65` names sh 35430, parent 34975, UID 501 and one thread. This joins the text stack to the observed generation; the later successful fixture resource checks and reaping explain why the post-capture lookup cannot find it.
- The native observer's `mono` is `mach_absolute_time()` converted with its timebase to nanoseconds (`goal-foundation-runtime-child-observer.c:39–41`; `observer.log:1` reports 125/3). The runtime logger emits `DispatchTime.now().uptimeNanoseconds` (`RuntimeLifecycleDiagnostics.swift:99–103`). Monotonic differences below use the recorded `mono` values directly; OSLog wall timestamps only align the text sample header with the local sequence. Printed wall timestamps and libproc birth are not treated as nanosecond-synchronized clocks. The reported birth-to-sample wall deltas are about 0.60–1.60 seconds, not an exact measurement of where evaluation began.
- The recorded source manifest before and after the invocation is identical. The three currently read Swift files also match their same-run hashes (`source.sha256:150,161,233`). Source interpretation therefore applies to this invocation.

## Exact same-run sequence

Wall times below are on 2026-09-07 +0800; the date is omitted for compactness. `E` means `events-admitted.ndjson`, `N` means `observer.log`, `S` means `selector.ndjson`, and `A` means `apple.log`. Monotonic entries are nanoseconds. Multi-event ranges preserve distinct endpoints rather than asserting simultaneous events.

| Event | Wall time / exact mono | Evidence |
|---|---|---|
| Fixture launch called; backend queued | 01:11:43.252531 / `131626955700250`; 01:11:43.252637 / `131626955802583` | E:982–983 |
| Fixture returned; consumer queued; readiness wait starts with value 3000 | `131626955905416`; `131626955912125`; 01:11:43.252760 / `131626955931041` | E:984–988 |
| Backend run starts | 01:11:43.507345 / `131627210514875` | E:1064 |
| Spawn called → returned PID 35430 | 01:11:43.510706 / `131627213875750` → 01:11:43.520257 / `131627223424708` | E:1074,1077 |
| Fixture consumer starts | 01:11:43.517484 / `131627220651000` | E:1075 |
| Suspended validation returns; stdout reader queued | `131627224145208`; `131627224163125` | E:1079–1081 |
| Group SIGCONT (19), target -35430; result/errno 0; wrapper returns | 01:11:43.521015 / `131627224186041`; `131627224202291`; `131627224204208`; `131627224207000` | E:1083–1089 |
| Selector first quiet observation | `131627225255166`–`131627225401500` | S:1 |
| Native admission; first complete quiet sample | `131627301180916`; task `131627301354083`, pipe `131627301381916` | N:648,658–665 |
| Reaper starts; stdout reader starts / enters drain | 01:11:43.833986 / `131627537156541`; 01:11:43.845902 / `131627549067750`; `131627549076375` | E:1128–1130 |
| Selector second quiet sample; selection | `131627615595833`–`131627616114166`; `131627616192083` | S:2–3 |
| Capture helper starts; spindump 35445 starts for target 35430 | `131627779869958`; `131627781189583` | A:1–2 |
| Text stack's actual sample window: 10 snapshots, 100 ms interval | **01:11:44.098–01:11:45.099**, reported duration 1.00 s | sample-stdout.log:1–2,20–21,64–79 |
| Last native quiet task / zero-byte pipe observation | `131629302296500` / `131629302317541` | N:1078,1082–1083 |
| First changed task counters; six pipe bytes | `131629407103291`; `131629407162041` | N:1100,1104–1105 |
| Next pipe observation remains six bytes | `131629527243125` | N:1122–1123 |
| Backend first bytes = 6; first stdout line enqueued, value 0 | 01:11:45.910781 / `131629613948916`; 01:11:45.910830 / `131629614000666` | E:1289–1290 |
| Native pipe now zero, same handles and valid identity | `131629618529333` | N:1137–1138 |
| Fixture receives / records first stdout | 01:11:45.924038 / `131629627207791`; `131629627214625` | E:1298–1299 |
| Readiness ends successfully, value 0 | **01:11:45.941661 / `131629644829583`** | E:1311 |
| Group TERM (15), target -35430; result/errno 0 | 01:11:45.947554 / `131629650724750`; `131629650730708`; `131629650732958` | E:1318–1322 |
| Group KILL (9), target -35430; result/errno 0 | 01:11:46.009782 / `131629712951958`; `131629712972166`; `131629712974166` | E:1353–1357 |
| waitpid returns 35430; finalize joins reaper | 01:11:46.010520 / `131629713688125`; `131629713721666` | E:1358–1359 |
| Native child no longer available, errno 3 | `131629719825666`–`131629719829875` | N:1147–1148 |
| Finalize joins stdout EOF / stderr EOF, both value 0 | 01:11:46.020079 / `131629723227416`; 01:11:46.020088 / `131629723258000` | E:1369–1370 |
| Server stop finishes; finalize succeeds | `131629734975500`; 01:11:46.032076 / `131629735245250` | E:1384,1388 |
| Fixture stream succeeds; consumer joins; cancellation/exit evidence logged | `131629735303625`; `131629735332083`; `131629735337041`–`131629735370333` | E:1389–1402 |
| Spindump reaped with exit 0; text bytes complete; target already absent | `131642326518833`, `post_available=0`, `post_same=0` | A:187–188; process.log:15 |

The stdout/err `Finished` events are timestamps at which finalization **joined the readers and inspected their Boolean EOF result**, not instrumented timestamps of the kernel's first EOF delivery (`CliProcessBackend.swift:1249–1265`). Similarly, fixture TERM/KILL/reap/EOF fields at E:1394–1398 are the final evidence summary; the actual earlier signal and waitpid events are used for timing. Signals here are the workload's already-recorded calls: `CliBackendTests.swift:751–765` logs around the real `Darwin.kill` call.

## Durations and what each establishes

| Recorded interval | Duration | Interpretation |
|---|---:|---|
| Backend queued → run started | 254.712292 ms | Parent-side task delay before backend execution; cause not identified. |
| posix_spawn called → spawned event | 9.548958 ms | The logged spawn call interval is short; neither the 67-second test duration nor the later script-evaluation wait is a 67-second `posix_spawn` call. |
| Stdout task queued → started | 324.904625 ms | Reader scheduling delay exists, but the reader entered drain before the stack sample started. |
| SIGCONT returned → first bytes | 2.389741916 s | Startup-to-output interval includes the sampled OS wait and other unmeasured work. |
| Drain entered → first bytes | 2.064872541 s | Drain entry alone cannot distinguish time without output, polling backoff and scheduling delay. |
| Native first/last quiet task observations | 2.000942417 s | 20 complete quiet samples; it is not a continuous named-stack observation. |
| Last quiet task → first changed task | 104.806791 ms | Brackets the first observed counter transition, not the exact exit from AppleSystemPolicy evaluation. |
| First six-byte native pipe observation → backend first bytes | 206.786875 ms | A later output-delivery interval exists after output is present; attribution requires per-read/wakeup evidence. |
| First line enqueued → fixture receives it | 13.207125 ms | The line reached the fixture promptly after enqueue. |
| Fixture first stdout recorded → ready wait ends | 17.614958 ms | Consistent with the fixture's 20 ms condition polling; no missed readiness in this run. |
| Readiness starts → ends | **2.688898542 s** | Success value 0 with a configured 3000 ms budget; nominal margin 311.101458 ms. |
| Readiness ends → TERM logged | 5.895167 ms | Includes the expected after-ready body checks/failure and entering owned cleanup; exact cancellation entry has no separate event. |
| TERM → KILL logged | 62.227208 ms | Consistent with the configured 50 ms TERM grace plus asynchronous observation overhead. |
| KILL logged → waitpid returned | 0.736167 ms | Actual child reaping followed the signal rapidly. |
| Readiness ends → fixture stream finished | 90.474042 ms | The checked cleanup and stream completion did not remain stuck. |
| Fixture launch called → fixture stream finished | **2.779603375 s** | Covers the instrumented owned-launch interval; does not cover the whole 67.105-second test. |
| spindump started → helper reports reaped result | 14.545329250 s | Tool processing/transport lifetime, not target sample duration or target OS-wait duration. |

Native samples 4–61 (20 samples, `observer.log:658–1083`) all retain task `user=0`, `system=2037`, faults/pageins/Mach/Unix syscalls 0, context switches 4, one thread, running 0, pipe candidate bytes 0, and valid final identity/API checks. Their optional task-basic query has `suspend_count=0`; this is not evidence of a lingering task-level suspension in those observations. The stack explicitly names the wait for the 10 captured snapshots (`sample-stdout.log:67–79`), while counters alone cannot name it before/after that window.

At sample 64 the task changes to `user=105303`, `system=176156`, faults 810, pageins 18, Mach syscalls 423, Unix syscalls 560, context switches 57; the pipe has 6 bytes. Samples 67 and 69 retain those task counters, and the pipe goes 6 → 0. All three have valid final identity and required libproc APIs (`observer.log:1099–1138`). These are raw task counter values, not converted CPU durations or a claim that the child remained completely inactive. Optional `task_basic` now fails with `kr=268435459` and `valid=0`; its suspension state is **unknown** at these later points, not zero and not proof of suspension.

The final recorder summary is: cancellation state 2 (success), PID/PGID 35430, status 137, TERM/KILL/reaped/stdoutEOF/stderrEOF all 1, exit-frame count 1 and exit-frame status 137 (`E:1391–1402`; decoding in `CliBackendTests.swift:1234–1276`). `test.log:2331–2333` then reports resource observations `failures=0` and the CLI-347 test pass. The resource checker tests PID/group absence and an already-reaped child (`CliBackendTests.swift:1411–1454`); native child disappearance and later metadata `TD/goal-foundation-runtime-admin-observed2-post-identity.json:50–56` agree. The absent post-spindump target is expected after reaping, not a basis to relabel another process as the captured child.

The test's 67.105 seconds includes work outside the 2.779603375-second launch-to-stream interval. Test output provides no individual monotonic timestamp for its `started` line (`test.log:314`). Source places harness/request setup and `LoginShellEnvironment.shared.environment()` before recorder creation/launch (`CliBackendTests.swift:596–630`), and resource assessment after stream completion. This trace cannot allocate the remaining roughly 64.325 seconds between those stages. It must not be attributed wholesale to the sampled child, reader, evaluation service, or `posix_spawn`.

## Same-run RED outcomes

| Parent test | Actual failure evidence | Issues |
|---|---|---:|
| `rateLimitTriggersGlobalCooldownThenRecovers()` | `blocked` and `done` false; failed after 46.554 s (`test.log:1501,1724,1728`) | 2 |
| `emergencyStopCancelsRunningBeforeWaitingForPlanner()` | `runningWasCanceledBeforePlannerReleased` false; failed after 50.281 s (`test.log:1626,1830`) | 1 |
| `emergencyStopHaltsDispatchAndResumeContinues()` | `done` false; failed after 37.678 s (`test.log:1645,1652`) | 1 |
| `cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe()` | Watchdog primary error plus `held pipe cleanup was reported as certain`; failed after 65.503 s; identity 152 / PID 35416 (`test.log:2282–2286`) | 1 |

These account for all five parent issues. The embedded `deliberateChildFailure` block is explicitly mode `expected-failure` (`test.log:747–758`), and its parent `p1f1d075FDChildFailureReachesParent()` passes (`test.log:1196`). The embedded blocked-handler FD leak block reports delta 32 in child 35392 (`test.log:2292–2307`), and parent `boardFDIsolatedLeakStillFailsParent()` passes (`test.log:2309`). Neither embedded red child block is an additional failure of this parent run. CLI-347's stack supplies no causal connection to the four failing parent tests.

### Supplement: failed CLI-152 has a different observed path

The same existing evidence directly links CLI-152 to recorder `6E6F89B4-95A8-49E5-9525-6ACFB04718C9` (`test.log:541`) and its terminal PID/PGID 35416 (`E:1182–1183`), which backend owner `0704AFF4-F9C1-45A7-AAE6-1C54BADEB3EB` spawned (`E:967`). Source confirms identity 152 belongs to the held-pipe test (`CliBackendTests.swift:258–262`). Its body is a completion watchdog of up to 200 iterations sleeping 10 ms, and expects a natural parent exit leaving a 0.3-second grandchild holding stderr to yield `.pipeDrainIncomplete` with 50 ms drain grace (`CliBackendTests.swift:272–315`). This fixture does not wait for `ready`.

| CLI-152 boundary | Exact mono (ns) | Measured interval / evidence |
|---|---|---|
| Run queued → run started | `131562852738000` → `131574208791416` | **11.356053416 s**, E:3,10 |
| Environment requested → environment ready | `131574211320916` → `131626914861583` | **52.703540667 s**, E:12,950; this brackets the call to `LoginShellEnvironment.shared.environment()` at `CliProcessBackend.swift:614–620` |
| Fixture body starts → PID 35416 spawned | `131562852776458` → `131626946125750` | **64.093349292 s**, E:6,967 |
| Cleanup sends TERM to -35416, result/errno 0 → waitpid returns 35416 | `131627210132583` → `131627210484166` | E:1058–1063 |
| Fixture stream succeeds → consumer joins and reports cancellation | `131627649635375` → `131627682968250`; summary through `131627683047458` | E:1161,1181–1192 |

The final CLI-152 evidence has status **143**, TERM true, KILL false, child reaped and both EOF flags true, successful stream, one exit frame with status 143 (`E:1182–1192`). The test still correctly reports its watchdog primary error and the unexpected successful held-pipe cleanup result (`test.log:2284–2286`). This is a canceled process path, not evidence that the intended natural-exit held-pipe scenario was reached. The body-entry-to-stream interval is 64.796858917 seconds, so the nominal 200×10 ms watchdog must not be reported as an exact two-second wall deadline. There is no separate watchdog-fired or cancellation-entry event to locate that transition exactly. The long queued-task and environment-call intervals are localized observations; they do not establish why the environment call took that long, whether a runnable task was starved, or what stack PID 35416 had. CLI-347 was sampled only later and cannot supply those missing causes.

## Bounded next scope, recommendations only

1. Preserve the resolved claim: **a named AppleSystemPolicy script-evaluation wait occurred in this exact CLI-347 launch, which then passed readiness and checked cleanup**. Do not label it a universal Gatekeeper root cause, a readiness timeout in observed2, a 67-second stack wait, or a repair of the runtime gate. The service-side reason, request/result and precise evaluation enter/leave times are absent. No service-side stack or policy verdict was captured in the approved target text.
2. The next runtime investigation should begin with the four actual failing parent tests in this same run. CLI-152's existing join above makes the environment-call boundary and canceled-before-intended-scenario path concrete; inspect that boundary's implementation and existing logs before selecting a change. The halt/cooldown lifecycle owners still require their own joins. Do not apply CLI-347's sampled stack to another PID or previous invocation. A pipeline-wide timeout increase, ignored failure, retry, or altered cleanup assertion is unsupported by these observations.
3. If the remaining launch latency matters, the narrow observability gap is (a) fixture entry → harness/staging → login-environment wait → owned launch and (b) reader read attempts/result, chosen backoff and wakeup → first bytes, with execution/recorder/backend owner linkage. The reader already polls with 10→100 ms backoff (`CliProcessBackend.swift:2000–2054`), while these logs record only entry and first data. The 206.786875 ms pipe-to-read interval cannot isolate polling from wakeup/actor/executor delay. Any proposed diagnostics should contain identifiers, counts and monotonic times only, retain bounded volume, and log no tokens or payload contents. This is a proposed diagnostic scope, not an implementation authorization or a behavioral fix.
4. Any renewed OS-level capture requires the separate capture/privacy issue to be resolved and renewed authority. `sample-stderr.log:3–4` reports an unexpected extra stackshot buffer. That path's contents were **not read, decoded, copied, hashed or deleted** in this review. Its unknown scope is outside this analysis; the capture/privacy reviewer owns acceptance. The tool's warning text about processing time is not a measured target wait; use the 1.001-second report window and 14.545329250-second observed helper interval separately.
5. Keep runtime/A1/A2 acceptance blocked by the actual RED full run and the separate capture/privacy decision. This read-only analysis executes none of the proposed follow-up work and does not renew the consumed observed2 diagnostic attempt.

## SHA-256 input manifest

| Source | SHA-256 |
|---|---|
| RAW/sample-stdout.log | `b6540ae83a78af53ba4a399d3b4461d685fbc5751ca0a16b6d5fc3b2ec8f51ce` |
| RAW/sample-stderr.log | `cc89a6fabcca9aad3721d19c4a916b0554319472b5caf6d38127254bcb56e94b` |
| RAW/events-admitted.ndjson | `cb5c21ddbd28706643e56af5b650749b0921abd13f8815d9e3f9f0051a8f5dec` |
| RAW/observer.log | `fc2fba19c4a64d6ef149cc13a36c18430a9df17b8c1aed2d9b3e0de3b32f47be` |
| RAW/test.log | `eab1a8e32ed85991b16661d58eac8c579a582a7a3a15f0410c5c58b48dabf4ea` |
| RAW/process.log | `7dad5653222ceb738686c5bfe4a2c6900aa57519b06df7bfd56ce0cde9668450` |
| RAW/apple.log | `533890ef58dfca8733e9552490e9210d4bcb325ea193196e2d3e37470d2534d2` |
| RAW/selector.ndjson | `1a53e722506ff22ba1296bad320cd0eab5ea30fb9a0a4d566ba5d754acfe3d2b` |
| RAW/identity.log | `fe7cf61615427932c72fa6987e759f216656a6e48423c8d895c20f754046152e` |
| RAW/source.sha256 and RAW/source-after.sha256 (each) | `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f` |
| TD/goal-foundation-runtime-admin-observed2-location.json | `e4c2c71e60313159f9013c360995c75db854073f13fefe4cd9b885dffa33671d` |
| TD/goal-foundation-runtime-admin-observed2-post-identity.json | `13fb9082c6f4c3caa4e54ac195d5af0e06068c01b0749c68fe559712a8a7f5b8` |
| Sources/AgentLoopTestSuite/CliBackendTests.swift | `7e1ef3fb5f3b1a37b72cd21c4f0204f3a4aa5be6a0e98b3caec2c4f5f5f54d58` |
| Sources/AgentLoopCore/Loop/CliProcessBackend.swift | `20d5b42d7b768c6e3eb3f6c3ea770e358d7a328358ba7d1fa9da810a0241ed89` |
| Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift | `eb5b586478bcac3a84fde07f400621de14e77a797e4e644f743aaa8d5dc6e4f8` |
| TD/goal-foundation-runtime-child-observer.c | `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf` |

No digest of the unexpected extra buffer was computed or used.
