# CLI cleanup provenance and retained ownership implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Root owns all builds and test processes; implementers do not commit or run workloads.

**Goal:** Preserve the real launch and cleanup causes, retain the identity of an uncertified fixture, and obtain discriminating evidence for the remaining startup-abort failure.

**Architecture:** Keep existing process ownership and cancellation ordering. Add a structured, safely rendered cleanup error and fixed numeric lifecycle stages at the current boundaries. First exercise the real failure path without spawning a process; prospective real-process entry is reviewed separately after source verification.

**Tech Stack:** Swift 6, macOS 14+, existing POSIX backend and Swift Testing RunTests runner.

**Spec:** `docs/collaboration/tasks/2026-09-05-desktop-coding-closure/spec.md`; prior RED and exact findings are in `runtime-help-oauth-forward-progress-result.md`.

## Global constraints

- Preserve the existing dirty checkout and branch `codex/runtime-forward-progress-20260908`, HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`. No commit, push, merge, installed App, real data, secrets, paid Provider, administrator action, or sampling.
- Only the three listed source files may change. No Package/C helper/runner/inventory/deadline change, global serialization, skipping or silent cleanup fallback.
- Source-review and runtime-review are independent gates. Historical abort465 remains uncertified; never infer its PID or signal a historical process. The missing historical identity does not prohibit independently contained fresh work.
- Full `swift run RunTests`, strict App build and product acceptance remain later gates; focused passing is not a substitute.

## Scope and entry

Root records preimages and a full source/script/package manifest before editing:

1. `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
2. `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`
3. `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`

The independent reviewer accepts the prospective-entry concept: retain old uncertainty, prefer no-child tests, and require new exact ownership and independent containment before a real child is introduced. This plan does not itself admit a new real-process run.

### Task 1: Preserve primary and cleanup causes at actual failure boundaries

**Interfaces:** Add package `CliProcessCleanupFailureV1: Error, Sendable, CustomStringConvertible` in the existing backend file. It contains `executionId: String`, optional `pid` and `processGroupID`, `primary: any Error`, and ordered `causes: [Cause]`; `Cause` has a fixed phase enum and `underlying: any Error`. Use checked Sendable when possible. Safe description renders only fixed phases, execution/PID/group and error type names, never arbitrary underlying descriptions or request values. No new public enum case is required.

- [ ] Stage only the error data declarations and write `p1f1_065CleanupFailurePreservesPrimaryAndAuthorityCause`; production construction sites remain unchanged for RED.
- [ ] The test uses the existing private 065 harness and injected CLI signature rejection. Capture a cleanup authority, move its original file to a different name inside the same unique fixture, create a replacement at the captured path, then consume actual `backend.launch`. Signature rejection occurs before spawning. Require the aggregate; require the exact injected `.cli` primary, exact cleanup-authority `.identityMismatch` cause, matching executionId and nil PID/group. Require registry zero, inspector snapshots/signals zero, socket absent and replacement bytes unchanged. Use checked fixture teardown. Do not treat compilation failure as RED.

```swift
let failure = try #require(terminalError as? CliProcessCleanupFailureV1)
#expect((failure.primary as? P1F1D065SignatureFixtureError) == .injected(.cli))
try #require(failure.causes.count == 1)
#expect(failure.causes[0].phase == .cleanupAuthority)
#expect((failure.causes[0].underlying as? CliCleanupFileErrorV1) == .identityMismatch)
```

- [ ] Root runs `swift build --product RunTests`, then `swift run --skip-build RunTests --filter p1f1_065CleanupFailurePreservesPrimaryAndAuthorityCause`. Expected RED: actual old terminal error cannot be cast to the aggregate; no child or signal was created. Freeze the test bytes and keep complete logs.

Entry-review requirements: verify and report all zero-effect/resource/replacement checks before the intended aggregate-cast RED, and run checked teardown even when that cast throws. When an outer cleanup error accompanies a nested spawn-cleanup aggregate, retain its original primary, PID/group and ordered causes; append rather than erase or replace those facts. Exact staged test/source review precedes the build/test command.
- [ ] After RED review, replace erasure in outer `run` catch: retain the primary, append exact Board-stop and cleanup-authority causes, and publish the aggregate only if cleanup failed. Preserve the original error exactly when cleanup succeeds. `removeCleanupFiles` must retain the actual authority error with the fixed phase; it must not merely replace it with another generic string.
- [ ] In spawn catch, preserve exact primary and all encountered signal/liveness/descriptor errors in ordered causes, with PID/group. Keep current signal order, join placement and registry rules. Record joined reap/drain outcomes for diagnosis; do not yet change their success decision or wait-status interpretation. That behavior repair requires evidence and its own regression, rather than being mixed into provenance.
- [ ] Add fixed opt-in lifecycle stages for cleanup entry, wait raw status/errno, reap and drain join results, liveness absent/live/error, registry retained/unregistered and cause count. Use the existing owner UUID; no arbitrary strings. Test-side actual kill observations retain exact errno without expanding the production inspector protocol.
- [ ] Root reviews the changed delta, rebuilds and reruns the identical no-child regression for GREEN. Independent task review assesses both spec and quality, including no secret-bearing error descriptions. No process test has been admitted by this step.

### Task 2: Retain abort fixture identity and prepare a contained observation

- [ ] In the existing abort465 test, record unique fixture UUID, execution ID and exact root before launch; configure the existing inspector's diagnostic identity. Log actual PID/PGID, signal result/errno and liveness observation at the relevant boundary, not only after an assertion.
- [ ] Capture actual direct-child kernel identity before the first SIGCONT failure boundary (PID, parent PID, UID, PGID, start time and executable path/authority). The fixture mode has no descendants. If identity cannot be established, fail closed and retain the fixture.
- [ ] Replace unconditional abort fixture removal with a checked teardown guard. It remains false from launch until the joined stream/cancellation and exact resource observations certify cleanup. Retain root and identity on any uncertain cleanup; no `try?` removal in this path. All original signal, ordering, polling budget and error assertions remain.
- [ ] Add a narrowly scoped independent containment owner in test utilities if needed: it may signal only a freshly recorded child whose kernel identity and parent/PGID still match; it must not steal the backend's reap ownership, and any emergency intervention is a test failure, never passing cleanup evidence. Exact code and workload must receive independent review before any real-process execution.
- [ ] Root packages the source delta, no-child RED/GREEN and proposed one-test workload for independent entry review. If approved, run one discriminating 065 test with complete stdout/stderr plus its fixed numeric lifecycle evidence and fresh identities. Interpret it before further changes. This is not permission for an unchanged integration/full retry.

## Completion and next step

This unit succeeds when error provenance and retention have meaningful regression evidence and independent review, and the prospective observation (if admitted) identifies its own cleanup outcome without losing ownership. It does not claim the old cleanup/readiness defects are solved. Any observed underlying defect becomes a bounded source-grounded repair with regression before full integration. Root records results in the current task directory and continues within the user's existing implementation authority; only genuinely missing authority or a path requiring guesses goes back to the user.
