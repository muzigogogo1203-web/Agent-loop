# Registered spawn-failure cleanup reconciliation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Root owns source admission, workloads, and independent review. This document is a proposal, not source-edit or execution authority.

**Goal:** After an accepted termination request, join and check the existing owned reap/drain tasks before making the final cleanup decision, while preserving real authority failures and the original launch error.

**Architecture:** Extract only the registered-group branch of the spawn-failure catch into one package-internal helper, retaining the old branch for meaningful behavioral RED. Its GREEN result distinguishes KILL acceptance, provisional final-CONT failure, actual joined task results, and post-join group absence. A narrow typed report supports the existing abort465 certificate; no new process runner, deadline, reaper, signal authority, or general terminal-state framework is introduced.

**Tech Stack:** Swift 6 strict concurrency; existing Darwin process inspector, `BlockingProcessOperation`, `Task` handles, `ShellProcessRegistry`, and runtime lifecycle diagnostics.

**Spec:** This is a proposed, explicitly reviewed amendment to `runtime-abort-containment-plan.md` in this directory. It changes that plan's production-code/ignored-result freeze only for the registered spawn-failure branch and changes the newly added abort certificate's raw-only final-CONT rule only under the stronger proof below. All older abort465 assertions remain unchanged.

## Evidence and causal boundary

- Input source hashes at drafting: `CliProcessBackend.swift` = `129dcf9090e7e2461cbf090bda4f2e37d535ffcfd914c434e2914f79eb5d08e2`; `ExecutionEngineConformanceTests.swift` = `37eeeab9427d80f9774a0f8cc33a9c6bf50e5b89df50c3f60c3c17d21506e6b8`. Root must capture a fresh full entry before source work; these are not execution pins.
- `runtime-abort-contained-entry.json` identifies the evidence directory. Its `integration2.log` records initial CONT success, readiness 390/3000, KILL success, final CONT `-1/EPERM`, then two pre-reap group probes `-1/EPERM`. The branch at `CliProcessBackend.swift:1231` skips all three owned task joins and registry retirement. Later read-only certificate probes find PID/group ESRCH and waitid ECHILD; this cannot retroactively establish successful production joins.
- The test inspector copies errno immediately after each failing syscall, before logging. This is not stale errno from logging or another thread.
- [Apple XNU `killpg1` source](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/kern_sig.c) excludes zombie members during group iteration and can return POSIX EPERM when a group exists but has no eligible members. That is a compatible explanation, not proof of the exact host's kernel branch. EPERM is not globally equivalent to ESRCH.

## Global constraints and exact file scope

- No commit, push, installed-app update, real-user state mutation, or historical fixture deletion.
- No new signals, reordered/delayed signals, polling, sleep, timeout, process discovery, competing waitpid/waitid owner, or wait-status interpretation change. Preserve the initial CONT and cleanup `[SIGKILL, SIGCONT]` order and all existing deadlines. The real test's native guard remains exactly 30 seconds.
- An accepted KILL permits joining already-owned tasks; failed KILL plus live/unknown group does not. This retains the existing limit that an arbitrary stuck owned kernel operation is not forcibly made return by the test guard. Do not add a new fallback for that limit.
- `terminateAndReapSpawnedGroup` (unregistered path), normal `finalize`, normal cancellation, C fixture, Package.swift, runners, inventory, and scheduling stay unchanged. If sharing the existing signal routine would change the unregistered path, keep a compatibility projection of its old outcome instead of changing that caller's policy.
- Implementation files: `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`; new no-child helper tests in `Sources/AgentLoopTestSuite/CliBackendTests.swift`; the reviewed inspector/certificate amendment in `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`; and only scoped stage additions in `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`.
- Four no-child abort-owner regressions, existing controlled wait/socket reader regressions, provenance regression, old abort465 assertion block, and all other existing test bodies remain byte-frozen, except the specifically reviewed inspector error-contract alignment and new certificate amendment below. No existing generic validation-error assertion requires a Darwin.kill failure to have that type: the catch near EEC 10524 is the separate pre-spawn signature rejection.

