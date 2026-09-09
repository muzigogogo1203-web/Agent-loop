# P1 Stage Spec / Plan Independent Review — Review06

> Date: 2026-07-26
>
> Reviewer role: responsibility-separated fallback reviewer
>
> Independence: the reviewer did not participate in the bounded revision that
> produced this candidate, did not edit either frozen input, and did not repair
> findings during review. The only file written by this review is this report.

## Frozen inputs

- `p1-stage-spec.md`
  - SHA-256:
    `301dcb485b607e99f28be73fbabfa69a560e8d639bf3b0d1dea67d3a1b4aff2c`
- `p1-plan.md`
  - SHA-256:
    `8b2c5dd90f5e6c1a2e05a0804238dd4c0e660d898544ec55ace4a7c1011ac754`

Both hashes were independently recomputed before review. The repository
`AGENTS.md`, accepted master spec, P0 `blocked.md`, Review05, the complete
candidate migration/contract sections, and current source owners were read as
review inputs.

No Stage, Plan, master-spec, P0-status, product-code, prior-review, or test
fixture file was modified.

## Verdict

**CHANGES REQUIRED — 1 P0 finding and 1 P1 finding.**

The zero-P0/zero-P1 approval gate is not met. P0 acceptance remains closed,
P1-A1a is **not authorized for implementation**, and no P1 product-code slice
may start.

## Validation performed

### Worktree and product-code scope

- Branch observed: `codex/personal-ai-ranch-p0`.
- The worktree contains the existing P0 documentation changes.
- `git diff --name-only -- Sources Package.swift` returned no paths.
- No product-code delta was introduced by the frozen candidate or this review.

### SQL extraction, migration execution, and order

All eight normative `sql` fences were extracted in document order.

The final v16, v17, and GC fences were independently run from a populated v15
predecessor in memory under both available SQLite implementations:

| Check | SQLite 3.51.0 | SQLite 3.52.0 |
|---|---:|---:|
| v16 executes | pass | pass |
| claimed through-v16 trigger count | 56 | 56 |
| v17 executes | pass | pass |
| claimed through-v17 trigger count | 73 | 73 |
| GC query executes | pass | pass |
| `PRAGMA foreign_key_check` | 0 rows | 0 rows |
| `PRAGMA integrity_check` | `ok` | `ok` |
| FK target contains `_v16`, `_legacy`, or staging name | 0 | 0 |

The first v16 trigger occurs only after its final schema DDL, the first v17
trigger occurs only after its final schema DDL, and neither fence contains
table/index/alter/drop DDL after its first trigger. This closes the original
SQLite 3.52 unresolved-table ordering defect, but it does not prove that the
trigger graph is complete; R6-P0-1 shows that it is not.

The one normative Swift fence was type-checked with:

```bash
xcrun swiftc -swift-version 6 -warnings-as-errors -typecheck -
```

Result: exit 0.

### A–G and redaction counterexamples

The following transitions were rerun against an in-memory final schema:

- open `user_request`:
  `open -> withdrawn(camp_deleted)` succeeded only in
  `deletionRequested/quiescing`; early redaction aborted; finalizing redaction
  succeeded; later UPDATE and DELETE aborted;
- `schedule_fire`: erasing-phase redaction aborted; finalizing redaction
  succeeded; retained-column UPDATE and DELETE then aborted;
- `camp_provider_dispatch`: erasing-phase redaction aborted; finalizing
  redaction succeeded; later `requestHash` mutation and DELETE aborted;
- Ingestion/ActionCandidate: quiescing closeout to
  `discarded|dismissed(camp_deleted)` succeeded, retained正文 stayed locked,
  early redaction aborted, finalizing typed tombstones succeeded;
- `rumination_result`, `knowledge_source_link`, Ingestion, and ActionCandidate:
  post-redaction retained-column UPDATEs aborted.

Schema assertions also confirmed the candidate contains the promised fields
and shapes for:

- user-request lifecycle and redaction discriminators;
- schedule/provider/ingestion/rumination/source-link/candidate redaction;
- `approval_grant_use.adapterOperationId`;
- Engine cancellation and proposal invalidation reasons;
- active/tombstoned `artifact_storage_origin`;
- verified-outside and unresolved detach evidence;
- pending proposal-blob cleanup states and GC content-hash roots.

