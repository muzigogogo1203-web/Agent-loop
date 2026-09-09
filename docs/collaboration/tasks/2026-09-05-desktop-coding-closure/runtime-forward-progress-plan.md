# Runtime blocking-operation forward progress repair

2026-09-08. Status: independent entry review approved; Task 1 implementation authorized. This is an implementation unit, not acceptance of the whole desktop product.

## Authority and design

The user's request to fix the remaining failures and the ownership record in `../2026-09-05-product-takeover-baseline/spec.md` authorize this bounded reversible repair. Technical evidence: `runtime-repair-cli-cause.md` and `runtime-repair-halt-cause.md`. Source inspection proves blocking `waitpid` runs on a Swift cooperative worker; it does not prove that this caused all historical full-suite failures. Preserve HALT semantics and test deadlines.

Introduce `package enum BlockingProcessOperation` with `package static func start<Value: Sendable>(_ operation: @escaping @Sendable () -> Value) -> Task<Value, Never>`. Its caller retains the task and joins the actual result, including after cancellation. Initially extract the existing Task.detached container unchanged to obtain a meaningful behavioral RED. Then move only the blocking operation to a named utility Thread, bridged through one checked continuation inside the retained Task. Preserve the entire production waitpid loop, exact-child ownership, EINTR, status decoding, exit publication, and diagnostic events.

The discriminating test uses a real pipe/read through this production bridge, not a new suspended process. This intentionally narrows proof to executor availability at the production boundary and avoids descendant containment requirements in the existing self-exec helper. Existing CLI and full-suite tests cover the actual backend integration.

## Global constraints

- Authoritative dirty checkout remains in place; create `codex/runtime-forward-progress-20260908` before source edits. Freeze source preimages and complete build-input manifest. No commit, push, merge, worktree cleanup, installed App changes, real data, Provider calls, secrets, administrator operations, or sampling.
- Only three source paths: new `Sources/AgentLoopCore/Support/BlockingProcessOperation.swift`, one container replacement in `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`, new `Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift`. No existing test/helper/deadline edits.
- Dated post-full amendment: Task 3 additionally permits only `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` after independent amendment approval, to register the exact two successor files. Historical manifest bytes, counts and hashes remain frozen. This does not reopen other source gates.
- Root owns all builds and test execution; one implementer owns source writes. Review agents are read-only and do not execute workloads. Preserve full command output, exit status, source manifest and executable identity for RED/GREEN/full runs in a unique evidence directory.
- Test-only `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` applies to one self-exec child, never the whole suite or product. Its effective discrimination must be demonstrated by RED; setting it alone proves nothing.
- No passing claim if compilation/setup/containment fails. RED requires completed real blocking read, checked release/close, joined controller and sibling, and the specific rescue-used assertion. GREEN uses the identical regression with no rescue and successful cleanup.

### Task 1: Regression and behavior-preserving extraction

Write the new test first, then extract the current `Task.detached { operation() }` container into `BlockingProcessOperation.start`; replace only the production reaper's `Task.detached` call with this bridge. Do not apply the Thread fix yet. Follow the source scope and root-only execution constraints above.

Test `blockingProcessOperationPreservesCooperativeProgress` calls existing `runOwnedSelfExecTest` with exact filter, label, strict environment key/value, unique evidence path key, success evidence `blocking-progress-ok\n`, and a 15-second outer containment. In the child, create one real pipe, with distinct owned read/write descriptors. No subprocess or user shell.

An independent utility controller Thread starts synchronously before the bridge operation. Lock-protected state plus short Thread.sleep polling with ContinuousClock deadlines, or an equivalent monotonic condition wait, protects entry, sibling progress, rescue, I/O outcomes and completion. Set checked F_SETNOSIGPIPE on the owned writer so unexpected reader failure produces an observable EPIPE. The blocking operation signals entry immediately before real Darwin.read; retry EINTR only. After entry, the controller enqueues an unrelated Task.detached to record progress, then waits at most one second (monotonic bound) for it. On deadline, record rescue=true. Always release the reader via one checked byte write and checked close; record every failure. Use a finite five-second entry/setup bound. On setup failure close the writer to release any eventual read and report the failure. No swallowed errors or duplicate close ownership. Controller join uses a completion flag and checked continuation, never a blocking wait on a Swift worker.

Cancel the returned operation Task immediately, record isCancelled, and still join its actual result, controller completion and progress task before assertions or throwing. This exercises the retained-join-after-cancellation contract in the same fixture. Assert cancellation was requested, one expected byte read, successful write/descriptor closure, sibling progress, controller completion, and rescue=false. Emit phase details on both paths. Write exact success evidence only after passing all required conditions. The old container must fail specifically because rescue was required while the strict worker was blocked; outer containment/setup errors are not accepted RED.

Root verifies source scope and builds the frozen source while its read-only independent source review proceeds. The focused test starts only after source-review approval and successful build. Preserve expected nonzero RED. If RED is not discriminatory, investigate the actual result before changing the production container; no repeated blind runs.

### Task 2: Move blocking work off the cooperative executor

After root confirms Task 1 RED, change only the bridge implementation: retained Task.detached awaits withCheckedContinuation; a named `AgentLoop.process.blocking` utility Thread invokes the synchronous operation and resumes the continuation exactly once. Do not abandon the operation on cancellation, change backend lifecycle, or add speculative abstractions. Document that joining the task means the actual blocking operation has completed and that a blocking operation itself must have an external release/termination mechanism.

Root builds and runs the unchanged focused regression to GREEN, then one ordinary full `swift run RunTests` with no strict-pool override. Obtain independent spec/quality review of the exact delta and test evidence. If the full suite has residual failures, retain them, block acceptance and proceed only with a new discriminating cause/regression, not timeout relaxation or blind reruns. Update `progress.md`, `blocked.md`, `impl-report.md` and a bounded result report with true remaining limits. Full success is not installed-App/user acceptance.

### Task 3: Exact successor registration amendment after full-suite RED

2026-09-08 23:39 full result: 1131 tests/33 suites/45.325 seconds/8 parent issues in six tests/exit 1. Two issues are this unit's missed successor registration: `a3Revision02EntryBoundaryRemainsByteExact` enumerates 104 instead of historical 102, with precisely the two added files. Remaining CLI failures are separate and block full acceptance. Three historical HALT tests pass in this run, not a universal latency proof.

Before editing, independently approve this amendment and freeze the existing DurablePlanningTests preimage plus the two registered file identities. Sole writer may then add a dated `desktopCodingClosureBlockingProgressSuccessorFiles20260908` literal Set containing exactly the two new source paths. In the existing boundary test require count 2, literal equality, disjointness from manifestPaths, historicalSourcePaths and the A1 foundation successor set; require both paths regular/non-symlink. Exclude only this exact set from live enumeration. Do not change historical manifest digest 3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e, original206 entries, live102 count, old allowlists, per-entry hashes, or other assertions. No glob/prefix exclusion.

Existing full RED is the before evidence; after the narrow edit, root builds and runs only `a3Revision02EntryBoundaryRemainsByteExact` to GREEN, preserving complete evidence. Independent delta review is required. Do not run another full suite solely for this registration; residual CLI tests need a separate causal repair before another full gate. The first three source files remain frozen during Task 3.
