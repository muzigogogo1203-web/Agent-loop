# P1-F1 — Engine / Artifact / Discussion / Attention / Growth Plan

> Revision: 2 review candidate  
> Date: 2026-08-27  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Entry authority: P1-E acceptance SHA-256
> `114c3b6b157bce4e8de20bde5dbdc660bdeb8978629b5be1dcca0860891e50be`

## 1. Decision, authority, and entry gate

This is the decision-complete implementation plan for canonical P1-F1. Its
authority is:

- accepted master spec §§5–7, 22–25, and 29;
- canonical P1 stage §§16–17, 18.7, 19, and the P1-F1 completion/red-line
  clauses;
- canonical P1 plan §§8, 10, and 11;
- accepted P1-E implementation, Review02, and acceptance evidence.

P1-E is closed and is not re-audited here. Product, test, migration, Package,
and runtime writes for P1-F1 remain closed until an independent Codex reviewer
examines this exact plan, the exact machine allowlist, both machine manifests,
the frozen entry bytes, and returns `APPROVED — 0 P0 / 0 P1`. Historical
Review01 approved Revision 1, but an independent byte recount then proved its
phrase “770 nonblank lines” wrong: the same frozen SQL has 770 total
newline-terminated lines and 757 nonblank lines. Revision 2 changes only that
evidence label and adds the append-only Review01a artifact; Review01a is the
effective implementation gate. The user directed this implementation to
proceed without Claude; no Claude process or review is used.

P1-F1 delivers six bounded responsibilities:

1. v17 Engine/Artifact/Discussion/Attention/Growth schema, deterministic
   legacy-origin backfill, phase barrier, and dual-SQLite replay evidence;
2. one kernel-owned execution lifecycle with canonical request/session scope,
   monotonic events, terminal proposals, receipts, and deterministic recovery;
3. content-addressed Artifact staging, typed ownership provenance, safe GC,
   and one managed expedition-report filesystem owner;
4. ModelLoop/Codex/Claude adapters behind one truthful conformance protocol,
   with no adapter/Board/runner database terminal authority;
5. bounded Discussion, rule-derived Attention, evidence-bound Growth, and
   same-transaction Memory/Growth invalidation coordination;
6. a fake-adapter P1 integration path through accepted Outcome, Verification,
   Acceptance, Memory, and Growth, including exact reverse propagation.

P1-F1 deliberately does **not** expose Camp archive/delete/repair commands,
run a Camp deletion worker, produce `invalidCampDeletion`, implement owner
registry/global deletion fences, add P1-F2 or P2 product UI, contact real
providers/users, or perform any P3+ external validation.

## 2. Bounded execution model

P1-F1 is one leaf split into six ordered TDD bands. Each band starts with new
tests that fail for the missing capability, records one pure-red log, fixes
only the demonstrated root inside the allowlist, then runs the current band
plus every earlier P1-F1 test. A later band cannot waive an earlier failure.

| Band | Exact tests | Responsibility | Completion gate |
|---|---:|---|---|
| F1A | 001–016 | v17 literal, schema, backfill, barrier, replay, dual SQLite | exact runtime SQL hash and 79/208/84 checkpoint; all 16 green |
| F1B | 017–042 | request/scope, execution store, proposal/terminal, session/recovery | kernel owns every Run/Card terminal; all 26 green |
| F1C | 043–061 | blobs, staging, origin, verifier, Board artifact API, report owner | no raw durable path or unsafe filesystem owner; all 19 green |
| F1D | 062–080 | unified conformance, ModelLoop/CLI/Board adapters | descriptor/session/terminal truth across fake adapters; all 19 green |
| F1E | 081–095 | Discussion, Attention, Growth, reverse invalidation | all coordination mutations atomic and evidence-bound; all 15 green |
| F1F | 096–100 | full P1 integration and F2 boundary | golden/replay paths green; Camp retirement remains closed |

For each band, under Bash `set -u -o pipefail`:

1. add exactly the manifest identities for that band before its product code;
2. build an anchored filter from column four of `focused-test-manifest.txt` and
   run `swift run RunTests --filter '<name1>|<name2>|…'`;
3. require nonzero command status, zero tee status, discovered identities
   exactly equal the band manifest, and capability assertions—not a compile
   typo, harness fault, or unrelated regression—to explain the red;
4. atomically preserve complete stdout/stderr and statuses in the band log;
5. implement the unique root; then run the union of this and prior bands;
6. stop auditing the band after its gate is met and move forward.

The first unfiltered compatibility run occurs only after F1F focused green. If
it reveals an unplanned existing failure, preserve its full output in
`verify-red.log`, diagnose a repeatable root, and freeze/review the smallest
revision only when schema, ownership, public surface, allowed files, or tests
must change. Timing inflation, retry-until-green, serializing the authoritative
runner, longer sleeps/timeouts, lower assertions, and fallback success are not
valid fixes.

## 3. Frozen schema and migration decisions

### 3.1 Normative v17 bytes and registration

1. The migration identifier is exactly `v17-p1-engine-coordination`, directly
   after `v16-p1-identity-memory`; no v18 is introduced.
2. `AppDatabase.swift` carries one package-read-only multiline value named
   `p1F1EngineCoordinationMigrationSQL`. Its runtime UTF-8 bytes are the
   canonical Stage §18.7 code-fence content from the first
   `CREATE TABLE engine_session (` through the final `END;`, excluding the
   fence-separating blank line after that final statement: exactly 29,934
   bytes, 770 newline-terminated content lines (757 nonblank lines), SHA-256
   `a6ef8747ee3e8ffeb0856827f6cf8f858c681a70748cd373783ae1d23d2b4e99`.
   Tests hash the runtime value, not source indentation. The alternative
   29,935-byte fence-plus-trailing-newline representation is explicitly not
   the runtime authority.
3. The unique split token is
   `CREATE TRIGGER engine_session_first_redaction_exact`; it must occur once.
   The migration executes the untouched prefix (all tables/indexes, no v17
   trigger), performs the typed legacy origin backfill and phase barrier, then
   executes the untouched 17-trigger suffix in the same GRDB transaction.
4. The migration creates exactly 12 tables, 15 explicit indexes, 22 SQLite
   autoindexes, and 17 triggers. The through-v17 checkpoint is exactly
   79 tables / 208 indexes / 84 triggers. The through-v16 checkpoint remains
   67 / 171 / 67.
5. All Stage DDL CHECK/FK/unique/redaction/append-only shapes are byte-derived
   from the normative SQL. No `IF NOT EXISTS`, patch migration, trigger repair,
   or semantic SQL rewrite is permitted.
6. `Package.swift` may change only if the existing P1 migration runner target
   needs the v17 carrier; dependencies, products, app/test targets, linker
   settings, and CLT workaround remain exact. `Package.resolved` is protected.

The twelve tables are exactly:

`engine_session`, `engine_execution`, `engine_terminal_proposal`,
`artifact_blob`, `engine_proposal_artifact`,
`camp_deletion_proposal_blob`, `artifact_blob_reference`,
`artifact_storage_origin`, `discussion`, `discussion_turn`, `attention_item`,
and `growth_evidence`.

### 3.2 Deterministic legacy artifact-origin backfill

The migration joins exactly
`artifact -> card -> mission -> squad -> camp`. Every source artifact must
join once and receive exactly one origin row:

- `state=active`, `storageClass=unresolved`, `evidenceKind=legacyUnknown`;
- `version=1`, `classifiedAt=artifact.createdAt`;
- managed/terminal/redaction columns are null;
- `originalRefHash = SHA256(Data(persistedArtifactPath.utf8))`, with no path
  normalization and no filesystem access;
- `classificationEvidenceHash` is `CanonicalJSONV1` SHA-256 of the exact
  object `{schemaVersion:1, artifactId, cardId, campId, originalRefHash}`.

The phase barrier, before any v17 trigger, asserts source count = joined count
= origin count, one origin per artifact, exact derived Camp, exact path hash,
exact classification attestation, and empty `PRAGMA foreign_key_check`. A
missing/cross-Camp/duplicate/hash-drift row throws a typed migration integrity
error and rolls the whole migration back to an exact v16 logical snapshot.
Migration code must not call FileManager, stat/lstat/realpath, resolve symlinks,
or infer storage class from path text.

### 3.3 Migration matrix

The existing real-linked and literal SQLite 3.51/3.52 lanes remain. Each lane
executes and replays this ordered fixture set:

```text
fresh -> v7 -> v8-coding-ranch -> v9-evercamp -> v10-runtime-profiles
-> v11-cli-kinds -> v12-p1-durable-work -> v12-p1-schedule-fire
-> v13-p1-observability -> v14-p1-control-contracts
-> v15-empty -> v15-populated -> v16-identity-memory
-> v17-engine-coordination -> v17 replay
```

Each lane requires integrity/FK/DDL/checkpoint/predecessor/rollback evidence.
Required new sentinels include:

```text
engine_coordination_contract.real.<fixture>=pass
fixture.v16-identity-memory.engine_coordination.predecessor_snapshot=pass
fixture.v16-identity-memory.engine_coordination.legacy_artifact_backfill=pass
fixture.v17-engine-coordination.replay=pass
literal.v17.engine_coordination.checkpoint=79/208/84
literal.v17.engine_coordination.append_only=pass
literal.v17.engine_coordination.rollback=pass
artifact_origin.count_camp_path_hash=pass
discussion.redaction.first_wrong_second_noop_extra_delete=pass
p1_migration_matrix.result=pass
```

## 4. Frozen engine protocol and ownership

### 4.1 Domain types and adapter boundary

Protocol version is exactly `agentloop.execution.v1`. The new domain files own
the following typed surface; raw JSON/hash claims never become truth:

```swift
enum EngineCapabilitySupportV1: Sendable, Equatable, Codable {
    case supported
    case unsupported
    case conditional(reasonCode: String)
}

enum EngineExecutionReplayClassV1: String, Sendable, Codable {
    case replaySafe, idempotencyKeyed, nonReplayable
}

protocol ExecutionEngineAdapter: Sendable {
    func descriptor(profile: RuntimeProfileRecord) throws
        -> ExecutionEngineDescriptor
    func execute(request: EngineExecutionRequest)
        -> AsyncThrowingStream<EngineExecutionEvent, Error>
    func cancel(executionId: String) async throws
}
```

`ExecutionEngineDescriptor` owns adapter ID/version/profile kind, truthful
support for streamingProgress/boardTerminal/toolBridge/cancellation/
sessionResume/usageMetering/workspaceRead/workspaceWrite/network, and the pure
`executionReplayClass(for: EngineSessionScopeV1)` decision. Engine invocation
replay class is never copied from ApprovalGrant tool-effect replay class.

`EngineContextEnvelopeV1` is the only context identity. It contains schema 1,
Camp/nullable Goal/Mission/Card, exact OutcomeContract ref/hash, and sorted
input/memory/resource/prior-handoff/instruction refs. `ContextPacket` converts
once through `EngineContextEnvelopeV1.from(packet:scope:)`; prompt rendering is
transport only. Before any SQL, Store decodes the claimed canonical object,
re-encodes through `CanonicalJSONV1`, requires byte equality, recomputes its
hash, and rejects invalid/nonobject/noncanonical/hash mismatch with zero writes.

`EngineSessionScopeV1` contains only schema 1, Camp, profile, adapter ID/version,
engine kind/model, workspace hash, and contract ID/version/hash. Store derives
and canonical-encodes it from exact request fields. It excludes Input, Memory,
and answered-request context. Caller-provided scope JSON/hash is diagnostic at
most and cannot be persisted as authority.

`EngineExecutionRequest` contains the Stage §16.2 fields, including sorted
Grant IDs, budgets, workspace ref, optional session ref, store-derived replay
class/session scope, exact context bytes/hash, and the Camp lifecycle version
read inside begin. Store canonical-encodes the whole request once and computes
`requestHash`.

`EngineExecutionEvent` carries execution ID and a contiguous monotonic
sequence. Kinds are only accepted/sessionBound/progress/toolActivity/usage/
terminal. Terminal kind is exactly completed/blocked/failed/canceled; blocked
subtype is ordinary/needsHumanInput/engineProtocolError/externalEffectUnknown.
Usage/cost additions use `addingReportingOverflow`; overflow throws the nested
`EngineUsageV1.UsageOverflowError`, fails the execution, and never reuses the
separate protected planning error or saturates to success.

### 4.2 EngineExecutionStore commands

`EngineExecutionStore` is the sole execution/Run/Card terminal mutation owner.
Its required package API is:

```swift
beginEngineExecution(requestFields:idempotencyKey:)
    -> EngineExecutionRequest
markEngineDispatchStarted(
    executionId:expectedVersion:requestHash:commandIdempotencyKey:now:)
    -> EngineDispatchStartResultV1
commitEnginePreDispatchFailure(...)
    -> EngineTerminalCommitReceiptV1
acceptEngineEvent(executionId:sequence:event:)
recordEngineTerminalProposal(_:)
    -> EngineTerminalProposalSnapshotV1
commitEngineTerminal(proposalId:checkedUsage:now:)
    -> EngineTerminalCommitReceiptV1
commitEngineAskUser(proposalId:checkedUsage:now:)
    -> EngineTerminalCommitReceiptV1
invalidateProposalAndCommitProtocolError(
    proposalId:expectedVersion:failure:commandIdempotencyKey:now:)
    -> EngineTerminalCommitReceiptV1
recoverInterruptedEngineExecutions(now:)
    -> EngineRecoverySummaryV1
requestCancellation(executionId:expectedVersion:reason:now:)
    -> EngineExecutionRecord
activeRecoverySnapshots()
    -> [EngineExecutionRecoverySnapshotV1]
```

The exact command rules are:

1. `begin` validates context and derived scope before SQL, reads active Camp
   lifecycle in the transaction, derives descriptor replay class, allocates
   execution+Run once, moves Card ready->running, and emits events. Same key+
   same whole request replays; any field drift conflicts.
2. Dispatch CAS is the only durable adapter-call boundary. First prepared CAS
   returns `.startNow(exactPersistedRequest)`; same-command replay returns
   `.alreadyStarted` and must not call the adapter. Pre-dispatch setup mismatch
   uses the terminal failure transaction with nil `dispatchStartedAt`.
3. Events require exact next sequence. Unknown/duplicate/skipped/out-of-order or
   second terminal fails closed. Progress never gains terminal authority.
4. `EngineTerminalProposalContentV1` is one canonical identity over envelope,
   terminal kind/subtype/full payload, and completed artifact declarations
   normalized by explicit contiguous ordinal. First record generates artifact
   IDs inside the transaction; exact replay returns those rows. Payload or
   manifest subhashes are integrity aids only.
5. Completed commit revalidates all prepared blobs, then one transaction writes
   artifacts/origins/references, full handoff, engine, Run, Card, Mission rollup,
   events/outbox, proposal state, and receipt. Ask-user writes the exact
   user_request and blocked+needsHumanInput terminal in one transaction.
6. Invalid preparation transitions the existing pending proposal to invalid
   and commits one blocked+engineProtocolError receipt; it never creates a
   second proposal. Any projection/event fault rolls everything back.
7. `EngineTerminalCommitReceiptV1` contains receipt key, execution/proposal IDs,
   proposal hash, disposition, kind/subtype/reason, artifact/event IDs, and
   finishedAt. Disposition type contains committedProposal,
   invalidProtocolError, and invalidCampDeletion; F1 only produces the first
   two. Its canonical domain-command resultHash is `terminalReceiptHash`;
   proposalHash is never substituted.

`CardRunner`, `CliProcessBackend`, both adapters, `BoardTools`, and
`BoardToolServer` lose `startRun`, `finishRun`, `completeCard`, `blockCard`, and
direct Card/Mission mutation authority. Board complete/block/ask-user tools
only build a full proposal for an injected `EngineTerminalSink`; progress is a
nonterminal event. `BoardCardTransactions` removes every raw
`durablePath: String` completion overload.

### 4.3 Recovery and session continuation

Recovery precedence is exact:

1. pending proposal + active Camp: replay prepare and exact commit;
2. pending proposal + deletionRequested: leave for F2 specialized
   supersession; do not prepare, dispatch, or normally commit;
3. nonReplayable started/sessionBound without proposal: before cancellation,
   commit blocked+externalEffectUnknown and urgent Attention, never replay;
4. cancellation + prepared: adapter was never called; commit typed canceled;
5. cancellation + started/sessionBound replaySafe/idempotencyKeyed: reconcile
   same key and require adapter terminal evidence;
6. prepared without cancellation: first mark/start same request;
7. exact active session with resume support: exact resume;
8. no session and replaySafe/idempotencyKeyed: replay same execution/request key;
9. parser/EOF/session/descriptor mismatch: blocked+engineProtocolError.

The four failure-injected dispatch windows are pre-CAS, post-CAS/pre-call,
post-call/pre-event, and post-session-bind. Every branch ends through the
kernel terminal transaction; no branch guesses success/no-effect.

`EngineSessionStore` owns bind/resume/close/invalidate and requires exact Camp,
profile, adapter ID/version, derived scope hash, and workspace hash equality in
one transaction. A user answer creates a new execution/context hash but may
resume only the unchanged session scope. Scope drift starts a new session;
spoof/mismatch writes nothing. No credential is stored.

Its transaction-only helpers are `bindOrReplay(execution:externalSessionId:
database:now:)`, `requireExactResume(execution:sessionId:descriptor:database:)`,
and `closeOrInvalidate(sessionId:expectedVersion:disposition:database:now:)`.
The session row and execution FK commit before the kernel publishes the
`sessionBound` event.

Adapters and Board receive only DB-free injected sinks:

```swift
protocol EngineTerminalSink: Sendable {
    func submit(_ proposal: EngineTerminalProposalContentV1) async throws
        -> EngineTerminalProposalRecordResult
}
protocol EngineProgressSink: Sendable {
    func submit(
        executionId: String,
        sequence: Int,
        payload: EngineExecutionEventPayloadV1
    ) async throws
}
```

CLI contracts are fixed:

- Codex first call `codex exec ... --json`; parser obtains the exact JSONL
  thread/session ID; resume is `codex exec resume <exact-id> ... --json`.
- Claude first call uses a ranch-generated UUID with `--session-id`; result
  must return it; resume uses `--resume <exact-id>`.
- both re-inject workspace, ranchboard/MCP, permission, safety, model, and
  Contract flags; neither uses `--last`, `--continue`, or `-c` continuation;
- local `--help` capability mismatch returns typed unsupported;
- conformance uses deterministic fake CLIs. A real-login smoke is not run in
  this task because credentials/real external provider actions are outside the
  granted authority; this is disclosed, not treated as a failure.

## 5. Frozen Artifact and report ownership

### 5.1 ArtifactStager and ArtifactBlobStore

`ArtifactStager` is the only workspace-to-blob preparer:

```swift
prepare(proposalId:workspaceRoot:expectedWorkspaceHash:)
    throws -> [PreparedArtifactV1]
recoverPreparation(proposalId:workspaceRoot:expectedWorkspaceHash:)
    throws -> [PreparedArtifactV1]
cleanOrphanedStaging() throws
```

It first verifies a registered immutable blob by exact path/size/hash. Only a
missing blob authorizes a no-follow source read inside the execution workspace.
An existing corrupt blob, both sources missing, escape, symlink traversal, or
size/hash drift is a deterministic preparation failure. The write order is
`.staging/<executionId>/<artifactId>.tmp`, file fsync, atomic rename to
`blobs/<sha256>`, parent-directory fsync, blob-row upsert, then proposal
artifact CAS declared->prepared. Rename-before-row is recovered from the exact
hash path. No product row ever references staging or missing bytes.

`ArtifactBlobStore` owns blob metadata, prepared-artifact validation, GC, and
quarantine recovery. Its GC root is exactly the union of:

- declared/prepared `engine_proposal_artifact.contentHash` for pending proposal;
- active `artifact_blob_reference.contentHash`;
- nonterminal `camp_deletion_proposal_blob.contentHash` in
  pending/reserved/unlinkReady/retryableFailure.

`proposalHash` is never a root. `createdAt > now-24h` remains; only age >=24h is
eligible. The store holds the production `StateDirectoryLock`, CASes
available->quarantined, performs trusted no-follow unlink, then writes a
deleted tombstone with empty relative path/deletedAt/new version. Quarantine
recovers after crash. Reusing a tombstoned hash requires verified/restaged bytes
and a new-version CAS; an empty path is never revived. Shared/live refs remain.

### 5.2 Artifact origin and ownership verifier

`ArtifactStorageOriginStore` is the only artifact/origin/reference DB owner:

```swift
insertPreparedArtifacts(_:proposalId:database:) throws -> [ArtifactRecord]
insertWorkspaceExternalArtifact(_:database:) throws -> ArtifactRecord
upgradeLegacyOrigin(
    artifactId:expectedVersion:evidence:at:database:)
    throws -> ArtifactStorageOriginSnapshotV1
```

Managed create inserts artifact+blob reference+origin together; external create
inserts artifact+origin together and no blob ref. Managed path points to the
immutable blob while blob metadata stores a relative path. Legacy upgrade
accepts only verifier-signed managed or verified-outside-all-managed-roots
evidence and exact version CAS. Failure leaves all three projections unchanged.

`ArtifactOwnershipVerifier` is the only root-capability classifier. It uses
root descriptors plus `openat/fstatat` no-follow traversal and can sign only
trusted managed, explicit workspace external, or verified outside every
available managed root. Missing, symlink, permission/root unavailable, prefix/
name/extension spoof, identity/content/root drift, hardlink, pending proposal,
cross-Camp ref, and concurrent snapshot drift produce typed evidence or
unresolved—not guessed managed/external. It never unlinks and never uses
`resolvingSymlinksInPath` as authority.

### 5.3 Managed expedition reports

`ManagedExpeditionReportStore` becomes the sole report filesystem writer:

```swift
ensureReport(missionId:) throws -> URL
regenerateReport(missionId:) throws -> URL
recoverPendingWrites() throws
reportURL(missionId:) throws -> URL
```

It derives mission->squad->Camp owner scope, uses a trusted report root with
no-follow traversal, writes deterministic staging bytes, fsyncs, atomically
renames, fsyncs the directory, and recovers a valid final/temp/database render.
`ExpeditionReport.markdown` remains a pure renderer. Orchestrator closeout only
calls `regenerateReport`; AppStore ensure/open/reveal only calls the store.
Their raw `createDirectory` and `.write(to:)` report-root paths go to zero.
F1 records owner scope for later F2 enumeration but performs no deletion.

## 6. Frozen Discussion, Attention, Growth, and coordination

### 6.1 Discussion

The domain defines proposed/running/completed/blocked/canceled/failed status;
materialization decision/handoff/outcome/verification/cardRevision/planRevision;
typed create/start/append/materialize/cancel commands; immutable turns; and
aggregate snapshots. `CoordinationStore` owns:

```swift
createDiscussion(_:), startDiscussion(_:), appendDiscussionTurn(_:),
materializeDiscussion(_:), cancelDiscussion(_:), discussion(id:),
turns(discussionId:)
```

Participant IDs are sorted/unique and count >=2; maxRounds is 1...3. The
default helper fixes 2 rounds and token budget to
`min(20_000, floor((missionBudget-spentTokens)/10))` using checked subtraction,
and persists the final value. Turn sequence is contiguous; round never
decreases or exceeds the cap; speaker must participate; usage addition is
overflow checked. Budget exhaustion atomically blocks with
`discussion_budget_exhausted` and inserts no turn. Round exhaustion atomically
fails with `discussion_round_limit_exceeded` and inserts no turn.

Completion requires an existing exact same-Camp materialization. Handoff/
Outcome/Verification reference the real object. Decision/cardRevision/
planRevision create immutable domain events in the same transaction with event
types `discussion.decision-materialized.v1`,
`discussion.card-revision-materialized.v1`, and
`discussion.plan-revision-materialized.v1`. Missing/cross-Camp/type mismatch
fails the discussion. Every mutation has domain command receipt/event/outbox.

### 6.2 Attention

Typed reasons derive levels; callers cannot request escalation:

- ordinary progress/audit -> recordOnly;
- milestone/summary -> summary;
- missing decision/approval/acceptance or plan conflict -> needsAction;
- cost anomaly, data/security risk, unrecoverable failure -> urgent.

The semantic dedupe key plus source event/target/reason forms the whole command
identity. Exact replay returns the row; drift conflicts. State transitions are
open->acknowledged/dismissed/resolved and acknowledged->resolved/dismissed;
terminal rows never reopen. recordOnly/summary return no notification intent.
Only Application projects needsAction/urgent; Core sends no notification.

### 6.3 Growth and same-transaction invalidation

`CoordinationStore` derives each evidence hash from canonical typed content;
the caller never supplies authority. Capability evidence, at propose and
activate, requires the current accepted Outcome version, current passed valid
Verification, and exact accepted Acceptance. Relationship/world evidence must
reference a same-Camp collaboration/milestone domain event. Status is
proposed->active->invalidated and never revives. Growth code has no
ApprovalGrant/runtime profile/model/permission mutation surface.

The five accepted P1-D reverse commands stay owned by `OutcomeStore`; F1
replaces their direct Memory-only invalidation call with one
`CoordinationStore.applyInvalidation` inside the caller's existing GRDB
transaction. It applies Memory and every affected active Growth row using the
same command event/time, returns a deterministic sorted summary, and lets any
error roll back receipt, events/outbox, Outcome/Goal/Mission/Verification/
Acceptance/metric/Memory/Growth. Causes cover return Outcome, revoke
Acceptance, invalidate Verification, new Outcome version, and dependency
delete/invalidate. Initial Outcome creation invalidates nothing.

## 7. Exact allowlist, entry bytes, and dirty boundary

The executable allowlist is the 91 unique LF-delimited, byte-sorted paths in
`scope-allowlist.txt`, SHA-256
`b52bee00a85a14c326511296e6da0e13763085228e834e8b4fb966a886e356df`.
It contains exactly 67 canonical product/test/Package/matrix paths and 24 task
artifacts. Markdown is not parsed to reconstruct scope.

The 43 present canonical paths and exact entry bytes are frozen by
`entry-source-manifest.sha256`, SHA-256
`6c7e2a3c851f7f84c8bb7b94c2a5725892a90e8dd449afc2344181ee11a0a2ed`.
`shasum -a 256 -c` must pass before Review01a. These 24 canonical paths are
absent and may only be created for their named responsibility:

- `Sources/AgentLoopCore/Domain/ExecutionEngine.swift`
- `Sources/AgentLoopCore/Domain/EngineExecutionReceipt.swift`
- `Sources/AgentLoopCore/Loop/ArtifactStager.swift`
- `Sources/AgentLoopCore/Loop/ArtifactOwnershipVerifier.swift`
- `Sources/AgentLoopCore/Loop/ModelLoopEngineAdapter.swift`
- `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`
- `Sources/AgentLoopCore/Database/EngineExecutionStore.swift`
- `Sources/AgentLoopCore/Database/EngineSessionStore.swift`
- `Sources/AgentLoopCore/Database/ArtifactBlobStore.swift`
- `Sources/AgentLoopCore/Database/ArtifactStorageOriginStore.swift`
- `Sources/AgentLoopCore/Knowledge/ManagedExpeditionReportStore.swift`
- `Sources/AgentLoopCore/Domain/Discussion.swift`
- `Sources/AgentLoopCore/Domain/AttentionItem.swift`
- `Sources/AgentLoopCore/Domain/GrowthEvidence.swift`
- `Sources/AgentLoopCore/Database/CoordinationStore.swift`
- `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`
- `Sources/AgentLoopTestSuite/EngineExecutionStoreTests.swift`
- `Sources/AgentLoopTestSuite/EngineTerminalProposalTests.swift`
- `Sources/AgentLoopTestSuite/ArtifactBlobStoreTests.swift`
- `Sources/AgentLoopTestSuite/ArtifactStorageOriginTests.swift`
- `Sources/AgentLoopTestSuite/ArtifactOwnershipVerifierTests.swift`
- `Sources/AgentLoopTestSuite/EngineSessionTests.swift`
- `Sources/AgentLoopTestSuite/DiscussionContractTests.swift`
- `Sources/AgentLoopTestSuite/AttentionGrowthContractTests.swift`

Existing allowlisted files may change only for canonical plan §8.1 ownership:

- Package/matrix only for v17 carrier/fixtures;
- Engine/adapter/Board/runner files only to move execution and terminal
  authority to Store and satisfy conformance;
- database/domain files only for v17 records, same-transaction mutations, and
  typed legacy compatibility;
- Application/App hosts only for managed-report and needsAction/urgent
  projection, not new product UI;
- predecessor tests may only add P1-F1 identities/fixtures or adapt removed raw
  authority while preserving their old assertions.

The scope gate uses NUL-safe Git enumeration and hashes every outside node as:

```text
u64be(path byte count) || path bytes || u32be(lstat mode) ||
  file: "F" || u64be(content byte count) || raw SHA-256(content)
  symlink: "L" || u64be(target byte count) || target bytes
```

Entry after creating only the allowlist was:

```text
allowlist_lines=91
allowlist_sha256=b52bee00a85a14c326511296e6da0e13763085228e834e8b4fb966a886e356df
dirty_total=630
allowlisted_present_count=37
outside_count=593
outside_manifest_v1=ce12c40362a7a119241a5179eb52ebca6625c0a5c7daede7a29e8a10aaf90a94
```

Task artifacts may increase only the first two live dirty counts. Outside must
remain exactly 593 and
`ce12c40362a7a119241a5179eb52ebca6625c0a5c7daede7a29e8a10aaf90a94`
through Review02. Top-level status documents already fact-synced after P1-E are
outside and frozen during this leaf.

## 8. Frozen protected inputs

| Input | SHA-256 |
|---|---|
| P1 stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-E acceptance | `114c3b6b157bce4e8de20bde5dbdc660bdeb8978629b5be1dcca0860891e50be` |
| P1-E Review02 | `77eae9651e0e907efc7a33810b5a4982d0be99ad13730069b7beee11227a06c0` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| RunTests | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `CommandEnvelope.swift` | `a2117c80b0c7d052b35b38de98f9b9f846fc965cb9b2f9278c18455b6081f39e` |
| `DomainEvent.swift` | `876896f4d48ab1614630dcbf7075b2a4bcb1a8ba309605c10eeb976c1e59b925` |
| `CanonicalContractCoding.swift` | `b15c1f9fc8d602b834eb517cefc7e27437da3d576cc4d388d9f6472032ccdcaa` |
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `DurableWorkStore.swift` | `aa85935c593783759ff92fa6d30ed4a868aab4b7b7a4f0dd72c88f471e7f15b9` |
| `EventKind.swift` | `3d8d79b441272a043b71c6965f6fd89f6bdb1f05b358c847814c988c5149a779` |
| `InputGoalStore.swift` | `5f6dd93127b8b11cec76fd76e1645636d6438f8f6c6039b38317fd3195a1ff00` |
| `CoachUnderstandingStore.swift` | `daa3a9bea1c7ad05e4553b5f13c616fba2d1542bf6afd9747eceb82e0f55a2e3` |
| `ApprovalGrantStore.swift` | `53036b10bf1266c3e216dbaece49ea20a5cf851cd9d9025017faa9349c622bd0` |
| `CowResidencyStore.swift` | `3875f3ec5fbd982713a69bbec4ecd6ead2031a067381829735447eaf5ed2c747` |
| `CampProviderDispatchStore.swift` | `3b92362eacc72830d812232522920fab9ed6b3f7920d8b877eccb0d1c47baf5f` |
| `InputWorkflowController.swift` | `7f99d61894de33268a8b2cb8622eb6b632bebd613e1d960fab836973945fbf2a` |

`EventKind`, durable work owner/supervisor, canonical coding, runner, and
Package resolution are outside the allowlist and must remain byte-identical.
The 43-entry manifest—not Git HEAD—is the pre-image authority for allowed
files because accepted predecessor changes include untracked files.

## 9. Exact tests and verification commands

`focused-test-manifest.txt` is the machine authority for exactly 100 unique
identities, SHA-256
`03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968`.
Each line is `NNN|Band|Path|Function`; ordinals are contiguous 001–100, bands
match §2, paths are allowlisted, and each function must be declared/discovered
exactly once. Tests are not renamed or replaced after their red evidence.

The manifest cases expand as follows:

- F1A: runtime literal/hash, all predecessor replay, deterministic origin
  backfill/attestations, rollback barrier, every v17 CHECK/FK/redaction/
  append-only trigger, repeated migrate, and both SQLite carriers.
- F1B: context/scope golden bytes and zero-write rejection, begin/replay/CAS,
  monotonic events and checked usage, whole proposals, all terminal taxonomy,
  ask-user, projection rollback, session bind/resume/drift, recovery precedence,
  and all four dispatch crash windows.
- F1C: existing-blob-first preparation, no-follow source verification,
  fsync/rename/recovery, all missing/corrupt failures, exact GC union/age/shared/
  tombstone behavior, atomic typed origins, legacy evidence/CAS, ownership
  counterexamples, raw String API removal, and managed report recovery.
- F1D: truthful descriptors/replay classes, four terminals, EOF/parser/cancel/
  usage/session/Board/error secrecy, fake Codex and Claude exact flags/session,
  capability selection, and removal of adapter/runner/Board DB authority.
- F1E: bounded Discussion/overflow/materialization, Attention dedupe/rule table/
  app projection, Growth evidence/injection barriers, and all five atomic
  reverse commands.
- F1F: Engine-to-accepted-Growth integration, crash replay at canonical steps,
  adapter terminal to Outcome/Verification/Acceptance, Application report/
  Attention projection, and F2 closure.

Red/focused/compat wrappers record command and tee status and only atomically
replace their named log on completed execution. Focused final command is the
exact manifest regex. Compatibility verification includes all 159 entry
identities from the 14 existing allowed test files plus all 100 F1 identities;
the wrapper proves set equality from source declarations and test-start lines,
then requires green. It cannot be called the authoritative full gate.

Final commands, each with full stdout/stderr and pipefail evidence, are:

```bash
swift run RunTests --filter '<exact 100-name manifest regex>'
swift run RunTests --filter '<exact existing-159 plus F1-100 regex>'
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
swift build --product AgentLoopApp
swift run RunTests
git diff --check
git status --short --branch
```

The unfiltered `swift run RunTests` is authoritative and must be the final test
command after source gates, migration matrix, build, and isolated preview. Do
not pass `--no-parallel`, edit RunTests, or substitute `swift test`.

## 10. Source and product gates

`source-gates.log` must prove all of the following from live bytes:

1. exact allowlist line/hash/unique/LF contract; 43 entry hashes; 24 absent-at-
   entry list; exact outside count/hash; protected input hashes;
2. v17 registration exactly once, v18 zero, runtime SQL 29,934/770/SHA exact,
   12 table/15 explicit-index/17 trigger declarations, split token once, no
   v17 trigger before typed backfill+barrier, no `IF NOT EXISTS`/`DROP TRIGGER`;
3. final schema checkpoint 79/208/84 and v16 predecessor 67/171/67;
4. migration/backfill span contains no filesystem/path-classification API;
5. `durablePath` raw completion authority zero; BoardTools raw copy/remove/
   unique destination/direct complete/block zero; Board/runner/adapters direct
   Run/Card/Mission mutation zero;
6. raw product `INSERT INTO artifact` occurs only in the reviewed OriginStore/
   engine terminal transaction owners; artifact database rows never point at
   staging/missing paths;
7. GC SQL contains the exact three content-hash roots and never proposalHash;
8. verifier/stager use no-follow capabilities and no authoritative
   `resolvingSymlinksInPath`, prefix/name/extension classification;
9. Orchestrator/AppStore report-root create/write zero; only
   ManagedExpeditionReportStore performs filesystem writes;
10. Growth/Coordination have zero ApprovalGrant/runtime-profile/model/
    permission mutation dependency; recordOnly/summary have zero notification;
11. all 100 manifest declarations and discovery identities match exactly;
12. old existing test identities remain declared, no assertion is removed or
    weakened, `git diff --check` passes, and no unfinished marker or fallback masks
    an error.

## 11. Build, packaged preview, and evidence

After focused, compatibility, matrix, and source gates are green:

1. `swift build --product AgentLoopApp` must pass and be captured in
   `build.log`.
2. Package a fresh app through the repository script and launch exactly once
   with a unique temporary `AGENTLOOP_STATE_DIR`; never use normal state.
3. Verify the exact executable path/PID, bundle executable/resources,
   codesign/ad-hoc integrity, fresh database integrity/FK, and migration tail
   v17/v16/v15.
4. In deterministic preview/fake-provider state, exercise projection of a
   needsAction/urgent item and a managed expedition report, plus one failure/
   recovery state. No credential, network provider, normal user data, or real
   notification is used.
5. Terminate only that exact PID, wait for disappearance, and prove no
   AgentLoop/AgentLoopApp process remains. Preserve full output in
   `preview.log`.

Required current artifacts are:

- `plan.md`, `scope-allowlist.txt`, `entry-source-manifest.sha256`,
  `focused-test-manifest.txt`, historical Review01, and effective independent
  Review01a;
- six immutable pure-red band logs;
- `focused-verify.log`, `compatibility-verify.log`, `migration-matrix.log`,
  `source-gates.log`, `build.log`, `preview.log`, and final `verify.log`;
- `verify-red.log` only if the first unfiltered run is red;
- `impl-report.md`, `blocked.md`, independent Review02, and `acceptance.md`.

`impl-report.md` lists every changed file, plan mapping, any reviewed revision,
red/green chronology, counts/durations/statuses, evidence hashes, no-Claude
disclosure, no-real-CLI disclosure, and prohibited external actions not done.
Logs contain complete output, not summaries. Review02 is read-only except its
sole report and independently checks implementation, tests, source gates,
outside hash, migration bytes, packaged preview, and all red lines.

## 12. Completion gate

P1-F1 is accepted only when all are true:

1. Review01a approves this exact plan/allowlist/manifests with 0 P0/P1 before
   product code;
2. each of six red logs predates its band implementation and demonstrates the
   planned missing capability;
3. exactly 100 focused identities pass once, and the 259-test compatibility
   declaration/discovery set is exact and green;
4. v17 runtime bytes and migration order are exact; all real/literal SQLite
   3.51/3.52 predecessor/replay/rollback lanes pass at 79/208/84;
5. kernel alone owns execution, Run/Card terminal, proposal, receipt, and
   recovery; adapters/Board/runner have no database terminal authority;
6. Artifact staging, recovery, GC, provenance/no-follow classification, and
   managed report ownership satisfy every positive and counterexample test;
7. Discussion/Attention/Growth and all five Memory/Growth reverse commands are
   deterministic, evidence-bound, and transactionally atomic;
8. fake ModelLoop/Codex/Claude conformance and full P1 integration pass without
   secrets or real external actions;
9. source/scope/protected/outside gates, build, isolated packaged preview, and
   final authoritative unfiltered `swift run RunTests` all pass;
