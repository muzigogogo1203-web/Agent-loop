# Cold compiler source attribution and 069 partition map

2026-09-06. Source analysis was read-only: no compiler, tests, sample, LLDB, process signals, source edits or agents. The only authored file is this report. Parent owns all builds and diagnostic processes. Full runtime acceptance remains **RED**; diagnostic IR emission is not object compilation or runtime success.

## Confirmed attribution and frozen comparison

Current `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift` SHA-256 is `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`; original `runtime-cold-gate-cleanup-before/ExecutionEngineConformanceTests.swift` SHA-256 is `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f`. Both were independently checked; the current hash was rechecked after analysis.

The original `runtime-cold-compiler-sample.log:24–42` places all 294 main-thread samples in LLVM CoroSplit after Sema/SILGen, including 253 in CoroCloner creation. The associated memory summary attributes 18.3 GB physical footprint, 17.2 GB swapped writable memory and 124,239,755 allocator entries to frontend 46564; the later sample reports 24.1 GB footprint. These are frontend costs, not test-process memory. The sample by itself does not name a Swift function or prove a complexity class.

The parent's pre-LLVM diagnostic completed with exit 0 in 18.05 seconds, with disk headroom stable. This worker independently inspected the emitted `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-cold-irgen.20260906-47668-13sh61z/ExecutionEngineConformanceTests.ll`:

- Symbol: `$s18AgentLoopTestSuite31ExecutionEngineConformanceTestsV38p1f1_069BoardTerminalExactlyOnceMatrixyyYaKF`.
- IR lines 145927–362742 contain **216,814 body lines and 747 async suspend call sites** (216,816 lines including definition and closing brace).
- The parent's smaller-function measurements are original 065 = 11,205 body lines / 64 suspend sites; forced 065 = 1,917 / 3; forced async body = 856 / 4; detached cleanup = 837 / 7. This worker independently verified 069, not every smaller measurement.

The parent's second bounded probe now supplies the missing function/pass boundary. This worker independently checked `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-cold-irgen.20260906-48350-f3jhdm/frontend.log:9`:

> IR Dump Before CoroSplitPass on ($s18AgentLoopTestSuite31ExecutionEngineConformanceTestsV38p1f1_069BoardTerminalExactlyOnceMatrixyyYaKF)

The definition begins at log line 11. Parent reports stopping its exact owned frontend after 20.32 seconds before substantial cloning; zero tests ran. This identifies 069 at the CoroSplit boundary in the bounded reproduction. It does not retroactively read the function name from the earlier sample or prove an LLVM algorithm defect, but together with the dominant pre-split IR it supports a focused 069 coroutine-size intervention.

The entire 069 source is **byte-identical to the pre-cold-cleanup version**: current 6545–9591 versus original 6122–9168, including the following blank line; 132,128 bytes, SHA-256 `5d774fbec1816ed19d760e7ddc4114381b95b7f2d9309e6088f35120428ae94e`. It contains 446 lexical `await` tokens, 438 `#expect` and five `#require` occurrences, including nested callbacks. All three cold diffs leave 069 unchanged. The new cold helpers are not the leading explanation. Fix 2 resolving earlier macro type errors may simply have allowed backend compilation to become reachable; it does not prove its Bool bindings caused the LLVM cost. Exact cache/build-history attribution remains outside this report.

## Parent-selected bounded partition

Parent selected **21** contiguous helpers (the proposed list contains 21, not 22). This supersedes the worker's initial 19-helper map. Each takes zero parameters, constructs all its own locals and is called sequentially with `try await` at its original location. Keep the single 069 `@Test` and serialized suite. Keep all complete loops verbatim; no continue/return rewrites, new test registrations, production changes, timeout changes, compiler-pass changes or generic execution framework are needed.

Keep all stage prints in the caller at their original positions. Keep the terminal-winner block 8650–8685, exact-live-model block 8825–8920 and final unknown-outcome block 9560–9589 in the caller, preserving their whole-test guard returns. The existing exact-recovery helper matrix 8922–8933 also stays in the caller. Every nonblank statement in 069 is either moved verbatim in the table or retained at its existing sequential position.

Locations/counts refer to the frozen current source; counts are lexical and include nested closures, not predicted generated suspend sites.

