# Observed2 HALT failures — bounded analysis of retained evidence

2026-09-08. The running-before-planner test missed its unchanged one-second requirement because cancellation had **not yet reached `consumption.cancel()` when its observer returned false**. This is an observed delay in cancellation progress, not evidence of a promptly completed cancellation overlooked by polling. The retained run does not establish the underlying executor, lock, or operating-system cause. The other two HALT/cooldown tests have failed card-state observations but lack the identity/timing records needed to attribute their failures to this cancellation path. No repair or gate acceptance follows from this report.

## Evidence and scope

The raw directory is the exact `run_directory` in `goal-foundation-runtime-admin-observed2-location.json`:

`/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-admin-goal-foundation-runtime-admin-observed2-20260907-34931-1glsvj9`

`process.log` records the ordinary-user workload `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests`, PID **34975**, generation start **1788714636.236924**, starting **2026-09-07 01:10:36.234975 +08** and ending **01:12:11.395874 +08**, test/collector exit **1**. `test.log:2548` reports **1130 tests / 33 suites / 92.866 seconds / 5 parent issues**. Four of those issues belong to the following three tests; the fifth is the separate CLI watchdog failure.

| Parent test | Exact failure evidence in `test.log` | Whole-test duration |
| --- | --- | ---: |
| `rateLimitTriggersGlobalCooldownThenRecovers` | line 1501: `blocked`, source 3173; line 1724: `done`, source 3197 | 46.554 s, 2 issues, line 1728 |
| `emergencyStopHaltsDispatchAndResumeContinues` | line 1645: `done`, source 1033 | 37.678 s, 1 issue, line 1652 |
| `emergencyStopCancelsRunningBeforeWaitingForPlanner` | line 1626: `runningWasCanceledBeforePlannerReleased`, source 2616 | 50.281 s, 1 issue, line 1830 |

Whole-test duration includes setup and cleanup; it is not a polling deadline or cancellation latency. Expected failing child-test output is not counted as another parent HALT issue.

Read the relevant source, retained process record, full admitted NDJSON, target stdout mappings/failures, and prior `runtime-halt-precancel-analysis.md`, `runtime-provenance-full-halt-analysis.md`, and `runtime-combined-halt-analysis.md` to avoid repeating previously completed attribution. Only this report was written. No source/git change, Swift/compiler/test run, authentication, OSLog extraction, sampling, signal, App/Provider action, or subagent was performed. The prohibited extra stackshot buffer was not accessed, hashed, copied, decoded, or deleted. Its scope assessment belongs to the separate reviewer.

## Exact same-run join

`test.log:1572` explicitly binds the running-before-planner test to the first four identities below. `test.log:1583` binds its entry generation to the same orchestrator/execution:

| Role | Identity |
| --- | --- |
| Orchestrator | `EF39FFC7-A821-4FC1-A609-FCECD946DD5F` |
| Execution | `CBCB3A6C-F901-43EE-B60B-274B103B039A` |
| Provider | `8F88BAC3-79A7-403A-8545-6B3133B3161A` |
| Planner fixture gate | `F4320A1E-FF41-40DC-A244-747FBE6161F1` |
| Entry generation | `0E4E6DFB-B145-4C47-A092-068BF451C838` |

Independent parsing found **2062** admitted events, matching the process record's `admitted=2062`, `rejected=[]`, metadata `count=2062, finished=1`. Exactly **68** events match these five owners, all PID **34975**, with no repeated owner/stage pair. Their wall-time window is **01:11:10.597837–01:11:28.256356 +08**. Interleaved stdout order and unrelated CLI identities are not used to infer causation.

The cancellation state-load selected **running (0)**; the registry selected **new external cancellation on an existing primary attempt (6)**; installed-task/gate events carry **external origin (0)**; cancellation-state selected **new resolver (3)**. Running snapshot is **1**, and the later active cleanup attempt is **1**. All expected 68 target boundaries are present; the unselected terminal/cached/reused paths are not missing evidence.

## One-second requirement and actual ordering

The observable anchor is `haltProviderWaitStarted`, mono **131595193212416**, at **01:11:11.490042 +08**. `HaltAndCooldownTests.swift:908–923` constructs its one-second deadline immediately before this marker; the precise deadline is not recorded, and this report does not replace it with the marker. All durations below are differences of recorded monotonic integer timestamps divided by 1,000,000.

