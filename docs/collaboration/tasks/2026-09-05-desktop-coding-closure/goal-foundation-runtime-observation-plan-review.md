# A1 integration runtime observation plan — independent review

Review scope: `goal-foundation-runtime-observation-plan.md` only, SHA-256 `b547048134b92dfd355b75b8032f379771f88d2d60e4f81f5ae7209f93c82b65`. This review author did not write the plan or implementation under observation and did not run a compiler or test.

## Verdict

- Specification: **CHANGES REQUIRED**
- Plan quality: **CHANGES REQUIRED**
- Findings: **0 P0 / 1 P1 / 0 P2**

## Finding

### P1 — `--last 10m` does not enforce the actual invocation window

At `goal-foundation-runtime-observation-plan.md:17`, the plan correctly requires the actual RunTests PID and run start/end metadata, but the only concrete OSLog time constraint is `log show ... --last 10m`. That option is a bounded retrieval horizon, not the captured run interval. PID filtering plus a ten-minute lookback does not by itself prove that every admitted event belongs to this invocation; it also leaves “within the recent run window” operationally undefined. This is weaker than the referenced diagnostic contract, which requires events for the actual process **and interval** (`runtime-cli-readiness-diagnostics-plan.md:32,236`). Ambiguous attribution would make the one permitted observation inconclusive and cannot be repaired by rerunning.

Required bounded correction to line 17, with no source, timeout, concurrency, permission, or run-count expansion:

1. Record parseable, timezone-preserving wall-clock instants immediately before spawning the command and immediately after its wait/exit completes, in addition to the actual RunTests PID.
2. Retain the complete raw `--last 10m` NDJSON and its exit status as already planned, but parse each event timestamp as an absolute instant and admit an event to the diagnostic extract only when its timestamp is within the inclusive captured start/end interval, its process identifier equals the actual RunTests PID, and subsystem/category match exactly.
3. Retain the extraction predicate/command, raw and admitted event counts, and parse result. A missing or unparseable timestamp, PID mismatch, event outside the interval, logging permission failure, or ambiguous recorder/execution/continuedPID/Core-owner join is an evidence gap; it does not authorize a second run or inference from line proximity.

## Accepted portions and scope limits

The plan accurately preserves the unfiltered failure as RED, distinguishes the two expected child failures from the two parent issues, limits execution to one default-concurrency opt-in observation, prohibits semantic/source/timeout/probe/provider/App/real-data changes and observer-issued signals, retains complete outputs and input stability evidence, and has a sound one-capture stop rule. It also correctly prevents an instrumented pass from being called a repair or opening A1/A2.

This review does not diagnose the readiness miss, approve a repair or deterministic probe, accept A1/A2, or replace the required post-capture responsibility-separated evidence analysis. After the time-window correction above, the plan is otherwise ready for its single observation.

## Closure re-review

Re-reviewed only the corrected observation-admission text in `goal-foundation-runtime-observation-plan.md`, current SHA-256 `c8db999f29ace4a6418e80fbc6a7a50e6fc9982f92042c6591e1a84c0673bf6d`.

The new paragraph at line 19 closes the P1: it makes `--last 10m` retrieval-only; records nanosecond, timezone-bearing start-before-spawn and end-after-exit instants; preserves raw NDJSON; separately admits only parsed absolute-time events inside the inclusive invocation interval with exact PID/subsystem/category; records raw/admitted/rejected/metadata/parse/capture-exit evidence; and makes any timestamp, identity, permission, interval or consistency anomaly an explicit capture-blocking evidence gap with no rerun. This is the bounded metadata/extraction correction requested above and does not expand source, runtime-semantic, permission or run-count scope.

Final verdict for plan SHA `c8db999f29ace4a6418e80fbc6a7a50e6fc9982f92042c6591e1a84c0673bf6d`, superseding the initial verdict for the earlier plan revision:

- Specification: **PASS**
- Plan quality: **PASS**
- Open findings: **0 P0 / 0 P1 / 0 P2**

The review still does not pre-accept the capture, a diagnosis, any repair, A1 completion or A2 entry.
