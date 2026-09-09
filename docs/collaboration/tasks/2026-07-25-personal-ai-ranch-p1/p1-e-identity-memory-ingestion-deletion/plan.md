# P1-E — Identity / Residency / Camp Lifecycle / Memory / Active Ingestion Deletion Plan

> Revision: 2 frozen  
> Date: 2026-08-26  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Entry authority: P1-D acceptance SHA-256
> `bef50bba0f5baf6d0fbe4a194b97b1fe05c247ba211dc6f111cf145b5c7566bd`

## 1. Decision, authority, and entry gate

This is the decision-complete implementation plan for canonical P1-E. Its
authority is:

- accepted master spec §§5–7, 22–24, 29 and the accepted P1 route;
- canonical P1 stage §§14–15, 18.6, 19, 26, 27, and the P1-E completion gate;
- canonical P1 plan §§7, 10, and 11, including the sealed ordinary Ingestion
  deletion contract added after R6-P1-1;
- accepted P1-D implementation and acceptance evidence.

The frozen authority hashes are in §5. P1-D is closed and may not be
re-audited inside this leaf. P1-E product, test, Package, schema, migration,
and runtime writes remain closed until a read-only review of this exact plan
and exact machine allowlist returns `APPROVED — 0 P0 / 0 P1`.

The user explicitly directed Codex to proceed without Claude and without
delegated agents. Plan Review01 and implementation Review02 are therefore
disclosed same-agent read-only passes and must not claim independence.

P1-E delivers five linked boundaries:

1. v16 identity/lifecycle/scope/provider/memory schema and replayable backfill;
2. global Cow identity plus Camp residency/bridge authorization;
3. versioned Memory with provenance and atomic P1-D invalidation propagation;
4. durable Camp-scoped provider dispatch plus immutable legacy scopes;
5. active-Camp ordinary Ingestion deletion with a Store-only sealed command,
   connection-local raw SQLite permit, typed commit resolution, and truthful UI.

P1-E deliberately does **not** expose archive/unarchive/Camp deletion, run a
Camp deletion worker, create v17 Engine/Artifact/Discussion/Attention/Growth
schema, or implement any P1-F1/F2 product flow.

## 2. Bounded execution model

P1-E remains one acceptance leaf, but implementation is split into five
ordered TDD bands. Each band has its own pure-red evidence and completion
gate. A later band cannot authorize an earlier red or defer it to F1/F2.

| Band | Scope | Entry | Completion gate |
|---|---|---|---|
| E1 | v16 migration, backfill, SQL guards, raw-UDF lifecycle, dual-SQLite carriers | Review01a approved | tests 01–16 green; v16 schema is 67/171/67; v15 rollback snapshots exact |
| E2 | Cow/Residency/Bridge/Lifecycle read fence/Memory/P1-D invalidation | E1 green | tests 17–32 green; no retirement API exposed |
| E3 | legacy chat/note/event scope and Camp provider dispatch | E2 green | tests 33–48 green; raw scope/provider authority closed |
| E4 | sealed active Ingestion deletion Store/UDF/replay/resolution/races | E3 green | tests 49–80 green; both SQLite real lanes and four P0 counterexamples green |
| E5 | Application/UI four-phase pending command and source/privacy gates | E4 green | tests 81–90, build, isolated preview, source gates, and authoritative full run green |

For each band:

1. add only that band's exact tests;
2. save the expected capability failure to its immutable `red-eN-*.log` with
   command and tee statuses under Bash `set -o pipefail`;
3. make the smallest root-cause implementation inside the allowlist;
4. run the band tests plus all earlier P1-E tests;
5. stop the band audit once its gate is met and proceed to the next band.

If implementation discovers an authority conflict that changes schema,
ownership, public surface, allowed files, test obligations, or P1-E/F
boundary, write it to `blocked.md`, freeze a bounded plan revision, and review
that revision before further product writes. Ordinary implementation choices
already fixed below do not reopen planning.

## 3. Frozen product and technical decisions

### 3.1 Migration and database bootstrap

1. The migration identifier is exactly `v16-p1-identity-memory`, immediately
   after accepted `v15-p1-outcome-contracts`; no v17 identifier or object is
   introduced.
2. The normative Stage §18.6 SQL body is the byte authority: 1,998 SQL lines,
   80,830 bytes, SHA-256
   `3a86de973a0feff2a5a26bbd6d721464382f6cd13c667b062501808a5325fd71`.
   `AppDatabase.swift` carries it once as package-read-only
   `p1EIdentityMemoryMigrationSQL` between unique P1-E markers without semantic
   rewriting; tests hash the runtime UTF-8 value, not indented source bytes.
   The migration requires the exact four-line late-drop prefix beginning
   `DROP TRIGGER event_no_update;` to occur once, splits immediately before it,
   executes the authority prefix, runs the typed chat/note/event resolvers plus
   count/FK assertion barrier, then executes the untouched authority suffix in
   the same GRDB migration transaction. Missing/duplicate boundary is a typed
   migration failure. This is the only split and the only Swift work inserted
   between authority bytes; no resolver/DML/assertion occurs after the suffix
   begins.
3. The through-v16 checkpoint is exactly 67 tables, 171 indexes, and 67
   triggers. The through-v17 checkpoint remains 79 tables, 208 indexes, and
   84 triggers. The predecessor checkpoints remain v11=2, v12-durable=4,
   v12-schedule=4, v13=4, v14=8, v15=16 triggers.