| Helper group | Current lines | First / last boundary and contained scenarios | await / expect / require |
| --- | --- | --- | --- |
| 1. Board wiring | 6546–6676 | `initialRouter` through complete wiring-permutation loop; initial blocked proposal and board/adapter/EOF winners | 5 / 34 / 3 |
| 2. Active registry and start gate | 6678–6890 | `activeExecutionID` through downstream-count check; pending cancel, retry, shared failure, pending-only removal, canceled start gate | 51 / 26 / 0 |
| 3. Adapter cleanup sharing | 6892–7034 | `modelCleanupCell` through final `cliBoard` empty check; full model and CLI dual-canceler cases | 32 / 12 / 0 |
| 4. Model handoff and atomic claims | 7036–7168 | `modelHandoffCell` through `atomicReuseConsumer` success check | 28 / 12 / 0 |
| 5. Stubborn CLI and immediate winners | 7170–7300 | `stubbornCliCell` through whole outcome loop; retain existing immediate-CLI helper call after each model outcome | 26 / 14 / 0 |
| 6. Prelaunch CLI and quarantine | 7302–7446 | `prelaunchCliCell` through final quarantine stream success expectation | 27 / 20 / 0 |
| 7. Bound generations | 7448–7542 | `generationModelGates` through final `generationCliBoard` check | 10 / 6 / 0 |
| 8. Completion registry | 7544–7661 | `completionExecutionID` through duplicate-removal catch | 27 / 14 / 0 |
| 9. Duplicate dispatch and pre-begin | 7663–7808 | `duplicateFixture` through `preBeginLedger.execute == 0`; duplicate execute, incomplete handle and pre-begin cancellation | 18 / 21 / 0 |
| 10. Begin/register latch | 7810–7937 | `latchFixture` through final `latchCompletions` count | 22 / 19 / 0 |
| 11. Settled primary failure/retry | 7939–8131 | `settledChildFixture` through final active in-flight count; keep database trigger, both waiters, trigger removal and retry together | 28 / 41 / 0 |
| 12. Post-gate and bind behavior | 8133–8299 | `postGateFixture` through whole bind-mode loop; both cancel/throw cases | 24 / 31 / 0 |
| 13. Observer and finalizer failure | 8301–8451 | `observerFixture` through finalizer card-ready expectation | 17 / 29 / 1 |
| 14. Authorized-removal barrier/failure | 8453–8605 | `removalBarrierFixture` through retained failed-removal registry count | 34 / 17 / 0 |
| 15. Observer Store failure | 8607–8648 | `observerFailureFixture` through observer-count-zero check | 2 / 1 / 0 |
| 16. Exact live CLI | 8688–8823 | Complete bindSession false/true loop, including original continue branch | 17 / 24 / 0 |
| 17. Mission CLI recovery | 8936–9042 | Complete bindSession false/true loop | 5 / 18 / 0 |
| 18. Mission ModelLoop recovery | 9045–9145 | Complete bindSession false/true loop | 5 / 19 / 0 |
| 19. Shared recovery owner | 9148–9221 | `sharedRecoveryFixture` through final active in-flight count | 12 / 13 / 0 |
| 20. Recovery failure/retry | 9224–9333 | Complete transport/evidence/store failure-phase loop | 11 / 17 / 0 |
| 21. Shared recovery action matrix | 9336–9558 | Complete allCases loop, including racing attempts, blocker/trigger cleanup and retry | 28 / 26 / 1 |

The unchanged caller portions contain **17 lexical awaits, 24 expect and zero require** occurrences before adding the 21 sequential helper calls. Caller plus helpers retain exactly **438 expect and five require** occurrences. The largest outlined group has 51 lexical awaits and the longest group is 223 lines, instead of one 3,046-line function with 446 lexical awaits. These counts support a material partition, but generated IR must still be measured.

## Concrete cross-dependency and lifetime review

Static reading of every proposed group found **no cross-group local capture/data dependency requiring a parameter**. Closely coupled retry/failure state remains inside its group. Global fixture factories, deterministic IDs, constants and existing helpers remain unchanged external inputs. Repeated short variable names in separate loops are independent declarations.

No definite source blocker was found in the parent's partition. The named concurrent operations created in these groups remain with their waits/joins: cleanup-sharing groups 2–3; handoff/reuse consumers and atomic claim in 4–5; claim acknowledgments and consumer waits in 6–7; shared resolution waiters in 8; duplicate execute and canceled pre-begin tasks in 9; cancel/execute tasks in 10; primary/external tasks and retry in 11; post-gate execute/cancel in 12; finalizer task in 13; both task/raw-waiter pairs in 14; exact-live tasks in 16; both recovery tasks in 19; and both racing attempts in 21. This does not establish hidden production task completion beyond their existing observable join contracts.

