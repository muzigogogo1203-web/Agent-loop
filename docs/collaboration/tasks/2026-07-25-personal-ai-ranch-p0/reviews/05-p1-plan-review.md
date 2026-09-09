# P1 Stage Spec / Plan Independent Review — Authorized Round 5

> Date: 2026-07-25
>
> Reviewer role: responsibility-separated fallback reviewer
>
> This is the one additional bounded review explicitly authorized by the ranch
> owner after Round 4. It does not authorize another silent revision/review
> cycle.

## Frozen inputs

- `p1-stage-spec.md`
  - SHA-256:
    `1124c80ebaaadd6da427540dec19b89dabfc950405975146b2ac7cfa641c504d`
- `p1-plan.md`
  - SHA-256:
    `94828d327dff35e56c7d2c1eb2225b1d4ae02643fcaa613a8883cc5b224ceecd`

Both hashes were independently recomputed before and after this review and
matched exactly. The accepted master spec, repository `AGENTS.md`, P0 evidence,
Round 4 review, current source owners, normative SQL/Swift fences, and phase
gates were read as review inputs. No product code, plan, stage spec, master
spec, P0 evidence, or prior review was modified.

## Verdict

**CHANGES REQUIRED — 4 P0 findings and 1 P1 finding.**

P1-A1a is **not authorized for implementation**. P0 acceptance remains closed,
all P1 product-code implementation remains closed, and the repository's
long-running implementation Goal may not advance into A1a.

This was the ranch owner's final currently authorized extra review round. The
reviewer is not requesting or authorizing another revision. Any further
revision/review requires a new ranch-owner decision.

## Validation performed

### Product-code scope

`git diff --name-only -- Sources Package.swift` returned no paths. The current
P0 document worktree remains dirty, but there is no P1 product-code change in
the frozen review input.

### SQL fences and populated fixtures

All eight `sql` fences were extracted in document order. With SQLite 3.51.0,
foreign keys enabled, released predecessor stubs, two Camps, and populated
archived-Camp `running`, `queued`, and `retryScheduled` work plus open/closed
attempt/event fixtures:

- SQL fences executed: **8/8**
- archived nonterminal work after v16: **0**
- archived running/queued/retry rows became `canceled`
- the archived open attempt became
  `canceled:work_canceled:terminalWorkVersion=2`
- one matching cancellation event was appended
- active-Camp queued work remained queued
- all copied work received `campLifecycleVersion=1`
- a populated `domain_event` received one exact Camp scope row
- `PRAGMA foreign_key_check`: **no rows**
- `PRAGMA integrity_check`: **ok**

That result proves the 3.51 structural path and populated archived-work
backfill only. It does not prove lifecycle completion, erasure, ownership, or
portable migration ordering.

The same normative fence order fails under SQLite 3.52.0, as recorded in
R5-P1-1.

### Swift fence

The one Swift fence was type-checked with Swift 6, warnings as errors,
Foundation, and the two specified `CanonicalJSONV1` validation signatures:

```bash
xcrun swiftc -swift-version 6 -warnings-as-errors -typecheck -
```

Result: **exit 0**.

### Redaction counterexamples

The complete DDL was also exercised with deleting/finalizing fixtures.

1. After the first legal legacy-event redaction, repeating the exact marker
   update returned `changes() = 1` again instead of aborting.
2. An already-redacted terminal `camp_provider_dispatch` row accepted a later
   `requestHash` mutation because the trigger only runs when `requestJson` or
   `redactedAt` changes.

These are schema-level counterexamples, not inferred implementation concerns.

## Round 4 finding disposition

| Round 4 finding | Round 5 disposition |
|---|---|
| R4-P0-1 retirement authority/recovery | **Not closed.** Opaque permits, self-exclusion, failed-work replacement, and the non-replayable/no-proposal closeout are now specified, but a pending terminal proposal still has no deletion-authorized closeout; see R5-P0-1. |
| R4-P0-2 privacy erasure | **Not closed.** Many omitted fields and append-only exceptions were added, but the artifact-origin terminal shape and known private/ref columns remain unresolved, and retained audit evidence remains mutable after redaction; see R5-P0-3 and R5-P0-4. |
| R4-P0-3 legacy scope | **Closed.** Chat/note/event scope rules, exhaustive resolver requirements, post-v16 ownership, rollback cases, and tests are now assigned. |
| R4-P0-4 owner/provider gap | **Closed at plan level.** Current direct mutation owners, Guide/distillation provider dispatch, managed reports, registries, and source sentinels are now enumerated across E/F1/F2. |
| R4-P1-1 candidate status | **Closed.** Ingestion and ActionCandidate quiescence/deletion statuses are separated and individually tested. |
| R4-P1-2 Outcome command drift | **Closed.** `recordInitialOutcome` and `recordNewOutcomeVersion` now have distinct authoritative transitions and tests. |
| R4-P1-3 GC root | **Closed.** The live set is the exact pending proposal-artifact `contentHash` union active blob-reference `contentHash`; `proposalHash` is explicitly excluded. |
| R4-P1-4 legacy artifact classification | **Not closed.** The no-guess provenance model is now safe, but reachable unresolved legacy states have no completion authority; see R5-P0-2 and R5-P0-3. |