4. Migration order is fixed: complete tables/indexes/rebuilds/renames, staged
   child copy, backfill/resolution/count/FK barrier, five exact trigger drops,
   then all trigger creation. The four surviving-table drops contain no
   `IF EXISTS`; no DML, resolver, backfill, or assertion follows them. Every
   drop and trigger-install midpoint rolls back to byte-equivalent canonical
   v15 logical schema/data/16-trigger snapshots.
5. v16 fails fast on early `campDeletion`, dangling/cross-Camp/ambiguous scope,
   copy/FK drift, archived active-work residue, and old v12/v15 diagnostic rows
   that the 384-row v16 truth table classifies as illegal. It never repairs a
   poison row silently.
6. `AppDatabase` creates and strongly owns one
   `ActiveIngestionDeletionSQLPermitRegistryV1` before constructing its pool,
   captures that exact registry in `Configuration.prepareDatabase`, installs
   the UDF on every connection there, and only then runs the migrator.
7. `Package.swift` adds exactly one direct
   `.product(name: "GRDBSQLite", package: "GRDB.swift")` dependency to
   `AgentLoopCore`. It adds no package, target, product, setting, or other
   dependency change. `Package.resolved` remains byte-identical.

### 3.2 Cow, residency, bridge, and lifecycle

1. Cow identity is global. Every legacy Companion backfills one Cow with the
   same ID. Companion remains the P1 compatibility projection.
2. A valid non-null `companion.campId` backfills one active residency with ID
   `legacy-residency:<cowId>:<campId>` and idempotency key
   `legacy:<cowId>:<campId>`. Nil creates no residency and no authority.
3. Residency states and transitions are exactly:
   `requested -> authorized -> active <-> paused`, with
   `authorized|active|paused -> left|revoked`. Left/revoked rows never revive;
   rejoin creates a new ID. Duplicate commands replay; conflicting transitions
   fail before writes.
4. `CowResidencyStore` is the only residency/bridge mutation owner and exposes
   `requireActiveResidency`, `residentCows`, and `authorizedMemory`. A missing,
   paused, left, or revoked residency throws a typed authorization error; it
   never returns an empty result as an authorization substitute.
5. A bridge is directional, scope-bounded, time-bounded where configured, and
   revocable. Cross-Camp reads without an exact active bridge fail typed.
6. `camp_lifecycle` is the source of truth. E exposes only read helpers and
   transaction-only `requireActiveCampWrite(active + exact version +
   camp.archived=false)`. It never accepts a deletion capability.
7. E does not expose `archiveCamp`, `unarchiveCamp`,
   `requestCampDeletion`, repair/resolution commands, a deletion claim/permit,
   or a deletion worker. The v16 lifecycle/deletion ledger is schema-ready for
   F2 only.
8. The current legacy `setCampArchived` product route is closed in E so v16
   cannot split `camp.archived` from lifecycle truth: InputWorkflowController,
   AppStore, and RootView remove the action and visible archive/unarchive
   controls. The Core method remains only as an exact compatibility symbol so
   existing test targets compile; its release branch always throws typed
   `CampLifecycleCommandUnavailableError`, while its DEBUG branch is a
   fixture-only dual-write helper. It has no product caller or mutation
   authority in release. F2 later replaces it with reviewed commands.
9. Every post-v16 Camp creation transaction creates lifecycle v1. Every new
   Companion creates/updates its same-ID Cow identity in the same transaction;
   a nil Camp creates no residency. Camp guide/base-Cow provisioning also
   creates the exact Cow and active residency atomically, so migration backfill
   is not the only way to obtain post-v16 authorization.

### 3.3 Legacy content/event scope and provider dispatch

1. `LegacyContentScopeStore` inserts immutable thread/note scope before the
   content row. Guide is Camp-scoped, DM is globalCow, and cowork note requires
   exact Mission/Camp evidence. Raw post-v16 message/note insertion fails.
2. `LegacyEventScopeResolver` owns the exhaustive mapping for all 45 accepted
   `EventKind` values. `EventKind.allPersistedKinds` is added as the immutable
   public vocabulary and must equal the resolver key set.
3. The existing `AppDatabase.appendEvent` name may remain only as a
   package-internal compatibility funnel whose entire implementation delegates
   to `appendLegacyEventAndScope`; it is no longer raw write authority.
   `EventRecord.insert` may occur only inside that typed owner or migration
   fixtures. Missing/mismatched scope triggers abort.
4. `CampProviderDispatchStore` is the sole Camp provider checkpoint owner.
   Guide and guide/closeout/cowork distillation use
   `replaySafeInference`; DM/global distillation and connection tests are typed
   global and create no Camp dispatch row.
5. The Camp flow is message+work atomically, prepare, start+event+fence commit,
   network, returned checkpoint+event+fence commit, consume from checkpoint,
   then final output+work success atomically. Returned never recalls provider.
   A started/no-response row must be abandoned before an exact bounded replay.
6. Lifecycle fence wins against post-fence dispatch, response, tool, reply, or
   note commit. Unknown external-write provider routes fail before dispatch.
   Guide tools are read-only search/status plus receipt-deduplicated
   `propose_squad`.
7. `GuideChatService`, `MemoryDistillService`, `Distiller`, and `Orchestrator`
   no longer own an unregistered provider plus fire-and-forget task; they hand
   durable work/dispatch to the supervisor/store. Historical unsafe started
   rows close with `provider_effect_unknown` and an observable safe intent.

### 3.4 Memory and downstream invalidation

1. `MemoryRecordStore` is the sole writer of versioned Memory and append-only
   dependencies. Raw/working records may be created but are not trusted.
