# Abort465 exact-owner containment implementation draft

> **Status:** Tasks 1–2 are independently approved for bounded source preparation after fresh entry capture. Root owns every source application, build, test and evidence gate. Exact staged review remains required before workloads. Task 3's test-address split and containment-before-assertion design are accepted in principle, not an execution permit.

**Staging amendment:** Task 1 includes gate/client/guard/owner plus no-child regressions only. Concrete process identity capture, publication and signaling are deferred to Task 3; no placeholder success or unused signal implementation. Guard-expiry first-abort ownership is checked across guard plus epilogue because those legitimate paths may race: exactly one first abort per gate, zero ordinary releases, both waiters aborted, one expiry and repeated post-join aborts false. No real-process claim follows from the no-child unit.

**Goal:** Give the `00000000-0000-4000-8000-000000000465` ready-file abort subcase total test-body ownership, capture its exact fresh child identity before its first `SIGCONT`, and contain only that identity if ordinary backend cleanup cannot be certified.

**Architecture:** Keep the backend as the sole normal terminator and reaper. In `ExecutionEngineConformanceTests.swift`, extract the existing abort choreography behind a small owner with a one-shot epilogue, add a native deadline guard that can only wake the two test gates and shut down the currently owned client, and add a separate exact-identity observer/last-resort positive-PID containment path that never calls `waitpid`. Four process-free tests first prove the current early-return ownership defect and then freeze the unconditional-epilogue repair before abort465 is wired to it.

**Prerequisites:** Root must first freeze fresh preimages after cleanup-provenance Task 1 and cooperative-offload Task 2 are GREEN. The current Task 2 source hash reported at draft time is `dd0a9a6c6df7831996f3b8cbe452fe10cd381c2a6624150f94d0d98327031cad`; it is context, not an entry hash.

**Implementation source:** `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift` only. Do not change `CliProcessBackend.swift`, `BlockingProcessOperation`, the C fixture, Package.swift, runner inventory, production wait-status handling, ignored reap/drain-result behavior, signal order, polling budgets, or global scheduling.

## Fixed invariants

- The ready-file fixture has no descendants. Normal cleanup remains wholly owned by `CliProcessBackend`.
- The guard never closes a descriptor, calls `waitpid`, consumes a wait event, discovers a PID by name/range, or signals a group. Its only client action is checked `shutdown` of the exact client stored in its synchronized slot.
- Emergency process intervention is allowed only after revalidating the one captured direct-child identity. It signals a positive PID only. Any intervention, identity ambiguity, unexpected errno, live process/group, waitable child, guard expiry, or cleanup residue fails the real test and retains the fixture.
- The owner receives a positive guard-started acknowledgement before it starts the stream or reaches any controlled blocking boundary.
- Control locks protect snapshots and one-shot state only. They are never held while waking a gate, shutting down a client, joining a task, reading process/file identity, probing liveness, or sending a signal.
- Guard expiry, late identity publication, and returned-uncertain cleanup share one synchronized containment claim. Exactly one path may attempt containment; every other path records that the claim was already consumed.
- The guard is disarmed and joined after reader/cancellation/stream joins and before the owner performs the one checked client close.
- No assertion, `try await`, or early `throw` may escape between body capture and the end of the owner epilogue.
- Existing Task 2 wrapper behavior, controlled-wait counters, strict-pool tests, and every existing abort465 publication/signal/readiness/resource assertion remain. Moving the abort465 block to its own test must not delete or weaken an oracle.

## Exact small interfaces

All names below are private to the test source.

### Gate abort state

Extend `P1F1D065GateWaitOutcome` with `.aborted`. Add:

```swift
private struct P1F1D065GateAbortObservation: Sendable, Equatable {
    let firstAbort: Bool
    let hadEntered: Bool
    let pendingAsyncWaiters: Int
    let entries: Int
    let releases: Int
}
```

