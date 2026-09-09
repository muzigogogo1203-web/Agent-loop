# 069 coroutine partition preflight review

Decision: **APPROVE the exact 21-group plan for implementation.** No blocking cross-boundary reference, callback ownership, resource lifetime, or control-flow finding was identified. This is approval of the proposed source partition, not approval of an implemented diff or runtime acceptance.

Reviewed `AGENTS.md`, `runtime-coro-split-plan.md`, `runtime-cold-compiler-checkpoint.md`, the complete original 069 test, the relevant existing scenario helpers and fixture destructor, and `runtime-cold-compiler-source-analysis.md`. Independently verified the frozen preimage SHA-256 as `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`. All ranges below refer to that preimage.

## Boundary findings

Every selected range is a complete statement sequence with its own local inputs. None requires an argument from another selected group or from the retained caller, and none supplies a local used by a later group. Existing file-level factories, constants, fixtures, and helpers remain accessible to file-private zero-argument `async throws` functions. No selected statement relies on the suite instance.

| Group / preimage range | Ownership and completion at the proposed boundary |
| --- | --- |
| Routing winners / 6546–6676 | Initial sink submission is awaited. The complete permutation loop retains its polling, assertions, database observations, and per-iteration root defer. Its fixture scope was already the loop iteration; extraction does not move that cleanup boundary. |
| Active cancellation registry / 6678–6890 | Pending registration/cancel, both failing cleanup waiters, retry/removal, and canceled start-gate task all retain their waits and final observations. |
| Shared adapter cleanup / 6892–7034 | Both cancellation callers and the stream consumer are awaited for each adapter after construction/cleanup gates are released. |
| Model claim handoff / 7036–7168 | Both handoff consumers, old atomic claim, original atomic consumer, and reuse consumer remain joined; claim wait/acknowledgment remains in the group. Lifecycle-recording task caveat is addressed below. |
| CLI handoff and immediate winners / 7170–7300 | Both stubborn CLI consumers and termination waits remain. The complete finished/failed loop preserves both model claim waits/acknowledgments, consumer join, and existing immediate-CLI helper call. |
| Prelaunch and quarantine / 7302–7446 | Both sets of cancellation claims are waited and acknowledged, all blocking gates are released, consumers are awaited, and final quarantine reuse is consumed before return. |
| Generation-bound cleanup / 7448–7542 | Existing `p1f1d069ExerciseGenerationBoundCancellation` waits both consumers and all claims and acknowledges them; each model/CLI invocation remains awaited before its final assertions. |
| Completion registry / 7544–7661 | Both resolution tasks remain awaited; lifecycle publication/consumption, authorized removal, completion delivery, and negative duplicate-removal check remain together. |
| Dispatch admission / 7663–7808 | Both duplicate execute tasks are joined after the bind gate release. Pre-begin task cancellation, gate release, expected error join, and unchanged-database check stay together. Incomplete-handle negative case starts no waiter. |
| Begin registration latch / 7810–7937 | Sleeping bound callback, command gate, observer gate, cancel task, execute task, and final empty registries stay together; both named tasks are awaited. |
| Settled primary retry / 7939–8131 | Trigger/function, primary/external callers, observer barrier, both joins, trigger removal, awaited retry, and terminal observations remain one group. |
| Post-gate and bind cancellation / 8133–8299 | Post-gate cleanup is released and cancel/execute joined before assertions. The complete cancel/throw bind loop retains its own per-iteration root defer and awaited callbacks/execute outcomes. |
| Observer and finalizer failure / 8301–8451 | Awaited routed execution retains all observer/database checks. Finalizer task is awaited after releasing its observer, including the expected failure and final state checks. Callback-local guard return remains inside the callback. |
| Completion removal barriers / 8453–8605 | Success and failure each retain coordinator-task and raw-receipt-waiter joins. The final failed registry count of one is intentional retained failure evidence; it is not an unjoined task. No cleanup should be added. |
| Observer Store failure / 8607–8648 | Store fault installation, awaited execution failure, existing catch, and observer-count assertion stay together. No new background task is introduced by extraction. |
| Exact live CLI / 8688–8823 | Entire false/true loop stays intact. Cleanup release and both cancel/execute joins precede the existing guard/continue. Sibling observations and final registry checks remain within the iteration. |
| Mission CLI recovery / 8936–9042 | Entire false/true loop remains; recovery is awaited before all terminal/sibling checks. Resolver guard still throws only from its closure. |
| Mission model recovery / 9045–9145 | Entire false/true loop remains; recovery is awaited before all terminal/sibling checks. |
| Shared recovery owner / 9148–9221 | Cleanup probe release and both recovery-task joins precede final shared-result and registry observations. |
| Recovery failure retry / 9224–9333 | Entire transport/evidence/store loop stays intact, including query-only reset, failure disarm, awaited retry, and registry checks. Store-failure callback guard return remains callback-local. |
| Shared recovery action matrix / 9336–9558 | Entire allCases loop retains both racing attempts and joins, trigger drop, active blocker removal, awaited retry, and final state checks. No fault/cleanup state crosses the proposed boundary. |

