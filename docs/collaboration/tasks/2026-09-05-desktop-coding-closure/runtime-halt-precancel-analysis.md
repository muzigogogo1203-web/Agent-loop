# Halt pre-cancellation focused observation — independent interpretation

2026-09-06. The planned diagnostic's **sufficiently correlated focused-observation gate is complete** for this run. All expected boundaries on its selected running/new-external-cancellation/new-resolver path are present. Coordinator call to cancellation-persistence entry took **0.400208 ms**, compared with the retained combined failure's **863.437 ms**. This new focused pass establishes instrumentation integration and observable successful progress; it does not explain the old failure, prove a halt repair, or reopen the full runtime/product/package gate.

## Evidence and correlation

Read the complete pre-cancellation plan and independent source review, the prior combined halt analysis, and the new focused stdout/stderr, process record and all NDJSON records. No source review expansion, source edit, test/compiler invocation, sampling, signal, OSLog extraction, database, App, or subagent action was performed. This analysis is the only file written.

`runtime-halt-precancel-focused.log` records one passing test, 0 issues, **0.253 s** total. `runtime-halt-precancel-process.txt` records PID **57484**, **2026-09-06 04:53:31–04:53:32 PDT**, exit **0**, and all 12 source-manifest entries OK both before and after. These are retained execution checks against `runtime-coro-diagnostic-source.sha256`, not an analyst-triggered rerun. Compilation and prior source approval are separate evidence; this report evaluates the focused-observation gate only.

The two explicit fixture mappings join these identities:

- Execution: `19294DC2-C81E-4BFE-92F3-117EA7D06831`.
- Orchestrator: `2BDF289A-561A-448E-AF65-03E39EE4DBD3`.
- Provider: `72E8C2F2-9D20-4DF2-BBDA-0348F864959A`.
- Planner gate: `4C085498-55DF-4788-9869-0B86099ED432`.
- Entry generation: `EC2F9ECC-0695-4EEB-A1B7-C52ED9AB3EAF`.

Independent parsing found **68 event records plus one metadata record** (`count=68`, `finished=1`). Every event has exact PID 57484, falls within 04:53:32 of the recorded window, belongs to one of the five explicitly mapped owners, and has a unique stage in this capture. No ambiguous repeated same-owner invocation or missing required target identity appears. The execution mapping is from this new run, not the combined failure's UUID.

## Selected path

`haltCoordinatorStateLoadReturned value=0` identifies running state. `haltClaimCancellationSelected value=6` identifies newly installed external cancellation on an existing primary attempt. Installed-task and gate markers carry external origin **0**. `haltCancellationStateSelected value=3` identifies new resolver ownership. Snapshot count is 1; the later active-cleanup task uses attempt 1.

Consequently, absence of `haltCoordinatorTerminalPath` is correct for this run. There is no cached/in-flight resolver or reused cancellation branch to require pairing with earlier work. All 22 new stage families reachable on this selected path appear once; the 23rd family is the unselected terminal path.

## Measured pre-persistence intervals

All mono values below are the recorded monotonic integer timestamps; durations are their differences in milliseconds. Stage labels omit only the shared `halt` prefix. Aggregate rows and branch intervals overlap and must not be added together.

| Boundary | Start mono | End mono | ms |
| --- | ---: | ---: | ---: |
| CoordinatorCalled → CancellationPersistenceCalled | 112536039131125 | 112536039531333 | **0.400208** |
| CoordinatorCalled → CoordinatorEntered | 112536039131125 | 112536039136958 | 0.005833 |
| CoordinatorEntered → CoordinatorStateLoadCalled | 112536039136958 | 112536039142458 | 0.005500 |
| CoordinatorStateLoadCalled → CoordinatorStateLoadReturned | 112536039142458 | 112536039451166 | **0.308708** |
| CoordinatorStateLoadCalled → StateReadCalled | 112536039142458 | 112536039144833 | 0.002375 |
| StateReadCalled → StateReadBodyEntered | 112536039144833 | 112536039171375 | 0.026542 |
| StateReadBodyEntered → StateReadBodyReturned | 112536039171375 | 112536039432500 | 0.261125 |
| StateReadBodyReturned → CoordinatorStateLoadReturned | 112536039432500 | 112536039451166 | 0.018666 |
| CoordinatorStateLoadReturned → ClaimCancellationCalled | 112536039451166 | 112536039456916 | 0.005750 |
| ClaimCancellationCalled → ClaimCancellationEntered | 112536039456916 | 112536039470541 | 0.013625 |
| ClaimCancellationEntered → ClaimCancellationSelected | 112536039470541 | 112536039489000 | 0.018459 |
| ClaimCancellationCalled → ClaimCancellationReturned | 112536039456916 | 112536039508916 | 0.052000 |
| InstalledCancellationQueued → InstalledCancellationStarted | 112536039480166 | 112536039496500 | 0.016334 |
| InstalledGateOpenCalled → InstalledGateOpenReturned | 112536039490750 | 112536039506375 | 0.015625 |
| InstalledGateWaitCalled → InstalledGateWaitReturned | 112536039498458 | 112536039515000 | 0.016542 |
| CancellationObserverCalled → CancellationObserverReturned | 112536039516750 | 112536039518750 | 0.002000 |
| CancellationObserverReturned → CancellationResolveCalled | 112536039518750 | 112536039520458 | 0.001708 |
| CancellationResolveCalled → CancellationStateEntered | 112536039520458 | 112536039522541 | 0.002083 |
| CancellationStateEntered → CancellationStateSelected | 112536039522541 | 112536039526666 | 0.004125 |
| CancellationStateSelected → CancellationResolverCalled | 112536039526666 | 112536039528583 | 0.001917 |
| CancellationResolverCalled → CancellationPersistenceCalled | 112536039528583 | 112536039531333 | 0.002750 |

