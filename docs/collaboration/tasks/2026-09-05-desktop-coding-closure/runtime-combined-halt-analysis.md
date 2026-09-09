# Combined full run — exact halt failure boundary

**The one-second observer failed before the actual consumption cancellation was called.** This run localizes the missed boundary upstream of provider counter mutation: the coordinator-to-cancellation-persistence-entry interval consumed **863.437 ms**, and the cancellation-persistence entry was already **1007.537 ms after provider-wait start**. The subsequent active cleanup task began after the observer had returned false. This is measured late progress along the cancellation path, not a proven underlying scheduling/DB defect or a repaired halt bug.

## Scope and identities

`runtime-combined-full.log` ends **1091 tests / 31 suites / 63.440 s / 4 issues / exit 1**. Target halt contributes one assertion issue at line 1605 and finishes with one issue at line 1787. Actual parent PID **33956**, **02:09:14–02:10:18**, is retained in `runtime-combined-process.txt`; its before/after nine-file source checks and this analyst's independent manifest check all match. Expected FD children are excluded from this halt analysis.

Parsed all target-owner records from `runtime-combined-events.ndjson`, constrained to PID 33956. The **46 target events** join through the two explicit identity lines at full-log lines 1555/1562:

- Orchestrator `283F25E1-B52F-450B-AB06-8E39B22950FD`
- Execution `28DDA3B5-2950-472B-86BE-295951875755`
- Provider `32FFB7EB-98AE-4EE1-A80E-126809464CC4`
- Gate `B815AF38-3E92-40D1-80B5-97253FDD4272`
- Entry generation `3CA8778B-14EC-4E48-AE56-55E5A1D9EB46`

Snapshot count is 1; active cleanup task queue/start carries actual attempt 1. No target identity is missing. These are not joins inferred from interleaved test output order.

## The actual missed window

Provider wait-start is **102722476089166**. The original source constructs its one-second deadline immediately before this marker; marker time is a slightly later observable anchor, not a replacement exact deadline. Integer monotonic differences establish:

| Target event | Mono | ms after wait-start |
| --- | ---: | ---: |
| Profile read returned | 102722620158208 | 144.069 |
| Coordinator called | 102722620188708 | 144.100 |
| Cancellation persistence called | 102723483625791 | **1007.537** |
| Cancellation persistence returned | 102723500587458 | 1024.498 |
| Active cleanup task queued, attempt 1 | 102723500609666 | 1024.521 |
| Provider wait ended false | 102723504064125 | **1027.975** |
| Caller observed false | 102723504074666 | 1027.986 |
| Actual planner gate opened | 102723505396125 | 1029.307 |
| Active cleanup task started | 102723553236208 | 1077.147 |
| Consumption cancellation called | 102723553245958 | **1077.157** |
| Provider termination, `.cancelled` | 102724029631625 | 1553.542 |
| Provider actor cancellation count became 1 | 102724048919875 | **1572.831** |

The consumption cancel is **49.182 ms after** observer failure, and the actual counter increment is **544.856 ms after** it. Thus this failure is not merely a promptly completed provider cancellation whose counter actor update was delayed: counter catch → actor mutation is only **0.006 ms**. Nor did the provider already count cancellation but the polling loop overlook it; it was still zero when that loop exited. Planner gate opening precedes the eventual counter by **543.524 ms**, following the original test's retained failed assertion and gate-release order. This chronology does not prove the gate's opening caused later progress or that cancellation depends on it.

## Comparison with the passing focused run

All durations are milliseconds; intervals overlap and should not be summed indiscriminately.

| Boundary | Focused pass | Combined failure |
| --- | ---: | ---: |
| Stop queued → stop Task started | 0.015 | 133.246 |
| Supervisor suppression | 0.470 | 0.028 |
| Dispatch-mode persistence | 0.859 | 6.088 |
| Halting published → fixture observed it | 0.928 | 63.678 |
| Observer queued → provider wait started | 0.020 | 0.021 |
| Runtime profile read | 0.510 | 201.612 |
| Runtime composition | 0.013 | 0.015 |
| Coordinator called → cancellation persistence called | **0.355** | **863.437** |
| Cancellation persistence itself | 6.708 | 16.962 |
| Active cleanup task queued → started | 0.026 | 52.627 |
| Consumption cancel → provider termination | 0.157 | 476.386 |
| Provider task cancel returned → cancellation caught | 0.019 | 19.273 |
| Cancellation caught → actor counter increment | 0.004 | 0.006 |
| Provider wait started → ended | 10.301, true | 1027.975, false |
| Consumption cancel → joined | 0.355 | 2246.687 |
| Entry-task join | 0.024 | 333.570 |
| Planning cleanup | 4.233 | 11.512 |
| Stop queued → stop Task joined | 44.373 | 6032.682 |

Initial stop admission and halting observation occur before the provider's one-second window, so they are not milliseconds subtracted from that window. The runtime profile read overlaps its opening. The dominant unresolved **pre-cancel** interval is after coordinator-called and before persistence-called; do not confuse it with the measured 16.962 ms persistence operation itself. The later 476.386 ms consumption-to-provider interval is real but cannot explain why consumption had not yet been canceled at the already-expired deadline.

All target success-return stages eventually appear, including runtime cancel, consumption/entry joins, planning cleanup and stop-reached-end value 0. No further target test issue is reported. This establishes eventual completion in this run, not bounded cleanup latency under all concurrency or a deadlock. Whole-test 35.562 s includes setup outside this six-second stop segment and is not its observer timeout.

## Smallest remaining root-cause check

Source review identifies what the **863.437 ms** aggregate can contain, but the current events cannot separate it: `makeCoordinator(...).cancel` entry; the synchronous `loadExecutionAnyState` read (`Orchestrator.swift:2385–2435,2886+`); completion-registry `claimCancellation` actor admission/selection (`:1427+`); its existing `installCancellation` Task admission and gate wait (`:1633–1715`); the existing command-observer await and cancellation-state actor/resolver admission (`:661+`). The already measured **active** cleanup Task is a different, later task and must not be assigned that earlier gap.

If another diagnostic change is authorized, target only this pre-persistence gap first in the existing Orchestrator/logger files: mark coordinator method entry and exact state-read call/return; claim call/actor entry/return; the existing installed-cancellation task's queue/start/gate-return and resolver-call boundary. Retain canonical execution joins and the existing ownership tokens without creating new asynchronous seams, cancellation paths or retries. These boundaries can distinguish synchronous read time from actor/task/gate admission before selecting a repair. Do not preselect registry redesign, move cancellation ahead of durable persistence, change the observer timeout or expand to driver internals merely because the later interval also grew. This is a recommendation for a separate bounded reviewed probe, not authorization for another run.

Host context is unfavorable but not causal attribution: retained resource log shows VM pressure **2 before and after**, swap used **17973.06 → 17949.06 MiB**, and available data-volume space **4.0 → 2.1 GiB**. It does not assign a wait to a page fault, DB lock or executor, and must not explain all four full-run issues by assertion. Do not repeat full runs unchanged while pressure/disk constraints remain; parent owns whether a separately justified diagnostic observation can safely proceed.

Only this halt report was written. No source change, Swift invocation, OSLog extraction, signal, app/provider or agent was performed. CLI and other remaining full issues are outside this attribution; the full gate remains red.
