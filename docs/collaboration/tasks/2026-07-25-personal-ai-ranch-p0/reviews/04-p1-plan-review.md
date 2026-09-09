# P1 Stage Spec / Plan Independent Review — Authorized Round 4

> Reviewer role: responsibility-separated fallback reviewer
>
> Date: 2026-07-25
>
> This additional review round was explicitly authorized by the ranch owner in
> the accepted master spec. The reviewer did not edit the reviewed spec, plan,
> master spec, P0 evidence, AGENTS instructions, or product source.

## Frozen review target

The following inputs were independently hash-checked before review:

| File | Frozen SHA-256 |
|---|---|
| `p1-stage-spec.md` | `bfe8ac750ad028ab2508e6e5f6db21e0ad8b4a72cadcb0d9dd2686f8b3a35a67` |
| `p1-plan.md` | `5eb39c6c7170e76a99f83cd62fd0fffdb87e5d34d6218d7f7ba70c7c706e068b` |

Also reviewed:

- accepted master spec, including the ranch owner's Camp archive/deletion
  decision and the authorized extra review round;
- `reviews/03-p1-plan-review.md`;
- P0 `spec.md`, `plan.md`, `impl-report.md`,
  `current-state-evidence.md`, and the phase gates;
- root `AGENTS.md` and the collaboration protocol;
- current source facts needed to test F1/F2 ownership, legacy Camp scope,
  write paths, external dispatch paths, and artifact ownership.

## Conclusion

**CHANGES REQUIRED**

P1-A1a is **not authorized for implementation**. No P1 product-code
implementation may begin.

The revision closes most of Round 3's engine, Grant, canonical JSON, receipt,
terminal identity, context hash, and Input contracts. It still has four P0 and
four P1 findings. The blocking findings are concentrated in the newly expanded
Camp-retirement contract and in three remaining plan/spec naming conflicts.

The extra review was user-authorized, so performing Round 4 itself does not
violate the normal three-round limit. It does not waive the P0/P1 phase gate:
the reviewed documents remain Proposed, P0 acceptance remains closed, and a
further revision/review requires the ranch owner's direction rather than an
automatic silent cycle.

## Independent structural validation

### Frozen hashes

Command:

```bash
sha256sum \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md
```

Result: both values exactly matched the frozen hashes above before and after
the review.

### Seven SQL fences

The seven `sql` fences were extracted in document order with:

```bash
awk '
  /^```sql$/ { inside=1; next }
  inside && /^```$/ { inside=0; next }
  inside { print }
' p1-stage-spec.md
```

They were executed in one in-memory SQLite database after enabling foreign
keys and creating minimal predecessor stubs for the released legacy tables
referenced by the migrations: `camp` including `archived/createdAt`,
`companion`, `squad`, `mission`, `card`, `run`, `artifact`, `schedule`,
`mission_template`, `runtime_profile`, and legacy `event` plus its append-only
triggers.

The exact validation pipeline was:

```bash
{
  printf '%s\n' \
    'PRAGMA foreign_keys=ON;' \
    'CREATE TABLE camp(id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT "camp", createdAt DATETIME NOT NULL, archived INTEGER NOT NULL DEFAULT 0);' \
    'CREATE TABLE companion(id TEXT PRIMARY KEY, campId TEXT REFERENCES camp(id));' \
    'CREATE TABLE squad(id TEXT PRIMARY KEY, campId TEXT NOT NULL REFERENCES camp(id));' \
    'CREATE TABLE mission(id TEXT PRIMARY KEY, squadId TEXT NOT NULL REFERENCES squad(id));' \
    'CREATE TABLE card(id TEXT PRIMARY KEY, missionId TEXT NOT NULL REFERENCES mission(id));' \
    'CREATE TABLE run(id TEXT PRIMARY KEY, cardId TEXT NOT NULL REFERENCES card(id));' \
    'CREATE TABLE artifact(id TEXT PRIMARY KEY, cardId TEXT NOT NULL REFERENCES card(id), path TEXT NOT NULL DEFAULT "", kind TEXT NOT NULL DEFAULT "", label TEXT NOT NULL DEFAULT "", createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);' \
    'CREATE TABLE schedule(id TEXT PRIMARY KEY);' \
    'CREATE TABLE mission_template(id TEXT PRIMARY KEY, campId TEXT REFERENCES camp(id));' \
    'CREATE TABLE runtime_profile(id TEXT PRIMARY KEY);' \
    'CREATE TABLE event(id TEXT PRIMARY KEY, missionId TEXT, cardId TEXT, runId TEXT, kind TEXT NOT NULL, payloadJson TEXT NOT NULL, createdAt DATETIME NOT NULL);' \
    'CREATE TRIGGER event_no_update BEFORE UPDATE ON event BEGIN SELECT RAISE(ABORT, "event is append-only"); END;' \
    'CREATE TRIGGER event_no_delete BEFORE DELETE ON event BEGIN SELECT RAISE(ABORT, "event is append-only"); END;'
  awk '
    /^```sql$/ { inside=1; next }
    inside && /^```$/ { inside=0; next }
    inside { print }
  ' p1-stage-spec.md
  printf '%s\n' 'PRAGMA foreign_key_check;' 'PRAGMA integrity_check;'
} | sqlite3 :memory:
```

