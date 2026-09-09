# A2 Goal Driver Entry Amendment — Independent Review Record

Date: 2026-09-09  
Review type: responsibilities-separated plan review; no A2 implementation or
runtime execution was approved by this review.

## Verdict

Approved as the controlling amendment for only M4 and M7 of
`goal-driver-plan.md`. The amendment closes the post-A1 interface drift without
changing M1-M3 or M5-M6, widening SQL, changing A1 capture bytes, or expanding
input-deletion authority. This verdict does not itself grant A2 source entry.

## Findings closed

1. **Deterministic attempt ID versus UUID-only A1 validation.** The amendment
   verifies the actual coach work-ID authority and requires the operation ID to
   be derived only from the typed canonical work UUID and positive attempt as
   `coach-attempt:<workId>:<attempt>`. It adds a closed validator for that one
   owner/kind pair, keeps UUID-only validation for A1/inert rows, and rejects
   pre-existing or cross-identity conflicts transactionally.
2. **Capture-only A1 snapshot and retention decoder.** The amendment adds a
   closed owner/kind carrier discriminator for A1 capture, A2 coach attempt,
   A2 continuation, and the already accepted inert-row contract. A1 request,
   result, receipt, snapshot, and retention bytes remain unchanged; unknown
   rows do not become executable A2 payloads.
3. **Nil witness boundary.** `DesktopCoachAttemptCarrierV1` accepts the stored
   optional `safeReceiptJson` boundary and explicitly rejects nil internally.
   Every A2 attempt has an always-present, exact-key progress-or-terminal
   retention witness. Redaction preserves it byte-exactly, so a formerly
   nonterminal redaction is distinguishable from a terminal witness that was
   cleared or malformed. The post-redaction nil/terminal-subset/discriminator/
   identity/hash regressions are explicit.
4. **Truthful deletion evidence.** The positive A2 redaction check is labelled
   carrier-only codec evidence. Real A1 tombstone integration remains the
   allowed deletion path, while a real `goalCreated` A2 graph must prove the
   existing `InputGoalStore.requestDeletion` rejection and zero mutation. The
   plan does not manufacture input state or add deletion authority.
5. **Current source inventory.** M7 retains the exact four approved A2 paths
   and frozen 206/102 accounting while adding intersections with the later
   blocking-progress and native-CLI-fixture successor sets.

## Hash and scope record

```text
7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d  original independently approved historical goal-driver-plan.md
032ef4ff906b6acc74025ae3e2cdb9edf51c79eb44c145c0888ae13a4ae830f8  post-A1, pre-entry-amendment goal-driver-plan.md
5e611af2e5217f60620fb46fc6a84682b758379b84e78299366a2db331c8762a  approved goal-driver-entry-amendment.md
3ce87fa3b6daffcf98024b339b73c695b7f051eaf9eaafbcb29e63dfb70c3351  goal-driver-plan.md after pointer-only M4/M7 references
```

The original plan approval remains bound to its historical `7eed55fa...` hash.
Before this entry amendment, the separately accepted A1 narrative-text
amendment had already changed source fact 2 for the exact-key,
constructor-validating `UnderstandingContentV1` and `CoachAnswerV1` decoder;
that legitimate prior amendment is retained in the `032ef4ff...` pre-entry
state. The archived M4/M7 amendment was applied to that state to produce the
`3ce87fa3...` pointer update. It controls only the clauses named above and does
not re-approve, reinterpret, or revert the rest of the plan.

## Gates retained

The runtime authoritative unfiltered full-suite gate is still required and is
not cleared by this documentation review. A2 entry, source preimages, staged
RED/green execution, independent implementation review, strict App build, A3
application lifecycle binding, and later product acceptance remain separate
gates. This documentation step ran no build, test, application, process signal,
Provider call, runtime or user-data mutation, commit, push, or release.