### Append-only carrier inventory

The executable through-v17 `sqlite_master` graph was compared with the
normative list in Stage lines 2006–2022. Result:

| Normative append-only table | UPDATE guard | DELETE guard |
|---|---:|---:|
| `durable_work_attempt_event` | yes | yes |
| `domain_command_receipt` | **no** | **no** |
| `domain_event` | **no** | **no** |
| `verification_record` | yes | **no** |
| `verification_invalidation` | **no** | **no** |
| `acceptance_record` | yes | **no** |
| `external_operation_receipt` | yes | **no** |
| `memory_dependency` | **no** | **no** |
| `discussion_turn` | yes | yes |

Concrete raw-SQL results are recorded in R6-P0-1.

### Current-code implementability

The current Feed/Rumination deletion path and its UI/protocol were inspected
against the v16 unconditional DELETE guards. The existing operation was then
executed against the final schema in memory:

```text
DELETE rumination_result  -> abort: rumination result may not be deleted
DELETE action_candidate   -> abort: candidate may not be deleted
DELETE ingestion_item     -> abort: ingestion may not be deleted
```

This produces R6-P1-1.

## Review05 finding disposition

| Review05 finding | Review06 disposition |
|---|---|
| R5-P0-1 pending proposal deletion deadlock | **Closed at plan level.** The specialized proposal supersession preserves proposal identity, terminalizes projections without new side effects, registers every declared/prepared artifact in the cleanup ledger, and makes nonterminal cleanup a GC root/finalize blocker (Stage 1366–1408; Plan 2143–2151, 2247–2253). |
| R5-P0-2 legacy artifact permanent blocker | **Closed at plan level.** Fixed confirmation, trusted verifier evidence, every unresolved reason, typed retry/detach authority, detach-only external/unknown handling, and managed-only unlink authority are specified (Stage 1421–1426, 1470–1558; Plan 2157–2184, 2275–2282). |
| R5-P0-3 incomplete erasure/origin/typed shape | **Closed for the enumerated shape defects.** Origin tombstones, adapter operation ID, Engine reason fields, user-request/ingestion/candidate discriminators, exact JSON sentinels, and redacted-first readers are present (Stage 1560–1637; Plan 2189–2200, 2256–2264). |
| R5-P0-4 mutable audit evidence | **Not closed.** Existing post-redaction full-row locks are materially improved, but seven normative append-only carriers remain mutable and/or deletable in the executable graph; see R6-P0-1. |
| R5-P1-1 SQLite 3.52 trigger creation order | **Original ordering defect closed.** Both SQLite versions execute the current order and all trigger statements follow the phase barrier. The separately required append-only graph makes the fixed 56/73 counts internally inconsistent; that completeness defect is included in R6-P0-1. |

## A–G disposition

| Closure item | Result | Evidence |
|---|---|---|
| A — open request closeout | **PASS** | Exact claim-bound withdrawal, answer race, open-only quiescence, finalizing redaction, replay/conflict, and tests are specified (Stage 1318–1331; Plan 2112–2120, 2235–2236). Raw transition counterexamples passed. |
| B — schedule redaction | **PASS** | Typed discriminator, exact immutable scope, first-redaction validator, post-lock, and DELETE guard exist (Stage 1590–1598, 4219–4270; Plan 2198–2200, 2271–2273). Erasing failed and finalizing succeeded in raw SQL. |
| C — provider finalizing-only | **PASS** | Provider first redaction now requires `deleting/finalizing`, followed by an unfiltered post-redaction lock and DELETE guard (Stage 3910–3962; Plan 2185–2188, 2272–2273). Raw SQL reproduced the intended phase split. |
| D — v16/v17 graph, barrier, order | **CHANGES REQUIRED** | Statement order and SQLite 3.52 portability pass, but the executable graph omits eleven triggers required by the Stage's append-only rule, so the claimed 56/73 counts cannot describe the required graph. See R6-P0-1. |
| E — Ingestion closeout | **PASS for Camp deletion closeout** | Claim-bound work/provider closeout, no-work queued handling, CAS races, deletion terminal status, finalizing-only redaction, and tests are exact (Stage 1333–1355; Plan 2121–2129, 2220–2222, 2241–2243). The separate ordinary-user deletion compatibility gap is R6-P1-1. |
| F — typed tombstones and locks | **CHANGES REQUIRED only for append-only audit carriers** | The requested user-request/schedule/ingestion/rumination/candidate/source-link/Grant/Engine/origin fields and mutable-carrier locks are present and passed targeted checks. The general append-only carriers do not match the same normative immutability contract; see R6-P0-1. |
| G — reserved Grant release | **PASS** | Only exact `reserved` use with zero dispatch/receipt/operation evidence can be released by claim-bound F2 authority; Grant count/status/version stay unchanged and dispatched uses retain their existing resolution paths (Stage 1061–1075, 1111–1117, 1357–1360; Plan 2130–2142, 2237–2240). |

