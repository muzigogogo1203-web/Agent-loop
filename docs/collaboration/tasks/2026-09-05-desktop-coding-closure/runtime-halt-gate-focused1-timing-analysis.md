# Focused1 cancellation-gate retained-content timing analysis

Reviewed 2026-09-08, independently of the capture/identity reviewer. **All timeline conclusions below are conditional on that separate identity/scope review.** The collector records `scope_ok=false`, `runtests_identity=null`, and a skipped checker because its 100 live identity observations never saw the RunTests image. This report does not override those recorded failures, execute the checker, or declare collection/coverage acceptance.

Before finalizing this report, the reviewer read the completed independent `runtime-halt-gate-focused1-scope-review.md`: its verdict accepts the retained content for the frozen checker and bounded timeline only, while retaining the original harness FAIL and unobserved live RunTests identity. Root subsequently ran the frozen checker on those retained files, separately recording exit 0, `already_open`, coverage `PASS`, runtime gate `NOT_EVALUATED`, and **zero live test invocations** in `runtime-halt-gate-focused1-retained-check-result.json`. The analysis below operates within that limited retained-content acceptance; it does not turn the original collection into a successful live handshake. This reviewer ran no checker.

The retained events describe one successful **already-open gate branch**: the opener had no registered waiter, the later wait observed opened state and resumed its own continuation. The measured installed-open-return → installed-wait-return interval is **15,875 ns (15.875 μs)**. The previous **2.202327250 s** delay did not recur in these retained events. This is non-reproduction in a focused invocation with added instrumentation, not evidence of a repaired cause or a strict one-second guarantee.

## Scope, source interpretation and identities

`TD` = `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-09-05-desktop-coding-closure`.

`RAW` = `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-runtime-halt-gate-focused1-20260908-36899-88b8u6`.

`E:N` means line N of `RAW/events-admitted.ndjson`. Source paths are under `/Users/muzi/Agent-loop`. Input hashes are listed at the end. Root-written mutable result/checkpoint prose was not used as a review input.

`runtime-halt-gate-focused1-result.json:4–24` records exactly one `swift run --skip-build RunTests --filter emergencyStopCancelsRunningBeforeWaitingForPlanner` invocation, diagnostics enabled, PID **36904**, launcher **36899**, UID **501**, wall interval **22:47:19.378901–22:47:26.787337 +0800**, exit **0**, no signal. Its recorded before/after binary SHA is `94b6e7ab743afe85ba8406bbf7f7c98dda2bffe6c26da5a5e52908fb2940b061`; launcher wall duration is **7.408436 s**. The eight-line `test.log` records a **0.239 s** selected test and **0.240 s** one-test run, both passed (`test.log:4–8`). Launcher elapsed time, test duration and event-window duration are distinct measurements.

Independent parsing of the entire retained admitted file found **82** well-formed stage/owner/mono/value records, all reporting PID **36904**, UID **501**, subsystem `com.muzi.agentloop`, category `runtime-lifecycle`, and image `/Users/muzi/Agent-loop/.build/arm64-apple-macosx/debug/RunTests`. All wall timestamps lie within the recorded invocation, spanning **22:47:26.727194–22:47:26.768072 +0800**. There are no duplicate owner/stage pairs and no decreasing `mono` values in the retained sequence. This supports internal consistency of the retained content; it does not supply the missing direct live image observation or a process birth field absent from these OSLog events.

The result JSON independently records 82 raw events, 82 admitted, metadata `{count:82, finished:1}`, no rejected records or parse errors, while preserving `scope_ok=false` and the skipped checker (`:43–80`). The initial live identity is PID 36904, birth `1788878839.379232`, with the **swift-package** image (`:25–42`). The separate scope review supplies the limited retained-content verdict; this timeline does not replace the missing live identity observation.

Exactly one fixture identity appears at `test.log:5`; the single entry identity at `test.log:6` binds the same orchestrator/execution to its generation. These five owners account for all 82 records:

