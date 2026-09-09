# Desktop A2 Entry Amendment — M4 and M7 Only

Date: 2026-09-09  
Status: source-preparation artifact for independent review. It does not amend
the canonical plan until approved and contains no source or execution evidence.

## Scope and preserved decisions

This amendment closes only the current A1 carrier drift found after the approved
`goal-driver-plan.md` review and refreshes its source-inventory gate. M1-M3 and
M5-M6 remain unchanged. In particular, M3's internal throwing provider path
propagates ledger/storage/integrity errors; those errors never become a
model-level `.failed` outcome.

Preserve all of the following:

- the two existing `desktop_goal_context` / `desktop_goal_operation` tables;
- all A1 capture request, result, receipt, hash, and snapshot bytes;
- existing accepted inert system rows and their retention behavior;
- the approved deterministic attempt identity
  `coach-attempt:<workId>:<attempt>`;
- exact claim/reservation atomicity, typed transitions, consent/accounting,
  terminal receipt, and failure semantics already specified by M4; and
- the frozen 206-entry historical manifest and live/enumerated count of 102.

No SQL migration, table, column, index, public closure change, fallback decoder,
or arbitrary operation-ID allowance is authorized here.

## Verified current work-ID authority

The A2 coach path already has a canonical-UUID work-ID boundary:

- `DurableWorkStore.enqueue(..., in:)` creates a new generic work row with
  `UUID().uuidString` (`DurableWorkStore.swift:55-165`, lines 126-128).
- `CoachUnderstandingStore.enqueueCoachTurn` uses that exact generic enqueue
  path for `.coach` work (`CoachUnderstandingStore.swift:1377-1417`).
- `WorkClaimV1.init(claim:)` rejects a non-canonical work UUID before a claim is
  admitted to domain commands (`InputEnvelope.swift:287-305`).
- `ControlWorkerCommandEnvelopeFactoryV1.make` independently validates the
  stored work ID as a canonical UUID (`CommandEnvelope.swift:190-224`, line
  207).

Therefore A2 must derive an attempt operation ID only after loading the real
typed work/attempt and passing the existing claim/envelope graph validation. It
must not accept a caller-supplied attempt operation ID as authority.

## M4 amendment

### Exact attempt-ID grammar

Add one small domain helper local to the desktop goal workflow contract:

```swift
package enum DesktopCoachAttemptOperationIDV1 {
    package static func make(workId: String, attempt: Int) throws -> String
    package static func components(of value: String) throws
        -> (workId: String, attempt: Int)
}
```

Required behavior:

1. `make` validates `workId` with
   `CanonicalContractCodingV1.validateCanonicalUUID`, validates `attempt > 0`,
   and returns exactly `coach-attempt:<workId>:<attempt>` using the canonical
   decimal representation (no sign or leading zero).
2. `components` accepts exactly two components following the fixed
   `coach-attempt:` prefix, validates the UUID and positive canonical decimal,
   then calls `make` and requires byte equality with the input. It is a
   persisted-row validator, not an alternate writer.
3. `claimEligible` constructs the ID with `make` from the typed persisted work
   ID and the attempt returned by the in-transaction `DurableWorkStore.claim`.
   There is no operation-ID parameter on the claim API.
4. The reservation insertion requires the derived ID to be absent. Any
   pre-existing row is a typed replay/conflict error and rolls back the entire
   claim, reservation, continuation consumption, event, and journal
   transaction. Later transition/read paths require the stored
   input/owner/kind/request bytes and hash to match the typed identity; only the
   already-approved identical terminal-receipt replay remains idempotent.
5. Current UUID-only validation remains unchanged for A1 capture and legacy
   inert rows. Only the exact coach-attempt discriminator uses this grammar;
   arbitrary strings stay invalid.

### Closed operation payload dispatch

The A1 store must stop treating every non-submit row as an empty capture-stage
array. Add one closed discriminator used consistently by live snapshot, list,
redact, and deleted-retention validation:

| Stored owner/kind | Required contract |
| --- | --- |
| `userMutation` / `submit` | Existing A1 capture loader and receipt validator, unchanged. |
| `coachAttempt` / `coachAttempt` | A2 typed attempt request, append-only typed transitions, always-present closed retention witness, and derived attempt ID. |
| `system` / `coachContinuation` | The M4 typed local-owner continuation request/result/receipt and canonical UUID command operation ID. |
| Previously accepted other owner/kind pairs | Existing inert-row contract only: canonical UUID ID, canonical request bytes/hash, empty `[DesktopGoalSealedStageV1]` result, and the existing optional capture-safe-receipt validation. No new executable interpretation. |

The two exact A2 `kind` strings above become part of the typed wire contract.
Unknown rows never fall through to an A2 decoder. The legacy-inert branch is
not broadened beyond what the current A1 implementation already accepts.

Keep the A2 validation surface small and reusable by the store and tests:

```swift
package struct DesktopCoachAttemptCarrierV1: Sendable, Equatable {
    package init(operationId: String, inputId: String,
        phase: DesktopGoalOperationPhaseV1, requestJson: String?,
        resultJson: String?, safeReceiptJson: String?,
        requestHash: String) throws
}
```

This initializer explicitly throws on a nil witness before performing the
exact-key typed decode and all cross-field rules below. It does not write rows,
change retention state, or authorize execution.
The store constructs it only after the exact owner/kind discriminator matches.

For a `coachAttempt` row:

- live `prepared` rows decode the typed attempt request and exactly one initial
  `reserved` transition, optionally followed by `dispatching`; the only next
  transition is the single M4 terminal transition. The request's
  `workId`/`attempt` must reproduce the stored row ID;
- `safeReceiptJson` is never nil for an A2 attempt. Reservation inserts a closed
  `DesktopCoachAttemptRetentionV1` progress witness in the same transaction;
  dispatch and terminal CAS update it in the same transaction as the journal.
  Its exact-key payload contains only the approved safe schema/discriminator,
  operation/input/work/attempt IDs, request hash, last transition kind/hash,
  source operation phase, versions/times, and its canonical witness hash. It
  contains no prompt, response, endpoint, credential, or error description;
- the witness discriminator is closed: progress is valid only with source phase
  `prepared` and last transition `reserved` or `dispatching`; terminal is valid
  only with source phase `committed` or `failed`, last transition `terminal`,
  and the approved safe subset of `DesktopCoachTerminalReceiptV1`. Every common
  identity/hash must cross-check the live request/journal while those carriers
  exist;
- redaction removes request/result but preserves the exact witness bytes. A
  redacted row requires a witness, validates its canonical self-hash, derives
  the row ID again from the witness's typed work ID/attempt, and validates the
  witness's recorded source phase/last transition. Progress therefore proves a
  formerly nonterminal redaction, while terminal proves a formerly terminal
  redaction. Neither is executable authority;
- clearing `safeReceiptJson` after any A2 redaction is always corruption.
  Clearing the terminal subset, relabeling terminal as progress while retaining
  terminal source phase/transition, or changing any retained identity/hash also
  fails. A syntactically valid progress witness is not inferred merely from a
  missing terminal receipt;
- malformed transition order, duplicate terminal, phase/transition mismatch,
  missing witness, request/result/hash mismatch, or receipt
  provenance mismatch throws the existing foundation integrity family (or the
  narrowly typed A2 integrity error approved during implementation); and
- the snapshot gains only the typed A2 projection needed to inspect the attempt
  and continuation carriers. Existing A1 snapshot fields and encoded carrier
  bytes do not change.

### M4 test-first sequence and exact oracles

1. **Pre-implementation carrier RED, no new domain symbols.** Insert through the
   test database a plan-shaped `coachAttempt` row whose ID is
   `coach-attempt:<actual coach work UUID>:1`, with canonical request bytes/hash
   and a raw canonical initial-reserved transition plus progress witness. Call
   the current `snapshot`. The retained RED must be the current UUID/carrier
   rejection, not fixture setup or missing graph data. Rescue removes the
   injected row and proves the A1 snapshot still reads.
2. **ID grammar unit GREEN.** For the actual coach work produced by the domain
   command, require `work.id == UUID(uuidString: work.id)?.uuidString`; require
   `make(workId: work.id, attempt: 1)` equals the exact expected string and
   `components` round-trips. Reject lowercase/noncanonical UUID, zero/negative
   attempt, leading-zero attempt, extra separators/suffix, wrong prefix, and
   whitespace without normalization.