Result:

- SQL fences found and executed: **7/7**
- SQLite process exit: **0**
- `PRAGMA foreign_key_check`: **no rows**
- `PRAGMA integrity_check`: **ok**

This establishes structural SQL validity only. It does not resolve the
semantic lifecycle, ownership, privacy, or recovery findings below.

### Swift fence

The one Swift fence is the `DurableWorkFailure` contract. It depends on the
module-level Foundation import and the separately specified
`CanonicalJSONV1.validateCanonical(rawUTF8:)` API. The exact fence was
type-checked with those two surrounding declarations:

```bash
{
  printf '%s\n' \
    'import Foundation' \
    'enum CanonicalJSONV1 {' \
    '  static func validateCanonical(rawUTF8: Data) throws {}' \
    '}'
  sed -n '274,466p' p1-stage-spec.md
} | xcrun swiftc -swift-version 6 -typecheck -
```

Result: **exit 0**.

## Round 3 finding disposition

| Round 3 finding | Round 4 disposition |
|---|---|
| R3-P0-1 Camp deletion/archive incomplete | **Not closed.** Archive/delete are now in scope, but the retirement authority, stable scope, erasure, owner, and recovery contracts remain blocked by R4-P0-1 through R4-P0-4. |
| R3-P0-2 crashUnknown no-effect authority conflict | **Closed.** Only typed adapter attestation can prove no effect/refund; user resolution is limited to succeeded/abandonedUnknown and remains consumed. |
| R3-P0-3 engine dispatch boundary absent | **Closed.** `markEngineDispatchStarted`, the prepared/started boundary, exact replay-class recovery, and four crash windows are specified. |
| R3-P0-4 invalid terminal proposal and blob GC gaps | **Partially closed.** Invalid proposal closeout and persistent content-hash roots exist in the stage spec. The implementation plan still calls the proposal hash a GC root; see R4-P1-3. |
| R3-P1-1 `complete.outputJson` undefined | **Closed.** Canonical object-root validation, typed errors, pre-write checking, mutation suppression, rollback, and tests are explicit. |
| R3-P1-2 nullable receipt uniqueness | **Closed.** Receipt key/JSON/hash are non-null, ordinal is unique per use, and phase-specific partial unique indexes plus replay tests are defined. |
| R3-P1-3 waiting-for-user taxonomy | **Closed.** There are four terminal kinds; ask-user is blocked + needsHumanInput, and SQL/API rejection of a fifth kind is required. |
| R3-P1-4 proposal identity omitted manifest | **Closed.** The whole canonical proposal, including normalized artifact declarations and ordinals, is the sole replay identity. |
| R3-P1-5 context hash not verified | **Closed.** Context and session scope have separate typed canonical forms, Store recomputation, mismatch errors, and zero-write tests. |
| R3-P1-6 Outcome authoritative table/name drift | **Partially closed.** `invalidateVerification` is now in the authoritative table and `returnOutcome` is consistent, but the plan still omits/renames `recordNewOutcomeVersion`; see R4-P1-2. |
| R3-P1-7 Input payload/tombstone ambiguity | **Closed.** Active payload XOR and the exact tombstone retained/null/default fields are aligned across prose, DDL, Store plan, and tests. |

## P0 findings

### R4-P0-1 — The universal active-only Camp fence makes legal retirement operations impossible and leaves no complete recovery path

**Evidence**

- The stage spec requires every Camp-scoped mutation, dispatch, reserve, worker
  claim, and session start to call
  `requireWritableCamp(campId, expectedLifecycleVersion:)`, which accepts only
  `active + camp.archived=false`
  (`p1-stage-spec.md:1125-1129`). The plan repeats this for every listed
  mutation/claim path (`p1-plan.md:1764-1773`).