10. Review02 reports 0 P0/P1, acceptance and reports are current, and no
    outside/prohibited action changed;
11. acceptance explicitly states Camp retirement/deletion is not enabled and
    P1 is not yet complete; the next leaf is P1-F2.

Once accepted, stop auditing P1-F1, sync only the authorized living status
indexes, and create/review P1-F2's separate decision-complete plan before any
F2 product write.

## 13. Red lines

- No commit, push, merge, PR, release, public deployment/message, payment,
  credential use, real-user action, normal-state mutation, or destructive data
  reset.
- No path outside the exact allowlist; no use of Git HEAD to overwrite accepted
  dirty pre-images; no hidden generated source.
- No F2 archive/unarchive/deletion request/repair/finalize/worker/permit/owner
  registry/global write fence/deletion supersession, and no product creation of
  `camp_deletion_proposal_blob` rows.
- `invalidCampDeletion` is schema/type-only and is never produced in F1.
- No Camp erasure, physical Camp delete, unlink of workspace external/unresolved
  Artifact, archive/delete UI, v18, P2 UI, or P3+ validation.
- No raw String artifact ownership, path-prefix/name/extension guessing,
  symlink-following authority, missing-as-external fallback, proposalHash GC
  root, or database reference to missing/staging bytes.
- No adapter/Board/runner direct Run/Card/Mission terminal mutation; no
  completed-on-EOF/parser-error; no duplicate terminal; no session `--last` or
  `--continue`; no descriptor/replay-class lie.
- No swallowed errors, `try?`/empty/default-success fallback on truth, saturated
  usage success, relaxed assertions, skipped matrix row, timing inflation,
  serial authoritative runner, documentation in place of execution, or green
  rerun without preserving the first red.

## 14. Revision 3 — F1B typed-safe command and write-fence correction

Revision 3 is the sole effective correction to §§4, 7–10 for F1B. All other
Revision 2 clauses remain unchanged. It is required by two bounded P0 findings
that were found after the first F1B implementation reached 26/26 focused green:

1. engine commands wrote full requests, execution records, progress text,
   external session IDs, and reason/detail text into the shared
   `domain_command_receipt` / `domain_event` append-only tables instead of the
   Stage §8.1 closed `CampSafeCommandResultV1` / `CampSafeAuditPayloadV1`
   carriers, and replay checked counts rather than the exact graph;
2. ordinary dispatch, event, proposal, session, terminal, and recovery writes
   did not all enforce the Stage §14.2 exact lifecycle-version write fence.

The first corrected 26-test diagnostic is preserved outside the repository at
`/tmp/p1f1-f1b-exact26-fixed.XXXXXX.log`, SHA-256
`c5fad66a70630eff0897ffb00b116020d99f7399727f5f9b0418a58472adb39a`.
It proves the initial Store/recovery behavior but is not F1B acceptance because
the privacy/fence/session counterexamples were absent. Revision 3 does not
reopen F1A, any accepted predecessor leaf, or any F1C+ product scope.

No Revision 3 product byte may change until Review01b approves this exact
section, allowlist, entry-manifest delta, tests-first matrix, and red lines with
0 P0/P1. After approval, the existing 017–042 identities are strengthened in
place, `red-f1b-revision3.log` is captured while the frozen implementation below
is still present, and only then may product correction begin.

### 14.1 Exact scope, pre-images, and boundary

The effective allowlist is 96 unique byte-sorted LF-delimited paths, SHA-256
`8d4e07d1ccda444a5b5c53ba7951e5514a07d01e9262990bbf2934cad9f50e73`.
It contains 70 canonical product/test/Package/matrix paths and 26 task
artifacts. Revision 3 adds exactly:

- `Sources/AgentLoopCore/Database/EventKind.swift`;
- `Sources/AgentLoopCore/Domain/CommandEnvelope.swift`;
- `Sources/AgentLoopCore/Domain/DomainEvent.swift`;
- `red-f1b-revision3.log`;
- `reviews/01b-p1-f1-plan-review.md`.

The first three were protected predecessor inputs, not absent files. Their
Revision 3 pre-images remain byte-identical:

| newly authorized input | Revision 3 pre-image SHA-256 |
|---|---|
| `EventKind.swift` | `3d8d79b441272a043b71c6965f6fd89f6bdb1f05b358c847814c988c5149a779` |
| `CommandEnvelope.swift` | `a2117c80b0c7d052b35b38de98f9b9f846fc965cb9b2f9278c18455b6081f39e` |
| `DomainEvent.swift` | `876896f4d48ab1614630dcbf7075b2a4bcb1a8ba309605c10eeb976c1e59b925` |

The effective 46-line entry manifest SHA-256 is
`6048f075e2d09b21f5b6d4e56f929d81fe1ec72441e336cfaa98e356de8b9924`.
Its original 43 entries remain historical pre-images; the three rows above are
the only Revision 3 additions. Existing F1A/F1B changes are never overwritten
to make a historical `shasum -c` green.

Revision 3 freezes these already-implemented F1B/test inputs until Review01b:

| input | SHA-256 |
|---|---|
| `EngineExecutionStore.swift` | `23ae9669644c387f4ca5161aac895d3bd041d68cc7daf227f69d423609d96d6e` |
| `EngineSessionStore.swift` | `babd02286771b2b49a5e3e7bff5a7fc2a33126039d57098038d391fb7de3a743` |
| `DomainEventStore.swift` | `676ce2d100b43cc6abc6f096aaa732ce41ac47c65721d572f6f44dd2ec6a9b52` |
| `ExecutionEngine.swift` | `66a61b6f696ea683d4cff3c0a1e89ac30a4e15d44f74d2c4071c3930ba852ee9` |
| `EngineExecutionReceipt.swift` | `7c75eded6c83cc3acf1da24bf06fb73de02fb4208f096fbe9c0e0501f495a976` |
| `EngineExecutionStoreTests.swift` | `569ffd4439bc120acddba0318978da40961d6f5cedeedbc58ee1689437241605` |
| `EngineTerminalProposalTests.swift` | `1273e0f9929c37bfc96f75930614e45008dbbfa05a1e42508583c81e0675ee9b` |
| `EngineSessionTests.swift` | `85dfc2b166f6bee414b8247d0b3a6004a32732a10ae49bf3ae10a1359b57f069` |
| `CrashRecoveryTests.swift` | `9f7a2c030fa7e94e98668fce480d59ec49b33b9f9685f7a18fae70d04fa67cd9` |

The NUL-safe outside boundary is now exactly 590 nodes / SHA-256
`ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee`.
The three newly authorized files are the only removals from Revision 2's
outside set. Review01b and every later gate recompute the same binary serializer.

No schema, migration, `AppDatabase.swift`, `Records.swift`, F1C file, adapter,
Board, Orchestrator, UI, or package dependency is added to Revision 3.

### 14.2 Closed engine command vocabulary

`EventKind.swift` appends, without renaming or reordering predecessor raw
values, the following exact closed cases:

- aggregate: `engineExecution = "engine_execution"`;
- commands: `engineExecutionBegin = "engine.execution-begin.v1"`,
  `engineDispatchStart = "engine.dispatch-start.v1"`,
  `engineCancellationRequest = "engine.cancellation-request.v1"`,
  `engineEventAccept = "engine.event-accept.v1"`,
  `engineTerminalProposalRecord = "engine.terminal-proposal-record.v1"`, and
  `engineTerminalCommit = "engine.terminal-commit.v1"`;
- events: `engineExecutionBegan`, `engineDispatchStarted`,
  `engineCancellationRequested`, `engineEventAccepted`,
  `engineTerminalProposed`, `engineTerminalCommitted`, and
  `engineAttentionIntent`, with raw values equal to the current
  `engine.*.v1` event names;
- result/audit codes: one closed case corresponding to each command/event,
  plus `engineAttentionIntent`; no arbitrary String escape hatch.

`DomainEvent.swift` appends these sorted safe kinds:

- refs: `engineExecution`, `engineTerminalProposal`;
- hashes: `engineRequest`, `engineTerminalProposal`;
- versions: `engineExecutionProjection`,
  `engineTerminalProposalProjection`, `engineExecutionEvent`.

It adds result branches `beginEngineExecution`, `startEngineDispatch`,
`requestEngineCancellation`, `acceptEngineEvent`,
`recordEngineTerminalProposal`, `commitEngineTerminal`, and
`commitEngineTerminalWithAttention`.

The exact base engine safe membership is:

```text
refs      = [engineExecution]
hashes    = [commandPayload, engineRequest]
versions  = [engineExecutionProjection, engineExecutionEvent]
counts    = [domainEvent, outbox]
times     = [occurredAt]
```

Proposal and terminal results additionally contain
`engineTerminalProposal` ref/hash and
`engineTerminalProposalProjection` version. Attention terminal has exactly two
events; every other engine branch has exactly one. `recordEngineTerminalProposal`
is a first-class safe command and uses receipt key
`engine.terminal-proposal.v1:<terminalIdempotencyKey>`.

For multiple events on one execution aggregate, replay-plan versions remain
strictly contiguous, while the safe result stores the last aggregate event
version. Existing single-event branches remain byte- and behavior-identical.
All safe arrays preserve enum-defined sorted order; predecessor canonical bytes
must not change.

`CommandEnvelope.swift` authorizes the six engine command types only when:

```text
actorType=engine
actorId=engine:kernel:v1
deviceId=NULL
correlationId=<exact executionId>
causationId=NULL
```

Engine commands use the normal `PreparedDomainCommandV1.make` whole-envelope
hash and the strict `DomainEventStore`; neither the P1-D generic executor nor a
local safe-looking JSON carrier is allowed. On replay the Store reconstructs
the sealed first-write envelope from the validated receipt/event graph, so a
later wall clock does not change identity. Wrong actor/device/correlation/
causation, type, whole hash, ordinal, aggregate version, event key, payload,
scope, or outbox linkage fails closed.

### 14.3 Strict executor metadata and API reconstruction

`DomainEventStore` adds a non-persisted metadata return for its existing strict
executor:

```swift
package struct DomainCommandExecutionMetadataV1 {
    package let result: CampSafeCommandResultV1
    package let resultHash: String
    package let eventIds: [String]
    package let wasReplay: Bool
}
```

The metadata overload keeps the existing transaction order and exact graph
validation, permits an explicit validated `recordedAt` for engine-owned events,
and returns event IDs in ordinal order. Existing callers retain the old result-
only wrapper. New commands build projection plus `NewDomainCommandV1` in the
same transaction; later receipt/event/outbox failure rolls the projection back.
Replay validates the complete stored graph and never invokes the new-projection
closure.

`EngineExecutionStore` deletes its raw `EngineDomainEventSpecV1`, generic
`executeCommand`, and all direct INSERTs into the three shared command/event/
outbox tables. API results are reconstructed as follows:

- begin: safe execution ref + request hash -> strict authoritative execution
  row rehydrate;
- dispatch: same rehydrate; new metadata -> `.startNow`, replay metadata ->
  `.alreadyStarted`;
- cancellation: ref/hash/version -> exact execution row;
- accepted nonterminal event: safe result + final projection validation ->
  `Void`;
- proposal record: safe proposal ref/hash/version -> exact proposal plus
  ordinal artifact rows;
- terminal: typed command/proposal + ordered event IDs + authoritative terminal
  row + safe `resultHash` -> `EngineTerminalCommitReceiptV1`.

No context, model, workspace reference/path, external session ID, progress/tool
text, reason detail, prompt/options, or artifact path/label appears in safe
receipt/event JSON. Such material remains only in its erasable projection,
proposal/blob, or legacy-event carrier.

`EngineTerminalCommitReceiptV1.terminalReceiptHash` becomes the validated strict
receipt `resultHash`; it is no longer a hash of the API receipt object. That
same value is written to `engine_execution.terminalReceiptHash`. Proposal hash
remains distinct and never substitutes for it.

### 14.4 Exact active write fence and replay order

Every first ordinary begin/dispatch/cancel/event/proposal/session/pre-dispatch/
terminal/ask-user/invalidation write validates, in its own write transaction:

```text
campId = execution/request Camp
camp_lifecycle.state = active
camp_lifecycle.version = execution.campLifecycleVersion
camp.archived = false
```

Begin validates active lifecycle and legacy archived bit before allocation.
Exact committed receipt/proposal replay validates identity and graph first and
returns with zero writes even if lifecycle later changed. Same-key drift still
conflicts. A new or not-yet-committed command under archived, lifecycle-version
drift, deletionRequested, deleting, or deletedTombstone returns the typed Camp
write-fence error with no new receipt/event/outbox/projection. Generic APIs never
accept or infer an F2 permit.

`acceptEngineEvent` has no duplicate replay: an already-consumed sequence still
throws `EngineEventSequenceErrorV1`. The shared active guard is called only on
the first command path; the private terminal projection helper remains permit-
agnostic so F2 can later add a separate specialized owner without weakening the
ordinary fence.

Recovery reads lifecycle state/version and `camp.archived` before decoding
request/context/proposal/session material. Exact active/version/nonarchived is
required before any descriptor validation, start, resume, replay, or terminal
write. `deletionRequested|deleting` returns an F2 deferral containing only IDs
and optional proposal ID, never a full request; archived returns the typed
read-only fence error; deletedTombstone is a stable no-write terminal scan.
Lifecycle mismatch is never converted into engine protocol error.

### 14.5 Session, event, taxonomy, and recovery invariants

Store resolves an internal session ID to its exact active DB row after deriving
the session scope. The canonical adapter-facing request contains both internal
session ID and Store-derived external session ID; caller input may identify only
the internal ID and cannot claim the external value. Full request JSON may hold
the external ID, but safe receipt/event JSON may not.

`requireExactResume` accepts the adapter-reported external ID and explicit
finite `now`; it requires byte equality with the DB row and resolved request,
then CASes `started -> sessionBound` once. Duplicate sessionBound, mismatched
external ID, scope/workspace/adapter/profile/Camp/version drift, or inactive Camp
rolls back session, execution, events, and outbox. `closeOrInvalidate` performs
an exact version/state CAS: closed preserves the external ID and scope; invalid
marks state invalid without redaction and also preserves audit fields. F2 alone
owns redaction/nulling.

`EngineExecutionEventPayloadV1` has exactly six tagged Codable cases:
accepted, sessionBound, progress, toolActivity, usage, terminal. Terminal carries
the whole `EngineTerminalProposalContentV1` and routes to the proposal-record
safe command; it does not grant progress/adapter direct terminal authority.

Pre-dispatch terminal taxonomy is only failed+nil subtype or
blocked+engineProtocolError. Proposal/receipt decode validates every UUID,
lowercase hash, finite time, unique ordered IDs, terminal kind/subtype/payload,
stable `validateCode` reason, and nonempty bounded detail/prompt. Engine ask-user
rejects `.approval`; choice requires 2–6 unique nonempty options, confirm/text
require zero options.

Every synthetic kernel terminal (pre-dispatch failure, usage overflow, prepared
cancel, external-effect-unknown, or recovery protocol error) first creates an
exact durable zero-artifact proposal inside the same transaction. The receipt
therefore always references a real proposal ID/hash. Valid synthetic engine
terminal uses `committedProposal`; only invalidation of an existing pending
proposal uses `invalidProtocolError`. Before any active recovery action, exact
descriptor/version/derived scope/replay class is validated. Deletion deferral
is the sole branch that deliberately does not decode or validate descriptor.

### 14.6 Strengthened tests-first matrix and red evidence

The manifest remains exactly 100 identities and F1B remains 017–042; no test is
renamed or weakened. Before product correction, the four F1B test files add:

- 022/025/027/029/031/033/036/038: every engine receipt decodes only as
  `CampSafeCommandResultV1`, every event payload only as
  `CampSafeAuditPayloadV1`, safe JSON excludes the forbidden body/session/path
  sentinels, event keys use exact `#0000:` format, attention versions are
  contiguous, and API/execution/receipt hashes agree but differ from proposal
  hash;
- 023/025/038: tampering one event type/payload/hash/ordinal/aggregate version,
  scope, receipt field, or outbox link fails graph validation and performs no
  replay apply;
- 022/023/025–027/031–033/035/036/038/039/042: first writes reject archived,
  legacy archived-bit drift, lifecycle-version drift, deletionRequested,
  deleting, and deleted state with exact surface/projection snapshots; exact
  already-committed replay remains zero-write and stable;
- 021: claimed old scope plus model/workspace/contract drift is zero-write;
- 027: all six event cases, duplicate sessionBound rejection, terminal routing,
  and no progress terminal authority;
- 039–041: Store-resolved external session ID, wrong-ID zero-write, one bind,
  exact resume time/version, and close/invalid replay/stale matrix;
- 026/030/034–036/038: invalid taxonomy, UUID/hash/time/duplicate ID, blank code/
  detail/prompt, `.approval`, and options counterexamples;
- 042: lifecycle-first no-decode deletion scans, no-proposal deferral,
  archived/deleting/deleted zero-write, descriptor precedence over pending/
  cancellation, session mismatch/unsupported, and real proposal-linked
  synthetic receipts.

`red-f1b-revision3.log` captures the exact 26-name filter once, with complete
stdout/stderr and pipefail command/tee statuses. It must fail on these missing
contracts while the §14.1 pre-images are still present. Harness compile defects
may be corrected only if assertions/identities remain unchanged; the corrected
red is then rerun once and preserved. After implementation the same exact 26
must pass together.

### 14.7 Revision 3 completion gate and red lines

F1B closes only when Review01b is APPROVED with 0 P0/P1, the Revision 3 red
predates product correction, all 26 pass together, Core builds, the strict safe
decoder/tamper/fence/session/taxonomy/recovery matrix passes, and an independent
bounded implementation review reports 0 P0/P1. Then `blocked.md` records F1B
closed and F1C alone opens.

Revision 3 additionally forbids:

- arbitrary String engine command/event/audit vocabulary or a local
  safe-looking carrier that bypasses the closed decoder/catalog;
- storing API request/receipt, progress, external session ID, reason detail,
  prompt/options, path, label, or user/device identity in safe JSON;
- direct Engine Store INSERT into shared receipt/event/outbox or use of the
  P1-D generic executor;
- replay count-only validation, new-projection execution during replay, or a
  wall-clock-changed replay envelope;
- ordinary writes after the active exact-version fence, deletion-time decode/
  resume/terminalization, or generic consumption of an F2 permit;
- fake proposal IDs/hashes, proposalHash as terminalReceiptHash, descriptor
  validation after a recovery action, or synthetic terminal without a real
  proposal;
- adding F1C artifact staging/blob/GC, F1D adapter implementation, F2 deletion
  authority, schema/migration changes, or any path outside the 96-line list.

### 14.8 Revision 3a exact persisted engine contract

Revision 3a is the sole plan-only successor to Review01b, SHA-256
`580928733aabf1b08a30b566de304399069cf6e02f5a9749c16e1f8bd8d737e5`,
which reported `CHANGES REQUIRED - 0 P0 / 2 P1`. It closes only those two
decision-completeness findings. Sections 14.8-14.10 override any less precise
wording in §§14.2, 14.5, and 14.6; all other Revision 3 scope, pre-images,
tests-first ordering, completion gates, and red lines remain unchanged. The
96-line allowlist, 46-line entry manifest, and 590-node outside boundary do not
change. The original Review01b bytes remain a prefix of the same already
allowlisted review file; the responsibility-isolated successor verdict is
appended there rather than creating another artifact path.

The new cases are appended to their existing closed enums and predecessor
cases/order are not changed. These are domain command/event vocabulary, not
legacy `EventKind` rows, so none is added to `EventKind.allPersistedKinds`.

| category | Swift case | exact persisted raw value |
|---|---|---|
| aggregate | `engineExecution` | `engine_execution` |
| command | `engineExecutionBegin` | `engine.execution-begin.v1` |
| command | `engineDispatchStart` | `engine.dispatch-start.v1` |
| command | `engineCancellationRequest` | `engine.cancellation-request.v1` |
| command | `engineEventAccept` | `engine.event-accept.v1` |
| command | `engineTerminalProposalRecord` | `engine.terminal-proposal-record.v1` |
| command | `engineTerminalCommit` | `engine.terminal-commit.v1` |
| event | `engineExecutionBegan` | `engine.execution-began.v1` |
| event | `engineDispatchStarted` | `engine.dispatch-started.v1` |
| event | `engineCancellationRequested` | `engine.cancellation-requested.v1` |
| event | `engineEventAccepted` | `engine.event-accepted.v1` |
| event | `engineTerminalProposed` | `engine.terminal-proposed.v1` |
| event | `engineTerminalCommitted` | `engine.terminal-committed.v1` |
| event | `engineAttentionIntent` | `engine.attention-intent.v1` |
| result | `engineExecutionBegan` | `engine_execution_began` |
| result | `engineDispatchStarted` | `engine_dispatch_started` |
| result | `engineCancellationRequested` | `engine_cancellation_requested` |
| result | `engineEventAccepted` | `engine_event_accepted` |
| result | `engineTerminalProposed` | `engine_terminal_proposed` |
| result | `engineTerminalCommitted` | `engine_terminal_committed` |
| audit | `engineExecutionBegan` | `engine_execution_began` |
| audit | `engineDispatchStarted` | `engine_dispatch_started` |
| audit | `engineCancellationRequested` | `engine_cancellation_requested` |
| audit | `engineEventAccepted` | `engine_event_accepted` |
| audit | `engineTerminalProposed` | `engine_terminal_proposed` |
| audit | `engineTerminalCommitted` | `engine_terminal_committed` |
| audit | `engineAttentionIntent` | `engine_attention_intent` |

Attention has no result code: it is terminal commit's second audit event, and
that command's result remains `engine_terminal_committed`. Safe kind raw values
are their exact case spellings: refs `engineExecution` and
`engineTerminalProposal`; hashes `engineRequest` and
`engineTerminalProposal`; versions `engineExecutionProjection`,
`engineTerminalProposalProjection`, and `engineExecutionEvent`. They are
appended to the predecessor hand-written order switches. Exact command graphs
are:

| branch | command | result | ordered event / audit graph |
|---|---|---|---|
| `beginEngineExecution` | `engineExecutionBegin` | `engineExecutionBegan` | `0: engineExecutionBegan / engineExecutionBegan` |
| `startEngineDispatch` | `engineDispatchStart` | `engineDispatchStarted` | `0: engineDispatchStarted / engineDispatchStarted` |
| `requestEngineCancellation` | `engineCancellationRequest` | `engineCancellationRequested` | `0: engineCancellationRequested / engineCancellationRequested` |
| `acceptEngineEvent` | `engineEventAccept` | `engineEventAccepted` | `0: engineEventAccepted / engineEventAccepted` |
| `recordEngineTerminalProposal` | `engineTerminalProposalRecord` | `engineTerminalProposed` | `0: engineTerminalProposed / engineTerminalProposed` |
| `commitEngineTerminal` | `engineTerminalCommit` | `engineTerminalCommitted` | `0: engineTerminalCommitted / engineTerminalCommitted` |
| `commitEngineTerminalWithAttention` | `engineTerminalCommit` | `engineTerminalCommitted` | `0: engineTerminalCommitted / engineTerminalCommitted`; `1: engineAttentionIntent / engineAttentionIntent` |

Both attention events use aggregate `engine_execution`; their versions are
contiguous and the safe result stores the final version. The exact safe
membership remains §14.2. Proposal/terminal branches add the proposal
ref/hash/version. Every non-attention command has `domainEvent=1,outbox=1`;
attention terminal has `domainEvent=2,outbox=2`.

`EngineExecutionEventPayloadV1` uses these exact cases and hand-written tagged
Codable; synthesized enum layout is forbidden:

```swift
case accepted
case sessionBound(externalSessionId: String)
case progress(message: String)
case toolActivity(name: String)
case usage(EngineUsageV1)
case terminal(EngineTerminalProposalContentV1)
```

Outer `EngineExecutionEvent` has exactly keys `executionId,payload,sequence`.
Payload decoding rejects missing, extra, or nullable-instead-of-required keys:

| case | exact `kind` | exact payload keys | associated value |
|---|---|---|---|
| accepted | `accepted` | `kind` | none |
| sessionBound | `sessionBound` | `externalSessionId,kind` | exact external ID |
| progress | `progress` | `kind,message` | progress message |
| toolActivity | `toolActivity` | `kind,name` | tool name |
| usage | `usage` | `cacheReadTokens,costMicros,inputTokens,kind,outputTokens` | four required nonnegative `Int` values, with no nested `usage` object |
| terminal | `terminal` | `kind,proposal` | whole terminal proposal |

For terminal, outer execution ID/sequence must equal the proposal's exact
execution ID/sequence. It routes directly to the proposal-record command and
does not also emit `engine.event-accept.v1`. Progress/tool activity never have
terminal authority. A resumed sessionBound external ID must equal the resolved
request reference byte-for-byte; only a first bind may create a session. Usage
validates all four fields nonnegative before checked accumulation.

Caller session selection and canonical adapter material are separate types:

```swift
package struct EngineSessionSelectionV1: Sendable, Equatable {
    package let sessionId: String
}

package struct EngineSessionReferenceV1: Sendable, Equatable, Codable {
    package let sessionId: String
    package let externalSessionId: String
}
```

`EngineExecutionRequestFieldsV1` contains optional `sessionSelection`, which is
not Codable and never directly hashed. Store resolves it against an exact
active session row after Camp/profile/adapter/version/scope/workspace checks.
`EngineExecutionRequest.sessionRef` remains the canonical JSON key, is optional
resolved `EngineSessionReferenceV1`, and is either `null` or an exact object
with keys `externalSessionId,sessionId`. Store fills both fields before
canonical request encoding. A caller cannot supply the external ID. Missing or
inactive rows, blank external ID, or scope drift fail before begin writes.

All validation observes the original String; it never trims then stores,
truncates, replaces, lowercases, case-folds, or applies Unicode normalization.
Where a value is "already trimmed", the original must equal its
`whitespacesAndNewlines` trim or it is rejected. Original bytes participate in
identity. Exact scalar/collection bounds are:

| material | exact validation |
|---|---|
| durable engine UUID | execution/run/card/internal-session/proposal/artifact/event/user-request IDs pass `validateCanonicalUUID`: 36 UTF-8 bytes/scalars and uppercase canonical spelling |
| external session ID | 1...512 Unicode scalars and 1...512 UTF-8 bytes; `validateNonempty` |
| caller idempotency or terminal key | 1...256 scalars and 1...256 UTF-8 bytes; `validateNonempty` |
| reason/code | 1...128 scalars, at most 128 UTF-8 bytes, and existing `validateCode`; fixed kernel reasons use the lowercase constants in §14.9 |
| detail, prompt, progress | 1...1000 scalars and 1...4000 UTF-8 bytes; `validateNonempty`; no raw provider/Error body |
| tool activity name | 1...128 scalars and 1...512 UTF-8 bytes; `validateNonempty` |
| each choice option | 1...256 scalars and 1...1024 UTF-8 bytes; `validateNonempty` |
| choice options | exactly 2...6, caller order preserved, raw `Data(option.utf8)` unique |
| confirm/text options | exactly zero |
| approval request | always rejected by engine ask-user |
| proposal artifact declarations / receipt artifact IDs | 0...256; declaration ordinals exact `0...n-1`; receipt IDs unique and proposal-ordinal ordered |
| committed event IDs | exactly 1 for normal terminal or 2 for attention terminal; unique and event-ordinal ordered |
| hashes | exact 64-byte lowercase hex through `validateLowercaseHash` |
| dates | finite, with existing transaction ordering retained |

### 14.9 Exact synthetic terminal matrix

For this section `X` is the canonical execution UUID, `n` is
`engine_execution.nextSequence` at outer-transaction entry, and `T` is the
terminal idempotency key below. Proposal-record receipt/command key is always
`R = "engine.terminal-proposal.v1:" + T`; terminal receipt/command key is
always `C = "engine.terminal.v1:" + T`.

| source | exact `T` | required facts | exact proposal terminal | Attention | disposition |
|---|---|---|---|---|---|
| pre-dispatch failure | `engine.pre-dispatch-failure.v1:<X>` | running+prepared, dispatchStartedAt nil; retained API command key must equal exact `C` | caller failure is either `blocked/engineProtocolError/blocked(reasonCode,detail)` or `failed/nil/failed(code,detail)`; 026 fixes first form and reason `descriptor_capability_mismatch` | no | committedProposal |
| usage overflow | `engine.usage-overflow.v1:<X>` | started/sessionBound, incoming sequence=`n`, checked addition overflows before event command commits | `failed/nil/failed(code="usage_overflow",detail="engine usage counter overflow")` | no | committedProposal |
| prepared cancellation | `engine.recovery.cancel-prepared.v1:<X>` | running+prepared with persisted cancellationRequestedAt and nonempty validated cancellationReason | `canceled/nil/canceled(reasonCode=<exact persisted reason>,detail="engine execution canceled before dispatch")`; no fallback | no | committedProposal |
| external effect unknown | `engine.recovery.external-effect-unknown.v1:<X>` | nonReplayable+started/sessionBound, no pending proposal, and this branch precedes cancellation | `blocked/externalEffectUnknown/blocked(reasonCode="external_effect_unknown",detail="non-replayable dispatch outcome is unknown")` | urgent | committedProposal |
| recovery protocol error | `engine.recovery.protocol-error.v1:<X>` | active exact-version nonarchived fence passed, no pending proposal, then descriptor/request/session/recovery validation fails | `blocked/engineProtocolError/blocked(reasonCode="engine_protocol_error",detail="persisted engine recovery identity mismatch")` | urgent | committedProposal |

Dynamic pre-dispatch/cancellation reason and detail use the exact already-
validated bytes; there is no trim, normalization, or fallback. The existing
`proposalIdFactory` supplies a canonical UUID only after both `R` and `C` are
confirmed absent, inside the outer transaction. A rollback exposes no proposal
identity and may discard that candidate. After commit, all replay locates the
persisted proposal by `T`/`R` and never calls the factory again.

Each synthetic proposal's canonical content is exactly protocol version
`agentloop.execution.v1`, exact execution/run/card IDs, `sequence=n`, the table
`T` and terminal payload, and `artifacts=[]`. The real proposal row carries that
whole JSON/hash and `artifactManifestJson=[]`; it creates no proposal-artifact
row. The terminal receipt references its actual ID/hash, and receipt resultHash
is the terminalReceiptHash.

All five branches run two strict commands in one outer `database.pool.write`:

1. `R` records the pending proposal, moves execution projection version
   `p -> p+1` and dispatch state to terminalProposed, and writes one receipt,
   `engine.terminal-proposed.v1` event at ordinal zero, and one outbox;
2. `C` moves proposal pending/version 1 to committed/version 2 and execution
   `p+1 -> p+2` to terminal. A non-attention branch writes one receipt, one
   terminal event, and one outbox. An attention branch writes one receipt,
   terminal then attention events at ordinals 0/1, and two outboxes. F1B writes
   no `attention_item`.

Terminal receipt `committedEventIds` contains only C's one or two ordered event
IDs. Proposal event/result saves aggregate version `a+1`; terminal result saves
`a+2` or attention-final `a+3`. Each result's counts describe its own command,
not the outer transaction. Non-attention total delta is two receipts/events/
outboxes, one proposal, zero proposal artifacts, one legacy terminal event;
attention total is two receipts, three events/outboxes, one proposal, zero
proposal artifacts, and one legacy terminal event. Any projection, receipt,
event, outbox, or legacy failure rolls back both commands and the proposal.

Synthetic proposal sequence is `n`, but kernel synthesis is not an accepted
adapter event: neither command increments `nextSequence`, and terminal leaves
it exactly `n`. Usage overflow therefore retains test 028 exactly: attempted
sequence 0, proposal sequence 0, terminal nextSequence 0, unchanged counters,
no usage receipt/domain event/outbox/legacy usage event, and checkedUsage zero.
The committed synthetic terminal remains, then the API throws the nested
`UsageOverflowError`. A duplicate adapter event still throws
`EngineEventSequenceErrorV1`; it cannot replay through a synthetic receipt.

Normal adapter terminal proposal/commit and test 036 existing-proposal
invalidation do consume the one accepted terminal sequence (`n -> n+1`) and do
not reuse the synthetic no-consume flag. If recovery or preparation fails with
an existing pending proposal, no second proposal is created: the original is
invalidated through `invalidateProposalAndCommitProtocolError`, disposition is
`invalidProtocolError`, terminal is blocked+engineProtocolError with urgent
attention, and the transaction adds one receipt, two events/outboxes, one
legacy terminal event, consumes one sequence, and keeps proposal count one.

Exact committed synthetic replay first validates both R and C receipt/event/
outbox graphs, canonical proposal bytes/hash, projection transitions, execution
terminal linkage, and strict resultHash, then returns the first receipt with
its first finishedAt/event IDs/hash and zero writes regardless of later clock or
lifecycle. Same T with any terminal/run/card/sequence/proposal-byte drift is a
conflict. Only R or only C, a missing proposal, wrong ordinal/version/outbox, or
linkage drift is graph-integrity failure and is never healed. A terminal
execution is omitted from later recovery scans.

### 14.10 Revision 3a tests and successor review

The existing 017-042 identities are strengthened, without adding identities,
to assert the exact §14.8 golden bytes/key sets/bounds/session separation and
the complete §14.9 per-branch identity, two-command graph, totals, sequence,
rollback, and replay matrix. Test 028 keeps `nextSequence == 0`; test 036 keeps
the original proposal and consumes one adapter sequence. No test/product byte
changes until a responsibility-isolated reviewer appends a successor section
to Review01b and reports `APPROVED - 0 P0 / 0 P1` for the amended plan. The
subsequent red log still predates every Revision 3 product change.

## 15. Revision 4 — F1C compile-red and legacy fixture boundary correction

Revision 4 is a plan-only successor for F1C. It does not reopen F1A or F1B,
does not change the accepted F1B implementation, and does not expand F1C's
product responsibility beyond §§5.1–5.3. The effective Revision 3a plan
pre-image is SHA-256
`ae3162dbe24d2069009e7ffbc33e75b82c31c859a2a658db6bbbf543d7edf609`.
F1B closed with exact 017–042 focused evidence and the final bounded Review02,
SHA-256
`8a06de21ba238b02afc2030e82414e992b03e005899c875af3554773a7044673`,
verdict `APPROVED — 0 P0 / 0 P1`. Those bytes and findings are inputs, not a
new review surface.

Two verified entry facts require this single correction before any F1C test or
functional product write:

1. the five F1C product owners and all three F1C test files are absent at
   entry. Directly adding 043–061 first would fail compilation, discover zero
   tests, and violate §2's requirement that all 19 red tests be discovered and
   fail for the missing capability rather than for a missing symbol;
2. `GuideChatTests.swift` contains the only nonempty predecessor fixture that
   calls `BoardCardTransactions.completeCard` with a raw
   `(ArtifactDecl, durablePath: String)` tuple. The raw authority must disappear
   for identity 059, but that existing test must continue to prove its original
   Camp-status deliverable behavior. It cannot be preserved through reflection,
   a raw compatibility overload, or a fabricated database row.

No product, test, build, migration, matrix, or app command may run under this
revision until an independent Codex reviewer checks this exact section, the
machine allowlist/manifests, the frozen pre-images, and writes the sole new
review artifact
`reviews/01c-p1-f1-plan-review.md` with
`APPROVED — 0 P0 / 0 P1`.

### 15.1 Exact compile-scaffold exception and tests-first order

After Review01c approval, and before any 043–061 test declaration, the five
absent product owners plus the already-present v17 record owner may receive a
declaration-only compile scaffold:

- `Sources/AgentLoopCore/Database/Records.swift`;
- `Sources/AgentLoopCore/Loop/ArtifactStager.swift`;
- `Sources/AgentLoopCore/Loop/ArtifactOwnershipVerifier.swift`;
- `Sources/AgentLoopCore/Database/ArtifactBlobStore.swift`;
- `Sources/AgentLoopCore/Database/ArtifactStorageOriginStore.swift`;
- `Sources/AgentLoopCore/Knowledge/ManagedExpeditionReportStore.swift`.

The scaffold declares only the package-visible value types, closed enums,
initializers, and throwing operation signatures required by §§5.1–5.3 and
043–061. `ArtifactStager` has exactly the three operations frozen in §5.1;
`ArtifactStorageOriginStore` has exactly the three operations frozen in §5.2;
`ManagedExpeditionReportStore` has exactly the four operations frozen in §5.3.
The Blob Store and verifier expose only the validation, recovery, GC, root-
snapshot, and no-follow classification operations needed by the positive and
counterexample matrices 043–058. Deterministic package-only clocks, UUID
factories, filesystem fault points, root-descriptor fixtures, and transaction-
local overloads are permitted solely as test seams; they may not create an
additional production owner or path-based authority.

The one scaffold failure and its diagnostic vocabulary are exactly:

```swift
package enum ArtifactCapabilityV1:
    String, Sendable, Equatable, CaseIterable
{
    case prepare
    case recoverPreparation
    case cleanOrphanedStaging
    case validatePreparedArtifacts
    case collectGarbage
    case recoverQuarantined
    case insertPreparedArtifacts
    case insertWorkspaceExternalArtifact
    case upgradeLegacyOrigin
    case verifyOwnership
    case ensureReport
    case regenerateReport
    case recoverPendingWrites
    case reportURL
}

package struct ArtifactCapabilityUnavailableErrorV1:
    Error, Sendable, Equatable
{
    package let capability: ArtifactCapabilityV1

    package init(_ capability: ArtifactCapabilityV1) {
        self.capability = capability
    }
}
```

Every scaffold operation that could read or write SQLite or the filesystem
must throw its matching `ArtifactCapabilityUnavailableErrorV1` before
allocating an ID,
opening a path, acquiring a lock, starting a task, or mutating any in-memory or
persistent state. No operation may return success, an empty collection, nil,
or a placeholder value. Separate immutable value constructors may validate
their own caller material without DB/FS access, but every Store/verifier/stager
operation body is the immediate matching unavailable throw. No constructor may
manufacture a prepared artifact or ownership proof. `PreparedArtifactV1`, verified-managed evidence, verified-
external evidence, and trusted root capabilities have no public or package
initializer usable by a product caller; only their reviewed owning operation
can create them after functional implementation. `ExpeditionReport.markdown`
remains a pure renderer and is not part of the scaffold exception.

The exception changes §2 ordering only as follows, and nothing else:

1. freeze the approved declaration-only scaffold and prove it parses/builds
   far enough for test discovery;
2. add exactly manifest identities 043–061 once in their already frozen files;
3. run the anchored exact-19 filter under `set -u -o pipefail` and atomically
   preserve full stdout/stderr in `red-f1c-artifact.log`;
4. require command status nonzero, tee status zero, discovered identities equal
   the exact 19-name manifest, and every failure to name the typed unavailable
   scaffold or the directly resulting unmet capability assertion. A compile
   error, fixture/setup fault, crash, unrelated predecessor failure, missing
   identity, or fewer/more than 19 discovered tests invalidates the red;