## Other required dispositions

- **Pending proposal / blob / GC:** PASS at plan level. Proposal identity is
  preserved, ordinary Engine authority is not broadened, cleanup is
  crash-recoverable, nonterminal cleanup blocks finalize and remains a live
  content-hash root, and `proposalHash` is excluded from the exact GC query.
- **Legacy artifact detach-only / origin:** PASS at plan level. Explicit and
  verified-outside workspace references never enter unlink; incomplete roots,
  missing unknown files, symlinks, permission failures, and drift remain
  unresolved until trusted retry or user detach-only authority.
- **Privacy matrix / redacted-first:** PASS for the enumerated private-field
  matrix and typed decoder contract, subject to R6-P0-1's audit-carrier
  immutability failure.
- **Post-redaction locks:** PASS for every mutable carrier sampled and for the
  complete 23-table `redactedAt`/`payloadRedactedAt` inventory. Append-only
  carriers without `redactedAt` and three redacted append-only carriers still
  fail the separate mandatory DELETE/UPDATE rule in R6-P0-1.
- **Allowed files / owners:** broadly implementable for A–G and the Review05
  closure. R6-P1-1 is the one current owner whose public behavior has no
  authorized post-v16 disposition.
- **Open Questions:** both documents say exactly `无。`; findings below show
  that two implementation decisions/contracts are nevertheless unresolved.
- **Product code:** zero diff.

## P0 finding

### R6-P0-1 — The executable migration fences omit mandatory append-only guards, so durable audit truth can be rewritten or deleted

Stage lines 1997–2022 make §18 the normative database authority and require
both `<table>_reject_update` and `<table>_reject_delete` for nine named
append-only tables. When v16 substitutes a finalizing-only UPDATE exception,
the DELETE guard must remain.

The literal SQL fences do not implement that contract:

- v12 ends after the durable attempt-event indexes without installing its
  two introduction-time guards (Stage 2185–2203);
- v14 creates `domain_command_receipt` and `domain_event` without either guard
  (Stage 2313–2352);
- v15 creates `verification_invalidation` without either guard and creates
  Verification, Acceptance, and external receipts without their required
  introduction-time pair;
- v16 creates `memory_dependency` without either guard
  (Stage 3848–3866);
- v16 installs replacement UPDATE triggers for Verification, Acceptance, and
  external receipts but never installs/preserves their DELETE triggers
  (Stage 4574–4678);
- `domain_command_receipt`, `domain_event`, `verification_invalidation`, and
  `memory_dependency` still have no UPDATE or DELETE guard through v17.

This is executable, not theoretical:

```text
domain_command_receipt UPDATE -> changes() = 1
domain_command_receipt DELETE -> changes() = 1
domain_event UPDATE           -> changes() = 1
domain_event DELETE           -> changes() = 1
remaining dangling typed scope rows after event DELETE -> 1
external_operation_receipt DELETE -> changes() = 1
```

The external receipt DELETE succeeded under both SQLite 3.51 and 3.52.

