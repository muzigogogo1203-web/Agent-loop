# Default full-run halt timing: independent interpretation

The target halt test **passed in the retained default full run**, and its provider cancellation was recorded **29.666208 ms before the planner gate opened**. The new pre-cancellation diagnostics are sufficiently paired to locate this run's largest pre-persistence interval around installed-task/gate progress. They do not explain the old 863.437 ms gap. A separate important limit is that this pass does **not** establish a strict one-second cancellation bound: the provider counter was recorded 1032.460500 ms after provider-wait start, and the observer returned true at 1062.102667 ms.

## Evidence and exact correlation

Read `runtime-halt-precancel-plan.md`, `runtime-halt-precancel-analysis.md`, `runtime-combined-halt-analysis.md`, the new target stdout mappings/result, process record boundaries, all new NDJSON records and the unchanged target provider wait/test code. The full-gate reviewer owns overall test inventory, fixture-child accounting and source-manifest acceptance; this report owns only halt timing and pairing.

`runtime-provenance-full-process.txt` records parent PID **61158**, command **`swift run RunTests`**, 2026-09-06 **05:16:44–05:17:42 PDT**, exit **0**. `runtime-provenance-full.log:1788` reports `emergencyStopCancelsRunningBeforeWaitingForPlanner` passed after **22.374 seconds**; its final line 2463 reports **1092 tests / 31 suites / 57.278 seconds**, passed. That whole-test duration includes setup and is not the provider-observer timeout or the measured stop segment.

Full-log lines 1557 and 1564 explicitly join:

- Execution: `76F4697E-0D15-4374-9C1F-44273200F58F`.
- Orchestrator: `9FD2ED21-CCDB-44A5-81C9-6B5587402EFF`.
- Provider: `FB5CDB2F-6358-4308-917D-A19031FF2ADD`.
- Planner gate: `FB2964C3-9163-435E-AF56-FFA6B5170D95`.
- Entry generation: `D4DA6F58-D12A-4DA8-B5EB-2AFFA84AB67B`.

Independent parsing found **4080 event records plus one metadata record**, agreeing with `count=4080, finished=1`. Exactly **68 events** match these five owners; all are PID 61158, within **05:17:03.758537–05:17:08.322415 PDT**, and no owner/stage pair repeats. Thus no FD child or unrelated same-window fixture is needed for this halt join, and there is no ambiguous overlapping same-owner invocation in this captured path.

Verified SHA-256: full stdout `7705c0199a5f126605e500c8df2d65c1c0c6e5ce5ae505852bbb85fde48262a9`; NDJSON `4205398b6ceeaa047311501f09712a784ac554e92de5ef3be9ffbf2bf70ba49a`.

## Selected cancellation path and timing

State-load returned **0 (running)**; claim selection is **6 (new external cancellation on an existing primary attempt)**; installed-task and gate markers use **0 (external origin)**; cancellation-state selection is **3 (new resolver)**. Running snapshot count is 1 and later active cleanup attempt is 1. All 22 new reachable pre-cancellation stage families appear once. The terminal-path family is correctly absent. No cached resolver or reused cancellation requires pairing to prior work.

All intervals below use integer monotonic timestamps, divided by 1,000,000 for milliseconds. Shared `halt` prefixes are omitted. Aggregate and branch rows overlap; do not sum them.

| Boundary | Start mono | End mono | ms |
| --- | ---: | ---: | ---: |
| CoordinatorCalled → CancellationPersistenceCalled | 113948120984708 | 113948490319833 | **369.335125** |
| CoordinatorCalled → CoordinatorEntered | 113948120984708 | 113948121000500 | 0.015792 |
| CoordinatorStateLoadCalled → CoordinatorStateLoadReturned | 113948121007958 | 113948123233125 | 2.225167 |
| StateReadCalled → StateReadBodyEntered | 113948121031541 | 113948121109333 | 0.077792 |
| StateReadBodyEntered → StateReadBodyReturned | 113948121109333 | 113948122997250 | 1.887917 |
| StateReadBodyReturned → CoordinatorStateLoadReturned | 113948122997250 | 113948123233125 | 0.235875 |
| ClaimCancellationCalled → ClaimCancellationEntered | 113948123241708 | 113948123246958 | 0.005250 |
| ClaimCancellationEntered → ClaimCancellationSelected | 113948123246958 | 113948123283750 | 0.036792 |
| ClaimCancellationCalled → ClaimCancellationReturned | 113948123241708 | 113948446533958 | 323.292250 |
| InstalledCancellationQueued → InstalledCancellationStarted | 113948123267583 | 113948261504041 | **138.236458** |
| InstalledGateOpenCalled → InstalledGateOpenReturned | 113948123287000 | 113948446524250 | **323.237250** |
| InstalledGateWaitCalled → InstalledGateWaitReturned | 113948261512250 | 113948490290583 | **228.778333** |
| CancellationObserverCalled → CancellationObserverReturned | 113948490295708 | 113948490298916 | 0.003208 |
| CancellationObserverReturned → CancellationResolveCalled | 113948490298916 | 113948490302125 | 0.003209 |
| CancellationResolveCalled → CancellationStateEntered | 113948490302125 | 113948490305791 | 0.003666 |
| CancellationStateEntered → CancellationStateSelected | 113948490305791 | 113948490312458 | 0.006667 |
| CancellationStateSelected → CancellationResolverCalled | 113948490312458 | 113948490315750 | 0.003292 |
| CancellationResolverCalled → CancellationPersistenceCalled | 113948490315750 | 113948490319833 | 0.004083 |
| CancellationPersistenceCalled → CancellationPersistenceReturned | 113948490319833 | 113948501352208 | 11.032375 |

