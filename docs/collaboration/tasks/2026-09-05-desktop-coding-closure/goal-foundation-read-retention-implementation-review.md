# Independent A1 read/retention implementation review

## Verdict

**Spec: PASS for the admitted read/retention implementation. Quality: PASS for the same bounded delta. Zero P0 / P1 / P2 findings.**

The implementation places both carrier redactions and deletion-replay integrity checks in the existing domain transactions, validates raw retention before decoding payloads, and exposes actual scoped foundation records. The strengthened negative tests now pass without changing their frozen assertions. The parent-owned focused GREEN evidence and historical regressions are internally consistent and source-bound. This is not final A1, unfiltered-suite, strict App, runtime, packaging or product acceptance.

## Authority, source identity and independence

Reviewed `AGENTS.md`, the approved `goal-foundation-plan.md` read/retention contracts, its Task 1 brief, the preserved test-preparation findings/closure, the exact actual-preimage package, the full 503-line current store, the complete InputGoalStore delta, relevant existing domain-receipt validation, and the implementation handoff at the end of `.superpowers/sdd/goal-foundation-plan/task-1-report.md`.

The authoritative checkout is `/Users/muzi/Agent-loop` on `codex/desktop-coding-closure-20260905`. The review used the dirty entry preimages, not HEAD. A read-only unified-diff reconstruction independently applied every package hunk in memory to its recorded preimage and required all four results to equal their current files. No patch was applied to the worktree by this reviewer.

| Frozen input | SHA-256 |
| --- | --- |
| `goal-foundation-read-retention-implementation1.diff` | `b8c0360e52a37cfc990812a9c7b6bebb2163dc53c9ed05771d184debeafc9bc3` |
| Approved `goal-foundation-plan.md` | `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` |
| `.superpowers/sdd/goal-foundation-plan/task-1-brief.md` | `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82` |
| `DesktopGoalWorkflowStore.swift` | `2180fb927838582b7acb7773384934ee05613c42f916ac36493982f639563bcd` |
| `InputGoalStore.swift` | `967364e2a237cbddb42c75cc55910ccc825b53676865383af071f937954c9dd9` |
| `DesktopGoalWorkflow.swift` | `b8bb594993714408bb0de0bcab62511815297e624cd77abb599896d493dfff37` |
| `DesktopGoalFoundationTests.swift` | `120fa1c0f030ef7f3a92b10ecec1bf0adfb5a074f07782f105a3123f9c26bb56` |

The package's entry-before domain/store/test hashes are `9c45462e…`, `ed88fb67…`, and `e6fe7741…`; its InputGoalStore preimage is `bf055a97…`. Thus the package includes the already reviewed read contracts and eight tests added after the 26-test entry checkpoint. The production writer changed only Store and InputGoalStore; the prepared domain contracts and all 34 tests remained frozen during implementation. The separately authorized `CampLifecycleMigrationTests.swift` amendment at `570b26b9d72263fcbb6f69c62f725beef2dd28f7da50d8ecf7ebcc800da36c8f` is present in all GREEN manifests and is owned by a different review. It is neither an unauthorized drift nor part of this source verdict.

## Concrete review results

1. **Both actual tombstone hooks are atomic and preserve historical command behavior.** The complete InputGoalStore delta is +11/-3 lines. Cancellation calls `redact` immediately after `input.update` inside the existing `DurableWorkStore.cancel` business mutation (`InputGoalStore.swift:412`), after the actual work update. Completion uses the existing mutation's Database argument after constructing the in-memory tombstone (`:680`), before `executeOrdinary` persists input. The redactor explicitly accommodates that persisted `deletionRequested` state at the completion transaction point (`DesktopGoalWorkflowStore.swift:39`). Neither path introduces another pool write or changes the caller envelope, old head, domain result, public signature, transition permissions or `requestDeletion` rejection of goalCreated.

2. **Exact deletion replay validates; it does not repair.** Both existing event-store calls retain their result, invoke `validateDeletedRetention` before leaving the same write transaction, then return the original receipt (`InputGoalStore.swift:433`, `:726`). The ordinary-command hook is restricted to `inputCompleteDeletion`. The validator at `DesktopGoalWorkflowStore.swift:73` only reads and validates. It cannot turn live raw carriers beneath a tombstone into a successful replay. Any integrity exception also rolls back a newly executing domain command's input/work/events/outbox/receipt writes. A missing desktop context remains the intentional legacy no-op.

3. **Raw retention checks cover every operation before exposing JSON.** `retentionIsDeleted` reads actual input tombstone state and all operation rows, then validates NULL/phase state and safe identity/hash metadata (`DesktopGoalWorkflowStore.swift:78`). A redacted context cannot hide an operation with live request/result bytes; malformed raw bytes reach `retentionIntegrity` before the canonical decoder. Valid deleted reads return only reserved input/goal IDs, and original capture replay reaches `inputDeleted` only after the complete retained state passes validation. No raw payload is decoded from the deleted carriers and no spontaneous repair is performed.

4. **Initial redaction validates before mutation and advances all owned rows once.** `redact` validates context and all safe receipts, then computes every checked next version before writing (`DesktopGoalWorkflowStore.swift:46`). It updates the context and all matching operation rows, with ID/version predicates and affected-row checks; it has no owner/phase filter that could skip the failed system probe. It nulls all three raw JSON carriers, preserves original hashes/IDs/safe receipt bytes, and updates each version once. Repeated redaction takes the validation-only branch and leaves versions/times/bytes unchanged. Invalid safe shape, foreign receipt, checked arithmetic failure or SQL failure cannot partially commit the enclosing deletion transaction.