## Task 1: Extract the actual branch and establish deterministic RED

**Files:** Core backend plus new helpers/tests in `CliBackendTests.swift`. No real child is launched by the new tests. Use a local ordered fake, following the small queued-result pattern of `HaltR9DProcessInspector` in `HaltAndCooldownTests.swift:139`; do not share or change that existing fake.

**Interfaces:** Keep the existing reap result's fields and make that value package-internal for the actual helper's test seam; do not change its producer or decoding. Introduce these bounded value shapes in the backend file:

```swift
package struct CliProcessReapResult: Sendable {
    package let status: Int32?
    package let failure: String?
}

package struct CliSpawnCleanupSignalAttemptV1: Sendable {
    package let signal: Int32
    // nil = not attempted; success = inspector accepted; failure = exact error.
    package let result: Result<Void, any Error>?
}

package struct CliSpawnCleanupReportV1: Sendable {
    package let executionId: String
    package let processGroupID: Int32
    package let signals: [CliSpawnCleanupSignalAttemptV1]
    package let preJoinProbes: [Result<Bool, any Error>]
    package let reap: CliProcessReapResult?
    package let stdoutEOF: Bool?
    package let stderrEOF: Bool?
    package let finalGroupExists: Result<Bool, any Error>?
    package let reconciledFinalCONT: Bool
    package let causes: [CliProcessCleanupFailureV1.Cause]
    package let registryRetained: Bool
}

package enum CliProcessSpawnCleanupV1 {
    package static func runRegistered(
        executionId: String, processGroupID: Int32,
        processInspector: any EngineRuntimeProcessInspectingV1,
        reapTask: Task<CliProcessReapResult, Never>?,
        stdoutTask: Task<Bool, Never>?, stderrTask: Task<Bool, Never>?,
        registry: ShellProcessRegistry, diagnosticOwner: UUID
    ) async -> CliSpawnCleanupReportV1
}
```

The report's `reap`/EOF fields are populated only after the corresponding actual `.value` await; nil never means success. Signal attempts and ordered pre-join probes retain exact `Result` values, including provisionally reconciled errors, not error strings. The helper performs registry retirement, so tests exercise the production action rather than a duplicate predicate. The surrounding catch keeps descriptor closes, primary-error wrapping, and publication as they are.

- [ ] Extract the current registered branch into this helper without correcting its `causes.isEmpty || !groupStillLiveAfterFailure` join condition or ignored-result behavior. The existing signal routine may move with the extraction, retaining the unregistered caller's old behavior. Wire the actual catch to the helper immediately; a test-only copy is not acceptable.
- [ ] Add one no-child controlled inspector with an exact ordered script of `Result<Bool, Error>` probes and `Result<Void, Error>` signal sends. It rejects extra/misordered calls and uses only a synthetic group key in a private `ShellProcessRegistry`; it never calls Darwin, reads identity, or sends a signal. Use already-completing `Task` values for reap/drains, so even the wrong branch cannot leak a suspended worker. Join these same three tasks in the test epilogue before assertions regardless of the helper's observed join fields.
- [ ] Add the following exact test addresses. The success path below is the intended branch-defect RED; result-validation negatives expose the current ignored-result defect in the same helper. True-authority negatives protect against a broad GREEN shortcut.