2. Camp knowledge/global preference promotion requires user confirmation or
   independent-source provenance. Inference remains explicitly inference.
3. Outcome-based skill requires accepted Outcome plus valid Verification; it
   cannot be created from delivery, model claims, invalid Verification, or an
   unaccepted Outcome.
4. Active content has exactly one of `bodyText` or `contentRef`; tombstone has
   neither. Deletion erases the private carrier and keeps only non-sensitive
   IDs/hashes/enums/time.
5. P1-D downstream invalidation now takes a required `MemoryRecordStore`
   transaction participant. return/revoke/Verification invalidation/new
   Outcome version/dependency deletion and Memory
   `needsReview|invalidated|deletedTombstone` commit or roll back together.
   There is no optional callback or future Growth no-op.

### 3.5 Active-Camp ordinary Ingestion deletion

1. `IngestionDeletionStore` is the only factory, executor, resolver, permit
   runtime caller, specialized receipt/scope/event/outbox writer, and physical
   `ingestion_item`/`rumination_result` mutation owner.
2. Prepare accepts only an existing complete `CommandEnvelopeV1`, `campId`,
   `ingestionId`, and scope. It performs one consistent `pool.read`, derives
   lifecycle/rows/snapshots/counts itself, performs zero writes and installs no
   permit, and returns an opaque handle plus a safe preview with no private
   content.
3. `resultOnly` accepts only unredacted/unterminated `needsReview` or
   failed-with-result, exact unmaterialized result, and five zero blockers. It
   deletes exactly one result then CAS-updates ingestion to queued with counts
   `1/0/1`.
4. `sourceAndResult` accepts only unredacted/unterminated
   `queued|failed|needsReview|discarded`, optional exact unmaterialized result,
   and five zero blockers. It deletes 0|1 result and exactly one ingestion with
   counts `0|1/1/0`.
5. `everythingIncludingProjection` always throws
   `projectionDeletionUnsupported` before evidence or mutation. Candidate and
   link DELETE are permanently forbidden.
6. The five blockers are exact live counts for knowledge link, any candidate,
   nonterminal rumination work, open attempt, and nonterminal provider
   dispatch. All five are fixed zero in the sealed command, whole hash,
   receipt, event, permit, live revalidation, and finish.
7. Receipt/event safe JSON exact allowlists are 23 and 21 keys. They contain no
   raw/title/URL/result/user-edited/actor/device/account content. The full
   envelope is bound through the whole hash and dedicated event columns.
8. Event ordinal is zero and key is
   `<commandKey>#0000:ingestion:<ingestionId>`. Exactly one event and one
   matching outbox exist. Replay validates the complete receipt/scope/event/
   outbox graph before returning and never resets a progressed outbox.
9. The only mutation trust boundary is persisted guards plus an exact
   connection-local transaction generation UDF plus the Store/source gate.
   Previously committed evidence never independently authorizes a later
   mutation.

### 3.6 Raw SQLite permit and resolution

1. `ActiveIngestionDeletionSQLPermit.swift` is the only source importing
   `GRDBSQLite` or referring to raw SQLite UDF/pointer/autocommit symbols.
2. The only production registration call is exact
   `sqlite3_create_function_v2(pointer,
   "agentloop_active_ingestion_deletion_permit_v1", -1, SQLITE_UTF8,
   retainedContext, xFunc, nil, nil, xDestroy)`. There is no
   `DatabaseFunction`, deterministic flag, or DIRECTONLY flag.
3. Registry state is instance-owned and synchronized behind one private
   boundary. It publishes `installing` before the unlocked C call, reconciles
   after it, detects duplicate pointer registration before a C call, uses a
   random nonce, and keeps only weak cell state. Sticky lifecycle mismatch
   blocks later setup, mutation, and resolution.
4. SQLite exclusively owns the retained context. `xDestroy` performs exactly
   one `takeRetainedValue`, invalidates the exact cell generation, and removes
   the exact key/cell. Failure paths never manually release or call the
   destructor. BUSY, close-v2 zombie, teardown-after-setup-throw, and pointer
   reuse follow Stage §14.2 exactly.
5. The only DEBUG **raw-permit capability** surface is the closed
   internal-fixture probe with the seven lifecycle scenarios and five cleanup
   mismatch cases. It returns immutable counters/booleans and no pointer, key,
   nonce, cell, context, permit, Database, closure, or install/lookup
   capability.
6. Mutation lookup requires exact instance/pointer/nonce/writer/in-transaction/
   autocommit=0. Resolution lookup requires exact writer, no transaction,
   autocommit=1, and no active/finished generation, and returns Void.
7. UDF signatures are exact 53 (`deleteIngestion`) and 63 (`deleteResult`)
   arguments. Any type/nullability/arity/order/generation/cursor mismatch gives
   one stable no-content SQLite error and consumes nothing.
8. Execution uses one serialized `pool.write`, replay/preflight first, then
   full live revalidation, writer-cell generation, receipt→scope→event→outbox→
   resultMutation→ingestionMutation→finish, immediate `changesCount` checks,
   `afterNextTransaction` invalidation, and unconditional exact-generation
   `defer` cleanup. A guarded statement error is never retried in-transaction.
9. One private shared validator serves prepare relaunch scan, new-key
   preflight, same-key replay, and resolver. It reconstructs canonical envelope
   and typed payload and rejects self-consistent forged persisted hashes.