| Event | NDJSON line | Mono | ms after provider-wait start |
| --- | ---: | ---: | ---: |
| Installed cancellation queued | 311 | 131595277917875 | 84.705459 |
| Installed gate open called | 313 | 131595277935250 | 84.722834 |
| Installed cancellation task started | 341 | 131596143837125 | 950.624709 |
| Installed gate open returned | 365 | 131596763673750 | 1570.461334 |
| Installed gate wait returned | 371 | 131598966001000 | 3772.788584 |
| Cancellation persistence called | 378 | 131598966047000 | 3772.834584 |
| Cancellation persistence returned | 379 | 131598984113541 | 3790.901125 |
| Active cleanup task queued | 381 | 131598984145791 | 3790.933375 |
| Provider wait ended, **false (0)** | 382 | 131599070347708 | **3877.135292** |
| Fixture observed **false (0)** | 383 | 131599070357750 | 3877.145334 |
| Planner fixture gate opened | 385 | 131599070565000 | 3877.352584 |
| Active cleanup task started | 399 | 131599352820208 | 4159.607792 |
| `consumption.cancel()` called | 400 | 131599352829875 | **4159.617459** |
| Provider stream termination, canceled (0) | 418 | 131600076775916 | 4883.563500 |
| Provider cancellation caught | 435 | 131600467998791 | 5274.786375 |
| Provider counter recorded as **1** | 436 | 131600468006458 | **5274.794042** |

Actual consumption cancellation was **282.482167 ms after** the false observer result; the provider counter was **1397.658750 ms after** it. Catch-to-counter mutation was only **0.007667 ms**. Therefore neither a counter update awaiting actor admission nor the polling loop overlooking an already-positive counter explains this failure. The earliest recorded consumption cancel is itself far outside the one-second window.

The planner fixture gate opened **1397.441458 ms before** the provider counter changed. This is an actual failure of the test's observed cancellation-before-planner-release order. It does **not** establish that releasing the planner caused cancellation progress or that the cancellation algorithm waits for that planner gate. Source `emergencyStop()` invokes runtime cancellation and joins running entries before later planning cleanup (`Orchestrator.swift:12302–12375`). The installed execution-start gate in the table is a separate object from the planner fixture gate.

The observer also resumed late: it returned false after **3877.135292 ms**, despite a nominal one-second deadline. The helper polls every 10 ms, then returns `cancellations > 0` without checking whether the counter changed before the deadline. This permits a late *pass*, as the earlier full-run report already showed; it does not excuse the current false result. Keep the requirement at one second. A future oracle should retain the exact deadline/cancellation instant so that a late positive result cannot be promoted into one-second evidence.

## Where the measured pre-cancellation delay lies

The coordinator-to-persistence-entry interval is **3689.637292 ms**. The source now contains the previously missing boundaries, so this run can be localized more precisely than the older combined failure's unallocated **863.437 ms**. Aggregate and overlapping caller/task intervals below must not be added together.

| Boundary | ms |
| --- | ---: |
| Stop queued → stop task started, before provider wait | 246.855584 |
| Supervisor suppression | 0.036208 |
| Dispatch-mode persistence | 2.078083 |
| Halting publication → fixture observation | 179.953375 |
| Runtime profile read, partly before provider wait | 260.997417 |
| Coordinator called → cancellation persistence called | **3689.637292** |
| Coordinator state-load call → return | **1.442750** |
| State-read call → body entry | 0.121792 |
| State-read body | 1.242625 |
| State-read body return → coordinator state-load return | 0.075500 |
| Claim call → registry method entry | 0.004458 |
| Installed cancellation task queued → started | **865.919250** |
| Installed gate open call → return | **1485.738500** |
| Installed gate wait call → return | **2822.160334** |
| Installed gate open **return** → wait return | **2202.327250** |
| Cancellation observer call → return | 0.003333 |
| Resolve call → cancellation-state actor entry | 0.010667 |
| Cancellation persistence operation | **18.066541** |
| Later active cleanup task queued → started | **368.674417** |

The dominant measured interval surrounds installed cancellation task/gate progress (`Orchestrator.swift:1450–1608, 1692–1825`), before durable cancellation is requested. The synchronous state-read body, registry method admission, resolver admission, and measured persistence operation are short in this observation. These data do not support assigning the 3.690-second gap to the cancellation persistence write or a state-read DB lock.

The task started while the caller's gate-open await was still outstanding. The gate-open call returned at mono **131596763673750**, but the task's gate wait returned at **131598966001000**, another **2202.327250 ms** later. Source `EngineExecutionStartGateV1.open()` delegates to the lock-protected `state.open()`, which sets the open state and resumes an installed waiter (`Orchestrator.swift:568–636`). Thus gate-open *return* is an upper bound on completion of that open operation; the subsequent 2.202 seconds cannot all be charged to waiting for the caller to perform its opening operation. Existing markers do not distinguish the wait method's actor admission, its internal continuation path, resumption scheduling, or intervening thread execution. They also do not record lock acquisition intervals or the exact internal resume instant. No deadlock, executor exhaustion, gate-logic defect, or specific host-resource cause is proven.

Later progress is also slow but distinct: consumption cancel → provider termination **723.946041 ms**; provider task-cancel return → catch **391.211416 ms**; consumption cancel → consumption joined **8084.130833 ms**. These later intervals cannot explain why no consumption cancel had occurred when the observer returned false. Runtime cancellation, entry-task join (**47.118375 ms**), planning cleanup (**12.435791 ms**), and `haltStopReachedEnd` value **0** all eventually completed. Stop queued → stop joined was **17193.252584 ms**. Eventual cleanup is established for this test; bounded cancellation and overall runtime acceptance remain failed.