5. only after that pure red may implementation replace the unavailable throws,
   one demonstrated root at a time. Each 043–061 capability must become green
   through the real DB/filesystem path; the scaffold error must have zero
   references in product or tests at the F1C completion gate.

The scaffold is not an implementation milestone and cannot satisfy any F1C
assertion, source gate, report, preview, or completion clause. It exists only
to make the required runtime red observable without inventing functionality.

### 15.2 Exact predecessor adaptation and filesystem ownership

`Sources/AgentLoopTestSuite/GuideChatTests.swift` is newly allowlisted for one
bounded adaptation only. In
`campStatusToolReportsMissionsAndDeliverables`, its single nonempty raw tuple
fixture must create one real unique temporary regular file, construct one
validated `WorkspaceExternalArtifactReferenceV1.explicit` for that Card/kind/
label/fixed time, and use the typed `workspaceExternalArtifacts:` completion
surface. The Origin Store inserts artifact+external origin atomically in the
same Card completion transaction. The existing assertions remain: one mission,
one done Card, and the
`recentDeliverables` label `桥料清单`, with byte-identical repeated status-tool
output. No other Guide chat behavior, provider fixture, assertion, or identity
may change. Direct `ArtifactRecord.insert`, SQL fixture insertion, raw
`durablePath`, unchecked `/tmp/x`, reflection, and a test-only product bypass
are forbidden.

The public and transaction-local nonempty raw artifact overloads of
`BoardCardTransactions.completeCard` are removed. No replacement accepts a
String/URL path as ownership evidence. Existing no-artifact predecessor calls
may use an explicitly no-artifact overload, a `[Never]` compatibility overload
that can never represent a nonempty artifact, or the kernel terminal path.
The only legacy nonempty overload accepts typed
`[WorkspaceExternalArtifactReferenceV1]`, revalidates Card/kind/label against
the handoff, and calls the Origin Store in the same GRDB transaction. No
generic/reflection/tuple adapter can carry one artifact. `BoardTools` no longer copies to a
unique destination, rolls back by best-effort remove, or directly completes a
Card with artifacts. Until F1D injects the terminal sink, its legacy completion
may complete only a zero-artifact handoff; a nonempty declaration fails before
copy/delete/Card/artifact mutation. Identity 059 statically and behaviorally
proves that no nonempty raw path authority remains.

`ManagedExpeditionReportStore` is the sole report filesystem owner across all
three entry writers, not only the two originally named call sites:

- `Orchestrator` closeout calls `regenerateReport(missionId:)`;
- `AppStore` ensure/open/reveal calls the Store;
- `MissionWorkflowController.live` injects the same Store and its
  `ensureReport(missionId:)` closure delegates to it.

All three lose report-root `fileExists`, `createDirectory`, and `write(to:)`
authority. `ManagedExpeditionReportStore` derives mission→squad→Camp before a
write, owns the trusted root/no-follow traversal, deterministic bytes,
staging/fsync/atomic-rename/directory-fsync sequence, and durable recovery
cursor. Identity 060 proves it is the only writer/registry owner; identity 061
fault-injects every cursor boundary and proves recovery never returns a missing
or unregistered final file. This remains F1 report creation/recovery only; it
does not delete reports or create F2 permits.

### 15.3 Frozen F1C roots, gates, and red lines

Functional implementation remains exactly the Stage §14.2/§16.3 and plan
§§5.1–5.3 contract:

- existing immutable blob is verified before any workspace read; missing blob
  alone authorizes a no-follow workspace source read, and a corrupt existing
  blob is a deterministic failure;
- preparation order is staging write → file fsync → atomic rename → directory
  fsync → blob row → proposal-artifact prepared CAS. Rename-before-row and all
  other injected crash windows recover without a database reference to missing
  bytes;
- GC roots are exactly pending declared/prepared proposal content hashes,
  active blob-reference content hashes, and nonterminal Camp-deletion-proposal
  blob content hashes. `proposalHash` is never a root; the 24-hour boundary,
  shared reference, quarantine, and deleted-tombstone restage/version CAS are
  exact;
- managed artifact/origin/blob-reference creation and explicit workspace-
  external artifact/origin creation are atomic and owned only by
  `ArtifactStorageOriginStore`; legacy upgrade requires unforgeable verifier
  evidence plus exact version CAS;
- ownership classification uses a frozen root-set snapshot and no-follow
  descriptor traversal. Missing, symlink, permission/root unavailable,
  irregular, identity/content/root drift, hardlink, pending proposal,
  cross-Camp reference, and concurrent snapshot drift remain unresolved. Path
  prefix, filename, extension, normalization, or missing-as-external never
  grants authority;
- origin redaction/tombstone/terminal disposition is one-way and post-redaction
  locked. F1C performs no Camp retirement, unlink of external/unresolved bytes,
  deletion reservation, or `camp_deletion_proposal_blob` product insert.

F1C closes only when all 19 identities 043–061 pass together with 001–042,
the original predecessor assertions including GuideChat remain green, the
source gates prove raw durable path and unsafe report writers are zero, Core
and App build, and an independent bounded implementation review reports
0 P0/P1 for the F1C delta. The first valid red remains immutable. A failure
after the red is fixed by its reproducible root; it never authorizes a fallback
success, assertion reduction, filesystem retry-until-green, widened ownership
guess, or out-of-scope file.

### 15.4 Revised machine boundary

Revision 4 changes the machine boundary only by adding the existing
`GuideChatTests.swift` pre-image and the append-only Review01c path. The exact
files are authoritative; prose never reconstructs the allowlist.

```text
allowlist_lines=98
allowlist_sha256=9c9c0198e7570c56367c83e90e606a888bc08f7e833ed9cd82517bacb4e39020
entry_manifest_lines=47
entry_manifest_sha256=024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a
GuideChatTests_preimage_sha256=6b6150e00bf826fa98ae9eafbb5735735af81ed39fa64d05cd8628022329e7c7
outside_count=589
outside_manifest_v1=792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88
```

At the plan freeze, `dirty_total=648` and
`allowlisted_present_count=59`; only these two live counts may grow as allowed
artifacts/files appear. `outside_count` and `outside_manifest_v1` must remain
exact through Review01c and F1C implementation review. Every predecessor
protected hash not explicitly changed by the already accepted Revision 3a
continues to be checked from the entry manifest/current reviewed successor
chain. Review01c is the only authorized new plan-review path; no historical
review bytes are rewritten.

### 15.5 Exact scaffold vocabulary and Store surfaces

`Records.swift` adds only GRDB records for the existing v17 columns and these
closed raw-value enums: blob state
`available|quarantined|deletedTombstone`, blob-reference/origin state
`active|tombstoned`, storage class
`managed|workspaceExternal|unresolved`, evidence kind
`typedPreparedArtifact|verifiedManagedRootCapability|
explicitWorkspaceExternal|verifiedOutsideAllManagedRoots|legacyUnknown`, and
terminal disposition
`managedDeleted|managedAlreadyAbsent|managedSharedDetached|
workspaceExternalDetached|unresolvedDetached`. The exact records are
`ArtifactBlobRecord(contentHash,byteCount,relativePath,state,version,createdAt,
verifiedAt,deletedAt)`,
`ArtifactBlobReferenceRecord(artifactId,proposalArtifactId,executionId,campId,
contentHash,state,createdAt,tombstonedAt)`, and
`ArtifactStorageOriginRecord(artifactId,campId,state,storageClass,evidenceKind,
managedRootId,objectId,contentHash,fileIdentityHash,originalRefHash,
classificationEvidenceHash,terminalDisposition,terminalAuthorityHash,version,
classifiedAt,redactedAt)`. No migration/schema change is authorized.

`PreparedArtifactV1` is immutable, has no caller-usable public/package
initializer, and exposes exactly proposal ID, proposal-artifact ID, artifact
ID, execution/card/Camp IDs, ordinal, kind, label, byte count, content hash,
blob-relative path, managed-root/object/file-identity values, proposal-artifact
version, blob version, and prepared time. The owning Stager/Blob Store alone
constructs it. The exact Store surfaces are:

```swift
package enum ArtifactPreparationCheckpointV1: Sendable, Equatable {
    case afterTemporaryCreate
    case afterTemporaryFileSync
    case afterBlobRename
    case afterBlobDirectorySync
    case beforeDatabaseMutation
    case afterBlobUpsert
    case afterProposalArtifactCAS
}

package enum ArtifactGarbageCollectionCheckpointV1: Sendable, Equatable {
    case afterQuarantineCommit
    case afterUnlink
    case beforeTombstoneCommit
}

package struct ArtifactGarbageCollectionReceiptV1: Sendable, Equatable {
    package let retainedContentHashes: [String]
    package let quarantinedContentHashes: [String]
    package let deletedContentHashes: [String]
}

package final class ArtifactBlobStore: @unchecked Sendable {
    package init(
        database: AppDatabase,
        artifactStoreRoot: URL,
        stateDirectoryLock: StateDirectoryLock,
        checkpoint:
            (@Sendable (ArtifactGarbageCollectionCheckpointV1) throws -> Void)?
            = nil
    )
    package func validatePreparedArtifacts(
        proposalId: String,
        database: Database
    ) throws -> [PreparedArtifactV1]
    package func collectGarbage(
        now: Date
    ) throws -> ArtifactGarbageCollectionReceiptV1
    package func recoverQuarantined(
        now: Date
    ) throws -> ArtifactGarbageCollectionReceiptV1
}

package final class ArtifactStager: @unchecked Sendable {
    package init(
        database: AppDatabase,
        blobStore: ArtifactBlobStore,
        checkpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)? = nil
    )
    package func prepare(
        proposalId: String,
        workspaceRoot: URL,
        expectedWorkspaceHash: String
    ) throws -> [PreparedArtifactV1]
    package func recoverPreparation(
        proposalId: String,
        workspaceRoot: URL,
        expectedWorkspaceHash: String
    ) throws -> [PreparedArtifactV1]
    package func cleanOrphanedStaging() throws
}
```

Every final receipt list is lowercase-hash sorted/unique. Checkpoints are
failure-injection observations only: Store code never catches them, and a
throw must expose the real rollback/crash window rather than continue.

### 15.6 Exact ownership evidence and Origin Store surface

The verifier's unresolved reason is the closed Stage set
`unknownMissing|symlink|permissionDenied|managedRootUnavailable|
irregularFile|identityDrift|contentDrift|incompleteRootSet|
ambiguousHardlink`. `ManagedArtifactRootDescriptorV1` contains exact root ID,
Camp ID, and root URL; `ManagedArtifactRootSnapshotV1` contains generation,
root-set hash, and a deterministically ordered root list. These proof values
have no caller-usable public/package initializer:

- `VerifiedManagedArtifactEvidenceV1`;
- `VerifiedManagedArtifactAlreadyAbsentEvidenceV1`;
- `VerifiedWorkspaceExternalEvidenceV1`;
- `UnresolvedArtifactEvidenceV1`.

The closed result is
`managed|managedAlreadyAbsent|workspaceExternal|unresolved`; legacy upgrade
accepts only `managed(VerifiedManagedArtifactEvidenceV1)` or
`verifiedOutsideAllManagedRoots(VerifiedWorkspaceExternalEvidenceV1)`.
Legacy missing is unresolved. Only exact already-managed provenance may be
managed-already-absent. Cross-Camp identity, pending roots, or excess hardlinks
are ambiguous; root generation/set drift is incomplete-root-set.

```swift
package final class ArtifactOwnershipVerifier: @unchecked Sendable {
    package init(
        database: AppDatabase,
        roots: ManagedArtifactRootSnapshotV1,
        beforeFinalSnapshotValidation:
            (@Sendable () throws -> Void)? = nil
    )
    package func verify(
        artifactId: String,
        expectedOriginVersion: Int
    ) throws -> ArtifactOwnershipVerificationV1
}

package struct WorkspaceExternalArtifactReferenceV1:
    Sendable, Equatable
{
    package let cardId: String
    package let path: String
    package let kind: String
    package let label: String
    package let classifiedAt: Date
    package static func explicit(
        cardId: String,
        path: String,
        kind: String,
        label: String,
        classifiedAt: Date
    ) throws -> Self
}

package struct ArtifactStorageOriginSnapshotV1: Sendable, Equatable {
    package let artifact: ArtifactRecord
    package let origin: ArtifactStorageOriginRecord
    package let blobReference: ArtifactBlobReferenceRecord?
}

package final class ArtifactStorageOriginStore: Sendable {
    package init(
        database: AppDatabase,
        artifactIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    )
    package func insertPreparedArtifacts(
        _ prepared: [PreparedArtifactV1],
        proposalId: String,
        database: Database
    ) throws -> [ArtifactRecord]
    package func insertWorkspaceExternalArtifact(
        _ reference: WorkspaceExternalArtifactReferenceV1,
        database: Database
    ) throws -> ArtifactRecord
    package func upgradeLegacyOrigin(
        artifactId: String,
        expectedVersion: Int,
        evidence: ArtifactOriginUpgradeEvidenceV1,
        at: Date,
        database: Database
    ) throws -> ArtifactStorageOriginSnapshotV1
}
```

The explicit external constructor is typed caller intent, not a managed or
verified-outside proof. It can never create a blob reference, managed locator,
terminal disposition, or verifier evidence.

### 15.7 Exact managed-report surface and cursor

The report owner uses only these safe types and operations:

```swift
package struct ManagedExpeditionReportOwnerScopeV1:
    Codable, Sendable, Equatable
{
    package let missionId: String
    package let squadId: String
    package let campId: String
}

package struct ManagedExpeditionReportCursorV1:
    Codable, Sendable, Equatable
{
    package let schemaVersion: Int       // exactly 1
    package let missionId: String
    package let campId: String
    package let contentHash: String
    package let byteCount: Int
    package let temporaryName: String
    package let finalName: String
}

package enum ManagedExpeditionReportCheckpointV1: Sendable, Equatable {
    case afterTemporaryFileSync
    case afterCursorFileSync
    case afterFinalRename
    case afterReportDirectorySync
}

package final class ManagedExpeditionReportStore: @unchecked Sendable {
    package init(
        database: AppDatabase,
        reportStoreRoot: URL,
        checkpoint:
            (@Sendable (ManagedExpeditionReportCheckpointV1) throws -> Void)?
            = nil
    )
    package func ensureReport(missionId: String) throws -> URL
    package func regenerateReport(missionId: String) throws -> URL
    package func recoverPendingWrites() throws
    package func reportURL(missionId: String) throws -> URL
}
```

The cursor is canonical sorted-key JSON and contains no report text, Camp
name, goal, artifact path, user/device identity, credential, or diagnostic
body. The exact write sequence is derive scope/render → temp write+fsync →
cursor write+fsync → atomic final rename → directory fsync → cursor removal →
directory fsync. Recovery accepts only final/temp/cursor bytes whose mission,
Camp, byte count, and hash equal the current database render; mismatch fails
visibly and preserves evidence.

### 15.8 Exact F1C implementation order

After the immutable exact-19 red, implementation order is fixed:

1. v17 record decoding and sealed value/evidence validation;
2. no-follow file capability, Blob Store, and Stager for 043–052;
3. Origin Store plus engine terminal artifact-graph integration for 053–056;
4. verifier for 057–058;
5. Board raw-authority removal and typed GuideChat/Harvest fixture migration
   for 059;
6. sole managed-report owner and cursor recovery for 060–061.

After each group, run its F1C identities plus 001–042. Final F1C focused green
is exactly 001–061. The Review01c-approved scaffold bytes precede test bytes;
the valid red precedes every functional method body.

Revision 4 additionally forbids:

- treating the declaration-only scaffold as product progress or leaving its
  error/type referenced after the exact-19 red;
- adding F1C tests before Review01c, accepting a compile red as capability red,
  or manufacturing test discovery with source-text/dynamic-symbol checks;
- retaining raw artifact path authority for GuideChat, Harvest, Board,
  Orchestrator, Engine, or a compatibility shim;
- editing any GuideChat test outside the one named fixture, weakening its
  deliverable/status assertions, or inserting artifact/origin/ref rows by hand;
- leaving `MissionWorkflowController` as a third report writer, adding another
  report root owner, or using `try?`/cleanup fallback to hide a durability
  failure;
- implementing F1D adapters, F1E coordination, F1F integration, F1-F2 Camp
  deletion authority, P2 UI, or any external action under this correction.

## 16. Revision 4a — F1C compile and ownership-integration closure

Revision 4a is the sole bounded successor to the first Review01c verdict. A
responsibility-isolated compile audit found three plan-only gaps before any
F1C scaffold, test, or functional product byte changed: a non-synthesizable
snapshot conformance, two referenced-but-undeclared evidence enums, and an
unspecified Engine Store artifact dependency. This section closes only those
gaps. It does not change the 98-line allowlist, 47-line entry manifest,
589-node outside boundary, identities 043–061, Stage behavior, or F1D/F2
boundary. Sections 16.1–16.3 override the less precise corresponding wording
in §§15.5–15.8.

No F1C scaffold/test/product write is authorized until the original Review01c
file preserves its first verdict as an exact prefix and appends an independent
Revision 4a successor verdict `APPROVED — 0 P0 / 0 P1` for the new plan SHA.

### 16.1 Compile-exact snapshot and evidence types

`ArtifactStorageOriginSnapshotV1` conforms to `Sendable` only; it does not
claim synthesized `Equatable`, because predecessor `ArtifactRecord` is not
Equatable and F1C does not alter that public record's conformance. Tests compare
the snapshot's typed fields explicitly.

The root descriptors have no public/memberwise authority. Their only
package-visible construction surfaces are:

```swift
package struct ManagedArtifactRootDescriptorV1: Sendable, Equatable {
    package let rootId: String
    package let campId: String
    package let rootURL: URL

    package static func registered(
        rootId: String,
        campId: String,
        rootURL: URL
    ) throws -> Self
}

package struct ManagedArtifactRootSnapshotV1: Sendable, Equatable {
    package let generation: Int
    package let rootSetHash: String
    package let roots: [ManagedArtifactRootDescriptorV1]

    package static func frozen(
        generation: Int,
        rootSetHash: String,
        roots: [ManagedArtifactRootDescriptorV1]
    ) throws -> Self
}
```

`registered` requires nonempty trimmed canonical IDs and an absolute file URL.
`frozen` requires generation >=1, an exact lowercase SHA-256 root-set hash,
unique `(rootId,campId)` pairs, and caller order already equal to bytewise
`(rootId,campId)` order. It recomputes the canonical hash of exactly
`{generation,roots:[{campId,rootId,standardizedAbsolutePath}]}` and rejects a
mismatch; `standardizedAbsolutePath` is identity material only and is never an
ownership/classification decision. The verifier still opens and walks every
root no-follow before issuing proof.

The four sealed evidence values expose these exact immutable safe fields and
have no public/package initializer:

```swift
package struct VerifiedManagedArtifactEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let managedRootId: String
    package let objectId: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date
}

package struct VerifiedManagedArtifactAlreadyAbsentEvidenceV1:
    Sendable, Equatable
{
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let managedRootId: String
    package let objectId: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date
}

package struct VerifiedWorkspaceExternalEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let originalRefHash: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date
}

package struct UnresolvedArtifactEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let reason: UnresolvedArtifactReasonV1
    package let rootSetHash: String
    package let registryGeneration: Int
    package let observedAt: Date
}
```

Exact lowercase hashes, canonical IDs, positive versions/generation, finite
dates, and row/evidence Camp equality are revalidated by the consuming Origin
Store; sealed construction alone never bypasses transaction-time validation.

The referenced enums are exactly:

```swift
package enum ArtifactOwnershipVerificationV1: Sendable, Equatable {
    case managed(VerifiedManagedArtifactEvidenceV1)
    case managedAlreadyAbsent(
        VerifiedManagedArtifactAlreadyAbsentEvidenceV1
    )
    case workspaceExternal(VerifiedWorkspaceExternalEvidenceV1)
    case unresolved(UnresolvedArtifactEvidenceV1)
}

package enum ArtifactOriginUpgradeEvidenceV1: Sendable, Equatable {
    case managed(VerifiedManagedArtifactEvidenceV1)
    case verifiedOutsideAllManagedRoots(
        VerifiedWorkspaceExternalEvidenceV1
    )
}
```

Explicit workspace-external creation remains owned by
`WorkspaceExternalArtifactReferenceV1.explicit`; it does not fabricate
verifier evidence. For legacy verification, cross-Camp identity, any pending
proposal root, excess hardlinks, or conflicting live managed/reference
identity maps to `unresolved(.ambiguousHardlink)`. Root-set/generation drift or
an unavailable registered root maps to `incompleteRootSet` or
`managedRootUnavailable` respectively; it never signs outside-all-roots.

### 16.2 Exact Engine Store artifact dependency and transaction

F1C extends `EngineExecutionStore`'s package initializer by these optional
dependencies with nil defaults so every accepted zero-artifact F1B call site
retains source and behavior compatibility:

```swift
artifactBlobStore: ArtifactBlobStore? = nil,
artifactStorageOriginStore: ArtifactStorageOriginStore? = nil
```

Nil is not fallback authority. A pending proposal with one or more declared
artifacts requires both dependencies and otherwise fails visibly with the
existing typed preparation/protocol-error path and zero artifact/terminal
projection writes. A zero-artifact proposal does not access either dependency.

For a first nonempty `commitEngineTerminal`, inside the existing outer
`database.pool.write` and before any terminal projection mutation, the Store:

1. calls `validatePreparedArtifacts(proposalId:database:)` on the injected Blob
   Store using that exact transaction handle;
2. requires the returned values to match every persisted proposal-artifact by
   proposal ID, artifact/proposal-artifact ID, ordinal, execution/card/Camp,
   kind, label, byte count, content hash, state=prepared, and exact versions,
   with contiguous proposal ordinal and no extra/missing row;
3. calls `insertPreparedArtifacts(_:proposalId:database:)` on the injected
   Origin Store using the same handle. That call inserts artifact, managed
   origin, and active blob reference once, in proposal ordinal order;
4. writes the existing handoff/Run/Card/Mission/proposal/execution/legacy event
   and strict receipt/event/outbox graph in that same transaction; terminal
   receipt `artifactIds` is exactly the returned artifact IDs in proposal
   ordinal order.

Any validation, insert, projection, strict graph, or receipt failure rolls the
entire transaction back. The Origin Store rejects preexisting partial rows;
it never upserts, ignores, or repairs them during first commit.

Exact committed replay performs no staging or filesystem write and does not
re-run first-commit insertion. It validates the strict command graph plus the
persisted proposal-artifact → artifact → managed origin → active blob-reference
join, ordered receipt artifact IDs, hashes, versions, Camp/execution/card, and
proposal linkage. Missing/extra/drift/partial graph is
`DomainCommandGraphIntegrityError`, never a new projection or healing write.

### 16.3 F1C/F1D orchestration boundary

F1C implements only the Store-side prepared-artifact validation and atomic
terminal commit above. Tests 043–058 may create a real pending proposal,
invoke the reviewed Stager directly, and then call the Store commit; this is a
package test seam, not adapter authority.

The production sequencing owner that receives an Engine terminal proposal,
runs `ArtifactStager.prepare/recoverPreparation`, and then calls
`commitEngineTerminal` remains the F1D `EngineTerminalSink` /
`prepareAndCommitProposal` orchestration. Revision 4a does not implement or
wire ModelLoop/CLI/Board adapters, does not change their descriptors/session
surface, and does not allow an adapter to access SQLite. F1B recovery may keep
returning the already frozen `.prepareAndCommitProposal` directive; F1D is the
first band that consumes it in production. F1C only makes the underlying typed
Store operations real and testable.

## 17. Revision 5 — F1D compile-red and adapter authority closure

Revision 5 is the sole plan-only successor for F1D. F1A–F1C and their
implementation reviews are closed inputs. This revision does not reopen their
behavior, add schema, or enter F1E/F1F/F2. It closes one verified ordering gap:
`ModelLoopEngineAdapter.swift`, `CliEngineAdapter.swift`, and
`ExecutionEngineConformanceTests.swift` are absent, and identities 062–080 are
also absent. Adding the tests first would therefore be a compile/discovery red,
not the required 19-test runtime capability red.

No F1D scaffold, test, product, build, or app byte may change until a
responsibility-isolated Codex reviewer writes
`reviews/01d-p1-f1-plan-review.md` and approves this exact Revision 5 plan and
99-line allowlist with `APPROVED — 0 P0 / 0 P1`. Review01d is the only new
artifact path; no historical review is rewritten.

### 17.1 Frozen entry, scope, and compile-only exception

The effective allowlist is 99 unique byte-sorted LF-delimited paths, SHA-256
`cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa`.
The 47-line entry manifest and focused manifest remain byte-identical at
`024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a`
and `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968`.
The NUL-safe outside boundary remains exactly 589 nodes / SHA-256
`792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88`;
at this freeze `dirty_total=661` and `allowlisted_present_count=72`.
The three paths above remain absent at freeze. Relevant current pre-images are:

| input | SHA-256 |
|---|---|
| `ExecutionEngine.swift` | `bf394cad23ab06199a8ee63e728a953b06e0d9a08a5eab547f31922423f9f57d` |
| `EngineExecutionReceipt.swift` | `ab77296c711fa8b7321660a86eb6ecefd7c947dfe8494396bdf547a04fc27673` |
| `EngineExecutionStore.swift` | `b771100b9a49a505e19301436912bbef89c6cc0ace95a70f2ce2703f1bcd7ea7` |
| `EngineSessionStore.swift` | `6aacd5d69262abc7a6a3cedb21137ce00c02281cfd8d8de448f854b78f272c69` |
| `Orchestrator.swift` | `ef22c392abf31c9664b49dfa139219c71ee473c8fbf2be803b59504b2f923fa0` |
| `ContextPacket.swift` | `8b7a63255dba49775ce57975938d7986d951dc1552a0691f88862c411ad3d21a` |
| `CardRunner.swift` | `0402865cc9707b0210594d60da4ebc48816eea93be7808432823581cea2652df` |
| `CliProcessBackend.swift` | `5a3f6e59c17a8ca5e8da24098c185d6926fd98db7a85eb0cb3b7c67295f70fa4` |
| `BoardTools.swift` | `343daf95dba66cd216b17d8026d6e4ec6d84260dcefbdc689934f9b469f104ff` |
| `BoardToolServer.swift` | `672bb1dacc50cd6c04a08350cd61b27c242647051746608bfdb60afce21555a1` |
| `BoardServerBridgeMain.swift` | `ea7eb086e3f09755df01af80bb883d74e6257a4b916abfb44ed4b5d325f9067e` |

After Review01d, the two absent adapters plus the already-present domain,
orchestration, Board, context, and CLI owners may receive only declarations
needed to compile 062–080. The unavailable vocabulary is exactly:

```swift
package enum EngineAdapterCapabilityV1: String, Sendable, Equatable {
    case descriptor, execute, cancel, select, dispatch, recover
    case terminalIntent, progressIntent, artifactManifest
    case workspaceResolve, contextResolve, priorSessionResolve
    case codexParse, claudeParse, commandBuild, helpProbe
    case processLaunch, processCancel, secretSanitize
}

package struct EngineAdapterCapabilityUnavailableErrorV1:
    Error, Sendable, Equatable
{
    package let capability: EngineAdapterCapabilityV1
    package init(_ capability: EngineAdapterCapabilityV1)
}
```

Every scaffold operation's first executable statement throws the matching
error before DB/FS/socket/process/Task/lock/temp-config access, ID/hash/clock
generation, or in-memory success mutation. A nonthrowing stream factory may
only return a cold `AsyncThrowingStream` whose first pull throws this error; it
may not start a Task. Constructors validate caller values only and cannot emit
an event, proposal, manifest, session, or success. Then add exactly 062–080,
run the anchored exact-19 filter, and preserve `red-f1d-adapters.log`. A valid
red has command status nonzero, tee status zero, 19 discovered/started/failed,
and every failure is this typed unavailable capability or its direct assertion.
Compile errors, zero discovery, fixture faults, crashes, or predecessor failures
invalidate the red. Functional work begins only after this immutable red; final
product and tests contain zero references to both scaffold symbols.

### 17.2 Registry and truthful descriptors

`ExecutionEngineAdapter` keeps the accepted `descriptor(profile:)`,
`execute(request:) -> AsyncThrowingStream`, and `cancel(executionId:)` surface.
`EngineAdapterRegistryV1` is a DB-free ordered registry/factory. Its sole
selection API is
`resolve(profile:requiredCapabilities:) -> EngineAdapterSelectionV1`; it
requires profile-kind equality and `.supported` for every sorted unique
requirement. `.unsupported` and `.conditional` do not satisfy a required
capability in F1D; built-ins publish no conditional support. No caller may
select by `profile.kind.isCLI`, adapter ID string, or fallback ordering.

`EngineExecutionStore.descriptorResolver` changes everywhere—begin, exact
replay validation, session resolution, and recovery—to
`(RuntimeProfileRecord, [EngineCapabilityV1]) throws ->
ExecutionEngineDescriptor`. The Orchestrator registry supplies that same
closure. Persisted required capabilities are re-resolved during recovery;
adapter ID/version/profile kind/replay class drift becomes the existing
protocol-error terminal, never a broader substitute.

The built-in descriptor matrix is exact (`S` supported, `U` unsupported):

| adapter ID / version | profile kinds | replay class | stream | board | tools | cancel | resume | usage | read | write | network |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `agentloop.model-loop` / `1` | anthropicAPI, openAIAPI, chatGPTOAuth | nonReplayable | S | S | S | S | U | S | S | S | S |
| `agentloop.cli.codex` / `1` | cliCodex | nonReplayable | S | S | S | S | S | S | S | S | S |
| `agentloop.cli.claude` / `1` | cliClaude | nonReplayable | S | S | S | S | S | S | S | S | S |

CLI `S` is conditional on the exact local/fake help snapshot required by
§17.6; a missing flag changes only its affected capability to `U`, and a
required `U` yields typed unsupported before dispatch. All replay classes are
conservatively nonReplayable: ModelLoop may invoke tools, Codex cannot inject a
first-call external idempotency/session ID, and F1D does not claim Claude first-
call replay safety merely because it can preselect `--session-id`.

### 17.3 One coordinator, sequencer, and terminal owner

`EngineExecutionCoordinatorV1` is the only production owner of begin, dispatch
CAS, adapter-event consumption, recovery directives, proposal record, Artifact
prepare/recovery, and terminal commit. Its package surface is exactly
`execute(requestFields:idempotencyKey:transport:) async throws ->
EngineTerminalCommitReceiptV1`, `cancel(executionId:reason:) async throws`, and
`recover(now:) async throws -> EngineRecoverySummaryV1`. Orchestrator builds
fields/transport, calls this coordinator, and never constructs a backend by
profile kind. Adapters, CardRunner, CliProcessBackend, BoardTools, Board server,
and bridge hold no `AppDatabase` and never call start/finish Run, complete/block
Card, insert user_request, or mutate Mission.

`EngineEventRouterV1` is one actor per execution and the sole allocator of
contiguous sequence and terminal state. Accepted/session/progress/tool/usage
and Board intents all enter it; it emits one ordered stream. After its first
terminal it rejects every further event/intent. Board server has no independent
`terminalOutcome` truth and `onTerminal` only requests transport shutdown after
the router accepted the intent. Adapter EOF/error/cancel checks router state and
may create a terminal only when none exists; it never emits a second terminal.

The existing sinks are corrected to DB-free intents:

```swift
package protocol EngineTerminalSink: Sendable {
    func submit(_ intent: EngineTerminalIntentV1) async throws
}
package protocol EngineProgressSink: Sendable {
    func submit(_ payload: EngineExecutionEventPayloadV1) async throws
}
```

`EngineTerminalIntentV1` is closed to completed full `HandoffPayload`, ordinary
blocked, needs-human-input kind/prompt/options, failed, and canceled. It carries
no execution/run/card ID, sequence, hash, artifact ID, DB record, or path-derived
authority. Board complete/block/ask_user submit only these intents; progress
submits only progress. The router binds request IDs and sequence.

For a terminal event the coordinator records the full proposal once. For a
completed intent, `ArtifactStager.buildManifest(workspaceRoot:handoff:)` is the
sole no-follow normalized-path/regular-file owner that computes each contiguous
ordinal, byteCount, and SHA-256 before proposal identity; Board never accepts or
claims these fields. After record, the coordinator runs existing
prepare/recoverPreparation and commits. A disappearance/drift after manifest
creation invalidates that one pending proposal through the existing protocol-
error command. Zero-artifact, ask-user, blocked, failed, and canceled never
touch the filesystem. Usage is accumulated only with `EngineUsageV1.adding`.

Dispatch order is begin -> capability-exact registry recheck -> CAS. Only
`.startNow(exactRequest)` creates/calls an adapter; `.alreadyStarted` never does.
Nonterminal events call `acceptEngineEvent`; terminal calls record -> optional
manifest prepare -> `commitEngineAskUser` or `commitEngineTerminal`. EOF,
parser failure, or missing Board terminator becomes fixed
`blocked+engineProtocolError`, never completed. Recovery consumes every existing
directive: prepare/commit exact pending proposal, startPrepared, exact resume,
replay only if a future truthful descriptor allows it, and cancelAndReconcile;
deferCampDeletion remains untouched for F2.

### 17.4 Durable context, workspace, and prior session

Engine-path prompt material must be reconstructible from `contextJson` refs;
unreferenced tuples are not production authority. Each answered non-approval
`user_request` contributes an `inputRefs` entry with `type="input"`, its real
canonical UUID, version `1`, and the SHA-256 of canonical
`{schemaVersion:1,userRequestId,cardId,kind,prompt,optionsJson,answerJson,
answeredAt}`. The row must be answered, nonredacted, same Card, and its option/
answer JSON must decode and re-encode canonically; otherwise assembly fails.
Changing an answer therefore changes context bytes/hash. It never enters
`EngineSessionScopeV1`. Any other prompt-changing material must likewise have
an existing typed ref/hash; it cannot be fabricated from display text.

`EngineContextTransportResolverV1` builds the initial `ContextPacket` from real
rows and the canonical envelope, and on recovery reloads every ref, recomputes
its hash, and renders the same transport. Missing, redacted, cross-Camp, or
drifted material fails closed. The legacy tuple initializer may remain only for
predecessor tests; Orchestrator, both adapters, and recovery cannot call it.

`EngineWorkspaceRefV1.reference` is never interpreted as a path. Orchestrator
uses the existing unchanged `WorkspaceScopedAccess` to obtain the squad URL and
builds `squad-workspace.v1:<squadId>` plus the canonical hash of
`{schemaVersion:1,campId,squadId,workspacePath,bookmarkHash}`. The injected
`EngineWorkspaceResolverV1` re-derives card->mission->squad->Camp, reacquires
scoped access, recomputes the hash, and requires an absolute directory before
adapter or Stager access. Recovery repeats the same checks. No Support file is
edited and no raw reference/path fallback exists.

Production callers cannot choose an arbitrary session UUID. For a continuation
the coordinator supplies an exact predecessor execution ID; Store loads that
same-Card terminal predecessor's real `sessionId` FK and reuses it only after
the existing Camp/profile/adapter/version/scope/workspace checks. With no exact
predecessor, unsupported resume, closed/invalid session, or scope drift, begin
creates a new execution/run with no session selection. The old direct
`sessionSelection` construction remains only as an F1B test seam and must have
zero product callers.

### 17.5 Adapter and Board implementation

`ModelLoopEngineAdapter` owns a DB-free AgentLoop transport. CardRunner becomes
a tool/provider assembler that accepts request, resolved transport/workspace,
router sinks, and never allocates Run or finalizes Card. Board terminal intent
ends AgentLoop once; adapter reports the router's terminal and does not infer a
second outcome from `.finished`.

`CliEngineAdapter` owns a DB-free `CliProcessBackend` transport. BoardTools and
BoardToolServer receive only request-bound intent/progress sinks. Socket frames
may return tool acknowledgement, but not establish a second terminal fact.
Bridge/card/token mismatches and unknown tools fail visibly without a proposal.
`CliProcessBackend` owns process/pipe mechanics only: launch one process group,
on cancel send TERM, wait a bounded existing timeout, KILL if needed, drain both
pipes, and prove child disappearance before emitting canceled evidence. Cancel
requests never guess success and never mutate DB. `ShellProcessRegistry` is
unchanged.

### 17.6 Strict CLI commands, parsers, help, and secrecy

Codex first command is `codex exec [--cd W] --sandbox S -m M <approved -c
key=value config pairs> --json PROMPT`; resume is `codex exec resume <exact-id>
[the same workspace/sandbox/model/config] --json PROMPT`. Only `-c` immediately
followed by the frozen `model_reasoning_effort=` or `mcp_servers.ranchboard.*=`
keys is allowed; it is config, not continuation. `--last` and `--continue` are
always forbidden.

Claude first command contains `-p PROMPT --output-format stream-json --verbose
--mcp-config FILE --permission-mode MODE --session-id <ranch UUID>` plus exact
model/workspace flags; resume replaces session creation with
`--resume <exact-id>`. `--continue`, `--last`, and Claude continuation `-c` are
forbidden. Every first/resume command reinjects ranchboard MCP, workspace,
permission/safety, model, and Contract prompt; temp config is mode 0600 and is
removed after pipes/process close, with cleanup failure surfaced.

Codex parser recognizes the session only from exact
`{"type":"thread.started","thread_id":...}`. Claude recognizes exact
stream-json `system/init` and final `result` session IDs, both equal to the
pre-generated UUID. IDs are bound before `sessionBound` is emitted. Known text,
usage, and result events have exact key/type checks and checked Int conversion;
unknown/malformed JSON, ID drift, parser error, EOF, or no Board terminal fails
closed. Fake `--help` snapshots prove all required flags; a missing flag
produces the §17.2 capability downgrade without login or fallback guessing.

`CliEngineSecretSanitizerV1` is the sole error detail builder. It removes Board
token, credential-account/env sentinels, MCP config content/path, prompt/body,
and raw stderr/provider `Error`; persisted details are fixed reason text plus a
safe trace ID. No `String(describing:)`, raw stderr tail, token, prompt, config,
or credential reaches proposal, domain event, failure record, or logs.

### 17.7 Exact tests, implementation order, and close gate

After scaffold red, implement in this fixed order, always running the current
group plus 001–061:

1. 062–070: registry/descriptor matrix, router four terminals, EOF/parser,
   cancel, checked usage, bind/resume, Board once, and secret sentinels across
   ModelLoop/Codex/Claude fixtures;
2. 071 and 079: CardRunner/ModelLoop/CliProcessBackend lose every Run/Card/
   Mission mutation and terminate only through the coordinator;
3. 072–075: strict fake CLI first/resume flags, session parsing, config carveout,
   help downgrade, process cleanup, and zero real login;