10. The only resolver uses the same pool's `writeWithoutTransaction`; its first
    executable operation is `assertNoActiveGenerationForResolution`. It is
    SELECT-only and returns exactly committed, notCommitted, or
    resolutionPending(commitOutcomeUnknown|integrityBlocked|terminalConflict).

### 3.7 Worker races and UI truth

1. Feed/Rumination start/complete/fail/cancel/materialize use active lifecycle
   plus ingestion/result/work version CAS inside their write transactions.
   Ordinary deletion and late provider/worker callbacks have one SQLite winner;
   a loser cannot recreate rows or projections.
2. `InputWorkflowController` owns one session-local
   `PendingActiveIngestionDeletion` with phases
   `prepared|executing|executionResolutionPending|committedRefreshPending`.
   One confirmation generates one envelope/key and calls prepare once.
3. Prepared cancel clears. Executing cancel/dismiss does not clear the handle,
   cancel the underlying mutation, or guess commit state. notCommitted returns
   the same handle to prepared. committed enters refresh-pending.
4. Refresh failure retains the same command/result/trace; retry replays the
   same receipt/key before refresh. Success refreshes inbox/dashboard before
   closing. Explicit committed dismiss is not undo and mints no key.
5. commitOutcomeUnknown permits only same-handle read resolution;
   integrityBlocked permits no mutation and requires repair; terminalConflict
   permits only explicit abandon, ordinary reload, then a new confirmation.
6. Pending state is not durable. Relaunch restores only a complete committed
   graph/projection or a complete rollback; it never restores a stale phase,
   auto-replays, or auto-mints a key.
7. UI shows exactly two executable scopes and states that only unmaterialized
   source/rumination data is removed and Camp results are not. Failure remains
   on the page with a stable trace; there is no optimistic close or fake
   success.
8. UI failure evidence uses two release-zero DEBUG seams, not production
   fallbacks. `IngestionDeletionStore` has a package-internal exact checkpoint
   enum whose preview case throws before evidence writes; controller refresh
   has a fail-once port. AppStore activates them only when
   `AGENTLOOP_UI_PREVIEW=1` and exact
   `AGENTLOOP_P1E_DELETION_PREVIEW_SCENARIO` is
   `storeBeforeEvidenceFailure` or `refreshAfterCommitOnce`. Normal mode,
   unknown values, and release builds cannot activate either seam. The seams
   accept no caller row facts, mutation callback, Database, permit, or raw
   SQLite capability, and source/release-symbol gates prove containment.

## 4. Exact allowlist

The executable allowlist is the 88 unique newline-delimited paths in
`scope-allowlist.txt`, SHA-256
`ab95ea1f33ff41de6819f32602ac5fe0bf5988085bb6cfed9a2a8819687ecb60`.
It contains exactly 67 product/test/Package/matrix paths and 21 task evidence
paths. The source/scope gate reads this file directly; Markdown is not parsed
to reconstruct scope.

The 24 new source/test paths are exactly:

- `Sources/AgentLoopCore/Domain/CowIdentity.swift`
- `Sources/AgentLoopCore/Domain/CampResidency.swift`
- `Sources/AgentLoopCore/Domain/CampBridge.swift`
- `Sources/AgentLoopCore/Domain/MemoryRecord.swift`
- `Sources/AgentLoopCore/Domain/IngestionDeletion.swift`
- `Sources/AgentLoopCore/Database/CowResidencyStore.swift`
- `Sources/AgentLoopCore/Database/MemoryRecordStore.swift`
- `Sources/AgentLoopCore/Database/CampLifecycleStore.swift`
- `Sources/AgentLoopCore/Database/IngestionDeletionStore.swift`
- `Sources/AgentLoopCore/Database/ActiveIngestionDeletionSQLPermit.swift`
- `Sources/AgentLoopCore/Database/LegacyContentScopeStore.swift`
- `Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift`
- `Sources/AgentLoopCore/Database/CampProviderDispatchStore.swift`
- `Sources/AgentLoopApplication/CowResidencyWorkflowController.swift`
- `Sources/AgentLoopApplication/CampMemoryWorkflowController.swift`
- `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift`
- `Sources/AgentLoopTestSuite/CowResidencyContractTests.swift`
- `Sources/AgentLoopTestSuite/CampIsolationTests.swift`
- `Sources/AgentLoopTestSuite/MemoryProvenanceTests.swift`
- `Sources/AgentLoopTestSuite/P1ContractIntegrationTests.swift`
- `Sources/AgentLoopTestSuite/LegacyScopeMigrationTests.swift`
- `Sources/AgentLoopTestSuite/CampProviderDispatchTests.swift`
- `Sources/AgentLoopTestSuite/IngestionDeletionContractTests.swift`
- `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`

All other allowlisted paths already exist and may change only for the exact
responsibility named by canonical plan §7.1 and §3 above. In particular:

- `Package.swift` may change only as specified in §3.1.7;
- matrix runner/script may change only for v16 predecessor/literal/real lanes;
- accepted P1-D tests/stores may change only for required Memory invalidation
  participation or v16 compatibility;
- App/UI carriers may change only for the sealed deletion workflow and P1-E
  projections;
- `Sources/AgentLoopApp/Views/RootView.swift` is the sole derived carrier beyond
  canonical §7.1 and may change only to remove the currently exposed legacy
  archive/unarchive controls; its entry SHA-256 is
  `558c49ea0379e4e6b3c16e379b45f26a9bd92136094d128797b925228c3511cd`;
- existing knowledge/chat/rumination/product/orchestrator files may change only
  to route through residency, scope, lifecycle, durable provider, and version
  fences.

