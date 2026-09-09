# A1 integration runtime observation — independent capture/evidence review

Scope: the retained `goal-foundation-runtime-observed1-*` process, source, stdout/stderr and OSLog artifacts, plus the already retained uninstrumented `goal-foundation-integration-full1-*` and strict App compilation artifacts for gate disposition only. This reviewer did not run a compiler or test, change Source, diagnose root cause, or review/approve a repair.

Primary evidence pins: observed stdout `c585b10073e0a06faf545492f70c29b82dcd3ffdb9848564a2ab3bb2cab98bd4`; process record `475d801ef5e56df909eeee09ea88f19e2eb0c3466fe8c1ece903dba4a5c34ed2`; source manifest `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f` (all SHA-256).

## Verdict

- Capture integrity: **PASS**
- Failure accounting: **PASS**
- Runtime integration gate: **RED — unresolved**
- Open capture findings: **0 P0 / 0 P1 / 0 P2**

The single authorized observation is admissible evidence. It is not a repair, does not erase either full-run RED, and does not open A1 acceptance or A2 entry.

## Capture integrity

- The process record identifies the opt-in unfiltered command and actual RunTests PID 83578. Its nanosecond invocation interval is `2026-09-06T23:03:17.088286000+08:00` through `2026-09-06T23:04:43.449972000+08:00` (`goal-foundation-runtime-observed1-process.txt:314-317`). The run exits 1, and all 305 frozen inputs match exactly before/after with `source_drift=[]` (`:318-623`). Independent parsing confirmed 305 before entries, 305 after entries, no missing/extra path and no hash mismatch; the separate 305-line source manifest equals both sequences byte-for-byte.
- The retained raw NDJSON is distinct from the admitted reserialization and remains byte-pinned at SHA-256 `718da47ff6d786cf6c311e1f7c8c3f6eff8e3414809cd48d4ee779af49715c0f`. It has 1,998 lines: 1,997 original logger event rows plus the separate terminal metadata row `{"count":1997,"finished":1}`. The admitted artifact is SHA-256 `6143104161ceb8f3a57fc639f51f39e8957b8cbe8de74e276c3ee449b1c1ef8f`, contains 1,997 events, and is object-for-object and order-for-order equal to the 1,997 raw event rows after JSON parsing. The empty stderr artifact is SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- Independent parsing of every admitted timestamp found zero malformed values and zero events outside the inclusive invocation interval. The event interval is `2026-09-06T23:03:58.547222000+08:00` through `2026-09-06T23:04:40.432794000+08:00`. Every admitted row has processID 83578, subsystem `com.muzi.agentloop`, category `runtime-lifecycle`, the same RunTests image path and image UUID, and one boot UUID/trace ID. Thus no event from another PID or invocation was admitted.
- The process record independently retains the exact PID/subsystem/category predicate, `capture_admitted_count=1997`, `capture_rejected=[]`, matching metadata, `capture_metadata_ok=true`, `capture_exit=0`, `capture_event_count=1997`, `capture_parse_error=nil`, and `capture_ok=true` (`goal-foundation-runtime-observed1-process.txt:629-638`). The raw metadata count, admitted count and process-record counts agree; no event was silently discarded.

## Identity joins

The required joins can be made from explicit identities rather than chronology:

- Stdout maps recorder `C925FACA-9503-4F94-96CE-F84022ED1EA5` to execution 372, `BDB3B5D0-A896-4A23-8208-31EA3F86C2E4` to execution 346, and `76D0A18C-713E-4573-A315-E1C860176403` to execution 347 (`goal-foundation-runtime-observed1.log:2407-2409`). Checked cleanup maps those executions to continued PIDs 83963, 83965 and 83966 respectively (`:2521-2535`).
- Admitted `cliSpawned` events map PID 83963 to Core owner `F3246036-FBD9-4AD5-B3A4-DBBFAC449628`, PID 83965 to `63D2050A-239C-4831-80C4-C12927AE846E`, and PID 83966 to `BB3C7449-15B5-4B14-A4E7-0127A931C2F8` (`goal-foundation-runtime-observed1-events-admitted.ndjson:1043,1074,1099`). Each owner's `cliSIGCONTCalled` and `cliSIGCONTReturned` event carries the same PID (`:1049-1055,1080-1086,1105-1111`). Recorder-side cancellation PIDs independently agree (`:1387-1401,1421-1431`).
- The additional execution 152 identity and other lifecycle events are from the same admitted RunTests invocation and remain in the complete capture; they are not used to infer the 346/347/372 joins. No historical PID, line adjacency or duration similarity is needed.

## Block-aware failure accounting

The terminal result is exactly 1,130 tests in 33 suites, failed after 48.217 seconds with five parent issues (`goal-foundation-runtime-observed1.log:2705-2706`). Those five issues are fully accounted for:

- Execution 347 / `cliProcessBackendFixtureFailureStillJoinsRealCleanup`: two issues. Checked cleanup reports status 143, TERM true, KILL false, both EOFs true and child reaped; the test records the `killSent` expectation and the primary readiness failure with joined cleanup error (`:2521-2525,2528-2529`).
- Execution 346 / `cliProcessBackendCancellationEscalatesAfterGrace`: one parent issue, `process did not become ready` (`:2522-2527`).
- `p1f1_065CancellationCleansProcessAndCommitsOnce`: two parent issues, the cleanup-publication expectation and the terminal `coldGateReadinessTimedOut` error (`:2418-2427,2579-2580`). Its retained cleanup evidence shows the child reaped, both EOFs, no live PID/group/socket/registry entry, joined stream and no retained fixture root (`:2565-2576`); that cleanup does not make either parent assertion pass.

Two visually red nested blocks are not extra parent failures:

- The deliberate 075 child failure is bracketed by `FD CHILD BEGIN/END`, raw status 256, with its expected one-test child summary (`:890-901`); the enclosing top-level regression passes (`:2697`).
- The Board leak-proof child records delta 32 and its expected one-test child failure inside its own `FD CHILD BEGIN/END` block (`:2471-2486`); `boardFDIsolatedLeakStillFailsParent` passes (`:2488`).

Execution 372 is separately joined and its top-level checked-cancellation test passes (`:2534-2536`). None of these passing or expected-child facts reduces the five true parent issues.

## Gate disposition and limits

The earlier default uninstrumented full run remains RED: PID 81105, 1,130 tests/33 suites/53.406 seconds/exit 1 with two parent issues in execution 347 (`goal-foundation-integration-full1.log:2362-2366,2536`; process SHA-256 `d7c2ed52f990fb8b3780866c83e184256559ee7604e0d238777739ec30490c56`). The strict App command separately passed at PID 82106 with exit 0 and zero source drift (`goal-foundation-integration-strict-app1-process.txt:1,314,620-623`; log SHA-256 `be84f4913dfcdb723d1fe42ac567709feb7fc9e61c2919602bd0fe6856fa117d`). Compilation success is not runtime success.

This review accepts only the capture and the complete failure accounting. It does not choose among timing hypotheses, attribute cause to diagnostics or host pressure, approve a source change or deterministic probe, clear either full RED, or authorize another blind full rerun. A separate responsibility-separated timing/root-cause analysis remains required before any fix decision.
