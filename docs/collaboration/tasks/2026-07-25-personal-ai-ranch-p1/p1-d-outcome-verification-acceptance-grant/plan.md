# P1-D — Outcome / Verification / Acceptance / ApprovalGrant Plan

> Revision: 1 candidate  
> Date: 2026-08-25  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Entry authority: P1-C acceptance SHA-256
> `417be624b8c9a1b64730d5f3ebbca07d64aaa741159296d74f1520f44423ab82`

## 1. Decision and entry gate

This is the decision-complete implementation plan for canonical P1-D. Its
authority is the accepted master spec, canonical P1 stage §5/§8/§10/§12–§13/
§18.5/§19–§23, canonical P1 plan §6/§10/§11, and accepted P1-C state.

P1-C is frozen. P1-D product/test/schema work remains closed until a separate
read-only plan review of this exact hash reports
`APPROVED — 0 P0 / 0 P1`. The user directed Codex to work without Claude or
delegated agents; Review01 and later Review02 must disclose self-review and may
not claim independence.

P1-D closes R-08/R-09 by creating one durable outcome truth, independent
verification, post-commit acceptance navigation, and scoped/consumable grants.
It ends with Goal/Outcome/Acceptance/Grant semantics complete and deliberately
does not create P1-E Memory/Cow/Residency/Camp lifecycle or P1-F1 Attention/
Growth/Engine tables.

## 2. Frozen product decisions

1. `v15-p1-outcome-contracts` is copied byte-for-byte from stage §18.5: 515
   SQL lines, 14 tables, 14 explicit indexes, 8 append-only triggers, literal
   SHA-256
   `0fa300dd5c90e12a90b7cf3f9f0eb84af07f4d9bbc36f869123bdda236214cbb`.
2. The stage §12.2 Outcome table is the only state machine. There is no
   `recordProducedVersion` alias and no extra invalidation edge.
3. `ready -> active` exists only as the P1-D `activateGoal` command. Goal
   activation requires one exact confirmed Understanding, one active exact
   OutcomeContract, and a Camp-exact Mission link written in the same
   transaction. Pause/resume/achieve and system reopen use CAS.
4. Contract content, requirements, Outcome versions, Verification records,
   invalidations, Acceptance records, and external receipts use canonical
   JSON/hash references. Mutable heads never replace immutable evidence.
5. P1-D domain commands reuse `CommandEnvelopeV1` and v14 receipt/event/outbox
   tables through a new typed P1-D executor in `DomainEventStore.swift`.
   Accepted P1-C enums/files are not widened. P1-D command/event strings are
   defined in the new domain files and raw rows are decoded through P1-D-only
   record types.
6. Domain command replay validates command type, canonical whole-payload hash,
   result bytes/hash, exact event count/order/aggregate versions, event payload
   bytes/hash, and one pending outbox per event before returning. Divergence is
   a conflict; no factory, adapter, verifier, or mutation is recalled.
7. A policy acceptance hard guard runs before policy-row lookup. Beneficiary
   identity is the linked Goal's immutable `createdByActorId`; policy
   `subjectId` is the exact policy actor. First onboarding and first outcome
   type are derived from accepted history joined through Outcome→Goal, never
   caller flags.
8. `DeliveryCoordinatorV1` is the only public delivery caller and always uses
   `system:delivery:v1`. The Store reruns the reducer and manifest readability
   check in the delivery transaction.
9. `ApprovalGrantStore` is the sole owner of Grant/use/receipt transitions.
   `ApprovalGate`, tools, adapters, and coordinators cannot issue raw writes.
10. All currently approval-gated live tools (`write_file`, `run_shell`, and
    `mcp__*`) are conservatively `nonReplayable`. They therefore require an
    exact single-use user Grant even when legacy `MissionAutonomy` would not
    have prompted. `MissionAutonomy` remains only a compatibility signal for
    when approval is requested; it never acts as a Grant.
11. The Application target owns the sole async external-operation coordinator.
    It is injected into Orchestrator as a Core-defined Sendable port, then
    propagated to model and CLI runners. Missing production port fails closed;
    there is no direct-call fallback, singleton, or DB service locator.
12. External adapters expose descriptor, `start(idempotencyKey:)`, and
    `reconcile(idempotencyKey:operationId:)`. The same use idempotency key is
    used for every adapter attempt. Persisted receipts contain only canonical
    typed metadata plus evidence hash/ref summaries, never tool output or
    external response bodies.