The parent explicitly ruled that **earlier destruction after scenario tasks/streams have joined and scenario terminal assertions finish is intended test-fixture scope hygiene**. This report follows that ruling; it no longer recommends introducing fixture-return machinery for every helper. It is an intentional resource-lifetime adjustment, not a claim of byte-for-byte ARC timing equivalence.

Important retained caveats for implementation/review:

- `P1F1DCanonicalExecutionFixture.deinit` removes its root (`EngineExecutionStoreTests.swift:1633–1635`). Top-level fixtures moved into helpers can therefore be removed earlier. Keep helper return after all original operations/assertions. If an actual observer or producer outlives those joins, retain that specific fixture or keep its dependent region grouped; do not invent a generic retention framework.
- Asynchronous lifecycle observers in groups 4–6 can spawn recording tasks. Their local probes/adapters stay within the same group, and those groups have no canonical fixture whose root deinit could race later database access. Preserve all lifecycle waits and claims exactly.
- Group 14 deliberately ends the removal-failure case with `removalFailureRegistry.snapshotCount() == 1`. This is expected evidence of the failed finalizer, not an unfinished task or permission to force registry cleanup. Both the coordinator task and raw receipt waiter are awaited before that assertion. Preserve the retained-count assertion and failure outcomes; do not mutate the registry to make fixture teardown look cleaner.
- Group 10's sleeping bound callback, group 11's settled-primary observer barrier, group 13's finalizer observer and group 14's removal observer all remain with their corresponding awaited execute/finalizer tasks. The source partition does not split their owner/waiter relationship.
- All original per-iteration defers stay inside their original full loops (notably groups 1 and 12). The parent-selected spans introduce no moved top-level defer that extends across a later group.
- Existing error paths can unwind before success-path joins; preserve their exact throws/catches/Issue.record behavior. Earlier cleanup on an error path is not a new license to signal guessed processes, swallow errors, bypass gates or edit production ownership.
- Keeping all three outer guard blocks in the caller preserves whole-test early returns automatically. Keeping group 16's loop intact preserves its `continue`. No Boolean continuation protocol is needed.
- Keep all ten stage-print sites, six case-print sites, original enum/Boolean/failure-phase loop inputs and order, exact observations/syscall counts, gates, polling bounds, catches and required assertions.

The map is ready for a scoped implementation brief. Runtime safety and compiler improvement remain validation requirements, not claims supplied by this static review.

## Precise acceptance evidence

1. Parent freezes the existing source, complete diagnostic argv/output/exits, original compiler sample/memory evidence and exact pass-boundary log. Approve a scoped extraction brief including the selected fixture-lifetime policy. Only the test source and task evidence are in scope.
2. Preserve one 069 registered test and all prior tests. Mechanically compare moved source blocks against the frozen preimage; after normalizing indentation and the approved boundary/return syntax, every body statement must remain. Verify 438 expect / 5 require occurrences across caller plus helpers, all stage/case inputs/order, and joins/defers/early returns. Mere count equality is not sufficient without body comparison.
3. Run one bounded parent-owned pre-LLVM diagnostic with unchanged compiler settings. Re-measure every new helper and the 069 caller, not only aggregate module size. The old single 216,814-line / 747-suspend function must be gone; the largest new coroutine must materially shrink. Inspect actual lower-level counts before normal compilation. Do not disable CoroSplit/optimizations or delete tests.
4. Parent owns one normal compiler/focused-test invocation under the established resource policy. It must include **069 and both original/forced 065 tests** and actually finish those tests, retaining stdout/stderr, real exit, elapsed time and resource checks. A new focused success is distinct from full acceptance. Stop the exact owned process if the established boundary is reached, retain evidence and keep RED.
5. Obtain responsibilities-separated actual-diff review and run the unchanged authoritative `swift run RunTests` full inventory. Preserve complete output and actual exit. Earlier full-suite issues remain unresolved until this gate passes. No packaging or product-stage progression follows from a successful IR diagnostic, object compile or focused pass.

No source change or runtime verification was performed by this analysis worker. The complete proposed partition is ready for the parent to turn into a bounded, reviewable implementation brief.