4. 076: Orchestrator/Store/recovery use one required-capability registry and no
   profile-kind branch;
5. 077–078: Board and bridge submit one typed intent, no SQLite/terminal shadow;
6. 080: real answered-request ID/hash changes contextHash while exact derived
   sessionScopeHash and predecessor-session eligibility remain unchanged.

Final F1D focused evidence is exactly 001–080 with declarations/discovery/set
equality and all green. Source gates additionally require: scaffold symbols
zero; three adapter IDs and descriptor matrix exact; resolver arity includes
required capabilities at every begin/recovery call; `profile.kind.isCLI`
selection zero in Orchestrator; direct startRun/finishRun/completeCard/blockCard
and `AppDatabase` storage zero in adapters/runner/Board; one router sequence and
no Board terminal shadow; ArtifactStager alone computes manifest bytes/hash;
product tuple session selection and raw workspace-reference-as-path zero;
banned flags/unsafe `-c` zero; raw secret/error persistence zero.

F1D closes only after the valid exact-19 red, exact 001–080 green, Core and App
build, unchanged predecessor assertions, immutable outside boundary, and an
independent bounded implementation successor in Review02 reports 0 P0/P1.
Then record F1D closed and open F1E only. Revision 5 forbids schema/migration/
dependency changes; EventKind, Canonical JSON/coding, durable-work owners,
`Package.resolved`, `WorkspaceScopedAccess`, and `ShellProcessRegistry` edits;
new source/test paths; real CLI login/network; fallback adapter/session/path;
F1E/F1F/F2/P2 work; and any commit/push/release/external action.

## 18. Revision 5a — F1D declaration and byte authority closure

Revision 5a is a bounded plan-only correction to Review01d
(`61cb7cd6…`, 0 P0 / 4 P1). It changes only this `plan.md`; the effective
allowlist remains 99 lines / SHA-256
`cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa`.
Revision 5 remains controlling except where this section makes one of the four
reviewed contracts more exact. Review01d is immutable. No scaffold, test,
product, build, App, schema, dependency, or F1E/F2 work opens until a fresh
responsibility-isolated review approves the exact Revision 5 + 5a bytes with
0 P0 / 0 P1.

### 18.1 Complete compile-only declaration authority

All declarations below have `package` access unless an existing declaration
already has `public` access. Their listed owner is final; moving a declaration
or adding another F1D source file is forbidden. Value DTO initializers only
validate their arguments and assign the listed fields. They do no I/O, do not
read a clock, and do not create an ID. Protocols have exactly the listed
requirements and no default implementation.

| owner | exact declaration, stored fields, initializer and operations |
|---|---|
| `Domain/ExecutionEngine.swift` | temporary `EngineAdapterCapabilityV1` and `EngineAdapterCapabilityUnavailableErrorV1` from §17.1; final `EngineAdapterSelectionErrorV1: Error, Sendable, Equatable` with cases `duplicateProfileKind(RuntimeProfileKind)`, `missingFactory(RuntimeProfileKind)`, `missingHelpSnapshot(RuntimeProfileKind)`, `unsupportedCapability(EngineCapabilityV1)`, `descriptorMismatch`; `EngineAdapterFactoryV1: Sendable` stores `adapterId: String`, `adapterVersion: String`, `profileKinds: Set<RuntimeProfileKind>`, `descriptor: @Sendable (RuntimeProfileRecord, CliHelpSnapshotV1?) throws -> ExecutionEngineDescriptor`, and `makeAdapter: @Sendable (RuntimeProfileRecord, EngineAdapterRuntimeV1) throws -> any ExecutionEngineAdapter`; its memberwise initializer takes those five values; `EngineAdapterSelectionV1: Sendable` stores `descriptor` and captured `makeAdapter: @Sendable (EngineAdapterRuntimeV1) throws -> any ExecutionEngineAdapter`; `EngineAdapterRegistryV1: Sendable` stores input-order `factories: [EngineAdapterFactoryV1]` and `helpSnapshots: [RuntimeProfileKind: CliHelpSnapshotV1]`, initializes with exactly those two arguments, and exposes `resolve(profile:requiredCapabilities:) throws -> EngineAdapterSelectionV1`. |
| `Domain/ExecutionEngine.swift` | `EngineExecutionTransportV1: Sendable` stores `contextRequest: EngineContextResolveRequestV1`, `workspaceRequest: EngineWorkspaceResolveRequestV1`, `modelLoopDriver: (any ModelLoopExecutionDrivingV1)?`, and `cliProcessDriver: (any CliProcessDrivingV1)?`; exact memberwise initializer. `EngineAdapterRuntimeV1: Sendable` stores resolved `context: EngineResolvedContextTransportV1`, `workspace: EngineResolvedWorkspaceV1`, `terminalSink: any EngineTerminalSink`, `progressSink: any EngineProgressSink`, plus the same two optional drivers; exact memberwise initializer. Exactly one driver is nonnil and must match the selected adapter, otherwise selection throws `.descriptorMismatch` before dispatch. |
| `Domain/ExecutionEngine.swift` | `EngineRouterTerminalStateV1: Sendable, Equatable` is `.open` or `.accepted(sequence: Int, terminalIdempotencyKey: String)`; `EngineDuplicateTerminalErrorV1: Error, Sendable, Equatable` stores `executionId: String`; actor `EngineEventRouterV1` stores immutable `executionId`, `runId`, `cardId`, mutable `nextSequence`, `terminalState`, and cumulative `usage`. Its initializer takes those four identity/sequence values. Exact methods are `route(_ payload: EngineExecutionEventPayloadV1) throws -> EngineExecutionEvent`, `routeTerminal(_ intent: EngineTerminalIntentV1, artifacts: [EngineTerminalArtifactDeclarationV1]) throws -> EngineExecutionEvent`, `routeProtocolFailure(reasonCode: String, detail: String) throws -> EngineExecutionEvent`, and `state() throws -> EngineRouterTerminalStateV1`. |
| `Domain/ExecutionEngine.swift` | `EngineTerminalSink.submit(_ intent: EngineTerminalIntentV1) async throws -> Void`; `EngineProgressSink.submit(_ payload: EngineExecutionEventPayloadV1) async throws -> Void`. No overload accepting IDs, sequence, proposal, record, hash, or path remains. |
| `Domain/EngineExecutionReceipt.swift` | `EngineTerminalIntentV1: Sendable, Equatable` is exactly `.completed(handoff: HandoffPayload)`, `.blocked(reasonCode: String, detail: String)`, `.needsHumanInput(kind: UserRequestRecord.Kind, prompt: String, options: [String])`, `.failed(code: String, detail: String)`, or `.canceled(reasonCode: String, detail: String)`. It has no stored authority beyond associated values and no custom initializer. |
| `Loop/ContextPacket.swift` | byte DTOs and `EngineContextResolveRequestV1`, `EngineResolvedContextTransportV1`, and `EngineContextTransportResolverV1` have exactly the fields/signatures in §18.3. The resolver stores only `database: AppDatabase` and `dependencyLoader: ContextDependencyLoader`; initializer takes both; operations are `assemble(_:) throws -> EngineResolvedContextTransportV1` and `reload(_:) throws -> EngineResolvedContextTransportV1`. |
| `Kernel/Orchestrator.swift` | `EngineWorkspaceResolveRequestV1`, `EngineWorkspaceIdentityV1`, `EngineResolvedWorkspaceV1`, and `EngineWorkspaceResolverV1` have §18.3 signatures. Resolver stores only `database: AppDatabase`, initializes with it, and exposes `resolve(_:) throws -> EngineResolvedWorkspaceV1`. `EngineExecutionCoordinatorV1` stores only `store`, `registry`, `artifactStager`, `contextResolver`, `workspaceResolver`, and `clock: @Sendable () -> Date`; exact initializer takes those six. Its operations are `execute(requestFields:idempotencyKey:transport:) async throws -> EngineTerminalCommitReceiptV1`, `cancel(executionId:reason:) async throws`, and `recover(now:) async throws -> EngineRecoverySummaryV1`. |
| `Loop/ArtifactStager.swift` | static `buildManifest(workspaceRoot: URL, handoff: HandoffPayload) throws -> [EngineTerminalArtifactDeclarationV1]`; final error `ArtifactManifestBuildErrorV1: Error, Sendable, Equatable` has only `tooManyArtifacts`, `duplicatePath(ordinal: Int)`, `invalidPath(ordinal: Int)`, `missing(ordinal: Int)`, `symbolicLink(ordinal: Int)`, `notRegularFile(ordinal: Int)`, `changedDuringRead(ordinal: Int)`, and `readFailed(ordinal: Int)`. Existing instance fields/init/prepare/recovery methods do not change. |
| `Loop/ModelLoopEngineAdapter.swift` | protocol `ModelLoopExecutionDrivingV1: Sendable` requires `execute(request:context:workspaceURL:terminalSink:progressSink:) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>` and `cancel(executionId:) async throws`; struct `ModelLoopEngineAdapter: ExecutionEngineAdapter` stores `profile`, `driver`, resolved `context`, resolved `workspace`, `terminalSink`, and `progressSink`; exact memberwise initializer and the three adapter methods from `ExecutionEngineAdapter`. |
| `Loop/CliEngineAdapter.swift` | `CliEngineAdapter: ExecutionEngineAdapter` stores `profile`, `processDriver`, `commandBuilder`, `codexParser`, `claudeParser`, `sanitizer`, resolved `context`, resolved `workspace`, `terminalSink`, and `progressSink`; exact memberwise initializer and the three adapter methods. `CliHelpSnapshotV1`, probe, builder, parser DTOs, and sanitizer have §18.4 signatures. |
| `Loop/CliProcessBackend.swift` | `CliProcessDrivingV1`, `CliProcessLaunchRequestV1`, `CliProcessFrameV1`, and `CliProcessExitEvidenceV1` have §18.4 signatures. Refactored `CliProcessBackend` stores only process/mechanics dependencies and conforms to `CliProcessDrivingV1`; it has no `AppDatabase`, artifact root, runtime profile, Board, Card, Run, or Mission field. |
| `Tools/BoardTools.swift`, `Loop/BoardToolServer.swift`, `Loop/BoardServerBridgeMain.swift` | existing initializers replace DB/proposal callbacks with exactly `terminalSink: any EngineTerminalSink` and `progressSink: any EngineProgressSink`; no new terminal DTO or callback is declared in these files. |

For the compile-only phase, every throwing operation above has as its first and
only statement `throw EngineAdapterCapabilityUnavailableErrorV1(C)` using the
capability in the next table. Adapter `execute` and driver stream operations
instead return `AsyncThrowingStream { $0.finish(throwing:
EngineAdapterCapabilityUnavailableErrorV1(C)) }`; that closure starts no Task,
and the first iterator `next()` observes the error. Initializers only assign
caller-supplied fields. Enum/DTO validation may reject malformed caller bytes,
but may not manufacture a valid result. Protocol requirements have no body;
test fakes are caller-supplied and contain no product behavior.

| identity | first call in the test | exact unavailable case |
|---:|---|---|
| 062 | `registry.resolve(profile:requiredCapabilities:)` | `.select` |
| 063 | `router.routeTerminal(.completed(...), artifacts: [])` | `.terminalIntent` |
| 064 | `codexParser.parse(line:)` before its Claude matrix | `.codexParse` |
| 065 | `processDriver.cancel(executionId:)` | `.processCancel` |
| 066 | `router.route(.usage(...))` | `.progressIntent` |
| 067 | first pull from `cliAdapter.execute(request:)` | `.execute` |
| 068 | `registry.resolve` requesting `.sessionResume` | `.select` |
| 069 | first `terminalSink.submit(.blocked(...))` | `.terminalIntent` |
| 070 | `sanitizer.failure(reason:executionId:)` | `.secretSanitize` |
| 071 | first pull from `modelLoopAdapter.execute(request:)` | `.execute` |
| 072 | `commandBuilder.buildCodex(_:)` | `.commandBuild` |
| 073 | `commandBuilder.buildClaude(_:)` | `.commandBuild` |
| 074 | `commandBuilder.buildCodex(_:)` | `.commandBuild` |
| 075 | `helpProbe.snapshot(for:command:)` | `.helpProbe` |
| 076 | `registry.resolve(profile:requiredCapabilities:)` | `.select` |
| 077 | Board `complete_card` handler calling `terminalSink.submit` | `.terminalIntent` |
| 078 | server forwarding its first decoded terminal intent to the sink | `.terminalIntent` |
| 079 | first pull from `processDriver.launch(_:)` | `.processLaunch` |
| 080 | `contextResolver.assemble(_:)` | `.contextResolve` |

Thus the anchored red is exactly 19 discovered / 19 failed and every test
observes its listed case before any later matrix branch. Immediately after the
immutable red, delete both temporary scaffold types and replace every
unavailable body in this exact list: registry resolve; four router methods;
coordinator execute/cancel/recover; context assemble/reload; workspace resolve;
manifest builder; all six adapter methods; ModelLoop driver fake seam; CLI
command pair, two parsers, help probe, process launch/cancel, and sanitizer.
Final source gates require zero `EngineAdapterCapabilityV1`, zero
`EngineAdapterCapabilityUnavailableErrorV1`, zero
`CapabilityUnavailable`, and zero `finish(throwing:` bodies whose error type
contains `Unavailable` across Core and tests.

### 18.2 Final registry, transport, router, and coordinator contracts

`EngineAdapterRegistryV1.init` rejects an empty factory set, empty/duplicate
adapter ID+version, an empty profile-kind set, or any profile kind appearing in
two factories. Input order is retained only for deterministic diagnostics;
selection is exact by the one factory containing `profile.kind`, never first-
match fallback. A CLI kind requires exactly one injected help snapshot of the
same kind and command; API/OAuth kinds require nil. `resolve` computes the
descriptor once, requires descriptor ID/version/profile kind to equal factory
authority, sorts/deduplicates requested capabilities, and throws the first
lexicographically sorted `.unsupportedCapability` unless every support is
`.supported`. `EngineAdapterSelectionV1.makeAdapter` captures that exact profile
and factory; it cannot re-resolve a different profile. `EngineExecutionStore`
uses this same resolver closure with `(profile, requiredCapabilities)` at begin,
replay comparison, predecessor-session resolution, and recovery.

Coordinator resolves context/workspace and exact hashes before Store begin,
creates one router at Store `nextSequence`, binds the two DB-free sinks, builds
runtime, repeats persisted-capability selection, and dispatches only
`.startNow`; `.alreadyStarted` constructs no adapter and enters recovery. It
owns task/lease/sinks/cancel through one receipt. `route` accepts only accepted,
sessionBound, progress, toolActivity, or checked usage; it rejects terminal.
`routeTerminal` requires artifacts only for completed, sets
`terminalIdempotencyKey="engine.terminal.v1:"+executionId+":"+sequence`, and
atomically fixes sequence/state. `routeProtocolFailure` is blocked /
engineProtocolError / no artifacts. Any route after terminal throws
`EngineDuplicateTerminalErrorV1`; `state()` only reads state.

| intent | proposal kind / subtype / payload |
|---|---|
| `.completed(handoff)` | `.completed` / nil / `.completed(handoff:)`; artifacts are exactly the builder result |
| `.blocked(reasonCode,detail)` | `.blocked` / `.ordinary` / `.blocked(reasonCode:detail:)` |
| `.needsHumanInput(kind,prompt,options)` | `.blocked` / `.needsHumanInput` / `.needsHumanInput(kind:prompt:options:)` |
| `.failed(code,detail)` | `.failed` / nil / `.failed(code:detail:)` |
| `.canceled(reasonCode,detail)` | `.canceled` / nil / `.canceled(reasonCode:detail:)` |

First terminal sink call routes→records→optionally prepares→commits; later calls
throw and write nothing. Progress sink rejects accepted/sessionBound/terminal;
Board may submit only progress/toolActivity/usage. Router and Store both use
checked usage addition. Static DB-free manifest builder rejects >256/duplicates,
uses no-follow component opens beneath root, requires regular files, hashes the
open handle, compares pre/post device/inode/size/mtime, and returns array-order
ordinals with original normalized path/kind/label, checked bytes and lowercase
SHA-256. Failure closes handles and returns §18.1 ordinal error with no proposal.
Coordinator then route→record→instance prepare; recovery uses
`recoverPreparation`; later drift invalidates the pending proposal.

Recovery handling is exhaustive and has no default branch:

| existing action | coordinator behavior |
|---|---|
| `.prepareAndCommitProposal(id)` | reload workspace/context, verify descriptor and pending content; recover preparation, then commit exact proposal |
| `.startPrepared` | repeat capability selection and dispatch CAS; start only an exact `.startNow` |
| `.resumeSession(id,externalId)` | verify exact predecessor/session/scope/workspace, build provider resume command, then consume through one new router initialized from Store sequence |
| `.replayExecution` | require a future descriptor not equal to `.nonReplayable`; all three F1D built-ins therefore fail closed |
| `.cancelAndReconcile` | request adapter/process cancellation, wait for exit evidence, then route/commit exactly one canceled terminal |
| `.deferCampDeletion` | return it unchanged in `EngineRecoverySummaryV1`; F2 remains the sole consumer |

### 18.3 Byte-complete context, workspace, and predecessor identity

`EngineAnsweredRequestContextV1: Codable, Sendable, Equatable` is owned by
`ContextPacket.swift` and stores, in this exact schema/order-independent model,
`schemaVersion=1`, `userRequestId`, `cardId`, `kind`, `prompt`,
`optionsJson: JSONValue?`, `answerJson: JSONValue`, and `answeredAt: Date`.
Only answered, non-approval, nonredacted same-Card rows with nonnil answer and
finite answer date are accepted. JSON columns are decoded values, never quoted
JSON strings; custom Codable writes an explicit JSON `null` for nil options and
CanonicalJSONV1 writes Date as milliseconds since 1970. Golden bytes are
`{"answerJson":{"text":"yes"},"answeredAt":0,"cardId":"00000000-0000-4000-8000-000000000002","kind":"text","optionsJson":null,"prompt":"Proceed?","schemaVersion":1,"userRequestId":"00000000-0000-4000-8000-000000000001"}`
with SHA-256 `6dcb34c02a9adf580e2fb48f850eb7ffd0d93ec5b680c82d6ca90e036b6d34c2`.

`EngineContextResolveRequestV1` stores `campId`, `cardId`, `companionId`,
`contextJson`, and `contextHash`; `EngineResolvedContextTransportV1` stores the
decoded `EngineContextEnvelopeV1`, rebuilt `ContextPacket`, canonical envelope
JSON, and hash. `assemble` loads the rows below, creates sorted refs, then
rebuilds the packet; `reload` starts from persisted contextJson and must reload
every ref. Both require byte equality to the expected hash. Ref-to-source is
closed: input/Card = canonical `{id,missionId,title,descriptionText,
expectedOutput,dependsOnJson,maxTurns,tokenBudget}`; input/user_request = the
DTO above; input/card-return = latest `cardReturned` EventRecord canonical
`{id,cardId,payloadJson,createdAt}`; memory = canonical CampNoteRecord or
CompanionNoteRecord selected by ref ID; handoff = canonical upstream Card title,
handoff value, ordered workspace declarations and ordered durable Artifact rows;
resource/Companion = canonical `{id,name,rolePrompt,toolsJson}` plus sorted tool
definitions returned by the injected dependency loader; resource/Workspace =
§18.3 workspace identity keyed by squad ID; instruction = canonical
`{schemaVersion:1,outcomeContract,autonomy,contextPacketRenderVersion:1,
toolNames:[sorted unique names]}` keyed by outcome-contract ID/version. Row ID is
the real canonical UUID, ref version is the row version when present and `1`
otherwise, and ref hash is SHA-256 of those canonical bytes. Missing/redacted/
cross-scope rows, malformed JSON, changed bytes, dependency-loader drift, or an
unconsumed ref fails before dispatch. No other value may alter `system` or
`firstUserMessage`; tuple answeredRequests and tuple upstream inputs have zero
product callers after F1D.

`EngineWorkspaceIdentityV1: Codable, Sendable, Equatable` stores
`schemaVersion=1,campId,squadId,workspacePath,bookmarkHash:String?`; nil bookmark
is explicit null, nonnil is SHA-256 of raw bookmark bytes. Workspace path is
the absolute standardized file-URL path (no symlink resolution, no trailing
slash except `/`), and root must be a no-follow directory. Golden bytes
`{"bookmarkHash":null,"campId":"00000000-0000-4000-8000-000000000003","schemaVersion":1,"squadId":"00000000-0000-4000-8000-000000000004","workspacePath":"/tmp/ranch"}`
hash to `df5bd1c21309afa8511e45572db41698c8a9f18449cfa1a1058e8c168dd3b7c1`.
`EngineWorkspaceResolveRequestV1` stores card/camp IDs plus expected
`EngineWorkspaceRefV1`; resolver loads card→mission→squad→Camp, constructs
`WorkspaceScopedAccess`, derives identity, and requires reference exactly
`squad-workspace.v1:<squadId>` and hash exactly canonical identity hash.
`EngineResolvedWorkspaceV1` stores identity, URL and a private release-once
closure; `release()` and deinit call `WorkspaceScopedAccess.stop()` at most once.
Coordinator owns it through adapter/process/ArtifactStager completion and
releases after pipes and temp config close. Raw reference is never a URL.

`EngineExecutionRequestFieldsV1.sessionSelection` is replaced by
`predecessorExecutionId: String?`; its initializer validates a canonical UUID.
Store adds internal `resolvePredecessorSession(predecessorExecutionId:cardId:
campId:profileId:descriptor:workspaceHash:scopeJSON:scopeHash:database:) throws
-> EngineSessionReferenceV1?`. Nil means a new session. Nonnil performs one
exact-ID query and requires a nonrunning, nonredacted same-card/camp/profile/
adapter/version execution with nonnil session FK, then an open/nonredacted
session with nonnil external ID and exact scope/workspace. Any mismatch,
unsupported resume, or missing row throws `EngineSessionScopeMismatchError`
before execution/run/command/event writes; it never selects latest or falls
back. The old selection type may remain for frozen F1B tests, but product caller
and request-field references to it are zero.

### 18.4 Exact CLI command, help, parser, process, and safe evidence

`CliEngineCommandInputV1` owns command, W, S, M, R, prompt, bridge path, socket,
token, card ID, sorted tool names, 0600 Claude config URL, and `.first(ranchUUID)`
or `.resume(externalID)`. M is `EngineExecutionRequest.model`; W is the resolved
workspace path. Builder emits these exact ordered arrays:

```swift
// Codex first / resume; C is the exact ordered configPairs below.
["exec","--cd",W,"--sandbox",S,"-m",M] + C + ["--json",PROMPT]
["exec","resume",ID,"--cd",W,"--sandbox",S,"-m",M] + C + ["--json",PROMPT]
// Claude first / resume.
["-p",PROMPT,"--output-format","stream-json","--verbose","--mcp-config",FILE,
 "--permission-mode",MODE,"--session-id",UUID,"--model",M,"--add-dir",W]
["-p",PROMPT,"--output-format","stream-json","--verbose","--mcp-config",FILE,
 "--permission-mode",MODE,"--resume",ID,"--model",M,"--add-dir",W]
```

`C` is seven repeated `"-c", value` pairs, in order:
`model_reasoning_effort=toml(R)`, `mcp_servers.ranchboard.command=toml(B)`,
`mcp_servers.ranchboard.args=[toml("--board-server")]`, then env keys
`AGENTLOOP_BOARD_SOCKET`, `AGENTLOOP_BOARD_TOKEN`,
`AGENTLOOP_BOARD_CARD_ID`, `AGENTLOOP_BOARD_TOOLS`, each `=toml(value)`.
No other config key is accepted. Claude FILE is sorted-key canonical JSON with
only the equivalent `mcpServers.ranchboard.{command,args,env}` object. Prompt
already contains Contract; every resume rebuilds it. Process cwd is W.

`CliHelpSnapshotV1` stores kind, command, executable SHA-256, first/resume exit
status and stdout SHA-256, sorted unique first/resume flags, and sorted
subcommands. `CliHelpProbeV1.snapshot(for:command:) async throws` executes only
Codex `exec --help` and `exec resume --help`, or Claude `--help`, caps each
stdout at 256 KiB, requires exit 0, and extracts exact standalone flag tokens;
raw output is not persisted. Orchestrator caches in memory by
`(kind,command,executableHash)` and injects immutable snapshots into registry;
tests inject DTOs and launch no process. Capability requirements are exact:
Codex stream/usage=`--json`; board/tool/network=`-c`; read/write=`--cd`+
`--sandbox`; resume=`resume`+all prior flags. Claude stream/usage=
`--output-format`+`--verbose`; board/tool/network=`--mcp-config`; read/write=
`--add-dir`+`--permission-mode`; resume=`--resume`; all Claude execution also
requires `--model`, and first bind requires `--session-id`. Cancellation is
supported only when the injected process driver advertises TERM/KILL support.
A missing token downgrades exactly the capabilities naming it.

Parsers expose `parse(line: String) throws -> [CliProviderEventV1]`; accepted
exact-key JSON objects are: Codex `{type:"thread.started",thread_id}`,
`{type:"turn.started"}`, `{type:"item.completed",item:{id,type:"agent_message",
text}}`, `{type:"item.completed",item:{id,type:"mcp_tool_call",server,tool,
status}}`, `{type:"turn.completed",usage:{input_tokens,cached_input_tokens,
output_tokens}}`, and `{type:"error",message}`; Claude
`{type:"system",subtype:"init",session_id}`, `{type:"assistant",session_id,
message:{role:"assistant",content:[{type:"text",text}],usage:{input_tokens,
output_tokens,cache_read_input_tokens}}}`, and `{type:"result",subtype,
is_error,result,session_id,total_cost_usd,usage:{input_tokens,output_tokens,
cache_read_input_tokens}}`. Each object/nested object rejects extra/missing or
wrong-type keys; token/cost conversion is checked nonnegative Int (USD→micros
must be exact and nonoverflowing). Codex binds only thread.started; Claude init
and result IDs must equal the pre-generated UUID. Blank, malformed, unknown,
provider error, ID drift, EOF without result, or result without Board terminal
throws protocol failure; no recursive search or ignored event exists.

`CliProcessLaunchRequestV1` stores execution ID/spec/W; frames are
`.stdoutLine(String)`, `.stderr(Data)`, `.exited(Int32)`;
`CliProcessExitEvidenceV1` stores pid, processGroupID, status, termSent,
killSent, stdoutEOF, stderrEOF, childReaped. `CliProcessDrivingV1` requires
`launch(_:) -> AsyncThrowingStream<CliProcessFrameV1,Error>` and
`cancel(executionId:) async throws -> CliProcessExitEvidenceV1`. Launch creates
one process group. Cancel atomically marks intent, sends TERM to `-pgid`, waits
5 seconds, sends KILL if alive, waits 2 seconds, drains both pipes for at most
1 second after observed exit, closes handles, verifies wait/reap and ESRCH,
then removes the 0600 config; cleanup failure is returned, never swallowed.
Terminal-vs-cancel race is decided by router: accepted terminal wins; otherwise
only full exit evidence permits canceled.

Sanitizer derives execution-stable `trace = prefix16(sha256("engine-trace.v1\0"
+ executionId))`, lowercase hex. Exact persisted mappings are parser/EOF/ID/
missing-terminator → blocked `.engineProtocolError`, reason
`engine_protocol_error`, detail `Engine protocol failure. trace=<trace>`;
unsupported/help → blocked `.engineProtocolError`, `engine_capability_unsupported`,
`Engine capability unavailable. trace=<trace>`; launch/cleanup/exit uncertainty
→ blocked `.externalEffectUnknown`, `engine_external_effect_unknown`,
`Engine process outcome unknown. trace=<trace>`; provider error → failed nil,
`engine_provider_error`, `Engine provider failed. trace=<trace>`; proven cancel
→ canceled nil, `engine_canceled`, `Engine execution canceled. trace=<trace>`.
The sanitizer takes only this reason enum plus execution ID; raw Error/stderr,
prompt, token, credential/env values, MCP bytes/path, and config never enter its
result, logs, events, proposals, or `String(describing:)`.

Revision 5a closes only Review01d P1-1…P1-4. The next review must check these
exact declarations, bytes, templates, tables, and deletion gates; it may not
reopen F1A–F1C or expand F1D scope.

## 19. Revision 5b — closed sanitized terminal transport

Revision 5b is the sole plan-only correction for successor finding P1-5. It
overrides only the conflicting sanitizer/blocked-intent clauses in §§18.1,
18.2, and 18.4. The 99-line allowlist, paths, identities 001–080,
dependencies, descriptor matrix, compile-red ordering, and all F1A–F1C/F1E/F2
boundaries remain unchanged. No scaffold, test, product, build, process, or App
work opens until an independent successor review reports 0 P0 / 0 P1.

### 19.1 Exact DB-free sanitizer declarations

The following declarations are owned by the already-allowlisted
`Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`, have `package` access,
and import no database type:

```swift
package enum CliEngineFailureReasonV1: Sendable, Equatable {
    case protocolViolation
    case capabilityUnsupported
    case processOutcomeUnknown
    case providerFailure
    case provenCancellation
}

package struct CliEngineSanitizedFailureV1: Sendable, Equatable {
    package let reason: CliEngineFailureReasonV1
    package let traceLabel: String
    package let intent: EngineTerminalIntentV1

    package init(
        reason: CliEngineFailureReasonV1,
        traceLabel: String
    ) throws
}

package struct CliEngineSecretSanitizerV1: Sendable {
    package init()
    package func failure(
        reason: CliEngineFailureReasonV1,
        executionId: String
    ) throws -> CliEngineSanitizedFailureV1
}
```

The reason enum has no raw value, associated value, stored field, or custom
initializer. `CliEngineSecretSanitizerV1.init()` stores nothing. The result
initializer requires `traceLabel` to match exactly `^[0-9a-f]{16}$`, stores
the two arguments, and constructs `intent` solely from the closed table in
§19.3; it accepts no Error, stdout, stderr, prompt, token, credential, env,
MCP content/path, command, config, or free-form detail. The sanitizer method
first validates canonical `executionId`, computes the trace as specified in
§19.4, and calls that initializer. These types perform no DB/FS/socket/process/
Task/clock/UUID operation and expose no raw diagnostic channel.

For the compile-only phase the signatures above are final, but
`failure(reason:executionId:)` has exactly this first-and-only body:

```swift
throw EngineAdapterCapabilityUnavailableErrorV1(.secretSanitize)
```

Identity 070's first product call remains
`sanitizer.failure(reason:.protocolViolation, executionId: executionId)` and
must observe `.secretSanitize`; no result initializer or router call may occur
first. After the immutable 19/19 runtime red, this one body is replaced by the
final implementation. The post-red gates add: zero
`EngineAdapterCapabilityUnavailableErrorV1(.secretSanitize)`, zero unavailable
body in `CliEngineSecretSanitizerV1.failure`, and identity 070 still calls the
exact two-argument method. The shared temporary capability/error declarations
are then deleted under §18.1's existing zero-symbol gates.

### 19.2 Closed blocked subtype and lossless sinks

The following value types are owned by the already-allowlisted
`Domain/EngineExecutionReceipt.swift`:

```swift
package enum EngineBlockedIntentSubtypeV1: Sendable, Equatable {
    case ordinary
    case engineProtocolError
    case externalEffectUnknown
}

package enum EngineTerminalIntentV1: Sendable, Equatable {
    case completed(handoff: HandoffPayload)
    case blocked(
        subtype: EngineBlockedIntentSubtypeV1,
        reasonCode: String,
        detail: String
    )
    case needsHumanInput(
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]
    )
    case failed(code: String, detail: String)
    case canceled(reasonCode: String, detail: String)
}

package enum EngineBoardTerminalIntentV1: Sendable, Equatable {
    case completed(handoff: HandoffPayload)
    case blocked(reasonCode: String, detail: String)
    case needsHumanInput(
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]
    )
}
```

`EngineBlockedIntentSubtypeV1` is deliberately closed to the three listed
cases; needs-human-input is not a blocked-subtype case. In
`Domain/ExecutionEngine.swift`, `EngineTerminalSink` retains exactly
`submit(_ intent: EngineTerminalIntentV1) async throws`; new
`EngineBoardTerminalSink` has exactly
`submit(_ intent: EngineBoardTerminalIntentV1) async throws`. CLI and ModelLoop
adapters receive only `EngineTerminalSink`. BoardTools, BoardToolServer, and
BoardServerBridgeMain receive only `EngineBoardTerminalSink`, replacing their
§18.1 `EngineTerminalSink` field. The coordinator-owned Board sink converts
Board completed and needsHumanInput losslessly, and converts Board blocked only
to `.blocked(subtype:.ordinary, reasonCode:detail:)`. Board therefore has no
type-level construction path for `.engineProtocolError` or
`.externalEffectUnknown`.

The coordinator-owned adapter sink forwards its `EngineTerminalIntentV1`
unchanged to `EngineEventRouterV1.routeTerminal`. The router no longer exposes
`routeProtocolFailure`; coordinator-internal protocol failure also calls
`routeTerminal(.blocked(subtype:.engineProtocolError,...), artifacts: [])`.
Existing sequence, duplicate-terminal, idempotency, and zero-write-after-first
rules remain unchanged.

Router proposal conversion is exact and exhaustive:

| intent | `terminalKind` | `terminalSubtype` | payload / artifacts |
|---|---|---|---|
| completed | `.completed` | nil | `.completed(handoff:)` / exact manifest |
| blocked ordinary | `.blocked` | `.ordinary` | `.blocked(reasonCode:detail:)` / `[]` |
| blocked protocol | `.blocked` | `.engineProtocolError` | `.blocked(reasonCode:detail:)` / `[]` |
| blocked external unknown | `.blocked` | `.externalEffectUnknown` | `.blocked(reasonCode:detail:)` / `[]` |
| needs human | `.blocked` | `.needsHumanInput` | `.needsHumanInput(kind:prompt:options:)` / `[]` |
| failed | `.failed` | nil | `.failed(code:detail:)` / `[]` |
| canceled | `.canceled` | nil | `.canceled(reasonCode:detail:)` / `[]` |

No sink or router normalizes, drops, infers, or rewrites a blocked subtype,
reason code, or safe detail. The existing `EngineTerminalSubtypeV1` remains the
durable proposal enum; the new closed enum only constrains pre-proposal input.

### 19.3 Exact five-reason mapping

`CliEngineSanitizedFailureV1.init` uses this exhaustive switch and no default:

| reason | exact returned `intent` |
|---|---|
| `.protocolViolation` | `.blocked(subtype:.engineProtocolError, reasonCode:"engine_protocol_error", detail:"Engine protocol failure. trace=\(traceLabel)")` |
| `.capabilityUnsupported` | `.blocked(subtype:.engineProtocolError, reasonCode:"engine_capability_unsupported", detail:"Engine capability unavailable. trace=\(traceLabel)")` |
| `.processOutcomeUnknown` | `.blocked(subtype:.externalEffectUnknown, reasonCode:"engine_external_effect_unknown", detail:"Engine process outcome unknown. trace=\(traceLabel)")` |
| `.providerFailure` | `.failed(code:"engine_provider_error", detail:"Engine provider failed. trace=\(traceLabel)")` |
| `.provenCancellation` | `.canceled(reasonCode:"engine_canceled", detail:"Engine execution canceled. trace=\(traceLabel)")` |

Parser/malformed/unknown/EOF/session-ID/missing-terminator errors select
`.protocolViolation`; help/required-flag/unsupported-capability errors select
`.capabilityUnsupported`; launch/temp-cleanup/unreaped-child/unknown-exit
errors select `.processOutcomeUnknown`; provider-declared failure selects
`.providerFailure`; only full TERM/KILL/drain/reap evidence selects
`.provenCancellation`. Callers pass only the enum and execution ID. Ordinary
Board blocked never passes through this sanitizer.

### 19.4 Trace and privacy authority

Trace input bytes are UTF-8 `"engine-trace.v1"`, one NUL byte, then the exact
lowercase canonical execution UUID string. Compute SHA-256, render the full
digest as 64 lowercase ASCII hexadecimal characters, then take characters
`0..<16`. The resulting `traceLabel` is exactly 16 ASCII hex characters—a
64-bit diagnostic label—not 16 digest bytes and not 32 hex characters. The
same execution therefore receives the same label across adapter, replay check,
and recovery.

The only durable/display detail is one of the five fixed English copies in
§19.3 followed by that label. Reason carries no associated diagnostic. Raw
Error/stdout/stderr/prompt/token/config/credential/env/MCP values are neither
inputs to the sanitizer nor stored/logged alongside its result. Revision 5b
adds no path, identity, dependency, schema, F1E, or F2 behavior and closes only
successor P1-5.

## 20. Revision 5c — parent-side Board sink injection

Revision 5c closes only the remaining scoped successor finding that Revision
5b defined a typed Board sink without a production handoff to Board
construction sites. It overrides the conflicting runtime/adapter/driver/Board
field lists in §§18.1 and 19.2; every other Revision 5–5b contract remains
unchanged. No new path, schema, dependency, test identity, F1E, or F2 behavior
is authorized.

### 20.1 One router and three exact coordinator-owned sinks

The already-allowlisted `Kernel/Orchestrator.swift` owns these `package`
declarations:

```swift
package typealias EngineRoutedEventCommitV1 =
    @Sendable (EngineExecutionEvent) async throws -> Void

package struct EngineAdapterTerminalRouterSinkV1: EngineTerminalSink {
    package let router: EngineEventRouterV1
    package let commit: EngineRoutedEventCommitV1
    package init(
        router: EngineEventRouterV1,
        commit: @escaping EngineRoutedEventCommitV1
    )
    package func submit(_ intent: EngineTerminalIntentV1) async throws
}

package struct EngineBoardTerminalRouterSinkV1: EngineBoardTerminalSink {
    package let router: EngineEventRouterV1
    package let commit: EngineRoutedEventCommitV1
    package init(
        router: EngineEventRouterV1,
        commit: @escaping EngineRoutedEventCommitV1
    )
    package func submit(_ intent: EngineBoardTerminalIntentV1) async throws
}

package struct EngineProgressRouterSinkV1: EngineProgressSink {
    package let router: EngineEventRouterV1
    package let commit: EngineRoutedEventCommitV1
    package init(
        router: EngineEventRouterV1,
        commit: @escaping EngineRoutedEventCommitV1
    )
    package func submit(
        _ payload: EngineExecutionEventPayloadV1
    ) async throws
}
```