- Legal lifecycle operations necessarily run outside that state:
  `unarchiveCamp` writes while the Camp is archived
  (`p1-stage-spec.md:1161-1163`); deletion request may start from active or
  archived, enqueues a Camp-deletion work, then changes the Camp to
  deletionRequested (`p1-stage-spec.md:1165-1181`); the deletion worker must
  claim and mutate while deletionRequested/deleting
  (`p1-stage-spec.md:1182-1189`; `p1-plan.md:1777-1789`).
- The same problem prevents the Grant resolutions that deletion explicitly
  waits for. `confirmAdapterNoEffect` and `resolveExternalOperation` are
  Camp-scoped mutations, but after deletionRequested the universal active-only
  fence rejects them.
- The deletion worker is itself a running `durable_work(kind=campDeletion)`.
  The spec then says the worker cancels durable work and requires all
  mutable/in-flight owners to reach zero before entering deleting
  (`p1-stage-spec.md:1173-1189`), while its own work is not succeeded until the
  final transaction (`p1-stage-spec.md:1235-1237`). No exact exclusion binds
  the current job/work/attempt to a privileged deletion capability.
- Generic durable work becomes terminal failed after the fourth transient
  failure or maxAttempts exhaustion (`p1-stage-spec.md:257-264`,
  `p1-stage-spec.md:1617-1620`). Camp artifact filesystem failures are called
  retryable (`p1-stage-spec.md:1203-1206`), but the single deletion job keeps
  one fixed workId (`p1-stage-spec.md:2586-2609`) and there is no
  failed-to-queued, replacement-work, or user repair command. Exhaustion can
  therefore leave the Camp permanently fenced.
- Engine replay class is explicitly independent from Grant-use replay class
  (`p1-stage-spec.md:1281-1292`). Nevertheless deletion treats an unresolved
  nonReplayable engine as a blocker that waits for §13 user resolution
  (`p1-stage-spec.md:1183-1189`), while §13 resolves only approval_grant_use.
  An engine invocation with no corresponding Grant use has no resolution API.

**Required change**

Define two separate authorities:

1. the ordinary active-Camp write fence; and
2. a narrow lifecycle/deletion capability bound to the exact user-confirmed
   job, work, attempt, Camp, lifecycle version, and allowed transition.

Enumerate which archived/deletionRequested/deleting writes it permits
(unarchive, Grant resolution, quiesce, erase, finalize), and reject all
ordinary or expanding writes. Exclude the exact current deletion work from its
own quiescence count, define finite-error repair/requeue semantics, and define
an engine-specific unknown-effect resolution or a safe terminal rule. Add
race, restart, exhaustion, stale-capability, and wrong-job tests.

### R4-P0-2 — The promised privacy erasure cannot be implemented under the normative append-only schema and omits known sensitive fields

**Evidence**

- The accepted master requires deletion to erase Camp-private sensitive
  content and content references while retaining only a non-sensitive minimal
  audit tombstone (`personal-ai-ranch-master-spec.md:273-275`).
- The new erasure matrix promises to redact Verification raw refs and
  Acceptance reason text and declares Camp deletion the privacy-redaction
  exception for immutable P1 records
  (`p1-stage-spec.md:1208-1229`).
- Normative schema rules create unconditional UPDATE/DELETE abort triggers for
  `verification_record`, `acceptance_record`, and `discussion_turn`; the only
  deletion-time UPDATE exceptions are legacy `event` and
  `external_operation_receipt`
  (`p1-stage-spec.md:1588-1603`). The promised Verification/Acceptance
  redaction therefore cannot be executed.
- `inbox_message` persists `sourceDeviceId`, `payloadJson`, and error metadata
  (`p1-stage-spec.md:1867-1879`). Archive quiescence mentions a Camp inbox, but
  the field-erasure matrix has no inbox owner and only discusses event/outbox
  (`p1-stage-spec.md:1211-1224`).
- `discussion_turn.contentRef` is a Camp-private content reference and is
  append-only (`p1-stage-spec.md:3169-3183`), but Discussion is absent from the
  erasure matrix.
- Normalized proposal artifact rows retain `sourceRelativePath` and `label`
  (`p1-stage-spec.md:3086-3109`). Clearing only proposalJson/payloadJson/
  artifactManifestJson does not erase those duplicated path/label fields.
- F2 promises exact field sentinels but names none of these missing fields or
  their deletion-only trigger mechanics (`p1-plan.md:1791-1838`).

**Required change**

Create one exhaustive, table-and-column deletion matrix for every
Camp-reachable content carrier. For each append-only table, either:

- define a narrowly checked user-confirmed deletion-only redaction trigger and
  the exact allowed column diff; or
- move sensitive bytes/refs into an erasable indirection while leaving the
  immutable row content-safe.

