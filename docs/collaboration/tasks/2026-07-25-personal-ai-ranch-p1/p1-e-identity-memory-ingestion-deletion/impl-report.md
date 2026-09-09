# P1-E Implementation Report

Status: **IN PROGRESS — E1–E4 COMPLETE, E5 RED GATE OPEN**

This report is the durable implementation ledger for P1-E. It is updated at
each band completion gate and is not an acceptance claim until E1–E5 and the
leaf-wide gates are all complete.

## Execution authority

- Plan: Revision 2, SHA-256
  `e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727`.
- Machine allowlist: 88 lines, SHA-256
  `ab95ea1f33ff41de6819f32602ac5fe0bf5988085bb6cfed9a2a8819687ecb60`.
- The user explicitly directed Codex to proceed independently without Claude.
  No Claude process, subagent, commit, push, merge, release, deployment,
  payment, public communication, real-user action, or normal-state mutation
  has been used.

## E1 — complete

Implemented the exact v16 migration carrier and its runtime prerequisites:

- the sole `AgentLoopCore` direct `GRDBSQLite` product dependency;
- exact Stage §18.6 migration literal and runtime hash gate;
- exhaustive legacy chat/note/event scope resolution and v15 backfill;
- final-name durable child-FK rebuild and archived-work closure;
- connection-local raw SQLite UDF registration/ownership with fail-closed
  no-generation behavior;
- real fresh/v7/v8/v9/v10/v11/v12/v13/v14/v15-empty/v15-populated migration,
  replay, diagnostics, append-only, FK, integrity, and rollback carriers;
- literal SQLite 3.51/3.52 v16 67/171/67 fences, including matching deletion
  evidence that reaches and fails on the deliberately absent raw UDF.

E1 source and test paths changed or added:

- `Package.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Database/ActiveIngestionDeletionSQLPermit.swift`
- `Sources/AgentLoopCore/Database/LegacyContentScopeStore.swift`
- `Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift`
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`
- `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift`
- `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`

Root-cause corrections made while closing the matrix:

- counted the exact 1998 newline-terminated §18.6 lines from zero rather than
  adding a phantom non-terminated line;
- mapped each predecessor to its actual final trigger/FK set instead of using
  stale v12–v15 names after v16;
- treated v15 as already containing observability objects;
- namespaced the append-only probe so it cannot collide with the populated-v15
  fixture;
- compared composite foreign keys by distinct target table, preserving both
  columns of the real FK.

No assertion was relaxed and no product fallback was added.

## E1 evidence

- Pure red: `red-e1-migration.log` (immutable; predates E1 product changes).
- E1 remains covered by the current cumulative `focused-verify.log`; the
  superseding E2 frame runs tests 01–32.
- Dual SQLite evidence: `migration-matrix.log`, SQLite 3.51.0 and 3.52.0,
  both real and literal carriers, final
  `p1_migration_matrix.result=pass`, `script_status=0`,
  `wrapper_status=0`, `initial_tee_status=0`.
- `migration-matrix.log` SHA-256:
  `a0ba1dd80a2f9ab59e6462f159c5644580e17678b6a2140c87fcc315861a00f5`.
- Frozen `Package.resolved` SHA-256 remains
  `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`.
- Scope audit after E1:
  `dirty_total=559`, `allowlisted_present_count=52`,
  `outside_count=507`,
  `outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242`.

## E2 — complete

Implemented the frozen identity, authorization, lifecycle, Memory, and P1-D
invalidation band:

- global Cow identity contracts with canonical engine-policy JSON;
- exact requested/authorized/active/paused/left/revoked residency transitions,
  idempotent receipts, terminal rejoin rules, and active-residency authority;
- directional, scoped, expiring, and revocable Camp bridges;
- exact active-Camp lifecycle/version write fences;
- raw/working/Camp/global Memory layers with exact owner, carrier, scope,
  provenance, promotion, dependency, invalidation, and tombstone rules;
- accepted-Outcome skill promotion only from a current passed Verification and
  current accepted Acceptance;
- Memory invalidation in the same transaction as P1-D Outcome, Verification,
  Acceptance, and dependency transitions;
- post-v16 Camp/Companion/guide provisioning that atomically creates lifecycle,
  Cow, and active residency truth;
- removal of archive/unarchive product callers while retaining only the
  plan-authorized DEBUG fixture compatibility seam.

E2 product and test paths changed or added:

- `Sources/AgentLoopCore/Domain/CowIdentity.swift`
- `Sources/AgentLoopCore/Domain/CampResidency.swift`
- `Sources/AgentLoopCore/Domain/CampBridge.swift`
- `Sources/AgentLoopCore/Domain/MemoryRecord.swift`
- `Sources/AgentLoopCore/Database/CampLifecycleStore.swift`
- `Sources/AgentLoopCore/Database/CowResidencyStore.swift`
- `Sources/AgentLoopCore/Database/MemoryRecordStore.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift`
- `Sources/AgentLoopApplication/CowResidencyWorkflowController.swift`
- `Sources/AgentLoopApplication/CampMemoryWorkflowController.swift`
- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopTestSuite/CowResidencyContractTests.swift`
- `Sources/AgentLoopTestSuite/CampIsolationTests.swift`
- `Sources/AgentLoopTestSuite/MemoryProvenanceTests.swift`
- `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`