13. A `ToolHandler` adapter treats the returned operation ID as deterministic
    from adapter ID + use key. `ToolOutcome.error` maps to `failedFinal`; other
    terminal outcomes map to succeeded. The original `ToolOutcome` is returned
    only after the matching durable terminal receipt commits.
14. Memory/Growth mutations are absent in P1-D. Section §19 writes one required
    dependency-invalidation domain event and updates only current
    Outcome/Verification/Acceptance/Goal/Mission/metric tables. P1-E/F later
    extend the transaction with required stores; there is no optional no-op
    hook now.
15. Legacy Mission closeout remains available only when no active
    Goal/Contract/Outcome link exists. It never creates new metric credit or
    claims independent Verification. Contract-linked missions use the new
    Acceptance workflow exclusively.

## 3. Exact allowlist

### 3.1 Canonical existing files

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Tools/ApprovalGate.swift`
- `Sources/AgentLoopCore/Tools/ApprovalPolicy.swift`
- `Sources/AgentLoopCore/Tools/ToolExecutor.swift`
- `Sources/AgentLoopCore/Tools/BoardTools.swift`
- `Sources/AgentLoopCore/Tools/FileTools.swift`
- `Sources/AgentLoopCore/Tools/ShellTool.swift`
- `Sources/AgentLoopCore/Tools/WebFetchTool.swift`
- `Sources/AgentLoopCore/Mcp/McpToolBridge.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/ApprovalGateTests.swift`
- `Sources/AgentLoopTestSuite/ApprovalPolicyTests.swift`
- `Sources/AgentLoopTestSuite/BoardToolsTests.swift`
- `Sources/AgentLoopTestSuite/ToolExecutorTests.swift`

### 3.2 New canonical files

- `Sources/AgentLoopCore/Domain/OutcomeContract.swift`
- `Sources/AgentLoopCore/Domain/Outcome.swift`
- `Sources/AgentLoopCore/Domain/Verification.swift`
- `Sources/AgentLoopCore/Domain/Acceptance.swift`
- `Sources/AgentLoopCore/Domain/ApprovalGrant.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/ApprovalGrantStore.swift`
- `Sources/AgentLoopCore/Tools/ExternalOperationAdapter.swift`
- `Sources/AgentLoopApplication/ExternalOperationWorkflowCoordinator.swift`
- `Sources/AgentLoopApplication/AcceptanceWorkflowController.swift`
- `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`
- `Sources/AgentLoopTestSuite/VerificationContractTests.swift`
- `Sources/AgentLoopTestSuite/AcceptanceWorkflowTests.swift`
- `Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift`

### 3.3 Normatively required carrier additions

Canonical plan §10 requires a through-v15 dual-SQLite matrix, and the explicit
Application→Core coordinator injection cannot reach both model and CLI tool
paths without their existing constructors. These additions are therefore
required carriers, not new product scope:

- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`
- `Sources/AgentLoopCore/Domain/GoalController.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`

`GoalController.swift` may receive only a marker-delimited P1-D validation/
transition extension; the accepted P1-C body must strip to its frozen hash.
The three Loop carriers may only propagate the required Sendable port and may
not change provider, tool visibility, run, card terminal, socket, or CLI
semantics.

### 3.4 Task artifacts

- this `plan.md`
- `blocked.md`
- `red-tests.log`
- `focused-verify.log`
- `migration-matrix.log`
- `source-gates.log`
- `build.log`
- `preview.log`
- `verify-red.log`
- `verify.log`
- `impl-report.md`
- `reviews/01-p1-d-plan-review.md`
- `reviews/02-p1-d-implementation-review.md`
- `acceptance.md`

No other path may change. `Package.swift`, `Package.resolved`, RunTests, P1-C
source/test files, canonical authority, accepted evidence, packaging scripts,
and normal user state are read-only.

## 4. Frozen pre-images and protected inputs

The following high-risk pre-images are entry anchors; the full allowlist hash
table is recorded by Review01 and source-gates before the first red test.

