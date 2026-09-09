# Checkpoint 3 capture implementation — independent review

2026-09-06. Read-only responsibilities-separated spec/code/test review of `goal-foundation-capture-fix1.diff`, actual capture-entry preimages and released source. Reviewer did not implement production/tests or run compilers, tests, databases, Apps or Providers. Only this report was written.

Current status: **follow-up spec and quality PASS for checkpoint 3 only; both implementation P2 findings are closed** for fix2 package `6b530b639ecfb32f8c2ff49d399c795d7b3705e2783edfe93b142a91f205ebc6`. The initial rejected review remains below as history; the closing evidence and exact scope are in the final section.

## Initial decision — superseded by the follow-up closure below

**Changes required; checkpoint 3 implementation is not approved. Two P2 findings remain open.** Review target is package SHA-256 `d4a910e7a13523ab2efe8e3952961223b4b631d9919613dacef4e7dea8a0b189`, with the source hashes below. The parent’s first GREEN run was still pending when this source review began; no uncompleted run is counted as evidence. Even a pass of the current frozen tests would not cover these two counterexamples.

The prior first-attachment wrong-input-receipt test-preparation P2 remains closed as documented in `goal-foundation-capture-test-review.md`: its exact seven-line correction and meaningful RED2 were verified. The findings below concern the implementation and require new bounded RED evidence before repair.

## P2-1 — Canonically equivalent Unicode bypasses exact intent replay identity

`Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift:17,127` compares canonical request JSON with Swift `String ==`. Swift string equality admits Unicode canonical equivalence; the accepted canonical contract instead preserves original scalar/UTF-8 bytes and hashes. This is not equivalent to comparing sealed canonical command/intent bytes.

Concrete source-derived counterexample: prepare an intent with selected unresolved runtime model `caf\u{00E9}`, then submit the same IDs/envelope/source text with only the model changed to `cafe\u{0301}`. Both model values satisfy current validation and compare equal as Swift strings, but their canonical intent UTF-8 and hashes differ. Runtime context is outside CaptureInputCommand, so its unchanged domain command hash/replay does not catch this drift. The present prepare path can return the existing capture receipt rather than operationConflict; direct reseal similarly lacks the required stageConflict. Changing rawIntent itself is not the right isolated oracle because the input-domain command hash would detect that different payload later.

Required bounded regression: use these two context model representations, prove canonical request Data/hashes differ, then require prepare operationConflict and direct seal stageConflict with complete no-write snapshots. Keep the original source text/envelope/IDs fixed. No Provider resolution is needed.

Required repair: compare canonical request UTF-8 Data/bytes at both sites (or exact bytes plus the sealed request hash), never normalize Unicode. Preserve the separate legitimate-current-context revision behavior: replay still compares the caller with the stored original intent, not the current context JSON. The parent independently confirmed this source path and admitted a bounded RED before the two comparisons are changed.

## P2-2 — Direct receipt attachment bypasses the authoritative event/outbox graph check

`DesktopGoalWorkflowStore.swift:80–98` checks the domain receipt row’s command type/hash/count/result, current input/work scope, and work input payload. It does not check the actual command’s event rows, camp-event scope, event payloads/timestamps or outbox graph. `CampSafeCommandResultV1` validates schema/kinds/order/count shape (`DomainEvent.swift:989–1085`); those count values are not proof that the referenced durable graph still exists.

The ordinary prepare replay correctly calls InputGoalStore and therefore reaches `DomainEventStore.validateStoredGraph` (`DomainEventStore.swift:68–105,875–1002`). The independently callable append primitive skips that authority. A concrete source-derived counterexample is an actual captured input with a sealed, unattached stage, followed by deleting its outbox row in the isolated fixture. Receipt row/result hash and current input/work remain valid, so the present direct first append can publish safeReceiptJson and advance the operation. The authoritative replay path rejects precisely this missing-outbox state. The existing historical test already uses this supported corruption probe (`DomainEventContractTests.swift:705–755`, missing-outbox branch); no production trigger or schema change is necessary.

Required bounded RED: create actual capture/domain receipt and sealed carrier fixture, remove only that command’s outbox in the temporary database, then attempt first attachment. Require the existing `DomainCommandGraphIntegrityError` and unchanged **post-corruption** carrier/domain snapshot. Keep the already-added wrong-input receipt and replacement assertions intact; they prove different invariants.

### Scoped cause repair recommended to the parent

The parent’s proposed repair is spec-safe: make only the newly introduced `appendCaptureReceipt` primitive an instance method, retaining the supplied Database transaction, so it can use `DomainEventStore(database: self.database)`. Build the actual prepared capture command from the stored exact intent plus existing `InputGoalStore.captureReplayPlan`, retain the receipt-existence/identity check, and call the existing event store execution/replay entry in that same transaction. Its `makeNew` closure must always throw `DomainCommandGraphIntegrityError`; this path must validate an existing capture, never manufacture one. Compare the validated canonical result bytes with the candidate before publishing a journal receipt.