## Resource and callback qualifications

`P1F1DCanonicalExecutionFixture.deinit` removes its root (`EngineExecutionStoreTests.swift:1633–1635`). This review applies the parent's explicit ruling that completed independent scenarios may release their fixtures at helper return. The proposed helper returns are after the original scenario joins and final observations. No later scenario uses any earlier fixture, registry, database function, request, ledger, or callback.

The source does contain unstructured tasks that must not be described as universally joined:

- The model-handoff, atomic-model, and stubborn-CLI lifecycle observers spawn `Task { await lifecycleProbe.record(event) }`. These tasks capture their probe and event strongly; the probe's `record` only appends the event and resumes its own waiters. They capture no canonical fixture/root/database and provide no data to another group. The adapters, consumers, claim waits, lifecycle waits, and final assertions are retained. A delayed record task can retain its own probe after helper return without losing a resource required by that task. This is not a blocking fixture-lifetime dependency.
- `P1F1DWiringAdapter.execute` creates three unstructured submission tasks. Their existing outcome polling and assertions stay in the same complete permutation loop. Their fixture and explicit root cleanup already occurred at the loop boundary in the original test; extraction does not newly shorten that scope. No join or timeout should be invented as part of this mechanical refactor.

Error paths remain unchanged: a throwing helper immediately unwinds the caller through `try await`; existing expected-error catches and `Issue.record` behavior remain exactly as written. This review does not assert successful-path joins occur after an unexpected earlier throw, nor authorize new catches or cleanup to conceal that condition.

## Control flow and unchanged scope

The terminal-winner, exact-live-model, and final unknown-outcome guards stay directly in the original test. Their `return` therefore still exits the whole test. The exact-live-CLI `continue` stays inside the same complete loop. Returns inside task/result and observer/resolver closures retain their original lexical target. All loops retain original order, bounds, enum inputs, callbacks, claims, waits, and defers.

The one registered 069 test and serialized suite remain. Stage-print positions around helper calls and case prints inside complete loops are preserved by the proposed ranges. The plan admits no changes to either 065 test, production source, runtime timeouts, compiler settings, or assertions.

The compiler checkpoint supplies a measured reason for this test-only partition: 069 has 216,814 pre-split IR body lines and 747 suspension sites; a separate bounded probe identifies its actual CoroSplit entry. The earlier 24.1 GB sample is not retrospectively claimed to contain that Swift symbol. No compiler, tests, sampling, process operations, or source edits were performed in this review.

Implementation must still satisfy the plan's exact expansion-to-preimage check, assertion/test/marker inventory, unchanged 065 bytes, independent actual-diff review, measured IR reduction, and normal focused runtime execution. Full-suite and later product gates remain unresolved.