| File | SHA-256 |
|---|---|
| `AppDatabase.swift` | `3a393821dc86d8ac9bdf89cff48453ed1866919c7dfcdf443e597a96737b878b` |
| `Records.swift` | `b64a642db225533cd1d67a3441fd334312e10855f2e4190028dee4713c498671` |
| `Orchestrator.swift` | `594062914ee9b90df9672a633f9ddff6384607290c82d48464cdc2f3dde2019c` |
| `GoalController.swift` | `f2580c7393d9a9c1eef8455964ed0b3b3772ab438cd5c2d55471a68f53f7cfd8` |
| `DomainEventStore.swift` | `e41f3f9b0a06d7bdba5d8afb7cd9e0308ae46298dd58aa48ee27f688f9f26db5` |
| `ApprovalGate.swift` | `ef004ab0e97b72a536a161fb0041f7bbfa02d380dd9e884df76f4c1e8b9fd57b` |
| `ApprovalPolicy.swift` | `9a14735b72352a7cf64abe7024afde941fadcdf1b07b33af5dff536edd182ca2` |
| `ToolExecutor.swift` | `fdfc8e53fca920f5654f2e80a8a710728a21cd77dde45bdd670b9c30f55d78d1` |
| `CardRunner.swift` | `d350e83f263248117fb70e49171fa1bbc2b473d0c034378e978b0c17ae3be020` |
| `BoardToolServer.swift` | `fc778c9dd50b3a4ea8a60315503ef5542dd709c68aa3c222ebabc07a6d00f2db` |
| `CliProcessBackend.swift` | `665113119e2e107ece677c52fce60262fdea821438e391ded0fa9ad846739ce1` |
| `AppStore.swift` | `96eab76cf727c81d2bcfbfae6c9eb5aa352c5c1f7452ccac370659e80b8f983a` |
| `CodingRanchStoreAdapter.swift` | `c3fcbc5479920968c10aa7f40827aac67e4d8676f72b09f64ba286436c616b23` |
| `CodingRanchLiveHosts.swift` | `db9c34abbcbbcb013824d1ee884b103ec46e2325eacb242158124d159d3409d9` |
| Matrix runner | `ef010fb358e0ecd84ffd1a4941c761341e6732edf2c5ab8d52cad049019bf4b9` |
| Matrix script | `2b4be14c268560aaf254a3026c70b27c208f30f6e1a1c99048382ec898dde97f` |

Protected read-only anchors:

| Input | SHA-256 |
|---|---|
| Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-C acceptance | `417be624b8c9a1b64730d5f3ebbca07d64aaa741159296d74f1520f44423ab82` |
| Closeout acceptance | `ca70e16176806d19e88759b4349d246ff845a5a9111030c8d6b484272d6bcc09` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| RunTests | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `DomainEvent.swift` | `876896f4d48ab1614630dcbf7075b2a4bcb1a8ba309605c10eeb976c1e59b925` |
| `CommandEnvelope.swift` | `a2117c80b0c7d052b35b38de98f9b9f846fc965cb9b2f9278c18455b6081f39e` |
| `CanonicalContractCoding.swift` | `b15c1f9fc8d602b834eb517cefc7e27437da3d576cc4d388d9f6472032ccdcaa` |
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |

All 14 new product/test files in §3.2 are absent at entry. Outside the exact
allowlist, the NUL-safe lstat/content manifest is frozen as:

```text
dirty_total=503
allowlisted_present_count=12
outside_count=491
outside_manifest_v1=53b8f84867ab0445da2a772bbf20f7fb9c4bedc397100337a4854e266fbf12ab
```

Review01 replaces those two placeholders before approval; an approved plan
contains no placeholder.

## 5. Domain contracts and ownership

### 5.1 P1-D command/event executor

`DomainEventStore` adds a P1-D-only typed executor with this fixed transaction
order:

1. canonicalize command payload and validate actor/device before SQL;
2. receipt lookup; exact stored graph replay or whole-payload conflict;
3. read/CAS preflight and build a complete immutable result plus ordered event
   intents without writing;
4. insert receipt, ordered domain events, and one pending outbox per event;
5. apply all projection/evidence writes using the preallocated event IDs;
6. reread and validate the complete result/event/outbox/projection graph;
7. commit and return.

Because events are inserted before child invalidation rows inside the same
transaction, `verification_invalidation.eventId` always satisfies its FK. Any
later write/validation failure rolls back receipt and events too. Event keys
are `p1d:event:v1:<sha256(commandKey)>:<ordinal>:<aggregateType>:<aggregateId>`;
receipt results are exact-key Codable structs, not a permissive dictionary.

P1-D actor policy is exhaustive:

- user + device: contract draft/revise/cancel, Goal activate/pause/resume/
  achieve, user accept/return, approval answer/grant, and user external
  resolution;