The three P1-D/Memory integration tests were initially placed in the existing
P1-D `AcceptanceWorkflowTests.swift`. The NUL-safe scope gate caught that the
file is outside the P1-E allowlist. Those additions were moved to the
allowlisted `MemoryProvenanceTests.swift`; the P1-D file was restored exactly,
and the frozen outside manifest returned byte-for-byte. No baseline P1-D
content was discarded.

The v16 domain-event scope trigger also revealed that the legacy `event` write
funnel is not yet post-v16 capable. That capability is explicitly owned by E3
tests 33–36, so E2 does not pre-implement it. The stale P1-D migration replay
test was corrected to stop explicitly at its own v15 authority rather than
mistaking the repository's new v16 head for a v15 failure.

## E2 evidence

- Pure red: `red-e2-identity-memory.log`, 1,684 lines, SHA-256
  `8a330edcfaa61f542d2c8d3c3db9c78d85e9a89f93a3c0ccc0c5afccc6b79c2e`.
  Its appended status correction truthfully records zsh `pipestatus` after the
  original Bash-only `PIPESTATUS` capture mistake.
- Current cumulative focused evidence: `focused-verify.log`, marked
  `PARTIAL_E2_ONLY`, 32 tests / 5 suites, zero failures,
  `test_status=0`, `wrapper_status=0`, `tee_status=0`; SHA-256
  `82b28b4602232f703861bad0192296dfac74f1c0118993cb96006ca7fea7cf08`.
- Exact declarations: tests 01–32 each occur once; no later P1-E identifier is
  present.
- E2 surface scan: zero retirement command/API, Growth, v17, or P1-F
  `OutcomeContract` surface in the E2 product paths. The schema-ready
  `CowIdentityStatusV1.retired` value remains intentionally unexposed.
- Frozen hashes remain exact: plan
  `e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727`,
  allowlist
  `ab95ea1f33ff41de6819f32602ac5fe0bf5988085bb6cfed9a2a8819687ecb60`,
  and `Package.resolved`
  `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`.
- Scope audit after E2:
  `dirty_total=574`, `allowlisted_present_count=67`,
  `outside_count=507`,
  `outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242`.
- `git diff --check` passes.

## E3 — complete

Implemented the frozen legacy-scope and durable Camp-provider band:

- scope-first legacy chat thread, chat message, Camp note, companion note, and
  all 45 legacy event-kind writes, with temporary connection guards rejecting
  raw post-v16 writes without changing the canonical 67-trigger schema;
- a single durable Camp provider ledger with prepare/start/returned/consume,
  claim and lifecycle/version fences, exact replay, unknown-effect abandonment,
  and receipt-deduplicated Guide tool execution;
- atomic Guide message/work completion and atomic Camp distillation
  note/watermark/work completion;
- a durable closeout/cowork memory supervisor handed off by `Orchestrator`,
  replacing fire-and-forget provider ownership;
