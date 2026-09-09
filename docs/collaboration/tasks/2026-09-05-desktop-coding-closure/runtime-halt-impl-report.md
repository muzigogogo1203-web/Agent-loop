# Halt diagnostics implementation report

## Scope and status

Implemented the full approved 84-line `runtime-halt-diagnostics-plan.md` (SHA-256 `5f4671171ea26de32fcc4b8c8a584781e0bc04567189feee3a08bff485fe4d98`) and `runtime-halt-plan-review.md` clarifications in exactly the three authorized source files. The executing-plans workflow was used for this already-approved bounded assignment; parent retains independent review and all runtime verification.

This is instrumentation only, not a halt behavior fix or a cleared runtime gate. No build, test, OS-log extraction, App/Provider launch, process signal, new agent, commit or push was performed. No assertion, timeout, sleep, task ordering, cancellation, error propagation or actor state decision was changed.

## Exact incremental diff

Compared with the fresh post-CLI-signal snapshots in `runtime-halt-before/`:

| Source | Insertions / deletions | Change |
| --- | --- | --- |
| `RuntimeLifecycleDiagnostics.swift` | +18 / -0 | Append 51 fixed halt stages; existing stages, signal helpers, environment gate and logger format unchanged. |
| `Orchestrator.swift` | +102 / -2 | Immutable diagnostic owner, validated execution-owner helper, existing cancellation-chain boundaries, existing running-snapshot identity joins and emergency-stop boundaries. |
| `HaltAndCooldownTests.swift` | +112 / -7 | Optional fixture identities defaulting to nil; target-only correlation read and markers; actual provider termination/catch/counter and existing gate/deadline markers. |

The replaced lines are the existing Task/closure expressions and fixture constructors expanded for diagnostic value captures, not additional tasks or asynchronous seams. A private synchronous test helper ensures the opt-in identity query uses GRDB's synchronous `read` overload without adding an await.

## Stage owners and callers

All events retain the existing `stage / owner / mono / value` format and `AGENTLOOP_RUNTIME_DIAGNOSTICS=1` gate. Unless noted below, numeric value is zero.

| Owner and existing caller | Stages |
| --- | --- |
| `Orchestrator.haltDiagnosticId`, `emergencyStop` | `haltStopEntered`; `haltSuppressCalled/Returned`; `haltTransitionPublished`; `haltPersistenceCalled/Returned/Failed`; `haltRunningSnapshot`; `haltRuntimeResolved/ResolveFailed`; `haltPlanningCleanupCalled/Returned`; `haltStopReachedEnd`. |
| Actual canonical execution UUID, `emergencyStop` runtime-cancel loop | `haltRuntimeCancelCalled/Returned/Failed`. |
| Actual canonical execution UUID, `EngineExecutionRuntimeV1.cancel` | `haltRuntimeEntered` after existing validation; `haltProfileReadCalled/Returned`; `haltCompositionCalled/Returned`; `haltCoordinatorCalled/Returned`. |
| Actual canonical execution UUID, coordinator `resolveCancellation` | `haltCancellationPersistenceCalled/Returned`; `haltActiveCancelCalled/Returned`. |
| Actual canonical execution UUID, active registry `cancelLiveExecution` | `haltActiveTaskQueued/Started`, before/inside the same existing Task. Both use the already assigned attempt; immutable execution-ID and attempt copies enter the closure. |
| Actual canonical execution UUID, coordinator's registered `cancelAndAwait` closure | `haltConsumptionCancelCalled`; `haltConsumptionJoined`. Capture only the execution-ID value for new logging, not the request or actor. |
| Existing `entry.generationID`, emergency-stop entry loops | `haltEntryTaskCancelCalled`; `haltEntryTaskJoinCalled/Returned`; `haltEntryUnbound` for a snapshot entry without an execution ID. |
| Orchestrator diagnostic UUID, target test only | `haltFixtureIdentityMissing`; `haltFixtureStopQueued/StopTaskStarted`; `haltFixtureHaltedObserved`; `haltFixtureCancelObserveQueued/Returned`; `haltFixtureGateOpenQueued`; `haltFixtureStopJoined`. |
| Optional hanging-provider UUID | `haltProviderTermination`; `haltProviderTaskCancelReturned`; `haltProviderCancellationCaught`; `haltProviderCancellationRecorded`; `haltProviderWaitStarted/Ended`. |
| Optional gate UUID | `haltPlannerGateEntered`; `haltPlannerGateOpened`. |

Nonzero/value-bearing events:

- `haltPersistenceFailed`, `haltRuntimeResolveFailed`, `haltRuntimeCancelFailed`: 1 in the existing catches, retaining the original errors and propagation.
- `haltRunningSnapshot`: existing snapshot count.
- `haltStopReachedEnd`: 0 if `firstError == nil`, otherwise 1; emitted before the existing throw check, never for earlier returns.
- `haltActiveTaskQueued/Started`: existing integer attempt, with no new attempt counter.
- `haltFixtureCancelObserveReturned`, `haltProviderWaitEnded`: actual Bool mapped to 1/0.
- `haltProviderTermination`: 0 for actual `.cancelled`, 1 for actual `.finished`, never associated error text. Pattern matching avoids inventing a code for any future unknown case of the SDK's non-frozen enum. Existing unconditional `task.cancel()` still follows.
- `haltProviderCancellationRecorded`: actual actor-isolated cancellation count immediately after its existing increment.
- `haltFixtureIdentityMissing`: 1 = diagnostic read threw; 2 = no matching execution; 3 = multiple matching executions; 4 = noncanonical/invalid execution UUID. These are observation gaps, not test results or replacement identities.

## Identity and privacy contract

Orchestrator owns a new immutable `package nonisolated let haltDiagnosticId = UUID()`, independent of transition state. The execution helper checks the existing canonical representation (`UUID.uuidString == executionId`, uppercase), only when diagnostics are enabled. It never repairs an identity, logs an invalid raw string or throws a new execution error. Existing runtime validation remains authoritative.

After the target's original `await gate.waitUntilEntered()` and before its original stopping Task, the synchronous helper selects only `engine_execution.id` for the exact `runningIds.cardId`, `state = 'running'` and `redactedAt IS NULL`. Exactly one canonical ID yields:

`haltFixtureIdentity test=emergencyStopCancelsRunningBeforeWaitingForPlanner orchestrator=<UUID> execution=<UUID> provider=<UUID> gate=<UUID>`

Read failure or missing/ambiguous/invalid identity emits only the fixed code above and returns from the diagnostic helper, not from the test. The original test then continues unchanged. The helper performs no DB read or print when disabled.

The existing emergency-stop snapshot supplies the second join:

`haltEntryIdentity orchestrator=<UUID> generation=<UUID> execution=<UUID>`

This print is gated and includes only canonical UUIDs. An entry without an execution ID emits `haltEntryUnbound` instead. No card/mission identity, SQL result payload, provider text, reason, model, path, credential or error string was added to output. Only the target test supplies provider/gate UUIDs; all other callers retain the nil defaults and produce no new fixture output even when global diagnostics are enabled.

## Static checks and preserved behavior

Read the complete incremental diffs against all three fresh preimages; `git diff --no-index --check` produced no whitespace diagnostics (status 1 represents the expected file differences). Read the local GRDB synchronous read signature, actual execution-record columns, canonical UUID validator and local SDK termination cases.

Lexical pre/post counts provide a supplemental, non-runtime check:

| File | `await` | `Task {` | `.cancel()` | `try?` | `#expect(` |
| --- | --- | --- | --- | --- | --- |
| Orchestrator, before = after | 284 | 14 | 18 | 8 | 0 |
| Halt tests, before = after | 279 | 12 | 2 | 2 | 259 |

The original one-second provider observer, 10 ms polling sleep, `isHalted` yield loop, gate release after the unchanged counter assertion, stopping-task join, card/run/mission/event assertions and shutdown remain in place. Provider counter mutation remains actor-isolated. Existing task cancellation is unconditional and the original catches/returns remain authoritative. Diagnostic value captures do not retain any actor solely for logging.

Board and CLI test sources remain at the prior released hashes (`87b370af…` and `7e1ef3fb…`). The prior CLI signal instrumentation is retained in the logger and registry; no source outside the three-file scope was edited.

## Frozen source hashes

| File | Preimage SHA-256 | Postimage SHA-256 |
| --- | --- | --- |
| `RuntimeLifecycleDiagnostics.swift` | `a79a0fd1572c9b8934fcce36a3527ded89f0d3bfe81a63c1447e93bb25ba293a` | `4f9f718fac10e69e572aa5934b64e6fc06eb365c5bd61768139f2f1453f39b53` |
| `Orchestrator.swift` | `515db34be2fe282497d6cbf44d300efa51de49d85c862368c2dce4ba52abce68` | `e48f86308cac6e2f9b177d36034145444a43e61efeb5b1de83c0b7440a6da60f` |
| `HaltAndCooldownTests.swift` | `67e978a33c9039edcebd183fcd815a350f011c22aba304cfe78373e930e8c55a` | `ddaa4f0aa733aa2757276cde5013fcdf967c5db4576b3719188e1b2b5ce2cbbf` |

## Pending parent verification and release

Compilation, independent source review, one focused diagnostic integration check and the separately gated combined full observation remain pending parent execution. No passing or acceptance claim is made here. Missing owner mappings make an observation incomplete even if the functional test passes; missing success markers must not be classified as a particular failure without evidence.

The uninstrumented ModelLoopEngineAdapter/CardRunner/inner AgentLoop interval between consumption cancellation and provider termination remains an explicit potential measurement gap. The new outer markers do not attribute that interval to any nested task or authorize scheduling changes.

**Source-writer ownership is released for all three authorized files.** No further source edits will be made without a new parent assignment.
