# P1-F1 Revision 3 Independent Plan Review 01b

> Reviewer: responsibility-isolated Codex reviewer  
> Date: 2026-08-27  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Boundary: Revision 3 plan, scope, pre-image, TDD, completion, and red-line
> review only; no product/test/plan/manifest change and no build or test run

## Conclusion

**CHANGES REQUIRED — 0 P0 / 2 P1**

Revision 3 correctly identifies and bounds the two original P0 implementation
defects: shared append-only privacy/graph integrity and the exact active Camp
write fence. Its file scope is minimal, its protected pre-images and outside
boundary are true, and its high-level direction is consistent with canonical
Stage §§8.1, 14.2, and 16. However, two persisted-contract decisions remain
open. Both must be frozen in one bounded plan-only amendment before tests or
product code change; otherwise the implementer must invent canonical bytes and
terminal sequencing, contrary to the repository protocol.

## Reviewed immutable inputs

| Input | Verified SHA-256 |
|---|---|
| Revision 3 `plan.md` | `5a904ebf3423ae232b7604ece52266ab59b781bcc5ecb138695b75dca53a95bb` |
| 96-line `scope-allowlist.txt` | `8d4e07d1ccda444a5b5c53ba7951e5514a07d01e9262990bbf2934cad9f50e73` |
| 46-line `entry-source-manifest.sha256` | `6048f075e2d09b21f5b6d4e56f929d81fe1ec72441e336cfaa98e356de8b9924` |
| canonical P1 Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |

The allowlist is unique, byte-sorted, LF-terminated, and contains exactly 70
canonical paths plus 26 task artifacts. Removing the five Revision 3 additions
reconstructs the exact Revision 2 scope delta. The three newly authorized
protected files match their declared pre-images, as do all nine frozen live
F1B/product-test inputs in §14.1.

The 46-line manifest is path-sorted and contains exactly the original 43
historical rows plus the three declared protected-file rows. The three new rows
match live bytes. A full historical manifest check is intentionally not green:
seven original rows have accepted F1A/F1B changes, exactly as §14.1 discloses;
none was overwritten to manufacture entry evidence.

## Independent boundary proof

The documented NUL-safe, lstat-mode/type-aware serializer reproduced:

```text
dirty_total=642
allowlisted_present_count=52
outside_count=590
outside_manifest_v1=ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee
```

Recomputing with only the five Revision 3 allowlist additions removed produces
the exact Revision 2 boundary:

```text
outside_count=593
outside_manifest_v1=ce12c40362a7a119241a5179eb52ebca6625c0a5c7daede7a29e8a10aaf90a94
```

Thus the three newly authorized protected files are the only live nodes removed
from the outside set; the two new artifact paths were absent.

## Findings

### P1-1 — Persisted vocabulary and canonical payload bytes are not fully frozen

Plan §§14.2 and 14.5 name the new enums and six event tags, but do not specify
all persisted/raw values and associated payload schemas needed to write exact
Codable and golden-byte tests:

- the seven engine event, result-code, and audit-code raw-value mappings are
  described as “corresponding” or “current `engine.*.v1` names” rather than
  enumerated as an exact closed table;
- `.toolActivity` has no associated-value shape or coding keys;
- the canonical resolved `sessionRef` that must carry both the internal and
  Store-derived external ID is not distinguished exactly from the caller input
  type that may carry only the internal ID; and
- “bounded” detail/prompt has no numeric UTF-8/scalar limit, while option
  uniqueness/nonempty validation does not say whether trimming or any other
  normalization participates in identity.

These choices change persisted request/command hashes and typed decoder
membership. They also make the promised golden bytes and over-bound/duplicate
counterexamples non-deterministic. The accepted Stage fixes the privacy and
typed-carrier boundary, but does not supply these omitted byte-level choices.

### P1-2 — Synthetic proposal identity and sequence semantics are not closed

Plan §14.5 correctly requires every kernel synthetic terminal to reference a
real durable zero-artifact proposal and §14.2 makes proposal recording a
first-class safe command. It does not freeze the executable per-branch matrix
for pre-dispatch failure, usage overflow, prepared cancellation,
external-effect-unknown, and recovery protocol error:

- deterministic terminal/proposal and command idempotency keys;
- exact terminal kind/subtype/reason and whether Attention is emitted;
- whether the proposal-record command and terminal command both execute inside
  the stated single outer transaction, with their separate receipt/event/outbox
  graphs; and
- proposal sequence and whether terminalization consumes
  `engine_execution.nextSequence`.

The last point is already a live ambiguity, not a hypothetical implementation
detail: frozen test 028 currently requires usage-overflow terminalization to
leave `nextSequence == 0`, while the frozen implementation consumes sequence
whenever a proposal is present. Adding the newly required real proposal admits
two incompatible implementations unless the plan explicitly binds synthetic
sequence consumption. Replay identity and safe result versions/counts also
depend on this choice.

## Sole necessary revision

Make one bounded plan-only amendment to §14, without expanding the 96-line
allowlist or touching product/tests:

1. add one exact engine contract table containing every new aggregate/command/
   event/result/audit raw value, each event tag's associated Codable fields and
   exact keys, the caller-only session selection shape, the resolved canonical
   request session shape, and exact scalar/collection validation limits and
   normalization rules;