Change `P1F1D065SynchronousGate.enterAndWait()` to return `Bool`: `true` for an ordinary release, `false` for an abort. Add `abortWake() -> P1F1D065GateAbortObservation`. Under the existing condition lock it sets an explicit `aborted` bit, wakes the native condition, removes and resumes every async waiter with `.aborted`, and returns a snapshot. `waitUntilEnteredOrCompleted()` checks `aborted` before installing a continuation; `complete` cannot replace an abort. Add an owner-only idempotent ordinary-release operation that increments `releaseCount` only on the first ordinary release. Keep the existing `release()` behavior for the frozen Task 2 callers, so their `entries == 1 && releases == 1` oracle remains unchanged.

`P1F1D065BlockingProgressSink` and the process inspector's controlled wait throw a fixed `P1F1D065AbortSafetyError.gateAborted` when `enterAndWait()` returns false. They continue through `p1f1d065AwaitSynchronousBoundary`; no inline blocking is reintroduced.

### Client ownership

Keep `init(ownedDescriptor:)` for the Task 2 socketpair test. Add only the abort-owner path:

```swift
private static func makeUnconnectedAbortClient() throws -> P1F1D065SocketClient
private func connectAbort(path: String, control: P1F1D065AbortSafetyControl) throws
private func sendAbort(_ value: JSONValue, control: P1F1D065AbortSafetyControl) throws
private func readLineAbort(control: P1F1D065AbortSafetyControl) throws -> String?
private func interruptReadChecked() -> Result<Void, any Error>
```

`makeUnconnectedAbortClient` creates the socket, checks `SO_NOSIGPIPE`, and checks `F_GETFL`/`F_SETFL(O_NONBLOCK)` before returning ownership. Every setup failure checks the local close and reports both errors. The owner installs this client in the guard control immediately after creation and before `connectAbort`.

Connect, send, and read preserve the current protocol bytes and EOF behavior. `EINTR` retries; `EAGAIN`/`EWOULDBLOCK` and `EINPROGRESS` use `poll` in 25 ms slices, checking `control.isAborted` between slices. Nonblocking connect validates `SO_ERROR`. These methods remain synchronous POSIX units, but the owner must await each connect/hello/send unit through the already-GREEN `p1f1d065AwaitSynchronousBoundary`; no new Task, detached wrapper, or cooperative-thread blocking path is permitted. There is no shell fallback and no independent longer deadline; the guard's injected/live budget is the deadline authority.

Extend the existing shared reader helper, rather than duplicating its async wrapper:

```swift
private func p1f1d065ReadResultLinesUntilEOF(
    _ client: P1F1D065SocketClient,
    abortControl: P1F1D065AbortSafetyControl? = nil,
    onReadEntered: @escaping @Sendable () -> Void = {},
    onLine: @escaping @Sendable (String) -> Void = { _ in }
) async throws
```

Its one existing `p1f1d065AwaitSynchronousBoundary` closure selects `readLineAbort(control:)` only when `abortControl` is present; the nil path calls the unchanged `readLine()`. The frozen Task 2 test bodies continue to call the default nil path byte-for-byte. The abort owner's reader passes the control. The client never stores or retains the control; the control may retain the installed client, so there is no client/control strong-reference cycle.

`interruptReadChecked` holds the descriptor lock through `shutdown` and records its result/errno. It does not detach or close the descriptor. After all users and the guard are joined, the existing checked close detaches once and reports close failure. This removes the snapshot-then-FD-reuse race without changing the Task 2 socketpair contract.

### Fresh identity and containment

Add:

```swift
private struct P1F1D065AbortProcessIdentity: Sendable, Equatable {
    let pid: pid_t
    let parentPID: pid_t
    let processGroupID: pid_t
    let uid: uid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt32
    let executablePath: String
    let executableDevice: UInt64
    let executableInode: UInt64
    let executableHash: String
}

private func p1f1d065CaptureAbortProcessIdentity(
    pid: pid_t,
    authority: CliExecutableAuthorityV1
) throws -> P1F1D065AbortProcessIdentity
```

