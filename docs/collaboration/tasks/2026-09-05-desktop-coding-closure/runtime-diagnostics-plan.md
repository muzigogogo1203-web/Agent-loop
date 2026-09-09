# Runtime Queue Diagnosis Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the scoped instrumentation task. Parent owns the single diagnostic run and independent review; continue into a separate evidence-selected repair afterward. No commits.

**Goal:** Distinguish delayed worker start from a blocked running owner at the observed Board/probe/CLI cleanup boundaries.

**Architecture:** Add an opt-in, fixed-schema OSLog lifecycle diagnostic sink. Observe existing scheduling without changing queues, deadlines, ownership or error behavior. Monotonic timestamps distinguish enqueue/start/finish; no diagnostic callback runs on the queue under investigation.

**Tech Stack:** Swift 6, Foundation, existing `os.Logger`, macOS unified logging.

**Spec:** This directory's `spec.md`. Sample evidence: `runtime-before.log`, `runtime-sample-early.txt`, `runtime-sample-later.txt`. Sampling showed a cooperative worker blocked in Board stop/acceptGroup.wait, but no running utility accept/drain workers; it did not prove the original global-pool-capacity hypothesis. The sampled run had seven issues and perturbation is explicit.

## Global Constraints

- No scheduling, timeout, serialization, FD ownership, result, error handling, provider, database or authority changes.
- Diagnostics disabled unless `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`; logging contains only a closed stage enum, random per-owner UUID, monotonic uptime nanoseconds, and integer state/count. No command, environment contents, token, path, source or user text.
- OSLog subsystem `com.muzi.agentloop`, category `runtime-lifecycle`; `.notice` events. No stderr/stdout writes that could corrupt CLI protocols, no arbitrary observer closures, no new actor/queue/thread/lock.
- Core source edits wait until strict-build cleanup releases its overlapping Orchestrator file. Worker cannot run builds/tests concurrently with another owner.
- This is diagnostic instrumentation for root-cause work, not a behavior fix. Existing failing tests are the target; do not fabricate a new test asserting logger text or Swift standard-library mechanics. Compile-check and one opt-in focused test confirm instrumentation before one default-parallel diagnostic run.

### Task 1: Add opt-in lifecycle evidence

Create `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` with:

```swift
import Dispatch
import Foundation
import os

package enum RuntimeLifecycleStage: String, Sendable {
    case boardAcceptQueued, boardAcceptStarted, boardAcceptFinished
    case boardConnectionAccepted, boardHandlerQueued, boardHandlerStarted, boardHandlerFinished
    case boardStopStarted, boardAcceptJoined, boardHandlersJoined
    case drainQueued, drainStarted, drainEOF, drainFinished
    case drainJoinStarted, drainJoinCompleted, drainJoinTimedOut
    case probeCompositionStarted, probeCompositionCompleted
    case cliFinalizeStarted, cliStdinFinished, cliReaped, cliStdoutFinished, cliStderrFinished
    case cliServerStopStarted, cliServerStopFinished, cliFinalizeFinished
}

package enum RuntimeLifecycleDiagnostics {
    private static let enabled = ProcessInfo.processInfo.environment[
        "AGENTLOOP_RUNTIME_DIAGNOSTICS"
    ] == "1"
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop", category: "runtime-lifecycle"
    )

    package static func event(
        _ stage: RuntimeLifecycleStage, owner: UUID, value: Int = 0
    ) {
        guard enabled else { return }
        logger.notice("stage=\(stage.rawValue, privacy: .public) owner=\(owner.uuidString, privacy: .public) mono=\(DispatchTime.now().uptimeNanoseconds, privacy: .public) value=\(value, privacy: .public)")
    }
}
```

Modify only these boundaries:

1. `Loop/BoardToolServer.swift`: per-instance private `diagnosticId = UUID()`; record accept queued before dispatch, true callback entry and deferred completion. Capture UUID into an immutable local and into the closure; callback-start must not depend on `self?`, even if weak self is gone. Preserve weak-self capture and group.leave ordering. Record successful accept and handler queued/true-start/deferred-finish with no token/fd/path logging. Record stop entry, acceptGroup.wait return and handlerGroup.wait return. These events do not alter stop's behavior.
2. `Kernel/Orchestrator.swift`, `EngineManagedProbeLiveDrainV1` only: per-instance random UUID; queued versus actual utility closure start, EOF and deferred worker completion. For these four worker events, `value` is always stdout=0/stderr=1 so the two workers can be paired. Finish's existing join closure logs start and success/timeout; join-event `value` is attempt1/2 based on existing retry boolean. Existing one-second wait and worker counts unchanged. Capture UUID value into worker closure; no additional self retention.
3. `Loop/CliProcessBackend.swift`, `CliProcessExecution` owner only: per-instance UUID; finalize start and completion after stdin/reap/stdout/stderr. Log `cliStdinFinished` immediately after its await succeeds (value0), or on entry to its catch (value1), preserving existing error handling. Log `cliServerStopFinished` in both success(value0) and catch(value1). Record finalize exit in defer with a success flag set only after successful evidence construction, so throws are not mistaken for blocked work. These observed-await completion times are NOT claims of the OS's actual reap/EOF timestamp. Keep all errors and cleanup sequence intact. Other numeric values may report EOF as0/1; never a diagnostic string derived from error/user data.
4. `Sources/AgentLoopTestSuite/CliBackendTests.swift`, `p1f1d075AssertR9DCompositionContract` only: random test UUID; before/after each of its ten existing composition calls, fixed stages `.probeCompositionStarted/.probeCompositionCompleted` and integer indices0...9. Do not change assertions, wrappers, timeout or failure handling.

- [ ] Parent captures pre-change copies after strict-build cleanup.
- [ ] Worker applies scoped diagnostic changes, checks exact diff and formatting, records touched paths.
- [ ] Parent builds with normal test command and runs one exact075 filter with diagnostics enabled; inspect returned OSLog entries using subsystem/category and actual PID. If no events, diagnose logging configuration once before a full run; don't run an unobservable repeated experiment.
- [ ] Parent runs one opt-in default-parallel suite, saves full stdout/stderr and retrieves OSLog events for that exact parent RunTests PID plus launch-time window (exclude075 child RunTests events from parent analysis). No additional samples required; the earlier two samples are sufficient context.
- [ ] Independently analyze queue latency and finalize stage timestamps, select causal repair. If events falsify latency hypothesis, follow the exact stalled active owner. Record what was observed and not proven. Continue to repair, not another audit handoff.

Independent plan review: approved after incorporating stream identity, throw-path exit events, weak-self-independent callback events, PID/time-window extraction and observed-vs-OS timestamps (baseline_process_audit). No further planning review required for this fixed instrumentation scope.
