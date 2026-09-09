# 065 cleanup-publication: bounded evidence gap

Reviewed 2026-09-07 by `goal_remaining_migration_review`. Read-only analysis of the current pre-registration-abort subscenario, its immediate helpers/gates and the retained `child-observed1` evidence. No Source/plan changes, tests, compiler, sampling, authentication, signals or subagents. This document does not alter the pending one-shot CLI347 capture.

## Finding

The retained failure **does not establish premature publication**. It establishes that `!publishedBeforeCleanup && streamObservedExpectedFailure` was false. Either early publication, an unexpected stream outcome, or both can produce that result. The assertion's prose is a fixed diagnostic message, not an independently observed cause.

`publicationObservation` was already obtained by awaiting the cancellation task at source line 8432. The `<not evaluated>` at log lines 2278–2285 applies to its later equality comparison in the short-circuited assertion, not to execution of the cancellation task or collection of the observation. Its actual five fields are absent from this failure output.

## Exact evidence

- Source: `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`, SHA-256 `f7089c930283b0277721f3642a31491fef458006a5b20266b7119f5422c681f3`.
- Retained log: `goal-foundation-runtime-child-observed1.log`, SHA-256 `5588efa78bfd0265430f413f9bb986603757c8b99613009ea84eea6f2691dfea`.
- Relevant source: gates/probe at 278–391; injected resume branch at 552–588; cleanup observation at 1059–1092; this subscenario at 8292–8462. No general audit of the file or runtime implementation was performed.
- Log 2277–2286 records the source-8443 compound failure. Log 2458 reports this test finished with exactly one issue; the later suite summary likewise reports one issue for `ExecutionEngineConformanceTests`. The complete workload remains 1130 tests / 33 suites / 5 issues / exit 1, not a passing baseline.
- The process record identifies RunTests PID 97570, exit 1 and no terminating signal. Searches of the retained full output and scoped event records found no additional `…0465`, `pre-registration-abort`, injected-resume or cleanup-publication result values that resolve the two boolean operands.

## What the control flow establishes

1. The failing subscenario uses `abortExecutionId = …0465`, `abortHarness`, its own registry and two synchronous gates. Reaching the assertion means both gate waits selected `.entered`; the alternate completion paths throw before reaching it. This establishes that the gate entry events occurred, not that no competing task had subsequently completed.
2. The test releases `missingImageGate`, snapshots whether the publication probe is nonnil, then releases the blocked progress/cleanup gate. The probe is recorded only after `cancel` returns or throws and `p1f1d065ObserveCleanupPublication` has run. `publishedBeforeCleanup` therefore measures whether that probe record was already visible at this particular checkpoint; it is not a timestamped history of all possible publication events.
3. Before the assertion, the result-reader task has returned without propagating an error, the cancellation task has produced its observation, and the stream task has been joined. That stream join's outcome is deliberately collapsed into one boolean. A normal stream return, an unequal `CliProcessBackendError`, or any other error all produce `streamObservedExpectedFailure = false`.
4. The expected injected launch error is conditional: after releasing the first gate, the inspector attempts SIGCONT and polls for `resume-ready` up to 3000 one-millisecond sleeps. Seeing the file throws the expected `processLaunchFailed("injected resume dispatch failure")`; exhausting that loop throws the distinct `.resumeFailureReadinessTimedOut`. An unexpected signal error can take another path. These are source-permitted alternatives, **not evidence that any particular alternative occurred in this run**. The polling count is not a measured wall-clock duration under load.
5. The immediately following assertion expects attempted signals `[SIGCONT, SIGKILL, SIGCONT]`. With exactly one reported issue, there is no recorded failure of that check. Its source records each request before the underlying `kill` result, so matching this sequence does not prove successful resume, readiness or the specific thrown error.

## What cannot be inferred

- The log cannot distinguish the truth assignments `(publishedBeforeCleanup, streamObservedExpectedFailure) = (true, true), (true, false), (false, false)`.
- It cannot identify the actual stream error/category, whether the resume-ready file appeared in time, or whether cancellation observed the expected error.
- It cannot supply this subscenario's cleanup-file/socket/registry/checked-directory-close values. The observation helper calls checked close only when the first three cleanup predicates are true; otherwise it records `.notAttempted`. No value is printed here.
- It cannot establish a production publication-order defect, a fixture readiness timeout, resource starvation, or the same cause as CLI346/347/372. The 26.835-second duration belongs to the whole multi-part test, not this individual branch.
- The `065-cold` log beginning at 2287 belongs to the subsequent `gateHarness`, execution `…0065`, fixture `FD73951E-A77A-4C80-BFA7-3F43961FD736`, child 97830. Its successful cancellation, EOF/reap and `cleanup-certified=true` at 2439 are useful evidence for **that** fixture only. They do not fill the missing `abortHarness` observation. The later forced-failure cleanup test uses yet another execution, `…0865`.

## Minimum non-sensitive discriminator for a future recurrence

No instrumentation is authorized or applied by this analysis. If a later, separately approved change adds evidence, a fixed `065-pre-registration-publication` record immediately before this assertion is sufficient; it must use the already captured values, not repeat filesystem observations or resnapshot the probe later.

For the literal question “which conjunct failed?”, the strict minimum is one fixed integer field, `publicationFailureMask`: bit 0 = captured early publication, bit 1 = unexpected stream outcome, bit 2 = final observation mismatch. Compute the final comparison eagerly for this record. This preserves simultaneous failures instead of selecting a misleading single cause.

To distinguish the **error channel** hidden inside bit 1, the smallest useful additional field is `streamOutcomeCategory`, chosen from a fixed allowlist:

- `expectedInjectedResumeFailure`
- `completedWithoutError`
- `resumeFailureReadinessTimedOut`
- `otherCliProcessBackendError`
- `otherError`

Capture that category at the existing stream join/catch where the concrete error is still available, while preserving the assertion and existing failure semantics. Do not log error descriptions, associated strings, payloads, tokens, command arguments, environment, paths or arbitrary reflected types. The fixed scenario name plus mask/category needs no sensitive identifiers. A bare error category without the early-publication bit would still leave a possible simultaneous publication failure unresolved. The five observation components could be split later if bit 2 fails, but are not required to disambiguate this run's left-hand failure channels.

## Closure

Current classification: **unattributed compound-assertion failure with a specific observability gap**, not proven premature publication and not a repaired issue. Only this evidence-gap artifact was written; the source and retained log hashes were rechecked unchanged afterward. The current CLI347 capture plan, frozen product inputs and runtime/A1 gate are unchanged.