The capture reads the first `proc_bsdinfo`, then `proc_pidpath`, then completes checked path canonicalization plus staged-file `lstat` identity and SHA-256 authority validation, and only then reads the second `proc_bsdinfo`. This binds the kernel tuple around the entire path/file/hash interval. It requires: PID greater than 1; both BSD reads are full-sized; `pbi_pid == pid`; `pbi_ppid == getpid()`; `pbi_pgid == pid`; `pbi_uid == getuid()`; nonzero start tuple; identical PID/PPID/PGID/UID/start tuples across both reads; canonical process path equal to canonical staged path; and regular-file UID/device/inode/hash equal to the staged authority. Any failure returns no identity and signals nobody.

Add `configureAbortDiagnostics(fixtureId:executionId:rootPath:control:)` to `P1F1D065ProcessInspector`, one-shot like cold diagnostics. On the first injected `SIGCONT`, it captures and publishes the identity and synchronously prints fixture UUID, execution ID, exact private root, PID/PPID/PGID/UID/start/path/device/inode/hash before calling `missingImageGate.enterAndWait()`. The existing actual signal observation remains after that wait.

The prospective read-only certificate uses only the captured identity: `kill(pid, 0)`, `kill(-pgid, 0)`, and `waitid(P_PID, pid, WEXITED | WNOHANG | WNOWAIT)`. Passing requires PID and group `ESRCH` plus `waitid` `ECHILD`, registry zero, removed socket/config, successful directory-authority close, joined cancellation/stream/reader, and no guard action.

If returned cleanup is uncertain, a one-shot `p1f1d065ContainFreshAbortIdentity` re-runs the full identity capture and requires exact equality before any signal. Exact still-live identity permits positive-PID `SIGKILL`; if that same identity still exists, positive-PID `SIGCONT` may follow. Record every syscall/probe result and errno. Never call `waitpid`; `waitid` remains `WNOWAIT`. ESRCH sends nothing. Drift or ambiguity sends nothing and fails closed.

### Guard and owner lifetime

Add one lock/condition-based control, not a generic runner:

```swift
private final class P1F1D065AbortSafetyControl: @unchecked Sendable {
    func installClient(_ client: P1F1D065SocketClient) -> Result<Void, any Error>
    func publishIdentity(_ identity: P1F1D065AbortProcessIdentity) -> Result<Void, any Error>
    func waitAndExpire(after budget: Duration) -> P1F1D065AbortGuardReport
    func waitUntilGuardStarted() async
    func disarm() -> Bool
    var isAborted: Bool { get }
    var snapshot: P1F1D065AbortSafetySnapshot { get }
}

private func p1f1d065StartAbortGuard(
    control: P1F1D065AbortSafetyControl,
    budget: Duration
) -> Task<P1F1D065AbortGuardReport, Never>
```

The control owns only the two gates, synchronized optional client slot, optional exact identity, shared one-shot containment claim, guard-start acknowledgement, and fixed observations. `waitAndExpire` runs through `BlockingProcessOperation.start`, publishes its started acknowledgement first, then uses the condition for disarm or expiry. The owner awaits `waitUntilGuardStarted()` before starting either waiter or entering any controlled boundary. Expiry snapshots and claims work under the lock, releases the lock, then calls `abortWake()` on both gates and checked shutdown on the installed client. If identity is already present the shared claim may invoke exact containment; if not, it records `awaitingIdentity`, and later `publishIdentity` observes the aborted state and competes for that same claim. Installation after expiry similarly snapshots under lock, then interrupts the client outside the lock and rejects further connect work. Live budget is exactly 30 seconds; only the no-child expiry test injects a short budget.

Every control operation follows the same two-phase rule: mutate/snapshot/claim under the control lock, then perform gate, descriptor, process/file inspection, signal, or join work after unlocking. Identity capture and revalidation must not call back into the control while the control lock is held. The returned-uncertain path calls the same `claimContainment()` used by guard expiry and late publication; it cannot create a second signal attempt.

Use three small owner pieces rather than one coroutine:

