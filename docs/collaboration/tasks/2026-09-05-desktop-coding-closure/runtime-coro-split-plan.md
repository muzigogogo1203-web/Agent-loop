# 069 coroutine decomposition implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Parent owns all compiler/test commands, source writers are exclusive, and independent scope/lifetime review is required. No commit.

**Goal:** Make the existing069 matrix affordable to compile by outlining independent sequential scenarios, retaining every behavior and one test identity.

**Architecture:** Replace21 contiguous scenario groups with direct sequential `try await` calls to21 file-private async throwing helpers in the same test file. Keep the three outer guard-return scenarios in the test, as well as its stage markers and already outlined exact-owner loop. No test concurrency, production interface, data model, package or compiler-setting change.

**Tech stack:** Swift6, Swift Testing, current local Swift6.2.3 frontend, unchanged debug/Onone settings.

**Spec:** `runtime-cold-compiler-checkpoint.md`; compiler resource attribution and exact069 entry. Context is the accepted desktop-closure runtime gate, not a new product direction. `runtime-cold-compiler-source-analysis.md` supplies the checked original scenario map.

## Global constraints

- Work in `/Users/muzi/Agent-loop`, existing branch `codex/desktop-coding-closure-20260905`, HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`. Preserve all dirty changes; do not create another worktree or commit/push/merge/release.
- Sole source write: `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`. No edits to065, other test entries, production, runner, Package.swift, imports, flags, timeouts or historical manifests.
- Frozen preimage: `runtime-coro-split-before/ExecutionEngineConformanceTests.swift`, SHA256 `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`. All line ranges below refer to this exact preimage, never shifting current lines.
- Keep `@Suite(.serialized)` and exactly one `@Test func p1f1_069BoardTerminalExactlyOnceMatrix() async throws`. Helpers are not tests and add no task/concurrency wrappers, detached tasks, catches, retries, conditional skips or compiler attributes.
- Every moved block retains its exact statements, literals, assertion macros, loops, callbacks, diagnostics, waits and cleanup, allowing only uniform indentation. No extracting loop bodies or rewriting continue/return. Calls preserve source order.
- Terminal-winner8650–8685, exact-live-model8825–8920, existing exact-recovery-owner8922–8933, and final unknown-outcome9560–9589 stay in the test unchanged. In particular, guard failure still returns from the whole test.
- All ten stage print sites and six case print sites remain; prints outside selected blocks stay at the same logical position relative to helper calls.
- Do not move a scenario across any task/producer/consumer join, resource cleanup or later data use. Source review must check every new group boundary. A cross-group reference blocks that partition and must be reported, not silently added as a parameter or captured global.
- Fixture-scope ruling: a fully settled independent scenario's local fixtures may now release when its helper returns, after its existing joins and final assertions; its existing loop defers remain in those exact loops. This deliberately avoids retaining completed unrelated fixtures across later scenarios. If any pending asynchronous owner depends on an earlier fixture at a new boundary, that boundary is not admitted. Preserve failure propagation and do not add teardown to hide an unfinished owner.
- Parent alone runs probes/builds/tests with full output, exit and hashes; no source writes while a compiler runs. No real database, App, paid Provider or historical PID operations.

## Reviewed partition

Each helper has the signature `private func NAME() async throws` and consists exactly of the indicated inclusive lines, with uniform indentation adjusted from8 to4 spaces. Put the helpers immediately before `@Suite(.serialized)`. Replace the selected block in the original test with `try await NAME()` at the same indentation. All unselected bytes remain unchanged.

| Preimage lines | Helper name | Boundary |
| --- | --- | --- |
| 6546–6676 | p1f1d069ExerciseRoutingWinners | Initial board sink + complete production permutation loop |
| 6678–6890 | p1f1d069ExerciseActiveCancellationRegistry | Pending, retry/shared failure, pending-only and closed start gate |
| 6892–7034 | p1f1d069ExerciseSharedAdapterCleanup | Joined model and CLI cleanup |
| 7036–7168 | p1f1d069ExerciseModelClaimHandoff | Model generation handoff/reuse and atomic old claim |
| 7170–7300 | p1f1d069ExerciseCliHandoffAndImmediateWinners | Stubborn CLI reuse + complete immediate-outcome loop |
| 7302–7446 | p1f1d069ExercisePrelaunchAndQuarantine | Prelaunch CLI and quarantined cleanup |
| 7448–7542 | p1f1d069ExerciseGenerationBoundCleanup | Model and CLI generation-specific cleanup |
| 7544–7661 | p1f1d069ExerciseCompletionRegistry | Completion lookup, shared resolution, lifecycle, authorized removal |
| 7663–7808 | p1f1d069ExerciseDispatchAdmission | Duplicate dispatch, incomplete handle and pre-begin cancel |
| 7810–7937 | p1f1d069ExerciseBeginRegistrationLatch | Durable begin/register cancellation latch |
| 7939–8131 | p1f1d069ExerciseSettledPrimaryRetry | Settled-primary failure/retry and exact ownership |
| 8133–8299 | p1f1d069ExercisePostGateAndBindCancellation | Post-gate cancellation + full bind-mode loop |
| 8301–8451 | p1f1d069ExerciseObserverAndFinalizerFailure | Routed observer + finalizer failure |
| 8453–8605 | p1f1d069ExerciseCompletionRemovalBarriers | Authorized-removal barrier + removal failure |
| 8607–8648 | p1f1d069ExerciseObserverStoreFailure | Store rejection prevents observer |
| 8688–8823 | p1f1d069ExerciseExactLiveCliCancellation | Entire false/true bind-session loop, including continue |
| 8936–9042 | p1f1d069ExerciseMissionCliRecovery | Entire CLI recovery bind-session loop |
| 9045–9145 | p1f1d069ExerciseMissionModelRecovery | Entire ModelLoop recovery bind-session loop |
| 9148–9221 | p1f1d069ExerciseSharedRecoveryOwner | Shared recovery callers and one owner |
| 9224–9333 | p1f1d069ExerciseRecoveryFailureRetry | Entire transport/evidence/store failure loop |
| 9336–9558 | p1f1d069ExerciseSharedRecoveryActionMatrix | Entire allCases loop, fault, two joined attempts and retry |

### Task 1: Outline and verify the measured compiler cost center

**Files:** sole source above; task report, scoped diff and compiler/test evidence under this task directory. No new product/test utility source file.

**Interfaces:** Consumes the same file-private069 fixture and helper APIs already used in each block. Produces21 private zero-argument async throwing functions, invoked only by the original069 test. No public API.

- [ ] **Step 1: Verify preimage and failing compiler evidence.** Read this full brief and the sampled/IR checkpoint. Verify source equals frozen preimage and branch/HEAD. The retained RED is the actual compiler resource failure (24.1GB footprint, exact CoroSplit069 entry, intentional143 stop), not a fabricated runtime assertion. Do not rerun that unsafe unchanged compiler. This task changes test structure only; the original069 runtime behavior is its covering test, not a new source-text test.
- [ ] **Step 2: Check partition dependencies and implement the exact move.** For each row inspect both ends, task joins and later references. If all boundaries satisfy the constraints, add its complete verbatim body under the specified signature and replace it with the direct call. Do not make other cleanups. Use apply_patch. If a row is unsafe, stop source work and report the concrete dependency; parent will amend the partition before more edits.
- [ ] **Step 3: Establish mechanical preservation and self-review.** Reconstruct the old test by expanding the21 call sites with their helper bodies and undoing indentation, and verify it equals the preimage test exactly. Confirm all other preimage content unchanged except helper insertion and these calls. Record exact21 helper count, original @Test count,438 #expect/five #require in expanded069, all ten stage/six case markers, and unchanged065 bytes. This is a refactor audit, not runtime test evidence. Inspect each helper's asynchronous ownership completion, resource lifetimes, no non-local references and all three kept whole-test guards.
- [ ] **Step 4: Release writer and independent review.** Write `runtime-coro-split-impl-report.md` with changes, dependency/lifetime table, preservation evidence, hashes and pending verification; parent writes scoped actual preimage diff. Independent review must approve spec compliance and quality before the parent normal compiler run.
- [ ] **Step 5: Parent compiler and focused runtime verification.** First repeat the bounded pre-LLVM emission and compare largest function size/suspend count to216814/747 baseline; do not accept merely relocated giant code. Then run ordinary `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run --jobs 2 RunTests --filter 'p1f1_065|p1f1_069'` after verifying the runner filter is regex-compatible; otherwise use separate known-supported filters with only the first compiling. Keep normal settings, all captured stdout/stderr and actual exit. Monitor headroom and exact compiler identity; stop owned compiler if available disk drops below6GiB or observed footprint exceeds8GiB. The source change must compile normally and both065 cases plus unchanged069 must actually pass. Resource gates are operational guards, not hidden test timeouts.
- [ ] **Step 6: Resume unresolved runtime gate.** Only after compiler/focused evidence, perform the already planned exact halt diagnostic and review the unresolved CLI readiness boundary. An unchanged full rerun is not admitted just to seek green; the authoritative full `swift run RunTests` remains required after justified repairs. No product-stage/package advance or acceptance claim comes from this refactor alone.

## Parent preflight

Single source task; no inter-task source producer/consumer conflict. The output calls and zero-argument helper inputs match the table. The measured failure is in069;065 remains untouched. Selected ranges avoid every outer whole-test guard and retain entire loops. The open risk requiring independent review is fixture lifetime across the selected boundaries; no blanket assertion that every boundary is safe replaces that review.

User has delegated ordinary reversible engineering decisions and asked to continue complete optimization. This bounded test-lowering repair does not request new product decisions or expand into external/destructive actions. It amends only the runtime verification workstream; all later completion gates stand.
