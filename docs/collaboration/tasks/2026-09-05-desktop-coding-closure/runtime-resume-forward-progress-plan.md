# Resume and controlled-wait forward progress implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Root owns build/test execution; no implementer workloads or commits.

**Goal:** Remove proven synchronous waits from the cooperative executor without changing signal, cancellation, or test ordering.

**Architecture:** Await a retained BlockingProcessOperation at the actual synchronous boundary. Use strict-pool, no-descendant regressions with real pipes/gates/sockets and an external release controller; do not mask failures with deadlines or serialized suites.

**Tech Stack:** Swift 6, existing POSIX/NSCondition/Testing infrastructure.

**Spec:** desktop-coding-closure/spec.md; source findings recorded in runtime-cleanup-provenance-review.md.

## Global constraints

- Keep the current dirty codex branch and all earlier provenance changes; capture new preimages only after that writer releases ownership. No commit/push/App/real-data/secrets/admin/sampling/paid Provider action.
- Three source paths: CliProcessBackend.swift, BlockingProcessOperationTests.swift, ExecutionEngineConformanceTests.swift, at their existing Sources locations. One sequential writer at a time; no mutation while root compiles/runs.
- Original 065 3000x1ms poll budget, signal order, cancellation and cleanup publication ordering, readiness deadlines and assertions remain unchanged. No real-child strict-pool test, global serialization, skip, or deadline inflation.
- Existing source inventory and C fixture/Package/runner stay unchanged. Existing generic/help bridge tests remain behaviorally identical if a small shared test-controller extraction is needed.

### Task 1: Actual resume dispatch boundary

**Files:** `Sources/AgentLoopCore/Loop/CliProcessBackend.swift` and `Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift`.

- [ ] Stage a package production helper and route only the existing initial SIGCONT call through it, preserving surrounding diagnostics and arguments. Pre-RED implementation remains synchronous:

```swift
package enum CliProcessSignalOperationV1 {
    package static func send(signal: Int32, processGroupId: Int32,
                             using inspector: any EngineRuntimeProcessInspectingV1) async throws {
        try inspector.send(signal: signal, processGroupId: processGroupId)
    }
}
```

- [ ] Add `cliResumeSignalPreservesCooperativeProgress`. Its selected strict-pool child calls this actual helper with an inspector that records exactly one SIGCONT and literal group31415, blocks on a real owned pipe and then throws an exact sentinel. It must never call Darwin.kill, spawn descendants, or execute the fake group ID. Unexpected inspector snapshots/liveness calls throw immediately.
- [ ] The existing real-pipe controller pattern queues and retains a sibling task at operation entry. It releases the pipe after progress or its recorded1s rescue; entry deadline remains5s. Cancel the awaiting task and require actual sentinel completion, exact invocation arguments, byte/FD outcomes, controller and sibling joins, then require no rescue. All joins precede throwing assertions and success evidence. Reuse existing state/descriptor/controller utilities; any extraction preserves the original generic/help tests' checks and outcomes.
- [ ] After staged-source review, root builds and runs only the new no-descendant regression. RED must be the no-rescue/forward-progress expectation, not a compile failure or resource leak. Freeze the regression before GREEN.
- [ ] Replace only helper body with:

```swift
let operation = BlockingProcessOperation.start {
    Result<Void, any Error> {
        try inspector.send(signal: signal, processGroupId: processGroupId)
    }
}
try await operation.value.get()
```

- [ ] Root rebuilds and runs the same regression plus original generic/help tests. Independent spec/quality/evidence review before acceptance. This proves that the synchronous callback no longer pins a cooperative worker, not that every historical timing failure had that cause.

### Task 2: Controlled 065 progress gate and result-reader boundaries

**File:** `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`; may consume a shared internal test-controller helper from BlockingProcessOperationTests.swift only if Task1 creates one and its exact contract is reviewed.

- [ ] Add a private async throwing wrapper `p1f1d065AwaitSynchronousBoundary<Value: Sendable>(_: @escaping @Sendable () throws -> Value) async throws -> Value`; stage it inline for RED. Route P1F1D065BlockingProgressSink.submit's actual gate wait and the resultReader's full readLine-until-EOF body through it. Keep the original gate/read bodies and resultReader defer/completion location.
- [ ] Add one selected no-descendant strict-pool test `p1f1_065ControlledWaitsPreserveCooperativeProgress`. It exercises the real P1F1D065SynchronousGate wait used by submit and a real socketpair read/EOF body through the actual wrapper. Entry and release are explicit; external native controller queues/retains a sibling, rescue-releases after1s only if no progress, and closes/writes the owned socket. Assert exact bytes and EOF, one gate entry/release, no rescue, cancellation does not abandon completion, all controllers/tasks/FDs joined. No assertions on a separate mock of the wrapper.

Entry-review clarification: the gate case calls actual P1F1D065BlockingProgressSink.submit; the socket case calls the same extracted read operation used by resultReader. Both cases finish and release all resources before either no-rescue assertion can abort the combined test, so RED observes both. The controller owns only the peer socket and may write/close that peer; it never closes the descriptor being used by the reader. A private owned-descriptor initializer on the test-only socket client is allowed to connect the real socketpair to the existing readLine implementation; no product test-only method.
- [ ] Independently review staged code; root builds/runs this new no-descendant regression for meaningful RED. Preserve original publication assertions and all test budgets.
- [ ] Change only wrapper placement:

```swift
try await BlockingProcessOperation.start { Result { try operation() } }.value.get()
```

- [ ] Root runs identical regression for GREEN. Review both real boundary routing and evidence. No real065 workload until the separate abort-containment source/entry gate is met.

## Integration

After both fixes and provenance/containment independent gates pass, use one reviewed focused lifecycle run to check actual held-pipe/readiness/abort contracts. CLI152's distinct phase-oracle amendment is separately reviewed; it is not hidden inside these source changes. A remaining failure must be interpreted using fresh lifecycle evidence before any retry. Only then admit ordinary unfiltered swift run RunTests and strict App build; later package/UI/user acceptance remain separate.