```swift
private struct P1F1D065AbortOwnerOperations: @unchecked Sendable {
    let startStreamWaiter: @Sendable () -> Task<P1F1D065ControlledStreamReport, Never>
    let startCancellationWaiter: @Sendable () -> Task<P1F1D065CleanupPublicationReport, Never>
    let makeClient: @Sendable () throws -> P1F1D065SocketClient
    let connect: @Sendable (P1F1D065SocketClient) async throws -> Void
    let performHello: @Sendable (P1F1D065SocketClient) async throws -> Void
    let sendToolCall: @Sendable (P1F1D065SocketClient) async throws -> Void
    let startReader: @Sendable (P1F1D065SocketClient) -> Task<Result<Void, any Error>, Never>
}

private func p1f1d065RunAbortBody(...) async -> Result<P1F1D065AbortBodyObservation, any Error>
private func p1f1d065RunAbortEpilogue(
    claimant: P1F1D065AbortCleanupClaimant,
    bodySucceeded: Bool,
    lifetime: P1F1D065AbortLifetime
) async -> P1F1D065AbortEpilogueReport
private func p1f1d065RunAbortOwner(...) async -> P1F1D065AbortOwnerReport
```

`P1F1D065AbortLifetime` stores the two started waiter tasks, optional client, optional reader task, native guard task, and a one-shot epilogue claim. It exposes the same epilogue to a no-child test rescue only after the owner returns. The epilogue never throws; it records separately: both gate cleanup outcomes (abort observation or idempotent ordinary release), client shutdown, reader result/absence, cancellation result, stream result, guard disarm, guard result, and final checked close/absence.

The fixed epilogue order is:

1. Claim once as `.owner` or `.testRescue`.
2. If the body failed, call `abortWake()` on both gates so native and async pre-entry waiters are woken, and record both abort observations without increasing ordinary release counts. If the body succeeded, perform the owner-only idempotent ordinary release on both gates and record whether each was already released by the body.
3. Checked-shutdown the installed client, if any.
4. Join the reader if it was started.
5. Join cancellation and stream waiters.
6. Disarm and join the native guard.
7. Checked-close the client once.

`p1f1d065RunAbortOwner` first starts the native guard and awaits its positive started acknowledgement. Only then does it create the stream/cancellation waiters and call the body. `p1f1d065RunAbortBody` preserves the current choreography and samples: wait for missing-image entry/completion; make and install the client; await connect through the existing synchronous-boundary helper; await the complete hello send/read through that helper; await the tool-call send through that helper; start the shared result reader with `abortControl`; wait for cleanup-publication entry/completion; ordinarily release missing-image; sample `publishedBeforeCleanup`; ordinarily release cleanup-publication; then return. Every branch becomes a captured body result; it does not join or close directly.

## TDD sequence

### Task 1: Add the four process-free ownership regressions with a real PRE-RED

Add the types/helpers above and extract `p1f1d065RunAbortOwner` in its old ownership form: it runs the epilogue only after a successful body. On an early body failure it returns `body`, `epilogue: nil`, and its still-owned `lifetime`. Do not wire abort465 yet.

Add exactly these tests:

1. `p1f1_065AbortOwnerJoinsAfterHelloFailure`
   - Use a real `socketpair`; the owner owns one descriptor and the test owns the peer.
   - Start controlled stream and cancellation tasks through the real Task 2 synchronous-boundary wrapper so each is observably waiting on one of the two real gates.
   - Use the real owner operations through client installation; inject exact `P1F1D065AbortOwnerTestError.hello` at `performHello`.
   - After the owner returns, capture whether `epilogue` was present. If absent, call the same epilogue as `.testRescue`. Only after that rescue returns, join/checked-close the peer and assert the positive guard-start acknowledgement, body sentinel, both controlled tasks joined, guard joined without expiry, client shutdown/close succeeded, reader was absent, each gate has one first-abort observation, and ordinary release counts remain zero.
   - The sole intended PRE-RED assertion is that cleanup belonged to `.owner`, not `.testRescue`.