| Test suffix after `p1f1_065SpawnCleanup` | Controlled inputs | Required result |
| --- | --- | --- |
| `ReconcilesCONTAfterOwnedJoins` | Initial live; KILL accepted; CONT `.processSignal(EPERM)`; both immediate probes `.processSignal(EPERM)`; post-join absent; reap status 137/failure nil; both EOF true | Three joined fields; final absence; exact CONT error remains in signal observations; reconciled true; causes empty; registry retired |
| `RetainsDeniedKILL` | Initial live; KILL `.processSignal(EPERM)`; CONT accepted; remaining immediate probes live | No helper joins; exact KILL cause; registry retained; no reconciliation |
| `RetainsDeniedKILLAfterDisappearance` | Initial live; KILL `.processSignal(EPERM)`; subsequent probes absent; CONT accepted; owned joins succeed | Exact KILL error remains a terminal cause despite later disappearance; no reconciliation; registry retained |
| `RetainsInitialProbeEPERM` | Initial probe `.processSignal(EPERM)` | No signals or helper joins; exact liveness error; registry retained |
| `RetainsLiveGroup` | Same accepted-KILL/CONT-EPERM sequence; post-join live | Three joins; exact CONT plus liveness causes; registry retained |
| `RetainsUnknownFinalGroup` | Same sequence; post-join `.processSignal(EPERM)` | Three joins; exact final liveness error; registry retained |
| `RetainsUnrelatedPreJoinFailure` (two parameters: non-EPERM and untyped) | Initial live; KILL accepted; CONT `.processSignal(EPERM)`; first immediate probe `.processSignal(EINVAL)` or fixed test sentinel, second probe live; all joins succeed and post-join absent | Exact unrelated probe error remains a terminal cause; CONT is not reconciled; registry retained. Never clear pre-join causes by phase alone |
| `RetainsReapFailure` | Initial live; KILL/CONT accepted; post-join absent; reap status nil/failure `controlled wait failure` | Three joins; `.reap` cause; registry retained |
| `RetainsInvalidReapResult` | Initial live; KILL/CONT accepted; post-join absent; reap status nil/failure nil | Three joins; explicit invalid reap-result cause; registry retained |
| `RetainsStdoutFailure` | Initial live; KILL/CONT accepted; valid reap; stdout false/stderr true; post-join absent | `.pipeDrain` cause carrying `.pipeDrainIncomplete("stdout did not reach EOF")`; registry retained |
| `RetainsStderrFailure` | Initial live; KILL/CONT accepted; valid reap; stdout true/stderr false; post-join absent | Corresponding `.pipeDrain` stderr cause; registry retained |
| `RetainsUntypedCONTFailure` | KILL accepted; CONT fixed test sentinel, immediate probes live, joins succeed and post-join absent | Sentinel remains exact; no reconciliation; registry retained |
| `RetainsNonEPERMCONTFailure` | KILL accepted; CONT `.processSignal(EINVAL)`, immediate probes live, joins succeed and post-join absent | EINVAL remains exact; no reconciliation; registry retained |

The test harness creates the concrete tasks as follows; use the same returned handles both in the actual helper call and its unconditional test epilogue:

```swift
let reapTask = Task { CliProcessReapResult(status: 137, failure: nil) }
let stdoutTask = Task { true }
let stderrTask = Task { true }
let report = await CliProcessSpawnCleanupV1.runRegistered(
    executionId: "no-child-spawn-cleanup", processGroupID: syntheticGroup,
    processInspector: inspector, reapTask: reapTask,
    stdoutTask: stdoutTask, stderrTask: stderrTask,
    registry: registry, diagnosticOwner: UUID()
)
_ = await reapTask.value
_ = await stdoutTask.value
_ = await stderrTask.value
// Print the actual report and consumed script before assertions.
#expect(report.reap?.status == 137)
#expect(report.stdoutEOF == true && report.stderrEOF == true)
#expect(report.reconciledFinalCONT)
#expect(report.causes.isEmpty)
#expect(!report.registryRetained && registry.activeCount == 0)
```

The synthetic group constant is a registry-only key and must never flow to a syscall. Negative tests use the table's exact values and assert exact underlying enum/sentinel values, not only nonempty causes. Add `.pipeDrain` to the existing cleanup phase enum; a failed EOF result is not a descriptor-close error. Missing-task inputs get explicit reap/pipe-drain errors and never enable retirement; cover all three nil task positions with one parameterized `p1f1_065SpawnCleanupRetainsMissingTask` no-child test, using accepted KILL/CONT and a final absent probe. Its nonmissing task handles are always joined in the test epilogue. Reap/drain negatives intentionally use accepted signals to expose the old ignored-result defect independently of the CONT race.