The synchronous state-load bracket is the largest component in this successful observation. Its 0.026542 ms read-call-to-body interval measures pool-read admission; it does not establish a DB lock. Its 0.261125 ms body interval includes fetch and guards, and its 0.018666 ms final interval includes pool return overhead. Actor-call intervals include admission plus intervening synchronous work; they do not identify a specific executor problem.

The installed cancellation Task started at **112536039496500**, before claim returned at **112536039508916**. Its gate wait had already begun at **112536039498458** while the external claim's gate-open await was still in progress; gate-open returned at **112536039506375**, and wait returned at **112536039515000**. Thus claim-return timing and task progress are overlapping branches. Gate-open return marks await return, not the gate's exact internal opening instant; gate wait combines gate availability and continuation scheduling. Observer-return → resolve-called is the planned aggregate lifecycle-preparation residual, not cancellation-state actor delay.

## Later progress and observer outcome

These landmarks retain the distinction between the early installed cancellation Task above and the separate, later active-cleanup Task:

| Boundary | Start mono | End mono | ms |
| --- | ---: | ---: | ---: |
| CancellationPersistenceCalled → CancellationPersistenceReturned | 112536039531333 | 112536044354916 | 4.823583 |
| ActiveTaskQueued → ActiveTaskStarted | 112536044369416 | 112536044377666 | 0.008250 |
| ProviderWaitStarted → CancellationPersistenceCalled | 112536038633208 | 112536039531333 | 0.898125 |
| ProviderWaitStarted → ConsumptionCancelCalled | 112536038633208 | 112536044380041 | 5.746833 |
| ProviderWaitStarted → ProviderCancellationRecorded | 112536038633208 | 112536044461958 | 5.828750 |
| ProviderWaitStarted → ProviderWaitEnded | 112536038633208 | 112536048803875 | 10.170667 |
| ProviderCancellationRecorded → PlannerGateOpened | 112536044461958 | 112536049455708 | 4.993750 |
| FixtureStopQueued → FixtureStopJoined | 112536037578416 | 112536074388458 | 36.810042 |

Provider cancellation count reached 1, provider wait ended true, and the caller observed true. Cancellation was recorded **4.993750 ms before** the planner gate opened, directly satisfying the intended order in this focused observation. Runtime cancellation returned, consumption and entry tasks joined, planning cleanup returned, and stop reached its end with value 0. The provider-wait marker is an observable anchor immediately after the source creates its deadline; it is not a replacement exact deadline.

## Limits and disposition

The retained combined run remains **1091 tests / 31 suites / 4 issues / exit 1**. Its missing pre-persistence detail cannot be reconstructed from this new, much shorter successful execution. This result does not prove that the old 863.437 ms interval was a state-read delay, actor admission delay, gate delay, DB starvation, deadlock, executor exhaustion, or the same cause as any other issue. Timing under added diagnostics can differ.

No required observation boundary is missing in this selected path, so no capture-completeness blocker remains for this supplement. Diagnostic observation is complete; halt root cause and behavior repair remain unproven, the full runtime/desktop gate remains red, and no broader rerun, behavior change, merge, or release is authorized by this analysis. Root owns any later evidence-backed decision. CLI cancellation findings are outside this report.