- global DM and preference inference remains explicitly outside Camp dispatch;
- every runtime `EventRecord` construction is now centralized in
  `LegacyEventScopeResolver`, and every runtime `DurableWorkRecord` insertion
  carries the current active Camp lifecycle version;
- removed the final unreachable legacy closeout/cowork provider paths from
  `Orchestrator` rather than retaining a dead alternate authority.

E3 product and test paths changed or added:

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Database/LegacyContentScopeStore.swift`
- `Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift`
- `Sources/AgentLoopCore/Database/CampProviderDispatchStore.swift`
- `Sources/AgentLoopCore/Chat/GuideChatService.swift`
- `Sources/AgentLoopCore/Knowledge/Distiller.swift`
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopTestSuite/LegacyScopeMigrationTests.swift`
- `Sources/AgentLoopTestSuite/CampProviderDispatchTests.swift`
- `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`

Root-cause corrections made while closing E3:

- interactive Guide claims now claim the exact work ID instead of allowing a
  generic queue claim to steal unrelated work;
- lifecycle mismatch is diagnosed before inactive-state rejection so a stale
  writer cannot hide a version race;
- legacy planning, schedule, candidate, recovery, and rumination work/event
  constructors now use the v16 lifecycle/scope funnels;
- provider read failures retain the durable started checkpoint and normalize
  through the service's existing observable error contract.

## E3 evidence

- Pure red: `red-e3-scope-provider.log`, SHA-256
  `f1c29f6c08b1c16b3538d2fcc4f353725f667ecd785da4e1aa409bd4d299b0d4`.
- Current cumulative focused evidence: `focused-verify.log`, exactly tests
  01–48, 48 tests / 7 suites, zero failures, `test_status=0`,
  `tee_status=0`; SHA-256
  `5d7fb1a97a3d862bb8bf86d569ff79c0543d3d66fa06b48c1db058c11a2ff337`.
- Exact declarations: tests 01–48 each occur once.
- Authority source gate: no service-held `any LLMProvider`, direct
  `provider.streamTurn`, legacy `Distiller(provider:)`, Guide `Task {`, or
  legacy Orchestrator distillation-task symbol; only
  `LegacyEventScopeResolver.swift` constructs a runtime `EventRecord`.
- Frozen `Package.resolved` remains
  `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`.
- Scope audit after E3:
  `dirty_total=578`, `allowlisted_present_count=71`,
  `outside_count=507`,
  `outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242`.
- `git diff --check` passes.

The user explicitly removed the Claude-review requirement and directed Codex
to execute independently. E3 therefore has an implementer self-review against
the frozen plan and executable gates, not a falsely attributed independent
Claude approval.

## E4 — complete

Implemented the frozen ordinary-Ingestion deletion band:

- sealed prepare request, command payload, whole-command hash, execution
  resolution, safe result, and persisted event contracts;
- Store-only prepare/execute/resolve authority with zero-write prepare,
  exact replay, shared persisted-graph validation, and fail-closed typed
  not-committed/resolution-pending dispositions;
- exact `resultOnly` and `sourceAndResult` state matrices, blocker checks,
  lifecycle/row/result CAS fences, receipt/scope/event/outbox evidence, and
  exact affected-row accounting in one transaction;
- an instance-owned raw SQLite permit registry with one production UDF
  registration call, generation/cursor ordering, sticky mismatch handling,
  `xDestroy` ownership, direct close, BUSY close/retry, `close_v2` zombie, and
  256-cycle pointer-reuse lifecycle coverage;
- active-Camp lifecycle and ingestion/result version fences on rumination
  start, success, failure, cancel, repair, Feed discard, review writes, and
  materialization so stale workers cannot recreate or overwrite deleted data;
- removal of the legacy `deleteIngestionAtomically` and
  `IngestionDeletionMode` product seams, with App/Application callers routed
  through the sealed Store workflow.

E4 product and test paths changed or added:

- `Sources/AgentLoopCore/Domain/IngestionDeletion.swift`
- `Sources/AgentLoopCore/Database/IngestionDeletionStore.swift`
- `Sources/AgentLoopCore/Database/ActiveIngestionDeletionSQLPermit.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Ingestion/FeedService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift`
- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`
- `Sources/AgentLoopTestSuite/IngestionDeletionContractTests.swift`
- `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
- `Sources/AgentLoopTestSuite/DurableWorkTests.swift`
- `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`

Root-cause corrections made while closing E4:

- registration-failure testing now uses SQLite's invalid-function-name path at
  the same private registration call site, preserving real `xDestroy`
  semantics instead of simulating ownership;
- worker/materializer tests use real public APIs and all start/delete,
  completion/delete, failure/delete, cancel/delete, lifecycle, review, and
  projection race orders rather than raw-SQL smoke substitutes;
- rejection matrices assert the exact failure value, not merely the shared
  error type;
- legacy source sentinels were updated to assert the new Store authority and
  CAS fences without weakening runtime behavior.

## E4 evidence

- Pure red: `red-e4-ingestion.log`, immutable SHA-256
  `93259fbae9a2959a4b772963651e1ef810b89edba088b06588fe16f076b9eab1`.
- Current cumulative focused evidence: `focused-verify.log`, exactly tests
  01–80, 80 tests / 8 suites, zero failures, `test_status=0`,
  `tee_status=0`; SHA-256
  `f0465d9a3c10218b7af1396c29fadf66639bc0314c4c2f628807eebeec8fd78d`.
- Related Rumination regression: 45 tests / 3 suites, zero failures.
- Current dual SQLite matrix: SQLite 3.51.0 and 3.52.0 real/literal lanes,
  legal deletion paths, fail-closed raw UDF lane, replay, rollback, FK,
  integrity, and exact 67/171/67 checkpoint all pass;
  `p1_migration_matrix.result=pass`, `script_status=0`, `tee_status=0`.
  `migration-matrix.log` SHA-256:
  `9e18c4fab3bad64177b69ead35ef87fbd565144e3dd8a208c2fbbb7cb0d43c56`.
- Source ownership gate: only
  `ActiveIngestionDeletionSQLPermit.swift` imports `GRDBSQLite` or owns raw
  SQLite symbols; it contains one `sqlite3_create_function_v2` source call and
  no GRDB `DatabaseFunction`, deterministic/DIRECTONLY, or close-hook path.
- Exact declarations: tests 01–80 each occur once; no later P1-E identifier is
  present before E5.
- Frozen scope remains exact: `dirty_total=583`,
  `allowlisted_present_count=76`, `outside_count=507`,
  `outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242`.
- Frozen plan, allowlist, and `Package.resolved` hashes remain exact;
  `git diff --check` passes.

The user explicitly removed the Claude-review requirement and directed Codex
to execute independently. E4 therefore has an implementer self-review against
the frozen plan and executable gates, not a falsely attributed independent
Claude approval.

## Next gate

E5 is open only for tests 81–90 and `red-e5-application.log`. Application/UI
implementation remains closed until that pure-red frame is saved.

## E5 — implemented; final revalidation pending

Implemented the sealed application workflow and UI evidence band for tests
81–90, including prepared/executing/resolution-pending/committed-refresh
phases, same-handle replay, fail-once refresh recovery, stable trace display,
and release-zero preview seams. The initial 90-test focused gate, build,
source gate, matrix, and isolated UI evidence were green before the first
authoritative compatibility run. They will be regenerated after compatibility
closure rather than reused as final evidence.

## Revisions 02–04 compatibility closure — focused gate complete

The immutable first full-suite red frame is `verify-red.log`, 990 tests / 24
suites / 118 issues, SHA-256
`9cf63ce72bf30104132b736c53dd77fb0f4f1b60621dc438ed5fc7b4b8f1ea4b`.
The failures were corrected by their demonstrated v16 roots, without lifecycle
auto-provision, trigger weakening, deletion fallback, assertion removal, or
P1-F behavior.

Final compatibility root fixes include:

- explicit `open -> answered` user-request lifecycle writes in both answer
  owners;
- exact canonical event payload preservation and numeric epoch storage for
  `EventRecord.createdAt`;