- system exact IDs: contract activation/supersede/fulfill, Goal reopen,
  delivery, dependency invalidation, policy acceptance, grant expiry/recovery;
- cow/engine: Outcome production with envelope actor equal to producer;
- cow or deterministic system verifier: verification with envelope actor and
  exact requirement verifier ID aligned;
- adapters never issue domain commands as user/system and can only present a
  typed adapter attestation to the Grant Store.

Every command carries the expected mutable row versions and exact immutable
hashes read by its caller; the Store revalidates them inside the mutation
transaction. An Application read is presentation/input authority, never
permission to skip transactional TOCTOU checks.

### 5.2 OutcomeContract and Goal

`OutcomeContractContentV1` contains every immutable §18.5 field, explicit
dependency refs, risk/guard flags, and ordered requirement groups. Canonical
hashes include ID/version and all nullable fields. Group ordinals and
requirement ordinals are contiguous from zero; IDs are unique; every group is
nonempty; snapshot JSON is generated from the same canonical rows.

- create: absent contract ID -> immutable draft v1;
- revise draft: cancel old draft and append v+1 draft;
- revise active: append v+1 draft while old active remains effective;
- activate draft: validate exact confirmed joined Understanding, snapshot,
  policy ref, groups, and Coding deterministic requirement; then activate new
  version and supersede the prior active version in one transaction;
- fulfill: active -> fulfilled; cancel: draft -> canceled only;
- all other transitions fail with a typed error and zero writes.

`activateGoal` requires Goal ready, exact current Understanding, active same-
Goal contract, writable Camp, Mission in planning/executing/delivering, and
Mission→Squad Camp equality. It creates an absent active link or CAS-updates an
active null-contract link, then sets Goal active/current contract. Conflicting
mission/goal/Camp/link/version fails. `linkMissionToActiveGoal` provides the
same atomic rule for a Mission created after Goal activation.

Goal transitions are exactly ready→active, active→paused/achieved, paused→
active, and achieved→active only for `system:outcome-reopen:v1`, plus the
already accepted abandon/fail edges. Achieve requires an accepted current
Outcome; reopen is invoked by §19 return/revoke/invalidate/new-version paths.

### 5.3 Outcome, Verification, and delivery

`OutcomeStore` implements the §12.2 table literally. Initial and subsequent
commands have distinct command types and canonical payloads. A new version
appends `outcome_version_superseded` invalidations for every old current head
before switching the head; it never mutates old OutcomeVersion or
VerificationRecord.

Verification insert validates exact contract/requirement/outcome hashes,
producer independence, superseded head ID, and command key. It inserts the
immutable record, CASes one result head, applies all active invalidations, then
runs one reducer. The reducer requires every group; `all` requires every row,
`any` one row; Coding additionally requires a current deterministic pass.
Missing/failed/blocked/invalid/stale/mismatched heads never pass.

`CommandExitVerifier` uses an injected Sendable ProcessRunner and returns
passed only for known rule version, complete environment, timeout-free zero
exit, and canonical evidence. `ArtifactHashVerifier` rejects missing,
unreadable, non-regular/symlink, or mismatched artifacts. Neither interface has
a write method, grant, or workspace mutation capability.

Delivery validates fixed actor, verified reducer, no current invalidation, and
every manifest ref readable in the same DB transaction before `verified ->
delivered`.

### 5.4 Acceptance and §19 propagation

Acceptance policy rows are immutable versions with exact content hash. The
hard guard derives onboarding/type history, contract flags/risk, and current
reducer state before any policy-row lookup. Eligible policy acceptance then
validates exact ID/version/hash/actor/status/time/type/risk/age.

The acceptance transaction inserts one append-only record, moves Outcome,
Goal, and Mission, writes ordered events/outboxes, and activates or restores
the single `outcome_metric_credit`. Return/revoke/invalidate/new version reverse
the same credit and apply §19 projections. Mission `accepted -> delivering` is
explicit; `MissionStatus.rollup` keeps accepted only while no rework exists and
allows a reworked card to drive executing. All failures roll back.

`deleteOrInvalidateDependency` finds current records by exact contract
dependency refs, writes one command/event graph and one unique invalidation per
affected record, then reduces every affected Outcome in deterministic ID order.

### 5.5 Grant and external-operation state machine