Initializers only assign the two arguments. For each execution, coordinator
creates exactly one `EngineEventRouterV1` and one commit closure that calls the
existing Store event/proposal path. It constructs one value of each sink above
with that same actor instance and same closure before creating
`EngineAdapterRuntimeV1`. Adapter terminal sink calls
`router.routeTerminal(intent, artifacts: resolvedManifest)` then `commit`.
Board terminal sink exhaustively converts completed and needsHumanInput
losslessly and Board blocked to
`.blocked(subtype:.ordinary, reasonCode:detail:)`, then uses that same
`routeTerminal`/`commit` path. Progress sink calls `router.route(payload)` then
`commit`. No sink stores AppDatabase, sequence, terminal state, or a second
idempotency authority. Consequently Board terminal, adapter failure, EOF, and
process cancel race on the same actor; exactly the first routed terminal can
commit.

During compile-only red, `EngineBoardTerminalRouterSinkV1.submit` has the exact
first-and-only body:

```swift
throw EngineAdapterCapabilityUnavailableErrorV1(.terminalIntent)
```

Its initializer remains assignment-only. After the immutable 19/19 red, that
body is replaced by the exhaustive conversion/route/commit implementation
above. Final source gates add zero unavailable body in
`EngineBoardTerminalRouterSinkV1.submit`, one construction of each sink per
coordinator execution, and equality-by-identity checks in 069/077/078 proving
all three captured the same router actor.

### 20.2 Runtime, adapters, and driver signatures

`Domain/ExecutionEngine.swift` final `EngineAdapterRuntimeV1` field and
initializer order is now exactly:

```swift
package let context: EngineResolvedContextTransportV1
package let workspace: EngineResolvedWorkspaceV1
package let terminalSink: any EngineTerminalSink
package let boardTerminalSink: any EngineBoardTerminalSink
package let progressSink: any EngineProgressSink
package let modelLoopDriver: (any ModelLoopExecutionDrivingV1)?
package let cliProcessDriver: (any CliProcessDrivingV1)?

package init(
    context: EngineResolvedContextTransportV1,
    workspace: EngineResolvedWorkspaceV1,
    terminalSink: any EngineTerminalSink,
    boardTerminalSink: any EngineBoardTerminalSink,
    progressSink: any EngineProgressSink,
    modelLoopDriver: (any ModelLoopExecutionDrivingV1)?,
    cliProcessDriver: (any CliProcessDrivingV1)?
)
```

Coordinator passes the three freshly constructed exact sink values in those
three parameters. Runtime has no initializer overload omitting or deriving the
Board sink and performs no existential cast.

`Loop/ModelLoopEngineAdapter.swift` final `ModelLoopEngineAdapter` stores, in
order, `profile`, `driver`, `context`, `workspace`, `terminalSink`,
`boardTerminalSink`, and `progressSink`; its memberwise package initializer
takes the same order. `ModelLoopExecutionDrivingV1` is exactly:

```swift
package protocol ModelLoopExecutionDrivingV1: Sendable {
    func execute(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
    func cancel(executionId: String) async throws
}
```

`ModelLoopEngineAdapter.execute` passes its six exact execution arguments to
the driver. CardRunner/ModelLoop driver uses `boardTerminalSink` for every
BoardTools construction and `terminalSink` only for adapter/provider failure.
Passing, casting, or wrapping the general terminal sink as a Board sink is
forbidden.

`Loop/CliEngineAdapter.swift` final `CliEngineAdapter` stores, in order,
`profile`, `processDriver`, `commandBuilder`, `codexParser`, `claudeParser`,
`sanitizer`, `context`, `workspace`, `terminalSink`, `boardTerminalSink`, and
`progressSink`; its memberwise package initializer takes that exact order.
When it builds a process request it copies the exact Board/progress existential
values captured from runtime; sanitizer output continues only through the
general terminal sink.

`Loop/CliProcessBackend.swift` final request is:

```swift
package struct CliProcessLaunchRequestV1: Sendable {
    package let executionId: String
    package let spec: CliCommandSpec
    package let workspaceURL: URL
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package init(
        executionId: String,
        spec: CliCommandSpec,
        workspaceURL: URL,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    )
}
```

The initializer validates the execution UUID and absolute directory URL, then
assigns all five values without I/O. `CliEngineAdapter` is the only production
constructor. `CliProcessBackend.launch` passes only the last two capabilities
to the parent-side Board server path described below. Neither Swift existential
is encoded into argv, environment, JSON, MCP config, socket frames, or child
process memory.

### 20.3 Exact DB-free BoardTools and parent BoardToolServer

`Tools/BoardTools.swift` replaces its DB/Card/Run fields and initializer with:

```swift
public struct BoardTools: Sendable {
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package init(
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    )
    package func complete(input: JSONValue) async throws -> ToolOutcome
    package func block(input: JSONValue) async throws -> ToolOutcome
    package func progressNote(input: JSONValue) async throws -> ToolOutcome
    package func askUser(input: JSONValue) async throws -> ToolOutcome
}
```

Initializer only assigns. After existing input validation, `complete` calls
only `boardTerminalSink.submit(.completed(handoff:))`; `block` calls only
`.blocked(reasonCode:detail:)`; `askUser` calls only
`.needsHumanInput(kind:prompt:options:)`; `progressNote` calls only
`progressSink.submit(.progress(message:))`. A successful submit returns the
corresponding existing ToolOutcome; a sink error is thrown without raw
stringification. `BoardToolHandler.execute`, which must remain nonthrowing for
`ToolHandler`, catches it and returns the fixed
`.error("Board intent rejected.")`; it never logs or embeds the Error. These
four handlers have no DB/FS/process authority, and their closed Board enum
cannot express failed, canceled, engineProtocolError, or
externalEffectUnknown.

`Loop/BoardToolServer.swift` owns exactly this parent-side assembly surface:

```swift
package static func makeExecutor(
    boardTerminalSink: any EngineBoardTerminalSink,
    progressSink: any EngineProgressSink
) -> (executor: ToolExecutor, toolDefs: [ToolDef])

package init(
    socketURL: URL,
    token: String,
    cardId: String,
    boardTerminalSink: any EngineBoardTerminalSink,
    progressSink: any EngineProgressSink,
    onTerminalAccepted: @escaping @Sendable () -> Void,
    acceptQueue: DispatchQueue,
    handlerQueue: DispatchQueue
)
```

`makeExecutor` constructs one BoardTools with those exact sinks and exactly the
four handlers/defs `complete_card`, `block_card`, `progress_note`, `ask_user`.
The initializer calls that method, stores its executor/defs and the two sinks
to retain their lifetime, and stores no DB, terminal outcome, proposal, or
second terminal callback. It requires the explicit already-generated token;
there is no default sink or token on this initializer. After a parent executor
returns `.completed` or `.blocked`—which occurs only after sink submit
succeeded—the server invokes `onTerminalAccepted` solely to request transport
shutdown. It never infers or stores a terminal fact. CliProcessBackend extracts
the already-command-builder-validated canonical card ID from the exact
`AGENTLOOP_BOARD_CARD_ID` entry in `request.spec.environment`, then constructs
this server with `request.boardTerminalSink` and `request.progressSink` before
launching the child.

### 20.4 Child bridge boundary and exact 077/078 red paths

`Loop/BoardServerBridgeMain.swift` is explicitly corrected from §19.2: it does
not receive any sink. `BoardServerBridgeMain` and `BoardSocketBridgeClient`
remain DB-free, sink-free child-process socket relays whose state is only
socket handle, token, and optional card ID. A child `tools/call` JSON-RPC frame
becomes the existing authenticated `tool_call` socket frame; the parent
BoardToolServer validates token/card/tool, invokes its parent ToolExecutor,
which invokes BoardTools, and only then reaches the typed Board sink. No Swift
existential, pointer, closure, proposal, or terminal state crosses the process
boundary.

Identity 077's compile-red path is exactly valid complete input →
`BoardTools.complete` → injected `EngineBoardTerminalRouterSinkV1.submit` →
`.terminalIntent`. Because the package method throws, the test observes the
typed unavailable error directly before any ToolOutcome success. Identity
078's path is child bridge `tool_call` frame → parent BoardToolServer → same
parent BoardTools instance → the same Board sink → `.terminalIntent`; its fake
sink records the typed first cause before the server returns the fixed error
tool_result. Neither test calls a general terminal sink or constructs a blocked
subtype.

After red, the one Board sink unavailable body is replaced and both paths
produce only completed, ordinary blocked, or needs-human-input. Protocol/error
and external-effect-unknown intents remain adapter-only via
`EngineTerminalSink`. EOF/cancel/parser/provider and Board terminal still meet
at the same router, so no process callback or server shadow can win twice.
Final gates require: runtime/adapters/process request each contain exactly one
typed Board sink field; ModelLoop driver signature contains it; parent server
and BoardTools constructors receive it; child bridge contains zero
`EngineTerminalSink`, `EngineBoardTerminalSink`, or `EngineProgressSink` symbol;
Board files contain zero `AppDatabase`; and identities 077/078 retain their
exact first-call paths and `.terminalIntent` red. Revision 5c adds no new file,
identity, schema, dependency, F1E, or F2 work.

## 21. Revision 5d — completed-terminal manifest resolver

Revision 5d closes only the internal manifest-source gap in §20.1. It
overrides the two terminal-router sink field/initializer lists and the word
`static` on §18.1's manifest builder. All other Revision 5–5c declarations,
red identities, and boundaries remain unchanged.

The already-allowlisted `Kernel/Orchestrator.swift` owns this synchronous,
throwing, DB-free closure type:

```swift
package typealias EngineTerminalManifestResolveV1 =
    @Sendable (HandoffPayload) throws
        -> [EngineTerminalArtifactDeclarationV1]
```

`ArtifactStager.buildManifest(workspaceRoot:handoff:)` is a `package` instance
method, not static. Its signature, error taxonomy, no-follow/read-only behavior,
and result remain exactly §18.1/§18.2. Although its `ArtifactStager` instance is
the coordinator's already-injected authority, this method must not read or
mutate that instance's database/blobStore/checkpoint fields; it only performs
the bounded workspace reads and hand checks frozen in §18.2.

The two terminal sinks now have these exact stored fields and initializer
orders; the progress sink remains byte-for-byte as specified in §20.1:

```swift
package struct EngineAdapterTerminalRouterSinkV1: EngineTerminalSink {
    package let router: EngineEventRouterV1
    package let manifestResolver: EngineTerminalManifestResolveV1
    package let commit: EngineRoutedEventCommitV1
    package init(
        router: EngineEventRouterV1,
        manifestResolver: @escaping EngineTerminalManifestResolveV1,
        commit: @escaping EngineRoutedEventCommitV1
    )
    package func submit(_ intent: EngineTerminalIntentV1) async throws
}

package struct EngineBoardTerminalRouterSinkV1: EngineBoardTerminalSink {
    package let router: EngineEventRouterV1
    package let manifestResolver: EngineTerminalManifestResolveV1
    package let commit: EngineRoutedEventCommitV1
    package init(
        router: EngineEventRouterV1,
        manifestResolver: @escaping EngineTerminalManifestResolveV1,
        commit: @escaping EngineRoutedEventCommitV1
    )
    package func submit(_ intent: EngineBoardTerminalIntentV1) async throws
}
```

After workspace resolution and before constructing either sink, coordinator
creates exactly one resolver:

```swift
let manifestResolver: EngineTerminalManifestResolveV1 = {
    [artifactStager, workspaceRoot = resolvedWorkspace.url] handoff in
    try artifactStager.buildManifest(
        workspaceRoot: workspaceRoot,
        handoff: handoff
    )
}
```

It passes that same captured closure value to both terminal sink initializers,
along with the same router and commit closure. No adapter, Board object, driver,
or process creates or replaces a resolver. The resolver contains no Store,
sequence, router, proposal, prepare, terminal, clock, UUID, or write operation.

Final adapter-sink `submit` is an exhaustive switch. For
`.completed(handoff:)` it calls `manifestResolver(handoff)` exactly once, then
calls `router.routeTerminal(intent, artifacts: declarations)`. For blocked,
needsHumanInput, failed, and canceled it never calls the resolver and passes the
literal `[]`. Final Board-sink `submit` first performs §20.1's closed Board→
engine-intent conversion; completed then resolves exactly once, while ordinary
blocked and needsHumanInput pass literal `[]`. After a successful route, each
sink calls the shared commit closure exactly once.

A resolver error propagates as its typed `ArtifactManifestBuildErrorV1`; it
leaves router state open and emits no event/proposal, calls no commit/prepare,
and performs no DB/FS write or fallback terminal. The coordinator handles that
thrown pre-route failure under the already-frozen fail-closed path; it cannot
reinterpret it as completion. Because resolution precedes actor routing, two
concurrent completed submissions may both perform bounded read-only manifest
checks. Only the first successful actor route wins; every loser receives the
existing duplicate-terminal error and never invokes commit.

During compile-only red, both terminal sink `submit` implementations retain
their §20.1 first-and-only unavailable body. They therefore do not inspect the
intent, invoke the resolver, route, or commit. Identities 063, 069, 077, and 078
continue to fail first with their existing `.terminalIntent` authority; no red
identity or ordering changes.

Post-red assertions inside those existing identities require: one shared
resolver capture supplied to both terminal sinks; completed resolver count one
for the winning submission; noncompleted resolver count zero; resolver failure
leaves router `.open`, routed-event/commit/prepare/write counts zero; concurrent
completed loser commit count zero; and the winning manifest equals the exact
ArtifactStager declarations. Source gates require both terminal sink structs to
store exactly one `EngineTerminalManifestResolveV1`, both initializers to
require it, the progress sink to contain none, coordinator to define one closure
and pass it to both, and zero other production `buildManifest` caller. Revision
5d adds no file, identity, dependency, schema, F1E, or F2 work.

## 22. Revision 5e — typed CLI parent Board control handoff

Revision 5e closes only the remaining bounded Review01d successor finding: the
CLI process request did not carry the same typed Board socket, token, and Card
identity that the command builder had already embedded for the child. This
section overrides only the conflicting `CliProcessLaunchRequestV1` and CLI
control-value clauses in §§18.4 and 20.2–20.3. Every other Revision 5–5d
declaration, identity, first-failure order, sink, manifest, and child-bridge
boundary remains unchanged. No new DTO, file, identity, dependency, schema,
top-level child environment authority, F1E, or F2 behavior is authorized.

### 22.1 Exact final launch request

`Loop/CliProcessBackend.swift` final request field and initializer order is
exactly:

```swift
package struct CliProcessLaunchRequestV1: Sendable {
    package let executionId: String
    package let spec: CliCommandSpec
    package let workspaceURL: URL
    package let boardSocketURL: URL
    package let boardToken: String
    package let boardCardId: String
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package init(
        executionId: String,
        spec: CliCommandSpec,
        workspaceURL: URL,
        boardSocketURL: URL,
        boardToken: String,
        boardCardId: String,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    )
}
```

The initializer retains §20.2's execution-ID and workspace validation. It also
requires `boardSocketURL` to be an absolute, base-free `file:` URL with a
nonempty absolute socket path; `boardToken` to be exactly 64 lowercase ASCII
hexadecimal characters matching `[0-9a-f]{64}`; and `boardCardId` to equal
`UUID(uuidString: boardCardId)?.uuidString.lowercased()`. These are pure direct
argument checks. After validation it assigns the eight arguments in the order
above, performs no I/O, never parses `spec` arguments, environment, or config,
and never generates or replaces a socket URL, token, or Card ID. There is no
initializer overload that omits, derives, or defaults any of the three Board
control fields.

The existing socket, token, and Card-ID values owned by
`CliEngineCommandInputV1` are named `boardSocketURL`, `boardToken`, and
`boardCardId`. This renaming makes their typed equality with the launch-request
fields explicit; it does not add another DTO or another source of identity.

### 22.2 One same-source value flow before command build

For each `CliEngineAdapter.execute`, the adapter obtains all three control
values exactly once, before calling either command builder: `boardSocketURL`
from one `BoardToolServer.makeSocketURL` call, `boardToken` from one
`BoardToolServer.makeToken` call, and `boardCardId` directly from the
authoritative `EngineExecutionRequest.cardId`. It stores each in one local
constant. It neither parses nor regenerates the Card ID and never asks the
command builder or process backend to infer any of these values.

The adapter passes those same three local values, without transform, first to
the provider-appropriate `CliEngineCommandInputV1` and then to
`CliProcessLaunchRequestV1` together with the returned `CliCommandSpec`, exact
resolved workspace URL, and exact captured Board/progress sinks. The command
builder remains the sole owner of provider encoding: Codex writes the exact
values only into the already-frozen ranchboard `-c` config pairs, while Claude
writes them only into the already-frozen sorted-key 0600 ranchboard MCP file.
The launch request retains its three typed fields only for the parent backend;
it does not copy them into the child process's top-level environment.

No production code may recover a control value by parsing
`CliCommandSpec.arguments`, `CliCommandSpec.environment`, a Codex `-c` value,
or Claude MCP-file bytes. In particular, `CliCommandSpec.environment` contains
no top-level `AGENTLOOP_BOARD_SOCKET`, `AGENTLOOP_BOARD_TOKEN`, or
`AGENTLOOP_BOARD_CARD_ID` duplicate. Provider-specific child config is not a
parent control channel.

### 22.3 Direct parent server construction and cleanup ownership

`CliProcessBackend.launch` constructs the one parent `BoardToolServer` directly
with `socketURL: request.boardSocketURL`, `token: request.boardToken`,
`cardId: request.boardCardId`,
`boardTerminalSink: request.boardTerminalSink`, and
`progressSink: request.progressSink`, plus the already-frozen shutdown callback
and queues, before launching the child. It does not call `makeSocketURL` or
`makeToken`, derive a Card ID, inspect provider kind, parse
argv/environment/config, or read the Claude MCP file to construct that server.
It creates no second Board server, socket path, or token.

The child receives the three string values only through the existing
provider-scoped ranchboard config: Codex's nested MCP `env` `-c` values or
Claude's nested MCP `env` object in the 0600 file. `BoardServerBridgeMain` and
`BoardSocketBridgeClient` remain the socket-only, sink-free relay from §20.4;
they gain no DTO, typed sink, top-level environment authority, identity
generator, or provider-config parser.

The process backend owns the exact same `request.boardSocketURL` for server
start, stop, and unlink, and the exact same `request.boardToken` for the full
server lifetime. Exit/cancel cleanup retains §18.4's pipe/reap ordering and
then makes parent-server stop, unlink of that exact socket path, and removal of
the exact Claude 0600 config visible failures. None is swallowed, converted to
best-effort success, retried with a second socket/token, or repaired by reading
provider config; any uncertain cleanup continues through the already-frozen
`.processOutcomeUnknown` sanitizer path.

### 22.4 Existing red identities and final equality gates

Compile-only scaffold declarations include the three exact command-input and
launch-request fields and the eight-argument request initializer above, but
add no behavior or unavailable case. Identities 072, 073, and 074 retain their
first `.commandBuild` failure; 078 retains its first `.terminalIntent` failure
through the parent server and same typed Board sink; 079 retains its first
`.processLaunch` failure. The immutable red therefore remains exactly 19
discovered / 19 failed with the complete §18.1 first-call table unchanged.

Post-red assertions in existing identities 072/073/074 require the exact same
socket URL, token, and Card ID supplied to the builder input to appear in the
provider-scoped ranchboard config, and the exact same three local values to be
stored in the launch request. Identity 078 requires the parent
`BoardToolServer` to receive values equal to those three request fields and the
same Board/progress sink values, without an argv/environment/file reverse
parse. Existing cleanup assertions additionally require server stop/unlink and
provider-config cleanup failures to remain observable for that same socket and
token.

Final scaffold-signature and source gates require: exactly one typed
`boardSocketURL`, `boardToken`, and `boardCardId` field in each of
`CliEngineCommandInputV1` and `CliProcessLaunchRequestV1`; the launch-request
field/initializer order in §22.1; one adapter call each to
`BoardToolServer.makeSocketURL` and `BoardToolServer.makeToken` per execution;
one direct `request.cardId` binding; both builder input and launch request fed
from those same three locals; direct backend-to-server field forwarding; zero
backend generation or provider-config parsing; and zero top-level process
environment copy of the three `AGENTLOOP_BOARD_*` values. Revision 5e changes
only this plan and requires a fresh responsibility-isolated plan verdict of
`APPROVED — 0 P0 / 0 P1` before any F1D scaffold, test, product, build, process,
or App work opens.

## 23. Revision 5f — repository-canonical Card-ID bytes

Revision 5f overrides only §22.1's conflicting lowercase `boardCardId`
validation and the corresponding §22.4 fixture/equality assertions. Every
other clause and gate remains unchanged; no path, identity, dependency, schema,
F1E, or F2 behavior is added.

`CliProcessLaunchRequestV1.init` must reuse the existing
`CanonicalContractCodingV1.validateCanonicalUUID` for `boardCardId`; its
authoritative predicate is `UUID(uuidString: value)?.uuidString == value`.
Repository UUID factories preserve `UUID().uuidString` exactly, including its
canonical uppercase spelling. No `lowercased`, `uppercased`, normalization, or
other transform is permitted.

`CliEngineAdapter` binds the exact bytes of `request.cardId` once and passes
those same unmodified bytes through `CliEngineCommandInputV1`,
`CliProcessLaunchRequestV1`, the provider-scoped ranchboard config, the parent
`BoardToolServer`, and the child hello/Card comparison. Existing fixed Card-ID
fixtures use one repository-canonical UUID spelling unchanged; an all-lowercase
or any other noncanonical-casing variant is rejected by the initializer before
any I/O. No value is parsed, regenerated, normalized, or transformed anywhere
in this flow.

## 24. Revision 6 — F1D runtime authority closure

Revision 6 is the one bounded successor opened by the pre-implementation
future-green audit. It overrides only the contradictory F1D runtime signatures,
missing authority inputs, and compatibility-test boundary below. Revisions
5–5f remain controlling everywhere else. It adds no schema, migration,
dependency, source file, test identity, F1E, F2, or P2 behavior. Functional
implementation and the immutable 062–080 red remain closed until the existing
Review01d receives a responsibility-isolated Revision 6 successor verdict of
`APPROVED — 0 P0 / 0 P1`.

The pre-Revision-6 prefix is exactly 185,834 bytes / SHA-256
`cba526c908d72c92abc81fa641085f77109a921ef16cb1a211e12434f8c12a9b`.
The allowlist is expanded only for the four existing compatibility tests named
in §24.9. No temporary compatibility overload may preserve the legacy DB
authority that Revision 6 removes.

### 24.1 Payload-only adapters and one sequence owner

`Domain/ExecutionEngine.swift` owns the final adapter protocol:

```swift
package protocol ExecutionEngineAdapter: Sendable {
    func descriptor(
        profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor
    func execute(
        request: EngineExecutionRequest
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
    func cancel(executionId: String) async throws
}
```

Adapters and drivers emit only unsequenced, nonterminal payloads. The
coordinator sends each accepted payload through the one `EngineEventRouterV1`;
only that actor creates `EngineExecutionEvent`, allocates sequence, maintains
cumulative usage, and decides terminal state. A payload-stream `.terminal`
case is a protocol failure. Terminal facts enter only the two terminal sinks;
Board/progress sinks and the adapter stream all share the same router. No
adapter, provider parser, Board server, or process callback may manufacture a
sequence or a complete `EngineExecutionEvent`.

Identity 067 reads `EngineExecutionEventPayloadV1` and retains its exact first
`.execute` unavailable failure. All allowlisted fakes mechanically change their
stream element type; no 062–080 identity or first-failure mapping changes.

The router initializer is extended to accept durable cumulative state:

```swift
package init(
    executionId: String,
    runId: String,
    cardId: String,
    nextSequence: Int,
    initialUsage: EngineUsageV1
)
```

`Database/EngineExecutionStore.swift` adds the transaction-owning package
surface:

```swift
package func acceptRoutedEngineEvent(
    executionId: String,
    sequence: Int,
    event: EngineExecutionEvent
) throws
```

It verifies the exact routed identity and sequence, computes the checked delta
between the event's cumulative usage and the durable execution usage, then
persists through the existing F1B event/receipt/outbox transaction. Decrease,
overflow, mismatch, duplicate, or gap fails with zero write. The existing
`acceptEngineEvent` delta contract remains for frozen F1B callers; F1D product
callers use only `acceptRoutedEngineEvent`.

### 24.2 Truthful registry, descriptor, and runtime

`EngineAdapterRegistryV1.init(factories:helpSnapshots:)` is throwing and
performs all §18.2 structural validation. `resolve` and the captured selection
remain the sole adapter authority. Tests must write `try` at every initializer
call before the immutable red.

`EngineAdapterFactoryV1` officially owns this final production catalog seam:

```swift
package static func builtInFactories(
    makeModelLoopAdapter:
        @escaping @Sendable (
            RuntimeProfileRecord, EngineAdapterRuntimeV1
        ) throws -> any ExecutionEngineAdapter,
    makeCodexAdapter:
        @escaping @Sendable (
            RuntimeProfileRecord, EngineAdapterRuntimeV1
        ) throws -> any ExecutionEngineAdapter,
    makeClaudeAdapter:
        @escaping @Sendable (
            RuntimeProfileRecord, EngineAdapterRuntimeV1
        ) throws -> any ExecutionEngineAdapter
) -> [EngineAdapterFactoryV1]
```

It returns exactly the three §17.2 IDs/versions/profile partitions in that
order. After red, its descriptor closures implement the exact truthful matrix
from the injected CLI help snapshot; none throws an unavailable placeholder.

The final runtime is:

```swift
package struct EngineAdapterRuntimeV1: Sendable {
    package let descriptor: ExecutionEngineDescriptor
    package let context: EngineResolvedContextTransportV1
    package let workspace: EngineResolvedWorkspaceV1
    package let terminalSink: any EngineTerminalSink
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package let modelLoopDriver: (any ModelLoopExecutionDrivingV1)?
    package let cliProcessDriver: (any CliProcessDrivingV1)?
    package let cliConfiguration: CliEngineRuntimeConfigurationV1?
}
```

The coordinator passes the exact descriptor returned by its current registry
selection. API/OAuth runtime has only `modelLoopDriver`; CLI runtime has only
`cliProcessDriver` and `cliConfiguration`, and that driver must advertise
process-group cancellation. Every other combination throws
`.descriptorMismatch` before dispatch. Both production adapters store the
exact descriptor and return it only after exact profile ID/kind validation;
they never recompute a descriptor.

### 24.3 Canonical predecessor identity and durable recovery authority

`EngineExecutionRequest` gains `predecessorExecutionId: String?` in its stored
fields, CodingKeys, canonical builder, decoder, rehydration, request JSON/hash,
and replay comparison. The value is the exact caller claim already validated
by `EngineExecutionRequestFieldsV1`; it is never replaced by a latest-session
lookup. Two distinct predecessors that happen to reference the same session
remain distinct request identities.

The legacy `sessionSelection` seam may remain only on package test/direct F1B
initializers. It and `predecessorExecutionId` are mutually exclusive. F1D
product callers use only predecessor ID, and final source gates require zero
product caller of the legacy selection.

`Kernel/Orchestrator.swift` owns:

```swift
package typealias EngineExecutionTransportResolveV1 =
    @Sendable (EngineExecutionRequest) async throws
        -> EngineExecutionTransportV1

package actor EngineActiveExecutionRegistryV1 {
    package func register(
        executionId: String,
        cancel: @escaping @Sendable () async throws -> Void
    ) throws
    package func cancel(executionId: String) async throws
    package func remove(executionId: String)
}
```

`EngineExecutionCoordinatorV1` adds exactly `transportResolver` and
`activeExecutions` to its stored fields and initializer. Execute registers the
one live adapter/process cancel closure before consuming its stream and removes
it only after pipes, Board server, temp config, workspace lease, and terminal
reconciliation finish. `cancel` uses this registry; unknown/nonlive execution
fails rather than pretending success. `recover` obtains a fresh transport from
the injected resolver for each authoritative Store directive; it never uses a
global, profile-kind branch, nil driver, or hidden process registry. The
transport resolver must return context/workspace requests and exactly one
driver plus the CLI configuration required by §24.5.

The three production built-ins remain `.nonReplayable`. Tests that exercise a
future replay directive must inject a distinctly test-owned adapter descriptor
with `.idempotencyKeyed`; tests of `.startPrepared` keep the execution prepared.
No production descriptor is weakened to make recovery tests pass.

### 24.4 Async, fully reconstructible context

The unique dependency loader is async-capable, so the final resolver surface is:

```swift
package func assemble(
    _ request: EngineContextResolveRequestV1
) async throws -> EngineResolvedContextTransportV1

package func reload(
    _ request: EngineContextResolveRequestV1
) async throws -> EngineResolvedContextTransportV1
```

All callers await it. `assemble` and `reload` share one strict rebuild core and
never echo caller JSON. In addition to §18.3's source shapes,
Companion/tool-definition source bytes are frozen as the canonical object:

```text
{schemaVersion,id,name,rolePrompt,toolsJson,
 toolDefinitions:[{name,description,inputSchema}]}
```

`toolDefinitions` are sorted by UTF-8 name, are exact-key values returned by
the injected loader, and must match the sorted unique tool names used by the
packet and instruction ref. Companion, Card, Workspace, instruction, answered
request, memory, handoff, and card-return refs are closed; every required
source is consumed exactly once.

`EngineAnsweredRequestContextV1` encodes a finite, in-range Date as checked
`Int64((seconds * 1000).rounded(.towardZero))`; it does not require the source
Date already to be an exact millisecond. Decode restores exactly that
millisecond. GRDB reload, test golden construction, and ref hashing all use the
same rule.

The 068/069/076/080 tests share one internal
`P1F1DCanonicalExecutionFixture` owned by the existing allowlisted
`EngineExecutionStoreTests.swift`. It creates real canonical UUIDs and the
actual Camp→Squad→Mission→Card, assigned Companion, runtime profile, absolute
no-follow workspace, outcome contract, and optional answered request. Its
independent golden references are:

- Card input: canonical `{id,missionId,title,descriptionText,expectedOutput,
  dependsOnJson,maxTurns,tokenBudget}`, version 1;
- answered input: `EngineAnsweredRequestContextV1`, version 1;
- Companion resource: the exact Companion/tool-definition object above,
  version 1;
- Workspace resource: `EngineWorkspaceIdentityV1`, version 1, whose hash is
  also the `EngineWorkspaceRefV1.hash`;
- instruction: canonical `{schemaVersion:1,outcomeContract,autonomy,
  contextPacketRenderVersion:1,toolNames:[sorted unique]}`, keyed by contract ID
  and using the contract version.

Every ref hash is SHA-256 of independently canonicalized source bytes. Packet,
scope, envelope, context request, workspace request, fields, Store, and
coordinator all use those same real rows. Identity 080 starts with Card + one
answer input, then Card + two answers; Companion/Workspace/instruction refs
remain byte-identical while context bytes/hash change and session scope remains
unchanged. Empty-ref, forged-ref, raw-time, non-UUID squad, `/workspace`, or
nil-assignee fixtures are invalid evidence.

### 24.5 Complete CLI runtime inputs and session-specific parser

`Loop/CliEngineAdapter.swift` owns:

```swift
package struct CliEngineRuntimeConfigurationV1: Sendable, Equatable {
    package let command: String
    package let sandbox: String
    package let reasoningEffort: String
    package let bridgeExecutablePath: String
    package let boardSocketDirectory: URL?
    package let claudeConfigDirectory: URL
    package let ranchSessionId: String
}

package typealias ClaudeCliEventParserFactoryV1 =
    @Sendable (_ expectedSessionId: String) throws
        -> ClaudeCliEventParserV1
```

The configuration initializer takes the listed fields in order, performs no
I/O/clock/ID/environment access, requires nonempty command/reasoning/bridge,
`sandbox` exactly `read-only` or `workspace-write`, absolute base-free file
URLs, and repository-canonical UUID ranch session bytes.
`EngineExecutionTransportV1` adds `cliConfiguration` and validates the same
one-driver/config matrix as §24.2. Coordinator copies it unchanged and requires
its command to equal the selected registry help snapshot command.

Final `CliEngineAdapter` field/initializer order is `profile, descriptor,
processDriver, configuration, commandBuilder, codexParser,
claudeParserFactory, sanitizer, context, workspace, terminalSink,
boardTerminalSink, progressSink`. Claude parser expected ID is the configured
ranch UUID for first execution and the exact external ID in `request.sessionRef`
for resume; execute constructs one parser per invocation and never normalizes or
regenerates the resume ID.

Each execute validates request/profile/descriptor, creates one Board socket URL
and token, binds exact `request.cardId`, uses exact sorted Board tool names
`ask_user,block_card,complete_card,progress_note`, derives Claude config URL as
`claudeConfigDirectory/agentloop-<executionId>.mcp.json`, renders prompt only
from resolved context, and passes the same three Board locals to both command
input and launch request. Provider stream yields payloads only. Stderr/raw
errors never enter payload, terminal, trace, log, or persisted bytes. Provider,
parser, process, EOF, and cancel map only through the closed sanitizer. An EOF
or provider result without a Board terminal attempts protocol failure; a prior
Board winner permits only the existing duplicate-terminal error.

### 24.6 Mechanics-only CLI process and checked Board shutdown

The final process protocol adds truthful mechanics support:

```swift
package protocol CliProcessDrivingV1: Sendable {
    var supportsProcessGroupCancellation: Bool { get }
    func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error>
    func cancel(
        executionId: String
    ) async throws -> CliProcessExitEvidenceV1
}
```

The final backend stores no DB/Card/Run/Mission/profile/artifact authority and
has only this initializer:

```swift
package init(
    terminationGrace: Duration = .seconds(5),
    killGrace: Duration = .seconds(2),
    pipeDrainGrace: Duration = .seconds(1),
    registry: ShellProcessRegistry = .shared
) throws
```

It uses `posix_spawnp` with `POSIX_SPAWN_SETPGROUP`; parent Board server starts
before child launch; cwd is exact workspace; pid equals pgid. Cancel records a
pending intent even before process registration, signals `-pgid` TERM, waits
the exact injected grace, sends KILL only if still alive, then drains/closes
pipes, waits/reaps, requires `kill(-pgid,0)==ESRCH`, synchronously stops the
Board server, unlinks the exact socket, and removes every exact
`spec.cleanupURLs` entry. Any uncertain cleanup is a visible error. Legacy
`CardExecutionBackend`, DB initializer, `run(context:)`, profile/command/socket
fields, `CliBackendPolicy`, and `CliOutputParser` process authority are removed.

`BoardToolServer` adds `package func stop() throws`; it synchronously stops and
wakes listener/connection and unlinks its exact socket, propagating failure.
Deinit is non-authoritative cleanup only. The backend must explicitly call
`try stop()`. Final server/BoardTools retain only the typed sink surfaces of
§20.3; all DB/legacy executor/terminal shadow overloads are deleted. Accepted
complete text is exactly `Card completed.` and sink rejection remains exactly
`Board intent rejected.`.

### 24.7 DB-free ModelLoop/CardRunner

`Loop/CardRunner.swift` owns:

```swift
package typealias ModelLoopCapabilityToolsResolveV1 =
    @Sendable (
        _ request: EngineExecutionRequest,
        _ workspaceURL: URL
    ) throws -> [ExternalTool]
```

The final `CardRunner: ModelLoopExecutionDrivingV1, Sendable` initializer takes
`provider`, that resolver, `maxTurns`, `maxTokensPerTurn`, `retryDelays`, and
`turnTimeout` in the existing defaults/order. It stores no AppDatabase,
artifact root, Card/Run/Mission authority, and has no legacy `run(cardId:)`.
It constructs the four Board handlers only from injected sinks, merges the
resolver's already-authorized capability tools, rejects duplicate names and
Board-name replacement, builds AgentLoop from resolved context/workspace,
yields payloads, sends terminal only through a terminal sink, and keeps only a
Task cancel registry. `ModelLoopEngineAdapter` validates request/descriptor,
delegates to that driver, and forwards payloads; cancel delegates to the driver.

### 24.8 External-effect-unknown terminal topology

The F1D sanitizer's exact reason remains
`engine_external_effect_unknown`. `EngineTerminalCommitReceiptV1` accepts any
otherwise-valid safe reason code for `.committedProposal + .blocked +
.externalEffectUnknown`; it does not hard-code the older literal
`external_effect_unknown`. This subtype always emits urgent attention and
exactly two domain events. `commitEngineTerminal` sets `attention: true` for
that subtype and false for ordinary terminal proposals. Existing recovery
reason bytes remain valid. Proposal/receipt/event count, result hash, and replay
graph must agree or the whole command rolls back.

### 24.9 Compatibility boundary and immutable-red corrections

The allowlist adds only:

```text
Sources/AgentLoopTestSuite/AskUserTests.swift
Sources/AgentLoopTestSuite/McpTests.swift
Sources/AgentLoopTestSuite/ShellToolTests.swift
Sources/AgentLoopTestSuite/WebSearchTests.swift
```

These tests migrate to the final sink-only BoardTools, DB-free CardRunner tool
resolver, approval/coordinator shell authority, and resolver-based web-search
tool assembly respectively. `ApprovalGateTests`, `CardRunnerTests`, and
`CliBackendTests` are already allowlisted and migrate their helpers to the final
transport/driver/mechanics surfaces. No legacy DB/backend overload is retained.

Before capturing the immutable red, tests make only these harness corrections:

- add `try` to every throwing registry initializer;
- give 062 exactly one driver matching each profile kind;
- use the shared full canonical fixture in 068/069/076/080;
- canonicalize answered timestamps and assert the full base ref set;
- make 076's recovery branch prepared or use an explicitly test-owned future
  idempotency descriptor;
- add the missing `await` at 069's async database read and missing `return` in
  the 071 request helper;
- change adapter/fake streams and 067 helpers to payload element type.

These are not accepted as red failures. After those corrections, the exact
§18.1 mapping remains 19 discovered / 19 started / 19 failed, with each first
issue its listed temporary unavailable capability. Compile/setup/context/
workspace/timestamp/fixture faults invalidate the red. Product success work
begins only after that immutable log and contains zero unavailable scaffold
symbols.

### 24.10 One implementation and acceptance order

Implementation order is fixed:

1. request predecessor identity, payload stream, throwing registry/catalog,
   truthful runtime, router durable usage, and receipt topology;
2. strict async context resolver and workspace resolver;
3. shared terminal/progress sinks and manifest resolver;
4. process mechanics, checked Board server, final BoardTools;
5. CLI command/parser/help/sanitizer and Cli adapter;
6. DB-free CardRunner/ModelLoop adapter;
7. coordinator execute, active cancel, and exhaustive restart recovery.

The invariant order is `context/workspace resolve -> Store begin transaction ->
persisted-capability registry recheck -> dispatch CAS -> only startNow makes an
adapter -> router -> Store`. Completed terminal is `manifest read -> router
accept -> proposal transaction -> optional prepare -> terminal transaction`.
Recovery is `Store scan -> descriptor/context/workspace revalidation -> exact
prepare/start/resume/replay/cancel branch`; deletion deferral remains untouched
for F2.