5. **Safe receipt validation checks semantic ownership, not only decode success.** `retainedSafeReceipt` strictly decodes canonical `DesktopGoalCaptureReceiptV1`, checks its input/goal/operation identities against the carrier, and compares its nested capture result with the actual persisted original command receipt's type/count/bytes/hash/command hash (`DesktopGoalWorkflowStore.swift:128`). Initial redaction also compares the reserved session ID with the still-live context. Safe receipt JSON is preserved in place, never replaced with a newly fabricated or re-encoded receipt. After context redaction, the implementation correctly does not claim to reconstruct the discarded session identity; the retained row identities and actual nested command receipt remain the available checks. This reviewed boundary matches the admitted storage design and introduces no future-stage execution.

6. **Foundation reads have one read transaction and actual graph ownership.** `snapshot` and `list` each use a single pool read (`DesktopGoalWorkflowStore.swift:11`). They validate requested identifiers, check the stored camp using exact UTF-8 bytes, perform retention checks, then validate canonical context and journal bytes. List ordering is `createdAt,inputId`, non-carrier legacy inputs are excluded, and archived camps remain readable. A live result requires the actual input plus exact source/body/privacy/intent/camp joins, fixed goal/source-input joins when applicable, and any session's fixed session/goal/input identity. The broader session query catches an incorrectly attached session instead of hiding it by selecting only the expected ID.

7. **Owned work and capture evidence remain concrete.** The original parsing work is anchored by the actual capture receipt's work ID, so an aggregate mutation cannot be hidden by filtering that row away. Included parsing/coach records must match camp, aggregate kind/ID, canonical payload hash and typed input/goal/session payloads (`DesktopGoalWorkflowStore.swift:374`). The required real capture receipt is then checked through the existing DomainEventStore replay validator, using the same read Database and a new-command closure that always throws (`:401`). Inspection of `DomainEventStore.swift:69` confirms that a present receipt takes the existing graph-validation branch before new-command writes. No input/work/event is created during snapshot/list. Inert journal rows expose stored metadata and validated empty stage arrays; unsupported nonempty future stages fail closed rather than claiming execution.

8. **The regression assertions were not weakened to reach GREEN.** The final test hash equals the independently accepted 34-test preparation. Its two real tombstone branches, forced rollback, saved original old-head replays across reopen, legacy behavior, all-operation failed/system probe, isolated live-operation-under-redacted-context case, foreign actual receipt and unexpected-key matrices all pass. Existing Unicode byte-identity and missing-outbox receipt regressions also remain present and pass. The store's accepted capture/seal/append behavior remains intact, apart from the explicitly required stricter shared retention guard.

## Verified execution evidence

The reviewer ran no compiler or tests. The following are parent-owned executions whose retained complete logs, summaries and process records were inspected. The Foundation log contains repetitive compiler warnings from unchanged test files plus the retained driver/rpath warnings; it has no compilation error or failing test. `git diff --check` is limited to changes visible in the tracked tree and does not cover the untracked InputGoalStore baseline. The complete InputGoalStore change was reviewed against its actual preimage; the git whitespace check is not evidence of coverage for that untracked file.

| Run prefix | PID | Result | Build / test time | Log SHA-256 |
| --- | --- | --- | --- | --- |
| `goal-foundation-read-retention-green1` | 80443 | 34 tests, 1 suite, exit 0 | 137.80 s / 6.375 s | `b43f32e937733d20c9a4e647ca691af35c7b84b615dfa42be4dbac55cc3368e3` |
| `goal-foundation-read-retention-input-regression` | 80784 | 33 tests, 1 suite, exit 0 | 0.33 s / 2.436 s | `13d742618b22456fc7208e6d0e50625fb90e55908b997f80e69736486ed18110` |
| `goal-foundation-read-retention-outcome-regression` | 80766 | 18 tests, 1 suite, exit 0 | 0.13 s / 1.556 s | `4573825b33cdb571bd2aca71d6e6ce5c91efb9e83f33833651ef5d43e6294eae` |
| `goal-foundation-v17-checkpoint-amendment-green1` | 80742 | 13 tests, 1 suite, exit 0 | 0.34 s / 0.979 s | `815cab7f467efa0ae1592f7521f5b2f443972edc2f0662438792bacca7d19b4c` |

Each prefix has a complete `.log`, `-process.txt` and `-source.sha256` in this task directory. The recorded commands use `swift run --jobs 2 RunTests --filter` with the respective `DesktopGoalFoundationTests`, `P1CInputEnvelopeContractTests`, `P1DOutcomeContractTests`, and `P1ECampLifecycleMigrationTests` suite. All four record exit 0 and signal nil. A read-only audit required 305 before entries to equal 305 after-OK entries and each manifest, then required all four manifests to be identical and every current file to match. This checked the entire frozen revision, including the separately owned amendment.

Foundation run timing is `2026-09-06T22:45:16+08:00` through `22:47:44+08:00`; the three serial regression runs occupy `22:48:07` through `22:48:15`. Its process SHA-256 is `4f8853562e39b4200473a9ff0dd681cee6df32e10089c585b990fbd175c1cc14`, and the shared source-manifest SHA-256 is `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`. The previously reviewed intentional REDs remain separate historical evidence; they are not relabeled as successful execution.

## Acceptance boundary

This review accepts only the admitted A1 read/retention implementation and the focused evidence above. The separate historical migration amendment retains its own reviewer. Parent-owned unfiltered RunTests, strict App compilation, remaining source-boundary/integration evidence, final A1 review/acceptance and subsequent App/product validation are not substituted by these focused results. No A2/A3 driver, Provider, runtime, UI, packaging, commit, push or release approval is granted here.

Only this designated artifact was written. All source, tests, preimages, approved plans and existing evidence were preserved; frozen hashes were checked again after the artifact write. Review and verification skills guided the exact-preimage comparison, transaction/identity checks, and separation of retained test evidence from later acceptance.
