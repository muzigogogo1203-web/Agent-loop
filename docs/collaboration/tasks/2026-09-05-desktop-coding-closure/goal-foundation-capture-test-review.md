# Checkpoint 3 capture/journal test preparation review

2026-09-06. Read-only review of the frozen `goal-foundation-capture-red-before/` scaffolds and appended tests against the original A1 plan/brief and the parent’s scoped receipt-append/session-reservation rulings. No source changes or compiler/test/database/App/Provider execution by this reviewer. No implementation approval is given; the parent’s actual RED and explicit production grant remain required.

## Status

**One actionable test-coverage finding before production; otherwise the reviewed setup and oracles fit checkpoint 3.** This is a review of the frozen test source, not an interpretation of the unfinished RED process and not an A1 acceptance decision.

### P2 — Exercise wrong receipt on the first attachment, not only after a valid receipt exists

`DesktopGoalFoundationTests.swift:1150–1216` creates a real `otherReceipt` for a different input, but only passes it to `appendCaptureReceipt` after successfully attaching the correct receipt (`:1204`, expectedVersion 3). An implementation that accepts any structurally valid receipt on initial attachment, then rejects replacements, could pass the present test. That would leave the initial receipt-to-sealed-command/input provenance unproven, despite the plan’s requirement that receipt identities/hashes agree with the actual input/work and domain command.

Bounded correction: in this same test, after the stale-version assertion and before the successful append, call `appendCaptureReceipt` with the already-created `otherReceipt` at the actual current version 2. Require `DesktopGoalFoundationErrorV1.receiptConflict` and compare the complete twelve-table snapshot to `before`; then perform the existing valid append. This uses a real other input’s receipt and does not fabricate domain success, alter production APIs, require another source file or change the plan’s receipt semantics. Preserve the existing post-append replacement test because it proves a distinct invariant.

Parent disposition: the parent independently verified and accepted this exact gap. The current PID 72046 RED retains its frozen inputs until completion; only afterward will the parent admit the pre-success otherReceipt assertion plus unchanged twelve-table snapshot and observe a revised bounded RED before production. No plan expansion or broader audit is requested. The correction is not yet verified by this report.

## Positive review evidence

- Nine new tests are appended after line 735. Independently hashing exactly that first-735-line prefix yields `821812397b50661b42e7a20c33f31d53f3716ab23c0569086d590b419f67f1ac`, the reviewed text-amendment fourteen-test source. Earlier cases are byte-preserved.
- The new Domain declarations are appended after the existing capture intent. The temporary journal Codable entry points and three Store entry points throw explicit checkpoint3 scaffold errors; they do not generate successful receipts, swallow errors or simulate capture. They remain temporary RED scaffolds, not acceptable final implementations.
- `atomicCaptureCreatesActualInputWorkAndPreparedSubmission` checks real input/work/domain receipt rows; queued work has zero attempts, and goal/session/mission/outcome rows stay absent. Stage whole-command bytes/hash, safe receipt, actual domain result bytes/hash and input/work IDs/versions are cross-checked. The operation remains prepared at version 3, representing initial insertion → seal → receipt append, not fake submit completion.
- The rollback probe injects an abort specifically on the target operation’s non-null safeReceipt update. Its trigger first requires input, parsing work and domain receipt to exist, distinguishing premature journal writes from the intended post-domain failure. The test requires the specific DatabaseError message and compares counts, raw rows and hashes for twelve tables, with a real unrelated capture and its carriers already present. Counts alone cannot make it pass.
- Replay tests close/reopen the on-disk database and drive the actual parser claim/commit before returning the original capture receipt again. They check that replay does not add attempts or mutate progressed rows. The policy test distinguishes a changed incoming original gesture (conflict) from a later context-row revision (original gesture replay succeeds without rewriting that revision).
- Seal and append tests are independent of successful `prepareSubmission`: fixture setup uses the existing InputGoalStore to commit actual domain effects and only arranges local carrier rows describing those commands. Seal checks stale/current exact replay, future-version rejection, command bytes/envelope identity, prepared phase and no receipt. Append checks actual receipt bytes/hash and immutable stage prefix, duplicate append and post-append reseal without row mutation.
- The duplicate live-session reservation case uses a valid existing carrier plus real input receipt and attempts a distinct input/goal/operation sharing its reserved session ID. Requiring contextConflict before any new rows is consistent with the parent’s explicit same-transaction reservation ruling, not an inferred SQL uniqueness guarantee.
- Invalid-policy cases use independent canonical wire fixtures and no-write snapshots. A separate corrupted persisted context case requires `corruptCanonicalPayload` rather than silently repairing or treating the original request as sufficient authority. This is stronger than constructor-only rejection.
- Scoped reads, retention/redaction and the exact source-inventory successor are deliberately absent here. They remain later A1 checkpoints; these tests do not establish them. No new Provider or runtime authority is implied by unresolved selected runtime values.