- [ ] Root captures `swift build --product RunTests` and `swift run --skip-build RunTests --filter 'p1f1_065SpawnCleanup'`, after source review and frozen entry. The test target has known pre-existing warnings; warnings-as-errors is not its admission command. Accept RED only when failures match the old skipped-join/ignored-result behavior, every scripted test returns with every created test-owned task joined, and no child or real descriptor was created. Freeze test bodies/script inputs and the complete output before GREEN.

## Task 2: Correct only the registered cleanup decision

**Consumes:** The actual helper, frozen controlled tests, and exact signal/error observations from Task 1. **Produces:** A checked report and cause-preserving production catch.

- [ ] Record KILL acceptance separately from CONT failure. Keep the existing signal order and immediate observations. A typed EPERM from final CONT and subsequent pre-join probes is provisional evidence, not absence. Initial-probe failures, real KILL authority failures, non-EPERM errors, and untyped authority errors are never eligible for this reconciliation. Explicit precedence: a KILL `.processSignal(EPERM)` remains unreconciled even if a later CONT is accepted or a later probe finds absence; GREEN must correct the old signal routine's immediate-absence discard for this registered branch. Preserve the existing benign typed ESRCH-on-already-absent contract; ESRCH is not an authority failure, but requires its existing positive absence evidence. Keep the unregistered caller's old projection byte-equivalent.
- [ ] Join the existing tasks if KILL was accepted, or if the existing signal phase positively observed absence. Otherwise retain the error/registry and do not start an indefinite join. Do not use final CONT success to excuse denied KILL.
- [ ] Await reap, stdout, and stderr even if an earlier joined result failed; collect each failure independently. Reap success requires `status != nil && failure == nil`; use the producer's existing status without reinterpretation. Require `stdoutEOF == true` and `stderrEOF == true`. Missing tasks are errors. Preserve failure strings only inside existing error objects, not public diagnostics.
- [ ] Probe group absence only after those awaits. Reconcile only the recorded final-CONT `.processSignal(EPERM)` and its specifically associated pre-join EPERM probe causes when all proof terms are true:

```swift
let joinsSucceeded = reap.map { $0.status != nil && $0.failure == nil } == true
    && stdoutEOF == true && stderrEOF == true
let absentAfterJoins: Bool
if case .success(false)? = finalGroupExists { absentAfterJoins = true }
else { absentAfterJoins = false }
let mayReconcileFinalCONT = killAccepted && joinsSucceeded && absentAfterJoins
    && finalCONTFailure == EngineRuntimeAuthorityErrorV1.processSignal(EPERM)
    && !hasUnrelatedCause
```

Implement the comparison by a typed cast/pattern match, never by reflected error text. Keep eligible causes in separately tagged slots until this decision; do not delete all signal/liveness causes by phase. Preserve the exact raw failure in `report.signals` even when reconciled. A successful final probe alone is insufficient. Genuine KILL EPERM, persistent/unknown group, failed joins, untyped errors, and other errno values all remain failed cleanup.
- [ ] Retire the registry only when all three joined results succeed, final absence is positive, and no unreconciled cause remains. The outer catch throws its original primary directly only when the full cause list, including later descriptor closes, is empty; otherwise retain `CliProcessCleanupFailureV1(primary: original, causes: allFailures)`.
- [ ] Emit bounded integer-only evidence through existing lifecycle diagnostics with the same backend `diagnosticOwner`. Add specific stages for cleanup signal number/errno, provisional probe errno, and reconciliation decision. Reuse the existing target/group and joined-result stages. Record accepted KILL, exact failing signal/errno, three join results, post-join absence, and reconciled/not-reconciled. Do not manufacture raw result/errno for an untyped thrown error; record a separate untyped-failure stage. No UUID-only signal trace disconnected from the cleanup owner, secrets, arbitrary error text, or always-on log framework.
- [ ] Root reruns the identical frozen helper filter and requires GREEN plus exact error provenance/registry outcomes. Independent review must verify the actual catch calls this helper, tasks are truly awaited, and no normal-finalize/unregistered policy changed.