Gates remain 062–070, 071+079, 072–075, 076, 077–078, 080, exact 001–080,
authoritative full `swift run RunTests`, source/privacy/boundary gates, App
build, and packaged preview. No focused green is F1D or P1-F1 acceptance by
itself.

## 25. Revision 7 — transient recovery-session authority closure

Revision 7 is the one bounded plan-only successor opened by the step-7
future-green audit. It closes the crash window in which a CLI execution binds
its first provider session, persists that binding, and then restarts while the
canonical execution request correctly still has `sessionRef == nil`. Revision
7 overrides only the conflicting runtime/session-recovery clauses in
§§24.2–24.6 and the existing `sessionBound` acceptance branch. Revisions
5–6 remain controlling everywhere else.

The pre-Revision-7 prefix is exactly 205,269 bytes / SHA-256
`604526003684189eeecda8ecc291734154dc3d6948b16243f1c840657e146486`.
The existing `scope-allowlist.txt` remains byte-for-byte unchanged at SHA-256
`9184ba618c4d21f1a96eeecd7e533285793dba1e72a145d39dfd9cdd4ea9a2cb`.
The NUL-safe outside boundary remains exactly 586 nodes / SHA-256
`6581154ebc21bbec06c718173e3cbb7bb76b57bf8a079772d9ed29a934d5c49e`;
this allowlisted plan append changes neither its membership nor bytes.
Revision 7 adds no path, identity, schema, migration, dependency, durable DTO,
request byte, receipt byte, EventKind, provider login/network action, F1E, F2,
or P2 behavior. No product/test implementation of this successor opens until
an independent responsibility-isolated successor appended to Review01d reports
`APPROVED — 0 P0 / 0 P1` for Revision 7.

### 25.1 Canonical request remains the sole durable request identity

`EngineExecutionRequest.sessionRef`, `requestJson`, and `requestHash` retain
their Revision-6 meanings and bytes. A first provider call therefore persists
`sessionRef == nil` even after its matching `sessionBound` event creates and
binds an `EngineSessionRecord`. Recovery never rebuilds, clones, patches, or
re-encodes that request with a later session reference. The exact persisted
request returned on an `EngineRecoveryDirectiveV1` is the exact request passed
to the adapter on restart.

The recovery-only session authority is an ephemeral
`EngineSessionReferenceV1` obtained from Store immediately before adapter
construction. It is not added to `EngineExecutionTransportV1`, context,
workspace, request JSON/hash, proposal, terminal receipt, domain-command
payload/result, audit metadata, or logs. The external session ID continues to
appear only where the pre-existing protocol already requires it: the durable
`EngineSessionRecord`, the existing `sessionBound` event payload, and the
provider resume argv/parser state. No new encoding or diagnostic copy is
authorized.

### 25.2 Exact Store-resolved recovery session

`Database/EngineExecutionStore.swift` owns this final read-only package
surface:

```swift
package func resolveRecoverySessionReference(
    executionId: String,
    requestHash: String,
    sessionId: String,
    externalSessionId: String
) throws -> EngineSessionReferenceV1
```

The method validates canonical execution/session UUIDs, the lowercase request
hash, and the bounded external ID before one database read transaction. It
then requires exactly one nonredacted running execution whose ID/requestHash
match the arguments, whose dispatch state is `sessionBound`, and whose
`sessionId` equals the exact argument. It rehydrates and validates the
unchanged canonical request. It loads exactly that active, nonredacted session
and requires exact Camp, profile, adapter ID/version, workspace hash, session
scope JSON/hash, and external ID equality with the execution/request and the
four arguments. If the persisted request already has `sessionRef`, both its
session ID and external ID must be byte-equal to the resolved value.

The Store resolves the current runtime profile through its existing descriptor
authority with sorted unique
`request.requiredCapabilities + [.sessionResume]`. The resulting descriptor
must match the execution adapter ID/version and profile kind, must be a
`cliCodex` or `cliClaude` descriptor, and must publish `.supported` for
`.sessionResume`. ModelLoop/API/OAuth, missing/conditional/unsupported resume,
profile or descriptor drift, and any row/request/session mismatch fail before
the returned DTO. Existing typed selection/descriptor errors remain visible;
session/request-row mismatch throws `EngineSessionScopeMismatchError`.

This method reads no clock, creates no ID, and performs no insert/update/delete,
event, receipt, outbox, audit, log, adapter factory, process, filesystem, or
network action. All validation precedes return. A drift failure therefore has
zero Store writes and zero adapter/process construction.

### 25.3 Final runtime and adapter signatures

`Domain/ExecutionEngine.swift` adds exactly one field to the final runtime,
after `workspace` and before the three sinks:

```swift
package struct EngineAdapterRuntimeV1: Sendable {
    package let descriptor: ExecutionEngineDescriptor
    package let context: EngineResolvedContextTransportV1
    package let workspace: EngineResolvedWorkspaceV1
    package let resolvedSessionRef: EngineSessionReferenceV1?
    package let terminalSink: any EngineTerminalSink
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package let modelLoopDriver: (any ModelLoopExecutionDrivingV1)?
    package let cliProcessDriver: (any CliProcessDrivingV1)?
    package let cliConfiguration: CliEngineRuntimeConfigurationV1?

    package init(
        descriptor: ExecutionEngineDescriptor,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        modelLoopDriver: (any ModelLoopExecutionDrivingV1)?,
        cliProcessDriver: (any CliProcessDrivingV1)?,
        cliConfiguration: CliEngineRuntimeConfigurationV1?
    ) throws
}
```

Every normal execute and every recovery branch except `.resumeSession` passes
literal `nil`. A nonnil value is valid only for the existing exact CLI runtime
matrix, with a CLI descriptor whose `.sessionResume` support is `.supported`.
The ModelLoop runtime matrix requires nil and rejects a nonnil value with
`.descriptorMismatch`. No initializer overload/default may omit, derive, or
persist the new argument.

`Loop/CliEngineAdapter.swift` adds exactly one stored field
`resolvedSessionRef: EngineSessionReferenceV1?` after `workspace` and the same
required initializer argument after `workspace`. Its final stored-field order
is therefore `profile, descriptor, processDriver, configuration,
commandBuilder, codexParser, claudeParserFactory, sanitizer, context,
workspace, resolvedSessionRef, terminalSink, boardTerminalSink, progressSink`.
The registry's CLI factories copy `runtime.resolvedSessionRef` unchanged into
that argument. `ModelLoopEngineAdapter` gains no session field; runtime
validation rejects the value before its factory can construct an adapter.
`ExecutionEngineAdapter`, `EngineExecutionTransportV1`, the process request,
and both driver protocols remain byte-for-byte unchanged.

### 25.4 One effective CLI session and matching provider evidence

Before socket/token/config creation, command building, process launch, Task
creation, or provider I/O, `CliEngineAdapter.execute` computes one effective
session reference with this exhaustive rule:

| canonical `request.sessionRef` | transient `resolvedSessionRef` | result |
|---|---|---|
| nil | nil | first-call mode |
| value | nil | that canonical request value |
| nil | value | that Store-resolved recovery value |
| value A | byte-equal value A | value A |
| value A | different value B | throw `EngineSessionScopeMismatchError` before any external effect |

A nonnil effective reference additionally requires a CLI descriptor with
`.sessionResume == .supported`. The adapter never writes the effective value
back into the request. Codex and Claude resume argv use only its exact
`externalSessionId`; Claude's per-execution parser factory expects that same
ID. For Codex, a `thread.started` ID in resume mode must equal it before a
payload is yielded. For Claude, both init and result IDs retain the same exact
check. Any mismatching provider session evidence follows the existing
sanitized protocol-violation terminal path; raw IDs/errors gain no diagnostic
or log channel.

On first-call mode, Codex retains its exact first `thread.started` binding and
Claude retains the configured ranch UUID authority. On resume mode, every
provider `sessionBound` payload must equal the effective external ID. The
adapter emits no normalized, regenerated, fallback, latest-session, or
second-source value.

Store remains the second defense when accepting a routed `sessionBound` event.
Its existing first-bind branch remains: `started` plus nil execution session
binds or exact-resumes the request's canonical session. It adds one exhaustive
already-bound branch: when dispatch state is `sessionBound` and execution
`sessionId` is nonnil, Store loads that exact active/nonredacted session,
requires the same Camp/profile/adapter/version/workspace/scope identity and
requires its external ID to be byte-equal to the event. It does not bind,
replace, reopen, or update the session; only the existing accepted-event
transaction advances sequence and records the matching protocol event. A
mismatch fails before that transaction with zero event/receipt/outbox/legacy
or projection write. Every other state/session combination retains the
existing fail-closed behavior.

### 25.5 Coordinator recovery flow

Normal `EngineExecutionCoordinatorV1.execute` always constructs runtime with
`resolvedSessionRef: nil`, including a normal predecessor continuation whose
canonical request already contains its exact `sessionRef`.

For `.resumeSession(sessionId, externalSessionId)` only, restart recovery uses
this fixed order:

1. require the directive's exact canonical request and matching execution ID;
2. obtain its fresh `EngineExecutionTransportV1` and reload exact context and
   workspace;
3. select the current registry descriptor using sorted unique persisted
   required capabilities plus `.sessionResume`, and require exact CLI,
   adapter/version/profile, and supported-resume equality;
4. call `store.resolveRecoverySessionReference` with the directive execution
   ID, unchanged request hash, exact directive session ID, and exact directive
   external ID;
5. construct the one runtime with that returned value, then the one adapter;
6. execute the unchanged canonical request through the existing durable router
   sequence/usage and Store path.

The Store resolver deliberately runs after the injected transport resolver and
context/workspace reload, so test-injected or real drift during those steps is
observed immediately before adapter construction. No adapter, Board server,
socket, command/config, process, provider, event, proposal, or terminal write
occurs on failure. There is no retry with a latest session and no fallback to
first-call mode. `.startPrepared`, `.replayExecution`,
`.cancelAndReconcile`, `.prepareAndCommitProposal`, and normal execute pass nil;
`deferCampDeletion` remains untouched for F2.

### 25.6 Existing identities, source gates, and implementation order

Revision 7 adds no test identity and does not change the already-valid
immutable 062–080 red or any first-unavailable mapping. After its independent
plan successor approval, implementation resumes before Revision-6 step 7 in
this exact order:

1. add the Store resolver, already-bound `sessionBound` validation branch, and
   required runtime field; mechanically pass nil at every non-resume runtime
   construction;
2. add the CLI effective-session rule and provider evidence checks;
3. strengthen existing identity 067 for a canonical request with nil
   `sessionRef` plus a transient recovery reference, equal dual-source
   acceptance, mismatched dual-source zero launch, exact resume argv/parser,
   unchanged request JSON/hash, and ModelLoop nonnil rejection;
4. implement coordinator `.resumeSession` injection and strengthen existing
   identity 076 with a test-owned idempotency-keyed, resume-supported CLI
   execution that first binds from a nil-session request, restarts, captures
   the exact runtime reference, reports the same `sessionBound`, and reaches
   one terminal;
5. in identity 076 inject external-ID, session-ID, request-hash,
   scope/workspace, profile, and adapter/version drift from the transport
   resolver after Store scan; require the exact typed failure, factory/process
   counts zero, and no Store write beyond the deliberate fixture mutation;
6. rerun the unchanged Revision-6 step-7 coordinator, cancel, and exhaustive
   recovery implementation, then all existing acceptance gates.

Final source/privacy gates add: exactly one `resolvedSessionRef` field in
`EngineAdapterRuntimeV1` and `CliEngineAdapter`; no field or symbol in
`EngineExecutionTransportV1`, ModelLoop, process, Board, context/workspace,
request/receipt Codable keys, or logs; one Store resolver call only in the
`.resumeSession` coordinator branch; normal runtime construction passes
literal nil; no request clone/re-encode/mutation; no latest-session query or
profile-kind fallback; exact dual-source equality; and no compatibility
overload/default preserving an unverified recovery session. Existing exact
001–080, full `swift run RunTests`, Core/App builds, privacy/source/boundary
checks, packaged preview, and independent 0 P0/P1 implementation review remain
mandatory. A focused 067/076 green is not F1D acceptance.

The Revision-7 removal gate is explicit: before its green evidence, delete any
temporary recovery request clone, request/session mutation, second recovery
session DTO, transport/config session field, legacy runtime initializer, or
adapter fallback introduced while migrating call sites. No new unavailable
scaffold is authorized; the Revision-6 temporary unavailable vocabulary still
reaches zero under its existing final gate.

## 26. Revision 8 — production composition, ready-event causality, and engine-first recovery

This is a plan-only successor to the approved Revision 5–7 chain. It closes the
last production gap exposed after the Revision-7 focused greens: the Store,
coordinator, adapters, Board bridge, artifact graph, context resolver, and
workspace resolver are individually implemented, but the live Orchestrator
still constructs a removed `CardExecutionBackend` by `profile.kind.isCLI`.
Revision 8 replaces that branch with one production composition. It does not
add a schema, migration, dependency, event kind, focused identity, F1E/F2
behavior, UI feature, or approval protocol. All nonconflicting Revision 5–7
contracts remain controlling.

The immutable prefix through §25 is exactly 219,330 bytes with SHA-256
`b66293455f50bae1b9c9ad4888d53b6411a9c2be3bf879df6147a3e9b29b5cec`.
Before this append the effective allowlist is 103 sorted unique LF-terminated
paths with SHA-256
`9184ba618c4d21f1a96eeecd7e533285793dba1e72a145d39dfd9cdd4ea9a2cb`;
Review01d is 36,964 bytes with SHA-256
`ed9c8a46e46bafca72a73f395e1f51b6968030404c01fa8a03c209b5d0f847c8`.
The live NUL-safe boundary is dirty `671`, allowlisted present `85`, outside
`586`, outside-manifest-v1
`6581154ebc21bbec06c718173e3cbb7bb76b57bf8a079772d9ed29a934d5c49e`.

Revision 8 adds exactly three existing dirty paths and three implementation
paths to the allowlist, and no seventh path:

```text
Sources/AgentLoopCore/Database/ApprovalGrantStore.swift
Sources/AgentLoopCore/Observability/ContextDependencyLoader.swift
Sources/AgentLoopCore/Support/StateDirectoryLock.swift
Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift
Sources/AgentLoopBoardBridge/main.swift
scripts/package-app.sh
```

The resulting 109-line allowlist has SHA-256
`83db82562cd412e32a6920e222e3dfbafab24a63ebc2fa6a6d3b984e01061e53`.
The boundary becomes dirty `671`, allowlisted present `88`, outside `583`,
outside-manifest-v1
`1a19caaa14031b57885af39af6c8bd55d31ef6fe312d86c92ffdb7ab4dd80690`.
`ApplicationWorkflowTests.swift`, `KernelDefaults.swift`, and
existing tests outside the list remain outside: allowlisted tests cover the
changed startup/rework and dependency contracts, and existing constants are
read-only.

### 26.1 Current ready event is the sole dispatch cause

Every transition whose committed result is `Card.status == .ready` must end its
same SQLite transaction by appending a `card_ready` event for that Card. The
event must be later in rowid order than any `card_interrupted`, `card_returned`,
`user_request_answered`, or `approval_decided` event written by the same
operation. The following missing writers are corrected without a new event
kind:

- `AppDatabase.createSingleCardMission` appends `card_ready` with `{}` after
  `mission_created`;
- `AppDatabase.answerUserRequest` writes `user_request_answered`, then optional
  `approval_decided`, and only then appends the unique final `card_ready`;
  nonapproval uses `{"answeredRequest": UUID}` and approval uses `{}`;
- `AppDatabase.returnCardForRework` appends `card_ready` with `{}` after the
  existing exact `card_returned` payload;
- legacy `Orchestrator.adoptOrphans` appends `card_ready` with `{}` after
  `card_interrupted`, but only for a genuinely legacy non-engine Run; and
- `ApprovalGrantStore.answerApprovalRequest` appends `card_ready` with `{}`
  after `user_request_answered` and `approval_decided`.

The existing dependency/manual retry `{}`, non-approval
`{"answeredRequest": UUID}`, and engine-cancel
`{"executionId": UUID, "reasonCode": String-or-null,
"terminalKind": "canceled"}` shapes remain valid. These are the only three
accepted canonical `card_ready` payload shapes; exact-key validation rejects
extra or missing keys, a noncanonical UUID, a noncanonical JSON byte sequence,
or any other terminal kind. No old `card_interrupted`, `card_returned`,
`approval_decided`, current Card status, wall clock, Card ID, latest Run, or
latest execution may be substituted as an idempotency cause. An already-ready
legacy row with no valid current `card_ready` fails visibly and is suppressed
for the process session; Revision 8 does not invent a migration-time cause.

Add these exact package declarations in an already-allowlisted owner:

```swift
package struct EngineCardReadyCauseV1: Sendable, Equatable {
    package let eventId: String
    package let idempotencyKey: String
    package let answeredRequestId: String?
    package let causalPredecessorExecutionId: String?
}

package struct EngineCardReadyObservationV1: Sendable, Equatable {
    package let cardId: String
    package let cardStatus: CardStatus
    package let latestTransitionEventId: String?
    package let latestTransitionKind: String?
}

package enum EngineCardReadyCauseErrorV1:
    Error, Sendable, Equatable
{
    case missingCurrentReadyEvent(EngineCardReadyObservationV1)
    case malformedReadyEvent(
        observation: EngineCardReadyObservationV1,
        eventId: String
    )
    case ambiguousAnsweredRequest(
        observation: EngineCardReadyObservationV1,
        requestId: String
    )
    case brokenPredecessorGraph(
        observation: EngineCardReadyObservationV1,
        requestId: String
    )
}
```

`AppDatabase.resolveEngineCardReadyCause(for:in:)` runs inside the same
reconcile write transaction that materializes a dispatch candidate. It selects
the rowid-latest Card transition event among `card_started`, `card_completed`,
`card_blocked`, `card_ready`, `card_canceled`, `card_interrupted`, and
`card_returned`, and requires that row to be the exact current `card_ready`.
The idempotency key is exactly
`"engine.execution.v1:" + event.id`. Re-reading the same event produces the
same key; every new ready transition produces a new execution identity.

Only the one-key answered-request payload may yield a causal predecessor. The
exact `user_request` must be answered, nonapproval, nonredacted, same-Card, and
have canonical answer/date fields. Decode all same-request
`user_request_created` events and require zero or one exact match. Each match
must have exactly the canonical payload keys `kind`, `prompt`, and
`userRequestId`; the request ID is byte-equal, the event is same-Card, and its
Run ID is nonnil. Zero means a legacy question and nil predecessor. One must
carry a nonnil exact Run ID; load that Run and the unique
`engine_execution.runId`. A present engine execution must be same-Card,
terminal, nonredacted, `.blocked`, and
`.needsHumanInput`; otherwise the graph is broken and dispatch fails before an
engine write. No query orders or filters by latest session/execution.

`DispatchCandidate` carries this cause. Resolution first snapshots the Card
status and rowid-latest transition event ID/kind into
`EngineCardReadyObservationV1`; every failure carries that exact observation.
Cause failure writes only the existing sanitized kernel diagnostic/visible
failure, suppresses only while the current observation remains byte-equal, and
leaves engine_execution/Run/command/event/proposal/session counts unchanged.
Reconcile always rereads the observation before honoring suppression. A new
ready event therefore changes the observation and may retry in the same
process; App restart also clears suppression. The same unchanged bad
observation never spins each reconcile tick.

### 26.2 One context/workspace preparation core and one tool truth

The current resolvers validate a caller-prebuilt claim but expose no production
builder. Add these transient, non-Codable values and operations in the existing
owners:

```swift
package struct EngineCapabilityToolPlanV1: Sendable {
    package let logicalDefinitions: [ToolDef]
    package let modelLoopDefinitions: [ToolDef]
    package let cliDefinitions: [ToolDef]
    package let requiresWorkspaceWrite: Bool
    package let makeCapabilityTools:
        @Sendable (_ workspaceURL: URL) throws
            -> EngineBoundCapabilityToolsV1
}

package struct EngineBoundCapabilityToolsV1: Sendable {
    package let logicalDefinitions: [ToolDef]
    package let capabilityTools: [ExternalTool]
}

package struct EngineContextToolBindingV1:
    Codable, Sendable, Equatable
{
    package let logicalName: String
    package let providerVisibleName: String
}

package enum EngineContextToolNamespaceV1: Sendable, Equatable {
    case modelLoop
    case ranchMCP
}

package struct EnginePreparedContextVariantV1: Sendable {
    package let request: EngineContextResolveRequestV1
    package let resolved: EngineResolvedContextTransportV1
    package let namespace: EngineContextToolNamespaceV1
    package let toolBindings: [EngineContextToolBindingV1]
}

package struct EnginePreparedContextV1: Sendable {
    package let modelLoop: EnginePreparedContextVariantV1
    package let cli: EnginePreparedContextVariantV1
    package let profile: RuntimeProfileRecord
    package let contract: OutcomeContractRef
    package let companionId: String
    package let companionModel: String
    package let companionModelPolicy: CompanionModelPolicy
    package let autonomy: MissionAutonomy
    package let cardMaxTurns: Int
    package let cardTokenBudget: Int
    package let capabilityTools: EngineCapabilityToolPlanV1
}

package struct EnginePreparedWorkspaceClaimV1: Sendable {
    package let request: EngineWorkspaceResolveRequestV1
    package let workspace: EngineWorkspaceRefV1
}
```

`EngineContextTransportResolverV1.dependencyLoader` becomes
`any ContextDependencyLoading`. Its new
`prepareCurrent(campId:cardId:companionId:)` and
`reloadPrepared(_ persistedRequest:)` operations, plus existing
`assemble`/`reload`, delegate to one private graph/dependency derivation core.
The core retains the existing before/async-load/after snapshot comparison and
returns the exact profile, companion model policy, contract, limits, autonomy,
and handlers from that same snapshot. It derives both context variants from
the same immutable source: ModelLoop uses bare logical tool names; CLI maps
every logical name exactly to `mcp__ranchboard__<logical-name>`. The mapping is
injective, UTF-8 sorted, and rejects a logical name already containing the
provider prefix. `reloadPrepared` rebuilds both and requires the persisted
claim to equal exactly the variant selected by the captured factory. No caller
re-encodes a Card, answer, instruction, tool, or workspace row.

`EngineWorkspaceResolverV1.prepareCurrent(cardId:campId:)` derives the exact
claim with the same private identity core used by `resolve`. It acquires and
releases its temporary security scope before returning; the coordinator later
acquires the one execution lease from the returned request and owns it through
adapter/process/Board/config/artifact/terminal cleanup.

The capability plan is closed and deterministic. The four Board logical names
are exactly, in order, `complete_card`, `block_card`, `add_progress_note`, and
`ask_user`; this Revision 8 name set overrides the older CLI-only
`progress_note` spelling. Selected non-Board capability definitions follow in
UTF-8 name order. Logical definitions and handlers are one source; the two
namespace arrays are mechanical renames of that same source. Each variant
stores the complete ordered bindings: ModelLoop uses
`logicalName == providerVisibleName`, while CLI uses
`providerVisibleName == "mcp__ranchboard__" + logicalName`.
`ContextPacket` preserves its existing public `[String] toolNames` initializer
as a source-compatible identity-binding entry: it maps each name to
`logicalName == providerVisibleName` and delegates to a new package initializer
with the otherwise same arguments plus
`toolBindings: [EngineContextToolBindingV1]`. Only the engine resolver uses the
package binding initializer. `EngineInstructionContextSourceV1` canonically
encodes exactly the sorted-key object
`{schemaVersion:2,outcomeContract,autonomy,contextPacketRenderVersion:2,
toolBindings:[{logicalName,providerVisibleName}]}` with the bindings in their
already frozen order and no `toolNames` key. The instruction ref therefore commits
the bindings into the context envelope hash without adding a second envelope
field. All capability
and safety decisions use only `logicalName`; every rendered tool invocation in
the prompt uses the corresponding `providerVisibleName`, including
complete/block/progress/ask/file/write/web names. The request context
JSON/hash, instruction source, Companion resource hash, and transport-visible
definitions all use that exact selected variant. Definition/binding/handler
bijection for non-Board capability tools fails before Store begin; the four
Board definitions/bindings are checked pre-begin but their sink-bound handlers
are checked after `.startNow` as specified below. A CLI prompt must never
instruct the model to call a bare logical name.

The former exact schema-1 instruction object with
`contextPacketRenderVersion:1` and `toolNames:[String]` is decode-only evidence;
new prepare never emits it. A nonredacted running engine execution whose
persisted context contains schema 1 cannot be truthfully rebound to the new CLI
namespace/handler authority, so startup recovery halts with the fixed sanitized
context preflight failure before any legacy adoption or external dispatch. It
never rewrites the request/context hash or guesses identity bindings. This is a
visible compatibility gate, not a fallback.

- selected `list_dir`, `read_file`, `web_fetch`, available `web_search`, and
  `search_camp_notes` use their existing read-only handlers;
- selected `write_file` uses the existing workspace handler only for
  `.standard` or `.free`, and sets `requiresWorkspaceWrite=true`;
- under `.careful`, selected `write_file` is represented by a DB-free handler
  that returns the fixed visible `engine_approval_required` tool error;
- selected `run_shell` and every `mcp__` tool use that same DB-free unavailable
  handler in Revision 8 and never call the wrapped handler; and
- a selected required `web_search` with no credential retains the existing
  pre-begin context failure rather than silently disappearing.

Production engine capability assembly has zero references to
`ApprovalGateHandler`, never calls `suspendCardForApproval`, and never creates
an approval user_request. `approvalGrantIds` is exactly `[]`. This is the
conservative F1D boundary: restoring shell/MCP approval requires a later
coordinator-owned typed approval successor, not a DB-writing CardRunner
decorator. The fixed unavailable handler is observable but cannot terminalize
or mutate a Card.

`ContextDependencyLoader` removes its profile-kind-wide rejection of selected
CLI `web_search`/`mcp__` dependencies. `web_search` retains its existing
credential resolution independent of profile kind. Every selected canonical
`mcp__<server>__<tool>` name takes a pure local F1D branch: the loader does not
call `manager.ensureRunning`, `assembledTools`, `tools/list`, or any wrapped
handler. It synthesizes one exact definition with the selected canonical name,
fixed description `Unavailable in F1D engine execution.`, and canonical input
schema
`{"additionalProperties":true,"properties":{},"type":"object"}`; its
paired DB-free handler returns the fixed `engine_approval_required` tool error.
Thus selected MCP manager start/list/call counts are all zero even during
prepare. The closed tool plan above, not `RuntimeProfileKind.isCLI`, decides
whether every other selected handler is real or fixed-unavailable.

Ranch MCP is the only capability-bearing CLI tool channel.
`makeCapabilityTools` returns the full expected logical definitions plus only
selected non-Board real or fixed-error handlers; it cannot manufacture
placeholder Board handlers. Inside the gated consumption Task, `makeTransport`
invokes it exactly once with the resolved workspace and requires the returned
definitions equal the prepared plan and the handler names equal exactly the
non-Board definition suffix. The resulting
`EngineBoundCapabilityToolsV1` is a non-Codable transient field passed without
reassembly through `EngineExecutionTransportV1`,
`EngineAdapterRuntimeV1`, and both adapters. Revision 8 adds this nonoptional
field in the listed order immediately after `workspaceRequest`/`workspace` in
those two value initializers. ModelLoop passes its capability handlers into
CardRunner. CLI passes the same bound value through
`CliProcessLaunchRequestV1` immediately after workspace authority and into
`BoardToolServer`'s initializer immediately after its two sinks. No driver,
adapter, or server may reload or reconstruct capability handlers.

The final process-launch value replaces the old socket-URL surface in one
complete field and initializer order:

```swift
package struct CliProcessLaunchRequestV1: Sendable {
    package let executionId: String
    package let spec: CliCommandSpec
    package let cliExecutableAuthority: CliExecutableAuthorityV1
    package let workspaceURL: URL
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1
    package let boardSocketBasename: String
    package let boardToken: String
    package let boardCardId: String
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
}
```

It has one explicit package initializer in that order. The initializer performs
the existing canonical execution/Card/token/workspace checks, requires the
`spec.command` bytes to equal `cliExecutableAuthority.stagedPath`, and requires
the basename equal the last path component produced by
`BoardToolServer.makeSocketURL(directoryAuthority:executionId:)`, and rejects
slashes or any other basename. The adapter, backend, and server consume these
same values in this order; none accepts an alternate URL, path, tool array, or
side-channel authority. The captured factory/selection, which owns both values,
requires the request authority byte-equal its selected help snapshot authority
immediately before invoking this initializer; the initializer does not reload a
snapshot or compare against an unavailable side channel.

The final server initializer is likewise singular and ordered:

```swift
package init(
    directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
    socketBasename: String,
    token: String,
    cardId: String,
    boardTerminalSink: any EngineBoardTerminalSink,
    progressSink: any EngineProgressSink,
    boundCapabilityTools: EngineBoundCapabilityToolsV1,
    validatePeer: @escaping EngineBoardPeerValidateV1,
    onTerminalAccepted: @escaping @Sendable () -> Void,
    acceptQueue: DispatchQueue,
    handlerQueue: DispatchQueue
) throws
```

The former socket-URL initializer is removed with its allowlisted callers.
This initializer validates only values/tool bijection; bind owns the descriptor
lease and filesystem work.

After `.startNow`,
when coordinator terminal/progress sinks exist, CardRunner and BoardToolServer
mechanically prepend the four exact sink-bound Board handlers and verify the
combined names against `logicalDefinitions`. Runtime handler mismatch is a
typed engine-protocol terminal before any tool call. `BoardToolServer` exposes
authenticated DB-free `tools/list` and `tools/call`, and rejects any other
name. `BoardServerBridgeMain` obtains
the list from that parent socket; it no longer hardcodes four tools. The child
publishes the logical MCP names, while the provider-visible names and context
variant are exactly `mcp__ranchboard__<logical-name>`. Parent list, generated
MCP config, allowed-provider-name list, context definitions, and bridge calls
must form a bijection before launch; mismatch is a typed pre-dispatch failure.

The authenticated parent wire is exact. The child first sends canonical
`hello` with exactly `cardId,token,type`. After byte-equal token/Card checks,
the parent replies with canonical `hello_ok` containing exactly `tools,type`.
`tools` is the UTF-8-name-sorted unique full logical-definition array; every
element has exactly `description,inputSchema,name`, no extra key, and the
encoded response including newline is at most 256 KiB. The bridge validates
canonical JSON, exact keys, count at most 256, unique canonical names, and
schemas before caching that immutable array. MCP `tools/list` returns only
those definitions. Each later parent `tool_call` has exactly
`arguments,cardId,id,name,type`; Card must match and name must belong to the
cached list. Duplicate/unknown keys, post-hello list change, an oversized
frame, or an unlisted call closes the connection with the fixed protocol error
and invokes no handler.

Revision 8 overrides the older CLI argv/config arrays with a closed isolation
template. Codex root-global flags must precede `exec`; exec-global flags and
every config override must precede the `resume` subcommand. The exact first
argv is:

```text
codex -a never -C W -s read-only -m M exec --ignore-user-config --ignore-rules --strict-config --skip-git-repo-check [CONFIG] --json -
```

The exact resume argv is:

```text
codex -a never -C W -s read-only -m M exec --ignore-user-config --ignore-rules --strict-config --skip-git-repo-check [CONFIG] --json resume ID -
```

`[CONFIG]` is the following values in exact order, each emitted through the
existing builder convention as the two tokens `-c`, `value`:

```text
model_reasoning_effort=toml(R)
approval_policy="never"
web_search="disabled"
tools.web_search=false
features.shell_tool=false
features.apps=false
apps._default.enabled=false
features.browser_use=false
features.browser_use_external=false
features.browser_use_full_cdp_access=false
features.in_app_browser=false
features.computer_use=false
features.image_generation=false
features.code_mode=false
features.code_mode_host=false
features.code_mode_only=false
features.plugins=false
features.plugin_sharing=false
features.remote_plugin=false
features.tool_suggest=false
features.workspace_dependencies=false
features.auth_elicitation=false
features.tool_call_mcp_elicitation=false
features.request_permissions_tool=false
features.hooks=false
features.multi_agent=false
features.goals=false
features.memories=false
features.chronicle=false
features.skill_mcp_dependency_install=false
features.guardian_approval=false
features.unified_exec=false
features.shell_snapshot=false
check_for_update_on_startup=false
project_doc_max_bytes=0
instructions=""
developer_instructions=""
skills.include_instructions=false
skills.bundled.enabled=false
include_environment_context=false
include_permissions_instructions=false
include_apps_instructions=false
include_collaboration_mode_instructions=false
projects."<canonical-W>".trust_level="untrusted"
mcp_servers={ranchboard={command=...,args=["--board-server"],env_vars=["AGENTLOOP_BOARD_SOCKET","AGENTLOOP_BOARD_TOKEN","AGENTLOOP_BOARD_CARD_ID","AGENTLOOP_BOARD_TOOLS"],required=true,enabled_tools=[...],default_tools_approval_mode="approve"}}
```

`R` must be exactly one of `minimal,low,medium,high,xhigh` and is emitted as a
TOML string; any other configured value fails before Store begin. The help
snapshot parses root `codex --help`, `codex exec --help`, and
`codex exec resume --help` separately and proves every flag in its actual
scope, including `--skip-git-repo-check`. A non-Git but otherwise valid Ranch
workspace is an accepted fixture for first and resume parsing.

The final pair is one canonical whole-table value, not incremental dotted MCP
keys; its command/args/env-var names and sorted logical enabled tools are the
same frozen Board values. Codex table merge is recursive rather than
replacement, so this is Ranch-only only after the managed-layer emptiness gate
below proves there is no lower-priority server to preserve. Prompt input is represented in argv
only as `--json -`. No inherited MCP, project/user rule, hook, app, memory,
goal, multi-agent, discovered skill catalog, environment/permission/app block,
collaboration instruction, native shell, or native web feature remains enabled
by configuration. Because pinned 0.144.5 still expands an explicit raw
`$<skill-name>` mention even when the catalog block is disabled, Codex
preflight rejects any canonical prompt token matching exact ASCII pattern
`(^|[^A-Za-z0-9_])\$[A-Za-z0-9][A-Za-z0-9_-]{0,63}($|[^A-Za-z0-9_-])`.
That typed context failure occurs before Store begin and does not rewrite or
escape the hashed prompt. `${...}` and a lone dollar are not this syntax.
Codex may still render a nonremovable native tool name such as
`apply_patch`; Revision 8 does not claim model-visible equality for that native
surface. The strict config plus read-only sandbox must make every such native
tool inert, and an attempted native write/shell/web/app effect must fail with
the workspace and external state unchanged.

The staged Codex authority is accepted only when the same bounded process-group
probe returns exact version line `codex-cli 0.144.5` and its help proves the
listed CLI flags. Codex 0.144.5 has no credential-free dry-run that both loads
all feature/MCP config and performs no model/MCP effect; Revision 8 does not
invent one. The keys above are therefore an exact reviewed contract for that
one signed version. Any other version makes only the Codex factory unavailable
until a reviewed successor. Actual launch uses the full config with
`exec --strict-config`; a parse warning/error or failure of the whole-table MCP
replacement is a typed launch/protocol failure and never retries with relaxed
config.

Before registering the Codex factory, the seed's optional
`validateCodexManagedPolicy` closure performs the following exact read-only gate
with the same staged/signed/hash-pinned 0.144.5 authority before registry
creation and again immediately before each actual launch:

- descriptor checks require `/etc/codex/config.toml`,
  `/etc/codex/requirements.toml`, and `/etc/codex/managed_config.toml` be exact
  `ENOENT`; CFPreferences domain `com.openai.codex` keys
  `config_toml_base64` and `requirements_toml_base64` must both be nil;
- bounded `profiles status -type enrollment` must exit zero with exact two
  lines `Enrolled via DEP: No` and `MDM enrollment: No` and no other status;
- the canonical workspace's `config.toml` plus every `.codex/config.toml`
  candidate from that workspace through its repository/tree ancestors must be
  exact `ENOENT`; the workspace remains untrusted and `--ignore-user-config`
  separately excludes the user layer; and
- one bounded stdio `codex app-server --stdio` process receives only
  `initialize`, `initialized`, then matching request
  `{"method":"account/read","id":1,"params":{}}` (`refreshToken:false`). It
  must issue no server request and return exact result keys
  `account,requiresOpenaiAuth`, with `requiresOpenaiAuth:true`; `account` has
  exact keys `email,planType,type`, `type:"chatgpt"`, and `planType:"pro"`.
  Email is only type-checked as nil/string and never retained. The probe is then
  TERM/awaited with the same bounded group cleanup and makes no thread/model/MCP
  request.

All local source identities are sampled before/after the account probe and
must remain equal. Pinned `pro` is a consumer plan for which the 0.144.5 cloud
enterprise-config path is ineligible; Business/Enterprise/Edu/unknown, an
extra/missing JSON key, stderr, timeout, opaque permission, local source, or
identity drift makes only Codex unavailable before Store begin. AppStore can
therefore construct the live closure for a personal Pro account; nil remains a
typed unavailable boundary, not the normal production path. Tests inject the
same closed proof fixture. Revision 8 does not treat an inherited managed MCP
process as trusted Ranch capability and does not claim that the whole-table
`-c` value erases a lower layer.

Claude first/resume uses `-p --input-format text` plus the existing
stream/model/workspace/session flags and additionally emits exactly
`--tools "" --setting-sources ""
--strict-mcp-config --allowedTools` followed by the sorted provider-visible
Ranch names, `--permission-mode dontAsk --disable-slash-commands --no-chrome`.
Its 0600 config contains only `mcpServers.ranchboard`; `--bare` is forbidden.
Thus native file/shell/web/Chrome tools, user/project/local settings, and every
inherited MCP are disabled. The typed child environment also sets
`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1`,
`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `DISABLE_AUTOUPDATER=1`,
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`, `DISABLE_TELEMETRY=1`,
`DISABLE_ERROR_REPORTING=1`, and `DISABLE_BUG_COMMAND=1`; `spec.environment`
cannot override these reserved keys. This prevents Git state/instructions
outside the canonical context from entering the prompt and prevents the Ranch
MCP helper from inheriting Anthropic/cloud credentials. The same bounded signed-binary probe must
return exact version line `2.1.81 (Claude Code)`. The Codex version/help
snapshot and Claude version/help snapshot must prove every applicable
hardening flag before their factory is registered. A missing flag, unknown
version, or observed tool/server outside the exact Ranch set fails closed
before the first model call; no adapter downgrade or different provider is
selected.