Grant creation recomputes Camp through Card→Mission→Squad, validates typed
grantor/policy registry, exact capability/card/tool/input hash/time, and the
adapter replay class. `ApprovalToken.hash` becomes exactly
`CanonicalJSONV1.sha256Hex(CanonicalJSONV1.encode(input))`; tool ID is not
mixed into the input hash.

For the existing local approval UI, AppStore builds the user envelope with
actor `user:local-owner` and the canonical installation UUID returned by the
same process-shared `LocalCaptureIdentity` contract used by P1-C. The answered
`user_request.id` is the Grant ID, its command key is
`approval-answer:v1:<requestId>`, `validFrom=answeredAt`, and
`validUntil=answeredAt+900s`. Capability is `tool.execute:<toolId>`; data level
is `workspace` for file/shell and `external` for MCP. The exact Card assignee
is the cow grantee, or `system:card-runner:v1` when unassigned. Purpose is
`user_request:<requestId>`. Rejection answers the request but creates no Grant.

Every use transition accepts use ID, expected use version, command key, and
where count changes expected Grant version. Reservation also takes caller-
created use ID and validates exact Grant scope. Same key + same canonical whole
payload returns the old graph; same key + different payload conflicts.

The live single-use bridge derives use identity as
`grant-use:v1:<grantId>:<ordinal>`, where ordinal is the transactionally
validated count of prior uses plus one. A released pre-dispatch use permits the
next ordinal without consuming the Grant. Concurrent callers proposing the
same ordinal converge through Store insert/CAS and the actor-isolated
coordinator; only the dispatch-intent CAS winner may call the adapter.

Existing approval reads become throwing, exact decoders. `ApprovalToken.hash`
is throwing and has no empty-data fallback; malformed options, answers, or
Grant rows abort tool assembly visibly. `CardRunner` and `BoardToolServer`
remove the current `try?`/`compactMap` loss paths, executor construction becomes
throwing, and CLI propagation preserves that failure. A malformed approval is
never silently treated as “no approval”.

An approved request must join the exact same-ID Grant. An unused expired or
revoked Grant is a valid terminal reason to create a fresh approval request;
it is not reused. An existing use is always recovered before considering a new
request: succeeded/failed terminals replay only a sanitized local
acknowledgment, released permits the next ordinal, and crashUnknown blocks for
the typed user resolution path. Raw prior tool output is never reconstructed
or persisted merely to make replay convenient.

The only transition order is:

```text
reserve -> reserved
reserved -> dispatching + usedCount + dispatchIntent
dispatching -> accepted + adapterAccepted
dispatching|accepted -> succeeded|failedFinal + effectConfirmed
reserved(no intent) -> released
dispatching|accepted -> crashUnknown when recovery is ambiguous
dispatching|accepted|crashUnknown -> released only by AdapterNoEffectAttestation
dispatching|accepted|crashUnknown -> succeeded|abandonedUnknown only by user
```

No-effect refund decrements once and reduces Grant status deterministically:
revoked remains revoked; expired/time-expired remains expired; otherwise
underused becomes active and fully used remains exhausted. User resolution
never refunds. Terminal resolution and no-effect race on use version; revoke/
expiry also CAS Grant version. Late calls reread terminal state and never
rewrite it.

Coordinator crash seams exist only as injected test checkpoints immediately
before dispatch intent, after intent/before adapter call, after adapter effect/
before adapterAccepted receipt, and after adapterAccepted/before terminal
receipt. `replaySafe` safely restarts with the same key; `idempotencyKeyed`
reconciles exact operation/key; `nonReplayable` becomes crashUnknown and emits
an urgent-intent domain event without creating P1-F1 Attention rows.

The injected port exposes both `execute` and `recoverPending`. Orchestrator
awaits pending-use recovery before enabling normal card dispatch. Production
currently has only nonReplayable live adapters, so startup can mark their
ambiguous dispatching/accepted uses crashUnknown without rebuilding a tool
handler. ReplaySafe/idempotencyKeyed recovery requires an exact adapter
registry entry; missing registry authority is a visible blocked recovery, not
a guessed replay. Tests inject those adapters and exact operation IDs.

## 6. Application and legacy truth

`AcceptanceWorkflowController` reads an exact snapshot, selects user/policy,
commits through OutcomeStore, then returns a typed committed/notCommitted
result with stable trace. It never navigates or mutates SwiftUI state.

`AppStore` owns the post-return projection update. `ReturnSummaryHost` awaits
that method and calls `onAccepted` only for committed success. Failure retains
the current host, renders the trace-bearing message, and does not celebrate.