| Role | Exact UUID | Records |
|---|---|---:|
| Orchestrator | `F21148D6-846D-4626-854D-201F0E601B00` | 18 |
| Execution / installed cancellation gate diagnostic owner | `04FDA128-75DA-4AEE-B71A-2402BFAF9880` | 53 |
| Provider fixture | `4CC6E6F2-8758-4140-9E4F-664B3388585B` | 6 |
| Planner fixture gate | `100E88ED-F3E0-4C23-816D-172D4F6DA17C` | 2 |
| Entry generation | `B5298116-C126-41F1-ACAA-25499CBE7F48` | 3 |

The **installed cancellation gate** is the execution-owned object instrumented by this change; the planner fixture gate is a different object with its own UUID. Their opens must not be conflated. The read plan and frozen `runtime-halt-gate-source1.diff` define the diagnostic brackets. Current source was consulted only for additional concrete branch/observer semantics and was content-hashed: Orchestrator, RuntimeLifecycleDiagnostics and HaltAndCooldownTests each match `source-before.sha256:135,161,259`. Before/after manifests have the same hash. No product-code/build/test/checker execution or live OSLog query was performed in this review.

## Observed gate branch and local ordering

Existing selection events choose running state **0** (E:27), new external cancellation on an existing primary attempt **6** (E:31), external origin **0** for installed-task/gate calls, and a new cancellation resolver **3** (E:56). Source meanings are `Orchestrator.swift:2587–2595`, `1667–1704`, `1852–1899`, and `779–810`.

All gate rows below belong to the exact execution UUID. Times are **recorded monotonic nanoseconds**, not inferred wall times. A zero waiter-presence code means the optional opener resume did not actually resume a continuation.

| E line | Stage | Mono | Value / meaning |
|---:|---|---:|---|
| 30 | `haltInstalledCancellationQueued` | 168906342047625 | 0, external |
| 32 | `haltInstalledGateOpenCalled` | 168906342055708 | 0, external |
| 33 | `haltGateActorOpenEntered` | 168906342060125 | 0 |
| 34 | `haltGateStateOpenEntered` | 168906342062041 | 0 |
| 35 | `haltGateOpenLockReturned` | 168906342064333 | **0, no detached waiter** |
| 36 | `haltGateOpenResumeAttempt` | 168906342065750 | **0, optional resume has no waiter** |
| 37 | `haltGateOpenResumeReturned` | 168906342067208 | **0, no actual opener resume** |
| 38 | `haltGateActorOpenSucceeded` | 168906342068666 | 0 |
| 39 | `haltInstalledCancellationStarted` | 168906342072125 | 0, external |
| 40 | `haltInstalledGateWaitCalled` | 168906342074041 | 0, external |
| 41 | `haltGateActorWaitEntered` | 168906342075833 | 0 |
| 42 | `haltGateStateWaitEntered` | 168906342077333 | 0 |
| 43 | `haltGateWaitContinuationEntered` | 168906342080166 | 0 |
| 44 | `haltGateWaitLockReturned` | 168906342084250 | **1, already opened / success** |
| 45 | `haltInstalledGateOpenReturned` | 168906342084541 | 0, caller resumed |
| 46 | `haltGateWaitResumeAttempt` | 168906342086250 | **1, immediate success resume** |
| 47 | `haltGateWaitResumeReturned` | 168906342089833 | **1** |
| 48 | `haltGateStateWaitSucceeded` | 168906342094250 | 0 |
| 49 | `haltClaimCancellationReturned` | 168906342094625 | 0, another caller boundary |
| 50 | `haltGateActorWaitSucceeded` | 168906342097958 | 0 |
| 51 | `haltInstalledGateWaitReturned` | 168906342100416 | 0, waiting caller resumed |
| 52 | `haltCancellationObserverCalled` | 168906342102250 | 0 |
| 53 | `haltCancellationObserverReturned` | 168906342104291 | 0 |