This reuses full event/scope/outbox validation rather than duplicating graph SQL. It requires no DomainEventStore change or new file. Static append was a new extraction choice, not an original required public A1 signature: the plan specifies transaction-taking shared seal/append primitives (`goal-foundation-plan.md:76`). Receiver-only changes to the existing append tests can preserve every assertion. This recommendation does not authorize a generic domain replay redesign or broaden checkpoint scope.

## Other reviewed properties

- Original Domain first 370 lines are byte-preserved; their independently computed SHA-256 matches the capture-entry preimage. Added stage/receipt types have strict top-level key sets and canonical-byte/hash validation. Capture receipts revalidate CampSafe shape, require inputCaptured and initial input/work versions, and expose only safe IDs/versions and the existing safe receipt.
- Stage loading reconstructs the expected entire stage from the sealed intent and compares command Data/hash/envelope/receipt; arbitrary canonical payload JSON cannot silently become an executable stored capture. Only ordinal zero/inputCapture/no predecessor is supported. No simulated later stage is added.
- InputGoalStore change is the bounded transaction extraction: its public wrapper opens one write and delegates to the Database-taking overload, which preserves prepared command, existing event-store execution, input/work creation and original domain result construction. Desktop prepare opens one write, inserts carriers, seals, runs that overload and attaches its receipt. No nested pool write or second transaction splits atomic capture.
- Checked increments and id/version/phase CAS protect actual updates. Exact stale seal/receipt replay returns retained values without mutation; future versions and stale first writes reject. Submission stays prepared, with real queued parsing work and no fabricated goal/session/mission/outcome.
- Current context JSON/hash is validated separately, while its mutable runtime/policy fields are not compared to the old original context. Fixed input/goal/session/camp joins remain checked. New submissions validate actual reserved-ID conflicts, duplicate live session reservations and exact camp lifecycle authority inside the write.
- The frozen checkpoint tests cover actual receipt binding, rollback injected after domain writes, twelve-table counts/raw rows/hashes, reopen, real parser progress, policy identity, stale seal/append/replacement and corrupted context. Their earlier fourteen-test prefix remains unchanged. They do not cover the two new counterexamples above.
- Read/list APIs, deletion/redaction hooks, source-inventory successor and later integration gates are not implemented or approved here. Raw retention prechecks used by capture replay do not substitute for those future checkpoints.

## Frozen review evidence

Released source hashes were identical at initial and closing source inspection:

| Input | SHA-256 |
| --- | --- |
| DesktopGoalWorkflow.swift | `9c45462e0e59668d91030debce66a11f6fc40d7c944ca17764e1f70f4f7a0518` |
| DesktopGoalWorkflowStore.swift | `024c31b6c80bc78cdf32e6c8f551625311517049ea2dedc650ea21fd3fde7511` |
| InputGoalStore.swift | `bf055a97c13e6109a93239508949adad4cb963c26dfbf13a5ed664b2a8421afd` |
| DesktopGoalFoundationTests.swift | `c9ce30d15621694359e96ffce4fd9b3bb251097d7e42cfd68368147d16c5692e` |
| Actual-preimage fix1 package | `d4a910e7a13523ab2efe8e3952961223b4b631d9919613dacef4e7dea8a0b189` |

Domain prefix/entry preimage: `06f55681625d1450476d119c70c6855c3f29b2f5bc5a9b771a339d072c7f7bc4`. InputGoalStore entry preimage: `5f6dd93127b8b11cec76fd76e1645636d6438f8f6c6039b38317fd3195a1ff00`. New Store is reviewed against `/dev/null`, not against its temporary RED stub. Independently checking the RED2 305-entry source manifest while excluding only these three admitted production paths gives **302 unchanged inputs**, no failures; the frozen tests and historical source remain intact.

Original authority remains the approved A1 plan and `.superpowers/sdd/goal-foundation-plan/task-1-brief.md`, with the separately accepted narrative-text amendment untouched. No hash/sentinel or schema relaxation is recommended. Parent must preserve the initial implementation/run evidence, observe the two additional RED counterexamples, produce a narrowly repaired actual-preimage diff and completed GREEN/compatibility evidence, then request follow-up review. **No checkpoint, A1, full-runtime or strict-App acceptance follows from this report.**

## Follow-up closure — fix2, completed RED/GREEN and input compatibility

2026-09-06. **Spec PASS; code/test quality PASS; P2-1 and P2-2 closed. No remaining actionable finding in the bounded checkpoint 3 implementation.** This follow-up approves only the reviewed atomic capture/seal/receipt/replay checkpoint. Original A1 scoped reads, retention/deletion hooks, exact source-inventory successor, full unfiltered runtime, strict App build and later packaged/live/user acceptance remain unapproved future gates. No claim of full A1 or desktop-flow completion is made.

### Actual regression evidence before correction

The three added tests were read in frozen `goal-foundation-capture-review-red1-before.swift`, hash `0d18e590e932aaaeb1d303286c5e114e47cd764ff1e85333272fe9817b7b1ef8`. Unicode cases independently prove Swift String equality while canonical request Data and SHA-256 differ, with the source text/IDs fixed; they exercise prepare and direct seal separately and retain exact-replay checks. The missing-outbox case resolves the actual command’s one event/outbox, removes only that outbox in an isolated database, and first proves ordinary InputGoalStore replay rejects the same graph without mutation before testing direct append.