- scope-first schedule events and a dual global/Camp kernel-error rule;
- lifecycle/scope-correct historical fixtures, GRDB-backed isolated application
  corruption clones, and real Run ownership in BoardTools fixtures;
- exact multiline Cow personality validation and companion-note scope;
- current v16 deletion fences and A3/A4 successor-boundary sentinels.

Revision 03 and Revision 04 are independently approved by Codex Review01c and
Review01d with zero P0/P1. The user explicitly excluded Claude; neither review
is attributed to Claude.

Current post-fix evidence:

- kernel source-unchanged red: 2 tests / 2 issues,
  `/tmp/p1e-kernel-red.Vhcyl3`, command 1 / tee 0, SHA-256
  `4307a926fd8890ff2ab44fdbd0d29a1c40aaefde7bc8f8760f14ef3f6f8e98d7`;
- kernel green: 4 tests / 2 suites,
  `/tmp/p1e-kernel-green.qqABTp`, command 0 / tee 0, SHA-256
  `4549537b6222dd11bd3d9e712640df1b4aeafe3164db96819794d27a3ba33a7c`;
- Schedule corruption green: 1 test,
  `/tmp/p1e-schedule-corruption-green.C2FuZq`, command 0 / tee 0, SHA-256
  `8b70b4972ceff56087bb2df5116f974a406fa52ac3130da1ce9caf2890db2401`;
- Board/Schedule/boundary green: 7 tests,
  `/tmp/p1e-final-fixtures-green.baPQbl`, command 0 / tee 0, SHA-256
  `c97eccaa175a849aad5c9774f7053b329d3fab9ac5a3b7e6d76a5713a5fbb971`;
- all 112 current successors of the first red-frame failures: 112 tests / 8
  suites, `/tmp/p1e-compatibility-green.dOIzvY`, command 0 / tee 0, SHA-256
  `31f5f83827c6a191e663df31c70d7e721d854de77db5eeec96ce063a81ffbe9e`;
- four load-sensitive tests, each standalone three times: all 12 runs green,
  `/tmp/p1e-load-sensitive-3x.6EODiC`, command 0 / tee 0, SHA-256
  `e6d0f2afcbf5717764e2a328f70d3cd91b54ad2e6a9b95f0619cf01dd3fe653b`.

Effective scope is the 104-line allowlist, SHA-256
`fa6fb13794903e66ce316f69a5f39922e9edca0fea69f72099a258c12cd3b43c`.
The frozen outside boundary is 499 paths with manifest
`206148164535b7e48b1fc64ec564c4bf5ff9b86981ec12509c9d43b7fd9243a9`.

## Next gate

Regenerate, in order: exact 90-test focused evidence, source/scope evidence,
App build, dual SQLite matrix, authoritative unfiltered `swift run RunTests`,
then independent implementation review and acceptance. P1-F1 remains closed.

## Revision 05 — plan frozen; implementation not started

The first post-Revision-04 default-parallel full gate is preserved as
`verify-revision-05-red.log`: 990 tests / 24 suites / 10 issues, SHA-256
`73d01654ef40470f46a770ce0ad53266aab5ebbcb9e0886061a47e0bf2463e62`.
The five deterministic canonical failures reproduce together in
`red-revision-05-canonical.log`, SHA-256
`275f82090c8a68c28015d2eaf52d988f0a41030930ce8a6ed951a9861f7accf6`.
The serial diagnostic is `verify-serial-revision-05-red.log`: 990 tests / 24
suites / 6 issues, SHA-256
`362552121ec436911a860639654d0eb65d9bf54d3b2314f379a123dbe0897c6d`.

Revision 05 freezes three bounded roots: canonical bytes at the typed legacy
event seam plus exact planning-token fixture integers; single-flight cold
login-environment capture; and Board test-client timeout/first-baseline
semantics. It explicitly preserves the default-parallel authoritative gate,
all product timeouts/cooldowns, `RunTests`, raw canonical validation, and Board
server production code. The effective allowlist is 115 lines, SHA-256
`a1f784a4f664c91583a1b3c758a32b3573a21810e0e722048ab7e7ada582085c`;
outside boundary is 496 / `5324d448...2299b95`.