No path outside `scope-allowlist.txt` may change during P1-E implementation.
Top-level P1 status/ledger synchronization is a later closeout operation after
immutable P1-E acceptance and is not implementation scope.

## 5. Frozen inputs, pre-images, and dirty boundary

### 5.1 Authority and protected inputs

| Input | SHA-256 |
|---|---|
| Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-D acceptance | `bef50bba0f5baf6d0fbe4a194b97b1fe05c247ba211dc6f111cf145b5c7566bd` |
| `Package.swift` pre-image | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` protected | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| RunTests protected | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `CommandEnvelope.swift` protected | `a2117c80b0c7d052b35b38de98f9b9f846fc965cb9b2f9278c18455b6081f39e` |
| `DomainEvent.swift` protected | `876896f4d48ab1614630dcbf7075b2a4bcb1a8ba309605c10eeb976c1e59b925` |
| `CanonicalContractCoding.swift` protected | `b15c1f9fc8d602b834eb517cefc7e27437da3d576cc4d388d9f6472032ccdcaa` |
| `CanonicalJSON.swift` protected | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |

### 5.2 High-risk implementation pre-images

| File | SHA-256 |
|---|---|
| `AppDatabase.swift` | `8f33661c321109096f11646e6ccefc4458c5b5887e4e903d89593c34ab1a8c34` |
| `Records.swift` | `017f43c4d8976c763872c438d20975238d9329caab89f540a0d52e6fa3aa2543` |
| `EventKind.swift` | `67ca50ba59b0ec191a3543e7af5a39164e644909219a6b621a929d084991c117` |
| `DurableWorkStore.swift` | `71e2dd602cf59647fd9dc5c0bd5a74eeb770f6b4d91010744c4a40b91ae28b6e` |
| `KnowledgeStore.swift` | `1b97a0495576d0556cdab26e01edcfc516facaa35bd0659d7dd1bc2c9a291a24` |
| `OutcomeStore.swift` | `f44189917f456f8d72930765e6354f650fbb76f48ae075e696bcd9d721d10d87` |
| `DomainEventStore.swift` | `662fcc1f51b7a56c2989608c6bea7a5b3748f207dd29d25660d32301f82c24a9` |
| `FeedService.swift` | `2d5907a5cbeb23934025e3fad248de7c719e61935f34ca7a776c8a525fb0fdae` |
| `RuminationService.swift` | `e1adf999b7b4d4b69ca5530601d3363fc691074d3dc5b4342b9ba36a95faeb6e` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `GuideChatService.swift` | `849d026abe5ec6b5223885f5a5bbd650db84110514ab6e114370b9ef67392b55` |
| `MemoryDistillService.swift` | `c2c4131edd309c9a153f950d90c5527eff9857ac6cf1df61de4e0abccc4151bc` |
| `Orchestrator.swift` | `b3818ceb5ce33c736a035027d8fa70380885406df249cd8c4c2498e1636483ca` |
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `InputWorkflowController.swift` | `0021a0cb8b5d80624cc5bd49fd5d96cc96202bf8da73d3c911e2d5453aeca17f` |
| `AppStore.swift` | `84bbf8d84a100af0e958c6ee74d312affa8aed65dbccaf3dc166b31148be4c4d` |
| `CodingRanchStoreAdapter.swift` | `b9ca45a48bae38345f37a7011ca9b2bf7ce052697d944a4ecacc93f5adc81e69` |
| `RuminationViews.swift` | `54950383569ee7b0965364eda8a6402277e2c7f251aeab7de4f68340a4f97e34` |
| Matrix runner | `2c3f66a42504b0273968ac902834136164c150cf2acf7b2cb6f1ddacf6c0cb00` |
| Matrix script | `1beee980f7a5cdf284a96b1cd8d587cf0748d16614de39ac547545a829cf84e9` |

Review01 records the complete existing-allowlist pre-image table. All 24 new
source/test paths in §4 are absent at entry.

### 5.3 NUL-safe outside manifest

The scope gate reads the exact allowlist file, obtains modified/untracked paths
with `git ls-files --modified --others --exclude-standard -z`, rejects duplicate
or blank allowlist entries, excludes allowlisted paths, sorts remaining path
bytes, and hashes each entry as:

```text
u64be(path byte count) || path bytes || u32be(lstat mode) ||
  file: "F" || u64be(content byte count) || raw SHA-256(content)
  symlink: "L" || u64be(target byte count) || target bytes