2. `p1f1_065AbortOwnerJoinsAfterClientConstructionFailure`
   - Use the same controlled waiter tasks; inject exact `.clientConstruction` from `makeClient` before a client or reader exists.
   - Perform the same unconditional test rescue before assertions.
   - Require the exact body sentinel, client/reader absence, both gates abort-woken, ordinary release counts zero, both waiters and guard joined, and no FD/process/signal effect.
   - The sole intended PRE-RED assertion is owner rather than rescue ownership.

3. `p1f1_065AbortGuardExpiryWakesPendingWaiters`
   - Configure no child and no client, a short injected guard budget, and waiter operations that use `waitUntilEnteredOrCompleted` without entering either gate.
   - Let the actual guard expiry drive both gates to `.aborted`; no sleep-based ordering is required because later waiter registration must also observe `.aborted`.
   - After owner return, perform test rescue if needed, then require both async waiters joined with `.aborted`, both first-abort observations present, ordinary release counts zero, guard joined/expired exactly once, no descriptor/process/signal action, and exact body `.gateAborted`. A later rescue `abortWake()` must report `firstAbort == false` and must not create a second intervention.
   - The sole intended PRE-RED assertion is again owner rather than rescue ownership. Guard expiry is expected only in this dedicated test.

4. `p1f1_065AbortOwnerJoinsStartedReaderAfterBodyFailure`
   - Use a real socketpair with its peer open and silent until epilogue shutdown and reader join finish. The shared reader uses the actual abort-control path.
   - Its existing `onReadEntered` callback completes the cleanup-publication gate with `.reader`; keep that gate unentered, using an async cancellation waiter for this case. The body fails with exact `.gateCompleted(.reader)`.
   - The cancellation waiter may register before completion or after the epilogue abort; record and allow only those exact typed outcomes `.gateCompleted(.reader)` or `.gateAborted`. This independently reviewed scheduling distinction does not relax the exact body error or successful reader EOF. No extra registration latch or sleep is needed.
   - Run the identical rescue epilogue if needed before assertions, then checked-close the peer. Require reader operation entry (not a claim of kernel-blocked read), the specifically expected reader terminal result, successful shutdown/close, every task and guard joined, and no guard expiry. Do not accept an arbitrary reader error as cleanup success.
   - The sole intended PRE-RED assertion is owner rather than rescue ownership. No new owner injection hook is needed.

This fourth case was independently approved by `forward_progress_review` on 2026-09-09 before source staging. No `#require`, throw, or desired-ownership assertion may occur before rescue, waiter/guard joins, and checked FD close. Print one fixed summary per test proving those cleanup facts before the intended assertion.

Root then runs, and only root runs:

```sh
swift build --product RunTests
swift run --skip-build RunTests --filter '(p1f1_065AbortOwnerJoinsAfterHelloFailure|p1f1_065AbortOwnerJoinsAfterClientConstructionFailure|p1f1_065AbortGuardExpiryWakesPendingWaiters|p1f1_065AbortOwnerJoinsStartedReaderAfterBodyFailure)'
```

Expected PRE-RED: build succeeds; exactly the four owner-ownership assertions fail; all rescue summaries prove waiters/guard joined and FDs closed; no subprocess, process signal, fixture, or registry entry exists. Freeze the four test bodies and root's complete logs before GREEN.

### Task 2: Make the owner epilogue unconditional

Change only `p1f1d065RunAbortOwner`: capture the body `Result`, always call `p1f1d065RunAbortEpilogue(claimant: .owner, bodySucceeded: ...)`, and return both. A failed body therefore abort-wakes both gates; only a successful body takes the idempotent ordinary-release path. Do not special-case any sentinel. Rerun the identical build and four-test filter. Expected GREEN: the test rescue path is unused; body errors remain exact; every epilogue result is present and joined.

Independent review must compare the frozen tests and verify that no test rescue, guard action, ignored close, or broadened deadline can manufacture success.

### Task 3: Wire only abort465 and isolate its test address