3. **Atomic reservation GREEN.** Run real A1 capture plus eligible coach claim.
   Require the inserted row ID equals the helper result from the returned typed
   claim; its owner/kind/request hash match; work attempt/event, reservation,
   continuation consumption, and journal all commit together. Abort insertion
   with the existing temporary-trigger strategy and require every compared row
   and count remains byte-identical to before.
4. **Conflict rejection.** Seed the derived ID with one mismatch at a time
   (input, owner, kind, request work ID, attempt, request bytes/hash). Require
   the typed conflict/integrity error and exact rollback of work, attempt/event,
   reservation, continuation, and journal. No provider factory or run starts.
5. **Typed snapshot/transition checks.** Require reserved and dispatching rows
   round-trip through snapshot/list with exact transition order. Require one
   terminal transition plus matching phase/terminal witness to round-trip.
   Reject
   skipped/reordered/duplicate terminal transitions, phase disagreement,
   missing witness, and cross-work/context/runtime/request hashes.
6. **Carrier-only A2 retention codec.** Exercise the same small typed
   `DesktopCoachAttemptCarrierV1` initializer/decoder used by the store with
   explicitly labelled synthetic carrier values; this is not a normal input
   deletion test. Require live reserved/dispatching/terminal carriers to become
   redacted carrier values only by removing request/result and preserving the
   exact progress/terminal witness bytes. Require both progress and terminal
   redacted carriers to decode. After a terminal redacted carrier has decoded,
   set `safeReceiptJson` to nil and require corruption; separately remove its
   terminal subset, change its discriminator/source phase/last transition, and
   tamper every retained identity/hash, requiring corruption each time. This
   pure carrier codec has no authority to mutate `input_envelope` state.
7. **Truthful deletion boundaries.** Keep the existing real A1 tombstone and
   `DesktopGoalWorkflowStore.redact` integration tests, including current A1
   byte assertions and
   `retentionStrengtheningRedactsEveryOwnedOperation`; its failed,
   empty-result, nil-receipt inert system row remains accepted unchanged. In a
   separate real A2 graph that has reached `goalCreated` and contains a live
   attempt, call the ordinary `InputGoalStore.requestDeletion` command and
   require `P1ContractValidationError.invalidMembership`, no carrier/input/work
   mutation, and no claim that A2 deletion/redaction succeeded. This is the
   current explicit domain boundary at `InputGoalStore.swift:631-654`, lines
   647-651. Do not directly rewrite the input status/retention state to
   manufacture a positive flow and do not expand deletion authority in A2.
8. **Continuation discriminator.** Require only exact `system` /
   `coachContinuation` rows decode as the typed one-use receipt. Replays cannot
   grant another reservation; wrong owner/kind/prior attempt/terminal hash fails
   closed. An unrelated legacy inert system row remains metadata-only.

The first RED is meaningful against the current call site. Later tests may name
new typed APIs only after their minimal declarations exist; compilation failure
from merely absent test-only symbols is not accepted as the behavioral RED.

## M7 amendment

At the A2 inventory step:

1. Name the exact four-file set with the actual entry date, not the draft
   `desktopCodingClosureA2DriverSuccessorFiles20260906` suffix.
2. Preserve the four approved paths and no fifth source file.
3. Assert count/exact membership, regular non-symlink status, and empty
   intersection with every frozen/historical set plus:
   `desktopCodingClosureRuntimeDiagnosticsSuccessorFiles`,
   `desktopCodingClosureA1FoundationSuccessorFiles20260905`,
   `desktopCodingClosureBlockingProgressSuccessorFiles20260908`, and
   `desktopCodingClosureNativeCLIFixtureSuccessorFiles20260909`.
4. Add only the A2 set to the enumerated-source exclusion near
   `DurablePlanningTests.swift:5781-5797`.
5. Require frozen 206, live 102, enumerated 102, sorted equality, every
   historical hash, and all existing successor identities to remain unchanged.

The M7 test is green only when the exact four files exist and all those
assertions pass. It does not alter or repin any previously frozen source.

## Entry gate

Independent review must approve this amendment before it is merged into the
canonical plan or used to authorize A2 writes. Runtime Task3 ownership remains
independent and is neither modified nor certified by this artifact.