Implementation remains closed pending independent Codex Review01e with zero
P0/P1. P1-E is not accepted and P1-F1 remains closed.

## Revision 05 implementation and Revision 06 trigger

Independent Codex Review01e approved Revision 05 with zero P0/P1 before any
source/test write. Tests-first evidence is
`red-revision-05-tdd.log`, command 1 / tee 0, SHA-256
`90acaa76cc389d2fc62b16e7c1c9f9bbf266af804c1bd13f4cfe2e681ec5b426`.

Revision 05 implemented only the approved roots:

- typed legacy-event payloads now enter the strict raw sink through
  `CanonicalJSONV1`;
- the test planning helper uses exact typed `Int64` counters and raw canonical
  bytes;
- login-shell capture is a cancellation-independent single-flight with cache
  publication before slot clearing;
- shell-registry failure cleanup cancels and awaits the task;
- Board timeout and EOF are distinct test-client outcomes;
- the historical allowlist/intersection sentinel was updated exactly.

Initial green evidence:

- combined root gate: 8 tests / 2 suites, command 0 / tee 0,
  `/tmp/p1e-rev05-narrow-8.log`, SHA-256
  `d23e2e32604e4443afd49800e70353ca65974cc91a27a3980ee8a803595ef440`;
- canonical closure: 7 tests, command 0 / tee 0,
  `/tmp/p1e-rev05-canonical-green.log`, SHA-256
  `410fd65d3b6f20c845972ecf797243746d313166af794bc7a4ef149cad749365`;
- login environment plus shell registry: 2 tests in each of three executions,
  command 0 / tee 0, `/tmp/p1e-rev05-shell-3x-green.log`, SHA-256
  `16196929134f19dd9f39a509a43998cec050ab87f24542ec647e81ae225d68f4`.

The next Board gate preserved a descriptor failure instead of retrying. The
task-local copy is `red-revision-06-board-fd.log`, command 1 / tee 0, SHA-256
`9960c733280e44f6278adf28f3d889d3b92757ea6c6aeed50add81c037e5a7de`.
Independent LLDB/lsof analyses matched every caught failed connect to one
unclosed `unix ->(none)` descriptor and ruled out product server/DB
accumulation. A separate static audit found two proof defects: complete merged
environment equality was not asserted, and the suspended-queue test installed
its resume defer after throwing setup.

Revision 06 freezes the resulting bounded correction in
`plan-revision-06.md`, 255 lines, SHA-256
`6894971b1a39bc004ffde1f71bc2954843b5b4eccc88dbeffc383aa30722b0f9`.
The effective allowlist is 121 lines, SHA-256
`390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46`;
the outside boundary remains 496 /
`5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95`.
No further source/test implementation has started pending independent
Review01f.

## Revision 09 — final implementation and verification

Revision 09 is the effective completion authority. Its plan SHA-256 is
`84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5`.
Independent Codex Review01i approved it before product/test writes with zero
P0/P1; the review SHA-256 is
`8b82999ec282ef321ed3f1dffdb42c09a85e398c9eec79fdec95ce35fba3120d`.
Revisions 07–08 and Reviews 01g–01h remain immutable trigger/review history.

The first post-Revision-06 exact default-parallel full gate was preserved,
not retried into a chance green. `verify-revision-07-red.log` records 992 tests
in 24 suites with four issues and has SHA-256
`8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d`.
`diagnostic-revision-07.log`, SHA-256
`162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b`,
separates the four reproducible causes from product behavior:

- shutdown used scheduler-sensitive wall time instead of observing the
  injected 25 ms deadline causally;
- cooldown used real time, so full-suite load could consume the 400 ms window
  before the second reconciliation;
- Board framing shared the global utility queue with a heavily parallel test
  process;
- failed-connect ownership was asserted through process-global FD counts,
  which can rise or fall because unrelated tests own the same process.

