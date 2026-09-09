# Independent cold-gate Fix 1 source re-review

Date: 2026-09-06. Scope: Fix 1 only, prior to focused execution.

Prior P2 publication-race finding: **ADDRESSED**. Fix-brief compliance: **PASS**. Source quality: **PASS**; no new actionable P0/P1/P2 finding in the fix-only diff. This closes the source-review objection in `runtime-cold-gate-cleanup-review.md`; that original report remains preserved. Runtime acceptance remains pending.

## Inputs and scope

Read the complete `runtime-cold-gate-fix1.diff`, `runtime-cold-gate-fix1-brief.md`, and the appended Fix 1 sections of `runtime-cold-gate-cleanup-impl-report.md` and `.superpowers/sdd/runtime-cold-gate-cleanup-plan/task-1-report.md`. Read the affected current-source method and corresponding exact Fix 1 preimage section to assess surrounding assertions and ownership.

Parent/writer-supplied identities for this review:

- Fix preimage: `runtime-cold-gate-fix1-before/ExecutionEngineConformanceTests.swift`, SHA-256 `404db276fd96e1a69ba30763dccbc09ae8ee42b62f1744a3d5b3916584d11716` (the previously reviewed source).
- Fix-only diff: `runtime-cold-gate-fix1.diff`, SHA-256 `be481f5f33ccf4bc77f6aea55a2ed89b0a09c7911a1374a1e5440f9085380a69`.
- Fixed source: `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`, SHA-256 `ce476a5f42732d61983eb405bb35db8337cf45d988cb463a2dfd127fbd6012bb`.

Those hashes and the reported full-file byte-preservation checks were not rerun by this reviewer, as instructed. The complete supplied fix diff contains one hunk inside the new forced regression, changing only its readiness polling predicate and start/end diagnostics. The original 065 method is outside that hunk. No aggregate dirty-checkout diff was reviewed.

## Per-finding resolution and new-breakage assessment

**Addressed P2: child readiness no longer suffices before SIGCONT publication.** At `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift:5762–5768`, the owned body continues polling while either the ready file is absent or there is no published successful SIGCONT observation. The successful observation is read through the existing lock-protected snapshot. Once the predicate observes that record, the append-only observation array cannot subsequently become empty, closing the original syscall-to-publication race before the exact-count assertion.

The deadline is still the original post-launch three-second deadline at line 5752, with the same throwing ten-millisecond sleep. There is no added deadline, separate wait, task, synchronization primitive, early stream consumer, or cancellation in this readiness loop. The ordinary 065 method's readiness behavior is unchanged.

The post-loop file guard, exact-one assertion, positive PID, real group/live PID checks, and deliberate `.afterReady` throw remain at lines 5770–5781. A successful observation count of two still fails the exact-count requirement; a count of zero at verification also fails instead of being recast as the marker. A missing ready file still throws its original timeout error. All such failures remain inside the existing owned body, so cancellation and actual stream join still run before assessment.

The added start/end diagnostic fields at lines 5758–5760 log only readiness Bool and successful-continuation count alongside the established safe fixture identity. They distinguish missing file from missing publication without exposing command, token, payload, or arbitrary error text. These are observational snapshots, not a new timing or cleanup certificate.

The post-loop cleanup assessment, actual cancellation/stream result checks, TERM/KILL requirements, signature sequence, identity checks, and exact-primary/no-cleanup-error acceptance guard are unchanged in the inspected preimage/current sections. No new mutable shared state, Sendable capture, lock ordering, unsafe indexing, error suppression, or teardown path is introduced by Fix 1.

## Pending gate and limits

The source objection is resolved and this fix is ready for the parent-owned focused observation after the other required source review. Acceptance still requires complete output and actual exit code for both `p1f1_065CancellationCleansProcessAndCommitsOnce` and `p1f1_065ColdGateForcedFailureStillJoinsCleanup`, including their actual identity/resource certificates, followed by independent evidence review. No focused result has been supplied or evaluated in this re-review.

No checks, build, Swift invocation, test run, process action, OS-log access, network/provider use, source edit, commit, or subagent was performed. Reads and this new review artifact were the only work. No new unsafe RED is requested. Prior limitations remain: this change does not establish the original readiness-delay cause, bound all production joins, repair other harness lifetimes, prove a separate parent-cancellation injection, or clear the red full-suite/runtime delivery gate.