The fixed counts expose the same contradiction. A required final graph has
eleven more guards than the executable graph: through-v16 would contain 67
triggers and through-v17 84, not 56/73. Conversely, keeping 56/73 necessarily
omits mandatory audit protection. An implementer cannot satisfy the normative
append-only rule, literal fences, and fixed-count gates simultaneously.

This is P0 because command receipts, domain events, verification
invalidations, acceptance/verification evidence, external-operation receipts,
and memory provenance are the audit truth used for replay, deletion,
acceptance, permission, and traceability. Allowing raw mutation/deletion makes
those guarantees unverifiable and can leave typed scope rows dangling.

Required closure:

1. Install both standard abort guards in each table's introducing migration,
   not only in v16/F2.
2. Before the v16 durable attempt-event UPDATE exception is installed,
   explicitly drop/replace its standard UPDATE guard; preserve its DELETE
   guard. Apply the same replace-update/preserve-delete rule to Verification,
   Acceptance, and external receipts.
3. Add the missing final guards for `domain_command_receipt`, `domain_event`,
   `verification_invalidation`, `memory_dependency`, and the three missing
   DELETE guards.
4. Recompute and update the v16/v17 exact trigger counts in both Stage and
   Plan.
5. At every introducing-slice migration gate and in both SQLite lanes, insert
   a legal row for every one of the nine tables and prove ordinary UPDATE and
   DELETE abort. For the five deletion-redactable tables, also prove exact
   first finalizing UPDATE succeeds while wrong phase, second/no-op,
   extra-column UPDATE, and DELETE abort.
6. Prove rejected `domain_event` DELETE cannot leave or create a dangling
   `camp_event_scope`.

## P1 finding

### R6-P1-1 — v16 permanently disables the current user-facing Feed/Rumination delete operation, but the plan never chooses a replacement

The current product exposes:

- `IngestionDeletionScope.resultOnly|sourceAndResult|everythingIncludingProjection`
  (`CodingRanchContracts.swift:195-200`);
- a public `deleteIngestion` protocol command
  (`CodingRanchContracts.swift:245-253`);
- UI copy promising “删除原文和反刍结果”
  (`RuminationViews.swift:508-514`, also 662–664);
- an implementation that physically deletes `rumination_result`,
  `action_candidate`, and `ingestion_item`
  (`CodingRanchStoreAdapter.swift:198-216`).

The v16 fence instead installs unconditional permanent DELETE guards on
`ingestion_item`, `rumination_result`, `action_candidate`, and
`knowledge_source_link` (Stage 4103–4217). Its only redaction exception is the
Camp-deletion `deleting/finalizing` path; there is no ordinary active-Camp user
deletion transition.

The current operation therefore deterministically aborts after E. Plan B
allows several UI/adapter files only for error visibility and application
seams; it never authorizes removal or semantic replacement of this feature.
Plan E installs the guards but says deletion workflow is not exposed there
(Plan 1457–1459). F2 specifies only confirmed Camp retirement. Under the
repository's no-unplanned-decisions rule, the implementer cannot decide
whether the user command should disappear, become a typed tombstone/redaction
command, or retain some other deletion semantics.

Required closure:

1. Decide the post-v16 semantics of all three `IngestionDeletionScope` cases.
2. Assign the decision to an exact slice before or with v16 and list every
   required owner, including contracts, adapter/controller, live host, UI
   wording, records/store, and tests.
3. If deletion remains, define a typed active-Camp user-deletion authority,
   terminal state/tombstone, provenance behavior, exact fields, races,
   idempotency, and one-shot guards without weakening Camp-deletion evidence.
4. If it is removed or deferred, remove/disable the protocol and UI promise
   before v16 and define the replacement UX.
5. Add migration-and-runtime tests for all three scopes, materialized/source
   link blockers, retries/replay, and post-v16 UI behavior.

## Final gate

- P0 findings: **1**
- P1 findings: **1**
- P1-A1a implementable now: **No**
- P0 acceptance may continue now: **No**
- Product-code diff: **0 paths**
- Verdict: **CHANGES REQUIRED**

The next action is another explicitly authorized bounded Stage/Plan revision
and responsibility-separated review. Until a frozen candidate reaches
zero P0 and zero P1, keep P0 acceptance and all P1 implementation closed.