## Frozen inputs

All paths in this table are snapshot files under `goal-foundation-capture-red-before/`:

| File | SHA-256 |
| --- | --- |
| DesktopGoalWorkflow.swift | `99a8c71b54dee9a84b8e711c4660c41d756f8a13135aabe5f458d1c91db2058f` |
| DesktopGoalWorkflowStore.swift | `f2ceafcdff253230bd1be3c306b691586aa2b990f7e84ca012a3a026165b7d68` |
| DesktopGoalFoundationTests.swift | `e08c1726fd8ba1f90a986bada45765d0b77b2c32784809ea7f414a47216f60d6` |

Relevant original authority: `goal-foundation-plan.md:44–45,76,85–86,135–179`; identical receipt/atomicity requirements are retained in `.superpowers/sdd/goal-foundation-plan/task-1-brief.md`. The existing API risk map explains narrow package-visible receipt append and live-session collision enforcement without a schema expansion (`goal-foundation-api-risk-map.md:44–50`). This review adds no new production entry point or broader file permission.

Once the first-attachment provenance case is added, preserve these RED artifacts, freeze the revised tests separately and let the parent observe its meaningful RED before granting production work. Final implementation review must still inspect receipt-to-command provenance, transaction boundaries, checked versions, strict canonical payload validation and actual GREEN evidence; this test preparation report cannot substitute for it.

## P2 test-preparation closure — revised frozen test and RED2

2026-09-06. **The P2 test-preparation finding above is closed.** Read-only comparison of the original frozen tests with `goal-foundation-capture-red2-before.swift` confirms exactly seven added lines, with no other edits. Before the first successful attachment, the revised test passes the existing real `otherReceipt` to `appendCaptureReceipt` at current expectedVersion 2, requires `receiptConflict`, and compares `afterWrongFirstReceipt` with the original complete twelve-table snapshot. The valid first append and subsequent replacement rejection remain intact. The gap is now directly exercised, not inferred from post-attachment immutability.

The revised frozen test SHA-256 is `c9ce30d15621694359e96ffce4fd9b3bb251097d7e42cfd68368147d16c5692e`. The complete `goal-foundation-capture-red2.log` has SHA-256 `6345a8c5817737c88886ce1bfda4ecfca5ec9a0df5e3e986fcb7c02aaa907e1c`. Its matching process evidence records PID 72733, `swift run --jobs 2 RunTests --filter sealedStageAndReceiptCASIsReplayableButNotReplaceable`, build 22.80 seconds, one test/one suite failing in 0.140 seconds, exit 1/no signal. All three observed issues reach the actual unimplemented Store entry: stale-version rejection, the newly added wrong-first-receipt rejection, and valid first-append success. All receive the explicit checkpoint3 scaffold error; there is no fixture-setup failure masking the new assertion. Independently checking process evidence gives 305 before/305 after-OK input hashes and zero mismatches.

This closes only the **test coverage preparation** finding. It does not claim first-attachment provenance is implemented, does not approve active production work or its eventual diff, and does not admit read/list/retention/source-inventory functionality. The parent’s separately granted checkpoint 3 production scope and later actual-diff/GREEN review remain the authority and implementation gates.