There are **14 unique `haltGate*` events**: the 12 common successful-path milestones plus the two immediate-wait-resume milestones. No `haltGateCancel*` event, registered-wait value 0, failure value 2, duplicate or unknown gate milestone occurs. The source's wait lock checks opened first and returns success without registering a waiter (`Orchestrator.swift:594–601`). The open lock sets opened and detaches its existing waiter, if any (`:642–650`). Together, open waiter-presence 0 plus subsequent successful wait value 1 establish the already-open path in this retained trace. Open code 0 alone would not distinguish an ordinary empty waiter from a canceled no-op; the later opened-state success and complete branch sequence supply the additional evidence here.

Both local source-order chains hold: actor-open entry → state-open entry → lock-return → optional-resume-attempt → optional-resume-return → actor-open success; and actor-wait entry → state-wait entry → continuation entry → wait-lock-return → immediate-resume-attempt → immediate-resume-return → state-wait success → actor-wait success. Caller markers are correctly interleaved: the wait lock-return event is **291 ns before** the opener caller's open-return event. This is not an ordering defect; the underlying open already succeeded before either caller completed its surrounding await. No rule requiring open-caller return before wait entry was imposed.

The retained content contains the branch observations specified by the plan. The original collector's scope gate failed and skipped its checker. The subsequently read, separate root-owned retained-file checker result records coverage PASS for this same already-open path, consistent with this independent parsing. This is **retained-path coverage under the limited scope verdict, not successful original harness capture or direct live-image coverage**. The registered-waiter resume path and error/cancel branches are unobserved in this single run.

## Gate interval decomposition

All intervals subtract the exact `mono` values. They bracket operations including logger overhead and possible scheduling; no marker is inside the lock. None is an exact lock-wait, publication or continuation-ready instant. Resuming a continuation does not by itself mean the waiting actor/caller has resumed execution.

| Boundary | E lines | Duration |
|---|---|---:|
| Cancellation task queued → started | 30→39 | 24.500 μs |
| Open called → gate actor entered | 32→33 | 4.417 μs |
| Gate actor-open entry → state-open entry | 33→34 | 1.916 μs |
| State-open entry → post-lock marker | 34→35 | 2.292 μs |
| Opener optional-resume bracket, **no waiter** | 36→37 | 1.458 μs |
| Actor-open success → opener caller return | 38→45 | 15.875 μs |
| Full installed open call → return | 32→45 | 28.833 μs |
| Wait called → gate actor entered | 40→41 | 1.792 μs |
| Actor-wait entry → state-wait entry | 41→42 | 1.500 μs |
| State-wait entry → continuation closure entry | 42→43 | 2.833 μs |
| Continuation entry → wait lock-return | 43→44 | 4.084 μs |
| Wait lock-return → immediate resume attempt | 44→46 | 2.000 μs |
| Immediate success-resume bracket | 46→47 | 3.583 μs |
| Immediate resume-return → state-wait success | 47→48 | 4.417 μs |
| State-wait success → actor-wait success | 48→50 | 3.708 μs |
| Actor-wait success → installed wait caller return | 50→51 | 2.458 μs |
| Full installed wait call → return | 40→51 | 26.375 μs |
| **Installed open return → installed wait return** | **45→51** | **15.875 μs** |
| Wait caller return → cancellation observer call | 51→52 | 1.834 μs |
| Cancellation-command observer call → return | 52→53 | 2.041 μs |

The previous selected comparison is open-return `131596763673750` → wait-return `131598966001000`, **2.202327250 s**, documented in the frozen prior halt analysis at lines 88 and 96. Focused1's corresponding interval is `168906342084541` → `168906342100416`, **0.000015875 s**. The old run lacked these internal gate milestones; its waiter-registration branch cannot be retroactively inferred from focused1. These different executions, with different workload and instrumentation, do not establish a speedup caused by the patch, a fixed gate defect, or an explanation for the old delay.

## Observer ordering and remaining halt boundaries