## Task 3: Align the real inspector and explicitly amend only the new certificate

**Files:** Existing EEC inspector and newly added certificate; the backend's existing internal initializer may receive the narrow witness callback below. No new runtime process-inspection protocol.

- [ ] At both actual Darwin.kill failure sites in `P1F1D065ProcessInspector.send`, throw existing `EngineRuntimeAuthorityErrorV1.processSignal(errorNumber)` instead of erasing errno into `EngineContextValidationErrorV1`. Preserve its current benign ESRCH contract and the intentionally injected readiness/launch failure exactly. Apply this independently of diagnostics configuration.
- [ ] Make `P1F1D065ProcessInspector.processGroupExists` match the production inspector: result zero means true, ESRCH means false, and EPERM/other errno throws the typed `.processSignal(errorNumber)`. Retain the immediate copied errno observation. This is a reviewed contract correction, not a test-only claim that permission failure proves liveness.
- [ ] Add one nonthrowing, default no-op internal initializer callback, `spawnCleanupObserved: @Sendable (CliSpawnCleanupReportV1) -> Void = { _ in }`, propagated only to the execution and called once after `runRegistered` returns. It cannot change decisions and is not called under locks. Abort465 supplies a lock-protected single-slot recorder that records duplicate delivery as a test failure; the default production path allocates no recorder. This narrow witness is proposed specifically because accepting raw CONT EPERM without actual typed join evidence would weaken the certificate. It is an explicit review item, not an optional-cast observer protocol.
- [ ] Pass that report into `p1f1d065MakeAbortCertificate` and require matching execution/group, valid actual reap result, both EOF results, final group absence, empty causes, and registry retirement. Keep every current identity, readiness, publication, client/guard, PID/group/wait, no-intervention, resource, and original-primary assertion.
- [ ] Keep the current normal raw signal rule. Add exactly one exceptional classification: final CONT may have raw `result == -1 && errno == EPERM` only when initial CONT and KILL raw results are both zero, all three targets match the captured identity, signal order is unchanged, and the matched production report has `reconciledFinalCONT == true` with the complete checked proof above. The raw EPERM stays in the log and report. No other signal position/errno gets this allowance.
- [ ] Add no-child certificate classification tests with fixed value inputs: the full proof accepts; missing/mismatched report, denied KILL, arbitrary CONT error, failed reap, each non-EOF, live/unknown final group, any remaining cause, and intervention all reject. These test the exceptional classifier directly but do not replace Task 1's actual-helper RED/GREEN.
- [ ] Root obtains explicit independent approval of this certificate amendment before running abort465. Then root captures one isolated `swift run --skip-build RunTests --filter p1f1_065AbortBeforeRegistrationOwnsAllLifetime` under the existing exact-identity guard and regular-file log wrapper. Either the normal raw path or the precisely certified transient path may pass. Any failure retains its fresh root and calls the already-reviewed containment path before assertions. Do not reinterpret the old failed integration2 run as passing or delete its root.

## Final gates and stop rules

- [ ] Root and independent reviewer compare frozen old test bodies, signal order, deadlines, wait-status producer, unregistered cleanup, normal finalize, C fixture, and runner inventory against entry hashes/diffs. Resolve any mismatch before integration.
- [ ] After accepted isolated evidence, root runs the already-approved integration set, then the repository's authoritative complete `swift run RunTests`, `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`, and `git diff --check`, with unique complete captures and exact source/binary pins. The app product, not the RunTests product, is the strict-warning gate. A focused result is not full-suite completion.
- [ ] Record actual changed paths, RED/GREEN results, the precise certificate amendment, and unresolved limits in the task report. No release, commit, push, app replacement, or acceptance claim follows merely from the plan.

Stop on any unexpected helper failure, new failure class, unowned/hung task, guard intervention, unclear typed error, or unreviewed scope drift. Preserve evidence and report the one concrete blocker; do not add retries, broaden permission acceptance, or guess an exit status.