Add exact sentinel tests for inbox payload/device/error fields, Verification,
Acceptance, Discussion turns, normalized proposal artifact path/label, and
every other duplicated content/ref column. The tests must prove both privacy
erasure and rejection of ordinary mutation.

### R4-P0-3 — Legacy note/chat and legacy event data do not have a complete stable Camp scope, so deletion cannot be targeted safely

**Evidence**

- The stage claims every Camp-reachable table has a stable campId or immutable
  FK path (`p1-stage-spec.md:1131-1137`) and deletion must avoid cross-Camp
  erasure.
- Existing `companion_note` has only companionId and an optional sourceThreadId
  (`Sources/AgentLoopCore/Database/AppDatabase.swift:179-187`).
  Existing DM threads are deliberately created with `campId=nil`
  (`Sources/AgentLoopCore/Database/AppDatabase.swift:1436-1447`).
  The new model allows one Cow to reside in multiple Camps. v16/v17 add no
  stable legacy note/chat ownership mapping, while F2 says it introduces no
  additional schema (`p1-plan.md:1686-1690`). It is therefore impossible to
  prove which Camp may erase a legacy companion note/DM message without
  deleting global or another Camp's data.
- The v16 `camp_event_scope` backfill derives legacy event scope only through
  mission/card/run (`p1-stage-spec.md:2662-2679`).
- Current valid Camp events often have all three refs nil and carry Camp scope
  through payload or another legacy aggregate: camp archive
  (`Sources/AgentLoopCore/Database/AppDatabase.swift:499-514`), bootstrap
  (`Sources/AgentLoopCore/Product/ProductBootstrapService.swift:18-64`), cow
  unlock (`Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift:43-58`),
  ingestion (`Sources/AgentLoopCore/Ingestion/FeedService.swift:43-74`), and
  rumination/schedule events are concrete examples.
- Migration prose says any Camp-reachable unscoped event must fail
  (`p1-stage-spec.md:2858-2867`) but does not define a typed mapping for these
  legitimate event kinds. A supported v11 database can therefore fail
  migration on normal valid history.
- After v16, only new `domain_event` insertion is required to add a matching
  scope row (`p1-stage-spec.md:2868-2870`). There is no equivalent transaction
  rule or trigger for future legacy `event` appends, so such events can escape
  deletion redaction even if backfill succeeds.

**Required change**

Define and migrate a stable Camp ownership model for legacy companion
notes/chats, including how global Cow/DM data is distinguished from Camp data.
Define a complete typed legacy-event scope resolver for every supported event
kind and relationship, reject genuinely ambiguous rows, and require every
post-v16 legacy event append to insert the matching scope in the same
transaction. Add representative v11 fixtures for every nil-ref Camp event and
cross-Camp/global note/chat fixtures that prove no over-erasure.

### R4-P0-4 — F2 cannot enforce the promised exhaustive write/dispatch fence within its authorized owners or quiescence model

**Evidence**

- The stage requires all Camp-scoped writes, dispatches, reserves, worker
  claims, and session starts to be fenced in the same transaction
  (`p1-stage-spec.md:1125-1137`).
- The F2 exact allowed-file list (`p1-plan.md:1691-1763`) omits current direct
  Camp mutation owners, including:
  - `BoardCardTransactions.swift`, whose public complete/block methods open
    their own write transactions
    (`Sources/AgentLoopCore/Database/BoardCardTransactions.swift:5-12,65-71`);
  - `NewcomerUnlockPolicy.swift`, which inserts a Camp cow/event directly
    (`Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift:43-58`);
  - `ProductBootstrapService.swift`, which updates/inserts Camp companions and
    events (`Sources/AgentLoopCore/Product/ProductBootstrapService.swift:18-64`).
    That file appears in P1-E, but E does not specify an ordinary-write fence
    retrofit and F2 cannot repair it.
- Guide chat persists a Camp message, then starts an asynchronous Provider
  stream outside that transaction
  (`Sources/AgentLoopCore/Chat/GuideChatService.swift:27-32,52-119`).
  Guide-memory distillation similarly reads Camp messages and makes an
  external model call (`Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift:59-90`).
  Neither service is in F2's allowed list.
- F2 quiescence counts database projections but has no durable
  provider-dispatch/session fact for these live streams
  (`p1-stage-spec.md:1141-1156`). Deletion can win the DB fence while an
  already-created Task still sends Camp-private context or later attempts to
  write a reply.
- The registry compares Camp-reachable schema/FK owners, so it cannot discover
  an in-memory external Provider dispatch that has no ledger row.

**Required change**