```

Entry values after creating only the machine allowlist are:

```text
allowlist_lines=88
allowlist_sha256=ab95ea1f33ff41de6819f32602ac5fe0bf5988085bb6cfed9a2a8819687ecb60
dirty_total=549
allowlisted_present_count=42
outside_count=507
outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242
```

Adding task artifacts changes only `dirty_total` and
`allowlisted_present_count`. `outside_count` and `outside_manifest_v1` must
remain exact through implementation Review02.

## 6. Band implementation details

### E1 — migration and permit lifecycle

1. Add tests 01–16 and save `red-e1-migration.log` before product changes.
2. Add the exact Package dependency and raw permit registry/bootstrap.
3. Add v16 migration literal plus exhaustive Swift scope resolver/assertion
   bridge where required, records, and migration matrix carriers.
4. Make the migration replayable from every predecessor through v15, with
   populated archived work, scope, v15 Outcome/Verification/Acceptance/receipt,
   poison diagnostics, child-FK, guard ordering, failure-injection, redaction,
   and UDF-absent CLI fixtures.
5. E1 stops only when tests 01–16 and both matrix lanes pass. Domain/store/UI
   functionality may still be absent.

### E2 — identity, authorization, lifecycle fence, and Memory

1. Add tests 17–32 and save `red-e2-identity-memory.log`.
2. Add four domain contracts, Cow/Residency/Memory/Lifecycle stores, and two
   Application controllers.
3. Wire only active residency/bridge authorization and E-owned active Camp
   writes. Keep retirement commands absent.
4. Extend P1-D invalidation transactions with required Memory mutation.
5. E2 stops only when tests 01–32 pass and source checks show zero retirement,
   Growth, or v17 surface.

### E3 — legacy scope and provider durability

1. Add tests 33–48 and save `red-e3-scope-provider.log`.
2. Add content/event scope stores and exhaustive resolver; route every
   allowlisted raw legacy insertion through them.
3. Add provider dispatch Store and move Guide/Camp distillation authority from
   service-held tasks/providers into durable supervisor/ledger paths.
4. E3 stops only when tests 01–48 pass, all 45 event kinds are resolved, and
   returned/lifecycle crash matrices are green.

### E4 — ordinary Ingestion deletion

1. Add tests 49–80 and save `red-e4-ingestion.log`.
2. Remove the legacy caller-fact `deleteIngestionAtomically` and
   `deleteIngestion(ingestionId:scope:)` seams.
3. Add sealed domain types, Store factory/executor/resolver, shared graph
   validator, transaction-generation permit use, safe receipt/event/outbox,
   exact result/source mutations, and worker version/lifecycle fences.
4. E4 stops only when tests 01–80, legal 53/63 paths, raw negative matrix, four
   original P0 counterexamples, replay/resolution, and all writer races pass in
   both real SQLite lanes.

### E5 — Application/UI and completion evidence

1. Add tests 81–90 and save `red-e5-application.log`.
2. Replace Adapter/Contracts/LiveHosts/RuminationViews with prepare/execute/
   resolve plus four-phase pending UI and truthful copy.
3. Run the exact 90-test focused gate, source/scope gate, matrix, App build,
   isolated UI smoke, then authoritative full `swift run RunTests`.
4. Write `impl-report.md`; only then run Review02. Acceptance is closed unless
   Review02 reports zero P0/P1 and every required evidence log is current.

## 7. Exact P1-E test manifest

The final focused manifest contains exactly these 90 unique Swift test
identifiers, numbered and declared once. Table-driven cases inside a test must
emit the case label and fail on missing rows; a loop cannot silently skip an
empty matrix.

```text
01 p1e01V16MigrationIsImmediateSuccessor
02 p1e02V16SchemaObjectCountsAndDDL
03 p1e03CompanionCowResidencyBackfillReplay
04 p1e04NilAndCorruptCampBackfillMatrix
05 p1e05ArchivedWorkClosureAndLifecycleBinding
06 p1e06LegacyPoisonDiagnosticsRollback
07 p1e07DurableChildFKRebuildUsesFinalNames
08 p1e08LegacyChatNoteScopeBackfill
09 p1e09LegacyEventScopeExhaustiveBackfill
10 p1e10LegacyScopeMalformedRollback
11 p1e11V16GuardDropOrdering
12 p1e12V16FailureBoundaryRestoresV15
13 p1e13V16RedactionAndAppendOnlyGuards
14 p1e14LiteralSQLite351V16Fence
15 p1e15LiteralSQLite352V16Fence
16 p1e16RealSQLiteDualLaneV16Contract
17 p1e17CowIdentityContractValidation
18 p1e18ResidencyTransitionsReplayAndRejoin
19 p1e19RequireActiveResidencyAuthorization
20 p1e20SameCowTwoCampsMemoryIsolation
21 p1e21InactiveResidencyBlocksReadWrite
22 p1e22BridgeDirectionScopeAndRevocation
23 p1e23RequireActiveCampWriteFence
24 p1e24P1ERetirementAPIsRemainClosed
25 p1e25MemoryRawWorkingPromotionFlow
26 p1e26MemoryLayerOwnerAndCarrierInvariants
27 p1e27AcceptedOutcomeSkillPromotion
28 p1e28UnacceptedOrInvalidSkillPromotionRejects
29 p1e29MemoryDependencyAppendOnlyGraph
30 p1e30DependencyInvalidationStateMatrix
31 p1e31MemoryTombstoneErasesPrivateCarrier
32 p1e32P1DInvalidationAndMemoryRollbackAtomically
33 p1e33LegacyContentWritesScopeFirst
34 p1e34LegacyContentRawWriteRejected
35 p1e35LegacyEventAppendScopeFirst
36 p1e36LegacyEventMissingMismatchRejected
37 p1e37ProviderMessageAndWorkCommitAtomically
38 p1e38ProviderPrepareStartReturnConsumeSuccess
39 p1e39ReturnedCheckpointNeverRecallsProvider
40 p1e40StartedDispatchAbandonAndExactReplay
41 p1e41ProviderLifecycleFenceRace
42 p1e42GuideAndCampDistillReplayClass
43 p1e43GlobalProviderRoutesAvoidCampDispatch
44 p1e44UnknownExternalWriteRouteRejects
45 p1e45GuideToolAllowlistAndReceiptDedupe
46 p1e46HistoricUnsafeStartedFailsObservably
47 p1e47ServicesHaveNoUnregisteredProviderAuthority
48 p1e48P1EProviderScopeIntegrationFailsClosed
49 p1e49DeletionPrepareRequestSurface
50 p1e50DeletionCommandFactoryAuthority
51 p1e51DeletionPrepareSnapshotZeroWritePrivacy
52 p1e52DeletionCommandCanonicalHashAndCounts
53 p1e53ResultOnlyNeedsReviewSuccess
54 p1e54ResultOnlyFailedWithResultSuccess
55 p1e55ResultOnlyRejectionMatrix
56 p1e56SourceAndResultWithoutResultSuccess
57 p1e57SourceAndResultWithResultSuccess
58 p1e58SourceAndResultRejectionMatrix
59 p1e59ProjectionScopeAndPermanentProjectionGuards
60 p1e60KnowledgeLinkBlockerRejects
61 p1e61CandidateBlockerRejects
62 p1e62RuminationWorkBlockerRejects
63 p1e63OpenAttemptBlockerRejects
64 p1e64ProviderDispatchBlockerRejects
65 p1e65DeletionLifecycleTOCTOURejects
66 p1e66DeletionRowAndResultTOCTOURejects
67 p1e67DeletionBlockerTOCTOURejects
68 p1e68DeletionEnvelopeAndPersistedGraph
69 p1e69DeletionExactJSONAndOutboxContract
70 p1e70DeletionReplayAfterLifecycleAndSourceLoss
71 p1e71DeletionConflictIntegrityAndNewKeyMatrix
72 p1e72DeletionRawEvidenceAndUDFRejectMatrix
73 p1e73DeletionOriginalFourP0Counterexamples
74 p1e74PermitRegistryInstallAndIsolationContract
75 p1e75PermitLifecycleScenarioMatrix
76 p1e76PermitCleanupMismatchStickyFaultMatrix
77 p1e77PermitGenerationArityCursorAndReuseMatrix
78 p1e78DeletionExecutionResolutionMatrix
79 p1e79DeletionSharedValidatorForgeryAndRelaunch
80 p1e80DeletionWorkerAndMaterializerRaceMatrix
81 p1e81DeletionControllerSingleFlight
82 p1e82DeletionPreparedCancelAndNotCommittedRetry
83 p1e83DeletionExecutingCancelCommitRace
84 p1e84DeletionRefreshFailureSameKeyReplay
85 p1e85DeletionCommitOutcomeUnknownActions
86 p1e86DeletionIntegrityBlockedActions
87 p1e87DeletionTerminalConflictAbandonFlow
88 p1e88DeletionCommittedDismissAndReload
89 p1e89DeletionProcessDeathPersistenceMatrix
90 p1e90DeletionUISourcePrivacyAndScopeSentinels
```

Focused discovery fails if any identifier is absent, duplicated, or an
unplanned `p1eNN` identifier appears. The authoritative full run remains the
unfiltered `swift run RunTests`.

## 8. Source, schema, and scope gates

The final source gate is fail-fast and saves full stdout/stderr. It must prove:

1. exact allowlist SHA/line uniqueness and unchanged outside count/manifest;
2. authority, P1-D acceptance, `Package.resolved`, RunTests, canonical domain,
   and canonical JSON hashes remain exact;
3. only the 24 exact new source/test paths exist; no extra P1-E file appears;
4. exactly 90 planned test declarations and 90 discovered focused tests;
5. AppDatabase migration order ends at v16, extracted v16 literal hash matches
   §3.1, and no v17 identifier or v17-only F1/F2 table/type/command appears;
6. Package diff is exactly the one Core GRDBSQLite product; no other target,
   dependency, product, package, or resolved-file change;
7. only `ActiveIngestionDeletionSQLPermit.swift` imports `GRDBSQLite`, owns raw
   SQLite symbols, raw callbacks, `Unmanaged.passRetained/takeRetainedValue`,
   registry key/cell/context, autocommit, and the single production
   registration call;
8. AppDatabase contains exactly one release/product
   `registry.installConnectionUDF(on: db)` call in `prepareDatabase`; the only
   test install is inside the Permit file's DEBUG internal fixture;
9. zero `DatabaseFunction`, deterministic/DIRECTONLY, caller raw pointer/nonce,
   global callback storage, manual release/destructor, close wrapper,
   `onConnectionWillClose`, GRDB patch, raw unregister/overwrite, or capability
   leakage;
10. Store-only command factory, permit mutation path, specialized evidence
    write, physical result/source mutation, shared validator, and exact
    `writeWithoutTransaction` resolver. Store/Controller/tests do not import
    GRDBSQLite or invoke raw symbols;
11. legacy `deleteIngestionAtomically`, adapter/UI caller-fact deletion, raw
    candidate/link/source/result deletion outside Store, and generic mutation
    callback are absent;
12. legacy content/event writes route through their typed stores; raw
    `EventRecord.insert`, CompanionNote, or ChatMessage insertion outside the
    named owner/migration fixture is absent;
13. all 45 persisted EventKind values equal resolver keys; no default/global
    fallback exists;
14. service-held unregistered provider/fire-and-forget authority is absent;
15. P1-E has no archive/unarchive/request-deletion/repair/deletion-worker,
    Engine/Artifact/Discussion/Attention/Growth schema or product surface;
16. no P1-E failure is swallowed by `try?`, empty-array/default fallback,
    optimistic close, or fake success;
17. RootView/AppStore/Application contain no legacy archive/unarchive product
    caller; the single Core compatibility method has a typed-failing release
    branch and DEBUG-only dual-write fixture branch;
18. the two named UI preview failure seams are DEBUG-guarded, require preview
    mode plus an exact enum value, have zero release symbols/callers, and expose
    no database/mutation/permit capability;
19. `git diff --check` passes.

Any source-gate command that receives empty input, an `rg` error, unexpected
count, or non-regular allowlist node fails. `rg` status 1 is accepted only by a
dedicated absent assertion; status 2 is always failure.

## 9. Migration and runtime evidence

### 9.1 Dual SQLite matrix

The authoritative command is:

```bash
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
```

Both versions run the same literal fence and the same real GRDB migrator for
fresh, v7, v8, v9, v10, v11, v12-durable, v12-schedule, v13, v14, and v15,
plus populated archived-work and complete legacy scope fixtures. Each lane
must replay, check exact DDL/counts/backfill, FK, integrity, append-only guards,
failure rollback, poison diagnostics, and v16 67-trigger truth table.

The literal CLI intentionally has no UDF and proves matching-evidence raw
DELETE fails closed. Legal resultOnly, sourceAndResult(no result), and
sourceAndResult(with result) run only through AppDatabase in both real linked
lanes. No relaxed CLI test function is allowed.

### 9.2 App build and UI smoke

`swift build --product AgentLoopApp` must pass. UI smoke uses a fresh explicit
`AGENTLOOP_STATE_DIR` under a validated temporary directory and never the
normal root. It captures command, state path, app/process identity, screenshot,
database facts, integrity/FK checks, and graceful termination for:

1. successful ordinary deletion: inbox/dashboard refresh before the sheet
   closes; one key/event/outbox and exact projection;
2. injected Store failure: original page and selection remain with trace;
3. commit then refresh failure: same pending handle/key replays receipt,
   refresh succeeds, then closes with no second event/outbox/delete;
4. prepared cancel, verified rollback to prepared, executing cancel/commit
   race, all three resolution dispositions, committed dismiss/reload, and
   process death before/after commit.

No external provider, real user data, real credential, payment, network write,
or release action is used.

### 9.3 Authoritative final run

All commands run under Bash with `set -euo pipefail`; full stdout/stderr goes
to a unique temporary file, command and tee statuses are checked separately,
then the completed bytes are moved to the named task log.

```bash
swift run RunTests
swift build --product AgentLoopApp
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
scripts/run-app.sh --preview
git diff --check
git status --short --branch
```

The preview wrapper supplies the isolated state root and evidence setup; the
bare command above describes the required product path, not permission to use
normal state.

## 10. Required artifacts and report contract

The task directory must contain current, non-placeholder:

- immutable `plan.md`, exact `scope-allowlist.txt`, and Review01;
- one pure-red log for each E1–E5 band;
- `focused-verify.log` for exactly tests 01–90;
- `migration-matrix.log`, `source-gates.log`, `build.log`, `preview.log`;
- authoritative unfiltered `verify.log`;
- `impl-report.md` with changed files, plan mapping, deviations/revisions,
  command/tee status, test/suite counts, evidence hashes, no-Claude disclosure,
  and remaining prohibited external actions;
- read-only implementation Review02 and `acceptance.md`.

`verify-red.log` is required if the first full compatibility run reveals an
unplanned existing regression; it records the failure before a bounded root
fix. It cannot replace any band red.

Every log is full stdout/stderr, not a summary or exit code. A green test does
not count if its wrapper, filter, tee, packaging, migration, or evidence copy
failed.

## 11. Completion gate

P1-E is accepted only when all are true:

1. Review01 approved the exact plan/allowlist with zero P0/P1 before product
   code;
2. all five red frames predate their corresponding implementation bands;
3. exactly 90 planned focused tests pass and are discovered once;
4. authoritative full `swift run RunTests` passes with zero failures;
5. SQLite 3.51 and 3.52 literal/real/replay/rollback/failure matrices pass;
6. v16 is exactly 67 tables / 171 indexes / 67 triggers and all migration
   order/backfill/guard/FK/integrity contracts pass;
7. source/scope/hash/privacy/Package gates pass with outside manifest exact;
8. AgentLoopApp builds and isolated success/failure/recovery UI evidence is
   truthful;
9. Camp isolation works at Store/runtime level without UI filtering;
10. Memory provenance is traversable and P1-D invalidation is atomic;
11. active ordinary Ingestion deletion satisfies Store-only factory,
    connection-local generation-bound raw UDF, safe command/outbox, fixed-zero
    blockers, typed resolution, and four-phase UI;
12. Camp retirement remains schema-only and unexposed;
13. implementation Review02 reports zero P0/P1;
14. `impl-report.md`, evidence hashes, `blocked.md`, and acceptance are current;
15. no outside path or prohibited external action changed.

After acceptance, stop auditing P1-E. Only the separate top-level fact sync and
P1-F1 decision-complete planning gate open.

## 12. Red lines

- No commit, push, merge, PR, release, deployment, payment, public message,
  real-user action, destructive data reset, or normal-state mutation.
- No file outside the exact allowlist and no hidden generated source.
- No v17, F1/F2 implementation, Camp retirement UI/worker/command, Growth, or
  alternate schema.
- No caller-fact command, public permit, global registry, nearest/current/
  last-writer fallback, relaxed test UDF, second registration call, manual C
  ownership patch, or capability leakage.
- No evidence-only SQL authorizing a later mutation; no candidate/link delete.
- No swallowed errors, `try?`/default empty fallback on P1-E truth, lowered
  assertions, skipped matrix row, optimistic UI close, or documentation in
  place of tests.
- No physical Camp deletion or private content in audit payload/log/preview.
- No later green can overwrite or reinterpret a failed red/review artifact.
