# Read/retention checkpoint — independent test-preparation review

Status: three P2 coverage findings open. The five required tests are present and broadly aligned with the approved A1 contract, but the retention assertions below need bounded strengthening before this preparation is accepted. This is not an implementation review or permission to widen A1. Throwing snapshot/list/redact stubs are intentional RED scaffolding, not findings.

## Scope and evidence

Reviewed `goal-foundation-plan.md` read/retention contracts (lines 46, 87–90, 183–207), corresponding Task 1 brief, both supplied patch artifacts, actual entry preimages, and current appended tests/types/stubs. The first 1,362 test lines hash exactly to the preimage (`e6fe77418b7c10dc2b23aeafe7cf4173552b93fbbe4398e6391a6b09c9d9ec0f`), preserving the earlier 26-test checkpoint. InputGoalStore is unchanged. No compiler/test execution, source edits, or database/application actions were performed by this reviewer. Parent owns the in-progress RED run; no result or behavioral success is inferred here.

## Findings and minimal additions

### P2 — Exercise every operation row, not just the single submit row

`DesktopGoalFoundationTests.swift:1636–1652` fetches all operations but asserts count one and inspects only `first`. Both actual deletion branches create only that one operation. Consequently, a redactor restricted to the first/prepared-userMutation/submit row could satisfy every existing deletion assertion while leaving another owned carrier's raw request/result behind. The plan explicitly requires nulling every operation request/result and advancing each version, independent of owner/phase.

Minimal addition: in the isolated retention fixture only, insert a second schema-valid inert carrier row for the same input (for example owner `system`, phase `failed`, distinct operation ID, non-null marker request/result, real computed request hash, nil safe receipt, positive version). Label it solely as a retention storage probe: do not call it a successfully executed future stage, add a runtime API, or invent a domain success receipt. The migration already permits this shape (`AppDatabase.swift:4710–4731`). For both actual deletion branches, compare all operation IDs against the pre-delete set and require every row's payloads null, phase redacted, version advanced once, original hash preserved, and repeated deletion/redaction unchanged. Keep the existing 12-table rollback oracle and actual submit receipt assertions.

### P2 — Isolate operation retention failure from context retention failure

`DesktopGoalFoundationTests.swift:1816–1817` corrupts context and operation to live simultaneously. A read/replay implementation that rejects the context immediately but never checks operation rows would pass. Likewise, valid deletion with a redacted context and a leaked operation could be returned as `.deleted` without inspecting that row.

Minimal addition: after a real delete, leave context redacted with NULL contextJson and change only an owned operation to a schema-valid non-redacted phase with malformed `requestJson`/`resultJson`. Require `retentionIntegrity` from snapshot, list, original capture replay, exact original deletion replay, and direct repeated redaction, with the complete SQL snapshot unchanged. The malformed bytes discriminate retention-before-decode from a canonical decoder failure. Use the original saved old-head deletion command for each branch. The current combined corruption case remains valuable; do not replace it.

### P2 — Check safe receipt identity as well as strict JSON shape

`DesktopGoalFoundationTests.swift:1831–1855` checks an extra `originalText` key only after redaction. This establishes rejection of an unsafe shape, but not binding of a well-formed receipt to its owning input/goal/operation. A decoder-only check would accept a canonical actual receipt from another real submission. The existing valid-case byte equality (`1645–1653`) cannot detect this negative case.

Minimal addition: obtain a second valid receipt through actual `prepareSubmission` with the existing second-intent helper, then substitute its canonical bytes into the first carrier's safeReceiptJson. Test both before the first actual deletion (failure must roll back input/work/carrier changes) and after a valid deletion (snapshot/list, repeated redaction, and exact original deletion replay must fail closed without mutation). Exercise both deletion hooks where appropriate. This uses real receipt evidence and tests row ownership rather than introducing fake future execution. Retain the existing unexpected-key probe; include that shape in first-redaction rollback coverage as well, since validation is required before preserving safeReceiptJson, not merely on later reads.

## Sound coverage already present

- Scoped reads start from actual captures in two camps plus a legacy input; equal-time reverse insertion tests input-ID tie ordering, legacy exclusion and cross-camp rejection. Actual parse, conversion and session-opening commands produce the later goal/session/coach graph; no Provider or fabricated successful runtime record is used.
- Missing input, wrong goal/source and session/input joins, owned parsing aggregate/camp mismatches, coach goal/session payload mismatches with recomputed hashes, and hash corruption are independently injected. They cannot be satisfied merely by ignoring unrelated data. Read-only 12-table snapshots are compared around valid reads and corrupt reads.
- Archived, lifecycle-inactive and legacy-archived camps reject new captures while existing carriers remain readable and unredacted.
- Both actual deletion paths preserve the exact original command and old input head over pool close/reopen. Replay receipt equality and byte equality are checked; deleted capture replay must fail and not create work.
- Cancellation and completion triggers observe the relevant real mutations and force failure; all 12 table counts, raw row values and row hashes must roll back. Those tables include carriers, input/work/attempts, domain events/outbox/receipts, goal/session, mission and outcome (`773–786`). Successful deletion checks canonical safe receipt equality and absence of private marker text. Legacy no-carrier deletion/replay remains covered.