The synchronous state-read body and cancellation-state resolver admission are short in this run. The installed task starts while the caller's gate-open await is still outstanding; its gate wait begins at 113948261512250, gate-open returns at 113948446524250, claim returns at 113948446533958, and the task's gate wait returns at 113948490290583. These are overlapping caller/task branches. An open-return marker means the awaited call returned, not the exact internal opening instant. Gate-wait time includes gate availability and continuation scheduling; queue-to-start records task admission. Their durations do not establish a DB lock, executor starvation or an internal gate bug.

## Provider-before-planner order and the one-second limitation

Provider-wait start is **113947961649458**; source creates its deadline immediately before that marker. The following observed offsets do not redefine the original deadline:

| Event | Mono | ms after provider-wait start |
| --- | ---: | ---: |
| Cancellation persistence called | 113948490319833 | 528.670375 |
| Actual consumption cancellation called | 113948665336333 | 703.686875 |
| Provider stream termination, canceled | 113948898362375 | 936.712917 |
| Provider cancellation count recorded as 1 | 113948994109958 | **1032.460500** |
| Provider wait ended true | 113949023752125 | **1062.102667** |
| Caller observed true | 113949023760125 | 1062.110667 |
| Actual planner gate opened | 113949023776166 | 1062.126708 |

The canceled termination event and counter mutation both precede planner release; counter → gate is **29.666208 ms**. This directly supports the test's intended ordering, and cancellation did not require releasing the planner gate first in this observation.

However, `HaltHangingProvider.waitUntilCanceled` (`HaltAndCooldownTests.swift:908–922`) checks `cancellations == 0 && clock.now < deadline` around a sleeping polling loop, then returns the final `cancellations > 0` without requiring that mutation to have occurred before the deadline. If execution resumes late and the counter is already positive, it can return true after the nominal deadline. That is what the recorded markers permit here. The pass must therefore be reported as **observed cancellation before planner release**, not “provider counter updated within one second” or proof of a hard latency guarantee. No timeout/test-oracle change was performed or authorized by this analysis.

Additional measured progress: profile read **231.749750 ms**; separate later active-task queue/start **163.949000 ms**; consumption-cancel → provider termination **233.026042 ms**; provider-task-cancel-return → cancellation-caught **95.725958 ms**; caught → count mutation **0.013500 ms**. The later active task is not the earlier installed cancellation task and cannot be assigned its pre-persistence gap.

The cleanup path eventually joined: consumption-cancel → consumption-joined **1965.905000 ms**, entry-task join **109.241375 ms**, planning cleanup **9.592000 ms**, stop queued → stop task joined **4381.817417 ms**. Runtime cancellation returned, stop reached end with value 0 and the target test passed. These are observed completion intervals, not universal production bounds.

## Disposition relative to the earlier failure

The retained failed combined run's coordinator → persistence-entry interval was **863.437 ms**; the pre-cancellation focused pass measured **0.400208 ms**; this default full pass measures **369.335125 ms**. The newly instrumented run exposes task/gate progress intervals that the old failure did not record. It cannot retrospectively allocate the old 863.437 ms among those components or prove that all runs share one scheduling cause. No causal claim about DB starvation, deadlock, executor exhaustion, host pressure or the intervening CLI repair follows from this comparison.

For this full run, the target halt assertion and its observed provider-before-planner order pass. Historical halt latency/root-cause attribution remains unresolved; a strict one-second counter guarantee is not demonstrated. Overall default-full-run acceptance belongs to the separate full-gate evidence reviewer, and App build/package/product acceptance belongs to the parent. This report does not request another run or expand source scope.

Only this analysis artifact was written. No source change, test/compiler invocation, OSLog extraction, process signal/probe, DB/App action or subagent was performed. An initial read-only parser used an unavailable Ruby `filter_map`; it failed visibly and was replaced by equivalent `map.compact` before deriving any results.