Tests-first evidence is frozen in `red-revision-08-tdd.log`, SHA-256
`370566efabebd27ae43767b2acff04d148257002e719fd69c5bfa6618677de77`.
It preserves the unrelated-pipe FD failure and the missing `acceptQueue` /
`rateLimitNow` compile failures before the corresponding implementation.

The Revision-09 implementation changes only the five frozen files:

- `BoardToolServer.swift` adds a source-compatible injected accept queue and
  uses it only for the accept loop; the handler queue remains distinct;
- `Orchestrator.swift` adds a package-testable clock seam whose public/live
  default remains `ContinuousClock.now` and whose only two reads are the
  cooldown set/check sites;
- `BoardServerTests.swift` proves real descriptor open/close ownership with an
  observer while unrelated FDs remain open, and gives framing two distinct
  ready serial queues without changing the five-second socket timeout;
- `HaltAndCooldownTests.swift` replaces wall-clock waiting with exact manual
  time and proves zero dispatch before, then recovery after, a 400 ms advance;
- `DurablePlanningTests.swift` controls only the 25 ms shutdown deadline,
  preserves the cancellation-ignoring provider contract, and updates the
  historical scope sentinel to the approved 135-path arithmetic.

The first shutdown probe intercepted an unrelated supervisor sleep; that
failure is retained and classified in `revision-08-narrow-gates.log`. The
bounded correction passes non-25 ms sleeps through the original cancellable
sleep and controls only the contractual shutdown deadline. No product timeout,
cooldown duration, socket timeout, runner parallelism, assertion, provider
double, or supervisor behavior was weakened.

### Final gates

- Revision-09 narrow/compatibility evidence: root four green; shutdown plus
  cooldown five separate runs green; Board framing/timeout/owned-FD/wrong-token
  five separate runs green; full Board suite three runs green; resource eight
  three runs green; exact 112 successors green; SHA-256
  `3a7de4497d2fd529306cfbc771a64937e844d9e4658149bf49d241f45f6cd9d3`.
- Exact P1-E manifest: 90 tests / 9 suites green; SHA-256
  `5c20c836cedcdbd0c0703505b3e0ff9f5d5b69b2db6ea70812bdbc3faa380649`.
- Source/scope gate: all 19 inherited sections and every Revision-09 delta
  pass; 135 allowlist entries; outside 494 with manifest
  `b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740`;
  A4 raw/owned/unaffected = 40/10/128; A3 raw/owned/live = 42/10/124;
  SHA-256
  `a2a510c1ea2895f372ffa81ebcef5ae33a81eac1d45eb6d8d395870c06fe01b5`.
- `swift build --product AgentLoopApp`: command/tee 0; SHA-256
  `67b6b8a18690e9d68e853e196739f8beb84aeac969cf4532fcb08230eaed9802`.
- Dual-SQLite migration/replay/rollback/FK/integrity matrix remains valid
  because every protected input hash is unchanged; SHA-256
  `060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d`.
- Fresh isolated packaged-app preview passed executable identity, 27 bundled
  resources, codesign inspection, SQLite integrity/FK, migration tail
  v16/v15/v14, exact process termination, and no residual app process;
  SHA-256
  `4563da916861f4bcc57de2832c46e10d2a2f8dfc6d222eab484558209e532f55`.
- Final authoritative exact `swift run RunTests`: 992 tests / 24 suites passed
  in 50.505 seconds under default parallel execution; command/tee 0; it was run
  once after all other gates; SHA-256
  `0a0be3ef6b29fd949c97628183e07514476fc4545ed396fd4fa7e691c23d51e6`.
- Full `git diff --check` passed. No `RunTests`, `AgentLoop`, or
  `AgentLoopApp` process remained after verification.

The source-gate evidence discloses three pre-product gate-script corrections:
Ruby 2.6 method syntax, a Ruby `Set` constructor shape, and the distinction
between the registered function-name variable and its single release literal.
All failed candidates are hashed in `source-gates.log`; none changed source,
tests, or the repository evidence log before the final all-green calculation.

No commit, push, merge, release, payment, public communication, real-user
action, or normal-user-data mutation was performed. P1-E is ready for the
independent implementation Review02; P1-F1 remains closed until Review02 and
`acceptance.md` are green.