## P0 findings

### R5-P0-1 — A pending terminal proposal has no deletion-authorized closeout, so a confirmed deletion can deadlock

The normal Camp guard accepts only `active` and explicitly rejects deletion
authority (`p1-stage-spec.md:1164-1171`). Requesting deletion atomically enters
`deletionRequested` and immediately installs the permanent normal-write fence
(`p1-stage-spec.md:1273-1290`).

A pending engine terminal proposal is a quiescence blocker
(`p1-stage-spec.md:1255-1258`). The engine recovery matrix says it must be
replayed first and committed exactly (`p1-stage-spec.md:1708-1713`), while a
completed proposal commit creates artifact rows/blob references, handoff, and
Run/Card/Mission terminal projections (`p1-stage-spec.md:1640-1653`).

The deletion contract only gives an explicit engine closeout to the separate
case `nonReplayable + started|sessionBound + no proposal`
(`p1-stage-spec.md:1301-1306`; `p1-plan.md:2024-2028`). The red line also says a
deletion permit may not enter a generic Engine API
(`p1-stage-spec.md:4554-4556`). Neither F2's allowed operations nor its tests
define a specialized permit-bound command for an already-pending completed,
blocked, failed, canceled, or artifact-bearing proposal.

Therefore this reachable state has mutually exclusive requirements:

1. deletion cannot quiesce while the proposal is pending;
2. the normal terminal commit cannot pass the active-Camp fence;
3. the deletion permit has no specified proposal commit/invalidation command;
4. the proposal cannot be discarded or replaced without violating terminal
   identity and recovery truth.

Required resolution: specify one exact specialized, permit-bound closeout for
every pending proposal shape, including artifact prepare/commit/failure,
projection writes, replay identity, lifecycle generation, crash windows, and
zero-new-dispatch guarantees. It must not broaden generic Engine authority.

### R5-P0-2 — Safe legacy-artifact classification contains permanent blocker states with no resolution authority

Current legacy artifacts contain only Card, path, kind, label, and time
(`Sources/AgentLoopCore/Database/AppDatabase.swift:101-108`), and the current
completion path accepts an arbitrary durable path
(`Sources/AgentLoopCore/Database/BoardCardTransactions.swift:5-42`).

Round 5 correctly refuses to guess ownership: v17 backfills every legacy
artifact as `unresolved/legacyUnknown`, without reading the filesystem
(`p1-stage-spec.md:4368-4376`). But the deletion contract then makes unknown
missing files, symlinks, permission/root failures, and identity/hash drift
hard blockers (`p1-stage-spec.md:1367-1374`; `p1-plan.md:2037-2041`).

There is no typed user/adaptor resolution command that can safely choose
detach-only, supply trusted evidence later, or abandon physical deletion while
still erasing the DB reference. `repairCampDeletion` only replaces an exhausted
deletion work and resumes the same cursor
(`p1-stage-spec.md:1308-1315`); it cannot resolve artifact ownership.

Thus an ordinary historical artifact whose file was moved or is no longer
readable can leave a user-confirmed logical deletion permanently fenced. This
does not meet the accepted master's required irreversible logical-deletion
contract.

Required resolution: define an explicit fail-safe resolution state machine and
authority for every unresolved terminal condition. It must preserve the rule
that no unknown or external file is unlinked, while still providing a bounded
path to erase/detach the Camp-private database reference and finish deletion.

### R5-P0-3 — The exhaustive erasure registry still has fields and a promised artifact-origin tombstone with no implementable schema shape

The deletion matrix requires `artifact_storage_origin` to become an
origin/reference tombstone (`p1-stage-spec.md:1399-1405`). Its normative DDL,
however, has no tombstone state or `redactedAt`; a `managed` row must retain
non-null `managedRootId`, `objectId`, `contentHash`, and `fileIdentityHash`,
while the other two storage classes represent external or unresolved
classification rather than a terminal tombstone
(`p1-stage-spec.md:4158-4201`).

This leaves no exact transition that both:

- preserves the proven historical ownership class needed for audit/recovery;
- stops representing a live managed locator/object;
- clears the ref fields promised by the erasure matrix; and
- satisfies the existing CHECK constraints.