The provider observer starts at E:17, mono **168906341016708**, wall **22:47:26.729090 +0800**. Its exact deadline is constructed immediately before that marker but not recorded (`HaltAndCooldownTests.swift:908–922`). The observer retains its one-second default and returns `cancellations > 0` after condition polling; it does not test the counter's timestamp against the deadline.

| Event | E line(s) | Mono / ms after provider-observer start |
|---|---|---|
| Stop entered | 4 | 168906339433958 / **−1.582750 ms** |
| Halt published; fixture later sees halted | 7,15 | 168906340195750; 168906340991750 |
| Runtime cancel called | 12 | 168906340968208 / **−0.048500 ms** |
| Provider observer starts | 17 | 168906341016708 / **0 ms** |
| Running state loaded, value 0 | 27 | 168906342022791 / **1.006083 ms** |
| Installed gate wait returns | 51 | 168906342100416 / **1.083708 ms** |
| New resolver selected, value 3 | 56 | 168906342112333 / **1.095625 ms** |
| Cancellation persistence call → return | 58–59 | 168906342116875 → 168906347920541 / **1.100167→6.903833 ms** |
| Active task queued → started, attempt 1 | 61–62 | 168906347937416 → 168906347952291 |
| Consumption cancel called | 63 | 168906347954708 / **6.938000 ms** |
| Provider termination, canceled value 0 | 64 | 168906348043708 / **7.027000 ms** |
| Provider task-cancel returns; cancellation caught | 65–66 | 168906348050750 → 168906348084208 |
| Provider counter records cancellation, value 1 | 67 | 168906348086875 / **7.070167 ms** |
| Consumption joined; active cancel returned | 68–69 | 168906348290125 → 168906348301333 |
| Provider observer ends **true (1)** | 70 | 168906352968875 / **11.952167 ms** |
| Fixture receives **true (1)** | 71 | 168906352975750 / **11.959042 ms** |
| Planner fixture gate opens | 73 | 168906353648333 / **12.631625 ms** |
| Coordinator / runtime cancellation return | 74–75 | 168906376203583 → 168906376246375 |
| Entry task join returns | 78 | 168906376333625 / **35.316917 ms** |
| Planning cleanup returns; stop reaches end | 80–81 | 168906379949250 → 168906379988416 |
| Fixture joins stop | 82 | 168906379999625 / **38.982917 ms** |

Provider cancellation is recorded **4.882000 ms before** the observer returns true and **5.561458 ms before** the planner fixture gate opens. Fixture observation returns true **0.672583 ms before** that planner open. Source opens the planner only after evaluating `runningWasCanceledBeforePlannerReleased` (`HaltAndCooldownTests.swift:2608–2621`). Thus the retained sequence supports this invocation's cancellation-before-planner-release order; it is not a late-positive observation of a previously opened planner gate.

The measured provider-observer interval is **11.952167 ms**, and cancellation is recorded **7.070167 ms after** its start marker. This trace does not contain a slow one-second observer interval. It also does not repair the oracle's absence of an exact persisted deadline/cancellation-time comparison or establish a strict deadline guarantee over other schedules. The recorded monotonic field comes from the unchanged `DispatchTime.now().uptimeNanoseconds` logger (`RuntimeLifecycleDiagnostics.swift:108–112`), while the helper's deadline uses `ContinuousClock`; neither logger position nor a passing assertion is substituted for that exact deadline.

Other measured same-run brackets are: coordinator state load **0.366625 ms** (E:23–27), state-read call→body **0.028500 ms** (24→25), read body **0.316542 ms** (25→26), body return→state-load return **0.019333 ms** (26→27), claim call→entry **0.010458 ms** (28→29), resolver call→cancellation-state entry **0.002166 ms** (54→55), cancellation persistence **5.803666 ms** (58→59), active task queued→started **0.014875 ms** (61→62), consumption cancel→provider termination **0.089000 ms** (63→64), provider task-cancel return→catch **0.033458 ms** (65→66), catch→counter **0.002667 ms** (66→67). Runtime cancel call→return is **35.278167 ms** (12→75), and stop queued→joined **40.621000 ms** (2→82). These are overlapping operation brackets, not additive CPU/lock costs or a claim that every intervening wait has been identified.