## Frozen inputs

| Input | SHA-256 |
| --- | --- |
| Read tests/types/stubs patch | `bd4f70214b9f781c7e09e72e436017545203ca5f9c729a8b1538475b9ef1e292` |
| Retention tests/stub patch | `e234fa17c4a12c95df141b290489798e84a4ff58f5ee0d43b75a5a9f5e2643dc` |
| Current DesktopGoalFoundationTests.swift | `3304461cebd23cd2e33681a7546c91101baa9dc7d534e3e19499f45b5b35eddd` |
| Current DesktopGoalWorkflow.swift | `b8bb594993714408bb0de0bcab62511815297e624cd77abb599896d493dfff37` |
| Current DesktopGoalWorkflowStore.swift | `2e5e9da896d8831e39ca81cdb1f87d4abf926acfdcf6df7d7531f2858a6aa7cd` |
| Unchanged InputGoalStore.swift | `bf055a97c13e6109a93239508949adad4cb963c26dfbf13a5ed664b2a8421afd` |
| Approved A1 plan | `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` |
| Task 1 brief | `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82` |

These additions strengthen existing retention requirements; they do not require a broader plan, new production surfaces, schema changes, or future-stage execution. Actual RED evidence and independent implementation/GREEN review remain separate gates.

## Independent test-preparation closure — 2026-09-06

**Current preparation verdict: PASS. All three P2 coverage findings above are closed; zero open P0 / P1 / P2 findings in this bounded preparation delta.** The original review and its then-open status remain unchanged as history. This closure accepts the strengthened test preparation and its meaningful RED evidence only. It does not approve production implementation, A1 completion, a later stage, or integrated acceptance.

### Reviewed delta and preservation

The reviewer read the original three findings, current strengthened source, retained patch, relevant existing helpers/retention tests, and the approved plan/Task 1 requirements. The exact original 1,882-line, 31-test source prefix remains byte-identical to `goal-foundation-read-retention-red1-before/DesktopGoalFoundationTests.swift` (`3304461cebd23cd2e33681a7546c91101baa9dc7d534e3e19499f45b5b35eddd`). Three tests and one negative-fixture helper were appended, bringing this file to 34 tests. No original test or assertion was replaced.

The first strengthening patch, `goal-foundation-retention-test-strengthening.patch`, remains historical at `f0c346e2f6de486c4ad9a8223a5ba67d006397a1564f949139dd26cd0996fe8e`; its resulting source snapshot is `goal-foundation-retention-strengthening-red1-before.swift`, hash `0cccc47508c56fd81fa7f4cf72b5beed9a268263b5efa4d7ef90c215d3fd0348`.

This reviewer found one residual detail in that first strengthening: both the submit and inert system operation were `prepared`, allowing an implementation restricted to `phase='prepared'` to evade the intended phase-independent assertion. The parent changed only the inert probe's phase to `failed`. A read-only exact string comparison verified that this one-word substitution is the entire subsequent source difference. The current `DesktopGoalFoundationTests.swift` hash is `120fa1c0f030ef7f3a92b10ecec1bf0adfb5a074f07782f105a3123f9c26bb56`.

### Finding-by-finding closure

1. **Every owned operation — CLOSED.** `retentionStrengtheningRedactsEveryOwnedOperation` (`DesktopGoalFoundationTests.swift:1900`) now exercises both actual deletion commands with the real prepared userMutation submit plus a separate failed system operation at version 7. The second row is explicitly inert schema-valid journal data, with canonical marker request, computed request hash, non-null result and nil safe receipt; it is never dispatched and claims no future-stage success. After deletion, the test requires two rows, matches each retained ID to its pre-delete row, checks every phase/payload/hash/version, requires versions 4 and 8 respectively, preserves the actual submit receipt bytes, and requires exact original delete replay plus direct repeated redaction to leave the full 12-table snapshot unchanged. Matching every resulting primary key to the two-row preimage, together with equal count, also rejects a lost or substituted operation. The changed `failed` phase catches both owner-only and prepared-only filtering.

2. **Operation failure independent of context — CLOSED.** `retentionStrengtheningRejectsLiveOperationUnderRedactedContext` (`:1980`) runs both original deletion branches, leaves the context NULL/redacted, then modifies only the owned operation to prepared with malformed request/result bytes. It directly compares context before/after that corruption, closes/reopens the database, and requires exact `retentionIntegrity` from snapshot, list, original capture replay, the saved original deletion command, and direct repeated redaction. The 12-table snapshot must remain unchanged. The negative arrangement helper at `:1886` first verifies that the actual domain command produced an input tombstone, then creates the schema-valid NULL/redacted carrier arrangement needed to isolate this failure before hooks exist. That helper is expressly negative test setup and is never used as evidence that the production hook succeeded. The original positive deletion tests and the first strengthening test remain responsible for proving actual redaction.