## The other two tests: established failures, unproven cause

`waitForCard` (`HaltAndCooldownTests.swift:737–746`) polls the database for a target status with a **five-second** default, sleeps 30 ms between attempts, and performs a final read after leaving the loop. A false result proves the expected status was absent from those observations, including the final one. It does not reveal the actual card state or guarantee that the helper itself resumed within five seconds.

- In `emergencyStopHaltsDispatchAndResumeContinues` (`:998–1035`), the only reported issue is post-resume `done`. The preceding ready/no-runs/halt-event/isHalted checks and subsequent resume-event check report no issues; `resume()` did not throw. The failure is therefore specifically post-resume completion observation, not demonstrated dispatch during HALT. No fixture identity binds its orchestrator/card/execution to the admitted OSLog records, and no dispatch/terminal timestamps for that card were retained. A late completion, absent dispatch, or another terminal state cannot be separated from this evidence.
- In `rateLimitTriggersGlobalCooldownThenRecovers` (`:3135–3198`), both the first card's `blocked` observation and the second card's `done` observation fail. Execution continued through `waitUntilIdle()`, and the cooldown-event count and second-card no-runs-during-cooldown assertions report no issues. That establishes later cooldown handling and the checked suppression behavior, but does not prove when/if the first card reached `blocked` or the second reached `done`. The manual cooldown clock remains frozen until the explicit **400 ms** advance; `reconcile()` suppresses dispatch only while `rateLimitNow() < cooldownUntil` (`Orchestrator.swift:12135`). Elapsed wall time therefore does not itself expire this fixture's cooldown. There is no retained per-card identity/state timeline to decide among delayed progression, dispatch failure, and terminal-state mismatch.

The available logger has HALT cancellation and CLI stages, but these two tests do not call `haltFixtureReportIdentity`, report their relevant card/execution IDs, or emit card-wait start/deadline/end/state records. Assigning an unlabelled orchestrator's events by stdout adjacency would be an unsupported join. Their **three assertions remain unresolved**; the measured running-before-planner delay must not be generalized to them.

The other CLI child's AppleSystemPolicy sample cannot explain these failures. It concerns a different identity/path and later window; this report made no stack-based claim. Host resource snapshots likewise do not identify what held a particular actor, continuation, lock, or card transition.

## Smallest feasible next step — plan only

The **one highest-value next step** is a reviewed diagnostic-only observation of the installed cancellation gate: add the missing internal readiness/resumption boundaries, then run `emergencyStopCancelsRunningBeforeWaitingForPlanner` **once** through the ordinary focused runner. Retain its normal task behavior and unchanged one-second requirement. This is one bounded diagnostic experiment, not acceptance or an instruction to run it this turn.

Carry the existing canonical execution identity into markers at gate method entry, state observation/waiter registration, actual open-state publication/continuation resume, and wait completion. Preserve the existing ownership/gate semantics and avoid additional tasks/awaits. These markers distinguish gate-opening work from progress after the gate is ready, the specific boundary still unresolved by the **2202.327250 ms** interval. Limit the patch to that diagnostic plumbing and its existing logger; do not change persistence ordering, timeout values, cancellation behavior, or the polling assertion. The two card-state failures remain separately unresolved and are not bundled into this next experiment.

**Completion criterion:** freeze and independently review the diagnostic diff, retain the complete single-run command/output/exit, and account for every reachable gate boundary under the same execution identity. If the delay recurs, attribute the observed interval to the recorded readiness/resumption boundary without claiming an unobserved executor or OS cause. A focused pass can validate the instrumentation but cannot establish a repair or a strict deadline guarantee.

**Stop criterion:** after that one run, write the exact result and stop. If the delay does not recur, or a required boundary is missing, retain that limitation and leave the root cause/runtime gate unresolved. Do not progress automatically to another probe, stress loops, full reruns, administrator authentication, or system sampling. No longer timeout, serialized/skipped tests, or registry redesign is justified by this report. A later behavioral fix still requires a discriminating cause and independent review; authoritative `swift run RunTests` is a separate completion gate after such a fix.

## Relevant input integrity

The following explicit files were content-hashed. The three current source hashes match both retained before/after manifest entries, so the cited source is the source used by observed2. This is a scoped source check; full-manifest acceptance belongs to the parent reviewer.

| Input | SHA256 |
| --- | --- |
| Raw `test.log` | `eab1a8e32ed85991b16661d58eac8c579a582a7a3a15f0410c5c58b48dabf4ea` |
| Raw `events-admitted.ndjson` | `cb5c21ddbd28706643e56af5b650749b0921abd13f8815d9e3f9f0051a8f5dec` |
| `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift` | `ddaa4f0aa733aa2757276cde5013fcdf967c5db4576b3719188e1b2b5ce2cbbf` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `950f118f546f54c95bf8d0ca85c6ad478217ac56428850f91bff65c02c029131` |
| `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` | `eb5b586478bcac3a84fde07f400621de14e77a797e4e644f743aaa8d5dc6e4f8` |