This test-address split is a separate scope amendment requiring explicit independent approval after the no-child GREEN. Approval of the owner/guard concepts alone does not authorize moving a test. The move must produce one abort465 child run, never a copy in both tests.

Move the existing abort465 block, with all its assertions, from `p1f1_065CancellationCleansProcessAndCommitsOnce` into a distinct `p1f1_065AbortBeforeRegistrationOwnsAllLifetime` test. Do not duplicate the child run. The former test retains its production signature, injected signature, cold gate, ready/drain, and forced-error cases unchanged.

In the new test:

- Create the fixture UUID, execution ID, gates, and safety control before launch. Configure abort diagnostics before constructing the cold stream.
- Build production owner operations from the existing stream waiter, cancellation/publication observer, protocol hello/tool call, and actual result reader; use the unconnected nonblocking client path and live 30-second guard.
- Run the reviewed owner and collect, without throwing, `Result`-backed observations for the positive guard-start acknowledgement; epilogue claimant; every started-task join; guard result; client shutdown/close; body/stream/cancellation terminal values; publication sample; readiness; signals; fresh identity/order; cleanup/socket/registry/directory state; and PID/group/`waitid` probes. Print the scoped identity and each actual signal/liveness errno observation with fixture UUID and execution ID as those Results are captured.
- Construct an explicit `P1F1D065AbortCleanupCertificate` from those stored booleans/Results before emitting any assertion. Its fields cover: expected body/stream/cancellation primary errors; publication ordering; readiness contract; exact signal contract; owner epilogue and every join/shutdown/close result; guard-start acknowledgement; fresh identity and before-wait ordering; cleanup/socket/registry/directory results; PID and group absence; `waitid` `ECHILD`; and guard disarmed with no action. Its computed `allowsRemoval` is the conjunction of those named fields. It must not read or infer the state of `#expect`/`#require` calls.
- If `certificate.allowsRemoval` is false, leave teardown permission false and, before any `#expect`, `#require`, `try`, or other throwing assertion, call the shared one-shot exact-identity containment path and store/print its complete Result. Guard expiry or late publication may already own the claim; that is recorded rather than retried. Containment success does not make the certificate pass and does not enable removal.
- Only after the certificate and any required containment Result are final, assign teardown permission directly from the already-computed `certificate.allowsRemoval`, then emit the preserved `publishedBeforeCleanup`, expected injected resume error, cleanup/socket/registry/directory-close, readiness polling, exact `[SIGCONT, SIGKILL, SIGCONT]`, identity, epilogue, guard, containment, and liveness assertions. An uncertified path therefore retains the root before assertions begin, and assertion control flow cannot manufacture removal eligibility.

There is no outer self-exec timeout: it cannot own the backend's separate process group and was already rejected. The native guard is only a release/shutdown/identity-containment aid; the explicit remaining limit is that it cannot force an arbitrary backend task to return if that task stays stuck after all owned wakeups and validated containment.

After source review, root may build and run only:

```sh
swift build --product RunTests
swift run --skip-build RunTests --filter p1f1_065AbortBeforeRegistrationOwnsAllLifetime
```

Entry requires the exact RunTests image/manifest and complete stdout/stderr capture. Do not run the old broad 065 test or the full suite until this single result is interpreted and independently reviewed.

## Acceptance gate

This unit is ready for broader integration only when:

- the four frozen no-child tests show meaningful PRE-RED and GREEN with complete resource summaries;
- independent source review approves identity timing, one-shot ownership, descriptor synchronization, guard lifetime, and absence of a second reaper;
- the one isolated abort465 run returns, preserves its primary error/provenance, joins every started task, certifies PID/group/wait absence and resources, and uses no emergency intervention; and
- the retained diff does not change runtime wait-status interpretation, ignored reap/drain decisions, deadlines outside the guard, other 065 oracles, or production code.

If the isolated run does not return despite guard action, stop: retain its fixture/evidence and report the unowned backend join as the remaining blocker. Do not add a timeout, skip, global serialization, or broader signal authority.