Artifact viewing becomes an explicit session event/set updated only by reveal;
artifact presence no longer implies viewed. Knowledge/writeback remain
unknown/not-connected unless a real record exists. Legacy closeout stays
separate and cannot create Outcome/Acceptance/metric rows.

A DEBUG-only isolated preview fixture/failure seam may live only in the
existing AppStore/LiveHosts allowlist. It must be marker-delimited, absent from
release symbols, use a fresh `AGENTLOOP_STATE_DIR`, never access Keychain or a
provider, and prove failed acceptance remains on the page with a visible trace.

## 7. TDD batches and exact red manifest

Each batch is executed serially. Before any product write for that batch, add
only its tests, run the exact filter under `set -o pipefail`, and append the
complete expected failure frame to `red-tests.log`. A compile failure is valid
only when it names the intended missing type/API; unrelated failures block.
After the unique root implementation, append the exact green frame to
`focused-verify.log`. Later batches may not weaken prior tests.

The exact P1-D manifest is 80 test functions:

### D1 — v15, OutcomeContract, Goal (18)

1. `outcomeContractMigrationLiteralMatchesStageSection18_5`
2. `outcomeContractMigrationReplaysFreshAndEveryPredecessorTwice`
3. `outcomeContractMigrationRollbackRestoresV14Snapshot`
4. `v15AppendOnlyCarriersRejectNoopUpdateAndDelete`
5. `v15RedactionShapesAndPolicySchemaAreExact`
6. `v15RawGrantAndReceiptConstraintMatricesFailClosed`
7. `contractContentAndRequirementHashesUseCanonicalJSONV1`
8. `draftCreationIsImmutableIdempotentAndConflictDetecting`
9. `draftRevisionCreatesNextVersionAndCancelsOnlyPriorDraft`
10. `activationRequiresExactConfirmedUnderstandingAndSnapshotRows`
11. `codingActivationRequiresDeterministicRequirement`
12. `activationSupersedesPriorActiveOnlyAfterNewVersionValidates`
13. `contractFulfillAndCancelAllowOnlyFrozenTransitions`
14. `goalReadyActivationRequiresActiveExactContractAndSameGoal`
15. `goalPauseResumeAchieveAndSystemReopenAreExhaustive`
16. `goalMissionLinkIsCampExactCASAndCarriesContractRef`
17. `p1CReadyBehaviorRemainsValidWithoutOutcomeContract`
18. `everyP1DContractAndGoalCommandRejectsWrongActorBeforeSQL`

### D2 — Outcome, Verification, Delivery (22)

19. `initialOutcomeCreatesOnlyV1FromLinkedExecutingOrDeliveringMission`
20. `newOutcomeVersionAcceptsOnlyFiveFrozenSourcesAndIncrementsOnce`
21. `initialAndSubsequentOutcomeKeysCannotAlias`
22. `everyOutcomeTransitionPairMatchesCanonicalStateTable`
23. `outcomeManifestOrContractDriftRequiresNewVersionAndInvalidatesOldHeads`
24. `recordVerificationRequiresExactContractRequirementOutcomeHashes`
25. `duplicateVerificationReplaysAndSupersedeCASRejectsStaleHead`
26. `allGroupRequiresEveryCurrentPass`
27. `anyGroupAllowsOneAlternativeButEveryGroupRemainsRequired`
28. `failedBlockedMissingAndInvalidHeadsReduceExactly`
29. `currentInvalidationReopensVerifiedDeliveredAndAcceptedExactly`
30. `cowVerifierCannotEqualProducerAndModelOnlyCodingNeverPasses`
31. `commandExitVerifierPassesOnlyZeroExitWithCompleteEvidence`
32. `commandExitVerifierTimeoutNonzeroMissingEnvironmentAndParseFailClosed`
33. `artifactHashVerifierRejectsMissingUnreadableSymlinkAndHashDrift`
34. `deterministicVerifiersExposeNoWorkspaceWriteCapability`
35. `deliveryOnlySystemDeliveryV1CanMarkDelivered`
36. `deliveryRerunsReducerAndManifestReadabilityInSameTransaction`
37. `recordNewVersionAppendsSupersededInvalidationsForEveryOldHead`
38. `dependencyInvalidationWritesOneEventAndAllAffectedRowsAtomically`
39. `verificationReceiptEventAndOutboxReplayGraphDetectsTampering`
40. `concurrentVerificationHeadsHaveOneCASWinner`