3. **Safe receipt ownership and first-redaction validation — CLOSED.** `retentionStrengtheningRejectsOtherActualCaptureSafeReceipt` (`:2017`) obtains a second receipt from real `prepareSubmission`, round-trips it through canonical decode, and injects its bytes into the first operation. Its pre-deletion matrix covers cancel/complete crossed with foreign actual receipt/unexpected `originalText` key. Each case requires exact `retentionIntegrity`, byte/value/count/hash equality of the full 12-table snapshot, and unchanged actual input/work state. Its post-deletion cases cover both branches, an independently arranged redacted carrier, foreign receipt injection, database reopen, and rejection without mutation from snapshot/list/direct redaction/original deletion replay. The existing extra-key-after-deletion test is preserved. These assertions discriminate strict JSON validation from binding an otherwise valid receipt to its real owner and reject committing a tombstone before either check succeeds.

### Meaningful, source-bound RED evidence

- `goal-foundation-retention-strengthening-red1.log` records a successful 26.13-second build followed by all three added tests executing, with 74 expected issues in 1.523 seconds. The all-operation case produces 28 issues from unchanged live payloads, unchanged versions and the explicit redaction stub. The operation-only case produces 10 issues: read/redaction stubs, capture returning `inputDeleted` instead of `retentionIntegrity`, and original deletion replay incorrectly succeeding in both branches. The receipt case produces 36 issues: all four pre-deletion cases incorrectly commit and change the snapshot/input/work, plus post-deletion stubs and incorrectly successful original deletion replay. These are missing-behavior failures, not compile errors or invalid fixture setup.
- `goal-foundation-retention-strengthening-red2.log` records the one-word failed-phase correction running through both deletion branches: successful 25.93-second build, one test, 28 expected issues in 0.273 seconds. In particular, log lines 26 and 40 observe the inert operation still in `failed`, while lines 29/43 observe its version remaining 7 instead of 8. The corrected fixture is reached in both branches and fails on the missing production behavior.
- RED1 process evidence records `swift run --jobs 2 RunTests --filter retentionStrengthening`, PID 77780, start `2026-09-06T22:25:53+08:00`, end `2026-09-06T22:26:24+08:00`, exit 1 and signal nil. RED2 records the `retentionStrengtheningRedactsEveryOwnedOperation` filter, PID 78138, start `2026-09-06T22:29:13+08:00`, end `2026-09-06T22:29:42+08:00`, exit 1 and signal nil.
- A read-only audit verified 305 before entries equal 305 after-OK entries and the full manifest for each run. The latest manifest also matched all current files using `shasum -a 256 -c --quiet`. RED1 remains evidence for its exact prior source; RED2 supplies the corrected phase probe's new evidence. No combined 34-test GREEN or production success is inferred.

| Evidence | SHA-256 |
| --- | --- |
| `goal-foundation-retention-strengthening-red1.log` | `bc878b8ec5a44d255e2400e936af5adf58e995ca8d4bb2887770b8b6307f8307` |
| `goal-foundation-retention-strengthening-red1-process.txt` | `eab31d4ee55f2aa58ab1fb7e3a126459a4e0dc5b8084f1cba1b84d3510abca5b` |
| `goal-foundation-retention-strengthening-red1-source.sha256` | `c3c581921be7d3c56ad521f74430f804308d0f70e3626b4b2bbe8834eb83855c` |
| `goal-foundation-retention-strengthening-red2.log` | `4100ebd42601698ad666142880da42c1ce6708996913e843d64b89be0f57f8e5` |
| `goal-foundation-retention-strengthening-red2-process.txt` | `eada3de72084cd20815d5f3c68b4901a8efaf358981ca410b905456d6af07f31` |
| `goal-foundation-retention-strengthening-red2-source.sha256` | `00ae01fc25d485e91e598aebeb5f023c091aeac18bbd5bba006519f3ffd74d28` |

### Boundary retained

`InputGoalStore.swift` remains `bf055a97c13e6109a93239508949adad4cb963c26dfbf13a5ed664b2a8421afd`; `DesktopGoalWorkflowStore.swift` remains `2e5e9da896d8831e39ca81cdb1f87d4abf926acfdcf6df7d7531f2858a6aa7cd`; `DesktopGoalWorkflow.swift` remains `b8bb594993714408bb0de0bcab62511815297e624cd77abb599896d493dfff37`. Snapshot/list/redact still throw the intentional `DesktopGoalReadNotImplemented.integrationCheckpoint` scaffold. The production hooks and integrity behavior still require implementation, GREEN verification and independent implementation review.

The current plan and brief retain their hashes from the original table. The reviewer only appended this closure, preserved the original review's first 7,443 bytes (SHA-256 `1ee07a118b38dbe8029224c4d49cfcb29c298639a80b5cab886744373c41bebf`), and checked frozen inputs again afterward. No compiler/test was run and no source, schema, fixture file, App, Provider or real database was modified by this reviewer. The separate migration-compatibility issue and its amendment are outside this preparation verdict. Review/verification skills require this separation between valid RED preparation and production acceptance.