Two other known Camp-reachable private/ref columns also lack an exact deletion
disposition:

- `approval_grant_use.adapterOperationId`
  (`p1-stage-spec.md:2761-2778`) is not the receipt field cleared by the combined
  Grant/receipt matrix row (`p1-stage-spec.md:1418`);
- free-text `engine_execution.cancellationReason`
  (`p1-stage-spec.md:3930-3933`) is neither explicitly retained as a safe code
  nor cleared in the Engine erasure row (`p1-stage-spec.md:1421`).

Because F2 must fail closed on any unregistered Camp-reachable
TEXT/BLOB/reference column (`p1-stage-spec.md:1192-1201`), these are not harmless
documentation omissions: a conforming implementation either cannot finalize,
must preserve unspecified private references, or must invent an unreviewed
schema/data decision.

Required resolution: add an exact artifact-origin terminal schema and enumerate
the retained/cleared sentinel for every known private/ref column, including
both operation-ID copies and cancellation reason. The DDL, registry, Store
commands, migration/backfill, and field-by-field tests must agree.

## Remaining findings

### R5-P1-1 — v16 trigger creation order is SQLite-version-sensitive and fails on SQLite 3.52

The normative v16 DDL creates
`camp_provider_dispatch_reject_request_redaction_outside_delete`, whose body
queries `camp_deletion_job`, at `p1-stage-spec.md:3209-3247`.
`camp_deletion_job` is not created until `p1-stage-spec.md:3337-3363`.
Between those points, the migration renames the rebuilt durable-work tables
(`p1-stage-spec.md:3317-3322`).

SQLite 3.51.0 accepts this order. SQLite 3.52.0 revalidates the schema during
the rename and fails with:

```text
error in trigger camp_provider_dispatch_reject_request_redaction_outside_delete:
no such table: main.camp_deletion_job
```

This was reproduced with foreign keys enabled and the frozen SQL order. Moving
the trigger, only in an in-memory diagnostic copy, until after
`camp_deletion_job` exists makes the same populated through-v17 chain pass
foreign-key and integrity checks.

Required resolution: create every trigger only after all tables referenced by
its body exist, and add a migration-matrix execution using the newer SQLite
behavior. A supported migration must not depend on permissive unresolved-table
handling in one SQLite release.

### R5-P0-4 — Redaction guards are not one-shot and allow retained audit evidence to be rewritten after deletion redaction

The legacy `event` redaction trigger requires the scope marker to be non-null
but does not require the old payload to be unredacted
(`p1-stage-spec.md:3537-3559`). With a deleting Camp and finalizing job:

```text
first marker UPDATE  -> changes() = 1
same marker UPDATE   -> changes() = 1
```

The second update should abort under the explicit ordinary/second/extra-diff
contract (`p1-stage-spec.md:1431-1438`;
`p1-plan.md:2094-2096`).

The provider guard has a more material bypass. Its outer `WHEN` only runs when
`requestJson` or `redactedAt` changes
(`p1-stage-spec.md:3209-3215`). Once a terminal provider row is redacted, a
separate update can change retained `requestHash` (and other non-gating
columns) without any deleting/finalizing check. That corrupts the pre-redaction
evidence the exact-diff clause intends to preserve.

Required resolution: make the exception one-shot and make terminal redacted
rows immutable except for no further mutation. Add direct raw-SQL tests for a
repeated marker update and for every retained column changed in a separate
post-redaction statement, not only as an extra column in the first redaction
statement.

## Owner, lifecycle, and phase-gate result

- **A1a local package:** the new canonical JSON and DurableWorkFailure
  ambiguities are substantially resolved; the Swift fence and the 3.51 v12
  structural path pass. This does not override the package-wide zero-P0/P1
  authorization rule.
- **E:** stable legacy scopes and provider ledger ownership are materially
  improved, but the v16 ordering defect must be corrected before migration
  implementation.
- **F1/F2:** current source owners are now broadly enumerated, but pending
  proposal closeout, legacy artifact resolution, artifact-origin terminal
  state, and exact erasure remain non-implementable.
- **Product code:** zero diff.
- **P0 acceptance:** closed.
- **P1-A1a implementation:** closed.
- **Further revision/review:** not authorized by this review.

## Final gate

- P0 findings: **4**
- P1 findings: **1**
- P1-A1a implementable now: **No**
- P0 acceptance may pass now: **No**
- Verdict: **CHANGES REQUIRED**

The next action is a ranch-owner decision about whether to authorize another
bounded revision/review. Until then, preserve the frozen inputs and keep all P1
implementation closed.