### D3 — Acceptance, UI, legacy truth (15)

41. `firstOnboardingRequiresUserBeforePolicyLookup`
42. `firstOutcomeTypeRequiresUserBeforePolicyLookup`
43. `eachContractHardGuardRequiresUserBeforePolicyLookup`
44. `highIrreversibleAndUnverifiedRequireUserBeforePolicyLookup`
45. `eligiblePolicyRequiresExactActiveVersionHashActorRiskAgeAndTime`
46. `acceptanceCommitAtomicallyUpdatesRecordOutcomeGoalMissionMetricEvents`
47. `acceptanceFailureLeavesProjectionAndNavigationUnchangedWithTrace`
48. `duplicateAcceptanceCountsOneCreditAndReplaysOneGraph`
49. `returnFromDeliveredOrAcceptedReopensGoalMissionAndReversesCredit`
50. `revokeAcceptanceReopensGoalMissionAndReversesCredit`
51. `invalidationReopensAcceptedAndReversesCredit`
52. `newVersionReacceptRestoresSameCreditWithoutDuplicate`
53. `downstreamTransitionRollbackIsTotalForEverySection19Command`
54. `legacyAcceptanceNeverCreatesOutcomeMetricAndKnowledgeTruthStaysUnknown`
55. `artifactViewedIsExplicitSessionEventAndLiveHostNavigatesOnlyAfterCommit`

### D4 — Grant and external coordinator (25)

56. `approvalInputHashIsCanonicalInputOnlyAndToolRemainsSeparateScope`
57. `approvalAnswerCreatesTypedSingleUseGrantWithRecomputedCamp`
58. `rejectionCreatesNoGrantAndExpiredRevokedMismatchFailClosed`
59. `policyGrantRequiresExactImmutableRegistryTuple`
60. `nonReplayableGrantRequiresUserAndOneUseInSwiftAndRawSQL`
61. `reserveValidatesCapabilityScopeTimeCampAndWholePayloadReplay`
62. `concurrentSingleUseReservationHasOneWinner`
63. `reservedWithoutDispatchIntentReleasesWithoutConsuming`
64. `dispatchIntentAtomicallyConsumesAndWritesFirstReceipt`
65. `adapterAcceptedCannotBeRecordedBeforeAdapterReturnAttestation`
66. `effectSuccessAndFailureReachConsumedTerminalsExactly`
67. `receiptCanonicalHashKeyOrdinalReplayAndConflictAreExact`
68. `receiptPhaseResultAuthorityRawMatrixRejectsInvalidTuples`
69. `dispatchAcceptanceAndTerminalPartialUniqueGuardsAreExact`
70. `reconciliationFailureMayRepeatOnlyWithNextOrdinalAndNewKey`
71. `adapterNoEffectAttestationRefundsExactlyOnce`
72. `userCannotAttestNoEffectReleaseOrRefund`
73. `userResolutionAllowsOnlySucceededOrAbandonedUnknownAndKeepsConsumed`
74. `noEffectAndUserResolutionCASHaveOneWinner`
75. `refundReducerPreservesRevokedExpiredAndUnderusedRules`
76. `refundVersusRevokeAndExpiryRacesNeverResurrectOrDoubleDecrement`
77. `lateReconcileCannotChangeSucceededOrAbandonedUnknown`
78. `nonReplayableCrashAtEveryAmbiguousWindowStopsCrashUnknown`
79. `replaySafeAndIdempotencyKeyedRecoveryReuseExactKeyAndOperation`
80. `coordinatorOwnsReserveDispatchAdapterReceiptOrderAndConvergesExternalSuccessCrash`

Parameterized tests must enumerate every row claimed in their name; a single
example does not satisfy a matrix. Existing canonical tests may be updated only
where P1-D intentionally changes frozen behavior (accepted Mission rollup and
MissionAutonomy-vs-Grant). No assertion may be deleted or weakened.

## 8. Migration and source gates

D1 extends the real matrix runner/script with a named `v14` checkpoint and a
literal v15 lane. Both SQLite 3.51 and 3.52 must run fresh, v7, v8, v9, v10,
v11, v12-durable, v12-schedule, v13, and v14 through the same real GRDB
migrator, replay twice, and pass FK/integrity/DDL/append-only/rollback checks.
The literal lane applies exact §18.5 bytes. Final trigger checkpoint is 16.
The full v15 sqlite_master checkpoint is 55 application tables, 134 indexes
(including SQLite autoindexes), and 16 triggers; each lane proves the exact
name sets rather than count alone.

