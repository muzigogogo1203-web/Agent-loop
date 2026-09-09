# Independent cold-gate Fix 2 source review

Date: 2026-09-06. Scope: the compile boundary and two-hunk Fix 2 only.

**Source gate: PASS.** Fix-brief compliance and source quality pass, with no actionable P0/P1/P2 finding in this change. The fix preserves all three required predicates and their ordering. **Compilation repair remains UNVERIFIED** until the parent supplies a successful compiler result; this source review is not focused-test acceptance.

## Evidence and identity

Read the complete 141-line `runtime-cold-gate-cleanup-focused.log`, the Fix 2 brief, the appended Fix 2 implementation report, the complete fix-only diff, and the affected source assertions. The log contains three compiler errors in new `#require` expansions at the then-current lines 5778, 5780 and 5793: `cannot convert value of type 'Void' to type 'Bool' in coercion`. It also shows those nonoptional predicates being diagnosed as optional-require candidates. There is no test-execution output. The parent reports the command exited 1 before either focused test ran; this is compile RED, not runtime-cleanup failure.

Verified SHA-256 values:

- Retained compile log: `8aae063940741b282b46363d04424c5e8b1598a812d38d1460555d2f6b092e64`.
- Fix 2 preimage: `ce476a5f42732d61983eb405bb35db8337cf45d988cb463a2dfd127fbd6012bb`.
- Fix 2 diff: `3420fc97e743269c487b105d74dd677dc3bd9bb1ac9dd107834aa5d0ea03509e`.
- Released test source: `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`.

A read-only exact replacement comparison against `runtime-cold-gate-fix2-before/ExecutionEngineConformanceTests.swift` passed: each of the three old statements occurs once; replacing them with the supplied explicitly typed Bool binding plus required assertion produces the complete current file byte for byte. Thus all nontarget source is unchanged, including Fix 1 readiness synchronization, ownership/cleanup, original 065, all other assertions, imports and dependencies. The aggregate dirty-checkout diff was not used.

## Predicate and behavior assessment

In `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`:

- Lines 5778–5779 bind the exact `pid > 0` predicate to `hasPositivePID: Bool`, then retain `try #require(hasPositivePID)` before the unchanged process-group check.
- Lines 5781–5782 bind the exact `Darwin.kill(pid, 0) == 0` predicate to `isProcessAlive: Bool`, then retain `try #require(isProcessAlive)`. This performs one actual signal-zero syscall, after positive-PID and group verification and before the unchanged deliberate `.afterReady` throw. Requiring the stored Bool does not reevaluate the syscall.
- Lines 5795–5796 bind the exact `evidence.pid > 0` predicate to `hasPositiveEvidencePID: Bool`, then retain its throwing required assertion after TERM/KILL evidence and before the unchanged evidence group comparison.

Each local is immutable and evaluated immediately before its required assertion. No predicate, PID type, cast, catch, default, skip, timeout, branch or assertion severity was changed. Body failures still enter the owned primary result; post-cleanup evidence failures still enter the existing labelled cleanup-verification catch. The literal-zero comparisons are now resolved in an explicit Bool assignment before the assertion macro receives a simple Bool value. This directly addresses the observed expression-expansion boundary without weakening the test.

No new concurrency, Sendable capture, mutable shared state or lifetime behavior is introduced. Using named Bool values may yield less automatic operand detail than a direct binary-expression macro, but it preserves the required pass/fail semantics and the existing actual PID/cancellation diagnostics. This is not an actionable defect in the bounded fix.

The GRDB/import overload context remains a plausible contributor described by the parent, not an isolated or proven root cause. Neither the retained log nor this source-only review justifies a stronger causal claim. The explicit Bool contract is a scoped correction for the confirmed macro boundary; whether it resolves the compiler errors must be established by compiling the fixed source.

## Pending gate and limits

Proceed to the parent's corrected compile and planned two focused tests under the existing ownership and evidence rules. Acceptance requires a successful compiler result and actual execution of both `p1f1_065CancellationCleansProcessAndCommitsOnce` and `p1f1_065ColdGateForcedFailureStillJoinsCleanup`, complete output/exit code, their identity/resource certificates, and independent evidence review. The failed compile supplies no runtime evidence for either test. No new unowned behavioral RED is required.

This reviewer performed only scoped reads, read-only hash/exact-replacement verification and this new report write. No source edit, build, Swift invocation, tests, OS-log access, process signal, network/provider action, commit or subagent was performed. Earlier review artifacts and evidence remain untouched. No claim here clears the separate full-suite/runtime delivery gate or expands prior lifecycle guarantees.