2. add one exact synthetic-terminal table for all five sources, freezing
   proposal/terminal keys, kind/subtype/reason, Attention, disposition,
   proposal-record plus terminal command graphs, sequence value/consumption,
   and replay behavior; it must explicitly preserve or intentionally revise
   test 028's exact sequence assertion rather than leave that choice to code;
3. bind §14.6 counterexamples/golden assertions to those tables, retain the
   existing 017–042 identities, and keep the red-before-product and all current
   completion/red-line gates unchanged; then rehash the plan and request one
   incremental Review01b successor.

No schema, migration, F1C+, adapter, Board, UI, package, or additional source
file is needed for this amendment.

## Review boundary

- P0: none.
- P1: 2, both above.
- P2: none.

I did not run any Swift build/test, migration/matrix, package/App preview,
credential/provider, normal-state, Git-write, or external action. Product code
remains closed until a successor review reports **APPROVED — 0 P0 / 0 P1** on
the amended immutable inputs.

---

## Revision 3a Successor Review

> Successor reviewer: responsibility-isolated Codex reviewer  
> Date: 2026-08-27  
> Reviewed delta: plan §§14.8–14.10 only  
> Revision 3a `plan.md` SHA-256:
> `ae3162dbe24d2069009e7ffbc33e75b82c31c859a2a658db6bbbf543d7edf609`

### Successor verdict

**APPROVED - 0 P0 / 0 P1**

Revision 3a closes both P1 findings above without expanding scope. The original
Revision 3 plan at SHA-256
`5a904ebf3423ae232b7604ece52266ab59b781bcc5ecb138695b75dca53a95bb`
is the exact first 1,136 lines of the amended plan; §§14.8–14.10 are an
append-only, plan-only clarification.

### Closure of P1-1

Section 14.8 now freezes every new aggregate/command/event/result/audit case and
persisted raw value, the complete ordered branch-to-event/audit graph, safe-kind
spellings and membership, and exact event tagged-Codable key sets. It specifies
`.toolActivity(name:)`, whole-proposal terminal routing, flat usage fields,
extra/missing/null key rejection, and the terminal execution/sequence equality
check.

Caller session selection is now a non-Codable internal-ID-only type, while the
canonical request carries the separately Store-resolved internal/external
session reference with exact keys. Numeric scalar/UTF-8/collection limits,
original-byte identity, trimming rejection, raw-byte option uniqueness/order,
UUID/hash/date rules, and ask-user option taxonomy are explicit and executable.
No canonical byte, validation rule, or session authority remains for the
implementer to invent.

### Closure of P1-2

Section 14.9 freezes all five synthetic sources with exact terminal key `T`,
proposal command key `R`, terminal command key `C`, preconditions,
kind/subtype/reason/detail, Attention, and disposition. It requires the
proposal-record and terminal commands to run in one outer write transaction,
specifies each command's independent receipt/event/outbox graph and aggregate
versions, and rolls back both commands on any downstream failure.

Synthetic proposals use the real persisted ID/hash, exact zero-artifact bytes,
sequence `n`, and never consume `nextSequence`; usage overflow therefore keeps
test 028's exact zero-sequence/counter/no-partial-event assertions. Normal
adapter terminals and existing-proposal invalidation consume one sequence, so
test 036 remains distinct. Exact replay validates both command graphs and all
linkage before returning the original terminal receipt with zero writes; partial
or drifted graphs fail closed.

### Authority, test, and stage consistency

- Canonical Stage §16.2 request/session authority is preserved: callers choose
  only an internal session, Store derives scope and resolves the external ID
  before canonical request encoding, and safe JSON never receives it.
- Stage §§16.3–16.4 terminal taxonomy, proposal identity, resultHash linkage,
  urgent Attention branches, exact session resume, and recovery precedence are
  preserved. Deletion deferral remains lifecycle-first and outside the synthetic
  active-recovery matrix.
- Existing identities 017–042 remain exact. Section 14.10 binds their golden,
  bounds, session, two-command, rollback, replay, and sequence assertions without
  adding or renaming a test and retains red-before-product ordering.
- F1B creates no artifact staging/blob/GC behavior and no `attention_item`;
  F1C and F1E remain closed. No F2 permit, deletion supersession, redaction, or
  terminal authority is introduced.

### Reverified immutable boundary

```text
plan_sha256=ae3162dbe24d2069009e7ffbc33e75b82c31c859a2a658db6bbbf543d7edf609
allowlist_lines=96
allowlist_sha256=8d4e07d1ccda444a5b5c53ba7951e5514a07d01e9262990bbf2934cad9f50e73
entry_manifest_lines=46
entry_manifest_sha256=6048f075e2d09b21f5b6d4e56f929d81fe1ec72441e336cfaa98e356de8b9924
original_review01b_prefix_sha256=580928733aabf1b08a30b566de304399069cf6e02f5a9749c16e1f8bd8d737e5
outside_count=590
outside_manifest_v1=ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee
```

The two Review01b P1 findings are closed. Revision 3 tests-first work may open
under §§14.8–14.10 and all unchanged gates/red lines. This successor review ran
no Swift build/test, migration/matrix, package/App preview, credential/provider,
normal-state, Git-write, or external action.
