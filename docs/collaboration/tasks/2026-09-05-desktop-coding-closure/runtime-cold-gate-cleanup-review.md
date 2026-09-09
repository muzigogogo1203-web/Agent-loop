# Independent cold-gate cleanup source review

Date: 2026-09-06. This is the pre-execution source gate, not runtime acceptance.

Spec compliance: **PASS** against the frozen task-1 brief. Code quality: **CHANGES REQUESTED**, one P2 test-oracle race. No P0/P1 finding.

## Reviewed inputs and integrity

Reviewed all 527 lines of `runtime-cold-gate-cleanup.diff` first, then `.superpowers/sdd/runtime-cold-gate-cleanup-plan/task-1-brief.md`, `task-1-report.md`, the detailed implementation report, and the relevant exact preimage/current source sections. The aggregate dirty-checkout diff was not used.

Verified SHA-256 values:

- Current test source: `404db276fd96e1a69ba30763dccbc09ae8ee42b62f1744a3d5b3916584d11716`.
- Scoped diff: `113e901a068a6ce26d070d7908e67bbf13676ade642acad25ad9b23a9f338924`.
- Exact test preimage: `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f`.
- HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

The scoped diff changes only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`. Independent substring comparisons confirmed byte-identical original signature/pre-registration bodies, cold success assertions plus the complete main branch, and gate backend factory. Scoped whitespace checking emitted no diagnostics (exit 1 represents differing files).

## Actionable finding

**[P2] Synchronize readiness with successful SIGCONT-record publication before asserting its presence.**

Location: `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift:5770–5773`; producer ordering at lines 589–594 and 498–500.

The forced-failure test stops polling as soon as the child creates `cold-ready`, then immediately requires one successful SIGCONT observation. The inspector first calls `Darwin.kill(-processGroupId, SIGCONT)` and only afterward appends its captured result under the lock. A valid execution can resume the child and create the marker while the sender is descheduled between the syscall and `recordSignal`. The test can therefore observe readiness and an empty observation array, report an expectation failure, and never reach the deliberate `.afterReady` marker even though launch/readiness are correct. The locks protect array access, but they do not order marker creation after publication. The backend's synchronous `send` call does not provide such an ordering to the independently polling test task.

Keep the child owned exactly as now. Before making the one-record assertion, establish publication ordering, for example by including the required successful continuation observation in the new regression's existing readiness polling condition under the same already-created three-second deadline and ten-millisecond sleep. Then retain the exact-count, positive-PID, live-PID/group checks and deliberate marker. Alternatively add an explicit fixture-local publication barrier with the same bounded readiness contract. Do not consume the stream early, expand the deadline, weaken the assertion, or replace an unexpected error with the deliberate marker. No unmanaged RED is needed to resolve this source-level race.

This is a false-failure risk in the new test oracle, not evidence of an orphan or of unsafe cleanup: a failed requirement is captured as the primary and cleanup still runs. The implementation mirrors the brief's example, so this is a quality issue in that prescribed sequencing rather than an undisclosed implementation deviation.

## Compliance and quality checks that passed

- **Owned cold stream:** lines 205–253 capture body errors, perform exactly one explicit backend cancellation in a detached task, begin stream iteration only after that attempt settles, and await the detached task's actual result. No cancellation retry, consumer cancellation, throwing gap after launch, or timeout race abandons this ownership.
- **Error preservation:** lines 193–200 and 262–280 retain the actual body error, cancellation result and joined-stream result separately. Assessment independently appends actual cancellation and stream errors. The ordinary test fails on any primary or cleanup failure. Error descriptions expose controlled categories and observation integers rather than raw backend/stream payloads.
- **Signal identities:** both existing signal syscalls execute once; errno is captured immediately; accepted ESRCH remains accepted by the fixture but cannot count as successful continuation. Existing attempt bookkeeping, injected gate ordering, polling and thrown errors remain unchanged. Only actual successful SIGCONT records supply the cold PID candidate.
- **Certification before teardown:** lines 808–923 require exactly one positive successful continuation identity, matching cancellation PID/group, reaping and both EOFs, PID/group `-1/ESRCH` probes, non-consuming `waitid` with `WNOWAIT` and `-1/ECHILD`, exact socket `lstat` with `-1/ENOENT`, empty registry and successful joined stream with exited evidence. Observations accumulate independently, including after cancellation failure. Missing/uncertain identity or evidence retains the root. Signal-zero probes do not send a terminating signal; the only wait retry is EINTR.
- **Checked removal:** `removeChecked` closes the directory authority before removing the exact root and propagates failures. Both cold call sites disable removal immediately before synchronous launch; no await intervenes. Defers report retained roots or checked teardown errors. The ordinary primary alone does not prohibit removal once all resource evidence passes, as specified.
- **Timing and existing behavior:** original three-second/ten-millisecond readiness logic, synchronous launch, original shell command and preserved assertions remain. The unchanged factory and backend defaults retain five-second TERM, two-second KILL and one-second drain grace. Earlier 065 signature, pre-registration and main paths remain unchanged apart from shared signal observation instrumentation and the explicitly scoped gate-root defer.
- **Forced-path oracle apart from the finding:** the fixture uses the actual normal backend and live child. Readiness, successful continuation, positive PID, live PID and actual process group are checked inside the owned body before `.afterReady`. Actual TERM/KILL, signature order, matching PID/group and exited evidence are verified after cleanup. Only the exact expected primary plus no cleanup/verification errors is accepted; readiness/assertion/cancel/stream failures cannot become an expected success. Additional evidence failures can fail the test while a separately complete resource certificate permits removal, consistent with the brief.
- **Swift 6 static assessment:** backend conforms to the Sendable driving protocol; frames and cancellation evidence are Sendable; detached captures use those types and immutable identity/execution strings. The body is `@Sendable`; harness mutable state and signal records use their existing locks. Array indexing and group negation in certification are protected by short-circuit count/positive checks. No new static sendability or shared-state violation was identified. This is not compiler evidence.

## Boundaries and next gate

Unchanged production source was consulted only for named risks: detached-capture sendability, synchronous launch/stream termination/cancellation semantics, default grace values, and the SIGCONT publication race. No broad source review was performed. An initial targeted lookup used a nonexistent `Sources/AgentLoop` directory; it failed visibly, then was corrected by locating `CliProcessBackend.swift` under `Sources/AgentLoopCore`.

No build, Swift invocation, test run, app, OS-log access, network/provider use, process signal, commit, source edit or subagent was performed in this review. Only this review artifact was written. The parent-approved retained behavioral RED exception is preserved; this review does not request a fresh unsafe reproduction.

Resolve the P2 publication race and provide the new frozen diff/source hashes for review before the planned focused observation. Runtime acceptance remains pending full parent-owned output for both focused tests and independent review of that evidence. A passing focused run would not by itself disprove this scheduling race. No conclusion here clears the existing full-suite/runtime delivery gate, diagnoses the original readiness delay, establishes a hard bound on production join, repairs other harness lifetimes, or proves parent-cancellation behavior through a separate runtime injection.