Claude's `--setting-sources ""` excludes user/project/local settings but cannot
override OS/account managed policy. Before the Claude factory is registered it
requires the seed's optional `validateClaudeManagedPolicy` closure. That
authority descriptor-requires exact `ENOENT` for
`/Library/Application Support/ClaudeCode/managed-settings.json`,
`/Library/Application Support/ClaudeCode/managed-mcp.json`, and
`/Library/Application Support/ClaudeCode/CLAUDE.md`. It also derives the
current username only from `getpwuid_r(getuid())` (never `$USER` or `$HOME`) and
descriptor/no-follow requires exact `ENOENT` for both Claude 2.1.81 managed
preference authorities:
`/Library/Managed Preferences/com.anthropic.claudecode.plist` and
`/Library/Managed Preferences/<current-username>/com.anthropic.claudecode.plist`.
Present, symlinked, permission-denied, opaque, or before/after-drifting material
makes Claude unavailable even when the host is not currently enrolled. Version
2.1.81 has no `managed-settings.d` source, so this Revision does not invent one.
The same bounded `profiles status -type enrollment` output must be the exact two
non-enrolled lines above. It then runs the same staged/signed/hash-pinned
2.1.81 binary's bounded `claude auth status --json` before factory registration
and every actual launch. Stdout must be one object with exact sorted key set
`apiProvider,authMethod,email,loggedIn,orgId,orgName,subscriptionType`, stderr
empty, and exact public values `loggedIn:true`, `authMethod:"claude.ai"`,
`apiProvider:"firstParty"`, `subscriptionType:"pro"`. `email`, `orgId`, and
`orgName` must each be nonempty strings but are never retained, hashed, or
logged. Missing/extra keys, Team/Business/Enterprise/unknown subscription,
timeout, local managed material, MDM enrollment, or identity drift fails
closed. Thus AppStore constructs the live validator for a personal Pro account;
nil or thrown validation makes only Claude unavailable before Store begin.
Tests inject the same consumer fixture. The plan never pretends that an opaque
managed hook is part of the hashed ContextPacket or safely executable outside
the Ranch channel.

`CliCommandSpec` has this complete final source-compatible declaration:

```swift
public struct CliCommandSpec: Sendable, Equatable {
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]
    public let stdinBytes: Data
    public let cleanupURLs: [URL]

    public init(
        command: String,
        arguments: [String],
        environment: [String: String] = [:],
        stdinBytes: Data = Data(),
        cleanupURLs: [URL] = []
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.stdinBytes = stdinBytes
        self.cleanupURLs = cleanupURLs
    }
}
```

The default preserves existing non-engine mechanics callers. For engine
launches `stdinBytes` is exactly the canonical UTF-8 prompt and its byte count
must be in `1...4_194_304`; the engine launch-request initializer rejects an
empty or larger value before process/Board work. No prompt,
Board token/socket/Card/tool list, or config content appears in argv. Before
spawn, `CliProcessBackend` creates a dedicated CLOEXEC stdin pipe and applies
descriptor-local `fcntl(F_SETNOSIGPIPE, 1)` to its write end; failure occurs
before spawn. It removes all reserved `AGENTLOOP_BOARD_*` keys from the
login-shell environment, rejects any
attempt by `spec.environment` to set them, then injects the exact values from
the typed launch request. The child inherits only the pipe read end as stdin;
the App's stdin is never inherited. After successful spawn the backend writes
all bytes with checked short-write/EINTR handling and checked close. `EPIPE` is
a checked write failure, never a process-wide SIGPIPE; an immediately exiting
child cannot terminate the App. A write/close failure sends TERM/KILL as
required, drains/reaps, stops Board, removes config, and surfaces
process-outcome-unknown; no child/socket/config is left. Provider-mandated
first/resume session IDs remain the sole nonsecret
execution identifiers in argv and are never copied to logs/errors.

### 26.3 Factory-captured request and transport authority

Selection remains exact and registry-owned. Add:

```swift
package struct EngineAdapterHelpRequirementV1:
    Sendable, Equatable
{
    package let kind: RuntimeProfileKind
    package let command: String
}

package typealias EngineInitialModelLoopProviderResolveV1 =
    @Sendable (
        _ profile: RuntimeProfileRecord,
        _ companionId: String,
        _ companionModel: String,
        _ modelPolicy: CompanionModelPolicy
    ) throws -> EngineModelLoopProviderAuthorityV1

package typealias EngineRecoveryModelLoopProviderResolveV1 =
    @Sendable (
        _ profile: RuntimeProfileRecord,
        _ companionId: String,
        _ persistedModel: String
    ) throws -> EngineModelLoopProviderAuthorityV1
```

The help-requirement initializer accepts only CLI kinds plus a nonempty
command. Each
`EngineAdapterFactoryV1` gains one nullable help requirement, a captured
`prepareRequest` closure, and a captured `makeRecoveryTransport` closure in
addition to its existing descriptor/adapter factory. The returned
`EngineAdapterSelectionV1` captures the exact profile, help snapshot,
descriptor, request preparation, recovery transport, and adapter factory. No
Orchestrator, coordinator, AppStore, or recovery code may switch on
`profile.kind.isCLI`, provider kind, adapter ID, or fallback order.

Their exact added fields/signatures are:

```swift
// EngineAdapterFactoryV1
package let helpRequirement: EngineAdapterHelpRequirementV1?
package let prepareRequest:
    @Sendable (
        RuntimeProfileRecord,
        CliHelpSnapshotV1?,
        EngineExecutionTransportSeedV1
    ) throws -> EngineAdapterPreparedRequestV1
package let makeRecoveryTransport:
    @Sendable (
        RuntimeProfileRecord,
        CliHelpSnapshotV1?,
        EngineExecutionRequest,
        EngineResolvedContextTransportV1,
        EngineResolvedWorkspaceV1,
        EngineExecutionTransportSeedV1
    ) throws -> EngineExecutionTransportV1

// EngineAdapterSelectionV1, with profile/help captured by resolve
package let prepareRequest:
    @Sendable (EngineExecutionTransportSeedV1) throws
        -> EngineAdapterPreparedRequestV1
package let makeRecoveryTransport:
    @Sendable (
        EngineExecutionRequest,
        EngineResolvedContextTransportV1,
        EngineResolvedWorkspaceV1,
        EngineExecutionTransportSeedV1
    ) throws -> EngineExecutionTransportV1
```

The common preparation inputs and selected output are:

```swift
package struct EngineModelLoopProviderAuthorityV1: Sendable {
    package let profileId: String
    package let effectiveModel: String
    package let makeProvider: @Sendable () throws -> any LLMProvider
}

package struct EngineExecutionTransportSeedV1: Sendable {
    package let context: EnginePreparedContextV1
    package let workspace: EnginePreparedWorkspaceClaimV1
    package let baseRequiredCapabilities: [EngineCapabilityV1]
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1?
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1?
    package let validateCodexManagedPolicy:
        (@Sendable () throws -> Void)?
    package let validateClaudeManagedPolicy:
        (@Sendable () throws -> Void)?
    package let claudeConfigDirectory: URL
    package let cliExecutableDirectory: URL
    package let resolveInitialModelLoopProvider:
        EngineInitialModelLoopProviderResolveV1
    package let resolveRecoveryModelLoopProvider:
        EngineRecoveryModelLoopProviderResolveV1
    package let makeCliProcessDriver:
        @Sendable () throws -> any CliProcessDrivingV1
}

package struct EngineAdapterPreparedRequestV1: Sendable {
    package let descriptor: ExecutionEngineDescriptor
    package let engineKind: String
    package let model: String
    package let budget: EngineExecutionBudgetV1
    package let context: EnginePreparedContextVariantV1
    package let requiredCapabilities: [EngineCapabilityV1]
    package let makeTransport:
        @Sendable (
            EngineExecutionRequest,
            EngineResolvedContextTransportV1,
            EngineResolvedWorkspaceV1
        ) throws -> EngineExecutionTransportV1
}
```

`EngineModelLoopProviderAuthorityV1` has an explicit package initializer in
the listed field order; its closure parameter is `@escaping`. Every new
Revision-8 package value that crosses the Core/App/test target boundary has an
explicit package initializer in its listed field order rather than relying on
an internal synthesized memberwise initializer.

The environment's optional `bridgeExecutablePath` is only the source input to
runtime staging. AppStore's live environment always supplies it together with
a nonnil Board socket-directory authority. Runtime does not stage/require
either for ModelLoop; a compatibility seed may therefore carry nil. A CLI
factory requires both a nonnil staged `bridgeExecutableAuthority` and a
nonnil Board directory authority inside `prepareRequest`, before Store begin,
or is typed unavailable. It captures those exact authorities in the prepared
transport closure; gated `makeTransport` only consumes the captured values and
never performs a later optional lookup. ModelLoop requires neither. No factory
accepts a naked bridge path/directory.
`CliEngineRuntimeConfigurationV1` and `CliEngineCommandInputV1` likewise
replace `bridgeExecutablePath` with that full Board-bridge authority. They also
carry the selected help snapshot's nonoptional
`cliExecutableAuthority: CliExecutableAuthorityV1`, and
`CliProcessLaunchRequestV1` carries both authorities without reconstruction.
Vendor command bytes derive only from `cliExecutableAuthority.stagedPath`;
Board helper command/config bytes derive only from
`bridgeExecutableAuthority.stagedPath`.

The final runtime configuration field/init order is exactly
`command,cliExecutableAuthority,sandbox,reasoningEffort,bridgeExecutableAuthority,
boardSocketDirectoryAuthority,claudeConfigDirectory,ranchSessionId`; both
executable authorities and the Board-directory authority are nonoptional. Its
initializer requires `command == cliExecutableAuthority.stagedPath` and the CLI
authority's own canonical fields. The captured factory/selection performs the
byte-equality check against its selected help snapshot authority immediately
before constructing this configuration; the value initializer has no snapshot
side channel. Its existing `Sendable, Equatable` conformances remain. Final
`CliEngineCommandInputV1` field/init order is exactly
`command,cliExecutableAuthority,workspaceURL,sandbox,model,reasoningEffort,
prompt,bridgeExecutableAuthority,boardSocketURL,boardToken,boardCardId,
toolNames,claudeConfigURL,session`; its initializer requires
`command == cliExecutableAuthority.stagedPath` and self-validates that
authority's canonical fields before rendering. The captured factory equality
against the help snapshot was already performed before configuration/input
construction and is not repeated through a hidden side channel. Its derived
socket URL is a rendering value, not directory authority.

Immediately before vendor spawn, the backend reopens the staged vendor
executable no-follow and revalidates requirement/team/CDHash/hash/device/inode
from the launch request's CLI authority. It separately reopens and revalidates
the staged Board helper from the request's bridge authority before any helper
launch. No factory, builder, or backend may recover either expected identity
through a side channel or path string.

ModelLoop preparation alone invokes the initial provider-authority resolver
with the exact prepared profile, companion ID, stored companion model, and
model policy. AppStore's live resolver recomputes inherit/pinned selection from
the same profile-scoped defaults and trusted catalog, returns the exact profile
ID/effective model, and captures credential authority in a deferred provider
closure. Factory preparation requires returned profile ID byte-equal to the
prepared profile and compares the effective model to the catalog before Store
begin; the provider closure is invoked only after `.startNow`. Recovery passes
the exact persisted model, requires exact persisted profile identity, and never
recomputes an inherit/default model. The nil compatibility environment supports
only a nonempty pinned companion model through its old
`makeProvider(model,companionId)` authority; inherit/default without AppStore's
live resolver fails visibly before Store begin rather than persisting a false
model. ModelLoop creates CardRunner with the same capability plan,
`cardMaxTurns`, `KernelDefaults.maxTokensPerTurn`, transport retry delays, and
turn timeout. CLI preparation never invokes that resolver. Codex freezes
`KernelDefaults.codexCliDefaultModel`; Claude freezes
`KernelDefaults.claudeCliModel ?? KernelDefaults.defaultGuideModel`; an empty
value or `cli-default` is a typed preflight failure. Normal/startPrepared CLI
transport acquires `makeCliProcessDriver` only after `.startNow`; recovery
acquires it only inside a Store-validated directive branch that actually
dispatches or cancels an external process. Non-dispatch recovery directives
and all ModelLoop paths never invoke it.

`engineKind` is exactly the selected descriptor adapter ID, not a second
`api/cli/model-loop` vocabulary. The request budget is exactly Card
`tokenBudget`, cost micros `0`, wall-clock seconds `0`. Zero is explicitly
unconfigured/not enforced; Revision 8 does not claim a cost or wall watchdog
that does not exist. ModelLoop continues to enforce token/max-turn/turn-idle
limits. CLI's persisted token limit is identity/audit data, not a claimed
provider cutoff.

Base required capabilities are sorted unique
`boardTerminal,cancellation,network,streamingProgress,toolBridge,
usageMetering,workspaceRead`. Registry resolves that common set first. The
captured factory chooses its exact context variant and returns the final sorted
unique capabilities in `EngineAdapterPreparedRequestV1`; it adds
`workspaceWrite` only when the shared capability plan exposes a real parent
`write_file` handler. The runtime resolves the same profile again with that
final set and requires the same factory/descriptor identity before constructing
request fields. No caller branches on adapter/profile kind. If and only if the
exact ready cause has a causal predecessor and the initially selected
descriptor reports `.sessionResume == .supported`, the runtime generically
appends `.sessionResume` to the factory-returned final set, performs the same
exact registry capability recheck, sets that exact predecessor ID, and lets
Store perform all existing session/scope checks. The factory does not receive
or infer the ready cause.
Unsupported or conditional resume intentionally starts fresh with nil
predecessor and no resume requirement. Once nonnil is asserted, any Store
drift fails closed; there is no catch-and-retry with nil.

The three factory transport rules are exact:

- ModelLoop invokes only the captured provider closure and never the CLI
  closure;
- Codex/Claude invoke only the CLI closure, acquire the runtime's one shared
  `CliProcessBackend`, and never the provider closure; and
- recovery reloads the persisted profile/model and uses the selected factory's
  recovery closure. It never recomputes a default over persisted request
  bytes.

Codex/Claude runtime config uses the selected help snapshot's bound staged
executable path and always uses CLI-native `read-only`; all real writes occur
only through the parent Ranch handler under the execution workspace lease.
It also uses Codex's existing reasoning effort (Claude accepts the same
nonsecret field but does not map it to an argv flag), the App bridge path, the
App runtime directories, and `ranchSessionId == request.executionId`. First,
startPrepared, and resume never generate a second ranch UUID.

### 26.4 Executable identity, partial registry, and runtime directories

`CliHelpSnapshotV1` adds
`executableAuthority: CliExecutableAuthorityV1` and has no independently
caller-supplied path/hash fields. Snapshot construction requires that stored
authority byte-equal the input authority; descriptor validation and transport
launch read path/hash/device/inode only through that stored value. Add:

```swift
package struct CliExecutableAuthorityV1: Sendable, Equatable {
    package let kind: RuntimeProfileKind
    package let command: String
    package let commandSourcePath: String
    package let commandSourceHash: String
    package let resolvedExecutablePath: String
    package let stagedPath: String
    package let executableHash: String
    package let designatedRequirement: String
    package let teamIdentifier: String
    package let cdHash: String
    package let stagedDevice: UInt64
    package let stagedInode: UInt64
}

package struct EngineBoardBridgeExecutableAuthorityV1:
    Sendable, Equatable
{
    package let sourcePath: String
    package let stagedPath: String
    package let executableHash: String
    package let designatedRequirement: String
    package let teamIdentifier: String?
    package let cdHash: String
    package let stagedDevice: UInt64
    package let stagedInode: UInt64
}

package final class EngineBoardSocketDirectoryAuthorityV1:
    @unchecked Sendable, Equatable
{
    package let directoryURL: URL
    package let device: UInt64
    package let inode: UInt64
    package let uid: UInt32
    package let mode: UInt16
    package let ownerIdentityHash: String
    package let bootId: String

    package init(
        directoryURL: URL,
        ownedDescriptor: Int32,
        device: UInt64,
        inode: UInt64,
        uid: UInt32,
        mode: UInt16,
        ownerIdentityHash: String,
        bootId: String
    ) throws
    package func makeDescriptorLease() throws
        -> EngineBoardSocketDirectoryDescriptorLeaseV1
    package func close() throws
    package static func == (
        lhs: EngineBoardSocketDirectoryAuthorityV1,
        rhs: EngineBoardSocketDirectoryAuthorityV1
    ) -> Bool
}

package final class EngineBoardSocketDirectoryDescriptorLeaseV1:
    @unchecked Sendable
{
    package let fileDescriptor: Int32
    package func close() throws
}

package struct EngineRuntimeProcessSnapshotV1: Sendable, Equatable {
    package let pid: Int32
    package let processGroupId: Int32
    package let uid: UInt32
    package let startSeconds: UInt64
    package let startMicroseconds: UInt32
    package let executablePath: String
    package let executableDevice: UInt64
    package let executableInode: UInt64
    package let executableHash: String
    package let designatedRequirement: String
    package let cdHash: String
}

package protocol EngineRuntimeProcessInspectingV1: Sendable {
    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1]
    func send(
        signal: Int32,
        processGroupId: Int32
    ) throws
    func processGroupExists(_ processGroupId: Int32) throws -> Bool
}

package typealias EngineBoardPeerValidateV1 =
    @Sendable (_ peerPid: Int32) throws -> Void

// Replaces CliHelpProbeV1.init().
package init(
    processInspector: any EngineRuntimeProcessInspectingV1
)

// Replaces the final mechanics-only CliProcessBackend initializer.
package init(
    terminationGrace: Duration = .seconds(5),
    killGrace: Duration = .seconds(2),
    pipeDrainGrace: Duration = .seconds(1),
    registry: ShellProcessRegistry = .shared,
    processInspector: any EngineRuntimeProcessInspectingV1
) throws

package func identifyAndStage(
    for kind: RuntimeProfileKind,
    command: String,
    stagingDirectory: URL
) throws -> CliExecutableAuthorityV1
package func snapshot(
    for kind: RuntimeProfileKind,
    authority: CliExecutableAuthorityV1
) async throws -> CliHelpSnapshotV1
package func identifyAndStageBoardBridge(
    sourcePath: String,
    stagingDirectory: URL
) throws -> EngineBoardBridgeExecutableAuthorityV1
```

`EngineBoardSocketDirectoryAuthorityV1` uniquely owns the already-opened
no-follow descriptor passed to its initializer. The initializer fstats and
requires every listed identity/owner/mode field before taking ownership. Each
lease duplicates by `F_DUPFD_CLOEXEC`, registers one authority capture, and
owns that fd. Lease `close` is checked/release-once and decrements the capture;
its deinit fallback closes but marks an unchecked-release fault that makes the
authority's final checked `close` fail visibly. Authority `close` is
release-once and fails while any lease remains or an unchecked release
occurred; lease-after-close fails. Internal locks protect both state machines.
The AppStore-owned `EngineExecutionRuntimeV1` is the sole lifetime/close owner
of this authority. Dispatch, recovery, emergency stop, and mission cancellation
may borrow checked leases but never close the authority. Only App shutdown,
after every execution/Board lease and registry entry is gone, performs the
checked current-boot-directory teardown described below, releases its final
descriptor lease, and then calls authority `close()` exactly once. A teardown,
lease-release, or authority-close failure is aggregated visibly and the gate
remains closed; deinit is never accepted as checked shutdown evidence.
`directoryURL` exists solely to render the child socket string after the
descriptor/basename checks; it is never reopened as filesystem authority.
Its explicit `Equatable` implementation compares only the immutable
`directoryURL,device,inode,uid,mode,ownerIdentityHash,bootId` fields. It never
compares descriptor numbers, capture counts, close state, or the
unchecked-release fault, so `CliEngineRuntimeConfigurationV1` retains its
existing value equality without turning liveness into identity.
AppStore constructs `CliHelpProbeV1` and the shared `CliProcessBackend` with
the exact same environment inspector; neither owner may instantiate a hidden
live inspector. The backend combines that inspector with the launch request's
bridge authority into one `EngineBoardPeerValidateV1` closure and passes it to
`BoardToolServer` immediately after the bound capability tools in its exact
initializer. The server calls it exactly once on `LOCAL_PEERPID` before reading
or responding to `hello`; it owns no database or process-signaling authority.

Before copying, `SecStaticCode` must validate a trusted Developer ID chain and
the exact built-in designated authority. Codex requires identifier `codex` and
Team ID `2DC432GLL2`; Claude requires identifier
`com.anthropic.claude-code` and Team ID `Q6L2SF6YDW`. The exact normalized
designated requirement, Team ID, and CDHash are captured in the authority.
After staging, `SecStaticCode` revalidates the same requirement and CDHash in
addition to bytes/device/inode. An arbitrary PATH Mach-O, ad-hoc vendor binary,
or help-compatible impostor is typed unavailable; custom binary trust is not a
Revision-8 feature.

The packaged Board helper has exactly two nonmixable signature modes. For a
Developer-ID App it must have a valid Developer-ID chain, the exact same Team
ID/anchor as the containing App, and exact helper identifier
`com.muzi.agentloop.board-bridge`. For a
`SIGN_ID=-` development/preview package, both the containing App and nested
helper must be valid ad-hoc signatures produced by the same packaging
invocation; the containing App's sealed nested-code record, fixed helper
identifier, App CDHash, and helper CDHash must all validate before staging.
Developer-ID/ad-hoc mixing or an unsealed loose helper fails. The optional
bridge `teamIdentifier` is nonnil only in Developer-ID mode. Release packaging
requires Developer ID; the ad-hoc mode exists only for the repository's local
preview workflow. Both modes pass that exact identifier to `codesign -i`, and
authority creation, staging, and every launch revalidate it. Development unit tests use an explicit injected signed
authority fixture and cannot weaken either packaged mode.

`identifyAndStage` resolves PATH without a shell, resolves the intentional
command symlink once, and opens the canonical command source no-follow. A
native Mach-O command is the resolved executable directly. The only accepted
script form is `.cliCodex` whose canonical command source is the official
`@openai/codex/bin/codex.js`, begins with exact
`#!/usr/bin/env node`, and resolves by the package's exact platform mapping to
the regular native target
`node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex`
on arm64 or the corresponding `codex-darwin-x64` /
`x86_64-apple-darwin/bin/codex` target on x86_64. The wrapper path/hash and
native target path/hash are both frozen in the authority; an unknown script,
package layout, architecture, or target fails closed. Help and launch execute
the staged native target, never `/usr/bin/env`, a PATH-selected `node`, or the
wrapper. This explicitly supports the production npm Codex installation
without making arbitrary scripts executable authorities.

The chosen native target must be a no-follow regular executable. The resolver
streams it into a descriptor-relative
`O_CREAT|O_EXCL|O_CLOEXEC|O_NOFOLLOW` file mode 0500 inside a fresh private
authority directory, hashes while copying, fsyncs file and parents, reopens the
staged file no-follow, and requires byte count/hash plus pre/post source and
staged dev/inode/size/mtime identity. It then seals that authority directory
mode 0500. A native binary that cannot execute correctly from the staged path
fails its help probe; there is no source-path or wrapper fallback.

`snapshot` and every process launch use only the staged path. They reopen it
no-follow and require the captured device/inode/hash before execution. The
private sealed authority directory remains alive until every child using that
generation is reaped. Help and vendor launch set
`POSIX_SPAWN_START_SUSPENDED` together with the existing process-group flags.
Before `SIGCONT`, the process inspector samples the returned PID/start
identity/path/device/inode/hash/requirement/CDHash and requires an exact match
to the staged authority; mismatch kills and reaps the still-suspended group and
returns the typed identity failure. This is the executable image used by the
child, not a second pre-spawn path check. Any staged identity drift is a typed
launch failure before `SIGCONT`, vendor code, model/network access, or MCP
child effect. The process and any already-created Board socket or token-bearing
config are expected pre-verification resources; the failure path must
kill/reap the suspended group, stop and unlink the exact Board socket, and
checked-delete the exact config before returning. Raw help output,
source/staged paths, environment, and process errors are never persisted or
logged.

An Orchestrator-owned actor caches successful snapshots and one in-flight Task
by exact `(kind,commandSourcePath,commandSourceHash,resolvedExecutablePath,
executableHash)`. Concurrent callers share the
Task. Failure removes the in-flight entry and is not negative-cached; the
ready-event suppression gate prevents repeated probes for the same Card cause.
Changed hash means a new probe. ModelLoop-only dispatch/recovery performs zero
CLI identify/probe operations.

Each help invocation uses its own process group, concurrently drains stdout
and stderr without exposing either, caps stdout at exactly 256 KiB, and has a
five-second monotonic deadline. Exit, overflow, or deadline failure sends TERM
to the group, waits at most one second, sends KILL to the surviving group,
then drains and reaps every child before returning the sanitized failure. On
any identify/probe/snapshot failure, the runtime descriptor-relatively removes
that attempt's staged file and authority directory and fsyncs both parents
before clearing the in-flight cache entry. A failed probe therefore leaves no
`O_EXCL` residue and an explicit later retry can probe again; a hung or
forking CLI cannot halt startup indefinitely.

All cause/context/workspace/provider/help/executable/tool-policy/runtime-dir
preflight failures pass through one closed sanitizer:

```swift
package enum EnginePreflightFailureReasonV1:
    String, Sendable, Equatable
{
    case readyCause
    case context
    case workspace
    case provider
    case cliHelp
    case cliExecutable
    case toolPolicy
    case runtimeDirectory
}

package enum EnginePreflightFailureScopeV1: Sendable, Equatable {
    case ready(EngineCardReadyObservationV1)
    case startup
}

package struct EngineSanitizedPreflightFailureV1:
    Sendable, Equatable
{
    package let reasonCode: String
    package let detail: String
    package let trace: String
}
```

The builder accepts only the closed reason plus scope, never an Error/string,
stderr/stdout/path/prompt/token/session/credential/config value. It uses a
fixed nonsecret detail per reason and `trace` equal to the first 16 lowercase
hex characters of SHA-256 over the canonical reason/scope value. Only this
result reaches Kernel events, suppression state, FailureReporter, receipts, or
logs. Typed low-level errors choose the exhaustive reason before sanitizing;
`String(describing:)`, localized/raw error text, and catch-all detail are
forbidden on this path.

Each built-in factory declares nil help, `(.cliCodex,"codex")`, or
`(.cliClaude,"claude")`. The runtime builds an immutable registry from all
currently successful snapshots. A missing dormant CLI does not block API/OAuth
work. New dispatch for that CLI fails before Store begin and suppresses that
ready cause. Before recovery, the Store's new static/read-only
`activeRecoveryProfileKinds(database:)` returns sorted unique profile kinds for
nonredacted running engine executions; only those CLI kinds are probed. Missing
active CLI help keeps startup halted before legacy adoption.

Revision 8 adds a standalone package executable product/target
`AgentLoopBoardBridge` at `Sources/AgentLoopBoardBridge/main.swift`, depending
only on `AgentLoopCore`. Its main invokes `BoardServerBridgeMain` in forced
bridge mode and exits nonzero if that call ever returns without handling the
bridge. `scripts/package-app.sh` builds it, copies it to exact
`Contents/Helpers/AgentLoopBoardBridge`, signs the helper before the containing
App, and verifies its signature and executable bit. Production never uses
`Bundle.main.executableURL` as an MCP child. Tests/dev inject an explicit helper
path.

Revision 8 also anchors the runtime to the directory actually protected by
`StateDirectoryLock`, not merely to its path string. `StateDirectoryLock`
descriptor-opens the final state directory no-follow, opens `.agentloop.lock`
with exact
`openat(dirfd,".agentloop.lock",O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600)`,
and fstats a current-UID regular mode-0600 link-count-one file. After acquiring
`flock`, it performs `fstatat(...,AT_SYMLINK_NOFOLLOW)` and requires the same
device/inode/type before retaining both descriptors for its lifetime. A
symlink, hardlink, replacement, ownership/mode drift, or lock identity mismatch
fails before database/runtime construction. It then
adds exactly:

```swift
package func duplicateLockedDirectoryDescriptor() throws -> Int32
```

The duplicate uses `F_DUPFD_CLOEXEC`; the caller owns it and must checked-close
it after constructing the longer-lived runtime authorities. This short-lived
duplicate has no capture/refcount contract. AppStore fstats it and derives:

```swift
package struct EngineStateRootIdentityV1:
    Codable, Sendable, Equatable
{
    package let canonicalPath: String
    package let device: UInt64
    package let inode: UInt64
    package let uid: UInt32
}
```

`canonicalPath` is exact `F_GETPATH` of that opened descriptor. The listed
device/inode/UID must byte-match both the duplicated lock parent and every
runtime-root operation. Its identity bytes are sorted-key canonical JSON with
exactly `canonicalPath,device,inode,uid` and no trailing newline; the
state-root identity hash is lowercase SHA-256 of those bytes. The short-root
mode-0600 `owner` file is sorted-key canonical JSON with exactly
`bootUUID,stateRootIdentityHash`, no trailing newline, and a canonical UUID
boot value. Reads require exact keys, canonical re-encode byte equality, exact
hash, current UID, regular file, mode 0600, and link count one. No path-only,
device-only, or caller-supplied identity is accepted.

After taking the existing `StateDirectoryLock`, AppStore descriptor-anchors an
`engine-runtime` directory and a unique canonical-UUID boot child, all mode
0700, containing only `cli-config` and `cli-executables` mode 0700. It validates
the packaged bridge source no-follow and stages it into a sealed current-boot
authority exactly like a native CLI executable, recording source/staged
hash/device/inode. Every MCP config uses only that staged standalone helper;
the helper authority remains alive until all Board children are reaped and is
revalidated immediately before its config is handed to the vendor. On the
accepted socket, `BoardToolServer` reads `LOCAL_PEERPID` before `hello_ok` and
uses the process inspector to require that peer's stable executable/signature
identity byte-match the exact bridge authority; mismatch closes the connection
and exposes no tools. Darwin offers no suspended-spawn control over the
vendor's later MCP child, so the same private-current-UID ownership boundary
described for socket paths applies; Revision 8 does not claim resistance to a
separate malicious process already running as that UID.

AF_UNIX sockets do not live under the long Application Support path. While
holding the same StateDirectoryLock, AppStore obtains
`_CS_DARWIN_USER_TEMP_DIR`, canonicalizes only that system-returned path once
through `realpath`/`F_GETPATH`, and requires the target be absolute under exact
`/private/var/folders/` with final `T` component. This explicitly accepts the
macOS system `/var -> /private/var` alias; it then descriptor-opens every
canonical component no-follow and requires a current-UID mode-0700 anchor. No
AgentLoop-created or user-controlled intermediate symlink is accepted. It
creates one short current-boot directory named `a-<12-lowercase-hex>`, mode
0700, where the suffix is the first 12 hex characters of SHA-256 over the exact
canonical owner-file bytes `{bootUUID,stateRootIdentityHash}` defined above.
An exact mode-0600 `owner` file
stores only the canonical state-root identity hash and boot UUID.
Different-state-root directories are ignored, never removed. On a short-name
collision with a different owner, startup generates a fresh canonical boot
UUID and retries at most eight total candidates; exhaustion fails visibly. A
same-state-root live collision is impossible under the lock and fails. Board
socket names are exactly `s-<16-lowercase-hex>.sock`, where the suffix is the
first 16 hex characters of SHA-256 over the canonical execution UUID's exact
UTF-8 bytes, with no delimiter or newline.
Construction checks before bind
that full socket-path UTF-8 byte count plus NUL is no greater than
`MemoryLayout.size(ofValue: sockaddr_un().sun_path)`; violation is a typed runtime-directory
failure. AppStore places this open authority in the environment's
`boardSocketDirectoryAuthority`;
`claudeConfigDirectory` and `cliExecutableDirectory` remain under the long
boot child.

Revision 8 replaces the old random/default socket maker with exactly:

```swift
package static func makeSocketURL(
    directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
    executionId: String
) throws -> URL
```

It canonical-UUID-validates the execution ID, derives the fixed basename and
checks `path.utf8.count + 1 <= MemoryLayout.size(ofValue:
sockaddr_un().sun_path)`. It performs no I/O and generates no random value. The
old public `makeSocketURL(directory: URL? = nil)` overload is removed after its
allowlisted tests migrate. Adapter passes exact `request.executionId`.

`BoardToolServer.bindAndListen` uses an authority descriptor lease to require
the current boot socket basename be `ENOENT` immediately before bind; it never
predeletes a path. Darwin `bind(2)` and the child `connect(2)` necessarily use
the frozen full `sun_path`, so the server also byte-matches the printed parent
path's dev/inode/UID/mode to the authority immediately before and after bind.
`EADDRINUSE`, any existing object, or parent drift is a collision/identity
failure. After bind it captures the socket device/inode/UID/type. `stop`
unlinks only when a fresh
descriptor-relative no-follow stat still byte-matches that captured
current-UID `S_IFSOCK`, then fsyncs the parent; replacement or drift is a
cleanup failure and the replacement is never deleted. Startup sweep operates
only on older owned boot directories, never the current bind directory.

Revision 8 replaces every naked Board directory URL in
`CliEngineRuntimeConfigurationV1`, `CliProcessLaunchRequestV1`, and
`BoardToolServer` with the nonoptional directory authority; the launch request
also carries the validated socket basename. Those initializer fields appear
where the former directory/URL field appeared. Only command/config rendering
receives the derived full URL string. Pre/post stat, stop unlink, and fsync use
an authority descriptor lease; only Darwin bind/connect use the frozen path.
The private current-UID 0700 directory plus StateDirectoryLock is the process
ownership boundary. Revision 8 detects path drift caused by its own lifecycle
or accidental replacement but does not claim to withstand a malicious process
already running as the same UID; defending that different threat would require
FD passing or a different channel, not a nonexistent `bindat` API.

Each staged executable lives in an exact
`<cli-kind>-<lowercase-64-hex-hash>` child containing only `executable`; the
bridge uses `board-bridge-<lowercase-64-hex-hash>` with the same shape. After
population an authority child is mode 0500 and its file is current-UID,
regular, mode 0500, and link-count one.

Before deleting any prior-boot authority or socket/config residue, runtime uses
the injected `EngineRuntimeProcessInspectingV1` while still holding the
StateDirectoryLock. It enumerates current-UID processes and finds every PID
whose executable path/device/inode belongs to a validated owned old-boot CLI or
bridge authority. For each group it requires one leader with `pid == pgid`,
all members current-UID, and every member one of those exact staged signed CLI
or bridge authorities; an unknown member fails closed and is never signaled. PID/start
identity, group, path/device/inode/hash/requirement/CDHash are sampled before
and after `SIGSTOP`. Drift sends `SIGCONT` to the still-matching group and
aborts cleanup. A stable owned group receives SIGTERM then SIGCONT, a bounded
five-second monotonic grace, and SIGKILL if still present. Because these are
not necessarily child processes, cleanup never claims `waitpid` reap; it polls
`kill(-pgid,0)` until exact `ESRCH` before unlinking residue. Failure leaves the
gate closed and residue intact. Unrelated processes are never stopped or
signaled. This applies to surviving main CLI, help, and Board bridge groups, so
an App crash cannot leave a paid/network session alive while recovery launches
a second one.

Before choosing new boot children, no-follow descriptor-relative sweeps remove
only owned residue. A long-root sweep accepts only older canonical-UUID boot
children with exact `cli-config`/`cli-executables` shapes. Config residues are
exact `agentloop-<canonical-execution-UUID>.mcp.json`, current-UID regular mode
0600, link-count one. Executable/bridge residues must match the exact sealed
authority directory/file shapes and filename hashes. The per-user-temp sweep
opens only `a-<12hex>` directories whose owner file exactly matches this
state-root hash; inside, it accepts only the owner file plus
`s-<16hex>.sock` residues that are current-UID `S_IFSOCK` with link-count one.
Unknown names, a symlink, regular file in place of a socket, hardlink, identity
drift, ownership/mode mismatch, or checked cleanup failure aborts startup
visibly. Every descriptor-relative unlink/rmdir fsyncs its parent. No recursive
`FileManager.removeItem`, `try?`, ignored unlink, public `/tmp` directory, or
AgentLoop/user-controlled symlink alias is allowed; the one system temp-root
canonicalization above is the only trusted alias step.

Per execution, Board stop remains the sole socket unlink owner and CLI cleanup
the sole config unlink owner after child reap and pipe drain. Unlaunched config
cleanup is checked. Successful generation teardown removes sealed executable
and bridge authorities only after every captured child is reaped. Crash residue
cannot collide with a later boot and is removed only by the locked sweeps.

Because a sealed authority child is mode 0500, teardown and sweep never try to
unlink through that mode. After no-follow/openat validation of the complete
owned shape, hash, device/inode, UID, link count, signature, and capture count,
cleanup uses the already-open authority-directory fd to checked `fchmod` it to
0700 and immediately fstats the exact mode/identity. It then `unlinkat`s the
`executable`, fsyncs the authority directory, `unlinkat(...,AT_REMOVEDIR)` on
the child from its validated parent fd, and fsyncs that parent. Any chmod,
identity, unlink, rmdir, or fsync failure remains visible and leaves the gate
closed; cleanup never path-chmods or deletes a replacement object.

### 26.5 One live composition and source-compatible initializers

`AppStore` is the production composition root. Add one package
`EngineExecutionEnvironmentV1` carrying the exact StateDirectoryLock, database,
artifact/runtime paths, bridge executable, provider-authority closures,
dependency loader, CLI probe/driver makers, and clock. AppStore constructs it
explicitly from the same lock already acquired before the database, the same
credential/default/OAuth authority used by runtime bootstrap, and the same
MCP/search dependency loader injected into Orchestrator. Initial provider
resolution returns profile ID, effective model, and a deferred provider
closure. Recovery requires the exact persisted profile/model and never
substitutes a new default. AppStore injects the Darwin sysctl/proc/kill process
inspector; deterministic tests inject a fake. The compatibility environment may
construct that inspector but still has nil CLI bridge/socket authorities.

The environment has exactly these stored authorities; its initializer takes
them in the same order and performs value/path validation only:

```swift
package struct EngineExecutionEnvironmentV1: Sendable {
    package let database: AppDatabase
    package let stateDirectoryLock: StateDirectoryLock
    package let artifactStoreRoot: URL
    package let bridgeExecutablePath: String?
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1?
    package let validateCodexManagedPolicy:
        (@Sendable () throws -> Void)?
    package let validateClaudeManagedPolicy:
        (@Sendable () throws -> Void)?
    package let claudeConfigDirectory: URL
    package let cliExecutableDirectory: URL
    package let processInspector: any EngineRuntimeProcessInspectingV1
    package let dependencyLoader: any ContextDependencyLoading
    package let resolveInitialModelLoopProvider:
        EngineInitialModelLoopProviderResolveV1
    package let resolveRecoveryModelLoopProvider:
        EngineRecoveryModelLoopProviderResolveV1
    package let helpProbe: CliHelpProbeV1
    package let makeCliProcessDriver:
        @Sendable () throws -> any CliProcessDrivingV1
    package let clock: @Sendable () -> Date
}
```