Enumerate every current production mutation and external-dispatch owner before
F2. Add the exact owning files/tests to the appropriate slice, or explicitly
remove/seal obsolete APIs and prove they are unreachable. Give Camp chat and
distillation dispatches a durable in-flight/intent boundary that participates
in archive/delete quiescence and a lifecycle-generation gate that prevents
post-fence dispatch/commit. Test every omitted direct write and the
message-written/provider-not-started/provider-running/provider-returned crash
and race windows.

## P1 findings

### R4-P1-1 — Archive quiescence applies ingestion status values to action candidates

The archive list combines legacy ingestion and action candidates under
`queued|ruminating|needsReview`
(`p1-stage-spec.md:1149-1152`). Those are `IngestionStatus` values. Current
`ActionCandidateStatus` is `proposed|accepted|dismissed|converted`
(`Sources/AgentLoopCore/Ingestion/IngestionRecords.swift:118-120`).

As written, proposed/accepted candidates are either never counted or require
the implementer to invent a separate query and terminalization rule. Split the
two projections, name the exact blocking/terminal statuses for each, define
the deletion transition for proposed/accepted candidates, and add per-status
quiescence tests.

### R4-P1-2 — The plan still omits the authoritative `recordNewOutcomeVersion` command

The stage's unique Outcome state table and §19 use
`recordNewOutcomeVersion`
(`p1-stage-spec.md:876-890,3263-3269`). The plan's complete Outcome command list
instead has `recordProducedVersion` and no `recordNewOutcomeVersion`
(`p1-plan.md:1100-1111`).

Clarify whether `recordProducedVersion` is only initial production or is an
alias. Prefer using the authoritative stage name, with the exact initial
creation command separately named, and require the returned/revoked/
invalidated/verificationFailed/blocked transition and downstream invalidation
tests.

### R4-P1-3 — The F1 plan names the wrong GC root

The stage correctly says each pending proposal artifact's expected
`contentHash` is a GC root (`p1-stage-spec.md:1417-1421,3252-3255`). The F1 plan
says the “pending proposal hash” is the root
(`p1-plan.md:1526-1530`). A proposalHash is not an artifact blob contentHash and
cannot protect the corresponding blob row.

Replace the plan wording with the exact live-set query: pending
engine_proposal_artifact contentHash union active artifact_blob_reference
contentHash, and make the 23h/25h tests assert those exact keys.

### R4-P1-4 — Legacy artifact ownership has no deterministic classification rule

The deletion contract requires every artifact to be classified as
managedExclusive, managedShared, or workspaceExternal before any unlink
(`p1-stage-spec.md:1191-1206`; `p1-plan.md:1791-1799`). Existing legacy
`artifact` rows only store cardId/path/kind/label, and legacy
`completeCard` accepts an arbitrary durablePath
(`Sources/AgentLoopCore/Database/BoardCardTransactions.swift:5-43`).

No v16/v17 backfill or F2 rule says how a legacy path proves App ownership,
when ambiguity is a blocker, or whether an unrecognized path must default to
workspaceExternal. Freeze a deterministic, fail-safe classification contract
and add legacy managed, external, missing, ambiguous, shared, and
cross-Camp fixtures. No implementation may infer ownership from path shape and
delete a user workspace file.

## F1/F2 owner, test, and phase-gate result

- **F1:** Engine dispatch, terminal identity, invalid proposal closeout,
  context/session hashing, and conformance ownership are substantially
  specified. F1 still has the blocking plan-level GC-root conflict in
  R4-P1-3, so it is not independently implementation-ready.
- **F2:** Owner coverage, lifecycle authority, stable scope, erasure,
  quiescence, and restart recovery are not implementation-ready. Its listed
  tests cannot repair missing authority/schema contracts without unplanned
  decisions.
- **A1a:** Its local canonical JSON, DurableWorkFailure, DDL/Store API,
  outputJson, retry, CAS, and test contracts are reviewable in isolation.
  However, this review's required verdict rule and the P0/P1 stage entry gate
  prohibit authorizing A1a while any P0/P1 remains anywhere in the frozen
  stage package.

## Non-blocking suggestions

No additional P2/P3 suggestions are recorded. The review intentionally stops
at the confirmed blocking contract failures.

## Final phase gate

- P0 findings: **4**
- P1 findings: **4**
- Decision: **CHANGES REQUIRED**
- P1-A1a implementable now: **No**
- P1 implementation authorized: **No**
- P0 acceptance may claim P1 review passed: **No**
- `Open Questions` may remain “无”: **No**
- Required next action: **Return the frozen package to planning, resolve all
  P0/P1 findings, and obtain the ranch owner's direction before any further
  review cycle or P1 implementation.**