`goal-foundation-capture-review-red1.log`, SHA-256 `62adf78d169497f3c896f5d37c191f087b60d426354004bc08cd8aa4d69b7859`, records PID 74071: build 23.48 seconds, three tests/one suite, four issues in 0.418 seconds, exit 1/no signal. Both Unicode expected conflicts were not thrown. Direct append after missing-outbox corruption also did not throw, and its complete snapshot changed because a receipt was attached. The original domain-replay oracle and post-oracle no-mutation check passed. Process evidence has 305 before/305 after-OK hashes, zero mismatches. Thus the two source findings were demonstrated behaviorally, not merely inferred.

### Reviewed correction

- P2-1: Store prepare now compares `Data(stored.requestJSON.utf8)` to caller request Data (`DesktopGoalWorkflowStore.swift:17`); seal compares stored request Data to the canonical encoded intent (`:141`). Neither normalizes strings or switches identity to current mutable context. Existing exact original-intent replay and legitimate context revision behavior remain intact.
- P2-2: the admitted new append primitive is now an instance method. After the existing candidate/receipt identity checks, it rebuilds the exact capture PreparedDomainCommand and original replay plan, then invokes the unchanged DomainEventStore with the **same supplied Database transaction** (`:87–99`). Its makeNew closure always throws DomainCommandGraphIntegrityError; it cannot create a missing capture. The validated canonical result bytes must equal the candidate bytes before input/work checks and before any journal update. Full event/scope/outbox authority is reused; no copied partial validator, nested pool write or DomainEventStore source change was introduced.
- Comparing initial-review Store preimage to current Store shows only those two byte comparisons, instance receiver/Self qualification changes and the shared validator call/result-byte check. Domain and InputGoalStore are unchanged from the initial released implementation.
- Comparing frozen review-RED tests to current tests shows exactly **six append receiver substitutions**, no changed assertions or other changes. The previously closed wrong-first-input-receipt assertion remains in place, as do replacement, stale/current replay, no-write and original fourteen domain/text tests.

### Completed post-correction verification

This reviewer read the complete saved logs/process evidence; all compiler/test runs were performed by the parent:

| Run | Verified result |
| --- | --- |
| `goal-foundation-capture-green2.log`, PID 74547, filter DesktopGoalFoundationTests | Build 26.99 seconds; **26 tests/1 suite PASS in 2.410 seconds**, exit 0/no signal. Includes all three new review regressions, first wrong-receipt rejection, atomic rollback, context revision/replay, seal/append CAS and earlier domain/text cases. |
| `goal-foundation-capture-input-regression.log`, PID 74763, filter P1CInputEnvelopeContractTests | **33 tests/1 suite PASS in 2.733 seconds**, exit 0/no signal. Exercises the unchanged public capture contract, payload replay conflicts, parser lifecycle/renewal/cancellation, camp authority and legacy input/tombstone behavior after the transaction extraction. |

Each process manifest independently reports 305 before/305 after-OK hashes and zero mismatches. A closing read-only check of every path in the input-regression manifest against the current workspace produced **305/305 matches**, no failures. This includes the released correction and unchanged historical source; it is not a source-inventory-sentinel run. Existing driver/linker warnings are retained in GREEN2; this is not a warning-free build claim.

### Final approval identity

The actual-preimage full checkpoint package is `goal-foundation-capture-fix2.diff`, hash `6b530b639ecfb32f8c2ff49d399c795d7b3705e2783edfe93b142a91f205ebc6`. It retains original capture-entry Domain/InputGoalStore preimages and new Store versus `/dev/null`, while the small review correction was additionally inspected against `goal-foundation-capture-review-before/`. No HEAD diff substitutes for the dirty preimages.

| Final input | SHA-256 |
| --- | --- |
| DesktopGoalWorkflow.swift | `9c45462e0e59668d91030debce66a11f6fc40d7c944ca17764e1f70f4f7a0518` |
| DesktopGoalWorkflowStore.swift | `ed88fb677aef954e5a8ca4f184f21125469183a790ba3d6bf8e6562a354cd2cd` |
| InputGoalStore.swift | `bf055a97c13e6109a93239508949adad4cb963c26dfbf13a5ed664b2a8421afd` |
| DesktopGoalFoundationTests.swift | `e6fe77418b7c10dc2b23aeafe7cf4173552b93fbbe4398e6391a6b09c9d9ec0f` |
| GREEN2 log | `9a042b348926a99d32b7884299ce60804adf99514608c295de6aff5da1a86e55` |
| Input regression log | `b94226ac7b92e77af32ee0522bdb86e994ef1abd1b877d25c800893636302484` |

Store/test/package hashes match their initial correction-release inspection and closing inspection. Original A1 plan and brief retain hashes `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` and `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82`. The parent may proceed to the next separately approved A1 checkpoint; subsequent source changes do not inherit this byte-bound approval automatically.