## Bounded conclusion

Retained-content findings: one fixture, five joined owners, 82 internally consistent events, the already-open gate's 14 expected successful-path milestones, short observed actor/state/continuation/caller brackets, and provider cancellation preceding observer success and planner release. The separate reviewer accepted only retained-content scope, followed by root's separate retained checker PASS. Missing direct live RunTests image admission and the original harness failure remain explicit. The frozen checker was skipped in the original harness and was not run by this timeline reviewer.

The selected historical delay did not recur, so no specific actor starvation, lock contention, continuation scheduling defect or other cause of that delay is demonstrated. The registered-waiter, cancellation and throwing branches are not covered by this retained successful path. A focused test pass and source-only diagnostics cannot clear the original full-runtime RED, A1/A2 or product acceptance. The plan's single-run stop criterion applies: retain this evidence and stop the diagnostic unit. This reviewer performed no new run, checker, source change, full-suite attempt or expanded observation; this analysis authorizes none.

## SHA-256 input manifest

| Input | SHA-256 |
|---|---|
| TD/runtime-halt-gate-plan.md | `4721a69dd8976fe7cec29b1457c3984b79e043463626707a7a81b82f04e08910` |
| TD/runtime-halt-gate-source1.diff | `16dac9fca39c835373d5faef191cd6ed1c12409d4f032bc8eac26068d560913c` |
| TD/runtime-halt-gate-focused1-result.json | `81a438c7e3e2da3397a292af26e32e39f5948f555466c4e600345abe501eeb15` |
| TD/runtime-halt-gate-focused1-scope-review.md | `fa815e3a5d3d092b974d1760256fd6f162bd5d474945a75197ad385afd4f3a1f` |
| TD/runtime-halt-gate-focused1-retained-check-result.json | `478dd0b322a77a855fa2c24e7bf9b229aab16c6fd503c6ec1c92a06f53c46319` |
| RAW/test.log | `40c420aa656306f75c262d8681b01f0957c8e67d527ed8a64da1205d760d1233` |
| RAW/events-admitted.ndjson | `e0f4c9d74cded88ad55760ac22441c380bce34bf15a5b6ab5911495e6e0f46fd` |
| RAW/source-before.sha256 and RAW/source-after.sha256 (each) | `ecef432164402b0ef2ea2cc83958c39b608a8edfb9ade7711167072ef255a4f8` |
| Sources/AgentLoopCore/Kernel/Orchestrator.swift | `c43aaf48d2eae23512e13c41da95209c84129d18da5ef44677096e30ace0e48c` |
| Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift | `0f33c77feed702b896f6f7c890ea6e206b554d7b4e79e04d6bbe62ee3f237daf` |
| Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift | `ddaa4f0aa733aa2757276cde5013fcdf967c5db4576b3719188e1b2b5ce2cbbf` |
| TD/goal-foundation-runtime-admin-observed2-halt-analysis.md | `cd95c610c169a674a7ebd0913b6581821ed81cdcc6a15b29ace0923c889ddd90` |

## Closure — 2026-09-08

The timeline was first analyzed conditionally while identity/scope review was pending. Before finalization, this reviewer read scope review `fa815e3a5d3d092b974d1760256fd6f162bd5d474945a75197ad385afd4f3a1f` and the subsequent root-owned retained checker result `478dd0b322a77a855fa2c24e7bf9b229aab16c6fd503c6ec1c92a06f53c46319`. **Separate retained-content scope and the already-open path's retained checker now PASS. Original harness FAIL / `scope_ok=false`, original skipped checker, and the missing direct live RunTests image observation are unchanged.** The later checker used retained files and added no live test invocation; runtime gate remains `NOT_EVALUATED`. The existing timing findings and non-reproduction limit are unchanged. This closes the bounded evidence account without further timeline work or experiment.