The final source gate runs fail-fast and proves:

- protected hashes and approved plan/review hash;
- exact 14 new files, no unexpected P1-D node, and exact 80 declarations plus
  exact 80 discovered tests;
- Stage §18.5 literal line/hash and AppDatabase migration bytes match;
- final migration name is `v15-p1-outcome-contracts`;
- P1-C GoalController pre-image is recovered after stripping the single P1-D
  marker block;
- no P1-E/F1 table/type (`memory_record`, `cow_identity`, `camp_residency`,
  `attention_item`, `growth_evidence`, `engine_execution`) appears in P1-D
  source or migration;
- no `recordProducedVersion`, direct tool fallback, adapter raw SQL, optional
  Memory/Growth hook, pre-commit navigation, JSONEncoder approval hash,
  user-declared no-effect, timeout release, or raw external body persistence;
- one Application live coordinator port reaches Orchestrator, CardRunner and
  CLI BoardToolServer; absence fails closed;
- release symbols contain no DEBUG preview failure/fixture seam;
- `git diff --check` and the outside manifest are unchanged.

## 9. Verification order and evidence

Every command is run from `/Users/muzi/Agent-loop` under Bash with
`set -euo pipefail` and `set -o pipefail`; complete stdout/stderr and true exit
status are written through a unique temporary capture, then atomically moved to
the named task log.

Order after all four focused batches are green:

1. exact 80-test focused filter -> `focused-verify.log`;
2. `scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`
   -> `migration-matrix.log`;
3. source/hash/scope gate -> `source-gates.log`;
4. `swift build --product AgentLoopApp` -> `build.log`;
5. isolated DEBUG acceptance-failure preview using a fresh temp state root,
   no provider/Keychain/normal data, plus screenshot/process evidence ->
   `preview.log`;
6. authoritative unfiltered `swift run RunTests` last -> `verify.log`.

Any failure preserves its log (the final-suite failure additionally uses
`verify-red.log`), is diagnosed at its root, and blocks Review02. The exact
failing batch plan is revised/reviewed before any new architectural or scope
decision.

## 10. Report, review, and acceptance

`impl-report.md` records every changed/new path, pre/post hashes, red-to-green
frames, 80-test manifest, v15 objects/matrix lanes, Outcome/Verification/
Acceptance/Grant state coverage, crash windows, UI failure trace, full-suite
count/duration, deviations, outside-manifest result, and prohibited actions not
performed.

Review02 is a separate read-only pass over exact plan, diff, source images,
logs, migration literal, receipt/event graphs, actor/Camp boundaries, state
matrices, external port ownership, UI ordering, and outside manifest. Under the
user override it discloses self-review. Any P0/P1 reopens the exact batch.

Acceptance requires Review01/Review02 zero P0/P1, all four red/green chains,
dual SQLite matrix, App build, isolated failure UI evidence, authoritative full
suite, unchanged protected/outside state, no open question, and no prohibited
action. It closes P1-D and opens only P1-E formal planning.

## 11. Completion gate and red lines

P1-D is complete only when:

1. this exact placeholder-free plan is approved at zero P0/P1;
2. v15 exact DDL and every predecessor/literal lane pass on both SQLite lanes;
3. all 80 named tests first fail for intended capability and then pass;
4. Goal active/paused/achieved, Contract, Outcome, Verification, Delivery,
   Acceptance, metric and Grant contracts match canonical tables/matrices;
5. every external crash window converges without replaying nonReplayable work;
6. failed acceptance does not navigate and exposes a stable trace;
7. legacy UI truth is honest and legacy closeout does not enter new metric;
8. focused/matrix/source/App/preview/full gates pass;
9. Review02 and acceptance have zero P0/P1; and
10. there is no unknown failure, red test, scope drift, open question, hidden
    fallback, or prohibited action.

Red lines: no commit/push/merge/release/reset/revert, normal-data mutation,
payment, public communication, real-user action, provider call, secret logging,
P1-E/F implementation, model-text verification, direct Grant/receipt SQL
outside its Store, direct adapter execution outside the coordinator, precommit
navigation, or weakening append-only/CAS/hash/permission/migration assertions.

Open questions: none.