Add `package actor EngineExecutionRuntimeV1` inside the already-allowlisted
`Orchestrator.swift`; no new source path is created. It is the one lifetime
owner of Context/Workspace resolvers, ArtifactBlob/Origin stores,
ArtifactStager, shared `EngineActiveExecutionRegistryV1`, shared
`CliProcessBackend`, help cache, and the current immutable
registry/Store/coordinator generation. Adding a successful help snapshot
creates a new generation; already-running Tasks retain their captured old
generation. No Card creates a second active registry, state lock, blob store,
or help cache.

The runtime owns one locked lazy cell initialized with the environment's
`makeCliProcessDriver`. Environment/runtime/seed construction and request
preparation never invoke it. The cell serializes concurrent first access,
caches only the first successful driver, returns that exact shared instance on
all later calls, and leaves itself empty after a thrown construction failure.
Each transport seed exposes `makeCliProcessDriver` only as a captured closure
to this cell. ModelLoop and non-dispatch recovery never invoke the closure;
normal/startPrepared does so only after `.startNow`, and a fresh-process
recovery does so only in a Store-validated external dispatch/cancel directive.

Its exact dispatch surface is:

```swift
package struct EngineDispatchIdentityV1: Sendable, Equatable {
    package let campId: String
    package let cardId: String
    package let companionId: String
    package let cause: EngineCardReadyCauseV1
}

package struct EnginePreparedDispatchV1: Sendable {
    package let requestFields: EngineExecutionRequestFieldsV1
    package let idempotencyKey: String
    package let context: EnginePreparedContextV1
    package let workspace: EnginePreparedWorkspaceClaimV1
    package let selected: EngineAdapterPreparedRequestV1
}

package func prepare(_ identity: EngineDispatchIdentityV1) async throws
    -> EnginePreparedDispatchV1
package func execute(
    _ prepared: EnginePreparedDispatchV1,
    onExecutionBound: @escaping EngineExecutionDidBindV1
) async throws -> EngineTerminalCommitReceiptV1
package func recover(
    missionId: String?,
    now: Date
) async throws -> EngineRecoverySummaryV1
package func cancel(executionId: String, reason: String) async throws
```

The existing three Orchestrator initializer signatures remain source
compatible. The public initializer and the first package initializer retain
their existing parameter lists and forward nil. The third package initializer,
which AppStore currently calls, adds only a final defaulted
`engineEnvironment: EngineExecutionEnvironmentV1? = nil`; AppStore passes
nonnil. Nil does not restore or retain the removed backend: on first engine use
it lazily creates a compatibility environment from the existing artifact root,
`makeProvider`, dependency loader, nil bridge source, and a real
StateDirectoryLock on the state-root parent, then enters the same runtime actor.
That path can execute ModelLoop without any CLI identify/probe; CLI selection
fails before Store begin because no bridge authority exists. Existing tests
that require CLI construction use the third initializer with one shared
explicit environment.
The lazy result is cached once. Lock/path/provider failure is stored and thrown
on every attempted dispatch/recovery with visible suppression; it is never
converted to a fake driver or swallowed. Tests that intentionally construct
multiple Orchestrators over one state root inject one shared environment.

This additive seam avoids mechanical edits to unrelated Orchestrator callers
without preserving DB-writing execution behavior. Final source gates require
AppStore's production construction to be nonnil and the old profile-kind
backend branch to be absent.

### 26.6 Coordinator bind, pending cancel, and post-commit observation

Add the exact bind disposition and observer:

```swift
package enum EngineExecutionBindDispositionV1:
    Sendable, Equatable
{
    case dispatch
    case cancel(reason: String)
}

package typealias EngineExecutionDidBindV1 =
    @Sendable (EngineExecutionRequest) async throws
        -> EngineExecutionBindDispositionV1

package typealias EngineRoutedEventDidCommitV1 =
    @Sendable (_ cardId: String, _ event: EngineExecutionEvent)
        async -> Void

package typealias EngineCancellationResolveV1 =
    @Sendable (
        _ handle: EngineExecutionCompletionHandleV1,
        _ reason: String
    ) async throws
        -> EngineTerminalCommitReceiptV1

package enum EngineCancellationLifecycleDispositionV1:
    Sendable, Equatable
{
    case noTransport
    case registeredCleanupComplete
}

package actor EngineExecutionCompletionHandleV1 {
    package nonisolated let executionId: String
    package init(
        executionId: String,
        resolveCancellation: @escaping EngineCancellationResolveV1
    ) throws
    package func waitForReceipt() async throws
        -> EngineTerminalCommitReceiptV1
    package func resolveCancellation(reason: String) async throws
        -> EngineTerminalCommitReceiptV1
    package func publishCancellationLifecycle(
        _ disposition: EngineCancellationLifecycleDispositionV1
    ) throws
    package func waitForCancellationLifecycle() async throws
        -> EngineCancellationLifecycleDispositionV1
    package func complete(
        receipt: EngineTerminalCommitReceiptV1
    ) throws
}

package actor EngineExecutionCompletionRegistryV1 {
    package func lookupOrInstall(
        executionId: String,
        makeHandle: @Sendable () throws
            -> EngineExecutionCompletionHandleV1
    ) throws -> (
        handle: EngineExecutionCompletionHandleV1,
        didInstall: Bool
    )
    package func remove(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1
    ) throws
    package func snapshotCount() -> Int
}

package enum EngineActiveExecutionRegistrationDispositionV1:
    Sendable, Equatable
{
    case installed
    case pendingCancellationConsumed(reason: String)
}

package enum EngineActiveExecutionCancellationDispositionV1:
    Sendable, Equatable
{
    case latched
    case cancelledAndAwaited
}

package actor EngineExecutionStartGateV1 {
    package func waitUntilOpened() async throws
    package func open() throws
    package func snapshotWaiterCount() -> Int
}

package enum EngineCancellationRequestDispositionV1:
    Sendable, Equatable
{
    case requested(EngineExecutionRecord)
    case terminalWon(EngineTerminalCommitReceiptV1)
}

// EngineActiveExecutionRegistryV1 exact final surface
package func register(
    executionId: String,
    cancelAndAwait: @escaping @Sendable () async throws -> Void
) async throws -> EngineActiveExecutionRegistrationDispositionV1
package func cancel(
    executionId: String,
    reason: String
) async throws -> EngineActiveExecutionCancellationDispositionV1
package func remove(
    executionId: String,
    terminalReceipt: EngineTerminalCommitReceiptV1
) throws
package func finishPending(
    executionId: String,
    terminalReceipt: EngineTerminalCommitReceiptV1
) throws
package func snapshotCounts() -> (
    live: Int,
    pending: Int,
    inFlight: Int
)
```

The bind callback remains throwing only for a typed RunningEntry
ownership/invariant failure. Coordinator never lets that throw escape directly
after Store begin. It catches it, requests fixed cancellation reason
`engine_bind_failed` through the atomic Store method, publishes `.noTransport`
to the exact completion handle, and calls or joins that handle's sole
`resolveCancellation(reason: "engine_bind_failed")` Task. That sole resolution
owner creates or replays the one registry latch, recovers/commits the canceled
terminal, performs the receipt-bound noncancellable finalizer, and calls
`finishPending`; the bind-failure catch must not independently recover, commit,
remove, or finish the execution. Only after that shared resolution completes
does coordinator throw the fixed sanitized bind failure. It exposes no callback
description and leaves no prepared/running row, live entry, completion handle,
pending latch, or external effect. Cleanup failure is aggregated visibly under
the same fail-closed gate; naked post-begin callback throw is forbidden.

Coordinator execute takes `EnginePreparedDispatchV1` plus the bind callback.
It verifies the prepared context/workspace/descriptor against fields, obtains
and holds the execution workspace lease, begins Store, then calls the callback
exactly once immediately after `beginEngineExecution` and before registry
recheck or dispatch CAS. `.cancel` persists request cancellation while the
execution is prepared, constructs no transport/adapter, and recovers the exact
canceled receipt. `.dispatch` continues. After the Store's capability-aware
authority recheck, only `.startNow` creates the gated consumption Task. The
selected `makeTransport` and adapter are invoked inside that Task only after
registry installation returns `.installed` and the coordinator opens its
start gate. `.alreadyStarted` constructs none and enters recovery.

`EngineExecutionCoordinatorV1` therefore replaces the old final-transport
resolver with:

```swift
package typealias EngineExecutionTransportSeedResolveV1 =
    @Sendable (EngineExecutionRequest) async throws
        -> EngineExecutionTransportSeedV1
```

Normal execute receives the already prepared value; recovery calls this seed
resolver, reloads the context/workspace, reselects the current factory, and
invokes only its captured `makeRecoveryTransport` in a directive branch that
actually dispatches. The coordinator initializer also requires the nonthrowing
event observer. No overload retaining caller-built final transport remains.

The runtime and coordinator recovery surfaces both take the same optional
`missionId`. `nil` means the complete recovery set. A nonnil canonical Mission
ID is passed into Store's recovery scan, which joins each execution through its
exact Card and filters inside the same read/write snapshot before producing any
directive; proposal and cancellation reconciliation use that identical set.
There is no scan-all-then-discard behavior. Startup, manual resume, emergency
stop, and App shutdown pass nil. Mission cancellation passes only its exact
target ID, so another Mission's process/session cannot be replayed or canceled
by the scoped operation. Existing direct coordinator call sites mechanically
pass nil.

`EngineExecutionStore.requestCancellation` drops the caller-supplied
`expectedVersion`; its exact arguments are `(executionId,reason,now)` and its
return is `EngineCancellationRequestDispositionV1`. In one SQLite write
transaction it loads the current row/version, verifies an exact strict-command
replay or first running/noncanceled state, and performs the CAS against that
transaction-loaded version. A same-reason receipt replay returns `.requested`
with the current row; a different reason/state conflicts. If the first read is
already terminal, or the CAS loses and one exact reread is terminal, it loads
and validates the exact terminal receipt/execution ownership, request hash,
Card, and nonredacted terminal projection, then returns `.terminalWon` without
writing a cancellation command or touching the registry. No other reread or
fallback is allowed. No Task/registry cancel is requested unless the result is
`.requested`, so concurrent progress/session version increments cannot create
a load-to-write race and terminal-before-cancel is clean success.

`EngineActiveExecutionRegistryV1` gains a pending-cancel latch, but it never
stores or calls naked `adapter.cancel`. Coordinator creates one consumption
Task plus one `EngineExecutionStartGateV1` after `.startNow` and before any
transport/provider/socket/config/process effect. The Task first awaits the
gate, checks cancellation, and only then constructs the selected transport and
adapter and consumes its stream. The registry stores a `cancelAndAwait` closure
that cancels this coordinator-owned Task and awaits its completion.

The per-execution start gate is a three-state actor: closed with at most one
waiter, opened, or canceled. `waitUntilOpened` uses
`withTaskCancellationHandler`; cancellation atomically removes and resumes the
sole continuation by throwing `CancellationError`. `open` and cancellation
race through one actor transition, so exactly one resumes the waiter and the
loser is a no-op/typed duplicate. A second waiter or second open is a typed
conflict. Canceling a still-gated Task must therefore complete in bounded time
with `snapshotWaiterCount() == 0`; registry cancel-and-await can never hang on a
continuation that ignored Task cancellation.

A cancel request for a canonical execution ID with no live closure records
exactly one reason and returns `.latched`; a byte-equal duplicate is
idempotently `.latched`, while a different reason conflicts. With a live
closure the first caller freezes that reason and stores one shared in-flight
`Task<Void,Error>` before awaiting it. That Task invokes `cancelAndAwait`
exactly once. Actor reentrancy cannot create a second Task: every simultaneous
or later byte-equal caller while it is in flight awaits that same Task and
receives the same success or error; a different reason conflicts immediately.
Success atomically replaces the Task with the cached completed outcome until
receipt-bound removal and returns `.cancelledAndAwaited` to every waiter.
Failure delivers the same error to every current waiter, clears only the
in-flight Task, and leaves the live entry/reason retryable by an explicit
durable recovery cancel; it never reports false completion. Registration atomically installs
that closure. With no pending intent it returns `.installed`; only after that
return may coordinator call `startGate.open()`. With one pending intent it
removes the latch and creates/joins the same shared in-flight Task primitive to
cancel/await the still-gated Task, then
returns `.pendingCancellationConsumed` without opening the gate. The pending
path therefore constructs no adapter/provider/Board/config/process and never
calls `adapter.cancel`. A thrown cancel-and-await leaves the live entry
installed without an in-flight Task so durable recovery can retry; it never
reports a false cancellation. A cancel arriving while pending-consuming
registration awaits joins that same Task and cannot return early or reinvoke
the closure.

Both adapters synchronously install their inner execution-handle state before
returning the outer `AsyncThrowingStream`. Their existing
`cancel(executionId:) async throws` becomes a cleanup-only operation: it
cancels and awaits that inner Task and performs no Store write or terminal
submission. The stream continuation's synchronous `onTermination` handler may
only signal cancellation; it is never treated as await evidence. The
coordinator consumption Task uses a thread-safe release-once cleanup cell.
Its synchronous `withTaskCancellationHandler.onCancel` closure only marks
cancellation and creates/publishes one noncanceled cleanup Task if an adapter
has been installed; it never awaits. Adapter installation races through the
same cell, so a prior cancellation either prevents installation/effects or
publishes that same cleanup Task immediately. The operation's catch/finally
loads and `try await`s the exact published Task value before it can normalize
or rethrow `CancellationError`; no fire-and-forget Task is completion evidence.
That cleanup Task calls and awaits
`adapter.cancel(executionId:)`. Before adapter installation, Task cancellation
remains the zero-effect path. The inner Task checks cancellation before
provider creation and before every socket/config/process effect. Once a CLI
driver stream has begun, adapter cancel propagates to the process driver and
waits for TERM/grace/KILL, pipe drain, reap, Board stop, config cleanup, and
workspace release. ModelLoop follows the same ownership for its provider Task.
Thus a post-gate cancel awaits real cleanup, while a pre-gate cancel has zero
external effect.

The coordinator consumption Task normalizes its expected top-level
`CancellationError` to a successful canceled-completion only after the
applicable zero-effect or full transport cleanup obligations above have
finished. Consequently `cancelAndAwait` does not throw merely because it
requested cancellation. It throws only for process/Board/config/workspace
cleanup failure or typed process-outcome-unknown. Both a still-gated pending
cancel and a live post-gate cancel can therefore reach their cancellation
disposition and receipt-bound removal; expected Task cancellation never leaves
a spurious live entry.

Cancellation of the consumption Task performs transport cleanup but does not
invent, submit, or remove a durable terminal. After registry cancel-and-await
returns, coordinator alone runs Store recovery/terminal commit and then the
receipt-bound registry removal. A terminal that wins before the Store
cancellation transaction is handled only by `.terminalWon`; no second canceled
terminal or registry cancel follows.

Runtime owns one shared `EngineExecutionCompletionRegistryV1`; the completion
handle is never execute-local. Immediately after Store begin and before the
bind callback, coordinator atomically `lookupOrInstall`s the exact execution
handle. Every recovery directive uses that same operation before acting. The
actor calls `makeHandle` only when absent, canonical-validates the requested
ID, and requires the created handle's nonisolated ID byte-equal before storing;
there is no external lookup→install gap.
Coordinator `cancel(executionId:)` first strict-loads the Store row. An already
terminal row validates/accepts its receipt without installing a handle, then
the existing Void cancel API returns normally; it does not expose the receipt. A
running row atomically lookup-or-installs the same handle before requesting cancellation,
so runtime cancel, bind cancel, recovery, and execute all reach it by canonical
execution ID. `didInstall` is the sole authority for the terminal-won cleanup
branch; concurrent callers receive the already-stored winner rather than
constructing or rejecting a second handle.
If the subsequent atomic Store call returns `.terminalWon`, an already-existing
handle is awaited through its normal finalizer; a handle newly installed by
this cancel call is removed from the completion registry and completed with
that exact receipt without touching the active registry. Neither case creates
a cancellation latch or second terminal.

`execute` awaits the handle's single durable receipt; it does not treat the
consumption Task's return/throw as terminal evidence. A normal router/EOF
commit calls `complete` once. The handle's first Store `.requested`
cancellation creates and publishes one shared cancellation-resolution Task
keyed by the exact reason and invokes its stored resolver as
`resolveCancellation(self, reason)` before active-registry cancel. The resolver
therefore receives the exact handle whose lifecycle it must await; it never
captures an uninitialized handle, performs another registry lookup, or retains
a holder-box cycle. Runtime
cancel, bind cancel, recovery reconciliation, and any same-reason concurrent
caller join that same Task; a different reason conflicts. Its strict order is
active-registry cancel → if `.latched`, await the handle's one lifecycle
disposition; if `.cancelledAndAwaited`, treat registered cleanup as complete →
wait until the registry's cleanup in-flight result is cached/clear → one Store
canceled recovery/commit → one observer/finalizer → receipt-bound
active-registry `finishPending` for `.noTransport` or `remove` for
`.registeredCleanupComplete` → remove the byte-matching handle from the
completion registry → fulfill that still-retained handle reference. A failure is delivered
to every waiter and leaves the durable command retryable; an explicit retry
reuses Store replay but can create only one new resolution Task.

The lifecycle barrier is publish-once. Bind `.cancel`, a Store/recovery branch
that constructs no adapter, and any cancellation terminalization before
registration publish `.noTransport` before commit. Register returning
`.pendingCancellationConsumed`, or live cancel returning only after cleanup,
publishes `.registeredCleanupComplete`. A normal installed/open execution does
not publish until cancellation cleanup actually completes. Duplicate equal
publication is idempotent; a different value, second waiter, or terminalization
without publication is a typed conflict. Therefore a begin-to-register latch
cannot race canceled recovery with a later registration/transport Task.

The consumption Task's cancellation catch only completes the cleanup barrier
and returns; it never awaits the resolution Task, recovers, commits, observes,
or removes, avoiding a cycle with registry cancel-and-await. The outer
`execute` call waits for the completion handle in its noncancellable final path,
so it returns the same receipt produced by the sole resolution owner. This
ordering makes it impossible for child cleanup to wake execute before the
registry caches its in-flight outcome, and prevents dual terminal/remove
ownership. Every terminal finalizer requires both active-registry counts and
completion-registry count for that execution to be zero.

`remove` requires a byte-matching durable terminal receipt, an installed live
entry, and no pending/in-flight cancellation. `finishPending` requires a
byte-matching durable terminal receipt plus a pending entry and no live/inflight
entry; it is the only cleanup for a bind-cancel branch that never constructs an
adapter. Supplying the wrong execution, removing before terminal, consuming a
pending latch twice, duplicate register, or removing in-flight is a typed
conflict. `snapshotCounts` exposes only counts for observability/tests, never
IDs or reasons. Coordinator always durably calls the atomic Store cancellation
method before registry cancel/latch.

`RunningEntry` records optional execution ID and one fixed cancellation reason.
The bind callback verifies exact Card/Mission ownership, stores the ID once,
and returns cancel if halt/mission cancel already marked the entry. A bind
`.cancel` branch first obtains `.requested` from the atomic Store method, then
publishes `.noTransport` and joins the handle's sole cancellation-resolution
Task; that owner creates/replays the registry latch, commits once, and calls
`finishPending`. A byte-equal concurrent stop joins the same resolution. If the
Store instead returns `.terminalWon`, it follows the handle rule above and
touches neither active registry nor `finishPending`. Normal and recovery registration branch on the returned
disposition: `.installed` alone opens the gate and may consume; a later
registry cancel cancels/awaits that consumption exactly once.
`.pendingCancellationConsumed` goes directly to canceled recovery, never opens
the gate, never calls `adapter.cancel`, publishes
`.registeredCleanupComplete`, and joins the same resolution owner, which uses
receipt-bound `remove` because the live Task entry was installed. Recovery's
`reconcileCancellation` uses the same registration disposition: it never
follows pending-consumed with a second direct cancel. Any cancellation
directive that terminalizes without registration publishes `.noTransport` and
joins the same resolution owner; that owner requires/replays `.latched` and
calls `finishPending` after commit so no latch survives. A non-cancellation recovery
directive that durably terminalizes without registration creates no registry
state and calls neither `finishPending` nor `remove`; it verifies the exact
execution has zero registry state instead. All terminal paths end with
live/pending/in-flight counts zero.
Pre-begin Task cancellation writes nothing; begin-to-register cancellation is
held by the bind disposition/latch; post-register cancellation cancels and
awaits the exact coordinator consumption Task once.

Coordinator receives the nonthrowing routed-event observer. It calls the
observer only after `acceptRoutedEngineEvent` or terminal commit succeeds, never
on a Store error. Orchestrator maps accepted to `turnStarted`, progress to
`textDelta`, toolActivity to `toolStarted`, and cumulative usage to
`turnEnded`; sessionBound exposes nothing and terminal emits no synthetic
finished event. Terminal success reloads the durable Mission/Card projection.
Observer delivery cannot roll back or convert an already-committed engine
event.

Once terminal commit returns its receipt, coordinator enters a noncancellable
finalizer before returning or allowing its outer Task to finish. An
unstructured shield Task that does not inherit outer cancellation runs the
nonthrowing observer, releases the workspace/transport resources, invokes the
applicable receipt-bound active-registry cleanup, removes the byte-matching
completion handle from its registry, and only then completes the retained
handle reference with the receipt; it records the first cleanup error but no
earlier failure skips either registry cleanup attempt. The outer Task awaits that exact
shield Task even if canceled. A stop that receives `.terminalWon` never writes
another terminal or touches the latch, but it still awaits the bound outer
Task/handle finalizer and verifies this execution is absent from both
registries. Thus cancellation in
the commit→remove window cannot leak a live entry or bypass lease cleanup.

### 26.7 Engine-first startup, resume, halt, and orphan adoption

Startup recovery and manual resume use this exact gate order:

```text
close/retain closed dispatch gate
→ acquire/retain the existing StateDirectoryLock
→ inspect, quiesce, terminate, and confirm ESRCH for every validated old-boot process group
→ descriptor-sweep the now-quiescent owned runtime residue
→ initialize required engine help/registry
→ recover external-operation authority
→ EngineExecutionRuntimeV1.recover(missionId:nil, now:) all non-F2 directives
→ forward only deferCampDeletion to F2
→ legacy orphan adoption
→ proposal/planning healing
→ reopen only if every prior phase succeeded
```

The old-boot group phase is the first recovery action after the state lock and
closed gate. It precedes external-operation recovery, database healing, help
probing, and engine recovery because a crashed App's vendor/help/bridge child is
not controlled by the new gate. Unknown membership, identity drift, signal
failure, or non-ESRCH completion leaves the gate closed and performs no sweep
or later recovery phase.

Emergency stop and App shutdown never use the reopen tail. Their exact order
is: persist/retain the closed dispatch gate; mark every scoped RunningEntry
with one fixed reason; for every bound ID durably call runtime cancel and
accept `.terminalWon` without touching the latch; cancel and await every scoped
outer Task; run `recover(missionId:nil,now:)`; forward only F2 deletion
deferrals; recover
external-operation authority; run legacy orphan/open-Run handling only with the
engine exclusions below; run proposal/planning cleanup; then verify process,
socket, config, workspace lease, and registry counts are zero. Failure of one
cancel records the first sanitized error but does not skip any remaining
cancel, await, recovery, deferral, or checked cleanup. After cleanup, the first
error is rethrown/reported. Emergency stop remains halted; shutdown tears down
the runtime and exits without reopening. Shutdown's zero-count check is followed
by descriptor-relative validation/removal of the current boot's socket owner
file and now-empty private directory, parent fsync, checked release of that
final descriptor lease, and the sole authority `close()` call. Those steps all
run even when an earlier sanitized error was retained; their first additional
failure is aggregated rather than swallowed. Emergency stop never performs
this App-lifetime close.

Mission cancellation leaves the global gate state unchanged but atomically
marks the target Mission as nondispatchable for this operation. It applies the
same mark → bound-ID durable cancel → cancel/await all scoped Tasks →
`recover(missionId:target,now:)` → F2 defer → external-operation recover → excluded legacy
`markOpenRunsCanceled` → proposal/planning cleanup sequence only to that
Mission. It likewise aggregates the first sanitized error while continuing
all scoped cleanup. Other Missions may dispatch; the target cannot dispatch
again before the sequence returns successfully. An error keeps the target
visibly unsettled and cannot be converted into a legacy cancel.

Any engine recovery/help/cleanup failure keeps a closed gate halted and
prevents legacy adoption/reopen. `adoptOrphans` selects only running Cards with
no nonredacted `engine_execution` in any state for that exact Card or its exact
open Run; its open-Run update has the same two `NOT EXISTS` predicates, then
writes `card_interrupted` followed by `card_ready`. Every legacy
`markOpenRunsCanceled` path has the same exclusion. A terminal/nonredacted
engine row paired with an open Run or running Card is an engine projection
mismatch: it keeps the gate closed and emits the sanitized visible failure; it
is never adopted as legacy. Legacy code may never mark any historically
engine-owned Run interrupted/canceled or move its Card ready before/after
coordinator recovery.

Recovery asks the runtime for a fresh seed from the unchanged persisted
request, rebuilds context/tool handlers and workspace authority, selects the
current captured factory, and creates transport only in the directive branch
that truly dispatches. Revision-7 transient session injection remains exact.
No dormant CLI probe, latest-session lookup, request clone, profile-kind
switch, or legacy adoption fallback is allowed.

### 26.8 Production Orchestrator replacement and removal gate

Reconcile now performs: same-transaction ready-cause capture; runtime
`prepare`; exact running-entry reservation; runtime `execute` with bind
callback; durable observer/UI projection; and `runnerFinished`. A preflight
cause/context/workspace/provider/help/runtime-dir failure creates no engine
execution/Run/process/socket/config, emits a sanitized stable kernel failure,
and suppresses only that ready event for the process session. Raw key, token,
prompt, command output/path, session ID, external ID, error description, and
config bytes have no AgentLoop-owned OSLog, Kernel/domain event,
FailureReporter, proposal, receipt-detail, or sanitizer channel.

CLI resume deliberately does not use Codex `--ephemeral` or Claude
`--no-session-persistence`. The provider-native session store is a distinct,
user-owned persistence boundary and may contain the raw prompt, model output,
and tool transcript required by those vendors to resume. AgentLoop never reads,
parses, copies, hashes, reports, or logs its paths or bytes; it persists only
the external session ID already covered by the execution contract. Before a
CLI factory may advertise `.sessionResume`, it descriptor-opens without a
shell the provider root selected by `CODEX_HOME` or exact `$HOME/.codex`, and
`CLAUDE_CONFIG_DIR` or exact `$HOME/.claude`, respectively. Every existing
component is descriptor-walked no-follow. System ancestors through `/Users`
must be root-owned and not group/other writable; from the canonical user home,
or an equivalently validated custom provider-root parent, every component must
be current-UID and not group/other writable. The final provider root must be a
current-UID directory. An absent/drifting/untrusted root makes
only that CLI resume factory unavailable before Store begin. AgentLoop does not
change permissions or sweep provider-owned data. A future requirement for zero
provider-native transcript persistence must instead enable the two ephemeral
flags and mark CLI session resume unsupported; it cannot claim both guarantees.

After the new path is green, delete the complete legacy branch that constructs
`CardExecutionContext`, `ModelLoopBackend`, `CliProcessBackend(db:...)`, or
calls `CardExecutionBackend.run`. Delete
`Sources/AgentLoopCore/Loop/CardExecutionBackend.swift`; all assigned tests
already use final driver surfaces. Product source must have zero
`CardExecutionBackend`, zero `ModelLoopBackend`, zero legacy backend initializer,
zero `backend.run(context:)`, and zero execution selection by profile kind.

The final removal gate also requires zero
`EngineAdapterCapabilityV1`, zero
`EngineAdapterCapabilityUnavailableErrorV1`, zero unavailable operation body,
zero compatibility `stopChecked`, zero DB-bearing CardRunner/Cli backend, and
zero production `ApprovalGateHandler` engine reference. No temporary optional
driver, empty stream, fake descriptor/help, `try?` cleanup, catch-and-retry
fresh session, or legacy fallback may survive.

### 26.9 Existing identities and bounded verification

Revision 8 adds no focused identity. Strengthen existing identities without
changing their names or original causal assertions:

- 062: reversed factory order, selected request/transport closure once,
  unselected provider/CLI closures zero, engineKind/model/budget exact;
- 069: bind callback and pending cancellation at pre-begin, post-begin,
  pre-register, pre-gate, and post-gate windows; pending-before-gate has zero
  adapter/provider/driver/process effect, post-gate cancel awaits exact cleanup,
  synchronous cancellation handlers publish but never await/fire-and-forget,
  expected CancellationError is normalized only after the shared cleanup Task,
  simultaneous same-reason callers join one in-flight result, different reason
  conflicts, failed cleanup is retryable, bind-callback throw reaches one
  canceled receipt with zero registry residue, each cancel is consumed once,
  child cleanup paused before registry outcome caching cannot wake a second
  recovery/remove owner,
  terminal-before-cancel-CAS returns terminalWon,
  terminal leaves registry counts zero, committed observer runs only after the
  durable row, and forced Store failure emits zero observer;
- 071/079: exact App/test provider versus CLI driver creation, safe tool plan,
  request execution ID as ranch session, stdin prompt with zero secret/prompt
  argv bytes, descriptor-local no-SIGPIPE, immediate-child-exit plus oversized
  multi-short-write/EPIPE cleanup, Codex explicit-skill-token rejection,
  Codex/Claude managed-policy nil/present fail-closed gates, Claude Git/subprocess
  environment scrubbing, provider-native session persistence treated only as
  the explicit resume boundary, and no legacy DB backend;
- 075: exact Developer-ID requirement/CDHash, production npm Codex
  wrapper-to-native resolution, staged identify/probe/launch identity and hash
  drift, suspended-spawn PID/image validation before SIGCONT, Board peer-PID
  bridge validation, concurrent one-probe cache, exact signed Codex 0.144.5 version/help
  gate plus no relaxed-config retry,
  hung/forking/infinite-output probe deadline/reap, failed-probe residue-free
  retry, dormant CLI isolation, and active missing CLI recovery halt;
- 076: normal/startPrepared/resume/recovery all use captured transport,
  unsupported resume starts fresh without catch retry, engine recovery precedes
  legacy adoption, CLI driver construction is zero for every nondispatch
  directive and exactly one on `.startNow` or a Store-validated external
  dispatch/cancel recovery directive;
- 080: production `prepareCurrent` derives all claims/limits/tools from real
  rows, definitions/bindings/prompt/handlers are one source, logical names drive
  safety rules while provider-visible names render every call, CLI prompt has
  no bare tool call, selected MCP causes zero manager start/list/call, and
  schema-2 instruction canonical bytes/hash are exact, schema-1 running recovery
  halts without rewrite, and stale/forged claims fail;
- GoldenPath/Halt tests: App-owned live environment, ready-event idempotency,
  cancellation ordering with cleanup-after-first-error, system `/var` temp
  alias acceptance plus user symlink rejection, actual AF_UNIX byte bound,
  short-name collision handling, bind-never-predeletes, identity-bound stop,
  exact locked state-root/owner bytes, descriptor-lease close/fault behavior,
  mode-0500 authority unseal/unlink/fsync, surviving main/help/bridge group
  STOP/revalidate/TERM/KILL/ESRCH before any recovery, PID drift and unknown
  group failure with unrelated processes untouched, runtime-dir cleanup,
  signed standalone bridge packaging, and no old backend;
- Harvest tests: initial/rework/orphan ready writers end with canonical
  `card_ready`;
- AskUser tests: nonapproval answer writes `user_request_answered` before its
  unique final answered-request `card_ready`, replay adds neither row, and the
  exact request resolves its own predecessor; and
- ApprovalGrantContract tests: approval answer ends with canonical
  `card_ready`, replay adds none, and no engine predecessor is inferred.

Deterministic cause tests also prove two ready cycles yield different keys,
same event replay yields one execution, an exact answered request resolves its
own older execution despite a newer unrelated session, legacy question yields
nil, and ambiguous/broken/missing cause makes zero engine write. No sleep race,
raw SQL success shortcut, fake latest session, OR assertion, or product
unavailable error may satisfy a gate.

Implementation order after independent Revision8 approval is fixed:

1. ready-writer/cause resolver and existing tests;
2. context/workspace production builders and one-source tool plan;
3. factory request/transport capture plus help identity/cache;
4. App environment/runtime directories/composition generation;
5. coordinator bind/latch/observer/recovery order;
6. Orchestrator dispatch replacement and legacy file/branch/scaffold deletion;
7. exact 062–080, exact 001–080, all touched predecessor tests, then full
   `swift run RunTests` with one complete log and separate RUN/TEE statuses;
8. Core and App builds, privacy/source/diff/boundary gates, packaged preview,
   and independent implementation review with 0 P0 / 0 P1.

Focused green is not acceptance. Any outside-file assertion that a correct new
path genuinely invalidates blocks this revision for a reviewed allowlist
successor; implementation may not edit it opportunistically. No build, test,
App, process, migration, package, or implementation byte is authorized by this
plan append itself.

## 27. Revision 9 — selected executable authority for managed-policy validation

Revision 9 is the single-finding successor to the official Revision-8 verdict
`CHANGES REQUIRED — 0 P0 / 1 P1`. It overrides only the two managed-policy
validator signatures and their registration/prelaunch invocation described
below. Every nonconflicting §26 contract remains controlling. This successor
adds no file, identity, schema, migration, dependency, event, capability,
runtime branch, or product behavior.

Its frozen predecessor is §26 plan SHA-256
`a3a078cd85050c9d8d87533759319227b0032f13cb149b590bd236838464d0b8`
at 330,868 bytes / 6,185 lines. The official Review01d successor containing the
finding is SHA-256
`ca63faeb5f3bba38d869a27c09acbd0e29ee7720c58f332665560c38f4ef3be5`
at 42,396 bytes / 721 lines, with its first 36,964 bytes still SHA-256
`ed9c8a46e46bafca72a73f395e1f51b6968030404c01fa8a03c209b5d0f847c8`.
The 109-line allowlist remains byte-identical at SHA-256
`83db82562cd412e32a6920e222e3dfbafab24a63ebc2fa6a6d3b984e01061e53`;
the NUL-safe boundary remains dirty `671`, allowlisted present `88`, outside
`583`, outside-manifest-v1
`1a19caaa14031b57885af39af6c8bd55d31ef6fe312d86c92ffdb7ab4dd80690`.

### 27.1 Exact authority-bearing validator surface

Add this single package typealias in the existing §26 executable-authority
owner:

```swift
package typealias EngineCliManagedPolicyValidateV1 =
    @Sendable (
        _ executableAuthority: CliExecutableAuthorityV1
    ) throws -> Void
```

The existing `validateCodexManagedPolicy` and
`validateClaudeManagedPolicy` stored fields in both
`EngineExecutionEnvironmentV1` and `EngineExecutionTransportSeedV1` are
exactly `EngineCliManagedPolicyValidateV1?`. They retain their existing field
and initializer positions, optionality, and provider-specific names. No
zero-argument overload, default implementation, ambient current-generation
lookup, or validator-owned executable resolver remains.

Each live AppStore validator treats its argument as the sole executable
authority for every §26 managed-source, version, account/auth, process-group,
and before/after identity check. The Codex closure first requires
`executableAuthority.kind == .cliCodex`; the Claude closure first requires
`executableAuthority.kind == .cliClaude`. Each invokes its bounded staged
binary only through `executableAuthority.stagedPath` and revalidates all
authority bytes already frozen in §26. PATH re-resolution, staged-directory
scanning, selecting another same-kind cache generation, or consulting a
mutable global/current authority is forbidden.

### 27.2 Exact registration and gated prelaunch flow

After one CLI help probe succeeds and before its factory is inserted into the
partial immutable registry, runtime invokes the matching validator exactly
once with that exact `CliHelpSnapshotV1.executableAuthority`. A nil validator,
kind mismatch, byte drift, or thrown policy result makes only that CLI factory
unavailable and leaves Store/registry execution state unwritten; no other
provider is substituted for a selected Card.

The CLI factory's `prepareRequest(profile:helpSnapshot:seed:)` requires a
nonnil matching help snapshot, binds one local
`selectedExecutableAuthority = helpSnapshot.executableAuthority`, and requires
its kind match the factory. It captures both that exact authority and the
matching validator in the returned gated `makeTransport` closure. Immediately
after the Store-authorized `.startNow` gate and before constructing any CLI
driver, Board server, token-bearing config, or vendor process, that closure:

1. requires its captured prepared authority byte-equal the captured selection
   snapshot authority;
2. invokes the matching validator exactly once with that same value; and
3. passes that same value without transform into
   `CliEngineRuntimeConfigurationV1`, `CliEngineCommandInputV1`, and
   `CliProcessLaunchRequestV1`.

The validator does not return or replace an authority. The prelaunch closure
does not re-read the help cache. Command/spec equality, backend no-follow
revalidation, suspended-child image verification, and checked cleanup remain
the independent later gates from §26. A prelaunch validator failure creates no
driver/process/Board/config effect and follows the existing typed
post-`startNow` terminal/cleanup path; it never retries with a different
generation or relaxed policy.

Recovery uses the authority captured by the exact persisted descriptor's
current registry selection. `makeRecoveryTransport` applies the same kind and
byte-equality checks, invokes the same authority-bearing validator in its gated
dispatching branch, and passes that authority through the same runtime/input/
launch-request chain. A non-dispatch recovery directive performs zero policy
probe. Descriptor or executable-generation drift remains the existing visible
recovery failure and never triggers adoption or fallback.

### 27.3 Focused proof and successor gate

Strengthen only the existing 071, 075, and 079 fixtures without changing their
identity strings. For both Codex and Claude they must prove:

- factory registration calls the matching validator once with bytes exactly
  equal to the successful selected help snapshot authority;
- gated normal prelaunch calls it once again with the same bytes, and recovery
  calls it only for a validated dispatching directive;
- two retained same-kind generations cannot cross: passing generation B to a
  selection/config/launch chain captured from generation A fails before
  driver/process/Board/config effect;
- wrong provider kind, nil validator, thrown validator, and one-field authority
  drift are typed visible failures with zero ambient lookup and zero fallback;
  and
- the final runtime configuration, command input, and launch request each carry
  the exact generation-A authority unchanged.

No new test identity, file, allowlist row, real credential/provider action, or
Swift/build/test/App execution is authorized by this plan-only successor.
Implementation remains closed until an independent reviewer appends to the
existing Review01d a Revision-9 verdict of `APPROVED — 0 P0 / 0 P1` against one
frozen full-plan SHA. A `CHANGES REQUIRED` verdict is retained as history and
blocks implementation; no reviewed bytes are rewritten.
