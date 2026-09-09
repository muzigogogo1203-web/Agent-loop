# 069 coroutine decomposition implementation report

## Status and scope

Source implementation is complete for the approved test-only compiler-cost repair. Compiler, runtime, and acceptance evidence remain pending with the parent task.

- Authoritative checkout: `/Users/muzi/Agent-loop`
- Branch: `codex/desktop-coding-closure-20260905`
- HEAD verified before editing: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- Frozen source preimage: `runtime-coro-split-before/ExecutionEngineConformanceTests.swift`
- Frozen/source preimage SHA-256: `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`
- Implemented source SHA-256: `e5a3ce4fae3ae1c0487ffe3c62b43360f49c7c6ef49ddf1d2d2538397ca2380e`
- Source writer ownership: only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift` was changed as source by this task. The pre-existing dirty tree was preserved.
- Additional task artifacts: this report and the identical task-directory copy.

The implementation inserts exactly 21 file-private, zero-argument `async throws` helpers immediately before `@Suite(.serialized)`. The original 069 test directly awaits the 21 helpers sequentially in original source order. No test concurrency, wrapper task, detached task, catch, retry, conditional skip, compiler attribute, import, production interface, package setting, timeout, or 065 change was introduced.

## Implemented partition and ownership self-review

| Frozen lines | Helper | Boundary/lifetime review |
| --- | --- | --- |
| 6546–6676 | `p1f1d069ExerciseRoutingWinners` | Initial sink submission remains awaited. The complete permutation loop retains outcome polling, assertions, database reads, and its per-iteration fixture defer; no value escapes the helper. |
| 6678–6890 | `p1f1d069ExerciseActiveCancellationRegistry` | Pending registration/cancel, both failing cleanup waiters, retry/removal, and the canceled start-gate task retain their waits and final observations. |
| 6892–7034 | `p1f1d069ExerciseSharedAdapterCleanup` | Model and CLI cancellation callers and stream consumers remain awaited after their cleanup gates are released. |
| 7036–7168 | `p1f1d069ExerciseModelClaimHandoff` | Handoff consumers, old atomic claim, original atomic consumer, and reuse consumer remain joined; claim wait/acknowledgment stays local. Lifecycle record tasks retain only their probe/event, not a fixture or later group input. |
| 7170–7300 | `p1f1d069ExerciseCliHandoffAndImmediateWinners` | Both stubborn CLI consumers and termination waits remain. The complete immediate-outcome loop retains its claim waits, acknowledgments, consumer join, and existing helper call. |
| 7302–7446 | `p1f1d069ExercisePrelaunchAndQuarantine` | All cancellation claims are waited and acknowledged, blocking gates released, consumers awaited, and quarantine reuse consumed before return. |
| 7448–7542 | `p1f1d069ExerciseGenerationBoundCleanup` | Both model/CLI generation-bound invocations remain awaited; the existing called helper retains both consumer joins, claim waits, and acknowledgments. |
| 7544–7661 | `p1f1d069ExerciseCompletionRegistry` | Both resolution tasks remain awaited; lifecycle publication/consumption, authorized removal, completion delivery, and duplicate-removal rejection stay together. |
| 7663–7808 | `p1f1d069ExerciseDispatchAdmission` | Duplicate execute tasks are joined after bind release. The pre-begin canceled task is joined after gate release; the incomplete-handle case starts no waiter. |
| 7810–7937 | `p1f1d069ExerciseBeginRegistrationLatch` | Bound callback, command/observer gates, cancel task, execute task, and final empty-registry observations stay together; both named tasks are awaited. |
| 7939–8131 | `p1f1d069ExerciseSettledPrimaryRetry` | Trigger, primary/external callers, observer barrier, both joins, trigger removal, awaited retry, and terminal observations remain one group. |
| 8133–8299 | `p1f1d069ExercisePostGateAndBindCancellation` | Post-gate cleanup is released and cancel/execute are joined. The complete bind-mode loop retains per-iteration defer, awaited callbacks, and outcomes. |
| 8301–8451 | `p1f1d069ExerciseObserverAndFinalizerFailure` | Routed execution remains awaited. Finalizer task is awaited after observer release, including expected failure and final state checks; callback-local return stays callback-local. |
| 8453–8605 | `p1f1d069ExerciseCompletionRemovalBarriers` | Success and failure paths retain coordinator-task and raw-receipt-waiter joins. The intentional failed-removal registry count of one remains exactly once; no teardown was added. |
| 8607–8648 | `p1f1d069ExerciseObserverStoreFailure` | Store fault installation, awaited execution failure, existing catch, and observer-count assertion remain together; no owner is introduced. |
| 8688–8823 | `p1f1d069ExerciseExactLiveCliCancellation` | The entire false/true loop remains intact. Cleanup release and cancel/execute joins precede the original guard/continue; sibling and registry checks remain within each iteration. |
| 8936–9042 | `p1f1d069ExerciseMissionCliRecovery` | The entire false/true loop remains; recovery is awaited before terminal/sibling checks and the resolver guard retains its closure target. |
| 9045–9145 | `p1f1d069ExerciseMissionModelRecovery` | The entire false/true loop remains; recovery is awaited before terminal/sibling checks. |
| 9148–9221 | `p1f1d069ExerciseSharedRecoveryOwner` | Cleanup release and both recovery-task joins precede shared-result and registry observations. |
| 9224–9333 | `p1f1d069ExerciseRecoveryFailureRetry` | The complete transport/evidence/store loop retains reset, disarm, awaited retry, and registry checks; callback guard return remains callback-local. |
| 9336–9558 | `p1f1d069ExerciseSharedRecoveryActionMatrix` | The complete all-cases loop retains both racing attempts and joins, trigger removal, blocker removal, awaited retry, and final state checks. |

No helper reads a local from the caller or another helper, and no helper-local fixture, registry, request, ledger, callback, or result is used by a later group. Under the approved fixture-scope ruling, each independent scenario may release its settled local fixture when its helper returns. Existing loop defers remain in their original loops. The known unstructured lifecycle-record tasks and wiring submission tasks were not rewritten or described as universally joined; their original ownership and evidence boundaries remain unchanged.

Error propagation is unchanged: each direct `try await` immediately propagates an unexpected helper error out of the original test. No cleanup or catch was added to mask an unfinished owner or failed operation.

## Mechanical preservation proof

A fresh static reconstruction was performed on the applied source:

1. Match and remove the exact concatenation of all 21 inserted helper definitions.
2. Match each of the 21 direct call sites exactly once and in source order.
3. Replace each call with the corresponding frozen inclusive line range, restoring the original eight-space indentation.
4. Compare the reconstructed entire source byte-for-byte with the frozen preimage.

Result: exact whole-source equality. Reconstructed SHA-256 is `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`.

Static inventory from the reconstructed 069 and applied source:

- Exact new helper signatures: 21/21.
- Exact direct call sites: 21/21, in original source order.
- File `@Test func` count: 10 before and 10 after.
- Exact `@Test func p1f1_069BoardTerminalExactlyOnceMatrix() async throws`: one.
- Exact `@Suite(.serialized)`: one.
- Expanded 069 assertions: 438 `#expect`, 5 `#require`.
- 069 marker strings: 10 `P1F1D069_STAGE=`, 6 `P1F1D069_CASE=`. One case marker is the string argument of a multiline `print`, so it is counted by marker string rather than same-line print syntax.
- Combined frozen 065 test bytes SHA-256: `726f1e2ad07855f5eb43a018352b78e6a877a9165100accd7958eaab1f1cd6a2`; the exact byte sequence occurs once in the applied source.
- Retained frozen spans remain byte-exact in the original test: 8650–8685, 8825–8920, 8922–8933, and 9560–9589. Thus the three whole-test guard scenarios remain in the caller, and the existing exact-recovery-owner loop remains there.
- Intentional `#expect(await removalFailureRegistry.snapshotCount() == 1)` occurrence: one.

Because expansion reconstructs the complete frozen source, all unselected bytes, literals, callbacks, loops, waits, assertions, markers, cleanup, and control-flow statements are preserved, aside from the specified uniform helper-body indentation while outlined.

## Verification pending with parent

Per the brief, this source writer did not run Swift, compiler, runtime, sample, signal, database, App, package, or commit operations. The following remain required and are not claimed by this report:

1. Responsibilities-separated actual-diff review of the applied source.
2. Bounded pre-LLVM emission and comparison against the 216,814-line / 747-suspension 069 baseline, ensuring cost is reduced rather than merely relocated.
3. Normal focused runtime verification covering both 065 cases and unchanged 069 with complete output, exit, hashes, compiler identity, and resource guards.
4. The previously planned halt diagnostic, CLI readiness review, authoritative full `swift run RunTests`, and all later product/package/acceptance gates.

## Concerns

No implementation-boundary concern was found after applying the reviewed partition. Runtime/compiler correctness and resource improvement are intentionally unresolved until the parent completes the required independent review and executions.
